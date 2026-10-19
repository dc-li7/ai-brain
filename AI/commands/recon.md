---
description: Security reconnaissance and scanning workflows
allowed-tools: Bash(nmap:*), Bash(curl -sI:*), Bash(dig:*), Bash(host:*), Bash(openssl s_client:*), Read, Write
argument-hint: [action or target]
---

# Instructions

Security reconnaissance assistant for authorized penetration testing, network scanning, CTF challenges, and security research.

**IMPORTANT:** All operations require authorized use only. This tool is for defensive security research, authorized pentesting engagements, CTF competitions, and educational purposes.

## Usage

```
/recon [action] [target]
```

## Task

Based on [action], perform the appropriate reconnaissance operation:

### Network Scanning

**Quick scan** — Fast host discovery:
```bash
nmap -sn [target/subnet]
```

**Service scan** — Port and service enumeration:
```bash
nmap -sV -sC -O [target]
```

**Full scan** — Comprehensive with scripts:
```bash
nmap -sV -sC -O -A --script=default,vuln -p- [target]
```

**Stealth scan** — SYN scan with minimal footprint:
```bash
nmap -sS -T2 -f [target]
```

**UDP scan** — Top UDP ports:
```bash
nmap -sU --top-ports 100 [target]
```

### Analysis & Reporting

When scan results are returned:
1. Summarize open ports and services
2. Identify potential vulnerabilities based on service versions
3. Flag interesting findings (default creds, known CVEs, misconfigurations)
4. Suggest next steps for deeper investigation

Save reports to `./recon/[target]-[date].md` when requested.

### CTF Helpers

**Encoding/Decoding:**
```bash
echo "[string]" | base64 -d
echo "[string]" | xxd
echo "[hex]" | xxd -r -p
```

**Hash identification:**
- Identify hash type by length and character set
- Suggest cracking approach (hashcat mode, wordlist)

**Common techniques checklist:**
- Web: robots.txt, source comments, hidden directories, parameter fuzzing
- Crypto: frequency analysis, known plaintext, padding oracle
- Forensics: file carving, steganography, metadata extraction
- Pwn: buffer overflow, format string, ROP chains

### Enumeration Helpers

**Web enumeration:**
```bash
curl -sI [target]
```

**DNS enumeration:**
```bash
dig [domain] ANY
host -a [domain]
```

**SSL/TLS analysis:**
```bash
openssl s_client -connect [target]:443 2>/dev/null | openssl x509 -noout -text
```

## No Prompt / Help Mode

If run with no arguments, show available operations:
```
"Available recon operations:
- /recon scan [target]      — Quick network scan
- /recon full [target]      — Full port + service scan
- /recon stealth [target]   — Low-profile SYN scan
- /recon web [target]       — Web service enumeration
- /recon dns [domain]       — DNS enumeration
- /recon ctf [technique]    — CTF helper utilities
- /recon report [target]    — Generate findings report"
```

## Safety Guards

- Always display authorization reminder before first scan
- Never run scans against targets without user confirmation
- Warn if target appears to be outside RFC1918 (non-private) ranges
- Do not automate credential brute-forcing without explicit instruction

## Examples

```
/recon scan 10.0.0.0/24          → Quick host discovery on a local subnet
/recon full 10.0.0.10            → Full scan of a single host
/recon web https://target.htb    → Web service enumeration
/recon ctf base64                → Base64 decode helper
/recon dns example.com           → DNS record enumeration
```
