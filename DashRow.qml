import QtQuick

// A label and its value, as a plain string, a chip, or both.
Item {
  id: root

  required property var dash
  property string label: ""
  property string value: ""
  property string chipText: ""
  property string chipTone: "secondary"
  // Drawn down when the fact is still true but nobody is acting on it any more
  property bool muted: false

  width: parent ? parent.width : implicitWidth
  implicitHeight: Math.max(labelText.implicitHeight, valueColumn.implicitHeight)
  opacity: root.muted ? 0.55 : 1

  Text {
    id: labelText
    textFormat: Text.PlainText
    anchors.left: parent.left
    anchors.right: valueColumn.left
    anchors.rightMargin: root.dash.space(12)
    anchors.verticalCenter: parent.verticalCenter
    elide: Text.ElideRight
    text: root.label
    color: root.dash.textSecondary
    font.family: root.dash.fontFamily
    font.pixelSize: root.dash.sizeBody
  }

  Row {
    id: valueColumn
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    spacing: root.dash.space(8)

    Text {
      textFormat: Text.PlainText
      visible: root.value !== ""
      anchors.verticalCenter: parent.verticalCenter
      text: root.value
      color: root.dash.text
      font.family: root.dash.fontFamily
      font.pixelSize: root.dash.sizeBody
    }

    DashChip {
      anchors.verticalCenter: parent.verticalCenter
      dash: root.dash
      tone: root.chipTone
      text: root.chipText
    }
  }
}
