// The action list grows server-side, so the thing worth holding is not which
// icon each action gets but that an unrecognised one still produces a row.
const { test } = require("node:test")
const assert = require("node:assert/strict")
const Timeline = require("./load")("Timeline.js")

// Notification's enum in the backend: DevicesAction::ACTIONS plus the list
// declared beside it. Not the dashboard's map, which carries an action the
// backend cannot send and omits one it can.
const KNOWN = [
  "lock", "wipe", "enterprise_wipe", "change_name", "reboot", "lost_mode",
  "retire", "repair",
  "none", "create", "update", "destroy", "list", "activate", "upload",
  "invite", "confirm", "approve", "complete", "assign_to", "rescheduled",
  "cancel", "override", "security", "mismatch", "collected", "stolen",
  "processed",
]

const TONES = ["success", "info", "error", "warning", "grey"]

test("the map is exactly the actions the platform can send", () => {
  // Both directions. A missing action is a grey dot where a red one belongs;
  // an extra one is a claim about something that cannot arrive, and it is how
  // enterprise_wipe came to be absent in the first place — the list was taken
  // from the dashboard rather than from the enum.
  const mapped = Object.keys(Timeline.ACTIONS).sort()
  assert.deepEqual(mapped, [...KNOWN].sort())
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
  for (const action of ["destroy", "stolen", "wipe", "enterprise_wipe", "cancel"]) {
    assert.notEqual(Timeline.appearance(action).tone, "success", action)
  }
})
