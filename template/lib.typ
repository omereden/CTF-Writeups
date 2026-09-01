// ============================================================
//  HTB writeup template — "dashboard cover + narrative"
//  Usage in machines/<n>/writeup.typ:
//    #import "../../template/lib.typ": *
//    #show: htb-writeup.with(machine: "Foo", ...)
//
//  To flip the accent to HTB-native green, set:  #let accent = htb-green
// ============================================================

// ---------- design tokens ----------
#let accent    = rgb("#1f6feb")   // single accent: rules, captions, procedures
#let htb-green = rgb("#9fef00")   // available if you prefer the HTB-native accent
#let ink       = rgb("#111318")
#let muted     = rgb("#5b6270")
#let faint     = rgb("#a9b0ba")
#let rule-col  = rgb("#dfe3e8")
#let zebra-col = rgb("#f7f8f9")
#let code-bg   = rgb("#1a1d23")
#let code-fg   = rgb("#e6e9ee")
#let body-col  = rgb("#3c424c")
#let amber     = rgb("#b07d00")
#let flag-bg   = rgb("#eef4fe")
#let flag-brd  = rgb("#bcd4f7")
#let flag-ink  = rgb("#14354a")
#let hdr-label = rgb("#6cb2ff")

#let sans = ("Inter", "Helvetica Neue", "Helvetica", "Arial", "DejaVu Sans")
#let mono = ("JetBrains Mono", "Fira Code", "Menlo", "DejaVu Sans Mono")

#let difficulty-color(d) = {
  let k = lower(d)
  if k == "easy" { rgb("#2f8f4e") }
  else if k == "medium" { amber }
  else if k == "hard" { rgb("#c23b3b") }
  else if k == "insane" { rgb("#7d4fc2") }
  else { muted }
}

// ---------- labels ----------
#let kicker(s) = text(font: sans, size: 8.5pt, weight: 600, fill: muted, tracking: 1.8pt)[#upper(s)]
#let mlabel(s) = text(font: mono, size: 7.5pt, weight: 500, fill: muted, tracking: 1.4pt)[#upper(s)]

#let pill(label, fill: muted) = box(
  fill: fill.lighten(85%), stroke: 0.5pt + fill.darken(5%), radius: 3pt,
  inset: (x: 6pt, y: 3pt),
  text(size: 8pt, weight: 600, fill: fill.darken(30%), label),
)

// ---------- content helpers (use these in the body) ----------

// Command block with a caption bar. The cheatsheet unit.
#let cmd(caption, code, lang: "bash") = block(breakable: false, width: 100%, below: 13pt, {
  if caption != none and caption != "" {
    block(width: 100%, fill: accent, inset: (x: 14pt, y: 8pt), radius: (top: 5pt),
      text(font: mono, size: 8pt, fill: white, weight: 700, tracking: 1.2pt)[#upper(caption)])
  }
  block(width: 100%, fill: code-bg, inset: (x: 14pt, y: 13pt),
    radius: if caption != none and caption != "" { (bottom: 5pt) } else { 5pt },
    text(font: mono, size: 9pt, fill: code-fg, raw(code, lang: lang, block: true)))
})

// Screenshot / scan output from evidence/. Pass the image so the path resolves
// relative to the WRITEUP file:  #ev(image("evidence/nmap.png"), caption: [...])
#let ev(img, caption: none) = figure(img, caption: caption)

#let callout(body, title: "Note", accent-col: accent, title-col: ink, glyph: "✓") = block(
  width: 100%, below: 13pt, stroke: (left: 3pt + accent-col), inset: (left: 15pt, y: 2pt),
  {
    text(font: mono, size: 8pt, weight: 700, tracking: 1.4pt, fill: title-col)[#glyph #h(2pt) #upper(title)]
    v(7pt)
    text(size: 9.5pt, fill: body-col, body)
  })

#let note(body)   = callout(body, title: "Note", accent-col: accent, title-col: ink, glyph: "✓")
#let gotcha(body) = callout(body, title: "Gotcha", accent-col: amber, title-col: amber, glyph: "⚠")
#let detect(body) = callout(body, title: "Detection", accent-col: rgb("#2f6fbf"), title-col: rgb("#2f6fbf"), glyph: "◆")

#let flag(kind) = box(
  stroke: (dash: "dashed", paint: faint, thickness: 0.6pt), radius: 5pt, inset: (x: 8pt, y: 5pt),
  text(font: mono, size: 8.5pt, fill: muted, kind + ": [redacted]"))

#let todo(body) = block(
  width: 100%, fill: rgb("#fdeaea"), stroke: 1pt + rgb("#c23b3b"), inset: 10pt, radius: 5pt, below: 13pt,
  text(size: 9pt, fill: rgb("#8b1f1f"), weight: 600, [TODO — ] + body))

// kill-chain ribbon. stages: array of (label, is-flag)
#let ribbon(stages) = {
  let cells = ()
  for (i, st) in stages.enumerate() {
    let (label, is-flag) = st
    cells.push(box(
      radius: 20pt, inset: (x: 9pt, y: 4pt),
      fill: if is-flag { flag-bg } else { white },
      stroke: 0.6pt + if is-flag { flag-brd } else { rule-col },
      text(font: mono, size: 7.5pt, tracking: 0.8pt, fill: if is-flag { flag-ink } else { ink })[#if is-flag [⚑ ]#upper(label)],
    ))
    if i < stages.len() - 1 { cells.push(text(size: 8pt, fill: faint)[→]) }
  }
  stack(dir: ltr, spacing: 7pt, ..cells)
}

// attack-path table. steps: array of (stage, technique, result)
#let chain-table(steps) = table(
  columns: (22%, 1fr, 30%),
  inset: (x: 14pt, y: 10pt),
  stroke: (x, y) => if y > 0 { (bottom: 0.5pt + rule-col) },
  fill: (_, y) => if y == 0 { ink } else if calc.odd(y) { zebra-col } else { white },
  table.header(
    ..("Stage", "Technique", "Result").map(h =>
      text(font: mono, fill: hdr-label, size: 7.5pt, weight: 500, tracking: 1.4pt)[#upper(h)]),
  ),
  ..steps.map(s => (
    text(size: 9pt, weight: 600, s.at(0)),
    text(size: 9pt, s.at(1)),
    text(font: mono, size: 8.5pt, fill: muted, s.at(2)),
  )).flatten(),
)

// cover stat tile
#let stat-tile(label, value, value-col: ink) = block(
  width: 100%, stroke: 0.5pt + rule-col, radius: 6pt, inset: (x: 14pt, top: 13pt, bottom: 15pt),
  { mlabel(label); v(9pt); text(size: 18pt, weight: 700, fill: value-col, value) })

#let metacol(label, value, is-mono: false, col: ink) = stack(spacing: 7pt,
  mlabel(label),
  if is-mono { text(font: mono, size: 9pt, fill: col, value) } else { text(size: 10pt, fill: col, value) })

// ---------- main template ----------
#let htb-writeup(
  machine: "",
  os: "",
  difficulty: "",
  points: none,
  ip: "",
  released: none,
  retired: none,
  author: "0x3d3n",
  tags: (),
  procedures: (),
  summary: none,
  chain: (),
  killchain: auto,
  body,
) = {
  set document(title: machine + " — HTB Writeup", author: author)
  set page(
    paper: "a4",
    margin: (x: 1.5cm, top: 1.5cm, bottom: 1.3cm),
    header: context {
      let n = counter(page).get().first()
      if n > 1 {
        grid(columns: (1fr, auto), align: (left, right),
          mlabel(machine + " · " + ip),
          text(font: mono, size: 8pt, fill: muted, tracking: 1.4pt)[#if n < 10 [0]#str(n)])
        v(3pt)
        line(length: 100%, stroke: 0.5pt + rule-col)
      }
    },
  )
  set text(font: sans, size: 10pt, fill: ink, lang: "en")
  set par(justify: true, leading: 0.72em, spacing: 1.15em)
  set heading(numbering: none)

  show heading.where(level: 1): it => block(above: 22pt, below: 14pt, {
    text(size: 22pt, weight: 800, it.body)
    v(8pt)
    box(width: 46pt, height: 3pt, fill: accent)
    box(width: 100% - 46pt, height: 3pt, fill: rgb("#eef1f4"))
  })
  show heading.where(level: 2): it => block(below: 9pt, above: 15pt,
    text(size: 13pt, weight: 700, fill: ink, it.body))
  show heading.where(level: 3): it => block(below: 7pt, above: 12pt,
    text(size: 10.5pt, weight: 700, fill: muted.darken(20%), it.body))

  show raw.where(block: false): it => box(fill: rgb("#f0f2f5"), inset: (x: 3pt, y: 1pt),
    outset: (y: 2pt), radius: 2pt, text(font: mono, size: 8.5pt, it))
  show link: it => text(fill: accent, it)
  show figure.caption: it => text(size: 8pt, fill: muted, it)

  // ================= COVER =================
  grid(columns: (1fr, auto), align: (left, right), column-gutter: 30pt,
    stack(spacing: 14pt,
      kicker("Hack The Box · Machine Writeup"),
      context {
        let nm = text(size: 40pt, weight: 800, machine)
        stack(spacing: 9pt, nm, box(width: measure(nm).width, height: 3pt, fill: accent))
      },
    ),
    text(font: mono, size: 9pt)[#ip \ #text(fill: muted)[#if retired != none [retired #retired]]],
  )

  if summary != none { v(26pt); block(width: 80%, text(size: 12.5pt, summary)) }

  v(26pt)
  grid(columns: (1fr,) * 4, column-gutter: 12pt,
    stat-tile("Difficulty", difficulty, value-col: difficulty-color(difficulty)),
    stat-tile("Points", if points != none { str(points) } else { "—" }),
    stat-tile("OS", os),
    stat-tile("Steps", if chain.len() > 0 { str(chain.len()) } else { "—" }),
  )

  let kc = if killchain == auto { chain.map(s => (s.at(0), false)) } else { killchain }
  if kc.len() > 0 { v(26pt); ribbon(kc) }

  if chain.len() > 0 { v(26pt); kicker("Attack Path"); v(11pt); chain-table(chain) }

  v(1fr)
  block(width: 100%, stroke: (top: 0.5pt + rule-col), inset: (top: 15pt),
    grid(columns: (1.15fr, 1.15fr, 0.7fr), column-gutter: 22pt,
      metacol("Tags", if tags.len() > 0 { tags.join(" · ") } else { "—" }),
      metacol("Procedures", if procedures.len() > 0 { procedures.join(" · ") } else { "—" }, is-mono: true, col: accent),
      metacol("Author", author, is-mono: true),
    ))
  v(12pt)
  text(size: 8pt, style: "italic", fill: muted)[Published after machine retirement, per Hack The Box content-sharing rules. Flag values omitted.]

  pagebreak()
  body
}
