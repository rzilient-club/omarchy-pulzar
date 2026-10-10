import QtQuick
import qs.Commons

// A label and its value on one line (InfoRow of the React panel). With a
// `tone`, the value is a chip in that tone (StatusChip).
Item {
  id: root

  required property var theme
  property string label: ""
  property string value: ""
  property string tone: ""
  // Optional control after the value — the row reserves the space itself
  property Component trailing: null

  readonly property real trailingInset: trailingLoader.item && trailingLoader.item.visible
    ? trailingLoader.width + Style.space(8) : 0

  width: parent ? parent.width : implicitWidth
  implicitHeight: Math.max(labelText.implicitHeight, valueItem.implicitHeight, trailingLoader.implicitHeight) + Style.space(4)

  Text {
    id: labelText
    textFormat: Text.PlainText
    anchors.left: parent.left
    anchors.right: valueItem.left
    anchors.rightMargin: Style.space(12)
    anchors.verticalCenter: parent.verticalCenter
    elide: Text.ElideRight
    text: root.label
    color: root.theme.dim
    font.family: root.theme.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  Loader {
    id: trailingLoader
    sourceComponent: root.trailing
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
  }

  Item {
    id: valueItem
    anchors.right: parent.right
    anchors.rightMargin: root.trailingInset
    anchors.verticalCenter: parent.verticalCenter
    width: Math.min(root.tone !== "" ? chip.implicitWidth : valueText.implicitWidth, root.width * 0.62)
    implicitHeight: root.tone !== "" ? chip.implicitHeight : valueText.implicitHeight

    Text {
      id: valueText
      textFormat: Text.PlainText
      visible: root.tone === ""
      anchors.fill: parent
      horizontalAlignment: Text.AlignRight
      elide: Text.ElideRight
      text: root.value
      color: root.theme.foreground
      font.family: root.theme.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    StatusChip {
      id: chip
      visible: root.tone !== ""
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      theme: root.theme
      tone: root.tone
      text: root.value
    }
  }
}
