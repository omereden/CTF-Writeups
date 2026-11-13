# Dante — Pro Lab Summary

> Completion certificate + capability summary. No walkthrough — HTB's content rules
> don't permit publishing Pro Lab solutions.

## Overview

Dante is HTB's entry-level Pro Lab: a multi-host enterprise network spanning several
subnets with a mix of Linux and Windows targets. The emphasis is breadth of
fundamentals and moving through a segmented network, rather than one hard exploit.

## Scope & environment

- Multiple subnets reached by pivoting from an initial foothold
- Mixed Linux and Windows hosts
- Web applications, exposed services, and misconfigurations as entry points

## Key techniques demonstrated

- Network and service enumeration across segments
- Web application exploitation for initial footholds
- Password attacks and credential reuse
- Linux and Windows privilege escalation
- Pivoting / tunnelling to reach internal subnets
- Lateral movement using looted credentials

## Skills / takeaways

End-to-end methodology on a realistic multi-host network — enumerate, exploit,
escalate, pivot, repeat — plus the discipline of tracking hosts, credentials, and
routes across a full engagement.
