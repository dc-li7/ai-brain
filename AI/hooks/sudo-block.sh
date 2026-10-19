#!/usr/bin/env bash
# sudo-block.sh — block Bash commands that escalate privilege
# PreToolUse hook for Bash. Exit 2 = block, 0 = allow.
# Enforces the AGENTS.md rule: hand privileged commands back to the user.
#
# WHAT THIS IS AND IS NOT
# ----------------------
# This stops the *casual and accidental* path: the agent reaching for `sudo` because
# that is how the task is normally done. It is NOT an adversarial control, and it
# cannot be one. Anything that can run a shell can escalate without the string ever
# appearing -- `S=su; D=do; $S$D`, base64 through a pipe, an interpreter's system()
# call. A regex over a command line cannot decide that; it is the halting problem
# wearing a moustache.
#
# The controls that actually hold are in settings.json: the `deny` rules, and not
# granting blanket execution primitives (python3:*, find:*, pip install:*) in the
# allow list. This hook is the seatbelt, not the brakes.
#
# Audited 2026-08-16: the previous regex required whitespace or line-start before
# the token, so `/usr/bin/sudo` sailed straight through, as did doas, pkexec and
# run0. Six of eight tested vectors passed. See hooks/tests/test-sudo-block.sh.
set -uo pipefail

# Parse failures fail CLOSED, matching secrets-guard.sh. A security control that
# quietly switches itself off is worse than one that is loudly broken.
if ! command -v jq >/dev/null 2>&1; then
    echo "BLOCKED by sudo-block: jq not found, cannot vet this command." >&2
    exit 2
fi

input=$(cat)

if ! command=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null); then
    echo "BLOCKED by sudo-block: could not parse hook input." >&2
    exit 2
fi

[ -z "$command" ] && exit 0

# Escalation binaries, matched as whole tokens and tolerant of a leading path.
#
#   sudo doas pkexec  — the usual three
#   run0              — systemd's newer sudo replacement, ships on Arch
#   su                — still an escalation, still worth handing back
#   machinectl        — `machinectl shell` gives a root shell in a container/host
#   systemd-run       — `--uid=0` / `-p User=root` runs a unit as root
#
# The leading (/[^[:space:]]*/)? is the fix for the path-qualified bypass: it
# consumes /usr/bin/ before the token so /usr/bin/sudo matches exactly as sudo does.
ESCALATORS='sudo|doas|pkexec|run0|su|machinectl|systemd-run'

# Preceded by: start of string, whitespace, or a shell metacharacter that begins a
# new command context (pipe, and/or, semicolon, newline, subshell, command
# substitution) -- OR a quote.
#
# The quotes are not decorative. Omitting them was a live bypass found by an
# independent audit on 2026-08-16: the single most natural way for a model to
# write these commands is inside a quoted string, and all three of
#     bash -c "sudo ..."      sh -c 'doas ...'      ssh host "sudo ..."
# walked straight through the first version of this regex. The trailing class
# takes quotes too, so `bash -c "sudo"` with nothing after the token still trips.
# The class also carries `\` and `!`, both found by a second adversarial pass:
#   \sudo   is identical to sudo in bash -- a backslash before a non-metacharacter
#           is a no-op, so it runs while reading as something else.
#   !sudo   with no space is how a git alias payload is written
#           (git config alias.x '!sudo id'), and the space-less form slipped both
#           halves of the pattern.
# Inside a bracket expression POSIX treats a backslash as literal, so one is enough.
if printf '%s' "$command" \
    | grep -qE "(^|[|&;(\"'\`!\\]|\\\$\(|[[:space:]])[[:space:]]*(/[^[:space:]]*/)?(${ESCALATORS})([[:space:]\"'\\]|$)"
then
    echo "BLOCKED by sudo-block hook: never escalate privilege from Claude." >&2
    echo "Hand the command back to the user to run manually:" >&2
    echo "  $command" >&2
    exit 2
fi

exit 0
