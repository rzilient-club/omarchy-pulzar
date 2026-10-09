import QtQuick
import qs.Commons

// A glyph in a tinted square, a title and a caption, and an optional chip
// on the trailing edge (the Avatar rows of the React panel)
Item {
  id: root

  required property var theme
  property string icon: ""
  property string tone: "default"
  property string title: ""
  property string caption: ""
  property string chipText: ""
  property string chipTone: "success"

  readonly property color toneColor: root.theme.tone(root.tone)

  width: parent ? parent.width : implicitWidth
  implicitHeight: Math.max(badge.height, labels.implicitHeight)

  Rectangle {
    id: badge
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    width: Style.space(34)
    height: width
    radius: root.theme.radius
    color: Util.alpha(root.toneColor, 0.16)

    Text {
      anchors.centerIn: parent
      text: root.icon
      color: root.toneColor
      font.family: root.theme.fontFamily
      font.pixelSize: Style.font.iconLarge
    }
  }

  Column {
    id: labels
    anchors.left: badge.right
    anchors.leftMargin: Style.space(12)
    anchors.right: chip.visible ? chip.left : parent.right
    anchors.rightMargin: chip.visible ? Style.space(8) : 0
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(2)

    Text {
      textFormat: Text.PlainText
      width: parent.width
      wrapMode: Text.WordWrap
      maximumLineCount: 2
      elide: Text.ElideRight
      text: root.title
      color: root.theme.foreground
      font.family: root.theme.fontFamily
      font.pixelSize: Style.font.body
      font.bold: true
    }

    Text {
      textFormat: Text.PlainText
      visible: root.caption !== ""
      width: parent.width
      wrapMode: Text.WordWrap
      maximumLineCount: 3
      elide: Text.ElideRight
      text: root.caption
      color: root.theme.dim
      font.family: root.theme.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  StatusChip {
    id: chip
    visible: root.chipText !== ""
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    theme: root.theme
    tone: root.chipTone
    text: root.chipText
  }
}
