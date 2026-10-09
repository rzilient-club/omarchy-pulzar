.pragma library

// Reads the snapshot written by the systray output of the agent and turns it
// into the status shown by the panel. It follows the status package of the
// agent's tray application: a change to the snapshot format must be made in
// both.

// Measurement of the line describing the snapshot, written by the output plugin
var SNAPSHOT_MEASUREMENT = "systray_snapshot"

// Snapshot written by the agent on Linux
var DEFAULT_PATH = "/var/lib/siot-telemetry/systray/latest.lp"

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

// A sensor the board leaves unconnected still answers when asked. The Super
// I/O chips return a placeholder far outside any real range (nct6793 gives
// 3892313.987 on an idle TSI channel), and their spare thermistor inputs
// float at a plausible-looking hundred degrees. Only a reading silicon can
// actually reach is kept, and SYSTIN/AUXTIN are dropped by name: they are
// unconnected on most boards, stay inside the valid range, and would win the
// maximum with a number no component ever reached.
var TEMPERATURE_MIN_CELSIUS = -40
var TEMPERATURE_MAX_CELSIUS = 150
var UNCONNECTED_SENSOR = /(?:^|_)(?:systin|auxtin[0-9]*)$/

function usableTemperature(metric) {
  var value = number(metric, "temp")

  if (value === null) return null
  if (value < TEMPERATURE_MIN_CELSIUS || value > TEMPERATURE_MAX_CELSIUS) return null
  if (UNCONNECTED_SENSOR.test(metric.tags.sensor || "")) return null

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

// Vendors are meant to burn an identifier into the DMI tables and plenty of
// them ship the template instead: this ASRock board answers "To Be Filled By
// O.E.M." for its serial number, others leave "Default string", a row of
// zeroes, or nothing but punctuation. The agent forwards whatever it reads,
// so the placeholders are recognised here and reported as no value at all,
// which lets the panel fall back to "Unknown serial number" instead of
// presenting boilerplate as an identifier.
var DMI_PLACEHOLDERS = [
  "0123456789",
  "base board serial number",
  "board serial number",
  "chassis serial number",
  "default",
  "default string",
  "empty",
  "filled by o e m",
  "invalid",
  "module serial number",
  "n a",
  "none",
  "not applicable",
  "not available",
  "not specified",
  "o e m",
  "oem",
  "system manufacturer",
  "system product name",
  "system serial number",
  "system version",
  "to be filled by o e m",
  "unknown"
]

// Returns the value trimmed, or "" when it identifies nothing.
function identifier(value) {
  var trimmed = String(value === undefined || value === null ? "" : value).trim()
  // Case and punctuation vary between vendors: "N/A", "n.a." and "N / A" are
  // the same non-answer, so they are compared without either
  var normalised = trimmed.toLowerCase().replace(/[^a-z0-9]+/g, " ").trim()

  if (!normalised) return ""
  if (DMI_PLACEHOLDERS.indexOf(normalised) !== -1) return ""
  // A single repeated character, "000000000" or "xxxxxxxx", names no device
  if (/^(.)\1*$/.test(normalised.replace(/ /g, ""))) return ""

  return trimmed
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
  if ((value = unsigned(metric, "swap.total")) !== null) hardware.swapTotalBytes = value
  if ((value = unsigned(metric, "swap.used")) !== null) hardware.swapUsedBytes = value

  // The agent already works the percentage out; taking it rather than dividing
  // again keeps the panel saying what the platform was told
  if ((value = percent(metric, "cpu.used_percent")) !== null) hardware.cpuUsedPercent = value

  // A load average only means something next to the number of cores, which the
  // snapshot does not carry, so it is reported and never given a tone
  var load = [number(metric, "cpu.load1"), number(metric, "cpu.load5"), number(metric, "cpu.load15")]
  if (load[0] !== null) hardware.cpuLoad = load.filter(function(one) { return one !== null })

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

// One entry per interface of the net input. `speed` is the link speed in
// megabits, and -1 where the driver does not report one (wireless, tunnels).
function applyInterface(status, metric) {
  var name = metric.tags.interface

  if (!name) return

  var existing = status.interfaces.filter(function(one) { return one.name === name })[0]
  if (existing && existing.collectedAtMs > metric.time) return

  var link = integer(metric, "speed")
  var entry = {
    name: name,
    collectedAtMs: metric.time,
    collectedAt: isoTime(metric.time),
    bytesReceived: unsigned(metric, "bytes_recv") || 0,
    bytesSent: unsigned(metric, "bytes_sent") || 0,
    packetsReceived: unsigned(metric, "packets_recv") || 0,
    packetsSent: unsigned(metric, "packets_sent") || 0,
    dropsIn: unsigned(metric, "drop_in") || 0,
    dropsOut: unsigned(metric, "drop_out") || 0,
    errorsIn: unsigned(metric, "err_in") || 0,
    errorsOut: unsigned(metric, "err_out") || 0
  }

  if (link !== null && link >= 0) entry.linkMegabits = link

  if (existing) status.interfaces[status.interfaces.indexOf(existing)] = entry
  else status.interfaces.push(entry)
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
    interfaces: [],
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
    if (metric.tags.host && !status.device.serial) status.device.serial = identifier(metric.tags.host)

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
    case "net":
      applyInterface(status, metric)
      break
    case "display":
      var count = integer(metric, "display.count")
      if (count !== null) status.hardware.displayCount = count
      break
    case "temp":
      var reading = usableTemperature(metric)
      if (reading !== null && (status.hardware.temperatureCelsius === undefined || reading > status.hardware.temperatureCelsius))
        status.hardware.temperatureCelsius = reading
      break
    }
  }

  for (var name in latest) status.inputs.push({ measurement: name, collectedAt: isoTime(latest[name]) })

  status.interfaces.sort(function(a, b) { return a.name < b.name ? -1 : (a.name > b.name ? 1 : 0) })

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
    usableTemperature: usableTemperature,
    identifier: identifier,
    waiting: waiting,
    build: build
  }
}
