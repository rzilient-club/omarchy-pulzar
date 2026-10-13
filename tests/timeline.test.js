// The action list grows server-side, so the thing worth holding is not which
// icon each action gets but that an unrecognised one still produces a row.
const { test } = require("node:test")
const assert = require("node:assert/strict")
const Timeline = require("./load")("Timeline.js")

// Every action the platform sends today
const KNOWN = [
  "create", "update", "destroy", "list", "activate", "upload", "invite",
  "confirm", "approve", "complete", "assign_to", "rescheduled", "cancel",
  "override", "security", "mismatch", "retire", "repair", "collected",
  "stolen", "wipe", "lock", "reboot", "transfer", "none", "change_name",
  "lost_mode", "processed",
]

const TONES = ["success", "info", "error", "warning", "grey"]

test("every action the platform sends has an appearance", () => {
  for (const action of KNOWN) {
    assert.ok(action in Timeline.ACTIONS, `${ action } is unmapped`)
  }
})

test("an action nobody has mapped still draws a row", () => {
  // Dropping it would leave a hole in a history with nothing saying so
  for (const unknown of ["a_brand_new_action", "", undefined, null, "CREATE"]) {
    const look = Timeline.appearance(unknown)
    assert.equal(look, Timeline.FALLBACK, `${ unknown } did not fall back`)
    assert.ok(look.icon)
    assert.ok(look.tone)
  }
})

test("every appearance has an icon and a tone the dashboard knows", () => {
  for (const [action, look] of Object.entries(Timeline.ACTIONS)) {
    assert.ok(look.icon && look.icon.length > 0, `${ action } has no icon`)
    assert.ok(TONES.includes(look.tone), `${ action } has tone ${ look.tone }`)
  }
})

test("destructive actions are not drawn as successes", () => {
  // A wiped or stolen machine reading green would be actively misleading
  for (const action of ["destroy", "stolen", "wipe", "cancel"]) {
    assert.notEqual(Timeline.appearance(action).tone, "success", action)
  }
})
