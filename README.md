# HTB Writeups

Penetration-testing writeups for **retired** Hack The Box machines. Each box is
worked from a hand-written `notes.md`; a Claude Code agent (`/writeup`) renders
it into a Typst PDF. Findings are cross-referenced to my field-manual procedure
IDs (P0–P9) so the collection reads as methodology, not walkthroughs.

> Only retired machines are published, per HTB's content-sharing rules. Flag
> values are omitted from every writeup.

## Workflow

```bash
# 1. start a box
cp -r template/machine-skeleton machines/<name>   # or just make the folder + copy notes.skeleton.md
# 2. fill machines/<name>/notes.md as you work
# 3. generate + build the PDF
/writeup <name>            # in Claude Code, from the repo root
# 4. refresh this index
python3 scripts/htb.py index
```

`scripts/htb.py check <name>` runs the retirement gate and flag scan on their
own (also wired into CI). `scripts/htb.py build <name>` checks then compiles.

## Machines

<!--INDEX-->
| Machine | OS | Difficulty | Retired | Tags |
|---|---|---|---|---|
| [Example](machines/example/writeup.pdf) | Linux | Easy | 2024-06-15 |  |
<!--/INDEX-->

## Layout

```
machines/<name>/notes.md     # the only hand-written file
machines/<name>/evidence/    # screenshots, scan output
machines/<name>/writeup.typ  # generated
machines/<name>/writeup.pdf  # built
template/lib.typ             # Typst template + helpers
scripts/htb.py               # guardrails + index
```
