import QtQuick
import qs.Commons

// The dashboard's shape, for the rzilient tab only.
//
// Its greys, its 16px cards, its 24px chips, its 8px scale and its timeline
// geometry — so the tab reads as the platform rather than as the bar. The
// typeface is deliberately not part of that: it follows the panel, so the two
// tabs are recognisably one window.
QtObject {
  id: root

  // The tenant's resolved palette, straight off the device payload. It can be
  // personalised per company, so it is read rather than assumed; the constants
  // below are only what to draw when a company has not been asked yet.
  property var tenant: null

  // The panel's own family, set by whoever builds this. Eduard's decision: the
  // tab matches the dashboard's shape — its sizes, weights, spacing, chips and
  // timeline geometry — but not its typeface, which stays the one the rest of
  // the plugin uses so the two tabs read as one panel.
  property string fontFamily: Style.font.family

  // 8px scale
  function space(steps) { return Math.round(Style.space(8) * steps / 8) }
  readonly property int cardRadius: Style.space(16)

  readonly property int sizeHeader: Style.space(14)
  readonly property int sizeBody: Style.space(14)
  readonly property int sizeCaption: Style.space(12)

  readonly property color grey0: "#FFFFFF"
  readonly property color grey100: "#F3F2EE"
  readonly property color grey200: "#EFEDE7"
  readonly property color grey300: "#E7E4DA"
  readonly property color grey400: "#D5D1C3"
  readonly property color grey500: "#A7A496"
  readonly property color grey600: "#787668"
  readonly property color grey700: "#3B3A33"
  readonly property color grey750: "#2A2E2B"
  readonly property color grey800: "#1F2321"
  readonly property color grey850: "#161A18"
  readonly property color grey900: "#000000"

  // A tenant may recolour its own surface; everything else is structural
  readonly property color background: root.tenant && root.tenant.primary ? root.tenant.primary : root.grey800
  readonly property color card: root.grey750
  readonly property color neutral: root.grey700
  readonly property color text: root.grey0
  readonly property color textSecondary: root.grey500
  // Never used as a chip: the tenant's primary is near-black charcoal and
  // illegible behind text
  readonly property color accent: root.tenant && root.tenant.secondary ? root.tenant.secondary : "#C1EE44"

  readonly property color divider: Qt.rgba(167 / 255, 164 / 255, 150 / 255, 0.2)
  readonly property color hover: Qt.rgba(167 / 255, 164 / 255, 150 / 255, 0.08)

  // Chip pairs: the palette's dark tone on its light tone lightened 30%
  readonly property var chips: ({
    success:   { text: "#118D57", fill: "#9FF2AD" },
    error:     { text: "#B71D18", fill: "#FFC4A7" },
    warning:   { text: "#B76E00", fill: "#FFE293" },
    info:      { text: "#006C9C", fill: "#90F6F6" },
    secondary: { text: "#7A9900", fill: "#D3F37C" }
  })

  function chip(tone) {
    return root.chips[tone] || root.chips.secondary
  }

  // Timeline dot backgrounds, the palette's main tone
  readonly property var dots: ({
    success: "#22C55E",
    info: "#00B8D9",
    error: "#FF5630",
    warning: "#FFAB00",
    grey: "#D5D1C3"
  })

  function dot(tone) {
    return root.dots[tone] || root.dots.grey
  }
}
