// A fresh install has no settings file, so whatever the panel passes down is
// what the sign-in gets. Twice the panel handed Session an empty string, which
// is a value and wins over the shipped default, leaving the footer reporting
// itself unconfigured with a client id sitting unused one file away. CI could
// not see it: no test exercises the QML.
//
// The shipped values now live in Config.js, which QML imports and Node can
// require, so most of this is structural. What has to stay textual is the
// binding in Panel.qml and the helper's own defaults, since neither is
// JavaScript — those two checks are blunt and a rename would slip past them.
const { test } = require("node:test")
const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")

const read = name => fs.readFileSync(path.join(__dirname, "..", name), "utf8")
const Config = require("./load")("Config.js")
const session = read("Session.qml")
const panel = read("Panel.qml")
const helper = read("bin/pulzar-auth")

test("the shipped values are present and non-empty", () => {
  for (const name of ["CLIENT_ID", "ISSUER", "CONSENT_ORIGIN", "SCOPE"]) {
    assert.equal(typeof Config[name], "string", `${ name } is missing`)
    assert.notEqual(Config[name].trim(), "", `${ name } is empty`)
  }
})

test("the two origins stay distinct", () => {
  // Collapsing them sends the browser to the API, which answers the authorize
  // request with JSON instead of a consent page
  assert.notEqual(Config.ISSUER, Config.CONSENT_ORIGIN)
})

test("a fresh install is configured", () => {
  // `configured` is what gates the Sign in button
  assert.match(session, /readonly property bool configured: root\.clientId !== ""/)
  assert.match(session, /readonly property string defaultClientId: Config\.CLIENT_ID/)
  assert.match(session, /property string clientId: root\.defaultClientId/)
})

test("the panel never hands down an empty value", () => {
  // pulzar.setting(name, "") returns "" when no setting exists, so each
  // binding has to fall back to the shipped value
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

test("the helper's own defaults agree with the shipped ones", () => {
  // The helper has to work when run directly, with no QML around it, so it
  // carries its own copy. Copies drift; this is the check that they have not.
  for (const [constant, expected] of [
    ["ISSUER", Config.ISSUER],
    ["CONSENT_ORIGIN", Config.CONSENT_ORIGIN],
    ["SCOPE", Config.SCOPE],
  ]) {
    const found = helper.match(new RegExp(`^${ constant } = "([^"]*)"`, "m"))
    assert.ok(found, `${ constant } is missing from bin/pulzar-auth`)
    assert.equal(found[1], expected, `${ constant } has drifted from Config.js`)
  }
})
