#!/usr/bin/env bash
# Regression tests for sudo-block.sh.
#
# Every ALLOWED line here was a live bypass before 2026-08-16. Run this after any
# change to the hook's regex:
#
#   bash AI/hooks/tests/test-sudo-block.sh
#
# Note the obfuscated cases at the bottom are expected to PASS THROUGH. They are
# recorded, not fixed: a regex cannot decide them, and pretending otherwise would
# be worse than documenting the limit. The control for those is the deny list in
# settings.json plus not granting blanket execution primitives.
set -uo pipefail

HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/sudo-block.sh"
pass=0
fail=0

# expect: "block" or "allow"
check() {
    local expect="$1" cmd="$2" rc
    printf '%s' "$(jq -Rn --arg c "$cmd" '{tool_input:{command:$c}}')" \
        | bash "$HOOK" >/dev/null 2>&1
    rc=$?
    local got="allow"
    [ "$rc" -eq 2 ] && got="block"
    if [ "$got" = "$expect" ]; then
        pass=$((pass + 1))
        printf '  ok       [%s] %s\n' "$got" "$cmd"
    else
        fail=$((fail + 1))
        printf '  FAIL     expected %s, got %s: %s\n' "$expect" "$got" "$cmd"
    fi
}

echo "--- must block: plain and path-qualified escalation ---"
check block 'sudo systemctl restart myapp'
check block '/usr/bin/sudo systemctl restart myapp'
check block '/bin/su - root'
check block 'doas id'
check block 'pkexec id'
check block 'run0 id'
check block 'machinectl shell root@'
check block 'systemd-run --uid=0 /bin/sh'
# ai-brain issue #5 (2026-10-30): sudoedit is its own binary, so `sudo` was followed
# by `e` and the token match missed it.
check block 'sudoedit /etc/hosts'
check block '/usr/bin/sudoedit /etc/fstab'
check block 'bash -c "sudoedit /etc/hosts"'

echo "--- must block: escalation after a shell operator ---"
check block 'echo hi && sudo id'
check block 'echo hi; sudo id'
check block 'echo hi | xargs sudo'
check block 'true || /usr/bin/doas id'

echo "--- must block: escalation inside a quoted string ---"
# All four were live bypasses until 2026-08-16; an independent audit caught them.
# A quoted string is the most natural way for a model to write these, so this is
# the likeliest real-world shape, not an exotic one.
check block 'bash -c "sudo id"'
check block "sh -c 'doas id'"
check block 'ssh deploy@203.0.113.10 "sudo systemctl restart myapp"'
check block 'bash -c "sudo"'

echo "--- must block: backslash and bang prefixes ---"
# Found by a second adversarial pass. A backslash before a non-metacharacter is a
# no-op in bash, so \sudo runs exactly as sudo does; !sudo with no space is the
# git-alias payload shape.
check block '\sudo id'
check block 'bash -c "\sudo id"'
check block "git config alias.x '!sudo id'"
check block "git config alias.x '! sudo id'"

echo "--- must allow: ordinary commands that merely contain the letters ---"
check allow 'systemctl --user status pipewire'
check allow 'grep -r pseudocode ./src'
check allow 'ls /home/alice/subdir'
check allow 'python3 -m pytest tests/'
check allow 'git status'

echo "--- known limits: obfuscation a regex cannot decide (recorded, not fixed) ---"
# shellcheck disable=SC2016  # the literal, unexpanded string is the test input
check allow 'S=su; D=do; $S$D id'
check allow 'echo c3VkbyBpZAo= | base64 -d | bash'

echo
echo "passed: $pass   failed: $fail"
[ "$fail" -eq 0 ]
