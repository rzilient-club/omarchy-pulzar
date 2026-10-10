import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

// Language selector for the panel header: the flag and the code of the
// current choice, the four languages and the automatic choice behind it.
// The shell's Dropdown draws its rows as plain text and Catalan has no flag
// that fits in a string, so the list is built here instead.
Item {
  id: root

  required property var theme
  // [{ value, language, code, name }] — `language` is "" when there is no flag
  property var options: []
  property string value: "auto"
  property string tooltipText: ""

  signal changed(string value)

  readonly property real rowHeight: Style.spacing.controlHeight
  readonly property real popupWidth: Style.space(190)

  function entry(value) {
    if (!root.options) return null

    for (var i = 0; i < root.options.length; i++)
      if (root.options[i].value === value) return root.options[i]
    return null
  }

  readonly property var current: root.entry(root.value)

  implicitWidth: trigger.implicitWidth
  implicitHeight: root.rowHeight

  BorderSurface {
    id: trigger
    anchors.fill: parent
    implicitWidth: triggerRow.implicitWidth + Style.space(14)
    color: "transparent"
    radius: root.theme.radius
    borderSpec: Border.controlSpec(triggerHover.hovered ? "hover-cursor" : "normal", root.theme.foreground, root.theme.accent)

    Row {
      id: triggerRow
      anchors.centerIn: parent
      spacing: Style.space(5)

      LanguageFlag {
        anchors.verticalCenter: parent.verticalCenter
        language: root.current ? root.current.language : ""
      }

      Text {
        textFormat: Text.PlainText
        anchors.verticalCenter: parent.verticalCenter
        text: root.current ? root.current.code : ""
        color: root.theme.foreground
        font.family: root.theme.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }

      Text {
        textFormat: Text.PlainText
        anchors.verticalCenter: parent.verticalCenter
        text: "\u{F0140}"
        color: root.theme.dim
        font.family: root.theme.fontFamily
        font.pixelSize: Style.font.caption
      }
    }

    HoverHandler { id: triggerHover; cursorShape: Qt.PointingHandCursor }

    MouseArea {
      anchors.fill: parent
      onClicked: popup.opened ? popup.close() : popup.open()
    }

    PanelToolTip {
      visible: root.tooltipText !== "" && triggerHover.hovered && !popup.opened
      text: root.tooltipText
      fontFamily: root.theme.fontFamily
    }
  }

  Popup {
    id: popup
    // The selector sits at the trailing edge, so the list opens inwards to
    // stay inside the panel
    x: trigger.width - root.popupWidth
    y: trigger.height + Style.space(3)
    width: root.popupWidth
    implicitHeight: list.contentHeight + Style.space(6)
    padding: Style.space(3)
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    background: BorderSurface {
      color: Color.popups.background
      borderSpec: Border.localOrSurfaceSpec("popups", "border", Color.popups.border, Color.popups.border, Style.normalBorderWidth)
      radius: root.theme.radius
    }

    contentItem: ListView {
      id: list
      implicitHeight: contentHeight
      interactive: false
      model: root.options

      delegate: Rectangle {
        required property var modelData
        width: list.width
        height: root.rowHeight
        radius: root.theme.radius
        color: rowHover.hovered ? Style.hoverFillFor(root.theme.foreground, root.theme.accent)
          : (modelData.value === root.value ? Util.alpha(root.theme.accent, 0.18) : "transparent")

        Row {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          LanguageFlag {
            anchors.verticalCenter: parent.verticalCenter
            language: modelData.language
          }

          Text {
            textFormat: Text.PlainText
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(34)
            text: modelData.code
            color: root.theme.foreground
            font.family: root.theme.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          Text {
            textFormat: Text.PlainText
            anchors.verticalCenter: parent.verticalCenter
            text: modelData.name
            color: root.theme.dim
            font.family: root.theme.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }
        }

        HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }

        MouseArea {
          anchors.fill: parent
          onClicked: {
            root.changed(modelData.value)
            popup.close()
          }
        }
      }
    }
  }
}
