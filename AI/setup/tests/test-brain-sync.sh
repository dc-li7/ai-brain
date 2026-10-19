#!/usr/bin/env bash
# End-to-end tests for brain-sync: two fake machines (a, b) and a fake stick, all in
# a temp folder. Includes the attacks the security review described.
#   bash AI/setup/tests/test-brain-sync.sh
set -uo pipefail
SRC="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"   # repo to copy as the brain
E="$(mktemp -d)"
trap 'rm -rf "$E"' EXIT
mkdir -p "$E/stub" "$E/stick" "$E/stick2"
printf '#!/bin/sh\nexit 0\n' > "$E/stub/notify-send"; chmod +x "$E/stub/notify-send"
export PATH="$E/stub:$PATH"
pass=0; fail=0
check() { if eval "$2"; then echo "PASS $1"; pass=$((pass+1)); else echo "FAIL $1"; fail=$((fail+1)); fi; }
sync() { local d=$1; shift; BRAIN_DIR="$d" BRAIN_STICK_DIR="${STICK:-$E/stick}" bash "$d/AI/setup/brain-sync" "$@" 2>&1; }
newmachine() {  # newmachine <dir> <name>: copy of the repo with its own git identity
    cp -r "$SRC" "$1"; rm -f "$1/.git/hooks/pre-commit"
    git -C "$1" config user.email "$2@example.com"; git -C "$1" config user.name "$2"
    git -C "$1" remote remove origin 2>/dev/null || true
}

newmachine "$E/a" a
out=$(sync "$E/a"); check "sync to a stick with no brain refuses (no silent copy)" '[[ $out == *"No brain on this stick"* ]] && [ ! -e "$E/stick/brain.git" ]'
out=$(sync "$E/a" --init); check "--init creates the stick copy" '[ -d "$E/stick/brain.git" ]'
out=$(sync "$E/a"); check "first sync pushes" '[[ $out == *"Brain synced"* ]]'
check "pre-push guard installed" '[ -x "$E/a/.git/hooks/pre-push" ]'
check "pre-push guard refuses GitHub" '! "$E/a/.git/hooks/pre-push" origin https://github.com/x/y.git 2>/dev/null'
check "pre-push guard allows the stick" '"$E/a/.git/hooks/pre-push" stick /run/media/u/BRAIN-STICK/brain.git'

git clone -q "$E/stick/brain.git" "$E/b"; git -C "$E/b" config user.email b@example.com; git -C "$E/b" config user.name b
printf -- '---\nname: b1\ndescription: From B\nmetadata:\n  type: user\n---\nb\n' > "$E/b/Memory/main/b1.md"
out=$(sync "$E/b"); check "memory-only change syncs without review" '[[ $out == *"Brain synced"* ]]'
out=$(sync "$E/a"); check "a receives b's memory" '[ -f "$E/a/Memory/main/b1.md" ] && grep -q b1.md "$E/a/Memory/main/MEMORY.md"'

# Attack: someone with the stick plants code in memory-index.
printf 'import pathlib; pathlib.Path("%s/PWNED").write_text("x")\n' "$E" >> "$E/b/AI/setup/memory-index"
git -C "$E/b" commit -qam "innocent looking"; git -C "$E/b" push -q origin HEAD:main
before=$(git -C "$E/a" rev-parse HEAD)
out=$(sync "$E/a"); check "planted code change pauses the sync" '[[ $out == *"Sync paused"* ]]'
check "planted code did NOT run" '[ ! -e "$E/PWNED" ]'
check "nothing was applied" '[ "$(git -C "$E/a" rev-parse HEAD)" = "$before" ] && ! grep -q PWNED "$E/a/AI/setup/memory-index"'
out=$(BRAIN_DIR="$E/a" BRAIN_STICK_DIR="$E/stick" setsid -w bash "$E/a/AI/setup/brain-sync" --review < /dev/null 2>&1); check "--review without a terminal applies nothing" '[ "$(git -C "$E/a" rev-parse HEAD)" = "$before" ] && [ ! -e "$E/PWNED" ]'
out=$(printf 'qno\n' | script -qec "BRAIN_DIR=$E/a BRAIN_STICK_DIR=$E/stick bash $E/a/AI/setup/brain-sync --review" /dev/null 2>&1)
check "--review answered no applies nothing" '[ "$(git -C "$E/a" rev-parse HEAD)" = "$before" ] && [ ! -e "$E/PWNED" ]'
# Undo the planted change on the stick, and add a real change the owner wants.
git -C "$E/b" revert --no-edit HEAD >/dev/null
mkdir -p "$E/b/AI/skills/new-skill"; printf -- '---\nname: new-skill\ndescription: x\n---\n' > "$E/b/AI/skills/new-skill/SKILL.md"
git -C "$E/b" add AI; git -C "$E/b" commit -qm "add a skill"; git -C "$E/b" push -q origin HEAD:main
out=$(sync "$E/a"); check "a wanted code change pauses too" '[[ $out == *"Sync paused"* ]] && [ ! -e "$E/a/AI/skills/new-skill/SKILL.md" ]'
out=$(printf 'qyes\n' | script -qec "BRAIN_DIR=$E/a BRAIN_STICK_DIR=$E/stick bash $E/a/AI/setup/brain-sync --review" /dev/null 2>&1)
check "--review answered yes applies it" '[[ $out == *"Brain synced"* ]] && [ -f "$E/a/AI/skills/new-skill/SKILL.md" ] && ! grep -q PWNED "$E/a/AI/setup/memory-index"'

# Attack: a git setting that runs a program.
git -C "$E/a" config core.fsmonitor "touch $E/FSMON"
out=$(sync "$E/a"); check "risky git config refuses the sync" '[[ $out == *"unexpected git settings"* ]]'
check "the fsmonitor program did NOT run" '[ ! -e "$E/FSMON" ]'
git -C "$E/a" config --unset core.fsmonitor
# remote.*.uploadpack names the program git runs to read the stick: allowlist, not blocklist.
git -C "$E/a" config remote.stick.uploadpack "touch $E/UPLOADPACK; git-upload-pack"
out=$(sync "$E/a"); check "any git setting outside the allowlist refuses the sync" '[[ $out == *"unexpected git settings"* ]] && [ ! -e "$E/UPLOADPACK" ]'
git -C "$E/a" config --unset remote.stick.uploadpack

# Attack: an Obsidian plugin (JavaScript that runs when the vault opens) planted on the stick.
mkdir -p "$E/b/.obsidian/plugins/evil"; echo 'require("child_process").exec("id")' > "$E/b/.obsidian/plugins/evil/main.js"
git -C "$E/b" add .obsidian; git -C "$E/b" commit -qm "theme"; git -C "$E/b" push -q origin HEAD:main
out=$(sync "$E/a"); check "a planted Obsidian plugin pauses the sync" '[[ $out == *"Sync paused"* ]] && [ ! -e "$E/a/.obsidian/plugins/evil/main.js" ]'
git -C "$E/b" revert --no-edit HEAD >/dev/null; git -C "$E/b" push -q origin HEAD:main
out=$(sync "$E/a")   # plugin added then removed: nothing left to review
# Normal Obsidian use (settings, not plugins) must not pause the other machine.
mkdir -p "$E/b/.obsidian"; echo '{"theme":"obsidian"}' > "$E/b/.obsidian/appearance.json"
git -C "$E/b" add .obsidian; git -C "$E/b" commit -qm "theme"; git -C "$E/b" push -q origin HEAD:main
out=$(sync "$E/a"); check "Obsidian settings changes sync without review" '[[ $out == *"Brain synced"* ]] && [ -f "$E/a/.obsidian/appearance.json" ]'

# Attack: a symlink planted on the stick (here MEMORY.md pointing at a script).
git -C "$E/b" pull -q --rebase origin main
ln -sf ../../AI/setup/link.sh "$E/b/Memory/main/MEMORY.md"
git -C "$E/b" add Memory; git -C "$E/b" commit -qm "index"; git -C "$E/b" push -q origin HEAD:main
out=$(sync "$E/a"); check "a planted symlink pauses the sync" '[[ $out == *"Sync paused"* ]] && [ ! -L "$E/a/Memory/main/MEMORY.md" ]'
git -C "$E/b" revert --no-edit HEAD >/dev/null; git -C "$E/b" push -q origin HEAD:main; out=$(sync "$E/a")
# And memory-index itself never writes through a link made locally.
cp "$E/a/AI/setup/link.sh" "$E/link.before"; ln -sf ../../AI/setup/link.sh "$E/a/Memory/main/MEMORY.md"
BRAIN_DIR="$E/a" python3 -I "$E/a/AI/setup/memory-index" >/dev/null 2>&1; rc=$?
check "memory-index refuses to write through a symlink" '[ $rc -ne 0 ] && cmp -s "$E/a/AI/setup/link.sh" "$E/link.before"'
git -C "$E/a" checkout -q -- Memory/main/MEMORY.md

# Secret committed by hand, outside brain-sync.
printf 'token = ghp_%s\n' "aB3dE5fG7hI9jK1lM3nO5pQ7rS9tU1vW3xY5" > "$E/a/Inbox/leak.md"
git -C "$E/a" add Inbox/leak.md; git -C "$E/a" commit -qm "by hand"
out=$(sync "$E/a"); check "secret in a hand-made commit blocks the push (gitleaks, or the basic check if it's missing)" '[[ $out == *"possible secret in a commit"* ]] && [ "$(git -C "$E/stick/brain.git" log -1 --format=%s main)" != "by hand" ]'
# Without a usable gitleaks (here: a fake one too old to have `git`), the basic check must catch it.
mkdir -p "$E/oldgl"; printf '#!/bin/sh\nexit 1\n' > "$E/oldgl/gitleaks"; chmod +x "$E/oldgl/gitleaks"
out=$(PATH="$E/oldgl:$PATH" sync "$E/a"); check "secret in a hand-made commit blocks the push (basic check)" '[[ $out == *"too old"* && $out == *"possible secret in a commit"* ]]'
git -C "$E/a" reset -q --hard HEAD~1

# Commit failure must not be reported as success.
cp -r "$E/a" "$E/c"; git -C "$E/c" config --unset user.email; git -C "$E/c" config --unset user.name
git -C "$E/c" config user.useConfigOnly true   # never guess an identity from EMAIL or the hostname
echo "new note" > "$E/c/Inbox/n.md"
out=$(env -u EMAIL HOME="$E/emptyhome" XDG_CONFIG_HOME="$E/emptyhome/.config" GIT_CONFIG_NOSYSTEM=1 BRAIN_DIR="$E/c" BRAIN_STICK_DIR="$E/stick" bash "$E/c/AI/setup/brain-sync" 2>&1)
check "missing git identity reports commit failed, not synced" '[[ $out == *"commit failed"* && $out != *"Brain synced"* ]]'

# A different stick with an unrelated brain.
git init -q --bare -b main "$E/stick2/brain.git"; git clone -q "$E/stick2/brain.git" "$E/x" 2>/dev/null
git -C "$E/x" -c user.email=x@e -c user.name=x commit -q --allow-empty -m other; git -C "$E/x" push -q origin HEAD:main
out=$(STICK="$E/stick2" sync "$E/a"); check "unrelated stick refused" '[[ $out == *"unrelated history"* ]]'

# Two syncs at once.
exec 8>"$E/a/.git/brain-sync.lock"; flock 8
out=$(sync "$E/a"); check "second sync at the same time refused" '[[ $out == *"Already syncing"* ]]'
exec 8>&-

echo "passed: $pass  failed: $fail"
(( fail == 0 ))
