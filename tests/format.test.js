const { test } = require("node:test")
const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const Format = require("./load")("Format.js")
const Locales = require("./load")("Locales.js")
const Snapshot = require("./load")("Snapshot.js")

const { en, fr } = Locales.translations
const status = () => Snapshot.build(
  Snapshot.parseSnapshot(fs.readFileSync(path.join(__dirname, "latest.lp"), "utf8")), "LAPTOP-01", 1759230000 * 1000)

test("formats sizes and percentages in the language", () => {
  assert.equal(Format.formatBytes(17179869184, en), "16.0 GB")
  assert.equal(Format.formatBytes(17179869184, fr), "16,0 Go")
  assert.equal(Format.formatBytes(0, en), en.unknown)
  assert.equal(Format.formatPercent(91.2, en), "91 %")
  assert.equal(Format.formatPercent(undefined, en), en.unknown)
  assert.equal(Format.formatTemperature(51.5, en), "52 °C")
})

test("computes the usage", () => {
  assert.equal(Format.usagePercent(1, 4), 25)
  assert.equal(Format.usagePercent(1, 0), 0)
  assert.equal(Format.usageTone(74), "secondary")
  assert.equal(Format.usageTone(75), "warning")
  assert.equal(Format.usageTone(90), "error")
})

test("formats dates", () => {
  const value = new Date(2025, 8, 30, 7, 5).toISOString()

  assert.equal(Format.formatDateTime(value, en), "30/09/2025 07:05")
  assert.equal(Format.formatTime(value, en), "07:05")
  assert.equal(Format.formatTime("", en), en.unknown)
})

test("filters programs ignoring the case and the accents", () => {
  const programs = [ { name: "Éditeur" }, { name: "Chrome" } ]

  assert.deepEqual(Format.filterPrograms(programs, " edit "), [ { name: "Éditeur" } ])
  assert.equal(Format.filterPrograms(programs, "").length, 2)
})

test("summarizes the agent", () => {
  assert.equal(Format.statusSummary(status(), false, en).tone, "success")
  assert.equal(Format.statusSummary(status(), true, en).label, en.connectionInterrupted)
  assert.equal(Format.statusSummary(undefined, false, en).label, en.agentWaiting)
})

test("builds the support information", () => {
  const text = Format.supportInformation(status(), en)

  assert.match(text, /^Pulzar - Support information\n/)
  assert.match(text, /\nSerial number: SERIAL01\n/)
  assert.match(text, /\nMemory: 9\.0 GB used of 16\.0 GB\n/)
  assert.match(text, /\nBattery condition: Excellent\n/)
  assert.match(text, /\n {2}Disk encryption: Enabled\n/)
  assert.match(text, /\n {2}Installed programs: 3\n/)
  assert.match(text, /\nConnected displays: 2\n/)
  assert.match(text, /\nAgent status: Telemetry active\n/)
})

// The agent's Linux probe never finds LUKS and reports every machine as
// unencrypted, so the panel verifies it and passes the answer through here.
test("the support text prefers the verified encryption over the reported one", () => {
  const line = verified => Format.supportInformation(status(), en, verified)
    .split("\n").find(l => l.includes(en.diskEncryption))

  // The fixture's agent reports an encrypted disk, so the override is only
  // proven by the case that contradicts it
  assert.match(line(false), /Disabled$/)
  assert.match(line(true), /Enabled$/)
  // Nothing verified: whatever the agent said stands
  assert.match(line(undefined), /Enabled$/)
})
