import QtQuick
import qs.Commons

// The flag of a language, in a box every language shares so a row of them
// lines up. English, Spanish and French are emoji, which Noto Color Emoji
// draws. Catalan has no flag in Unicode: the ES-CT tag sequence is well
// formed but outside the recommended set, so the font answers it with an
// empty box. The Senyera is drawn instead.
Item {
  id: root

  // "en", "es", "fr", "ca", or "" for no flag at all
  property string language: ""
  property real boxWidth: Style.space(19)

  readonly property var emoji: ({
    en: "\u{1F1EC}\u{1F1E7}",
    es: "\u{1F1EA}\u{1F1F8}",
    fr: "\u{1F1EB}\u{1F1F7}"
  })

  // The drawn flag takes the height the font gives the emoji ones, measured
  // rather than guessed, so a column of flags lines up whatever font answers
  readonly property real flagHeight: reference.paintedHeight > 0 ? reference.paintedHeight : root.boxWidth * 0.72

  implicitWidth: root.boxWidth
  implicitHeight: root.flagHeight

  Text {
    id: reference
    visible: false
    text: root.emoji.es
    font.pixelSize: root.boxWidth
  }

  Text {
    anchors.centerIn: parent
    visible: !!root.emoji[root.language]
    text: root.emoji[root.language] || ""
    font.pixelSize: root.boxWidth
  }

  // The Senyera: four red stripes on yellow, nine bands in all
  Rectangle {
    anchors.centerIn: parent
    visible: root.language === "ca"
    width: root.boxWidth
    height: root.flagHeight
    // The emoji flags are drawn with a hairline rounding; matching it keeps
    // the one flag that is drawn from looking like a different kind of object
    radius: 1
    clip: true
    color: "#fcdd09"

    Repeater {
      model: 4

      Rectangle {
        required property int index
        width: parent.width
        height: parent.height / 9
        y: height * (index * 2 + 1)
        color: "#da121a"
      }
    }
  }
}
