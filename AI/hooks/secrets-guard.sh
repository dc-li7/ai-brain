#!/usr/bin/env bash
# secrets-guard.sh — block writes to files matching secret patterns
# PreToolUse hook for Write|Edit|NotebookEdit. Exit 2 = block, 0 = allow.
# NOTE: does NOT cover the Bash tool — `cat > .env` and friends bypass this.
set -uo pipefail

input=$(cat)

# Parse failures fail CLOSED. Previously `set -e` let a jq failure abort with
# jq's own exit code (5); Claude Code reads anything other than 2 as a
# non-blocking error, so a malformed payload silently disabled this guard with
# no visible sign. A security control that quietly switches itself off is worse
# than one that is loudly broken. Change these to `exit 0` to fail open instead.
if ! command -v jq >/dev/null 2>&1; then
    echo "BLOCKED by secrets-guard: jq not found, cannot vet this write." >&2
    exit 2
fi
if ! file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null); then
    echo "BLOCKED by secrets-guard: could not parse hook input." >&2
    exit 2
fi

[ -z "$file_path" ] && exit 0

# Match on the RESOLVED path. Without this, a symlink at an innocuous name
# pointing at ~/.ssh/config or ~/.env sails straight through: the hook sees the
# harmless alias, the filesystem follows the link. readlink -f resolves a
# not-yet-existing final component fine, so writes to new files still work.
resolved=$(readlink -f "$file_path" 2>/dev/null) || resolved=""
[ -n "$resolved" ] && file_path="$resolved"

# Patterns that indicate a secrets file.
# NB: in a bash `case`, * matches across / — unlike find(1) or .gitignore
# globbing. So a bare `*.env` already covers every directory depth, and a
# `*/.env` variant alongside it would be unreachable dead code (SC2222).
case "$file_path" in
    *.env|*.env.*) blocked="env file" ;;
    *credentials*) blocked="credentials file" ;;
    *.pem|*.key) blocked="key file" ;;
    */secrets/*|*/.secrets/*) blocked="secrets directory" ;;
    *id_rsa|*id_ed25519|*id_ecdsa) blocked="ssh private key" ;;
    # --- patterns added 2026-07-29 to close skill coverage gaps ---
    # why: certificate keystores contain private keys + certs bundled together
    *.pfx|*.p12)                    blocked="certificate store" ;;
    # why: named secrets/secret files are credential dumps regardless of extension
    secrets.*|secret.*|*/secrets.*|*/secret.*)  blocked="secrets file" ;;
    # why: auth config files that embed plaintext passwords for CLI tools
    .netrc|*/.netrc)                blocked="netrc auth file" ;;
    .pgpass|*/.pgpass)              blocked="postgres password file" ;;
    .my.cnf|*/.my.cnf)              blocked="mysql password file" ;;
    # why: cloud provider config/key files — leaked SA keys are the #1 cloud breach vector
    */.aws/config)                  blocked="aws config" ;;
    *service_account*.json)         blocked="service account key" ;;
    *gcp-*.json|*firebase-*.json)   blocked="cloud service key" ;;
    # why: system auth files — editing these can lock out the box or leak hashes
    *htpasswd)                      blocked="htpasswd auth file" ;;
    */shadow)                       blocked="shadow password file" ;;
    # NB: master.key needs no arm — the *.key pattern above already covers it.
    # An explicit arm here would be unreachable dead code (shellcheck SC2222).
    # SSH config — blocks ProxyCommand injection + lockout risk; comment out this line to allow
    */.ssh/config)                  blocked="ssh config" ;;
    # --- self-protection, added 2026-08-16 ---
    # These files ARE the security policy: the allow/deny rules and every hook that
    # enforces them. Leaving them writable meant a prompt injection could simply
    # instruct the model to delete the deny list or rewrite a hook to `exit 0`, and in
    # auto mode nothing would prompt. Every other guard here rests on these two paths,
    # so they are the ones worth making mechanical rather than model-dependent.
    #
    # HONEST LIMIT: this covers Write/Edit/NotebookEdit only. The Bash tool is not
    # hooked for file writes, so `cat > settings.json` still gets through — the same
    # gap documented at the top of this file. What this closes is the path a model
    # actually takes to edit config, which is the Edit tool. Treat it as raising the
    # cost, not sealing the door.
    #
    # Edit these files outside Claude Code, which is the right workflow for security
    # policy anyway.
    */.claude/settings*.json)       blocked="claude settings file" ;;
    */.claude/hooks/*.sh)           blocked="claude hook script" ;;
    # 2026-10-16: hooks and sync scripts now live in the brain (~/Mind/AI) and
    # ~/.claude/hooks holds symlinks. The path above is matched AFTER readlink -f,
    # so without these arms the moved files would lose their protection.
    */Mind/AI/hooks/*.sh)           blocked="brain hook script" ;;
    */Mind/AI/setup/*)              blocked="brain setup/sync script" ;;
    # --- credential files found missing by audit, 2026-08-16 ---
    # why: registry/cluster/token files that hold live credentials in cleartext
    */.docker/config.json)          blocked="docker auth config" ;;
    */.gnupg/*)                     blocked="gnupg keyring" ;;
    *.npmrc)                        blocked="npm config (may hold auth tokens)" ;;
    */.kube/config)                 blocked="kubernetes config" ;;
    */.config/gh/hosts.yml)         blocked="github cli token file" ;;
    # why: direnv exports live in .envrc, which *.env patterns do not match
    *.envrc)                        blocked="direnv config (may hold secrets)" ;;
    *) exit 0 ;;
esac

echo "BLOCKED by secrets-guard hook: refusing to write $blocked at $file_path" >&2
echo "If this is intentional, edit the file directly outside Claude Code." >&2
exit 2
