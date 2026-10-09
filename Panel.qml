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

  // Feedback of the copy button
  readonly property int copiedFeedbackMs: 2200

  readonly property var t: telemetry.t
  readonly property var status: telemetry.status
  readonly property var summary: Format.statusSummary(pulzar.status, telemetry.isError, pulzar.t)
  // What the summary card used to spell out, now shown on hovering the light
  readonly property string summaryTooltip: [pulzar.summary.label, pulzar.summary.title, pulzar.summary.detail]
    .filter(function(line) { return !!line }).join("\n")
  readonly property var battery: pulzar.status ? pulzar.status.hardware.battery : undefined
  readonly property var computer: pulzar.status ? pulzar.status.computer : undefined

  property bool copied: false
  property string programSearch: ""
  property string programQuery: ""

  function copySupport() {
    if (!telemetry.hasData) return
    Quickshell.execDetached(["wl-copy", "--", Format.supportInformation(pulzar.status, pulzar.t)])
    pulzar.copied = true
    copiedTimer.restart()
  }

  function refresh() {
    telemetry.refresh()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) {
    telemetry.refresh()
    if (panelFlick) panelFlick.contentY = 0
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  Telemetry {
    id: telemetry
    snapshotPath: pulzar.setting("snapshotPath", "") || Snapshot.DEFAULT_PATH
    refreshIntervalSec: pulzar.setting("refreshIntervalSec", 5)
  }

  Theme {
    id: tones
    bar: pulzar.bar
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
    function support(): string { return pulzar.status ? Format.supportInformation(pulzar.status, pulzar.t) : "" }
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

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: pulzar.close()
      onTabRequested: function(direction) { pulzar.switchPanel(direction) }
      onTextKey: function(key) {
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
              PanelActionButton {
                radius: tones.radius
                iconText: pulzar.iconRefresh
                tooltipText: pulzar.t.refresh
                foreground: tones.foreground
                fontFamily: tones.fontFamily
                onClicked: pulzar.refresh()
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

            Row {
              width: parent.width
              spacing: Style.space(10)

              UsageMeter {
                width: (parent.width - parent.spacing) / 2
                theme: tones
                t: pulzar.t
                label: pulzar.t.memory
                icon: pulzar.iconMemory
                used: pulzar.status ? pulzar.status.hardware.ramUsedBytes : 0
                total: pulzar.status ? pulzar.status.hardware.ramTotalBytes : 0
              }

              UsageMeter {
                width: (parent.width - parent.spacing) / 2
                theme: tones
                t: pulzar.t
                label: pulzar.t.storage
                icon: pulzar.iconStorage
                used: pulzar.status ? pulzar.status.hardware.storageUsedBytes : 0
                total: pulzar.status ? pulzar.status.hardware.storageTotalBytes : 0
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
                readonly property var encryption: Format.encryptionAssessment(pulzar.computer ? pulzar.computer.encrypted : undefined, pulzar.t)
                theme: tones
                label: pulzar.t.diskEncryption
                value: encryption.label
                tone: encryption.tone
              }

              InfoRow { theme: tones; label: pulzar.t.manufacturingDate; value: pulzar.computer ? (pulzar.computer.manufacturingDate || pulzar.t.unknown) : "" }
              InfoRow { theme: tones; label: pulzar.t.agentVersion; value: pulzar.computer ? (pulzar.computer.agentVersion || pulzar.t.unknown) : "" }
              InfoRow { theme: tones; label: pulzar.t.systemInformationCollectedAt; value: pulzar.computer ? Format.formatDateTime(pulzar.computer.collectedAt, pulzar.t) : "" }
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

      // ---------- Footer: support, language ----------
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

        ButtonGroup {
          anchors.horizontalCenter: parent.horizontalCenter
          options: [{ value: "auto", label: pulzar.t.languageAuto, tooltip: pulzar.t.chooseLanguage }].concat(
            Locales.languageOptions.map(function(option) { return { value: option.id, label: option.short, tooltip: option.name } }))
          value: telemetry.languageChoice
          foreground: tones.foreground
          fontFamily: tones.fontFamily
          fontSize: Style.font.caption
          focusable: false
          onChanged: function(value) { telemetry.setLanguage(value) }
        }
      }
    }
  }
}
