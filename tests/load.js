// Loads a QML JavaScript resource in Node: drops its ".pragma library" line
const fs = require("node:fs")
const path = require("node:path")
const vm = require("node:vm")

module.exports = name => {
  const file = path.join(__dirname, "..", name)
  const source = fs.readFileSync(file, "utf8").replace(/^\.pragma library\s*$/m, "")
  const module = { exports: {} }
  vm.runInThisContext(`(function (module) {\n${ source }\n})`, { filename: file })(module)
  return module.exports
}
