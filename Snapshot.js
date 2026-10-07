.pragma library

// Reads the snapshot written by the systray output of the agent and turns it
// into the status shown by the panel. It follows the status package of the
// agent's tray application: a change to the snapshot format must be made in
// both.

// Measurement of the line describing the snapshot, written by the output plugin
var SNAPSHOT_MEASUREMENT = "systray_snapshot"

// Snapshot written by the agent on Linux
var DEFAULT_PATH = "/var/lib/telegraf/systray/latest.lp"

var AVAILABILITY_WAITING = "waiting"
var AVAILABILITY_ACTIVE = "active"
var AVAILABILITY_STALE = "stale"
var AVAILABILITY_STOPPED = "stopped"

// ------------------------------------------------------------ line protocol

function isDigit(c) {
  return c >= "0" && c <= "9"
}

// Reads up to an unescaped character of `stops`, unescaping `\x`. Returns the
// text and the index of the stop (or the end of the line).
function readEscaped(line, start, stops) {
  var text = ""
  var i = start

  while (i < line.length) {
    var c = line.charAt(i)

    if (c === "\\" && i + 1 < line.length) {
      text += line.charAt(i + 1)
      i += 2
      continue
    }

    if (stops.indexOf(c) !== -1) break

    text += c
    i++
  }

  return { text: text, end: i }
}

// A field value: { value, kind } where kind is float, int, uint, string or bool
function parseFieldValue(line, start) {
  if (line.charAt(start) === "\"") {
    var text = ""
    var i = start + 1

    while (i < line.length) {
      var c = line.charAt(i)

      if (c === "\\" && i + 1 < line.length && (line.charAt(i + 1) === "\"" || line.charAt(i + 1) === "\\")) {
        text += line.charAt(i + 1)
        i += 2
        continue
      }

      if (c === "\"") return { value: text, kind: "string", end: i + 1 }

      text += c
      i++
    }

    throw new Error("unterminated string field")
  }

  var raw = readEscaped(line, start, ", ")
  var token = raw.text

  if (/^(t|T|true|True|TRUE)$/.test(token)) return { value: true, kind: "bool", end: raw.end }
  if (/^(f|F|false|False|FALSE)$/.test(token)) return { value: false, kind: "bool", end: raw.end }
  if (/^-?\d+i$/.test(token)) return { value: Number(token.slice(0, -1)), kind: "int", end: raw.end }
  if (/^\d+u$/.test(token)) return { value: Number(token.slice(0, -1)), kind: "uint", end: raw.end }

  var number = Number(token)

  if (token === "" || !isFinite(number)) throw new Error("invalid field value " + JSON.stringify(token))

  return { value: number, kind: "float", end: raw.end }
}

// One line: { name, tags, fields, kinds, time } with time in milliseconds
function parseLine(line) {
  var measurement = readEscaped(line, 0, ", ")
  var metric = { name: measurement.text, tags: {}, fields: {}, kinds: {}, time: 0 }
  var i = measurement.end

  if (!metric.name) throw new Error("line without measurement")

  while (line.charAt(i) === ",") {
    var key = readEscaped(line, i + 1, "=")
    var value = readEscaped(line, key.end + 1, ", ")
    metric.tags[key.text] = value.text
    i = value.end
  }

  if (line.charAt(i) !== " ") throw new Error("line without fields")

  do {
    var fieldKey = readEscaped(line, i + 1, "=")

    if (line.charAt(fieldKey.end) !== "=") throw new Error("field without value")

    var field = parseFieldValue(line, fieldKey.end + 1)
    metric.fields[fieldKey.text] = field.value
    metric.kinds[fieldKey.text] = field.kind
    i = field.end
  } while (line.charAt(i) === ",")

  var timestamp = line.substring(i).trim()

  if (timestamp !== "") {
    if (!/^-?\d+$/.test(timestamp)) throw new Error("invalid timestamp")
    // Nanoseconds do not fit in a double, the milliseconds do
    metric.time = timestamp.length > 6 ? Number(timestamp.slice(0, -6)) : 0
  }

  return metric
}

// Parses the content of a snapshot file
function parseSnapshot(data) {
  var snapshot = { running: false, staleAfterMs: 0, writtenAt: 0, metrics: [] }
  var header = false
  var lines = String(data || "").split("\n")

  for (var n = 0; n < lines.length; n++) {
    var line = lines[n].replace(/\r$/, "")

    if (line.trim() === "" || line.charAt(0) === "#") continue

    var metric = parseLine(line)

    if (metric.name !== SNAPSHOT_MEASUREMENT) {
      snapshot.metrics.push(metric)
      continue
    }

    header = true
    snapshot.writtenAt = metric.time

    if (metric.kinds.running === "bool") snapshot.running = metric.fields.running
    if (metric.kinds.stale_after === "int") snapshot.staleAfterMs = metric.fields.stale_after * 1000
  }

  if (!header) throw new Error("snapshot without " + SNAPSHOT_MEASUREMENT + " line")

  return snapshot
}

// ------------------------------------------------------------------- values

function number(metric, key) {
  var kind = metric.kinds[key]
  var value = metric.fields[key]

  if (kind !== "float" && kind !== "int" && kind !== "uint") return null
  if (!isFinite(value)) return null

  return value
}

function percent(metric, key) {
  var value = number(metric, key)
  return value === null || value < 0 || value > 100 ? null : value
}

function integer(metric, key) {
  var kind = metric.kinds[key]
  return kind === "int" || kind === "uint" ? metric.fields[key] : null
}

function unsigned(metric, key) {
  var value = number(metric, key)
  return value === null || value < 0 ? null : Math.floor(value)
}

function text(metric, key) {
  return metric.kinds[key] === "string" ? String(metric.fields[key]).trim() : ""
}

function isoTime(ms) {
  return new Date(ms).toISOString().replace(/\.\d{3}Z$/, "Z")
}

// ------------------------------------------------------------------- status

// Classifies the remaining capacity, the agent does not report the cycle count
function batteryCondition(healthPercent) {
  if (healthPercent >= 90) return "excellent"
  if (healthPercent >= 80) return "very_good"
  if (healthPercent >= 70) return "good"
  return "poor"
}

// Fields of the system input
function applySystem(hardware, metric) {
  var value

  if ((value = unsigned(metric, "ram.total")) !== null) hardware.ramTotalBytes = value
  if ((value = unsigned(metric, "ram.used")) !== null) hardware.ramUsedBytes = value
  if ((value = unsigned(metric, "disk.total")) !== null) hardware.storageTotalBytes = value
  if ((value = unsigned(metric, "disk.used")) !== null) hardware.storageUsedBytes = value

  var charge = percent(metric, "batteries.0.current")
  var health = percent(metric, "batteries.0.health")

  if (charge === null && health === null) return

  var battery = { condition: "unknown" }

  if (charge !== null) battery.chargePercent = charge

  if (health !== null) {
    battery.healthPercent = health
    battery.condition = batteryCondition(health)
  }

  hardware.battery = battery
}

// Installed programs: an object of names and versions, or a list of names on
// the platforms without versions
function programs(encoded) {
  var result = []

  if (!encoded) return result

  var decoded

  try {
    decoded = JSON.parse(encoded)
  } catch (e) {
    return result
  }

  if (Array.isArray(decoded)) {
    for (var i = 0; i < decoded.length; i++) {
      if (typeof decoded[i] === "string") result.push({ name: decoded[i], version: "" })
    }
  } else if (decoded && typeof decoded === "object") {
    for (var name in decoded) result.push({ name: name, version: String(decoded[name] || "") })
  }

  result.sort(function(a, b) {
    var x = a.name.toLowerCase()
    var y = b.name.toLowerCase()
    return x < y ? -1 : (x > y ? 1 : 0)
  })

  return result
}

// Fields of the sysinfo input, flattened into dotted keys
function computer(metric) {
  var result = {
    operatingSystem: text(metric, "platform.name"),
    family: text(metric, "platform.family"),
    version: text(metric, "platform.version"),
    platform: text(metric, "platform.os"),
    architecture: text(metric, "platform.architecture"),
    processor: text(metric, "processor"),
    graphics: [],
    memoryBytes: unsigned(metric, "memory") || 0,
    storageBytes: unsigned(metric, "storage") || 0,
    manufacturingDate: text(metric, "manufacturing_date"),
    agentVersion: text(metric, "version"),
    programs: programs(text(metric, "programs")),
    collectedAt: isoTime(metric.time)
  }

  if (metric.kinds.encryption === "bool") result.encrypted = metric.fields.encryption

  var count = integer(metric, "graphics.count") || 0

  for (var i = 0; i < count; i++) {
    var prefix = "graphics." + i + "."
    var card = { vendor: text(metric, prefix + "vendor"), product: text(metric, prefix + "product") }

    if (card.vendor || card.product) result.graphics.push(card)
  }

  return result
}

// Status of a device whose agent did not write anything yet
function waiting(hostname) {
  return {
    availability: AVAILABILITY_WAITING,
    observedAt: "",
    device: { name: hostname || "", serial: "" },
    hardware: { ramTotalBytes: 0, ramUsedBytes: 0, storageTotalBytes: 0, storageUsedBytes: 0 },
    inputs: []
  }
}

// Turns the metrics of the snapshot into the status shown by the panel.
// `now` is in milliseconds.
function build(snapshot, hostname, now) {
  var status = waiting(hostname)
  var newest = 0
  var computerTime = 0
  var latest = {}

  for (var i = 0; i < snapshot.metrics.length; i++) {
    var metric = snapshot.metrics[i]

    if (metric.time > newest) newest = metric.time
    if (metric.time > (latest[metric.name] || 0)) latest[metric.name] = metric.time

    // Every input tags its metrics with the serial number
    if (metric.tags.host && !status.device.serial) status.device.serial = metric.tags.host

    switch (metric.name) {
    case "system":
      applySystem(status.hardware, metric)
      break
    case "sysinfo":
      if (!status.computer || metric.time > computerTime) {
        status.computer = computer(metric)
        computerTime = metric.time
      }
      break
    case "display":
      var count = integer(metric, "display.count")
      if (count !== null) status.hardware.displayCount = count
      break
    case "temp":
      var temperature = number(metric, "temp")
      if (temperature !== null && (status.hardware.temperatureCelsius === undefined || temperature > status.hardware.temperatureCelsius))
        status.hardware.temperatureCelsius = temperature
      break
    }
  }

  for (var name in latest) status.inputs.push({ measurement: name, collectedAt: isoTime(latest[name]) })

  status.inputs.sort(function(a, b) { return a.measurement < b.measurement ? -1 : (a.measurement > b.measurement ? 1 : 0) })

  if (newest > 0) status.observedAt = isoTime(newest)

  if (!snapshot.running) status.availability = AVAILABILITY_STOPPED
  else if (newest <= 0) status.availability = AVAILABILITY_WAITING
  else if (snapshot.staleAfterMs > 0 && now - newest > snapshot.staleAfterMs) status.availability = AVAILABILITY_STALE
  else status.availability = AVAILABILITY_ACTIVE

  return status
}

if (typeof module !== "undefined") {
  module.exports = {
    DEFAULT_PATH: DEFAULT_PATH,
    parseLine: parseLine,
    parseSnapshot: parseSnapshot,
    batteryCondition: batteryCondition,
    waiting: waiting,
    build: build
  }
}
