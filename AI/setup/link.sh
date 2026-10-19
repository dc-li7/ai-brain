#!/usr/bin/env bash
# link.sh: point this machine's AI tools at the brain. Safe to run again.
#   link.sh laptop    or    link.sh desktop
# Links every skill, agent, command and guard hook in ~/Mind/AI into the folders
# Claude Code (~/.claude), Codex (~/.codex, ~/.agents) and Grok/Gemini/Cursor
# (~/.agents) read. Never deletes anything: whatever is in the way gets moved to
# ~/.brain-backup/<timestamp>/ first. Settings files are not touched.
set -euo pipefail

role="${1:-}"
case "$role" in laptop|desktop) ;; *) echo "usage: $0 laptop|desktop" >&2; exit 2 ;; esac

BRAIN="${BRAIN_DIR:-$HOME/Mind}"
AI="$BRAIN/AI"
backup="$HOME/.brain-backup/$(date +%Y%m%d-%H%M%S)"
skip_file="$AI/setup/desktop-only.txt"
linked=0 moved=0 skipped=0

skipped_here() {  # $1 = kind/name
    [ "$role" = desktop ] && return 1
    grep -qE "^$1([[:space:]]|$)" "$skip_file"
}

link() {  # link <target in brain> <link path>
    local target="$1" path="$2"
    if [ -L "$path" ] && [ "$(readlink -f "$path")" = "$(readlink -f "$target")" ]; then
        return 0
    fi
    mkdir -p "$(dirname "$path")"
    if [ -e "$path" ] || [ -L "$path" ]; then
        mkdir -p "$backup$(dirname "$path")"
        mv "$path" "$backup$path"
        moved=$((moved + 1))
    fi
    ln -s "$target" "$path"
    linked=$((linked + 1))
}

for d in "$AI"/skills/*/; do
    name=$(basename "$d")
    if skipped_here "skill/$name"; then skipped=$((skipped + 1)); continue; fi
    link "$AI/skills/$name" "$HOME/.claude/skills/$name"
    link "$AI/skills/$name" "$HOME/.agents/skills/$name"
done

for f in "$AI"/agents/*.md; do
    name=$(basename "$f" .md)
    if skipped_here "agent/$name"; then skipped=$((skipped + 1)); continue; fi
    link "$f" "$HOME/.claude/agents/$name.md"
done

for e in "$AI"/commands/*; do
    name=$(basename "$e")
    if skipped_here "command/$name"; then skipped=$((skipped + 1)); continue; fi
    link "$e" "$HOME/.claude/commands/$name"
done

for h in "$AI"/hooks/*.sh; do
    link "$h" "$HOME/.claude/hooks/$(basename "$h")"
done

link "$BRAIN/AGENTS.md" "$HOME/.codex/AGENTS.md"
link "$AI/setup/brain-sync" "$HOME/.local/bin/brain-sync"
# The approval window the AI uses for sudo and anything else it is blocked from.
link "$AI/setup/confirm-run" "$HOME/.local/bin/confirm-run"
link "$AI/setup/confirm-open" "$HOME/.local/bin/confirm-open"

echo "link.sh ($role): $linked new links, $skipped skipped as desktop-only, $moved existing items moved to ${backup}"
[ "$moved" -gt 0 ] || rmdir "$backup" 2>/dev/null || true
