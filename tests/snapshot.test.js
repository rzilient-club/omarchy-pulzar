// Same cases as the Go tests of the tray application's status package
const { test } = require("node:test")
const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const Snapshot = require("./load")("Snapshot.js")

const snapshotTime = 1759230000 * 1000
const fixture = () => Snapshot.parseSnapshot(fs.readFileSync(path.join(__dirname, "latest.lp"), "utf8"))

test("parses the snapshot", () => {
  const snapshot = fixture()

  assert.equal(snapshot.running, true)
  assert.equal(snapshot.staleAfterMs, 30 * 60 * 1000)
  assert.equal(snapshot.writtenAt, snapshotTime)
  assert.equal(snapshot.metrics.length, 5)

  const system = snapshot.metrics[1]
  assert.equal(system.name, "system")
  assert.equal(system.tags.host, "SERIAL01")
  assert.equal(system.fields["ram.total"], 17179869184)
  assert.equal(system.kinds["ram.total"], "uint")
})

test("requires the header line", () => {
  assert.throws(() => Snapshot.parseSnapshot("system,host=A ram.used=1u 1\n"))
})

test("rejects invalid lines", () => {
  assert.throws(() => Snapshot.parseSnapshot("systray_snapshot running=true 1\nnot line protocol\n"))
})

test("unescapes tags, keys and strings", () => {
  const metric = Snapshot.parseLine('sysinfo,host=DEFAULT\\ STRING,a\\,b=c\\=d key\\ x="say \\"hi\\" \\\\ ok",n=-3i,f=1.5e3,b=F 1759230000123456789')

  assert.equal(metric.tags.host, "DEFAULT STRING")
  assert.equal(metric.tags["a,b"], "c=d")
  assert.equal(metric.fields["key x"], 'say "hi" \\ ok')
  assert.deepEqual([ metric.fields.n, metric.kinds.n ], [ -3, "int" ])
  assert.deepEqual([ metric.fields.f, metric.kinds.f ], [ 1500, "float" ])
  assert.deepEqual([ metric.fields.b, metric.kinds.b ], [ false, "bool" ])
  assert.equal(metric.time, 1759230000123)
})

test("builds the status", () => {
  const status = Snapshot.build(fixture(), "LAPTOP-01", snapshotTime)

  assert.equal(status.availability, "active")
  assert.deepEqual(status.device, { name: "LAPTOP-01", serial: "SERIAL01" })
  assert.equal(status.hardware.ramTotalBytes, 17179869184)
  assert.equal(status.hardware.ramUsedBytes, 9663676416)
  assert.equal(status.hardware.storageTotalBytes, 512110190592)
  assert.equal(status.hardware.storageUsedBytes, 201863462912)
  assert.deepEqual(status.hardware.battery, { condition: "excellent", chargePercent: 87.5, healthPercent: 91.2 })
  assert.equal(status.hardware.displayCount, 2)
  // The highest of all the sensors
  assert.equal(status.hardware.temperatureCelsius, 51.5)
  assert.deepEqual(status.inputs, [
    { measurement: "display", collectedAt: "2025-09-30T10:50:00Z" },
    { measurement: "sysinfo", collectedAt: "2025-09-30T10:43:20Z" },
    { measurement: "system", collectedAt: "2025-09-30T10:50:00Z" },
    { measurement: "temp", collectedAt: "2025-09-30T10:50:00Z" },
  ])
  assert.equal(status.observedAt, "2025-09-30T10:50:00Z")
})

test("reads the computer", () => {
  const computer = Snapshot.build(fixture(), "", snapshotTime).computer

  assert.equal(computer.operatingSystem, "Microsoft Windows 11 Pro")
  assert.equal(computer.version, "10.0.22631 Build 22631")
  assert.equal(computer.family, "Standalone Workstation")
  assert.equal(computer.platform, "windows")
  assert.equal(computer.architecture, "amd64")
  assert.equal(computer.processor, "Intel(R) Core(TM) i7-1185G7")
  assert.equal(computer.memoryBytes, 17179869184)
  assert.equal(computer.storageBytes, 512110190592)
  assert.equal(computer.encrypted, true)
  assert.deepEqual(computer.graphics, [ { vendor: "Intel Corporation", product: "Iris Xe Graphics" } ])
  assert.equal(computer.manufacturingDate, "2021-04-12")
  assert.equal(computer.agentVersion, "0.22.5")
  assert.equal(computer.collectedAt, "2025-09-30T10:43:20Z")
  // Sorted by name, ignoring the case
  assert.deepEqual(computer.programs, [
    { name: "7-Zip", version: "24.08" },
    { name: "adobe Reader", version: "24.1" },
    { name: "Google Chrome", version: "129.0" },
  ])
})

test("lists programs given as names", () => {
  const snapshot = Snapshot.parseSnapshot('systray_snapshot running=true 1\nsysinfo programs="[\\"b\\", \\"A\\"]" 1000000000\n')
  const computer = Snapshot.build(snapshot, "", 1000).computer

  assert.deepEqual(computer.programs, [ { name: "A", version: "" }, { name: "b", version: "" } ])
  assert.equal(computer.encrypted, undefined)
})

test("computes the availability", () => {
  const collected = snapshotTime - 10 * 60 * 1000
  const metrics = [ { name: "system", tags: {}, fields: {}, kinds: {}, time: collected } ]
  const staleAfterMs = 30 * 60 * 1000

  assert.equal(Snapshot.build({ running: true, staleAfterMs, metrics }, "", snapshotTime).availability, "active")
  assert.equal(Snapshot.build({ running: true, staleAfterMs, metrics }, "", collected + 31 * 60 * 1000).availability, "stale")
  assert.equal(Snapshot.build({ running: false, staleAfterMs, metrics }, "", snapshotTime).availability, "stopped")
  assert.equal(Snapshot.build({ running: true, staleAfterMs, metrics: [] }, "", snapshotTime).availability, "waiting")
})

// Line protocol has no infinity: an out of range charge stands for the 0 capacity of the first boot
test("ignores invalid battery values", () => {
  const snapshot = Snapshot.parseSnapshot("systray_snapshot running=true 1\nsystem batteries.0.current=150,batteries.0.health=100 1000000000\n")
  assert.deepEqual(Snapshot.build(snapshot, "", 1000).hardware.battery, { condition: "excellent", healthPercent: 100 })

  const withoutBattery = Snapshot.parseSnapshot("systray_snapshot running=true 1\nsystem ram.total=1u 1000000000\n")
  assert.equal(Snapshot.build(withoutBattery, "", 1000).hardware.battery, undefined)
})

test("classifies the battery condition", () => {
  const cases = { 95: "excellent", 90: "excellent", 85: "very_good", 75: "good", 69.9: "poor" }

  for (const [ health, expected ] of Object.entries(cases)) assert.equal(Snapshot.batteryCondition(Number(health)), expected)
})

// A Super I/O chip answers for every channel it exposes, connected or not:
// the idle TSI channels of an nct6793 all report 3892313.987, and the spare
// SYSTIN/AUXTIN thermistor inputs float around a plausible hundred degrees.
// Taken at face value they win the maximum and the panel shows a temperature
// no component ever reached.
const temperatures = sensors => Snapshot.parseSnapshot([
  "systray_snapshot running=true,stale_after=1800i 1759230000000000000",
  ...sensors.map(([sensor, value]) =>
    `temp,host=SERIAL01,sensor=${ sensor } temp=${ value } 1759229400000000000`),
].join("\n"))

const highest = sensors =>
  Snapshot.build(temperatures(sensors), "", snapshotTime).hardware.temperatureCelsius

test("ignores the placeholder of an unconnected sensor", () => {
  assert.equal(highest([
    ["k10temp_tctl", 62.25],
    ["nct6793_tsi0_temp", 69.625],
    ["nct6793_tsi2_temp", 3892313.987],
  ]), 69.625)
})

test("ignores the spare thermistor inputs of the Super I/O chip", () => {
  assert.equal(highest([
    ["k10temp_tctl", 62.25],
    ["nct6793_systin", 113],
    ["nct6793_auxtin1", 108],
    ["nct6793_auxtin0", 48],
  ]), 62.25)
})

test("keeps a sensor whose name merely contains a dropped one", () => {
  assert.equal(highest([["auxtin_board", 70], ["systin_extra", 71]]), 71)
})

test("keeps a reading at the edge of the plausible range", () => {
  assert.equal(highest([["coretemp_package_id_0", 150]]), 150)
  assert.equal(highest([["ambient", -40]]), -40)
})

test("reports no temperature when every sensor is unusable", () => {
  const status = Snapshot.build(temperatures([
    ["nct6793_tsi2_temp", 3892313.987],
    ["nct6793_systin", 113],
  ]), "", snapshotTime)

  assert.equal(status.hardware.temperatureCelsius, undefined)
})

// The agent tags every metric with the serial number it read from the DMI
// tables, placeholder included.
const serialOf = host => Snapshot.build(Snapshot.parseSnapshot([
  "systray_snapshot running=true,stale_after=1800i 1759230000000000000",
  `display,host=${ host } display.count=1i 1759229400000000000`,
].join("\n")), "", snapshotTime).device.serial

test("reports no serial number when the vendor left the DMI template", () => {
  assert.equal(serialOf("To\\ Be\\ Filled\\ By\\ O.E.M."), "")
  assert.equal(serialOf("Default\\ string"), "")
  assert.equal(serialOf("System\\ Serial\\ Number"), "")
  assert.equal(serialOf("Not\\ Specified"), "")
})

test("reports no serial number for a value that identifies nothing", () => {
  assert.equal(Snapshot.identifier("N/A"), "")
  assert.equal(Snapshot.identifier("n.a."), "")
  assert.equal(Snapshot.identifier("00000000"), "")
  assert.equal(Snapshot.identifier("xxxxxxxx"), "")
  assert.equal(Snapshot.identifier("0123456789"), "")
  assert.equal(Snapshot.identifier("...."), "")
  assert.equal(Snapshot.identifier("   "), "")
  assert.equal(Snapshot.identifier(undefined), "")
})

test("keeps a real serial number, trimmed", () => {
  assert.equal(serialOf("SERIAL01"), "SERIAL01")
  assert.equal(Snapshot.identifier("  C02XK1JPJG5H  "), "C02XK1JPJG5H")
  // Only the whole value is a placeholder, never a part of one
  assert.equal(Snapshot.identifier("OEM-4417-22"), "OEM-4417-22")
  assert.equal(Snapshot.identifier("None-77A"), "None-77A")
})

// The snapshot carries the processor, the swap and a net measurement per
// interface, none of which the panel used to read.
const systemLine = fields => Snapshot.parseSnapshot([
  "systray_snapshot running=true,stale_after=1800i 1759230000000000000",
  `system,host=SERIAL01 ${ fields } 1759229400000000000`,
].join("\n"))

test("reads the processor usage and the load average", () => {
  const hardware = Snapshot.build(systemLine(
    "cpu.used_percent=6.35,cpu.load1=3.93,cpu.load5=2.41,cpu.load15=2.2"), "", snapshotTime).hardware

  assert.equal(hardware.cpuUsedPercent, 6.35)
  assert.deepEqual(hardware.cpuLoad, [3.93, 2.41, 2.2])
})

test("reads the swap", () => {
  const hardware = Snapshot.build(systemLine(
    "swap.total=58581368832u,swap.used=5003919360u"), "", snapshotTime).hardware

  assert.equal(hardware.swapTotalBytes, 58581368832)
  assert.equal(hardware.swapUsedBytes, 5003919360)
})

test("ignores a processor usage outside the percentage range", () => {
  const hardware = Snapshot.build(systemLine("cpu.used_percent=135"), "", snapshotTime).hardware
  assert.equal(hardware.cpuUsedPercent, undefined)
})

test("reports no load average when the agent sent none", () => {
  const hardware = Snapshot.build(systemLine("ram.total=16u"), "", snapshotTime).hardware
  assert.equal(hardware.cpuLoad, undefined)
})
