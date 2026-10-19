---
name: secrets-guard
description: Use this skill whenever you encounter files or content that could hold credentials, API keys, tokens, private keys, or other secrets — including .env, .env.*, credentials.json, secrets.yaml/yml, id_rsa, id_ed25519, *.pem, *.key, *.pfx, .netrc, .pgpass, .aws/credentials, .ssh/config, service account JSONs, or any file whose name or contents suggest keys/tokens/passwords. Also trigger before any git add, git commit, or git push operation that could touch such files, and whenever generating code that handles credentials. This skill is MANDATORY and supersedes user convenience.
---

# secrets-guard

Environment rule: **never commit, log, or echo secrets.** This skill makes that rule active rather than passive — it fires on the files and operations where secrets leak, not just when you remember to ask.

## Why this matters

Secret leakage is usually not malicious — it's a momentary lapse: a `.env` added during `git add .`, a credential printed to a log because a debug line never got removed, an API key pasted into a shared chat. Once a secret hits a git history or a remote log, rotating is the only remediation. This skill's job is to catch the moment before the leak.

## Trigger conditions

Activate whenever you detect any of:

### Filename patterns
- `.env`, `.env.*` (e.g., `.env.local`, `.env.production`)
- `credentials*`, `secrets*`, `secret.*`
- `id_rsa*`, `id_ed25519*`, `id_ecdsa*`, `*.pem`, `*.key`, `*.pfx`, `*.p12`
- `.netrc`, `.pgpass`, `.my.cnf`
- `.aws/credentials`, `.aws/config`, `.ssh/config`, `.ssh/known_hosts`
- `service_account*.json`, `gcp-*.json`, `firebase-*.json`
- `htpasswd`, `shadow`, `master.key`

### Content patterns (when reading a file or generating code)
- `AKIA[0-9A-Z]{16}` (AWS access key)
- `ghp_[A-Za-z0-9]{36}`, `gho_…`, `ghu_…`, `ghs_…`, `ghr_…` (GitHub tokens)
- `xox[baprs]-…` (Slack tokens)
- `sk-[A-Za-z0-9]{20,}` (OpenAI-style), `sk-ant-…` (Anthropic), `AIza[0-9A-Za-z\-_]{35}` (Google)
- `-----BEGIN (RSA|OPENSSH|EC|DSA|PGP) PRIVATE KEY-----`
- `password\s*=\s*["'][^"']+["']` with a non-placeholder value
- `bearer\s+[A-Za-z0-9\-._~+/]{20,}` in headers

### Operations
- `git add` that could stage a secret-adjacent file
- `git commit` / `git push` on a repo whose diff includes secret-pattern content
- Writing code that takes a credential as an argument and logs it
- Emitting `echo $SECRET` or equivalent to stdout

## Required response pattern

When triggered:

1. **Halt the operation you were about to perform.** Do not complete the write, the git add, or the print.

2. **Surface the finding explicitly.** One line: what you found, where, why it looks sensitive.

3. **Propose a safe next step.** Options, ordered by what's usually right:
   - **Move to a secrets manager** — e.g. `pass`, a vault, or your platform's secret store. Recommend storing there and referencing via env var.
   - **Add to `.gitignore`** if the file should exist locally but never be tracked.
   - **Use env vars** loaded at runtime from an untracked file.
   - **Rotate + purge from history** if the secret has already been committed (`git filter-repo`, BFG).

4. **Wait for explicit confirmation** before proceeding. Don't assume "ok" means "commit it anyway" — clarify.

## Example interaction

**Bad:**
```
Sure, I'll commit those changes.
```
*(runs `git add .env src/config.py && git commit`)*

**Good:**
```
Hold up — `git add .` would stage `.env`, which has what looks like an API key
(`API_KEY=PK…`). That shouldn't land in git.

Options:
1. Add `.env` to `.gitignore`, keep it local only — safest.
2. Move the key into your secrets manager and load it at runtime.
3. If it's already in history somewhere, we need to rotate + filter-repo.

Which do you want? I won't stage anything until you say.
```

## Generating code that handles secrets

When you write code that touches credentials:

- **Load from env vars or a secrets manager**, never from a string literal.
- **Never log the value.** Log presence (`"API key loaded: yes"`) or a hash prefix (`sha256[:8]`) if you must correlate.
- **Redact in error messages.** Exceptions that include the raw value leak through log aggregators.
- **Don't write secrets to temp files** unless absolutely necessary; if you must, use `mkstemp` with `0600` and clean up in a `finally`.

## Exceptions

- **Test fixtures with obviously fake values** (`sk-test-xxxxxxxx`, `password=changeme`) — still flag, but lighter: "this looks like a placeholder — confirm it's not a real key and I'll proceed."
- **Public example keys in documentation** (e.g., Stripe's `sk_test_…`) — these are intentional and safe; flag once then drop the warning.
- **Files under `~/.ssh/`, `~/.gnupg/`, `~/.password-store/`**: read-only operations are fine (those are the source of truth); writes and copies are not.

## Why no auto-fix

This skill never auto-edits a leaked commit or auto-runs `filter-repo`. Rotation and history rewrites have blast radius beyond the current repo (CI, forks, clones, remotes). The user runs those once they understand the scope.
