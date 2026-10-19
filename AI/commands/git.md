---
description: Git Workflow
argument-hint: [prompt]
---

# Instructions

Perform git operations based on [prompt] using Bash git commands.

**Template:** read `~/.claude/templates/git-template.md` first (link.sh links it from `AI/templates`).

Follow the template for branch naming conventions, commit message formats, and safety checks.

## No Prompt / Help Mode

If run with no prompt, show a concise help message:

**Purpose:** Turn a natural-language instruction into a compliant Git workflow (create branches, make scoped commits, push) respecting repository policies.

**Quick examples:**
- `/git create branch for auth feature`
- `/git create commit`
- `/git push changes`

## Interactive Mode

When the prompt is ambiguous, ask for clarification:

```
"I see several possible actions:
1. Create a new branch for this work
2. Stage and commit current changes
3. Push existing commits

Which one matches your intent?"
```

## Protected Branch Policy

**Refuse to push** directly to: `main`, `master`, `release/*`, `prod/*` (changes reach them through a pull request)

## Safety Guards

- Block direct pushes to protected branches
- Disallow force-push
- Warn on large binary additions without LFS
- Refuse to commit files matching secret patterns (API keys, tokens, credentials, private keys, connection strings)

## Conflict Resolution

When merge conflicts occur:
- Auto-detect conflict types (code, config, documentation)
- Suggest resolution strategies based on change patterns
- Preview mode shows merge result before applying

## Examples

**Feature branch:**
```
/git create branch for deauth module refactor
→ Branch: feature/deauth/refactor-module
→ From: main
```

**Scoped commit:**
```
/git commit the scanner changes
→ feature(scanner): add channel hopping support
```

**Bug fix with ticket:**
```
/git fix rounding bug in signal calc (KEY-451)
→ Branch: fix/scanner/signal-rounding
→ Commit: fix(scanner): correct RSSI rounding to nearest dBm (KEY-451)
```
