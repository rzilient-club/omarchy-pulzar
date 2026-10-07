const { test } = require("node:test")
const assert = require("node:assert/strict")
const Locales = require("./load")("Locales.js")

test("every language defines every label of English", () => {
  const english = Locales.translations.en

  for (const option of Locales.languageOptions) {
    const labels = Locales.translations[option.id]

    for (const key of Object.keys(english)) {
      assert.equal(typeof labels[key], typeof english[key], `${ option.id }.${ key }`)
    }

    for (const key of Object.keys(english.inputNames)) assert.ok(labels.inputNames[key], `${ option.id }.inputNames.${ key }`)
  }
})

test("normalizes locale identifiers", () => {
  const cases = {
    "en": "en", "en-US": "en", "es-ES": "es", "ES": "es", "ca_ES.UTF-8": "ca",
    "ca-ES-valencia": "ca", "fr_FR@euro": "fr", "de-DE": "en", "C": "en", "": "en",
  }

  for (const [ identifier, expected ] of Object.entries(cases)) assert.equal(Locales.normalize(identifier), expected, identifier)
})

test("picks the first supported preference", () => {
  assert.equal(Locales.fromPreferences([ "de-DE", "ca-ES", "es-ES" ]), "ca")
  assert.equal(Locales.fromPreferences([ "en-GB", "fr-FR" ]), "en")
  assert.equal(Locales.fromPreferences([ "C.UTF-8", "fr_FR.UTF-8" ]), "fr")
  assert.equal(Locales.fromPreferences([ "de-DE" ]), "en")
  assert.equal(Locales.fromPreferences([]), "en")
})

test("follows the POSIX precedence", () => {
  const env = values => name => values[name] || ""

  assert.equal(Locales.systemLanguage(env({ LANGUAGE: "de:es", LANG: "fr_FR.UTF-8" })), "es")
  assert.equal(Locales.systemLanguage(env({ LC_ALL: "ca_ES.UTF-8", LANG: "fr_FR.UTF-8" })), "ca")
  assert.equal(Locales.systemLanguage(env({ LANG: "fr_FR.UTF-8" })), "fr")
  assert.equal(Locales.systemLanguage(env({})), "en")
})
