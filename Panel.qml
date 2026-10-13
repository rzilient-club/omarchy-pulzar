import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Snapshot.js" as Snapshot
import "Format.js" as Format
import "Locales.js" as Locales

// Pulzar in the Omarchy bar: the device status panel of the tray application
// in QML. A glyph in the bar, tinted by the state of the
// agent, opens the latest data collected on this device.
Panel {
  id: pulzar
  moduleName: "rzilient.pulzar"
  ipcTarget: moduleName
  manageIpc: false

  readonly property string iconPulse: "\u{F05F6}"
  readonly property string iconRefresh: "\u{F0450}"
  readonly property string iconCopy: "\u{F018F}"
  readonly property string iconCopied: "\u{F05E0}"
  readonly property string iconLaptop: "\u{F0322}"
  readonly property string iconMemory: "\u{F035B}"
  readonly property string iconStorage: "\u{F02CA}"
  readonly property string iconBattery: "\u{F0084}"
  readonly property string iconNoBattery: "\u{F008E}"
  readonly property string iconMonitor: "\u{F0379}"
  readonly property string iconSearch: "\u{F0349}"
  readonly property string iconAlert: "\u{F05D6}"
  readonly property string iconLock: "\u{F033E}"
  // A gauge, not a chip: the memory meter beside it already wears the chip
  readonly property string iconProcessor: "\u{F04C5}"
  readonly property string iconSwap: "\u{F04E1}"
  readonly property string iconNetwork: "\u{F0317}"

  // Arch's own page on dm-crypt: the distribution this runs on, and the only
  // instructions that cover converting a partition that is already in use
  // The serial the platform knows this machine by. A literal for now, by
  // Eduard's decision: the real source is pulzar.status.device.serial, which
  // reads empty on this machine because the vendor left the DMI template and
  // Snapshot.js reports a placeholder as no value at all. Swapping this for
  // that line is the whole change once a machine reports a real serial.
  readonly property string platformSerial: "39P70Y2"

  readonly property string encryptionGuideUrl: "https://wiki.archlinux.org/title/Dm-crypt/Device_encryption#Encrypt_an_existing_unencrypted_file_system"

  // Feedback of the copy button
  readonly property int copiedFeedbackMs: 2200

  readonly property var t: telemetry.t
  readonly property var status: telemetry.status
  // The agent cannot see LUKS, so the probe in Telemetry decides whenever it
  // has an answer and the reported flag is only a fallback
  readonly property var encrypted: telemetry.diskEncryptionKnown
    ? telemetry.diskEncrypted
    : (pulzar.computer ? pulzar.computer.encrypted : undefined)

  readonly property var summary: Format.statusSummary(pulzar.status, telemetry.isError, pulzar.t)
  // The languages for the header selector: the automatic choice first, wearing
  // the flag of whatever it resolved to so the effect of "auto" is visible
  readonly property var languageOptions: [{
    value: "auto",
    language: telemetry.systemLanguage,
    // The code column holds short codes; "automatic" spelled out in any of the
    // four languages would not fit beside EN, ES, CA and FR
    code: "AUTO",
    name: pulzar.t.languageAuto
  }].concat(Locales.languageOptions.map(function(option) {
    return { value: option.id, language: option.id, code: option.short, name: option.name }
  }))

  // What the summary card used to spell out, now shown on hovering the light
  readonly property string summaryTooltip: [pulzar.summary.label, pulzar.summary.title, pulzar.summary.detail]
    .filter(function(line) { return !!line }).join("\n")
  readonly property var battery: pulzar.status ? pulzar.status.hardware.battery : undefined
  readonly property var computer: pulzar.status ? pulzar.status.computer : undefined

  property bool copied: false
  property bool linkCopied: false
  property bool encryptionWarning: false
  property string programSearch: ""
  property string programQuery: ""

  function copySupport() {
    if (!telemetry.hasData) return
    Quickshell.execDetached(["wl-copy", "--", Format.supportInformation(pulzar.status, pulzar.t, pulzar.encrypted)])
    pulzar.copied = true
    copiedTimer.restart()
  }

  function copySignInLink() {
    if (session.consentUrl === "") return
    Quickshell.execDetached(["wl-copy", "--", session.consentUrl])
    pulzar.linkCopied = true
    linkCopiedTimer.restart()
  }

  function refresh() {
    telemetry.refresh()
  }

  // The button never encrypts anything: converting a mounted root is not
  // something a panel can do, and the steps belong in front of the user
  // before any of them is run
  function openEncryptionGuide() {
    pulzar.encryptionWarning = false
    Quickshell.execDetached(["xdg-open", pulzar.encryptionGuideUrl])
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) {
    // A warning left standing from a previous visit must not greet the user
    pulzar.encryptionWarning = false
    telemetry.refresh()
    if (panelFlick) panelFlick.contentY = 0
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  Telemetry {
    id: telemetry
    snapshotPath: pulzar.setting("snapshotPath", "") || Snapshot.DEFAULT_PATH
    refreshIntervalSec: pulzar.setting("refreshIntervalSec", 5)
  }

  Connections {
    target: session
    function onChanged() {
      // One lookup per sign-in: the record only changes when the session does
      if (session.signedIn && !session.deviceLooked && !session.busy)
        session.lookUpDevice(pulzar.platformSerial)
    }
  }

  Session {
    id: session
    // A setting overrides the shipped value; no setting leaves the shipped
    // value alone. Passing pulzar.setting(name, "") straight through would
    // hand down an empty string on a fresh install, which is a value and wins,
    // so the panel would report itself unconfigured with a client id sitting
    // unused one file away. An install that points at staging sets all three.
    clientId: pulzar.setting("clientId", "") || session.defaultClientId
    issuer: pulzar.setting("issuer", "") || session.defaultIssuer
    consentOrigin: pulzar.setting("consentOrigin", "") || session.defaultConsentOrigin
  }

  Theme {
    id: tones
    bar: pulzar.bar
  }

  Component {
    id: lockButton

    PanelActionButton {
      radius: tones.radius
      iconText: pulzar.iconLock
      tooltipText: pulzar.t.encryptThisDisk
      foreground: tones.foreground
      fontFamily: tones.fontFamily
      onClicked: pulzar.encryptionWarning = true
    }
  }

  Timer {
    id: linkCopiedTimer
    interval: pulzar.copiedFeedbackMs
    onTriggered: pulzar.linkCopied = false
  }

  Timer {
    id: copiedTimer
    interval: pulzar.copiedFeedbackMs
    onTriggered: pulzar.copied = false
  }

  Timer {
    id: searchDebounce
    interval: 150
    onTriggered: pulzar.programQuery = pulzar.programSearch
  }

  IpcHandler {
    target: pulzar.ipcTarget
    function open(): void { pulzar.open() }
    function close(): void { pulzar.close() }
    function show(): void { pulzar.open() }
    function hide(): void { pulzar.close() }
    function toggle(): void { pulzar.toggle() }
    function refresh(): string { pulzar.refresh(); return "ok" }
    function status(): string { return pulzar.status ? pulzar.status.availability : "unknown" }
    function support(): string { return pulzar.status ? Format.supportInformation(pulzar.status, pulzar.t, pulzar.encrypted) : "" }
    function language(value: string): string { telemetry.setLanguage(value); return telemetry.languageChoice }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: pulzar.bar
    text: pulzar.iconPulse
    foreground: {
      if (telemetry.isError) return tones.error
      switch (pulzar.status ? pulzar.status.availability : "") {
      case "active": return pulzar.barForeground
      case "stale": return tones.warning
      case "stopped": return tones.error
      default: return Qt.darker(pulzar.barForeground, 1.55)
      }
    }
    tooltipText: "Pulzar · " + pulzar.summary.label
    onPressed: function(code) {
      if (code === Qt.RightButton) pulzar.refresh()
      else pulzar.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: pulzar
    bar: pulzar.bar
    open: pulzar.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight + footer.implicitHeight + Style.space(12), Style.space(760))

    ConfirmDialog {
      id: encryptionDialog
      anchors.fill: parent
      opened: pulzar.encryptionWarning
      message: pulzar.t.encryptWarning
      cancelText: pulzar.t.encryptCancel
      confirmText: pulzar.t.encryptOpenGuide
      cornerRadius: tones.radius
      foreground: tones.foreground
      fontFamily: tones.fontFamily
      onCanceled: pulzar.encryptionWarning = false
      onConfirmed: pulzar.openEncryptionGuide()
    }

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: {
        // Escape dismisses the warning first, the panel only once it is gone
        if (pulzar.encryptionWarning) pulzar.encryptionWarning = false
        else pulzar.close()
      }
      onTabRequested: function(direction) { pulzar.switchPanel(direction) }
      onTextKey: function(key) {
        // The shortcuts must not fire behind the warning
        if (pulzar.encryptionWarning) return
        if (key === "r" || key === "R") pulzar.refresh()
        else if (key === "c" || key === "C") pulzar.copySupport()
        else if (key === "/") searchField.forceActiveFocus()
      }

      Flickable {
        id: panelFlick
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: footer.top
        anchors.bottomMargin: Style.space(12)
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width - (panelFlick.interactive ? Style.space(8) : 0)
          spacing: Style.space(14)

          // ---------- Header ----------
          PanelHero {
            width: parent.width
            title: "Pulzar"
            meta: pulzar.t.productSubtitle
            foreground: tones.foreground
            fontFamily: tones.fontFamily
            iconComponent: Component {
              StatusDot {
                theme: tones
                tone: pulzar.summary.tone
                tooltipText: pulzar.summaryTooltip
              }
            }
            trailingControl: Component {
              Row {
                spacing: Style.space(6)

                LanguagePicker {
                  anchors.verticalCenter: parent.verticalCenter
                  theme: tones
                  options: pulzar.languageOptions
                  value: telemetry.languageChoice
                  tooltipText: pulzar.t.chooseLanguage
                  onChanged: function(value) { telemetry.setLanguage(value) }
                }

                PanelActionButton {
                  anchors.verticalCenter: parent.verticalCenter
                  radius: tones.radius
                  iconText: pulzar.iconRefresh
                  tooltipText: pulzar.t.refresh
                  foreground: tones.foreground
                  fontFamily: tones.fontFamily
                  onClicked: pulzar.refresh()
                }
              }
            }
          }

          // ---------- Without data ----------
          Column {
            visible: !telemetry.hasData
            width: parent.width
            spacing: Style.space(8)

            Text {
              textFormat: Text.PlainText
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.WordWrap
              text: telemetry.isError ? pulzar.t.dataUnavailable : (telemetry.isPending ? pulzar.t.readingDevice : pulzar.t.agentWaiting)
              color: tones.foreground
              font.family: tones.fontFamily
              font.pixelSize: Style.font.body
              font.bold: true
            }

            Text {
              textFormat: Text.PlainText
              visible: !telemetry.isError
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.WordWrap
              text: pulzar.t.collectionHint
              color: tones.dim
              font.family: tones.fontFamily
              font.pixelSize: Style.font.caption
            }

            Button {
              visible: telemetry.isError
              anchors.horizontalCenter: parent.horizontalCenter
              radius: tones.radius
              text: pulzar.t.retry
              iconText: pulzar.iconRefresh
              fontSize: Style.font.bodySmall
              foreground: tones.foreground
              fontFamily: tones.fontFamily
              bordered: true
              onClicked: pulzar.refresh()
            }
          }

          // ---------- Device ----------
          SectionCard {
            visible: telemetry.hasData
            theme: tones
            title: pulzar.t.device

            IconRow {
              theme: tones
              icon: pulzar.iconLaptop
              tone: "secondary"
              title: pulzar.status ? (pulzar.status.device.name || pulzar.t.unknownDeviceName) : ""
              caption: pulzar.status ? (pulzar.status.device.serial || pulzar.t.unknownSerial) : ""
              chipText: pulzar.t.agent
              chipTone: "success"
            }
          }

          // ---------- Usage ----------
          SectionCard {
            visible: telemetry.hasData
            theme: tones
            title: pulzar.t.usage

            Grid {
              id: meters
              width: parent.width
              columns: 2
              spacing: Style.space(10)

              readonly property real cellWidth: (meters.width - meters.spacing) / 2
              readonly property var hardware: pulzar.status ? pulzar.status.hardware : null

              UsageMeter {
                width: meters.cellWidth
                theme: tones
                t: pulzar.t
                label: pulzar.t.processor
                icon: pulzar.iconProcessor
                // The agent reports the percentage; there are no bytes here, so
                // the two lines of the meter are given rather than derived
                reportedPercent: meters.hardware && meters.hardware.cpuUsedPercent !== undefined
                  ? meters.hardware.cpuUsedPercent : -1
                valueText: meters.hardware && meters.hardware.cpuUsedPercent !== undefined
                  ? Math.round(meters.hardware.cpuUsedPercent) + "%" : ""
                totalText: meters.hardware && meters.hardware.cpuLoad
                  ? pulzar.t.loadAverage + " " + meters.hardware.cpuLoad.map(Format.formatLoad).join(" · ") : ""
              }

              UsageMeter {
                width: meters.cellWidth
                theme: tones
                t: pulzar.t
                label: pulzar.t.memory
                icon: pulzar.iconMemory
                used: meters.hardware ? meters.hardware.ramUsedBytes : 0
                total: meters.hardware ? meters.hardware.ramTotalBytes : 0
              }

              UsageMeter {
                width: meters.cellWidth
                theme: tones
                t: pulzar.t
                label: pulzar.t.storage
                icon: pulzar.iconStorage
                used: meters.hardware ? meters.hardware.storageUsedBytes : 0
                total: meters.hardware ? meters.hardware.storageTotalBytes : 0
              }

              UsageMeter {
                // A machine without swap reports no total and gets no meter
                visible: !!meters.hardware && !!meters.hardware.swapTotalBytes
                width: meters.cellWidth
                theme: tones
                t: pulzar.t
                label: pulzar.t.swap
                icon: pulzar.iconSwap
                used: meters.hardware ? (meters.hardware.swapUsedBytes || 0) : 0
                total: meters.hardware ? (meters.hardware.swapTotalBytes || 0) : 0
              }
            }
          }

          // ---------- Battery ----------
          SectionCard {
            id: batteryCard
            visible: telemetry.hasData
            theme: tones
            title: pulzar.t.battery

            readonly property var assessment: Format.batteryAssessment(pulzar.battery ? pulzar.battery.condition : undefined, pulzar.t)

            IconRow {
              theme: tones
              icon: pulzar.battery ? pulzar.iconBattery : pulzar.iconNoBattery
              tone: pulzar.battery ? batteryCard.assessment.tone : "default"
              title: pulzar.battery ? batteryCard.assessment.label : pulzar.t.noBattery
              caption: pulzar.battery ? batteryCard.assessment.message : ""
            }

            InfoRow {
              visible: !!pulzar.battery
              theme: tones
              label: pulzar.t.currentCharge
              value: Format.formatPercent(pulzar.battery ? pulzar.battery.chargePercent : undefined, pulzar.t)
            }

            InfoRow {
              visible: !!pulzar.battery
              theme: tones
              label: pulzar.t.health
              value: Format.formatPercent(pulzar.battery ? pulzar.battery.healthPercent : undefined, pulzar.t)
              tone: batteryCard.assessment.tone
            }
          }

          // ---------- Computer ----------
          SectionCard {
            visible: telemetry.hasData
            theme: tones
            title: pulzar.t.computer
            subheader: pulzar.t.computerSubtitle

            Text {
              textFormat: Text.PlainText
              visible: !pulzar.computer
              width: parent.width
              wrapMode: Text.WordWrap
              text: pulzar.t.computerPending
              color: tones.dim
              font.family: tones.fontFamily
              font.pixelSize: Style.font.bodySmall
            }

            Column {
              visible: !!pulzar.computer
              width: parent.width
              spacing: Style.space(4)

              IconRow {
                theme: tones
                icon: pulzar.iconMonitor
                tone: "info"
                title: pulzar.computer ? Format.operatingSystemLabel(pulzar.computer, pulzar.t) : ""
                caption: pulzar.computer
                  ? pulzar.t.osVersion + " " + (pulzar.computer.version || pulzar.t.unknown) + " · " + (pulzar.computer.architecture || pulzar.t.unknown)
                  : ""
              }

              PanelSeparator { foreground: tones.foreground }

              InfoRow { theme: tones; label: pulzar.t.osFamily; value: pulzar.computer ? (pulzar.computer.family || pulzar.t.unknown) : "" }
              InfoRow { theme: tones; label: pulzar.t.processor; value: pulzar.computer ? (pulzar.computer.processor || pulzar.t.unknown) : "" }

              InfoRow {
                visible: !!pulzar.computer && pulzar.computer.graphics.length === 0
                theme: tones
                label: pulzar.t.graphics
                value: pulzar.t.unknown
              }

              Repeater {
                model: pulzar.computer ? pulzar.computer.graphics : []

                InfoRow {
                  required property var modelData
                  theme: tones
                  label: pulzar.t.graphics
                  value: Format.graphicsName(modelData)
                }
              }

              InfoRow { theme: tones; label: pulzar.t.installedMemory; value: pulzar.computer ? Format.formatBytes(pulzar.computer.memoryBytes, pulzar.t) : "" }
              InfoRow { theme: tones; label: pulzar.t.storageCapacity; value: pulzar.computer ? Format.formatBytes(pulzar.computer.storageBytes, pulzar.t) : "" }

              InfoRow {
                readonly property var encryption: Format.encryptionAssessment(pulzar.encrypted, pulzar.t)
                theme: tones
                label: pulzar.t.diskEncryption
                value: encryption.label
                tone: encryption.tone
                // Offered only when the disk is known to be unencrypted, never
                // on the "unknown" a failed probe leaves behind
                trailing: pulzar.encrypted === false ? lockButton : null
              }

              InfoRow { theme: tones; label: pulzar.t.manufacturingDate; value: pulzar.computer ? (pulzar.computer.manufacturingDate || pulzar.t.unknown) : "" }
              InfoRow { theme: tones; label: pulzar.t.agentVersion; value: pulzar.computer ? (pulzar.computer.agentVersion || pulzar.t.unknown) : "" }
              InfoRow { theme: tones; label: pulzar.t.systemInformationCollectedAt; value: pulzar.computer ? Format.formatDateTime(pulzar.computer.collectedAt, pulzar.t) : "" }
            }
          }

          // ---------- This device on the platform ----------
          SectionCard {
            visible: telemetry.hasData && session.configured
            theme: tones
            title: pulzar.t.platformDevice
            subheader: pulzar.t.platformDeviceSubtitle

            readonly property var record: session.deviceRecord

            // Signed out, or the platform declining to show a device. The
            // decline is a plain state, not a failure: it is also what a
            // machine that simply is not registered looks like.
            Text {
              textFormat: Text.PlainText
              visible: !session.signedIn || (!parent.record && session.deviceMessage !== "")
                || (!parent.record && !session.deviceLooked)
              width: parent.width
              wrapMode: Text.WordWrap
              text: {
                if (!session.signedIn) return pulzar.t.signInToSeeDevice
                if (session.deviceMessage !== "") return session.deviceMessage
                return pulzar.t.lookingUpDevice
              }
              color: tones.dim
              font.family: tones.fontFamily
              font.pixelSize: Style.font.bodySmall
            }

            IconRow {
              visible: !!parent.record
              theme: tones
              icon: pulzar.iconLaptop
              tone: "secondary"
              title: parent.record
                ? [parent.record.brand, parent.record.model].filter(Boolean).join(" ") || parent.record.device_name || ""
                : ""
              caption: parent.record ? (parent.record.serial_number || "") : ""
              chipText: parent.record ? (parent.record.status || "") : ""
              chipTone: "success"
            }

            InfoRow {
              visible: !!parent.record && !!parent.record.assigned_to
              theme: tones
              label: pulzar.t.assignedTo
              value: parent.record && parent.record.assigned_to
                ? (parent.record.assigned_to.name || parent.record.assigned_to.email || "") : ""
            }

            InfoRow {
              visible: !!parent.record && !!parent.record.category
              theme: tones
              label: pulzar.t.deviceCategory
              value: parent.record ? (parent.record.category || "") : ""
            }

            InfoRow {
              visible: !!parent.record && !!parent.record.purchase_year
              theme: tones
              label: pulzar.t.purchaseYear
              value: parent.record ? String(parent.record.purchase_year || "") : ""
            }

            InfoRow {
              visible: !!parent.record && !!parent.record.mdm_provider
              theme: tones
              label: pulzar.t.enrolledWith
              value: parent.record ? (parent.record.mdm_provider || "") : ""
            }

            InfoRow {
              // Every field is compacted server-side, so an absent one is
              // normal rather than a sign anything went wrong
              visible: !!parent.record && !!parent.record.tags && parent.record.tags.length > 0
              theme: tones
              label: pulzar.t.deviceTags
              value: parent.record && parent.record.tags ? parent.record.tags.join(", ") : ""
            }

            PanelSectionHeader {
              visible: !!parent.record && !!parent.record.orders && parent.record.orders.length > 0
              text: pulzar.t.recentOrders.toUpperCase()
              foreground: tones.foreground
              fontFamily: tones.fontFamily
            }

            Repeater {
              model: session.deviceRecord && session.deviceRecord.orders
                ? session.deviceRecord.orders : []

              InfoRow {
                required property var modelData
                theme: tones
                label: modelData.reference || ""
                value: [modelData.status, modelData.created_on].filter(Boolean).join(" · ")
              }
            }
          }

          // ---------- Network ----------
          SectionCard {
            visible: telemetry.hasData && !!pulzar.status && pulzar.status.interfaces.length > 0
            theme: tones
            title: pulzar.t.network
            subheader: pulzar.t.networkSubtitle

            Repeater {
              model: pulzar.status ? pulzar.status.interfaces : []

              Column {
                required property var modelData
                readonly property string share: Format.dropShare(modelData) || ""

                width: parent.width
                spacing: Style.space(2)

                IconRow {
                  theme: tones
                  icon: pulzar.iconNetwork
                  tone: "secondary"
                  title: modelData.name
                  // Wireless links and tunnels report no speed; the agent
                  // sends -1 and the parser leaves the field out
                  caption: modelData.linkMegabits !== undefined
                    ? pulzar.t.linkSpeed(modelData.linkMegabits)
                    : pulzar.t.noLinkSpeed
                }

                InfoRow {
                  theme: tones
                  label: pulzar.t.received
                  value: Format.formatCounter(modelData.bytesReceived, pulzar.t)
                }

                InfoRow {
                  theme: tones
                  label: pulzar.t.sent
                  value: Format.formatCounter(modelData.bytesSent, pulzar.t)
                }

                // A steady share of discarded arrivals is normal on a wired
                // card, so the row appears when there is something to see and
                // is left untinted rather than called a fault
                InfoRow {
                  visible: modelData.dropsIn > 0 && parent.share !== ""
                  theme: tones
                  label: pulzar.t.droppedPackets
                  value: pulzar.t.shareOfPackets(parent.share)
                }

                InfoRow {
                  visible: modelData.errorsIn > 0 || modelData.errorsOut > 0
                  theme: tones
                  label: pulzar.t.packetErrors
                  value: modelData.errorsIn + " / " + modelData.errorsOut
                }
              }
            }
          }

          // ---------- Collected data ----------
          SectionCard {
            visible: telemetry.hasData
            theme: tones
            title: pulzar.t.collectedData
            subheader: pulzar.t.latestInputs

            InfoRow {
              visible: !!pulzar.status && pulzar.status.hardware.displayCount !== undefined
              theme: tones
              label: pulzar.t.displays
              value: pulzar.status && pulzar.status.hardware.displayCount !== undefined ? String(pulzar.status.hardware.displayCount) : ""
            }

            InfoRow {
              visible: !!pulzar.status && pulzar.status.hardware.temperatureCelsius !== undefined
              theme: tones
              label: pulzar.t.temperature
              value: pulzar.status && pulzar.status.hardware.temperatureCelsius !== undefined
                ? Format.formatTemperature(pulzar.status.hardware.temperatureCelsius, pulzar.t) : ""
            }

            Repeater {
              model: pulzar.status ? pulzar.status.inputs : []

              InfoRow {
                required property var modelData
                theme: tones
                label: Format.inputName(modelData.measurement, pulzar.t)
                value: Format.formatDateTime(modelData.collectedAt, pulzar.t)
              }
            }
          }

          // ---------- Installed programs ----------
          SectionCard {
            id: programsCard
            visible: telemetry.hasData && !!pulzar.computer && pulzar.computer.programs.length > 0
            theme: tones
            title: pulzar.t.installedPrograms
            subheader: pulzar.computer ? pulzar.t.programCount(pulzar.computer.programs.length) : ""

            readonly property var matches: pulzar.computer ? Format.filterPrograms(pulzar.computer.programs, pulzar.programQuery) : []
            readonly property int visibleCount: pulzar.programQuery.trim() !== "" ? Format.VISIBLE_SEARCH_RESULTS : Format.VISIBLE_PROGRAMS

            TextField {
              id: searchField
              width: parent.width
              placeholderText: pulzar.iconSearch + "  " + pulzar.t.searchPrograms
              foreground: tones.foreground
              font.family: tones.fontFamily
              onTextChanged: {
                pulzar.programSearch = text
                searchDebounce.restart()
              }
              Keys.onEscapePressed: keyCatcher.forceActiveFocus()
            }

            Text {
              textFormat: Text.PlainText
              visible: programsCard.matches.length === 0
              width: parent.width
              text: pulzar.t.noProgramsFound
              color: tones.dim
              font.family: tones.fontFamily
              font.pixelSize: Style.font.bodySmall
            }

            Repeater {
              model: programsCard.matches.slice(0, programsCard.visibleCount)

              InfoRow {
                required property var modelData
                theme: tones
                label: modelData.name
                value: modelData.version || pulzar.t.unknown
              }
            }

            Text {
              textFormat: Text.PlainText
              visible: programsCard.matches.length > programsCard.visibleCount
              width: parent.width
              wrapMode: Text.WordWrap
              text: pulzar.t.morePrograms(programsCard.matches.length - programsCard.visibleCount)
              color: tones.dim
              font.family: tones.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }
      }

      // ---------- Footer: support ----------
      Column {
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: Style.space(10)

        PanelSeparator { foreground: tones.foreground }

        Button {
          width: parent.width
          radius: tones.radius
          text: pulzar.copied ? pulzar.t.copied : pulzar.t.copySupport
          iconText: pulzar.copied ? pulzar.iconCopied : pulzar.iconCopy
          fontSize: Style.font.bodySmall
          foreground: pulzar.copied ? tones.success : tones.foreground
          fontFamily: tones.fontFamily
          bordered: true
          selected: pulzar.copied
          enabled: telemetry.hasData
          opacity: enabled ? 1 : 0.45
          onClicked: pulzar.copySupport()
        }

        // ---------- Platform session ----------
        Item {
          width: parent.width
          implicitHeight: Math.max(sessionLabel.implicitHeight, sessionButton.implicitHeight)

          Column {
            anchors.left: parent.left
            anchors.right: copyLinkButton.visible ? copyLinkButton.left : sessionButton.left
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(1)

            Text {
              id: sessionLabel
              textFormat: Text.PlainText
              width: parent.width
              elide: Text.ElideRight
              text: pulzar.t.platformSession
              color: tones.dim
              font.family: tones.fontFamily
              font.pixelSize: Style.font.caption
            }

            Text {
              textFormat: Text.PlainText
              width: parent.width
              elide: Text.ElideRight
              text: {
                if (!session.configured) return pulzar.t.signInUnavailable
                if (session.failure !== "") return pulzar.t.signInFailed(session.failure)
                if (session.consentUrl !== "")
                  return session.consentOpened ? pulzar.t.awaitingConsent : pulzar.t.openSignInPage
                if (session.signedIn && session.expired) return pulzar.t.sessionExpired
                if (!session.signedIn && session.revokeFailed !== "") return pulzar.t.signOutNotRevoked
                return session.signedIn ? pulzar.t.signedIn : pulzar.t.notSignedIn
              }
              color: {
                if (session.failure !== "") return tones.error
                if (!session.signedIn && session.revokeFailed !== "") return tones.warning
                if (session.signedIn && !session.expired) return tones.success
                return tones.foreground
              }
              font.family: tones.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }
          }

          // Telling someone to open a page while showing them no way to reach
          // it is worse than saying nothing. This appears only when the helper
          // could not launch a browser, which is the one case where the URL is
          // theirs to open.
          Button {
            id: copyLinkButton
            visible: session.consentUrl !== "" && !session.consentOpened
            anchors.right: sessionButton.left
            anchors.rightMargin: Style.space(6)
            anchors.verticalCenter: parent.verticalCenter
            radius: tones.radius
            text: pulzar.linkCopied ? pulzar.t.signInLinkCopied : pulzar.t.copySignInLink
            iconText: pulzar.linkCopied ? pulzar.iconCopied : pulzar.iconCopy
            fontSize: Style.font.caption
            foreground: pulzar.linkCopied ? tones.success : tones.foreground
            fontFamily: tones.fontFamily
            bordered: true
            selected: pulzar.linkCopied
            onClicked: pulzar.copySignInLink()
          }

          Button {
            id: sessionButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            radius: tones.radius
            text: session.signedIn ? pulzar.t.signOut : pulzar.t.signIn
            fontSize: Style.font.caption
            foreground: tones.foreground
            fontFamily: tones.fontFamily
            bordered: true
            enabled: session.configured && !session.busy
            opacity: enabled ? 1 : 0.45
            onClicked: session.signedIn ? session.signOut() : session.signIn()
          }
        }

        Item {
          width: parent.width
          implicitHeight: Math.max(sourceText.implicitHeight, updatedText.implicitHeight)

          Text {
            id: sourceText
            textFormat: Text.PlainText
            anchors.left: parent.left
            text: pulzar.t.sourceAgent
            color: tones.dim
            font.family: tones.fontFamily
            font.pixelSize: Style.font.caption
          }

          Text {
            id: updatedText
            textFormat: Text.PlainText
            visible: !!pulzar.status && pulzar.status.observedAt !== ""
            anchors.right: parent.right
            text: pulzar.status ? pulzar.t.updatedAt(Format.formatTime(pulzar.status.observedAt, pulzar.t)) : ""
            color: tones.dim
            font.family: tones.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }
}
