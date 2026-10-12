import QtQuick
import Quickshell
import Quickshell.Io

// The platform sign-in behind the panel.
//
// None of this can be done in QML: Quickshell's Socket and SocketServer are
// Unix-domain only, so there is no way to serve the loopback address the
// authorization code comes back on, and there is no SHA-256 for the PKCE
// challenge either. `bin/pulzar-auth` owns both and answers in one line of
// JSON per stage, which is all this reads. No token ever crosses the pipe.
QtObject {
  id: root

  // Set once the platform registers the plugin as a public client
  property string clientId: ""
  property string issuer: ""

  property bool signedIn: false
  property bool expired: false
  property real expiresAt: 0
  property bool busy: false
  // "" while nothing is wrong; otherwise the reason the helper reported
  property string failure: ""
  // The page the user has to approve in, while a sign-in is in flight
  property string consentUrl: ""

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

    // The client id travels in the environment rather than the command line,
    // where every process on the machine could read it
    helperProcess.environment = ({
      PULZAR_CLIENT_ID: root.clientId,
      PULZAR_ISSUER: root.issuer
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
