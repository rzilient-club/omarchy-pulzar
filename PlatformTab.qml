import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Ui
import "Timeline.js" as TimelineJs
import "Format.js" as Format
import "Config.js" as Config

// What only the platform knows: who manages the machine, how it is protected,
// and what has happened to it.
//
// Built from the same pieces as the pulzar tab — SectionCard, InfoRow,
// IconRow, StatusChip — and the same theme, so the two tabs read as one panel
// rather than as two products sharing a window.
//
// Every field here is optional. The payload is compacted server-side, so an
// absent key means nobody has said, which is not the same as false and must
// not be drawn as false. Everything branches on presence.
Flickable {
  id: root

  required property var theme
  required property var t
  property var record: null
  property string message: ""
  property bool signedIn: false
  property bool loading: false

  readonly property var mdm: root.record && root.record.mdm ? root.record.mdm : null
  readonly property var security: root.record && root.record.security ? root.record.security : null
  readonly property var timeline: root.record && root.record.timeline ? root.record.timeline : []
  // The company dropped this MDM: provider and status are still true, so they
  // are drawn down rather than hidden — the machine really is still enrolled
  // in something nobody is running any more
  readonly property bool mdmDropped: root.has(root.mdm, "configured") && !root.mdm.configured

  function has(object, key) {
    return !!object && object[key] !== undefined && object[key] !== null
  }

  function yesNo(value) { return value ? root.t.yes : root.t.no }
  function boolTone(value) { return value ? "success" : "error" }

  contentWidth: width
  contentHeight: column.implicitHeight
  clip: true
  boundsBehavior: Flickable.StopAtBounds
  flickableDirection: Flickable.VerticalFlick
  interactive: contentHeight > height
  ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

  Column {
    id: column
    width: root.width - (root.interactive ? Style.space(8) : 0)
    spacing: Style.space(14)

    // ---------- Nothing to show ----------
    Text {
      textFormat: Text.PlainText
      visible: !root.record
      width: parent.width
      wrapMode: Text.WordWrap
      horizontalAlignment: Text.AlignHCenter
      text: {
        if (!root.signedIn) return root.t.signInToSeeDevice
        if (root.loading) return root.t.lookingUpDevice
        // The platform's own words: one message covers a serial it does not
        // know, someone else's machine and an unassigned one alike, and
        // rewording it would invent a certainty it did not express
        if (root.message !== "") return root.message
        return root.t.nothingFromPlatform
      }
      color: root.theme.dim
      font.family: root.theme.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    // ---------- The device ----------
    SectionCard {
      visible: !!root.record
      theme: root.theme
      title: root.t.platformDevice

      IconRow {
        theme: root.theme
        icon: "\u{F0322}"
        tone: "secondary"
        title: root.record
          ? ([root.record.brand, root.record.model].filter(Boolean).join(" ")
             || root.record.device_name || "")
          : ""
        caption: root.record ? String(root.record.serial_number || "") : ""
        chipText: root.record ? String(root.record.status || "") : ""
        chipTone: "success"
      }

      InfoRow {
        visible: !!root.record && !!root.record.assigned_to
        theme: root.theme
        label: root.t.assignedTo
        value: root.record && root.record.assigned_to
          ? (root.record.assigned_to.name || root.record.assigned_to.email || "") : ""
      }

      InfoRow {
        visible: root.has(root.record, "category")
        theme: root.theme
        label: root.t.deviceCategory
        value: root.record ? String(root.record.category || "") : ""
      }

      InfoRow {
        visible: root.has(root.record, "purchase_year")
        theme: root.theme
        label: root.t.purchaseYear
        value: root.record ? String(root.record.purchase_year || "") : ""
      }

      InfoRow {
        visible: !!root.record && !!root.record.tags && root.record.tags.length > 0
        theme: root.theme
        label: root.t.deviceTags
        value: root.record && root.record.tags ? root.record.tags.join(", ") : ""
      }

      PanelSectionHeader {
        visible: !!root.record && !!root.record.orders && root.record.orders.length > 0
        text: root.t.recentOrders.toUpperCase()
        foreground: root.theme.foreground
        fontFamily: root.theme.fontFamily
      }

      Repeater {
        model: root.record && root.record.orders ? root.record.orders : []

        InfoRow {
          required property var modelData
          theme: root.theme
          label: modelData.reference || ""
          value: [modelData.status, modelData.created_on].filter(Boolean).join(" · ")
        }
      }
    }

    // ---------- Device management ----------
    SectionCard {
      visible: !!root.mdm
      theme: root.theme
      title: root.t.deviceManagement

      Item {
        width: parent.width
        implicitHeight: Math.max(logo.height, mdmName.implicitHeight)
        opacity: root.mdmDropped ? 0.55 : 1

        // A path rather than a URL on purpose: the full one would be a signed
        // link with a lifetime of its own
        Image {
          id: logo
          visible: root.has(root.mdm, "logo_path") && status === Image.Ready
          width: Style.font.icon
          height: Style.font.icon
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          fillMode: Image.PreserveAspectFit
          source: root.has(root.mdm, "logo_path") ? Config.ISSUER + root.mdm.logo_path : ""
        }

        Text {
          id: mdmName
          textFormat: Text.PlainText
          anchors.left: logo.visible ? logo.right : parent.left
          anchors.leftMargin: logo.visible ? Style.space(8) : 0
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          elide: Text.ElideRight
          text: root.mdm ? (root.mdm.name || root.mdm.provider || "") : ""
          color: root.theme.foreground
          font.family: root.theme.fontFamily
          font.pixelSize: Style.font.bodySmall
          font.bold: true
        }
      }

      Text {
        textFormat: Text.PlainText
        visible: root.mdmDropped
        width: parent.width
        wrapMode: Text.WordWrap
        text: root.t.mdmNotConfigured
        color: root.theme.dim
        font.family: root.theme.fontFamily
        font.pixelSize: Style.font.caption
      }

      InfoRow {
        visible: root.has(root.mdm, "status")
        opacity: root.mdmDropped ? 0.55 : 1
        theme: root.theme
        label: root.t.mdmStatus
        value: root.mdm ? String(root.mdm.status || "") : ""
      }

      InfoRow {
        visible: root.has(root.mdm, "enrolled")
        opacity: root.mdmDropped ? 0.55 : 1
        theme: root.theme
        label: root.t.mdmEnrolled
        value: root.mdm ? root.yesNo(root.mdm.enrolled) : ""
        tone: root.mdm ? root.boolTone(root.mdm.enrolled) : ""
      }

      InfoRow {
        visible: root.has(root.mdm, "online")
        theme: root.theme
        label: root.t.mdmOnline
        value: root.mdm ? root.yesNo(root.mdm.online) : ""
        tone: root.mdm ? root.boolTone(root.mdm.online) : ""
      }

      InfoRow {
        visible: root.has(root.mdm, "dual_enrolment")
        theme: root.theme
        label: root.t.mdmDualEnrolment
        value: root.mdm ? root.yesNo(root.mdm.dual_enrolment) : ""
        // Two MDMs on one machine is a problem, not an achievement
        tone: root.mdm && root.mdm.dual_enrolment ? "warning" : "success"
      }
    }

    // ---------- Security ----------
    // Absent for a non-computer category, and absent again when the MDM could
    // not be reached, so the card simply does not appear
    SectionCard {
      visible: !!root.security
      theme: root.theme
      title: root.t.securityPosture

      InfoRow {
        visible: root.has(root.security, "score")
        theme: root.theme
        label: root.t.securityScore
        value: root.security ? String(root.security.score || "") : ""
      }

      InfoRow {
        visible: root.has(root.security, "scan")
        theme: root.theme
        label: root.t.securityScan
        value: root.security ? root.yesNo(root.security.scan) : ""
        tone: root.security ? root.boolTone(root.security.scan) : ""
      }

      InfoRow {
        visible: !!root.security && !!root.security.antivirus
        theme: root.theme
        label: root.t.antivirus
        value: root.security && root.security.antivirus
          ? [root.security.antivirus.name, root.security.antivirus.version].filter(Boolean).join(" ") : ""
        trailing: antivirusChip
      }

      // Two fields for one fact, deliberately: the connectors disagree on the
      // type. Some answer a real boolean, others a vendor string such as
      // ENCRYPTED_PARTIALLY_PROTECTED. The boolean becomes a chip; the string
      // is shown as written, because mapping vendor strings onto true or false
      // is a decision nobody has made and guessing it here would quietly
      // answer a question about whether a disk is protected.
      InfoRow {
        visible: root.has(root.security, "encrypted")
        theme: root.theme
        label: root.t.encryptionState
        value: root.security ? root.yesNo(root.security.encrypted) : ""
        tone: root.security ? root.boolTone(root.security.encrypted) : ""
      }

      InfoRow {
        visible: !root.has(root.security, "encrypted")
          && root.has(root.security, "encryption_status")
        theme: root.theme
        label: root.t.encryptionState
        value: root.security ? String(root.security.encryption_status || "") : ""
      }

      InfoRow {
        visible: root.has(root.security, "encryption_method")
        theme: root.theme
        label: root.t.encryptionMethod
        value: root.security ? String(root.security.encryption_method || "") : ""
      }

      // Whether a recovery key is escrowed, and nothing more. The key itself is
      // never in this payload and is never asked for from here: it sits behind
      // a role-gated, audited endpoint.
      InfoRow {
        visible: root.has(root.security, "recovery_escrowed")
        theme: root.theme
        label: root.t.recoveryEscrowed
        value: root.security ? root.yesNo(root.security.recovery_escrowed) : ""
        tone: root.security ? root.boolTone(root.security.recovery_escrowed) : ""
      }

      InfoRow {
        visible: root.has(root.security, "device_enrollment_program")
        theme: root.theme
        label: root.t.enrollmentProgram
        value: root.security ? root.yesNo(root.security.device_enrollment_program) : ""
        tone: root.security && root.security.device_enrollment_program ? "success" : "secondary"
      }

      InfoRow {
        visible: root.has(root.security, "pulzar_enrolled")
        theme: root.theme
        label: root.t.agentEnrolled
        value: root.security ? root.yesNo(root.security.pulzar_enrolled) : ""
        tone: root.security ? root.boolTone(root.security.pulzar_enrolled) : ""
      }
    }

    // ---------- Lifecycle ----------
    SectionCard {
      visible: root.timeline.length > 0
      theme: root.theme
      title: root.t.lifecycle

      Repeater {
        model: root.timeline

        TimelineRow {
          required property var modelData
          required property int index

          readonly property var look: TimelineJs.appearance(modelData.action)

          theme: root.theme
          icon: look.icon
          tone: look.tone
          headline: modelData.headline || ""
          // The dashboard formats these fr-FR whatever the reader's language,
          // which is a bug there rather than a spec to copy
          date: Format.formatDateTime(modelData.at, root.t)
          last: index === root.timeline.length - 1
        }
      }
    }
  }

  Component {
    id: antivirusChip

    StatusChip {
      theme: root.theme
      tone: root.security && root.security.antivirus
        ? root.boolTone(root.security.antivirus.active) : "default"
      text: root.security && root.security.antivirus
        && root.security.antivirus.active !== undefined
        ? root.yesNo(root.security.antivirus.active) : ""
    }
  }
}
