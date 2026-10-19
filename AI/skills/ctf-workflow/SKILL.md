---
name: ctf-workflow
description: Use this skill whenever the user is working on a CTF challenge or authorized penetration test. Trigger on any of: the acronyms CTF/HTB/THM/PWN/KOTH, platform names HackTheBox / TryHackMe / picoCTF / VulnHub / OverTheWire, box/machine names in the context of "root this" or "foothold", the words flag / user.txt / root.txt / getflag / proof.txt, challenge categories web / pwn / reverse / crypto / forensics / misc / stego / osint, the files provided with challenges (.zip/.tar.gz with challenge name, disassembled binaries, pcaps tied to challenges), or any scenario where the user says "I'm stuck on this challenge" or "how do I approach this box". This skill owns the methodology — /recon still owns specific tool invocations.
---

# ctf-workflow

CTFs and authorized pentests share a skeleton: enumerate, find a foothold, escalate, clean up, document. This skill keeps that loop straight so the user doesn't lose hours wandering a single rabbit hole.

## Authorization reminder

This skill is for **authorized** activity only: CTF competitions, HTB/THM/picoCTF style platforms, the user's own lab, or engagements with written authorization. If the context isn't clearly authorized, halt and ask. Default is "assume unauthorized until stated otherwise."

## The loop

```
┌──────────────┐   ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│  Enumerate   │──▶│   Foothold   │──▶│   Privesc    │──▶│ Post + Write │
└──────────────┘   └──────────────┘   └──────────────┘   └──────────────┘
       ▲                  │                   │                  │
       └──────────────────┴───────────────────┘                  │
              (pivot back on new info)                           │
                                                                 ▼
                                                          ┌──────────────┐
                                                          │   Lessons    │
                                                          └──────────────┘
```

**Cardinal rule:** if you're stuck for more than ~30 min, you almost certainly missed something in enumeration. Go back one phase, not forward.

## Phase 1: Enumerate

Goal: build a complete picture of attack surface before touching any exploit. The common mistake is jumping to exploitation on the first open port.

**Network-level (boxes):**
- Fast scan first to spot obvious ports: `nmap -sC -sV --top-ports 1000 <ip>`
- Then full range: `nmap -p- -T4 <ip>` — run in parallel with the fast scan
- UDP top-100 for overlooked services
- Version-match every service against known CVEs / default creds
- For each service, note: version, banner, auth type, any fingerprint oddity

**Service-specific dives** (don't skip these):
- **Web**: see `references/web.md`
- **SMB**: `smbclient -L //target/ -N`, `enum4linux -a`, null sessions
- **SSH**: version banner, host key fingerprint, user enumeration resistance
- **FTP**: anonymous login, writable paths
- **DNS**: zone transfer (`dig axfr`), subdomain enumeration
- **Kerberos**: pre-auth disabled users (AS-REP roasting), SPN scanning
- **SNMP**: public community strings, MIB walks

**Information layer:**
- Any provided hints/story text — CTFs hide pointers here
- Usernames from web scrape → SSH / SMB / kerberos candidate list
- Tech stack fingerprint → targeted vuln search

**Output**: a running notes file with everything found, organized by service. Do not trust memory.

## Phase 2: Foothold

Goal: any shell, any user. Doesn't have to be clever.

Common paths by category — see reference files for details:
- **Web** → `references/web.md` (SQLi, RCE, LFI, SSRF, upload bypasses, SSTI)
- **Binary** → `references/binary.md` (buffer overflow, format string, ROP)
- **Crypto** → `references/crypto.md` (padding oracle, weak PRNG, known plaintext)

**Heuristics:**
- If the box has one obvious entry point, it's probably a red herring — but check it anyway, quickly.
- Creds found in one service almost always work in another — try them everywhere.
- Default credentials are embarrassingly often the answer.
- If you find a version with a public PoC, try the PoC first before manual exploitation.

## Phase 3: Privesc (or lateral)

Goal: get to the flag. Usually root, sometimes a specific user.

**Linux priv esc checklist:**
- `sudo -l` — low-hanging fruit
- SUID binaries → GTFOBins lookup
- Kernel version vs known exploits (verify the exploit actually applies; don't firehose)
- Writable `/etc/passwd`, cron jobs, systemd units
- Capabilities: `getcap -r / 2>/dev/null`
- Environment: `PATH` hijack, `LD_PRELOAD`
- NFS no_root_squash
- Run `linpeas.sh` or `linenum.sh` — but read the output, don't grep for colors

**Windows priv esc checklist:**
- `whoami /priv` / `whoami /groups`
- Unquoted service paths, service binary perms
- AlwaysInstallElevated
- Token privileges (SeImpersonate → printspoofer/juicy potato)
- Scheduled tasks, startup scripts
- Credentials in registry, LSASS, Vault, SAM
- Run `winpeas.exe` or `PowerUp.ps1`

**Pivoting:**
- If you got a user but can't privesc, check if lateral movement to another user is the path forward
- Read other users' home dirs, mail, cron
- `find / -readable -path /proc -prune -o 2>/dev/null` for accessible files

## Phase 4: Post + write-up

**Flag capture isn't the end.** Capture these before moving on:
- How you got in (exact commands/payloads)
- Why the vulnerability existed (not just "SQL injection" — *what* pattern)
- What would have prevented it
- Any interesting artifacts you saw in passing (for later study)

**Write-up template:**
```markdown
# Box: <name>
## Recon summary
## Foothold
  - Vector:
  - Exploit:
  - Shell as:
## Privesc
  - Vector:
  - Exploit:
  - Shell as:
## Flags
  - user.txt: <hash>
  - root.txt: <hash>
## Lessons
```

Write-ups compound. You should have a `writeups/` directory — skill caller: suggest one if it doesn't exist.

## When the user says "I'm stuck"

Follow this order before suggesting new exploits:

1. **Ask what's enumerated.** 90% of "stuck" is missing recon. "What does your nmap look like? What web directories have you enumerated? Any creds anywhere?"
2. **Revisit discarded ports/services.** The first scan might have missed something; rescan differently.
3. **Revisit the story.** CTFs often embed hints in descriptions, readmes, usernames.
4. **Check for encoded/hidden data.** Comments, alt text, robots.txt, `/.git`, `/.svn`, backup files (`.bak`, `~`).
5. **Only then** suggest a new exploitation angle.

## Tool reminders (complements /recon)

- `/recon scan <target>` — fast nmap
- `/recon full <target>` — full port + service
- `/recon web <url>` — web enumeration
- `/recon ctf <technique>` — CTF helpers
- This skill does not duplicate those — for specific commands, use the slash command; for methodology, the skill is active.
