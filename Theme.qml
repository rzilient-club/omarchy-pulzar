import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Colors of the panel, from the current Omarchy theme. The tones of the React
// panel (success, secondary, warning, error, info, default) map to the named
// colors of the theme's colors.toml, so the panel follows every theme switch.
QtObject {
  id: root

  property QtObject bar: null

  readonly property color foreground: root.bar ? root.bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(root.foreground, 1.55)
  readonly property color accent: Color.accent
  readonly property color urgent: root.bar ? root.bar.urgent : Color.urgent
  readonly property string fontFamily: root.bar ? root.bar.fontFamily : Style.font.family

  // Named colors of colors.toml (green, yellow, red…)
  property var named: ({})

  // Omarchy derives Style.cornerRadius from Hyprland's decoration:rounding,
  // which is 2 here and reads as square corners. The panel carries its own
  // rounding so its cards, chips, meters and buttons stay round whatever the
  // window rounding is. Everything else still follows the theme.
  property int radius: Style.space(8)

  // A chip or a pill must not round past a half circle
  function pill(height) {
    return Math.min(root.radius, height / 2)
  }

  // Naming these is optional for a theme: Artemis defines only `accent`,
  // `muted` and the ANSI slots, so success and warning both resolved to the
  // accent and error to `urgent` — one pale blue for all three, which is how
  // a running agent came to look switched off. A theme that names a colour
  // still wins; a theme that names none falls back to the green, amber and
  // red a status light is read by, rather than to a colour that signals
  // nothing.
  readonly property color defaultSuccess: "#3fb950"
  readonly property color defaultWarning: "#e3b341"
  readonly property color defaultError: "#f85149"

  readonly property color success: root.pick("green", root.defaultSuccess)
  readonly property color warning: root.pick("yellow", root.pick("orange", root.defaultWarning))
  readonly property color error: root.pick("red", root.defaultError)

  function pick(name, fallback) {
    var value = root.named[name]
    return value ? value : fallback
  }

  function tone(name) {
    switch (name) {
    case "success": return root.success
    case "warning": return root.warning
    case "error": return root.error
    case "info":
    case "secondary": return root.accent
    default: return root.dim
    }
  }

  function parseColors(text) {
    var result = {}
    var lines = String(text || "").split("\n")

    for (var i = 0; i < lines.length; i++) {
      var match = lines[i].match(/^\s*([A-Za-z0-9_]+)\s*=\s*"(#[0-9A-Fa-f]{6}(?:[0-9A-Fa-f]{2})?)"/)
      if (match) result[match[1]] = match[2]
    }

    root.named = result
  }

  property FileView colorsFile: FileView {
    path: Color.currentThemePath + "/colors.toml"
    watchChanges: true
    printErrors: false
    onLoaded: root.parseColors(text())
    onLoadFailed: root.named = ({})
    onFileChanged: reload()
  }

  // A theme switch replaces the current theme folder
  property Connections themeSwitch: Connections {
    target: Color
    function onAccentChanged() { root.colorsFile.reload() }
    function onBackgroundChanged() { root.colorsFile.reload() }
  }
}
