#!/usr/bin/env python3
"""
htb.py — deterministic guardrails and index generation for the writeup repo.

  python3 scripts/htb.py check <machine>   # retirement gate + flag scan (exit!=0 on fail)
  python3 scripts/htb.py index             # regenerate README.md machine table
  python3 scripts/htb.py build <machine>   # check, then typst compile

No third-party deps. Frontmatter is parsed by hand to stay dependency-free.
"""
import sys, re, subprocess, datetime, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
MACHINES = ROOT / "machines"
FLAG_RE = re.compile(r"\b[0-9a-f]{32}\b", re.I)


def parse_frontmatter(md: str) -> dict:
    m = re.match(r"^---\n(.*?)\n---", md, re.S)
    if not m:
        return {}
    fm = {}
    for line in m.group(1).splitlines():
        if ":" not in line or line.strip().startswith("#"):
            continue
        k, _, v = line.partition(":")
        v = v.split("#", 1)[0].strip()
        if v.startswith("[") and v.endswith("]"):
            v = [x.strip() for x in v[1:-1].split(",") if x.strip()]
        fm[k.strip()] = v
    return fm


def load(machine: str):
    notes = MACHINES / machine / "notes.md"
    if not notes.exists():
        sys.exit(f"! no notes.md at {notes}")
    text = notes.read_text()
    return text, parse_frontmatter(text)


def check(machine: str) -> dict:
    text, fm = load(machine)
    errs = []

    retired = fm.get("retired", "")
    if not retired:
        errs.append("retired: is empty — box not confirmed retired, refusing to publish")
    else:
        try:
            d = datetime.date.fromisoformat(retired)
            if d > datetime.date.today():
                errs.append(f"retired: {retired} is in the future")
        except ValueError:
            errs.append(f"retired: {retired!r} is not a YYYY-MM-DD date")

    # Flag scan — body only, minus fenced code that might legitimately show hashes.
    body = re.sub(r"^---\n.*?\n---", "", text, flags=re.S)
    hits = FLAG_RE.findall(body)
    if hits:
        errs.append(f"possible flag value(s) in notes ({len(hits)} 32-hex hit[s]) — redact before publishing")

    if errs:
        print(f"[FAIL] {machine}")
        for e in errs:
            print(f"   - {e}")
        sys.exit(1)
    print(f"[OK] {machine} — retired {retired}, no flag values detected")
    return fm


def index():
    rows = []
    for d in sorted(p for p in MACHINES.iterdir() if p.is_dir()):
        notes = d / "notes.md"
        if not notes.exists():
            continue
        fm = parse_frontmatter(notes.read_text())
        name = fm.get("machine", d.name)
        pdf = d / "writeup.pdf"
        link = f"[{name}](machines/{d.name}/writeup.pdf)" if pdf.exists() else name
        tags = fm.get("tags", [])
        tags = ", ".join(tags) if isinstance(tags, list) else tags
        rows.append((name.lower(), f"| {link} | {fm.get('os','')} | {fm.get('difficulty','')} | {fm.get('retired','') or '—'} | {tags} |"))
    rows.sort()
    table = "| Machine | OS | Difficulty | Retired | Tags |\n|---|---|---|---|---|\n" + "\n".join(r[1] for r in rows)

    readme = ROOT / "README.md"
    content = readme.read_text() if readme.exists() else "# HTB Writeups\n\n<!--INDEX-->\n<!--/INDEX-->\n"
    content = re.sub(r"<!--INDEX-->.*?<!--/INDEX-->",
                     f"<!--INDEX-->\n{table}\n<!--/INDEX-->", content, flags=re.S)
    readme.write_text(content)
    print(f"[OK] indexed {len(rows)} machine(s) into README.md")


def build(machine: str):
    check(machine)
    typ = MACHINES / machine / "writeup.typ"
    if not typ.exists():
        sys.exit(f"! no writeup.typ — run /writeup {machine} first")
    r = subprocess.run(["typst", "compile", "--root", str(ROOT),
                        str(typ), str(typ.with_suffix(".pdf"))])
    sys.exit(r.returncode)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    cmd = sys.argv[1]
    if cmd == "check":
        check(sys.argv[2])
    elif cmd == "index":
        index()
    elif cmd == "build":
        build(sys.argv[2])
    else:
        sys.exit(__doc__)
