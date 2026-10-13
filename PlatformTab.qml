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
// Every field here is optional. The payload is compacted server-side, so an
// absent key means nobody has said — which is not the same as false, and must
// not be drawn as false. Everything branches on presence.
Flickable {
  id: root

  required property var dash
  required property var t
  property var record: null
  property string message: ""
  property bool signedIn: false
  property bool loading: false

  readonly property var mdm: root.record && root.record.mdm ? root.record.mdm : null
  readonly property var security: root.record && root.record.security ? root.record.security : null
  readonly property var timeline: root.record && root.record.timeline ? root.record.timeline : []

  function has(object, key) {
    return !!object && object[key] !== undefined && object[key] !== null
  }

  function yesNo(value) {
    return value ? root.t.yes : root.t.no
  }

  function boolTone(value) {
    return value ? "success" : "error"
  }

  contentWidth: width
  contentHeight: column.implicitHeight
  clip: true
  boundsBehavior: Flickable.StopAtBounds
  ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

  Column {
    id: column
    width: root.width
    spacing: root.dash.space(16)

    // ---------- Nothing to show ----------
    Text {
      textFormat: Text.PlainText
      visible: !root.record
      width: parent.width
      wrapMode: Text.WordWrap
      text: {
        if (!root.signedIn) return root.t.signInToSeeDevice
        if (root.loading) return root.t.lookingUpDevice
        // The platform's own words, passed through: one message covers a
        // serial it does not know, someone else's machine and an unassigned
        // one alike, and rewording it would invent a certainty
        if (root.message !== "") return root.message
        return root.t.nothingFromPlatform
      }
      color: root.dash.textSecondary
      font.family: root.dash.fontFamily
      font.pixelSize: root.dash.sizeBody
    }

    // ---------- The device itself ----------
    // Not one of the three sections asked for, but this is the subject of the
    // tab and it is platform data: it cannot stay on the local tab, which must
    // not trigger a fetch. Placed first because the rest describes it.
    DashCard {
      visible: !!root.record
      dash: root.dash
      title: root.t.platformDevice

      Text {
        textFormat: Text.PlainText
        width: parent.width
        elide: Text.ElideRight
        text: root.record
          ? ([root.record.brand, root.record.model].filter(Boolean).join(" ")
             || root.record.device_name || "")
          : ""
        color: root.dash.text
        font.family: root.dash.fontFamily
        font.pixelSize: root.dash.sizeHeader
        font.weight: Font.DemiBold
      }

      DashRow {
        visible: root.has(root.record, "serial_number")
        dash: root.dash
        label: root.t.serialNumber
        value: root.record ? String(root.record.serial_number || "") : ""
      }

      DashRow {
        visible: !!root.record && !!root.record.assigned_to
        dash: root.dash
        label: root.t.assignedTo
        value: root.record && root.record.assigned_to
          ? (root.record.assigned_to.name || root.record.assigned_to.email || "") : ""
      }

      DashRow {
        visible: root.has(root.record, "category")
        dash: root.dash
        label: root.t.deviceCategory
        value: root.record ? String(root.record.category || "") : ""
      }

      DashRow {
        visible: root.has(root.record, "status")
        dash: root.dash
        label: root.t.deviceStatus
        chipText: root.record ? String(root.record.status || "") : ""
        chipTone: "success"
      }

      DashRow {
        visible: root.has(root.record, "purchase_year")
        dash: root.dash
        label: root.t.purchaseYear
        value: root.record ? String(root.record.purchase_year || "") : ""
      }

      DashRow {
        visible: !!root.record && !!root.record.tags && root.record.tags.length > 0
        dash: root.dash
        label: root.t.deviceTags
        value: root.record && root.record.tags ? root.record.tags.join(", ") : ""
      }

      Text {
        textFormat: Text.PlainText
        visible: !!root.record && !!root.record.orders && root.record.orders.length > 0
        width: parent.width
        text: root.t.recentOrders
        color: root.dash.textSecondary
        font.family: root.dash.fontFamily
        font.pixelSize: root.dash.sizeCaption
        font.weight: Font.DemiBold
      }

      Repeater {
        model: root.record && root.record.orders ? root.record.orders : []

        DashRow {
          required property var modelData
          dash: root.dash
          label: modelData.reference || ""
          value: [modelData.status, modelData.created_on].filter(Boolean).join(" · ")
        }
      }
    }

    // ---------- Device management ----------
    DashCard {
      visible: !!root.mdm
      dash: root.dash
      title: root.t.deviceManagement

      Row {
        width: parent.width
        spacing: root.dash.space(12)

        // A path rather than a URL on purpose: the full one would be a signed
        // link with a lifetime of its own
        Image {
          visible: root.has(root.mdm, "logo_path")
          width: root.dash.space(40)
          height: root.dash.space(40)
          fillMode: Image.PreserveAspectFit
          source: root.has(root.mdm, "logo_path")
            ? Config.ISSUER + root.mdm.logo_path : ""
          // A logo that will not load is not worth an error box
          onStatusChanged: if (status === Image.Error) visible = false
        }

        Column {
          width: parent.width - (root.dash.space(52))
          spacing: root.dash.space(2)

          Text {
            textFormat: Text.PlainText
            width: parent.width
            elide: Text.ElideRight
            text: root.mdm ? (root.mdm.name || root.mdm.provider || "") : ""
            color: root.dash.text
            font.family: root.dash.fontFamily
            font.pixelSize: root.dash.sizeBody
            font.weight: Font.DemiBold
          }

          // The company dropped this MDM. Provider and status remain true, so
          // they are drawn muted rather than hidden — the machine really is
          // still enrolled in something nobody is running any more.
          Text {
            textFormat: Text.PlainText
            visible: root.has(root.mdm, "configured") && !root.mdm.configured
            width: parent.width
            wrapMode: Text.WordWrap
            text: root.t.mdmNotConfigured
            color: root.dash.textSecondary
            font.family: root.dash.fontFamily
            font.pixelSize: root.dash.sizeCaption
          }
        }
      }

      DashRow {
        visible: root.has(root.mdm, "status")
        dash: root.dash
        label: root.t.mdmStatus
        value: root.mdm ? String(root.mdm.status || "") : ""
        muted: root.has(root.mdm, "configured") && !root.mdm.configured
      }

      DashRow {
        visible: root.has(root.mdm, "enrolled")
        dash: root.dash
        label: root.t.mdmEnrolled
        chipText: root.mdm ? root.yesNo(root.mdm.enrolled) : ""
        chipTone: root.mdm ? root.boolTone(root.mdm.enrolled) : "secondary"
        muted: root.has(root.mdm, "configured") && !root.mdm.configured
      }

      DashRow {
        visible: root.has(root.mdm, "online")
        dash: root.dash
        label: root.t.mdmOnline
        chipText: root.mdm ? root.yesNo(root.mdm.online) : ""
        chipTone: root.mdm ? root.boolTone(root.mdm.online) : "secondary"
      }

      DashRow {
        visible: root.has(root.mdm, "dual_enrolment")
        dash: root.dash
        label: root.t.mdmDualEnrolment
        chipText: root.mdm ? root.yesNo(root.mdm.dual_enrolment) : ""
        // Two MDMs on one machine is a problem, not an achievement
        chipTone: root.mdm && root.mdm.dual_enrolment ? "warning" : "success"
      }
    }

    // ---------- Security ----------
    // Absent for a non-computer category, and absent again when the MDM could
    // not be reached, so the card simply does not appear
    DashCard {
      visible: !!root.security
      dash: root.dash
      title: root.t.securityPosture

      DashRow {
        visible: root.has(root.security, "score")
        dash: root.dash
        label: root.t.securityScore
        value: root.security ? String(root.security.score || "") : ""
      }

      DashRow {
        visible: root.has(root.security, "scan")
        dash: root.dash
        label: root.t.securityScan
        chipText: root.security ? root.yesNo(root.security.scan) : ""
        chipTone: root.security ? root.boolTone(root.security.scan) : "secondary"
      }

      DashRow {
        visible: !!root.security && !!root.security.antivirus
        dash: root.dash
        label: root.t.antivirus
        value: root.security && root.security.antivirus
          ? [root.security.antivirus.name, root.security.antivirus.version].filter(Boolean).join(" ") : ""
        chipText: root.security && root.security.antivirus
          && root.security.antivirus.active !== undefined
          ? root.yesNo(root.security.antivirus.active) : ""
        chipTone: root.security && root.security.antivirus
          ? root.boolTone(root.security.antivirus.active) : "secondary"
      }

      // Two fields for one fact, and that is deliberate: the connectors
      // disagree on the type. Some answer a real boolean, others a vendor
      // string like ENCRYPTED_PARTIALLY_PROTECTED. The boolean becomes a chip;
      // the string is shown as written, because mapping vendor strings onto
      // true or false is a decision nobody has made yet and guessing it here
      // would quietly answer a question about whether a disk is protected.
      DashRow {
        visible: root.has(root.security, "encrypted")
        dash: root.dash
        label: root.t.encryptionState
        chipText: root.security ? root.yesNo(root.security.encrypted) : ""
        chipTone: root.security ? root.boolTone(root.security.encrypted) : "secondary"
      }

      DashRow {
        visible: !root.has(root.security, "encrypted")
          && root.has(root.security, "encryption_status")
        dash: root.dash
        label: root.t.encryptionState
        value: root.security ? String(root.security.encryption_status || "") : ""
      }

      DashRow {
        visible: root.has(root.security, "encryption_method")
        dash: root.dash
        label: root.t.encryptionMethod
        value: root.security ? String(root.security.encryption_method || "") : ""
      }

      // Whether a recovery key is escrowed, and nothing more. The key itself
      // is never in this payload and is never asked for from here: it sits
      // behind a role-gated, audited endpoint for managers.
      DashRow {
        visible: root.has(root.security, "recovery_escrowed")
        dash: root.dash
        label: root.t.recoveryEscrowed
        chipText: root.security ? root.yesNo(root.security.recovery_escrowed) : ""
        chipTone: root.security ? root.boolTone(root.security.recovery_escrowed) : "secondary"
      }

      DashRow {
        visible: root.has(root.security, "device_enrollment_program")
        dash: root.dash
        label: root.t.enrollmentProgram
        chipText: root.security ? root.yesNo(root.security.device_enrollment_program) : ""
        chipTone: root.security && root.security.device_enrollment_program ? "success" : "secondary"
      }

      DashRow {
        visible: root.has(root.security, "pulzar_enrolled")
        dash: root.dash
        label: root.t.agentEnrolled
        chipText: root.security ? root.yesNo(root.security.pulzar_enrolled) : ""
        chipTone: root.security ? root.boolTone(root.security.pulzar_enrolled) : "secondary"
      }
    }

    // ---------- Lifecycle ----------
    DashCard {
      visible: root.timeline.length > 0
      dash: root.dash
      title: root.t.lifecycle

      Repeater {
        model: root.timeline

        TimelineRow {
          required property var modelData
          required property int index

          readonly property var look: TimelineJs.appearance(modelData.action)

          dash: root.dash
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
}
