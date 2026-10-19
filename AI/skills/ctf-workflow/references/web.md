# CTF Web Reference

Checklist and reminders for web-category CTF challenges and pentest web surfaces. Load when the target has an HTTP(S) service or the challenge category is web.

## First pass (always)

1. `curl -sI <url>` — headers tell a story (server banner, frameworks, CSP, cookies)
2. Open in browser with devtools → view page source, network tab, storage (cookies, localStorage, sessionStorage)
3. `robots.txt`, `sitemap.xml`, `security.txt`
4. Check `/.git/`, `/.svn/`, `/.DS_Store`, `.env`, backup files (`.bak`, `~`, `.old`, `.swp`)
5. Directory brute-force: `gobuster`/`feroxbuster`/`ffuf` with `raft-large-directories.txt` or `common.txt`
6. Subdomain enum if in scope: `ffuf -w <wordlist> -H "Host: FUZZ.target.com" -u https://target.com -fs <size>`

## Fingerprinting

- `Server:` and `X-Powered-By:` headers
- Cookies: `PHPSESSID` → PHP, `JSESSIONID` → Java, `express.sid` → Node/Express, `laravel_session` → Laravel
- Errors: stack traces leak framework + version
- Favicon hash (useful for Shodan pivots)
- `whatweb <url>` for automated fingerprinting

## Common vectors

### SQL injection
- Test: `'`, `" `, `'--`, `' OR '1'='1`, time-based `' AND SLEEP(5)--`
- Union-based: figure out column count with `' ORDER BY N--`
- Error-based: `extractvalue`, `updatexml` on MySQL
- Blind: time-based or boolean-based — slow but reliable
- `sqlmap -u "<url>" --batch --risk=2 --level=3` once manual confirms injection exists
- Post-exploitation: read files (`LOAD_FILE`), write files (`INTO OUTFILE`), UDF for RCE

### RCE
- Parameter injection: `;`, `|`, `&&`, `$(...)`, backticks
- Template injection (SSTI): `{{7*7}}` → 49 = vulnerable. Jinja2, Twig, Freemarker, Velocity all have distinct payloads
- Deserialization: PHP (`O:...`), Java (`rO0AB`), .NET (`AAEAAAD`), Python pickle
- File upload bypasses: double extensions, null bytes, MIME confusion, `.phtml`/`.phar`/`.htaccess`

### LFI / Path traversal
- `../../../etc/passwd`
- PHP wrappers: `php://filter/convert.base64-encode/resource=<file>`
- Log poisoning: poison apache/nginx access log via User-Agent, then include it
- `/proc/self/environ`, `/proc/self/cmdline` for process info

### SSRF
- `http://localhost`, `http://127.0.0.1`, `http://[::1]`
- Cloud metadata: `http://169.254.169.254/latest/meta-data/` (AWS), Azure/GCP variants
- Protocol smuggling: `gopher://`, `dict://`, `file://`
- DNS rebinding for filter bypass

### XXE
- Classic: `<!DOCTYPE foo [<!ENTITY xxe SYSTEM "file:///etc/passwd">]>`
- Blind: out-of-band via external DTD
- Billion laughs / quadratic blowup for DoS (don't — wrong category usually)

### Authentication
- Default creds: `admin:admin`, `admin:password`, `root:root`, vendor defaults
- JWT: `alg: none`, weak secret (crack with `jwt_tool`/`hashcat`), `kid` injection
- Password reset: token predictability, email header injection, host header injection
- Session fixation, session prediction

## Fuzzing payload lists

Keep these at hand:
- SecLists (`/usr/share/seclists/` or clone from danielmiessler/SecLists)
- PayloadsAllTheThings (Web + specific vulns)
- `Discovery/Web-Content/raft-*-directories.txt` (good default)
- `Fuzzing/XSS/XSS-*.txt`
- `Fuzzing/SQLi/Generic-*.txt`

## Post-exploitation on web

- Spawn an interactive shell if you only have RCE: `python3 -c 'import pty;pty.spawn("/bin/bash")'`
- Upgrade with `stty raw -echo; fg` + `export TERM=xterm`
- Pivot to DB if credentials are in config files
- Look for `/var/www/` config files: `wp-config.php`, `.env`, `config.php`, `settings.py`
