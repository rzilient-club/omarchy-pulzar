import QtQuick
import qs.Commons
import qs.Ui

// A titled section of the panel (SectionCard of the React panel)
Column {
  id: root

  required property var theme
  property string title: ""
  property string subheader: ""
  default property alias content: body.data

  width: parent ? parent.width : implicitWidth
  spacing: Style.space(8)

  Item {
    width: parent.width
    implicitHeight: Math.max(header.implicitHeight, sub.implicitHeight)

    PanelSectionHeader {
      id: header
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: root.title.toUpperCase()
      foreground: root.theme.foreground
      fontFamily: root.theme.fontFamily
    }

    Text {
      id: sub
      textFormat: Text.PlainText
      visible: root.subheader !== ""
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: Math.min(implicitWidth, parent.width - header.implicitWidth - Style.space(12))
      horizontalAlignment: Text.AlignRight
      elide: Text.ElideRight
      text: root.subheader
      color: root.theme.dim
      font.family: root.theme.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  Column {
    id: body
    width: parent.width
    spacing: Style.space(4)
  }
}
