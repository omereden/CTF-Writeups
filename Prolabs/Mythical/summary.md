# Mythical — Pro Lab Summary

> Completion certificate + capability summary. No walkthrough — HTB's content rules
> don't permit publishing Pro Lab solutions.

## Overview

Mythical is an intermediate mini Pro Lab built around an assumed-breach scenario:
the engagement starts with an existing C2 agent already running inside the target
network, rather than an external foothold. The environment spans two trusted
Active Directory domains, so the lab is as much about cross-domain trust abuse as
single-domain AD attack paths.

## Scope & environment

- Assumed-breach start via an existing C2 implant/agent
- Two AD domains joined by a one-way trust relationship
- Domain Controllers plus supporting Linux/Windows infrastructure
- Active Directory Certificate Services (AD CS) in scope
- A Microsoft SQL Server instance as a secondary pivot point

## Key techniques demonstrated

- Operating entirely through a C2 framework rather than direct tooling
- AD enumeration and attack-path discovery via BloodHound
- Locating and cracking an offline credential store found on the network
- AD CS template-misconfiguration abuse (ESC-class certificate attacks) to obtain
  a privileged certificate and authenticate as a domain admin
- Abusing a one-way inter-domain trust to operate across both domains
- Credential discovery from a network share and reuse/spraying across services
- MSSQL privilege escalation via a database-ownership / trustworthy-database
  misconfiguration to reach sysadmin, then command execution
- Local privilege escalation via a SeImpersonatePrivilege abuse technique, with
  attention to AV/EDR evasion
- Extracting a credential surfaced via legacy authentication settings in memory

## Skills / takeaways

Mythical goes beyond "foothold to domain admin" — it exercises operating under an
assumed-breach/C2 posture, chaining an AD CS misconfiguration into full domain
compromise, and then pivoting that access across a trust boundary into a second
domain to escalate again through a separate, unrelated misconfiguration (MSSQL).
It's a good proof point for multi-domain AD attack-path thinking and C2-driven
tradecraft rather than direct-tool exploitation.
