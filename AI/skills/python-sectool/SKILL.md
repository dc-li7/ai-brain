---
name: python-sectool
description: Use this skill whenever you are scaffolding or editing a Python security tool — a script or package that scans, enumerates, exploits, analyzes, or otherwise interacts with untrusted targets / data / networks. Trigger on any of: new Python project with a security purpose, editing code that uses socket / scapy / paramiko / requests against arbitrary targets, code that handles credentials or spawns subprocesses, argparse-based CLI tools under ~/scripts or ~/projects, or any mention of "scanner", "fuzzer", "exploit", "pentest tool" combined with Python. This skill enforces structured logging (with secret redaction), argparse conventions, safe subprocess usage, signal handling, and project layout.
---

# python-sectool

This skill encodes the habits that keep Python security tools safe, debuggable, and maintainable — especially when they handle credentials, talk to untrusted targets, or run long operations.

## Required shape of a Python security tool

Every non-trivial tool should have:

1. **`argparse` CLI** with subcommands when multiple actions exist, short options only for the obviously common ones
2. **Structured logging** via `logging` (not `print`), with a secret redaction filter attached at the root
3. **Signal handling** so Ctrl+C cleans up cleanly (sockets, subprocess children, temp files)
4. **Safe subprocess** — always `shell=False`, always a list of args, no f-string command construction from untrusted input
5. **JSON output mode** (`--json`) alongside the human-readable default — makes the tool pipeable
6. **Versioning** via `--version` reading from package metadata or a `__version__` constant
7. **Timeouts on everything external** — no bare `socket.connect`, no bare `requests.get`, no bare `subprocess.run`

See `references/template.md` for a copy-ready skeleton covering all of the above.

## Project layout

For anything more than a single file:

```
tool-name/
├── pyproject.toml
├── README.md
├── .gitignore                    # includes .venv/, __pycache__/, *.pyc, .env
├── src/
│   └── tool_name/
│       ├── __init__.py           # __version__ = "0.1.0"
│       ├── __main__.py           # CLI entry point
│       ├── cli.py
│       ├── core.py
│       └── logging_setup.py
└── tests/
    └── test_core.py
```

Use `src/` layout — it prevents accidental imports from the working directory and makes the package installable as a real package. Use `pyproject.toml` (PEP 621), not `setup.py`.

Use a venv per tool: `python -m venv .venv && source .venv/bin/activate`. Don't pip-install into the system Python (it may be managed by your distro's package manager and will break). Prefer `uv` if installed — it's much faster and handles venvs more cleanly.

## Logging with secret redaction

Root logger gets a filter that masks known secret patterns before any handler sees the record. Bake this into every tool.

```python
import logging
import re

_SECRET_PATTERNS = [
    (re.compile(r'(AKIA[0-9A-Z]{16})'), r'[AWS_KEY_REDACTED]'),
    (re.compile(r'(ghp_[A-Za-z0-9]{36})'), r'[GH_TOKEN_REDACTED]'),
    (re.compile(r'(sk-[A-Za-z0-9]{20,})'), r'[API_KEY_REDACTED]'),
    (re.compile(r'(Bearer\s+)[A-Za-z0-9\-._~+/]+'), r'\1[BEARER_REDACTED]'),
    (re.compile(r'(password\s*=\s*)[^\s,)]+', re.I), r'\1[REDACTED]'),
]

class RedactingFilter(logging.Filter):
    def filter(self, record):
        msg = record.getMessage()
        for pat, repl in _SECRET_PATTERNS:
            msg = pat.sub(repl, msg)
        record.msg = msg
        record.args = ()
        return True

def setup_logging(level=logging.INFO, json_mode=False):
    root = logging.getLogger()
    root.setLevel(level)
    handler = logging.StreamHandler()
    if json_mode:
        # use python-json-logger or equivalent
        ...
    else:
        handler.setFormatter(logging.Formatter(
            "%(asctime)s %(levelname)-5s %(name)s: %(message)s"
        ))
    handler.addFilter(RedactingFilter())
    root.addHandler(handler)
```

**Never** `logger.info(f"API key: {key}")`. Log presence, not value: `logger.info("API key loaded: yes")`.

## Safe subprocess

```python
import subprocess

# GOOD
result = subprocess.run(
    ["nmap", "-sV", target],
    capture_output=True, text=True, timeout=300, check=False,
)

# BAD
subprocess.run(f"nmap -sV {target}", shell=True)   # shell injection
subprocess.Popen(user_input.split())                # still unsafe — list parsing of user input
```

Rules:
- `shell=False` always (it's the default; don't flip it)
- Pass args as a list
- Never `f"{target}"` into the command unless `target` is validated against an allowlist
- Set `timeout=`; handle `subprocess.TimeoutExpired`
- Set `check=False` and inspect `returncode` rather than letting an exception escape

For shell-escaping when you genuinely need a shell command (rare): `shlex.quote`.

## Signal handling

Long-running security tools get Ctrl+C'd frequently. Make it clean:

```python
import signal
import sys

_shutdown = False

def _handle_sigint(signum, frame):
    global _shutdown
    if _shutdown:
        sys.exit(130)   # second Ctrl+C: hard exit
    _shutdown = True
    print("\n[!] shutting down — press Ctrl+C again to force", file=sys.stderr)

signal.signal(signal.SIGINT, _handle_sigint)
```

In the main loop, check `_shutdown` periodically and break out. Use `try/finally` to close sockets, kill child processes, flush logs.

## Network safety

- **Timeouts everywhere**: `requests.get(url, timeout=(5, 30))` — `(connect, read)`. No bare `timeout=None`.
- **User-Agent**: set it to something honest. Don't impersonate a browser unless the task requires it.
- **Verify TLS** by default. `verify=False` only with a loud log line and a `--insecure` flag.
- **Rate limit yourself**: a simple `time.sleep()` between requests is often enough. Don't hammer a target in CTF — it's a sign of bad tooling, not skill.
- **Don't scan localhost unless asked** — it's a common footgun when a placeholder URL makes it to production.

## JSON output mode

Tools that emit findings should support machine-readable output:

```python
parser.add_argument("--json", action="store_true", help="emit JSON results")
...
if args.json:
    json.dump(results, sys.stdout, default=str)
    sys.stdout.write("\n")
else:
    render_human(results)
```

This makes the tool composable with other tools and easy to feed into reports.

## Testing

- `pytest` as the runner
- One test file per module
- Use `responses` or `pytest-httpx` to mock HTTP; `unittest.mock` for subprocess and sockets
- Aim for meaningful assertions (did the tool parse this input correctly?), not coverage theater

## What this skill does NOT enforce

- Style rules beyond PEP 8 — use `ruff` and `black` and move on
- Type checking — `mypy` is nice but optional
- Specific library choices (requests vs httpx, click vs argparse) — your call, this skill just requires *one* of them consistently

## When to skip this skill

- Tiny one-off scripts (< 30 lines) where structure is overhead
- Jupyter notebooks for exploration
- Non-security Python (data analysis, web apps) — different habits matter there
