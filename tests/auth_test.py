#!/usr/bin/env python3
"""Drives bin/pulzar-auth end to end against a stand-in for the platform.

The stand-in enforces what the real one does — PKCE compulsory with S256, a
form-encoded token request, a public client sending no secret — so the flow is
exercised without the platform being reachable or the feature flag being on.
"""

import base64
import hashlib
import http.server
import importlib.machinery
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import threading
import time
import unittest
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
HELPER = os.path.join(HERE, "..", "bin", "pulzar-auth")

loader = importlib.machinery.SourceFileLoader("pulzar_auth", HELPER)
spec = importlib.util.spec_from_loader("pulzar_auth", loader)
pulzar_auth = importlib.util.module_from_spec(spec)
loader.exec_module(pulzar_auth)

CLIENT_ID = "pulzar-test-client"


class Platform(http.server.BaseHTTPRequestHandler):
    """Accepts only what the real authorize and token endpoints accept."""

    issued = {}
    faults = []
    live = set()
    spent = set()
    revoke_stalls = False

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path != "/oauth/authorize":
            self.send_error(404)
            return

        query = {k: v[0] for k, v in urllib.parse.parse_qs(parsed.query).items()}

        # require_pkce! runs before Doorkeeper and answers 400 invalid_request
        if not query.get("code_challenge") or query.get("code_challenge_method") != "S256":
            Platform.faults.append("pkce_missing_or_plain")
            self.send_error(400, "invalid_request")
            return

        code = "test-code"
        Platform.issued[code] = query["code_challenge"]

        target = query["redirect_uri"] + "?" + urllib.parse.urlencode(
            {"code": code, "state": query.get("state", "")})
        self.send_response(302)
        self.send_header("Location", target)
        self.end_headers()

    def do_POST(self):
        path = urllib.parse.urlparse(self.path).path

        if path == "/oauth/revoke":
            # Stands in for an endpoint that drops packets rather than
            # refusing. Interruptible, so teardown does not wait it out.
            waited = 0.0
            while Platform.revoke_stalls and waited < 30:
                time.sleep(0.05)
                waited += 0.05
            body = self.rfile.read(int(self.headers.get("Content-Length", 0))).decode()
            form = {k: v[0] for k, v in urllib.parse.parse_qs(body).items()}
            if "client_secret" in form:
                Platform.faults.append("sent_client_secret_to_revoke")
            if not form.get("client_id"):
                Platform.faults.append("revoked_without_client_id")
            # The token really dies here. RFC 7009 §2.2 wants 200 either way,
            # so the status alone would prove nothing — the test asserts the
            # token stops working, and this is what makes that true.
            Platform.live.discard(form.get("token"))
            Platform.spent.add(form.get("token"))
            self.send_response(200)
            self.send_header("Content-Length", "0")
            self.end_headers()
            return

        if path != "/oauth/token":
            self.send_error(404)
            return

        # enforce_content_type is on
        if self.headers.get("Content-Type") != "application/x-www-form-urlencoded":
            Platform.faults.append("wrong_content_type")
            self.send_error(400, "invalid_request")
            return

        body = self.rfile.read(int(self.headers.get("Content-Length", 0))).decode()
        form = {k: v[0] for k, v in urllib.parse.parse_qs(body).items()}

        # A public client must not be sending one
        if "client_secret" in form:
            Platform.faults.append("sent_client_secret")
            self.send_error(401, "invalid_client")
            return

        if form.get("grant_type") == "authorization_code":
            expected = Platform.issued.get(form.get("code", ""))
            digest = hashlib.sha256(form.get("code_verifier", "").encode()).digest()
            if base64.urlsafe_b64encode(digest).decode().rstrip("=") != expected:
                Platform.faults.append("verifier_does_not_match_challenge")
                self.send_error(400, "invalid_grant")
                return
            Platform.live.add("rt-1")
            self.json({"access_token": "at-1", "refresh_token": "rt-1",
                       "token_type": "Bearer", "expires_in": 7200, "scope": "external_api"})
            return

        if form.get("grant_type") == "refresh_token":
            # Rotation: a refresh token works once, then answers invalid_grant
            presented = form.get("refresh_token")
            if presented in Platform.spent or presented not in Platform.live:
                self.body_error(400, "invalid_grant")
                return
            Platform.spent.add(presented)
            Platform.live.add("rt-2")
            self.json({"access_token": "at-2", "refresh_token": "rt-2",
                       "token_type": "Bearer", "expires_in": 7200, "scope": "external_api"})
            return

        self.send_error(400, "unsupported_grant_type")

    def body_error(self, code, error):
        """An OAuth error carries its reason in a JSON body, not just a status."""
        body = json.dumps({"error": error}).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def json(self, payload):
        body = json.dumps(payload).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_args):
        pass


class Flow(unittest.TestCase):
    def setUp(self):
        Platform.issued, Platform.faults = {}, []
        Platform.live, Platform.spent = set(), set()
        Platform.revoke_stalls = False
        self.server = http.server.HTTPServer(("127.0.0.1", 0), Platform)
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        self.issuer = "http://127.0.0.1:%d" % self.server.server_address[1]

        # The consent card is served by the dashboard, not the API. Giving it
        # its own port means a regression that merges the two is a failure
        # here rather than something only production notices.
        self.consent_server = http.server.HTTPServer(("127.0.0.1", 0), Platform)
        threading.Thread(target=self.consent_server.serve_forever, daemon=True).start()
        self.consent = "http://127.0.0.1:%d" % self.consent_server.server_address[1]

        self.state = tempfile.mkdtemp()

    def tearDown(self):
        Platform.revoke_stalls = False
        self.server.shutdown()
        self.server.server_close()
        self.consent_server.shutdown()
        self.consent_server.server_close()

    def run_helper(self, command):
        environment = dict(os.environ,
                           XDG_STATE_HOME=self.state,
                           PULZAR_ISSUER=self.issuer,
                           PULZAR_CONSENT_ORIGIN=self.consent,
                           PULZAR_CLIENT_ID=CLIENT_ID,
                           PULZAR_NO_BROWSER="1")
        finished = subprocess.run([sys.executable, HELPER, command],
                                  capture_output=True, text=True, env=environment, timeout=60)
        lines = [json.loads(l) for l in finished.stdout.splitlines() if l.strip()]
        return finished, lines

    def visit(self, url):
        """Stands in for the browser the user would be sent to."""
        with urllib.request.urlopen(url, timeout=10) as reply:
            reply.read()

    def sign_in(self):
        environment = dict(os.environ,
                           XDG_STATE_HOME=self.state,
                           PULZAR_ISSUER=self.issuer,
                           PULZAR_CONSENT_ORIGIN=self.consent,
                           PULZAR_CLIENT_ID=CLIENT_ID,
                           PULZAR_NO_BROWSER="1")
        process = subprocess.Popen([sys.executable, HELPER, "login"],
                                   stdout=subprocess.PIPE, text=True, env=environment)
        with process.stdout as stream:
            first = json.loads(stream.readline())
            self.visit(first["url"])
            rest = [json.loads(l) for l in stream.read().splitlines() if l.strip()]
        process.wait(timeout=30)
        return first, rest

    # ------------------------------------------------------------------

    def test_signs_in_and_stores_the_token(self):
        first, rest = self.sign_in()

        self.assertEqual(first["stage"], "awaiting_consent")
        self.assertTrue(first["redirect_uri"].startswith("http://127.0.0.1:"))
        self.assertEqual(rest[-1]["stage"], "signed_in")
        self.assertEqual(Platform.faults, [])

    def test_the_authorize_url_carries_a_pkce_challenge(self):
        first, _ = self.sign_in()
        query = {k: v[0] for k, v in
                 urllib.parse.parse_qs(urllib.parse.urlparse(first["url"]).query).items()}

        self.assertEqual(query["code_challenge_method"], "S256")
        self.assertEqual(len(query["code_challenge"]), 43)
        # device_agent applications may ask for this and nothing else
        self.assertEqual(query["scope"], "device_self")
        self.assertEqual(query["response_type"], "code")
        self.assertNotIn("client_secret", query)

    def test_the_credentials_file_is_private(self):
        self.sign_in()
        path = os.path.join(self.state, "rzilient-pulzar", "credentials.json")

        self.assertEqual(os.stat(path).st_mode & 0o777, 0o600)
        self.assertEqual(os.stat(os.path.dirname(path)).st_mode & 0o777, 0o700)

    def test_status_before_and_after(self):
        _, before = self.run_helper("status")
        self.assertFalse(before[-1]["signed_in"])

        self.sign_in()
        _, after = self.run_helper("status")
        self.assertTrue(after[-1]["signed_in"])
        self.assertFalse(after[-1]["expired"])

    def test_refresh_replaces_the_token(self):
        self.sign_in()
        _, lines = self.run_helper("refresh")

        self.assertEqual(lines[-1]["stage"], "refreshed")
        with open(os.path.join(self.state, "rzilient-pulzar", "credentials.json")) as f:
            self.assertEqual(json.load(f)["access_token"], "at-2")

    def test_logout_forgets_the_token(self):
        self.sign_in()
        _, lines = self.run_helper("logout")
        _, after = self.run_helper("status")

        self.assertFalse(after[-1]["signed_in"])
        self.assertTrue(lines[-1]["revoked"])
        self.assertEqual(lines[-1]["revoke_failed"], "")

    def test_logout_retires_the_token_on_the_platform(self):
        """The file going away is not the point: the credential must stop working.

        RFC 7009 has the endpoint answer 200 for a token it does not know, so a
        green response proves nothing. This puts the revoked token back and
        checks the platform now refuses it.
        """
        self.sign_in()
        path = os.path.join(self.state, "rzilient-pulzar", "credentials.json")
        with open(path) as f:
            before = json.load(f)

        self.run_helper("logout")

        # Restore the credential someone could have kept a copy of
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            json.dump(before, f)

        _, lines = self.run_helper("refresh")

        self.assertFalse(lines[-1]["ok"])
        self.assertEqual(lines[-1]["reason"], "reauthorize_required")

    def test_signing_out_succeeds_even_if_the_platform_cannot_be_reached(self):
        """A person who clicks Sign out ends up signed out, network or not."""
        self.sign_in()
        self.server.shutdown()
        self.server.server_close()

        _, lines = self.run_helper("logout")
        _, after = self.run_helper("status")

        self.assertTrue(lines[-1]["ok"])
        self.assertFalse(lines[-1]["signed_in"])
        self.assertFalse(lines[-1]["revoked"])
        self.assertTrue(lines[-1]["revoke_failed"].startswith("unreachable"))
        # Locally signed out regardless
        self.assertFalse(after[-1]["signed_in"])
        self.assertFalse(os.path.exists(
            os.path.join(self.state, "rzilient-pulzar", "credentials.json")))

    def test_a_sign_out_killed_mid_revoke_still_signs_out(self):
        """The local half must not depend on the network half finishing.

        Revocation is synchronous with a thirty second timeout, and an endpoint
        that drops packets will sit there for all of it. If the helper is killed
        during that wait — panel closing, session ending, someone giving up —
        the person must still be signed out here. With the unlink last, they
        were not.
        """
        self.sign_in()
        path = os.path.join(self.state, "rzilient-pulzar", "credentials.json")
        self.assertTrue(os.path.exists(path))

        Platform.revoke_stalls = True
        environment = dict(os.environ, XDG_STATE_HOME=self.state, PULZAR_ISSUER=self.issuer,
                           PULZAR_CONSENT_ORIGIN=self.consent,
                           PULZAR_CLIENT_ID=CLIENT_ID, PULZAR_NO_BROWSER="1")
        process = subprocess.Popen([sys.executable, HELPER, "logout"],
                                   stdout=subprocess.DEVNULL, env=environment)
        try:
            # Long enough to be inside the stalled revocation, far short of its timeout
            time.sleep(2)
            self.assertIsNone(process.poll(), "the revoke should still be hanging")
            process.kill()
        finally:
            process.wait(timeout=10)

        self.assertFalse(os.path.exists(path),
                         "killed mid-revoke and still holding credentials")

    def test_signing_out_when_never_signed_in(self):
        _, lines = self.run_helper("logout")

        self.assertTrue(lines[-1]["ok"])
        self.assertFalse(lines[-1]["signed_in"])
        self.assertFalse(lines[-1]["revoked"])

    def test_a_code_under_the_wrong_state_is_refused(self):
        """A code arriving with someone else's state must not be exchanged."""
        environment = dict(os.environ, XDG_STATE_HOME=self.state, PULZAR_ISSUER=self.issuer,
                           PULZAR_CONSENT_ORIGIN=self.consent,
                           PULZAR_CLIENT_ID=CLIENT_ID, PULZAR_NO_BROWSER="1")
        process = subprocess.Popen([sys.executable, HELPER, "login"],
                                   stdout=subprocess.PIPE, text=True, env=environment)
        with process.stdout as stream:
            first = json.loads(stream.readline())

            with urllib.request.urlopen(
                    first["redirect_uri"] + "?" + urllib.parse.urlencode(
                        {"code": "injected", "state": "not-the-state"}), timeout=10) as reply:
                reply.read()

            rest = [json.loads(l) for l in stream.read().splitlines() if l.strip()]
        process.wait(timeout=30)

        self.assertFalse(rest[-1]["ok"])
        self.assertEqual(rest[-1]["reason"], "state_mismatch")
        self.assertFalse(os.path.exists(
            os.path.join(self.state, "rzilient-pulzar", "credentials.json")))

    def test_refusing_to_sign_in_without_a_client_id(self):
        environment = dict(os.environ, XDG_STATE_HOME=self.state,
                           PULZAR_ISSUER=self.issuer, PULZAR_CLIENT_ID="")
        finished = subprocess.run([sys.executable, HELPER, "login"],
                                  capture_output=True, text=True, env=environment, timeout=30)
        self.assertEqual(json.loads(finished.stdout)["reason"], "no_client_id")

    def test_a_spent_refresh_token_asks_for_consent_again(self):
        """Rotation retires a refresh token on use; retrying cannot recover it."""
        self.sign_in()
        self.run_helper("refresh")          # rt-1 is spent, rt-2 is live

        # Put the spent one back and refresh again
        path = os.path.join(self.state, "rzilient-pulzar", "credentials.json")
        with open(path) as f:
            stored = json.load(f)
        stored["refresh_token"] = "rt-1"
        with open(path, "w") as f:
            json.dump(stored, f)

        _, lines = self.run_helper("refresh")

        self.assertFalse(lines[-1]["ok"])
        self.assertEqual(lines[-1]["reason"], "reauthorize_required")

    def test_an_unwritable_store_keeps_the_previous_sign_in(self):
        """Deferred rotation means a failed write is recoverable, not fatal."""
        self.sign_in()
        directory = os.path.join(self.state, "rzilient-pulzar")
        before = open(os.path.join(directory, "credentials.json")).read()

        os.chmod(directory, 0o500)
        try:
            _, lines = self.run_helper("refresh")
        finally:
            os.chmod(directory, 0o700)

        self.assertFalse(lines[-1]["ok"])
        self.assertEqual(lines[-1]["reason"], "cannot_store")
        # The pair that was already on disk is untouched and still usable
        self.assertEqual(open(os.path.join(directory, "credentials.json")).read(), before)

    def test_an_empty_issuer_falls_back_to_the_default(self):
        """A QML property that was never configured arrives as an empty string,
        which os.environ.get would hand straight through as the issuer."""
        environment = dict(os.environ, XDG_STATE_HOME=self.state,
                           PULZAR_ISSUER="", PULZAR_CLIENT_ID="")
        finished = subprocess.run([sys.executable, HELPER, "login"],
                                  capture_output=True, text=True, env=environment, timeout=30)

        # It stops on the missing client id, not on a malformed empty issuer
        self.assertEqual(json.loads(finished.stdout)["reason"], "no_client_id")
        self.assertEqual(pulzar_auth.ISSUER, "https://api.rzilient.tech")

    def test_consent_goes_to_the_dashboard_and_tokens_to_the_api(self):
        """The two halves are different origins; collapsing them breaks sign-in.

        The API answers /oauth/authorize with JSON for the React consent card,
        so a browser sent there sees a payload rather than a consent screen.
        """
        first, rest = self.sign_in()

        self.assertTrue(first["url"].startswith(self.consent + "/oauth/authorize"),
                        "consent must go to the dashboard origin, got " + first["url"])
        self.assertNotIn(self.issuer, first["url"])
        # ...and the exchange still landed on the API
        self.assertEqual(rest[-1]["stage"], "signed_in")

    def test_an_unset_consent_origin_uses_the_dashboard_default(self):
        self.assertEqual(pulzar_auth.CONSENT_ORIGIN, "https://join.rzilient.club")
        self.assertNotEqual(pulzar_auth.CONSENT_ORIGIN, pulzar_auth.ISSUER)

    def opener_stub(self):
        """A stand-in browser that records the argv it was handed, one line each."""
        recorded = os.path.join(self.state, "opener-argv")
        stub = os.path.join(self.state, "opener")
        with open(stub, "w") as f:
            f.write("#!/bin/sh\n")
            # One line per argument, so a URL split by the shell shows up as
            # several lines rather than hiding inside one
            f.write('for a in "$@"; do printf "%s\\n" "$a"; done > ' + recorded + "\n")
        os.chmod(stub, 0o755)
        return stub, recorded

    def test_the_browser_receives_the_whole_url(self):
        """The handoff to the desktop, which no other test exercises.

        This went through os.system, so /bin/sh read the first & as the
        background operator and six of the seven parameters became shell
        variable assignments. Everything else was correct: login() built the
        full URL and reported it. Only the browser got a truncated one, which
        is why a green suite sat on top of a plugin that could not sign in.
        """
        stub, recorded = self.opener_stub()
        environment = dict(os.environ, XDG_STATE_HOME=self.state,
                           PULZAR_ISSUER=self.issuer, PULZAR_CONSENT_ORIGIN=self.consent,
                           PULZAR_CLIENT_ID=CLIENT_ID, PULZAR_OPENER=stub)
        # Note: no PULZAR_NO_BROWSER — the point is to let it open one
        process = subprocess.Popen([sys.executable, HELPER, "login"],
                                   stdout=subprocess.PIPE, text=True, env=environment)
        with process.stdout as stream:
            first = json.loads(stream.readline())
            self.visit(first["url"])
            stream.read()
        process.wait(timeout=30)

        deadline = time.time() + 10
        while not os.path.exists(recorded) and time.time() < deadline:
            time.sleep(0.05)
        self.assertTrue(os.path.exists(recorded), "the opener was never run")

        with open(recorded) as f:
            argv = [line.rstrip("\n") for line in f if line.strip()]

        self.assertEqual(len(argv), 1,
                         "the URL reached the browser in %d pieces: %r" % (len(argv), argv))

        query = urllib.parse.parse_qs(urllib.parse.urlparse(argv[0]).query)
        self.assertEqual(sorted(query), sorted([
            "client_id", "redirect_uri", "response_type",
            "scope", "state", "code_challenge", "code_challenge_method"]))
        self.assertEqual(query["code_challenge_method"], ["S256"])
        self.assertEqual(query["scope"], ["device_self"])
        self.assertTrue(first["opened"])

    def test_a_missing_browser_is_reported_not_fatal(self):
        """The URL is in the message, so the panel can still offer it."""
        environment = dict(os.environ, XDG_STATE_HOME=self.state,
                           PULZAR_ISSUER=self.issuer, PULZAR_CONSENT_ORIGIN=self.consent,
                           PULZAR_CLIENT_ID=CLIENT_ID,
                           PULZAR_OPENER=os.path.join(self.state, "does-not-exist"))
        process = subprocess.Popen([sys.executable, HELPER, "login"],
                                   stdout=subprocess.PIPE, text=True, env=environment)
        with process.stdout as stream:
            first = json.loads(stream.readline())
            self.assertFalse(first["opened"])
            self.assertTrue(first["url"].startswith(self.consent))
            self.visit(first["url"])
            rest = [json.loads(l) for l in stream.read().splitlines() if l.strip()]
        process.wait(timeout=30)

        # The sign-in still completes once the person reaches the URL
        self.assertEqual(rest[-1]["stage"], "signed_in")

    def test_the_pkce_pair_matches_the_rfc_vector(self):
        verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
        digest = hashlib.sha256(verifier.encode()).digest()

        # RFC 7636 Appendix B
        self.assertEqual(base64.urlsafe_b64encode(digest).decode().rstrip("="),
                         "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")

        made, challenge = pulzar_auth.pkce_pair()
        self.assertTrue(43 <= len(made) <= 128)
        self.assertEqual(challenge, base64.urlsafe_b64encode(
            hashlib.sha256(made.encode()).digest()).decode().rstrip("="))


if __name__ == "__main__":
    unittest.main(verbosity=2)
