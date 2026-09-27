const plugin = require("tailwindcss/plugin")
const fs = require("fs")
const path = require("path")

// Classes `ph-<nome>` (regular) e `ph-<nome>-<peso>` (thin, light, bold, fill,
// duotone) — o mesmo nome dos arquivos em deps/phosphor/raw/<peso>/.
// Tamanho padrão 1em, como os ícones do iconify no Chatwoot: defina com size-*.
module.exports = plugin(function({matchComponents}) {
  let rawDir = path.join(__dirname, "../../deps/phosphor/raw")
  let values = {}

  fs.readdirSync(rawDir).forEach(weight => {
    fs.readdirSync(path.join(rawDir, weight)).forEach(file => {
      values[path.basename(file, ".svg")] = path.join(rawDir, weight, file)
    })
  })

  matchComponents({
    "ph": fullPath => {
      let content = fs.readFileSync(fullPath).toString().replace(/\r?\n|\r/g, "")
      return {
        "--ph-svg": `url('data:image/svg+xml;utf8,${encodeURIComponent(content)}')`,
        "-webkit-mask": "var(--ph-svg) no-repeat",
        "mask": "var(--ph-svg) no-repeat",
        "mask-size": "100% 100%",
        "background-color": "currentColor",
        "display": "inline-block",
        "vertical-align": "middle",
        "width": "1em",
        "height": "1em"
      }
    }
  }, {values})
})
