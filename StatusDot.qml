import QtQuick
import qs.Commons
import qs.Ui

// The availability of the agent as a single light next to the panel title:
// green while it reports, amber once the data went stale, red when it stopped
// or the snapshot cannot be read. It stands in for the summary card, so the
// wording that card carried is kept on hover rather than dropped.
Item {
  id: root

  required property var theme
  property string tone: "default"
  property string tooltipText: ""

  readonly property color toneColor: root.theme.tone(root.tone)
  readonly property real diameter: Style.space(16)

  implicitWidth: root.diameter
  implicitHeight: root.diameter

  // The halo keeps the light readable on a theme whose background sits close
  // to the tone itself, where the bare dot would nearly disappear
  Rectangle {
    anchors.centerIn: parent
    width: root.diameter
    height: width
    radius: width / 2
    color: Util.alpha(root.toneColor, 0.22)
  }

  Rectangle {
    anchors.centerIn: parent
    width: Math.round(root.diameter * 0.55)
    height: width
    radius: width / 2
    color: root.toneColor
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
  }

  PanelToolTip {
    visible: root.tooltipText !== "" && mouse.containsMouse
    text: root.tooltipText
    fontFamily: root.theme.fontFamily
  }
}
