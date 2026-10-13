import QtQuick

// The dashboard's chip: 24px tall, fully rounded, a dark tone on a light fill.
Rectangle {
  id: root

  required property var dash
  property string tone: "secondary"
  property string text: ""

  readonly property var pair: root.dash.chip(root.tone)

  implicitWidth: label.implicitWidth + root.dash.space(16)
  implicitHeight: root.dash.space(24)
  radius: height / 2
  color: root.pair.fill
  visible: root.text !== ""

  Text {
    id: label
    textFormat: Text.PlainText
    anchors.centerIn: parent
    text: root.text
    color: root.pair.text
    font.family: root.dash.fontFamily
    font.pixelSize: root.dash.space(13)
    font.weight: Font.DemiBold
  }
}
