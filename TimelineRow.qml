import QtQuick
import qs.Commons

// One event in the device's history: a dot in its tone, a rail running to the
// next, the headline and the date.
//
// The arrangement is the dashboard's, because a chronology reads well that way
// and the data is inherently ordered. The sizing, colour and type are the
// panel's, like every other surface here.
Item {
  id: root

  required property var theme
  property string icon: ""
  property string tone: "default"
  property string headline: ""
  property string date: ""
  // The rail stops at the last row rather than trailing into nothing
  property bool last: false

  readonly property color toneColor: root.theme.tone(root.tone)
  readonly property int dotSize: Style.space(22)

  width: parent ? parent.width : implicitWidth
  implicitHeight: body.implicitHeight + Style.space(12)

  Rectangle {
    visible: !root.last
    width: Math.max(1, Style.normalBorderWidth)
    color: Util.alpha(root.theme.foreground, 0.18)
    anchors.top: dot.bottom
    anchors.topMargin: Style.space(2)
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: dot.horizontalCenter
  }

  Rectangle {
    id: dot
    width: root.dotSize
    height: root.dotSize
    radius: width / 2
    color: Util.alpha(root.toneColor, 0.18)
    anchors.left: parent.left
    anchors.top: parent.top

    Text {
      anchors.centerIn: parent
      text: root.icon
      color: root.toneColor
      font.family: root.theme.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  Column {
    id: body
    anchors.left: dot.right
    anchors.leftMargin: Style.space(10)
    anchors.right: parent.right
    anchors.top: parent.top
    spacing: Style.space(1)

    Text {
      textFormat: Text.PlainText
      width: parent.width
      wrapMode: Text.WordWrap
      // Already a finished sentence, built server-side in the reader's
      // language — shown as written rather than recomposed from action+event
      text: root.headline
      color: root.theme.foreground
      font.family: root.theme.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    Text {
      textFormat: Text.PlainText
      visible: root.date !== ""
      text: root.date
      color: root.theme.dim
      font.family: root.theme.fontFamily
      font.pixelSize: Style.font.caption
    }
  }
}
