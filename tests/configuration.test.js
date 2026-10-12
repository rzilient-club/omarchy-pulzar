// A fresh install has no settings file, so whatever the panel passes down is
// what the sign-in gets. Twice now the panel has handed Session an empty
// string, which is a value and wins over the shipped default, leaving the
// footer reporting itself unconfigured with a client id sitting unused one
// file away. CI could not see it: nothing here is JavaScript and the QML is
// not exercised by any test.
//
// So these read the QML as text. That is a blunt instrument and it will not
// notice a rename, but it does state the invariant — a fresh install is
// configured — somewhere a machine will check.
const { test } = require("node:test")
const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")

const read = name => fs.readFileSync(path.join(__dirname, "..", name), "utf8")
const session = read("Session.qml")
const panel = read("Panel.qml")

const shipped = name => {
  const found = session.match(new RegExp(`readonly property string ${ name }:\\s*"([^"]*)"`))
  return found && found[1]
}

test("the shipped values live in Session.qml and are not empty", () => {
  for (const name of ["defaultClientId", "defaultIssuer", "defaultConsentOrigin"]) {
    const value = shipped(name)
    assert.ok(value, `${ name } is missing from Session.qml`)
    assert.notEqual(value.trim(), "", `${ name } is empty`)
  }
})

test("a fresh install is configured", () => {
  // `configured` is what gates the Sign in button
  assert.match(session, /readonly property bool configured: root\.clientId !== ""/)
  assert.match(session, /property string clientId: root\.defaultClientId/)
})

test("the panel never hands down an empty value", () => {
  // Each binding must fall back to the shipped value, because
  // pulzar.setting(name, "") returns "" when no setting exists
  for (const [property, fallback] of [
    ["clientId", "defaultClientId"],
    ["issuer", "defaultIssuer"],
    ["consentOrigin", "defaultConsentOrigin"],
  ]) {
    const line = panel.split("\n").find(l => l.trim().startsWith(`${ property }:`) && l.includes("pulzar.setting"))
    assert.ok(line, `${ property } is not bound to a setting in Panel.qml`)
    assert.ok(line.includes(`session.${ fallback }`),
      `${ property } can be handed an empty string: ${ line.trim() }`)
  }
})

test("the two origins stay distinct", () => {
  // Collapsing them sends the browser to the API, which answers the authorize
  // request with JSON instead of a consent page
  assert.notEqual(shipped("defaultIssuer"), shipped("defaultConsentOrigin"))
})
