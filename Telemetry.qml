import QtQuick
import Quickshell
import Quickshell.Io
import "Snapshot.js" as Snapshot
import "Locales.js" as Locales

// Data of the panel: the snapshot written by the agent, the host name and the
// language. Plays the role of the status service of the agent's tray
// application, without leaving omarchy-shell.
QtObject {
  id: root

  property string snapshotPath: Snapshot.DEFAULT_PATH
  // The agent rewrites the snapshot after its collections, the file watch
  // catches it; the poll also ages the data (stale) and finds a new file
  property int refreshIntervalSec: 5

  // Parsed snapshot, kept when a later read fails
  property var snapshot: null
  property bool snapshotMissing: false
  property bool isError: false
  property bool isPending: true
  property string lastText: ""
  property real now: Date.now()

  property string hostname: Quickshell.env("HOSTNAME") || ""

  readonly property var status: {
    if (root.snapshot) return Snapshot.build(root.snapshot, root.hostname, root.now)
    if (root.snapshotMissing) return Snapshot.waiting(root.hostname)
    return null
  }
  // A failed refresh keeps showing the last data, with the error in the summary
  readonly property bool hasData: root.status !== null && root.status.inputs.length > 0

  // ----------------------------------------------------------------- language

  readonly property string home: Quickshell.env("HOME")
  readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || root.home + "/.local/state") + "/rzilient-pulzar"
  readonly property string languagePath: root.stateDir + "/language"

  // "auto" follows the operating system until the user picks a language
  property string languageChoice: "auto"
  readonly property string systemLanguage: Locales.systemLanguage(function(name) { return Quickshell.env(name) })
  readonly property string language: Locales.isLanguage(root.languageChoice) ? root.languageChoice : root.systemLanguage
  readonly property var t: Locales.translations[root.language]

  function setLanguage(choice) {
    var value = Locales.isLanguage(choice) ? choice : "auto"
    root.languageChoice = value
    saveLanguage.command = ["sh", "-c", "mkdir -p \"$1\" && printf %s \"$2\" > \"$3\"", "sh", root.stateDir, value, root.languagePath]
    saveLanguage.running = true
  }

  // -------------------------------------------------------------- encryption

  // The agent reports whether the system disk is encrypted, and on Linux it
  // never finds out: its binary carries no notion of LUKS, dm-crypt or
  // crypttab and answers false on every machine, encrypted or not. The panel
  // asks the system instead — the device carrying / either is a dm-crypt
  // mapping or it is not, which any user can read.
  property bool diskEncrypted: false
  property bool diskEncryptionKnown: false

  function applyDiskEncryption(output) {
    var answer = String(output || "").trim()

    if (answer !== "encrypted" && answer !== "plain") {
      root.diskEncryptionKnown = false
      return
    }

    root.diskEncrypted = answer === "encrypted"
    root.diskEncryptionKnown = true
  }

  property Process diskEncryptionProbe: Process {
    running: true
    // findmnt names the device behind /, with the btrfs subvolume stripped;
    // lsblk types it, and only a dm-crypt mapping types as "crypt"
    command: ["sh", "-c",
      "source=$(findmnt -no SOURCE / 2>/dev/null | sed 's/\\[.*\\]//'); " +
      "[ -n \"$source\" ] || { echo unknown; exit 0; }; " +
      "[ \"$(lsblk -no TYPE \"$source\" 2>/dev/null | head -1)\" = crypt ] && echo encrypted || echo plain"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyDiskEncryption(text)
    }
  }

  // ------------------------------------------------------------------ reading

  function refresh() {
    root.now = Date.now()
    snapshotFile.reload()
  }

  function parse(text) {
    root.isPending = false
    root.snapshotMissing = false

    // Same content: only the age of the data changes (status.Build uses now)
    if (text === root.lastText && root.snapshot && !root.isError) return

    try {
      root.snapshot = Snapshot.parseSnapshot(text)
      root.lastText = text
      root.isError = false
    } catch (e) {
      console.warn("rzilient.pulzar: cannot parse " + root.snapshotPath + ": " + e)
      root.isError = true
    }
  }

  // A missing snapshot is not an error: the agent did not write anything yet
  function failed(error) {
    root.isPending = false

    if (error === FileViewError.FileNotFound) {
      root.snapshot = null
      root.lastText = ""
      root.snapshotMissing = true
      root.isError = false
      return
    }

    console.warn("rzilient.pulzar: cannot read " + root.snapshotPath + ": " + FileViewError.toString(error))
    root.isError = true
  }

  property FileView snapshotFile: FileView {
    path: root.snapshotPath
    watchChanges: true
    printErrors: false
    onLoaded: root.parse(text())
    onLoadFailed: function(error) { root.failed(error) }
    onFileChanged: root.refresh()
  }

  property FileView hostnameFile: FileView {
    path: "/etc/hostname"
    printErrors: false
    onLoaded: {
      var name = String(text() || "").trim()
      if (name) root.hostname = name
    }
  }

  property FileView languageFile: FileView {
    path: root.languagePath
    printErrors: false
    onLoaded: {
      var value = String(text() || "").trim()
      root.languageChoice = Locales.isLanguage(value) ? value : "auto"
    }
  }

  property Process saveLanguage: Process {
    onExited: function(exitCode) {
      if (exitCode !== 0) console.warn("rzilient.pulzar: cannot save the language to " + root.languagePath)
    }
  }

  property Timer poll: Timer {
    interval: Math.max(1, root.refreshIntervalSec) * 1000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }
}
