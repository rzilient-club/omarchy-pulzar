import QtQuick
import qs.Commons

// A state in its tone: tinted background, colored label
Rectangle {
  id: root

  required property var theme
  property string tone: "default"
  property string text: ""

  readonly property color toneColor: root.theme.tone(root.tone)

  implicitWidth: label.implicitWidth + Style.space(12)
  implicitHeight: label.implicitHeight + Style.space(4)
  radius: root.theme.pill(height)
  color: Util.alpha(root.toneColor, 0.16)
  border.width: Math.max(1, Style.normalBorderWidth)
  border.color: Util.alpha(root.toneColor, 0.45)

  Text {
    id: label
    textFormat: Text.PlainText
    anchors.centerIn: parent
    text: root.text
    color: root.toneColor
    font.family: root.theme.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
  }
}
