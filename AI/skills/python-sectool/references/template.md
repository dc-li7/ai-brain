# Python Security Tool Template

Drop-in skeleton for a new Python security tool. Produces a CLI with argparse, redacting logger, signal handling, JSON mode, and timeout-aware subprocess.

## pyproject.toml

```toml
[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[project]
name = "tool-name"
version = "0.1.0"
description = "One-line description"
requires-python = ">=3.11"
dependencies = [
    "requests>=2.31",
]

[project.optional-dependencies]
dev = [
    "pytest>=8",
    "ruff>=0.4",
    "mypy>=1.10",
]

[project.scripts]
tool-name = "tool_name.cli:main"

[tool.ruff]
line-length = 100
target-version = "py311"
```

## src/tool_name/__init__.py

```python
__version__ = "0.1.0"
```

## src/tool_name/logging_setup.py

```python
import logging
import re

_SECRET_PATTERNS = [
    (re.compile(r"(AKIA[0-9A-Z]{16})"), r"[AWS_KEY_REDACTED]"),
    (re.compile(r"(ghp_[A-Za-z0-9]{36})"), r"[GH_TOKEN_REDACTED]"),
    (re.compile(r"(sk-[A-Za-z0-9]{20,})"), r"[API_KEY_REDACTED]"),
    (re.compile(r"(Bearer\s+)[A-Za-z0-9\-._~+/]+"), r"\1[BEARER_REDACTED]"),
    (re.compile(r"(password\s*=\s*)\S+", re.I), r"\1[REDACTED]"),
]


class RedactingFilter(logging.Filter):
    def filter(self, record: logging.LogRecord) -> bool:
        msg = record.getMessage()
        for pat, repl in _SECRET_PATTERNS:
            msg = pat.sub(repl, msg)
        record.msg = msg
        record.args = ()
        return True


def setup_logging(verbose: bool = False) -> None:
    level = logging.DEBUG if verbose else logging.INFO
    root = logging.getLogger()
    root.setLevel(level)
    handler = logging.StreamHandler()
    handler.setFormatter(
        logging.Formatter("%(asctime)s %(levelname)-5s %(name)s: %(message)s")
    )
    handler.addFilter(RedactingFilter())
    root.addHandler(handler)
```

## src/tool_name/cli.py

```python
import argparse
import json
import logging
import signal
import sys
from typing import Any

from . import __version__
from .logging_setup import setup_logging
from .core import run_scan

log = logging.getLogger(__name__)
_shutdown = False


def _handle_sigint(signum: int, frame: Any) -> None:
    global _shutdown
    if _shutdown:
        sys.stderr.write("\n[!] force exit\n")
        sys.exit(130)
    _shutdown = True
    sys.stderr.write("\n[!] shutting down — Ctrl+C again to force\n")


def shutdown_requested() -> bool:
    return _shutdown


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="tool-name",
        description="One-line description of the tool.",
    )
    p.add_argument("--version", action="version", version=f"%(prog)s {__version__}")
    p.add_argument("-v", "--verbose", action="store_true", help="debug logging")
    p.add_argument("--json", action="store_true", help="emit JSON results to stdout")

    sub = p.add_subparsers(dest="command", required=True)

    scan = sub.add_parser("scan", help="run a scan")
    scan.add_argument("target", help="target host or URL")
    scan.add_argument("--timeout", type=int, default=30)

    return p


def main(argv: list[str] | None = None) -> int:
    signal.signal(signal.SIGINT, _handle_sigint)
    parser = build_parser()
    args = parser.parse_args(argv)
    setup_logging(verbose=args.verbose)

    try:
        if args.command == "scan":
            results = run_scan(args.target, timeout=args.timeout)
        else:
            parser.error(f"unknown command: {args.command}")
            return 2

        if args.json:
            json.dump(results, sys.stdout, default=str)
            sys.stdout.write("\n")
        else:
            for line in _render_human(results):
                print(line)
    except KeyboardInterrupt:
        return 130
    except Exception as e:
        log.exception("unhandled error: %s", e)
        return 1

    return 0


def _render_human(results: dict) -> list[str]:
    # customize per-tool
    return [f"{k}: {v}" for k, v in results.items()]


if __name__ == "__main__":
    raise SystemExit(main())
```

## src/tool_name/__main__.py

```python
from .cli import main

raise SystemExit(main())
```

## src/tool_name/core.py (stub)

```python
import logging
import subprocess

log = logging.getLogger(__name__)


def run_scan(target: str, timeout: int = 30) -> dict:
    log.info("starting scan of %s", target)
    # EXAMPLE: safe subprocess call
    result = subprocess.run(
        ["nmap", "-sV", "--max-retries", "1", target],
        capture_output=True,
        text=True,
        timeout=timeout,
        check=False,
    )
    return {
        "target": target,
        "returncode": result.returncode,
        "stdout": result.stdout,
    }
```

## tests/test_core.py

```python
from tool_name.core import run_scan


def test_run_scan_returns_dict(monkeypatch):
    class FakeResult:
        returncode = 0
        stdout = "fake"
        stderr = ""

    def fake_run(*args, **kwargs):
        return FakeResult()

    monkeypatch.setattr("tool_name.core.subprocess.run", fake_run)
    out = run_scan("example.com")
    assert out["returncode"] == 0
    assert "example.com" in out["target"]
```

## .gitignore

```
.venv/
__pycache__/
*.pyc
.pytest_cache/
.mypy_cache/
.ruff_cache/
dist/
build/
*.egg-info/
.env
.env.*
```

## Bootstrap commands

```bash
mkdir -p tool-name/src/tool_name tool-name/tests
cd tool-name
python -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
pytest
```
