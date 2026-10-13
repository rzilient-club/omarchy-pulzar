import QtQuick

// A titled card in the dashboard's shape: 16px radius, its own surface.
Rectangle {
  id: root

  required property var dash
  property string title: ""
  default property alias content: body.data

  width: parent ? parent.width : implicitWidth
  implicitHeight: layout.implicitHeight + root.dash.space(32)
  radius: root.dash.cardRadius
  color: root.dash.card

  Column {
    id: layout
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: root.dash.space(16)
    spacing: root.dash.space(12)

    Text {
      textFormat: Text.PlainText
      visible: root.title !== ""
      width: parent.width
      elide: Text.ElideRight
      text: root.title
      color: root.dash.text
      font.family: root.dash.fontFamily
      font.pixelSize: root.dash.sizeHeader
      font.weight: Font.DemiBold
    }

    Column {
      id: body
      width: parent.width
      spacing: root.dash.space(8)
    }
  }
}
