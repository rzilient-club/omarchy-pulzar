import QtQuick
import qs.Commons
import "Format.js" as Format

// Used and total bytes of the memory or the storage, with a bar that turns to
// the warning, then the error tone (Metric of the React UsageCard)
Rectangle {
  id: root

  required property var theme
  required property var t
  property string label: ""
  property string icon: ""
  property real used: 0
  property real total: 0

  readonly property int percent: Format.usagePercent(root.used, root.total)
  readonly property color toneColor: root.theme.tone(Format.usageTone(root.percent))

  implicitHeight: content.implicitHeight + Style.space(20)
  radius: Style.cornerRadius
  color: Util.alpha(root.theme.foreground, 0.05)

  Column {
    id: content
    anchors.fill: parent
    anchors.margins: Style.space(10)
    spacing: Style.space(6)

    Item {
      width: parent.width
      implicitHeight: Math.max(iconText.implicitHeight, percentText.implicitHeight)

      Text {
        id: iconText
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: root.icon
        color: root.theme.dim
        font.family: root.theme.fontFamily
        font.pixelSize: Style.font.icon
      }

      Text {
        textFormat: Text.PlainText
        anchors.left: iconText.right
        anchors.leftMargin: Style.space(6)
        anchors.right: percentText.left
        anchors.rightMargin: Style.space(6)
        anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight
        text: root.label
        color: root.theme.dim
        font.family: root.theme.fontFamily
        font.pixelSize: Style.font.caption
      }

      Text {
        id: percentText
        textFormat: Text.PlainText
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: root.percent + "%"
        color: root.theme.foreground
        font.family: root.theme.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
      }
    }

    Column {
      width: parent.width
      spacing: Style.space(1)

      Text {
        textFormat: Text.PlainText
        width: parent.width
        elide: Text.ElideRight
        text: Format.formatBytes(root.used, root.t)
        color: root.theme.foreground
        font.family: root.theme.fontFamily
        font.pixelSize: Style.font.subtitle
        font.bold: true
      }

      Text {
        textFormat: Text.PlainText
        width: parent.width
        elide: Text.ElideRight
        text: root.t.ofTotal(Format.formatBytes(root.total, root.t))
        color: root.theme.dim
        font.family: root.theme.fontFamily
        font.pixelSize: Style.font.caption
      }
    }

    Rectangle {
      width: parent.width
      height: Style.space(4)
      radius: height / 2
      color: Util.alpha(root.theme.foreground, 0.12)

      Rectangle {
        width: parent.width * root.percent / 100
        height: parent.height
        radius: parent.radius
        color: root.toneColor
      }
    }
  }
}
