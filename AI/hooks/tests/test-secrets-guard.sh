#!/usr/bin/env bash
# test-secrets-guard.sh — test suite for secrets-guard.sh PreToolUse hook
# Invokes the hook with crafted JSON on stdin and checks exit codes.
# Exit 0 = all tests pass, exit 1 = at least one failure.
set -uo pipefail

HOOK="${HOOK:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/secrets-guard.sh}"
PASS=0
FAIL=0
TOTAL=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

run_test() {
    local description="$1"
    local input="$2"
    local expected="$3"

    TOTAL=$((TOTAL + 1))
    actual=$(echo "$input" | "$HOOK" 2>/dev/null; echo $?)
    # The last line of actual is the exit code
    actual=$(echo "$actual" | tail -1)

    if [ "$actual" -eq "$expected" ]; then
        printf "${GREEN}PASS${NC} [exit %d] %s\n" "$actual" "$description"
        PASS=$((PASS + 1))
    else
        printf "${RED}FAIL${NC} %s — expected exit %d, got exit %d\n" "$description" "$expected" "$actual"
        FAIL=$((FAIL + 1))
    fi
}

# Helper to build JSON payload
json_for() {
    local path="$1"
    printf '{"tool_input":{"file_path":"%s"}}' "$path"
}

echo "========================================"
echo " secrets-guard.sh test suite"
echo "========================================"
echo ""

# ----------------------------------------------------------
echo "--- MUST BLOCK (exit 2): pre-existing patterns ---"
# ----------------------------------------------------------
run_test "BLOCK .env in home dir" \
    "$(json_for '/home/alice/.env')" 2

run_test "BLOCK .env.production in config/" \
    "$(json_for '/home/alice/config/.env.production')" 2

run_test "BLOCK credentials.json" \
    "$(json_for '/p/credentials.json')" 2

run_test "BLOCK server.pem" \
    "$(json_for '/p/server.pem')" 2

run_test "BLOCK tls.key" \
    "$(json_for '/p/tls.key')" 2

run_test "BLOCK secrets dir — db.yaml" \
    "$(json_for '/p/config/secrets/db.yaml')" 2

run_test "BLOCK .secrets dir — token" \
    "$(json_for '/p/config/.secrets/token')" 2

run_test "BLOCK ssh id_rsa" \
    "$(json_for '/home/alice/.ssh/id_rsa')" 2

run_test "BLOCK ssh id_ed25519" \
    "$(json_for '/home/alice/.ssh/id_ed25519')" 2

run_test "BLOCK ssh id_ecdsa" \
    "$(json_for '/home/alice/.ssh/id_ecdsa')" 2

echo ""
echo "--- MUST BLOCK (exit 2): newly added patterns ---"

run_test "BLOCK cert.pfx" \
    "$(json_for '/p/cert.pfx')" 2

run_test "BLOCK keystore.p12" \
    "$(json_for '/p/keystore.p12')" 2

run_test "BLOCK secrets.yaml in subdir" \
    "$(json_for '/p/config/secrets.yaml')" 2

run_test "BLOCK secrets.yml in subdir" \
    "$(json_for '/p/config/secrets.yml')" 2

run_test "BLOCK secrets.json in deploy/" \
    "$(json_for '/p/deploy/secrets.json')" 2

run_test "BLOCK secret.env in config/" \
    "$(json_for '/p/config/secret.env')" 2

run_test "BLOCK bare relative secrets.yaml" \
    "$(json_for 'secrets.yaml')" 2

run_test "BLOCK .netrc" \
    "$(json_for '/home/alice/.netrc')" 2

run_test "BLOCK .pgpass" \
    "$(json_for '/home/alice/.pgpass')" 2

run_test "BLOCK .my.cnf" \
    "$(json_for '/home/alice/.my.cnf')" 2

run_test "BLOCK .aws/config" \
    "$(json_for '/home/alice/.aws/config')" 2

run_test "BLOCK service_account_key.json (with prefix)" \
    "$(json_for '/p/my-service_account_key.json')" 2

run_test "BLOCK service_account.json" \
    "$(json_for '/p/service_account.json')" 2

run_test "BLOCK gcp-project-key.json" \
    "$(json_for '/p/gcp-project-key.json')" 2

run_test "BLOCK firebase-adminsdk.json" \
    "$(json_for '/p/firebase-adminsdk.json')" 2

run_test "BLOCK htpasswd (apache2)" \
    "$(json_for '/etc/apache2/htpasswd')" 2

run_test "BLOCK /etc/shadow" \
    "$(json_for '/etc/shadow')" 2

run_test "BLOCK master.key (via *.key)" \
    "$(json_for '/p/config/master.key')" 2

run_test "BLOCK .ssh/config" \
    "$(json_for '/home/alice/.ssh/config')" 2

echo ""
# ----------------------------------------------------------
echo "--- MUST ALLOW (exit 0) ---"
# ----------------------------------------------------------
run_test "ALLOW README.md" \
    "$(json_for '/home/alice/projects/myapp/README.md')" 0

run_test "ALLOW config.py in src/" \
    "$(json_for '/p/src/config.py')" 0

run_test "ALLOW security-guide.md" \
    "$(json_for '/p/docs/security-guide.md')" 0

run_test "ALLOW secrets_manager.py (underscore, not dot)" \
    "$(json_for '/p/secrets_manager.py')" 0

run_test "ALLOW secret_storage.py (underscore, not dot)" \
    "$(json_for '/p/secret_storage.py')" 0

run_test "ALLOW id_rsa.pub (public key)" \
    "$(json_for '/home/alice/.ssh/id_rsa.pub')" 0

run_test "ALLOW known_hosts" \
    "$(json_for '/home/alice/.ssh/known_hosts')" 0

run_test "ALLOW shadow/component.py (shadow as dir name)" \
    "$(json_for '/p/src/shadow/component.py')" 0

run_test "ALLOW generate_htpasswd.py" \
    "$(json_for '/p/generate_htpasswd.py')" 0

echo ""
# ----------------------------------------------------------
echo "--- EDGE CASES ---"
# ----------------------------------------------------------
run_test "ALLOW empty file_path" \
    '{"tool_input":{"file_path":""}}' 0

run_test "ALLOW missing file_path field" \
    '{"tool_input":{}}' 0

# Malformed JSON must fail CLOSED (exit 2).
# Before 2026-07-29 the hook ran `set -e`, so a jq parse failure aborted with
# jq's own exit code (5). Claude Code reads anything but 2 as a non-blocking
# error — meaning garbage input silently disabled the guard. That is now an
# explicit `exit 2`. If this test starts failing with exit 0 or 5, the guard
# has quietly reverted to failing open.
echo ""
echo "--- MALFORMED JSON must fail CLOSED ---"
TOTAL=$((TOTAL + 1))
malformed_actual=$(echo 'not json' | "$HOOK" 2>/dev/null; echo $?)
malformed_actual=$(echo "$malformed_actual" | tail -1)
if [ "$malformed_actual" -eq 2 ]; then
    printf '%sPASS%s [exit 2] Malformed JSON fails closed (blocks)\n' "$GREEN" "$NC"
    PASS=$((PASS + 1))
else
    printf "${RED}FAIL${NC} Malformed JSON exited %d — expected 2 (fail closed). Guard fails OPEN on bad input!\n" "$malformed_actual"
    FAIL=$((FAIL + 1))
fi

run_test "ALLOW path with spaces" \
    "$(json_for '/home/alice/my docs/notes.md')" 0

# Symlink resolution: an innocuous-looking alias pointing at a secret must be
# caught. The hook resolves with readlink -f before matching, so the pattern
# sees the real target rather than the harmless name.
echo ""
echo "--- SYMLINK RESOLUTION ---"
TOTAL=$((TOTAL + 1))
_tmpd=$(mktemp -d)
: > "$_tmpd/.env"
ln -sf "$_tmpd/.env" "$_tmpd/innocent-notes.txt"
symlink_actual=$(echo "{\"tool_input\":{\"file_path\":\"$_tmpd/innocent-notes.txt\"}}" | "$HOOK" 2>/dev/null; echo $?)
symlink_actual=$(echo "$symlink_actual" | tail -1)
if [ "$symlink_actual" -eq 2 ]; then
    printf '%sPASS%s [exit 2] symlink to .env is resolved and blocked\n' "$GREEN" "$NC"
    PASS=$((PASS + 1))
else
    printf "${RED}FAIL${NC} symlink to .env exited %d — expected 2. Symlink bypass is OPEN!\n" "$symlink_actual"
    FAIL=$((FAIL + 1))
fi
rm -rf "$_tmpd"

echo ""
echo "--- CRITICAL: the policy files must protect THEMSELVES ---"
# Inverted 2026-08-16. This block previously asserted that allowing edits to the
# guard was correct, and reported a block as a CRITICAL failure -- encoding the
# vulnerability as the specification. An audit demonstrated the consequence: a
# prompt injection could tell the model to rewrite this hook to `exit 0` or delete
# the deny list, and in auto mode nothing would prompt. These files ARE the security
# policy, so they are now blocked and must be edited outside Claude Code.
#
# Note the coverage limit: the Bash tool is not hooked for file writes, so this
# raises the cost of tampering rather than sealing it. See the header of the guard.
for _policy_file in \
    "$HOME/.claude/hooks/secrets-guard.sh" \
    "$HOME/.claude/hooks/sudo-block.sh" \
    "$HOME/.claude/settings.json" \
    "$HOME/.claude/settings.local.json" \
    "$HOME/Mind/AI/hooks/secrets-guard.sh" \
    "$HOME/Mind/AI/setup/brain-sync" \
    "$HOME/Mind/AI/setup/confirm-run" \
    "$HOME/Mind/AGENTS.md" \
    "$HOME/Mind/CLAUDE.md" \
    "$HOME/.claude/CLAUDE.md" \
    "$HOME/Mind/AI/commands/sys.md" \
    "$HOME/Mind/AI/agents/coder.md" \
    "$HOME/Mind/AI/skills/sudo-safe/SKILL.md" \
    "$HOME/Mind/AI/templates/git-template.md" \
    "$HOME/.claude/commands/git.md" \
    "$HOME/Mind/.gitattributes" \
    "$HOME/Mind/.obsidian/plugins/x/main.js" \
    "$HOME/Mind/.claude/settings.local.json" \
    "$HOME/Mind/.git/config" \
    "$HOME/Mind/.git/hooks/pre-push" \
    /home/alice/projects/myapp/.git/config \
    "$HOME/.gitconfig" \
    "$HOME/.config/git/config" \
    "$HOME/.config/git/attributes" \
    "$HOME/Mind/.git/info/attributes" \
    "$HOME/.claude.json" \
    /home/alice/projects/myapp/.mcp.json \
    "$HOME/.codex/config.toml" \
    /home/alice/projects/myapp/.claude/settings.local.json
do
    TOTAL=$((TOTAL + 1))
    _rc=$(printf '{"tool_input":{"file_path":"%s"}}' "$_policy_file" | "$HOOK" >/dev/null 2>&1; echo $?)
    if [ "$_rc" -eq 2 ]; then
        printf '%sPASS%s [exit 2] policy file is self-protected: %s\n' "$GREEN" "$NC" "$_policy_file"
        PASS=$((PASS + 1))
    else
        printf "${RED}FAIL${NC} *** CRITICAL *** %s is WRITABLE via Claude Code (exit %d) — an injection could disarm the guards!\n" "$_policy_file" "$_rc"
        FAIL=$((FAIL + 1))
    fi
done

echo "--- the AI must still be able to save memories and notes ---"
for _ok_file in \
    "$HOME/Mind/Memory/main/feedback-example.md" \
    "$HOME/Mind/Memory/main/MEMORY.md" \
    "$HOME/Mind/Log/2026-10-19.md" \
    "$HOME/Mind/Projects/Example.md" \
    "$HOME/Mind/Inbox/note.md"
do
    TOTAL=$((TOTAL + 1))
    _rc=$(printf '{"tool_input":{"file_path":"%s"}}' "$_ok_file" | "$HOOK" >/dev/null 2>&1; echo $?)
    if [ "$_rc" -eq 0 ]; then
        printf '%sPASS%s [exit 0] still writable: %s\n' "$GREEN" "$NC" "$_ok_file"
        PASS=$((PASS + 1))
    else
        printf "${RED}FAIL${NC} %s is blocked (exit %d) but the AI needs to write it\n" "$_ok_file" "$_rc"
        FAIL=$((FAIL + 1))
    fi
done

echo ""
# ----------------------------------------------------------
echo "========================================="
echo " KNOWN FALSE POSITIVES — empirical check"
echo "========================================="
# ----------------------------------------------------------
echo ""

# These are OBSERVATIONS, not assertions — they document known edge behavior so
# a future change to it is visible. They deliberately do NOT touch PASS/TOTAL:
# counting a recording as a "pass" made the tally read 100% green while
# describing a false positive two lines above it.
observe() {
    local label="$1" path="$2" note_block="$3" note_allow="$4" rc
    rc=$(echo "{\"tool_input\":{\"file_path\":\"$path\"}}" | "$HOOK" 2>/dev/null; echo $?)
    rc=$(echo "$rc" | tail -1)
    printf "${YELLOW}OBSERVED${NC} %s — exit %d\n" "$label" "$rc"
    if [ "$rc" -eq 2 ]; then printf "  -> BLOCKED. %s\n" "$note_block"
    else printf "  -> ALLOWED. %s\n" "$note_allow"; fi
}

observe "/p/credential_loader_test.py" "/p/credential_loader_test.py" \
    "Unexpected — *credentials* should need the plural. Check which arm matched." \
    "Expected: *credentials* needs plural 'credentials'; singular does not match."

observe "/p/.env.example" "/p/.env.example" \
    "Known FALSE POSITIVE: *.env.* catches templates, which hold placeholders not secrets." \
    "Unexpected — the *.env.* arm should have caught this."

observe "/home/alice/.envrc" "/home/alice/.envrc" \
    "Covered." \
    "Known GAP (flagged by security-auditor): direnv .envrc can hold 'export API_KEY=...' but ends in .envrc, so *.env does not match. Add *.envrc if you use direnv for secrets."

echo ""
echo "========================================="
echo " FINAL TALLY"
echo "========================================="
printf "Total: %d | ${GREEN}Pass: %d${NC} | ${RED}Fail: %d${NC}\n" "$TOTAL" "$PASS" "$FAIL"

if [ "$FAIL" -gt 0 ]; then
    echo ""
    printf "${RED}%d test(s) FAILED.${NC}\n" "$FAIL"
    exit 1
else
    echo ""
    printf "${GREEN}All %d tests passed.${NC}\n" "$TOTAL"
    exit 0
fi
