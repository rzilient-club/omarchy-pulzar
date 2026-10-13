import QtQuick

// One event in the device's history: a coloured dot with its icon, a connector
// running to the next, the headline and the date.
Item {
  id: root

  required property var dash
  property string icon: ""
  property string tone: "grey"
  property string headline: ""
  property string date: ""
  // The connector stops at the last row rather than trailing into nothing
  property bool last: false

  readonly property int dotSize: root.dash.space(36)

  width: parent ? parent.width : implicitWidth
  implicitHeight: Math.max(root.dash.space(70), body.implicitHeight + root.dash.space(16))

  Rectangle {
    id: connector
    visible: !root.last
    width: 2
    color: root.dash.grey400
    anchors.top: dot.bottom
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: dot.horizontalCenter
  }

  Rectangle {
    id: dot
    width: root.dotSize
    height: root.dotSize
    radius: width / 2
    color: root.dash.dot(root.tone)
    anchors.left: parent.left
    anchors.top: parent.top

    Text {
      anchors.centerIn: parent
      text: root.icon
      color: "#FFFFFF"
      font.family: root.dash.fontFamily
      font.pixelSize: root.dash.space(24)
    }
  }

  Column {
    id: body
    anchors.left: dot.right
    anchors.leftMargin: root.dash.space(12)
    anchors.right: parent.right
    anchors.top: parent.top
    spacing: root.dash.space(4)

    Text {
      textFormat: Text.PlainText
      width: parent.width
      wrapMode: Text.WordWrap
      // Already a finished sentence, built server-side in the reader's
      // language — shown as written rather than recomposed from action+event
      text: root.headline
      color: root.dash.text
      font.family: root.dash.fontFamily
      font.pixelSize: root.dash.sizeBody
    }

    Text {
      textFormat: Text.PlainText
      visible: root.date !== ""
      text: root.date
      color: root.dash.textSecondary
      font.family: root.dash.fontFamily
      font.pixelSize: root.dash.sizeCaption
      font.weight: Font.DemiBold
    }
  }
}
