---
description: Generate a Typst HTB writeup from a machine's notes.md and build the PDF
argument-hint: <machine-folder-name>
allowed-tools: Read, Write, Edit, Bash(typst:*), Bash(ls:*), Glob
---

You are generating a Hack The Box writeup PDF for the machine in
`machines/$1/`. Work only inside that folder and the shared `template/`.

## Hard rules — violating any of these means STOP, do not build

1. **Retirement gate.** Read `machines/$1/notes.md` frontmatter. If `retired:`
   is empty, missing, or a date in the future, STOP and tell the user the box
   is not confirmed retired. HTB permits publishing solutions only for retired
   content, and "expired" is not "retired." Do not generate anything.
2. **No invention.** Only use facts present in `notes.md` and files under
   `machines/$1/evidence/`. Never add a port, CVE, credential, command, or step
   that is not in the notes. If a section is thin, leave it thin.
3. **No flags.** Never render a flag value even if one appears in the notes.
   Emit `#flag("user")` / `#flag("root")` instead. If you see a 32-hex string
   that looks like a flag, redact it and warn the user.
4. **Gaps are visible, not silent.** Where the notes are missing something a
   reader needs (e.g. how a credential was obtained), emit a `#todo[...]` block
   naming the gap rather than papering over it or guessing.

## Steps

1. Read `template/lib.typ` to confirm the current helper signatures
   (`cmd`, `ev`, `note`, `gotcha`, `detect`, `flag`, `chain-table`, `todo`).
   Do not assume — read it, the template may have changed.
2. Read `machines/$1/notes.md` and `ls machines/$1/evidence/`.
3. Apply the retirement gate. Then map notes → template:
   - Frontmatter → `htb-writeup.with(...)` arguments.
   - `## Summary` → `summary:` (keep it to 1–2 sentences).
   - `## Chain` lines `Phase | Technique | Result` → `chain:` array. If absent,
     synthesize a minimal chain ONLY from steps explicitly described in the
     notes; otherwise omit `chain`.
   - `## Recon/Foothold/Privilege Escalation/etc.` → `= ` headings in narrative
     0xdf style: explain *why* each step follows, not just *what*. Preserve the
     author's dead-ends and reasoning — that is the value.
   - ` ```cmd ` blocks with a caption line above → `#cmd("caption", "...")`.
     Blocks without `cmd` tag stay as normal `raw` blocks.
   - `![[evidence/X]]` → `#ev(image("evidence/X"), caption: [...])`.
   - Any "gotcha"/"detection"/"note" aside → the matching callout helper.
4. Write `machines/$1/writeup.typ`. Never edit `notes.md`.
5. Build: `typst compile --root . machines/$1/writeup.typ machines/$1/writeup.pdf`
   The `--root .` is required — Typst sandboxes to the file's dir otherwise, and
   the `#import "../../template/lib.typ"` will fail without it.
6. On compile error: read the error, fix `writeup.typ` only, retry. Max 3
   attempts. If still failing, show the user the error and the offending lines —
   do not keep looping.
7. On success, report: pages built, any `#todo` gaps you emitted, and anything
   you redacted.

## Style

Narrative walkthrough (0xdf voice): first person, past tense, explains the
reasoning between steps. Terse where the notes are terse. Technical, no filler.
