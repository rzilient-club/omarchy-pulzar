.pragma library

// How a timeline entry is drawn: which icon, which colour.
//
// The actions are Notification's enum in the backend — DevicesAction::ACTIONS
// plus the list beside it — and not the dashboard's own map, which differs:
// the dashboard carries `transfer`, which the backend cannot send, and omits
// `enterprise_wipe`, which it can.
//
// The list of actions grows server-side, so anything unrecognised falls back
// to a neutral dot rather than being dropped — a history with a silent hole in
// it is worse than one with a generic marker, because nothing tells the reader
// an event is missing.

var FALLBACK = { icon: "\u{F02FC}", tone: "default" }

var ACTIONS = {
  create:      { icon: "\u{F0415}", tone: "success" },
  update:      { icon: "\u{F03EB}", tone: "info" },
  destroy:     { icon: "\u{F0A7A}", tone: "error" },
  list:        { icon: "\u{F0279}", tone: "default" },
  activate:    { icon: "\u{F0E1E}", tone: "success" },
  upload:      { icon: "\u{F0552}", tone: "info" },
  invite:      { icon: "\u{F0014}", tone: "info" },
  confirm:     { icon: "\u{F012C}", tone: "success" },
  approve:     { icon: "\u{F012C}", tone: "success" },
  complete:    { icon: "\u{F0E1E}", tone: "success" },
  assign_to:   { icon: "\u{F0004}", tone: "info" },
  rescheduled: { icon: "\u{F00F0}", tone: "warning" },
  cancel:      { icon: "\u{F0156}", tone: "error" },
  override:    { icon: "\u{F0450}", tone: "warning" },
  security:    { icon: "\u{F0483}", tone: "info" },
  mismatch:    { icon: "\u{F0028}", tone: "warning" },
  retire:      { icon: "\u{F0A79}", tone: "default" },
  repair:      { icon: "\u{F0862}", tone: "warning" },
  collected:   { icon: "\u{F012C}", tone: "success" },
  stolen:      { icon: "\u{F0099}", tone: "error" },
  wipe:        { icon: "\u{F01B4}", tone: "error" },
  // Not a lesser wipe: the same destructive treatment, because drawing it as
  // anything calmer understates about the most consequential thing that can
  // happen to a machine
  enterprise_wipe: { icon: "\u{F01B4}", tone: "error" },
  lock:        { icon: "\u{F033E}", tone: "warning" },
  reboot:      { icon: "\u{F0709}", tone: "info" },
  none:        { icon: "\u{F02FC}", tone: "default" },
  change_name: { icon: "\u{F03EB}", tone: "info" },
  lost_mode:   { icon: "\u{F0099}", tone: "warning" },
  processed:   { icon: "\u{F012C}", tone: "success" }
}

function appearance(action) {
  return ACTIONS[String(action || "")] || FALLBACK
}

if (typeof module !== "undefined") {
  module.exports = {
    ACTIONS: ACTIONS,
    FALLBACK: FALLBACK,
    appearance: appearance
  }
}
