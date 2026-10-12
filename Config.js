.pragma library

// The shipped identity of this plugin, in one place that both sides can read.
//
// These used to live in QML only, which meant the test asserting them had to
// read QML as text — blunt enough that a rename would slip past it. A .js
// library is imported by QML and required by Node, so the invariant "a fresh
// install is configured" can be checked structurally instead.
//
// The sign-in helper carries the same values as its own defaults, because it
// has to work when run directly with no QML around it. That is a second copy,
// and copies drift, so a test asserts the two agree rather than trusting them
// to.

// One application, registered once by rzilient, whose client id ships inside
// every copy of this plugin. Not a secret: it identifies the software, never
// the customer or the machine, and PKCE is what makes each individual
// authorization unforgeable.
var CLIENT_ID = "pEeZFwYxLM4lUsc24FWs7GTM1d9zF6K6u7A1KI4ZwDo"

// One authorization server, two origins. Machine-to-machine calls — the token
// and refresh exchanges — go to the API. The person approving goes to the
// dashboard: the API answers /oauth/authorize with JSON for a React consent
// card to consume, so a browser sent there sees a payload, not a consent
// screen.
var ISSUER = "https://api.rzilient.tech"
var CONSENT_ORIGIN = "https://join.rzilient.club"

// The application is a device_agent, whose only permitted scope is this one.
// It is not a smaller external_api: a device_self token is refused by
// /api/external/v1/* on purpose.
var SCOPE = "device_self"

if (typeof module !== "undefined") {
  module.exports = {
    CLIENT_ID: CLIENT_ID,
    ISSUER: ISSUER,
    CONSENT_ORIGIN: CONSENT_ORIGIN,
    SCOPE: SCOPE
  }
}
