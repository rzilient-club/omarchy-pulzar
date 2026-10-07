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

  readonly property color success: root.pick("green", root.accent)
  readonly property color warning: root.pick("yellow", root.pick("orange", root.accent))
  readonly property color error: root.pick("red", root.urgent)

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
