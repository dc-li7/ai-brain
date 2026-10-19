---
name: pre-ship-review
description: Use this skill whenever the user is about to ship code — explicitly ("ready to commit", "ready to push", "ready to deploy", "review this before I ship"), or implicitly (about to run git commit / git push / deploy/push.sh / any deploy workflow after a non-trivial change). Also trigger when the user asks for a code review, sanity check, or "does this look ok". This skill runs the pre-ship checklist: lint, tests, type-check, secret scan, diff review, and surfaces blockers before they land. It is the last line of defense before changes leave the workstation.
---

# pre-ship-review

The goal: catch obvious problems on the workstation, not in production. This skill runs a standard checklist before any non-trivial commit or deploy and surfaces blockers clearly.

## When to run

- Before `git commit` on a non-trivial change
- Before `git push`
- Before project deploy workflows (deploy scripts, Docker compose up, flashing firmware to a device)
- When the user explicitly asks for a review
- When the user says "does this look right" on a chunk of work

Skip for: typo fixes, README touch-ups, single-line renames, comments. Use judgment — the point is to catch bugs, not to create friction.

## The checklist

Run these in order. Stop at the first blocker.

### 1. Diff review

```bash
git status
git diff --stat
git diff              # full diff for the staged + unstaged changes
```

Read the full diff, not just the stat. Look for:
- Debug prints / `console.log` / `println!` / `dbg!` left in
- Commented-out code (delete it — git has the history)
- Hardcoded credentials, API keys, test tokens
- Hardcoded paths specific to dev environment
- TODOs that should have been resolved in this change
- Dead code paths introduced this session
- Large refactors sneaking into a feature commit

If the diff is huge and mixes concerns, suggest splitting into logical commits before proceeding.

### 2. Lint

Language-appropriate:

| Language | Command |
|---|---|
| Python | `ruff check . && ruff format --check .` |
| Bash | `shellcheck <script>` (for each script) |
| C/C++ | `clang-tidy <file>` or the project's build warnings at `-Wall -Wextra` |
| JS/TS | `eslint .` / `biome check .` |
| Go | `go vet ./...` + `golangci-lint run` |
| Rust | `cargo clippy` |

Fail fast: if lint catches something, fix it or consciously `# noqa` it with a comment.

### 3. Type check

- Python: `mypy src/` if the project uses mypy, otherwise skip
- TS: `tsc --noEmit`
- Rust: implicit in `cargo build`
- Go: implicit

### 4. Tests

```bash
pytest                    # Python
cargo test                # Rust
go test ./...             # Go
make test                 # C/C++ if Makefile defines it
npm test / pnpm test      # JS/TS
```

All tests should pass. "These tests are flaky" is a signal that needs addressing, not ignoring. If a test is legitimately unrelated to the change and temporarily failing, explicitly call it out rather than silently pushing.

### 5. Secret scan

```bash
gitleaks protect --staged    # scans staged files only
# or for the whole tree:
gitleaks detect --no-banner
```

If gitleaks isn't installed, fall back to `git diff --cached | grep -iE 'api[_-]?key|secret|password|token|AKIA[0-9A-Z]|ghp_'` — crude but better than nothing.

This overlaps with the `secrets-guard` skill — both should be satisfied.

### 6. Project-specific preflight

Some projects have their own gate. Respect it:

| Project type | Pre-ship command |
|---|---|
| Python app with preflight | `python ci_check.py` or your project's preflight script |
| Docker Compose stack | `docker compose config` (validates the compose file) |
| Embedded / firmware | Build succeeds on target: `idf.py build` or `pio run` |
| Any Python lib | `python -m build` succeeds |

### 7. Git hygiene

- Commit message follows your format: `[TICKET] <type>(<scope>): <summary>` (see global CLAUDE.md)
- Branch name follows format: `<prefix>/<scope>/<description>`
- Not committing to a protected branch: `main`, `master`, `release/*`, `hotfix/*`, `prod/*`
- No `--no-verify` / `--force` unless explicitly asked

## Output format

After running the checklist, report results as a single pass/fail block:

```
Pre-ship review:
✓ Diff read (3 files, +47 -12)
✓ Lint clean (ruff, 0 issues)
✓ Type check (mypy, 0 errors)
✓ Tests passing (76/76)
✓ Secret scan clean (gitleaks, no leaks)
✓ Preflight (project CI check exit 0)
✗ Commit message — missing type prefix ("update login flow" → "feat(auth): update login flow")
```

Stop on the first blocker and ask the user how to handle. Don't silently auto-fix things — the user may have a reason.

## Blockers vs warnings

**Blockers** (must fix before shipping):
- Test failures
- Lint errors
- Type errors
- Secret scan hits
- Preflight failures
- Hardcoded credentials
- Committing to a protected branch

**Warnings** (surface but don't block):
- TODO comments in changed code
- Large diff size (> 500 lines)
- No tests added for new functionality
- Commit message style issues
- Unused imports / variables (depends on lint config)

## If the user overrides

If the user says "I know about X, ship anyway," document it in the commit message or ask them to. Don't drop the warning silently. Examples of legitimate overrides:
- "Shipping a hotfix, will clean up TODOs next commit"
- "Test is flaky, known issue, tracking in ticket #N"
- "Intentional large diff for the initial scaffold"

## What this skill does NOT do

- Run the actual commit or push — that's your call
- Judge code quality beyond obvious smells — this is a checklist, not a style review
- Enforce test coverage percentages — that's a project-level decision
- Replace actual code review by a human — this is pre-review hygiene
