#import "../../template/lib.typ": *

#show: htb-writeup.with(
  machine: "Example",
  os: "Linux",
  difficulty: "Medium",
  points: 30,
  ip: "10.10.11.42",
  released: "2024-01-13",
  retired: "2024-06-15",
  author: "0x3d3n",
  tags: ("web", "sqli", "suid", "gtfobins"),
  procedures: ("P1.WEB", "P3.SQLI", "P7.SUID"),
  summary: [A SQL injection in an unauthenticated search endpoint yields
    credentials, and a misconfigured SUID binary hands over root via a
    GTFOBins-documented escape.],
  chain: (
    ("Recon", "Full TCP + service scan", "22, 80 open"),
    ("Foothold", [Boolean SQLi in `/search`], "DB creds → SSH"),
    ("PrivEsc", [SUID `find` abuse], "root shell"),
  ),
  killchain: (
    ("Recon", false), ("Foothold", false), ("User", true),
    ("PrivEsc", false), ("Root", true),
  ),
)

= Recon

A full TCP sweep followed by targeted service enumeration on the two open
ports. Only SSH and an Apache instance were exposed.

#cmd("Full TCP scan", "nmap -p- --min-rate 5000 -oA scans/all 10.10.11.42
# then targeted:
nmap -p22,80 -sCV -oA scans/svc 10.10.11.42")

The web root advertised a search feature that took a single `q` parameter.

#ev(image("evidence/nmap-scan.png"), caption: [Service scan — only 22 and 80 exposed.])

#note[The `Server` header leaked a minor Apache version, but no public CVE
matched. The interesting surface was the application, not the stack.]

= Foothold

The search endpoint concatenated `q` straight into a query. A boolean payload
confirmed injection; from there, UNION-based extraction pulled the users table.

#cmd("Confirm boolean injection", "curl 'http://10.10.11.42/search?q=x%27+OR+1%3D1--+-'")

#gotcha[The app filtered spaces. Inline comments (`/**/`) bypassed the filter —
worth checking before assuming the endpoint is clean.]

Recovered a bcrypt hash, cracked offline, and the password was reused for SSH.

#flag("user")

= Privilege Escalation

A SUID-root `find` binary was the fastest path.

#cmd("Enumerate SUID, then exploit", "find / -perm -4000 -type f 2>/dev/null
find . -exec /bin/sh -p \\; -quit")

#detect[SUID abuse of this kind surfaces in `execve` auditd records where a
non-root uid spawns a root shell via a known GTFOBins binary — a high-signal
detection when baselined.]

#flag("root")

= Loot

- One reused credential pair (web DB → SSH).
- bcrypt hash for the `svc` account.

= Lessons

The filter bypass cost the most time — I assumed the endpoint was sanitised
after the space filter blocked the naive payload. Maps cleanly to `P3.SQLI` in
the field manual; adding the `/**/` bypass note there.
