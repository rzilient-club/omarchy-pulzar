import QtQuick
import Quickshell
import Quickshell.Io
import "Config.js" as Config

// The platform sign-in behind the panel.
//
// None of this can be done in QML: Quickshell's Socket and SocketServer are
// Unix-domain only, so there is no way to serve the loopback address the
// authorization code comes back on, and there is no SHA-256 for the PKCE
// challenge either. `bin/pulzar-auth` owns both and answers in one line of
// JSON per stage, which is all this reads. No token ever crosses the pipe.
QtObject {
  id: root

  // The shipped values come from Config.js, which Node can read too, so the
  // test that they are present and non-empty is structural rather than a
  // regex over this file. A caller pointing an install elsewhere overrides the
  // property; it must not pass an empty string to mean "use the default",
  // because an empty string is a value and wins — that is what blanked these
  // once already.
  readonly property string defaultClientId: Config.CLIENT_ID
  readonly property string defaultIssuer: Config.ISSUER
  readonly property string defaultConsentOrigin: Config.CONSENT_ORIGIN

  property string clientId: root.defaultClientId
  property string issuer: root.defaultIssuer
  // Where the person approves. The API answers /oauth/authorize with JSON for
  // the React consent card to consume, so a browser has to be sent to the
  // dashboard instead; the token exchange stays on the API above.
  property string consentOrigin: root.defaultConsentOrigin

  property bool signedIn: false
  property bool expired: false
  property real expiresAt: 0
  property bool busy: false
  // "" while nothing is wrong; otherwise the reason the helper reported
  property string failure: ""
  // The page the user has to approve in, while a sign-in is in flight
  property string consentUrl: ""
  // Set when signing out removed the credential here but could not get the
  // platform to retire it. Worth saying: the token stays usable until it
  // expires, so "signed out" would otherwise be half true.
  property string revokeFailed: ""

  readonly property bool configured: root.clientId !== ""

  // The helper sits next to this file; Quickshell hands back a file:// URL
  readonly property string helper: String(Qt.resolvedUrl("bin/pulzar-auth")).replace(/^file:\/\//, "")

  signal changed()

  function check() { root.run(["status"]) }
  function signIn() { root.run(["login"]) }
  function signOut() { root.run(["logout"]) }
  function renew() { root.run(["refresh"]) }

  function run(commandArgs) {
    if (root.busy) return

    root.busy = true
    root.failure = ""
    root.consentUrl = ""
    root.revokeFailed = ""

    // The client id travels in the environment rather than the command line,
    // where every process on the machine could read it
    helperProcess.environment = ({
      PULZAR_CLIENT_ID: root.clientId,
      PULZAR_ISSUER: root.issuer,
      PULZAR_CONSENT_ORIGIN: root.consentOrigin
    })
    helperProcess.command = [root.helper].concat(commandArgs)
    helperProcess.running = true
  }

  // Each line is a stage. `awaiting_consent` arrives first and the sign-in is
  // still running; the last line says how it ended.
  function apply(line) {
    var message

    try {
      message = JSON.parse(line)
    } catch (e) {
      console.warn("rzilient.pulzar: cannot read the sign-in helper: " + line)
      return
    }

    if (!message.ok) {
      root.failure = String(message.reason || "unknown")
      root.signedIn = false
      root.changed()
      return
    }

    if (message.stage === "awaiting_consent") {
      root.consentUrl = String(message.url || "")
      return
    }

    if (message.revoke_failed) root.revokeFailed = String(message.revoke_failed)

    if (message.signed_in !== undefined) root.signedIn = !!message.signed_in
    else if (message.stage === "signed_in" || message.stage === "refreshed") root.signedIn = true

    root.expiresAt = Number(message.expires_at || 0)
    root.expired = !!message.expired
    root.changed()
  }

  property Process helperProcess: Process {
    stdout: SplitParser { onRead: function(line) { if (line.trim()) root.apply(line) } }
    onExited: function(exitCode) {
      root.busy = false
      root.consentUrl = ""
      // A non-zero exit already reported its reason on stdout
      if (exitCode !== 0 && root.failure === "") root.failure = "helper_failed"
    }
  }

  // The helper writes the token; the panel only needs to know it is there
  property Timer initial: Timer {
    interval: 200
    running: true
    onTriggered: root.check()
  }
}
