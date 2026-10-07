.pragma library

// Formatting of sizes, dates, states and the support text, the same as the
// tray application of the agent: every function takes the labels `t` of
// Locales.js.

// Rows of the program list, a device can have thousands of them
var VISIBLE_PROGRAMS = 10
var VISIBLE_SEARCH_RESULTS = 50

// Usage above which the meters use the warning, then the error tone
var USAGE_WARNING_PERCENT = 75
var USAGE_ERROR_PERCENT = 90

// QML has no Intl: the four locales only differ in the decimal separator
function decimal(value, digits, t) {
  var text = Number(value).toFixed(digits)
  return String(t.locale).indexOf("en") === 0 ? text : text.replace(".", ",")
}

function formatBytes(value, t) {
  if (!value) return t.unknown
  return decimal(value / Math.pow(1024, 3), 1, t) + " " + t.byteUnit
}

function formatPercent(value, t) {
  if (value === null || value === undefined) return t.unknown
  return decimal(value, 0, t) + " %"
}

function formatTemperature(value, t) {
  return decimal(value, 0, t) + " °C"
}

function usagePercent(used, total) {
  if (!total) return 0
  return Math.min(100, Math.max(0, Math.round((used / total) * 100)))
}

function parseDate(value) {
  if (!value) return null
  var date = new Date(value)
  return isNaN(date.getTime()) ? null : date
}

function pad(value) {
  return value < 10 ? "0" + value : String(value)
}

// en-GB, es-ES, ca-ES and fr-FR all write dd/MM/yyyy HH:mm
function formatDateTime(value, t) {
  var date = parseDate(value)
  if (!date) return t.unknown
  return pad(date.getDate()) + "/" + pad(date.getMonth() + 1) + "/" + date.getFullYear() + " " + formatTime(value, t)
}

function formatTime(value, t) {
  var date = parseDate(value)
  if (!date) return t.unknown
  return pad(date.getHours()) + ":" + pad(date.getMinutes())
}

function inputName(measurement, t) {
  return t.inputNames[measurement] !== undefined ? t.inputNames[measurement] : measurement
}

// Tone of a state: success, secondary, warning, error, info or default
function batteryAssessment(condition, t) {
  switch (condition) {
  case "excellent":
    return { tone: "success", label: t.batteryExcellent, message: t.batteryExcellentMessage }
  case "very_good":
    return { tone: "secondary", label: t.batteryVeryGood, message: t.batteryVeryGoodMessage }
  case "good":
    return { tone: "warning", label: t.batteryGood, message: t.batteryGoodMessage }
  case "poor":
    return { tone: "error", label: t.batteryPoor, message: t.batteryPoorMessage }
  default:
    return { tone: "default", label: t.batteryUnknown, message: t.batteryUnknownMessage }
  }
}

function encryptionAssessment(encrypted, t) {
  if (encrypted === null || encrypted === undefined) return { tone: "default", label: t.unknown }
  return encrypted ? { tone: "success", label: t.encryptionEnabled } : { tone: "error", label: t.encryptionDisabled }
}

function usageTone(percent) {
  if (percent >= USAGE_ERROR_PERCENT) return "error"
  if (percent >= USAGE_WARNING_PERCENT) return "warning"
  return "secondary"
}

function normalize(value) {
  var text = String(value)
  if (typeof text.normalize === "function") text = text.normalize("NFD")
  return text.replace(/[̀-ͯ]/g, "").toLowerCase()
}

// Programs whose name contains the search, ignoring the case and the accents
function filterPrograms(programs, search) {
  var query = normalize(String(search || "").trim())
  if (!query) return programs
  return programs.filter(function(program) { return normalize(program.name).indexOf(query) !== -1 })
}

function operatingSystemLabel(computer, t) {
  return computer.operatingSystem || computer.platform || t.unknown
}

function graphicsName(card) {
  return [card.vendor, card.product].filter(Boolean).join(" ")
}

function availabilityLabel(status, t) {
  switch (status.availability) {
  case "active": return t.agentActive
  case "stale": return t.agentStale
  case "stopped": return t.agentStopped
  default: return t.agentWaiting
  }
}

// What the panel says about the agent, from the latest status and the read error
function statusSummary(status, isError, t) {
  if (isError) return { tone: "error", label: t.connectionInterrupted, title: t.dataUnavailable, detail: t.retryLater }

  switch (status ? status.availability : "") {
  case "active":
    return { tone: "success", label: t.agentActive, title: t.agentActiveTitle, detail: t.agentActiveDetail(formatTime(status.observedAt, t)) }
  case "stale":
    return { tone: "warning", label: t.agentStale, title: t.agentStaleTitle, detail: t.agentStaleDetail(formatDateTime(status.observedAt, t)) }
  case "stopped":
    return { tone: "error", label: t.agentStopped, title: t.agentStoppedTitle, detail: t.agentStoppedDetail }
  default:
    return { tone: "info", label: t.agentWaiting, title: t.agentWaitingTitle, detail: t.agentWaitingDetail }
  }
}

// Plain text pasted in support requests
function supportInformation(status, t) {
  var device = status.device
  var hardware = status.hardware
  var computer = status.computer

  var lines = [
    t.supportTitle,
    t.deviceName + ": " + (device.name || t.unknown),
    t.serialNumber + ": " + (device.serial || t.unknown),
    t.memory + ": " + t.usedOf(formatBytes(hardware.ramUsedBytes, t), formatBytes(hardware.ramTotalBytes, t)),
    t.storage + ": " + t.usedOf(formatBytes(hardware.storageUsedBytes, t), formatBytes(hardware.storageTotalBytes, t))
  ]

  if (hardware.battery) {
    lines.push(
      t.batteryCondition + ": " + batteryAssessment(hardware.battery.condition, t).label,
      t.batteryHealth + ": " + formatPercent(hardware.battery.healthPercent, t),
      t.batteryCharge + ": " + formatPercent(hardware.battery.chargePercent, t)
    )
  }

  if (computer) {
    lines.push(
      t.computerSubtitle + ":",
      "  " + t.operatingSystem + ": " + [operatingSystemLabel(computer, t), computer.version, computer.architecture].filter(Boolean).join(" · "),
      "  " + t.processor + ": " + (computer.processor || t.unknown)
    )
    computer.graphics.forEach(function(card) { lines.push("  " + t.graphics + ": " + graphicsName(card)) })
    lines.push(
      "  " + t.installedMemory + ": " + formatBytes(computer.memoryBytes, t),
      "  " + t.storageCapacity + ": " + formatBytes(computer.storageBytes, t),
      "  " + t.diskEncryption + ": " + encryptionAssessment(computer.encrypted, t).label,
      "  " + t.manufacturingDate + ": " + (computer.manufacturingDate || t.unknown),
      "  " + t.agentVersion + ": " + (computer.agentVersion || t.unknown),
      "  " + t.programsLabel + ": " + computer.programs.length
    )
  }

  if (hardware.displayCount !== undefined) lines.push(t.displays + ": " + hardware.displayCount)

  lines.push(
    t.agentStatus + ": " + availabilityLabel(status, t),
    t.lastCollection + ": " + formatDateTime(status.observedAt, t)
  )

  return lines.join("\n")
}

if (typeof module !== "undefined") {
  module.exports = {
    VISIBLE_PROGRAMS: VISIBLE_PROGRAMS,
    VISIBLE_SEARCH_RESULTS: VISIBLE_SEARCH_RESULTS,
    formatBytes: formatBytes,
    formatPercent: formatPercent,
    formatTemperature: formatTemperature,
    usagePercent: usagePercent,
    usageTone: usageTone,
    formatDateTime: formatDateTime,
    formatTime: formatTime,
    inputName: inputName,
    batteryAssessment: batteryAssessment,
    encryptionAssessment: encryptionAssessment,
    filterPrograms: filterPrograms,
    operatingSystemLabel: operatingSystemLabel,
    graphicsName: graphicsName,
    availabilityLabel: availabilityLabel,
    statusSummary: statusSummary,
    supportInformation: supportInformation
  }
}
