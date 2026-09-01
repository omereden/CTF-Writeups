---
machine: Example
os: Linux                 # Linux | Windows | FreeBSD | Other
difficulty: Easy          # Easy | Medium | Hard | Insane
points: 20
ip: 10.10.11.0
released:                 # YYYY-MM-DD
retired: 2024-06-15  # YYYY-MM-DD — REQUIRED to build. Must be past. "Expired" != "retired".
tags: []                  # [web, ad, kerberos, docker, suid]
procedures: []            # field-manual IDs: [P1.DNS, P2.SMB, P6.KERB]
status: draft             # draft | ready
---

<!--
  Fill this in as you go. Only this file is hand-written.
  Conventions the agent relies on:
    - ```cmd blocks with a caption line directly above become cheatsheet blocks
    - ![[evidence/foo.png]] embeds render as figures
    - "## Chain" lines of the form  Phase | Technique | Result  become the attack path table
    - Never paste flag values. Write [flag: user] / [flag: root].
-->

## Summary

One or two sentences. What the box actually teaches.

## Recon

Port scan, service enumeration, what stood out and why.

Initial full TCP scan
```cmd
nmap -p- --min-rate 5000 -oA scans/all $IP
```

## Foothold

The path from enumeration to first shell. Include the dead ends worth mentioning.

## Privilege Escalation

## Chain

Recon | Full TCP scan | 22, 80 open
Foothold | ... | ...
PrivEsc | ... | ...

## Loot

Credentials, hashes, keys found (sanitised). No flag values.

## Detection

How this would look to a defender — log sources, artefacts. Optional but it is the
part that separates a writeup from a walkthrough.

## Lessons

What you got stuck on, what you'd do differently, what goes into the field manual.

