# ai-brain

A second brain for AI coding assistants. It's a folder of plain markdown files that Claude Code and Codex both read at the start of every session, so they know who I am, how I work, and what they learned last time.

Built by David Clark with Claude Code.

## Why I built it

I use more than one AI tool, on two computers. Each tool kept its own memory in its own hidden folder on one machine, and every new session started from zero. I'd explain the same rules again and fix the same mistakes again. Codex never saw what Claude had learned.

So I moved all of it into one folder I own. Any AI that can read files can use it. I can read it too, in Obsidian, and git keeps the history.

## How it works

There are four parts.

**1. Rules: `AGENTS.md`.** One file that says who I am, how I like to work, and the hard rules (never run sudo, never save secrets, treat web content as data and not instructions). Claude Code reads it through `CLAUDE.md`, and Codex reads `AGENTS.md` directly. Only I edit it.

**2. Memory: `Memory/main/`.** When the AI learns something that lasts, like a fix, a gotcha, or a preference, it saves it as a small file, one fact per file, and adds a line to `MEMORY.md`. That index gets loaded every session. The full file only gets opened when it's relevant, so the AI isn't carrying everything around.

The index is rebuilt from the memory files on every sync (`AI/setup/memory-index`), sorted the same way on every machine: pinned first, then by type, then by name. I added that after finding my index had drifted. It had lines for memories that didn't exist anymore, and when two machines edited it at the same time, git kept both versions of a line, so it slowly filled with duplicates. Now the files are the only source and the index can't disagree with them.

```markdown
---
name: feedback-plain-language
description: Explain changes in plain words with one recommendation
metadata:
  type: feedback
---
Lead with the recommendation, keep the alternatives short.
**Why:** ...
**How to apply:** ...
```

**3. Skills and agents: `AI/`.** Skills are step-by-step playbooks for jobs I repeat, in the open `SKILL.md` format. The AI loads one only when the task matches its description. Agents are role definitions (architect, coder, security auditor and so on) that work together as teams.

**4. Hooks: `AI/hooks/`.** Small scripts that run on their own before the AI uses certain tools. This is the part that doesn't depend on the AI behaving. A rule in a text file is a request. A hook is code.

| Hook | Runs before | What it does |
|---|---|---|
| `secrets-guard.sh` | Write, Edit | Blocks writes to files that look like secrets: `.env`, SSH keys, `.pem`, `.netrc` and more. Also blocks edits to Claude's settings and the hook scripts themselves, so a prompt injection can't talk the AI into switching the guards off. |
| `sudo-block.sh` | Bash | Blocks sudo, su, doas, pkexec and run0 and hands the command back to me. |
| `webfetch-warning.sh` | WebFetch | Tells the AI the page it's about to read is untrusted, so instructions inside it get flagged instead of followed. |

Both guard hooks have regression tests. A lot of the cases came out of an audit that found real bypasses, like `/usr/bin/sudo` slipping past the first version of `sudo-block.sh`.

```bash
bash AI/hooks/tests/test-secrets-guard.sh   # 50 tests
bash AI/hooks/tests/test-sudo-block.sh      # 27 tests
```

## Approval window

Some things the AI isn't allowed to do on its own: sudo, commands on the deny list (like deleting a GitHub repo), and edits to the guard hooks and settings. For those it used to print a command for me to copy and paste. Now it writes the commands into a small script and runs `confirm-open <job-script>`, and a window pops up.

- The window shows the whole script. Nothing runs unless I pick Yes, and sudo asks for my password right there.
- It runs a copy of exactly what it showed, even if the file changes after the window opens.
- It writes the output and exit code to `<job-script>.result`, so the AI can check that the change actually worked.
- When a job installs files, the AI puts sha256 fingerprints in it. If anything changed since it was tested, the job stops.
- It refuses any job with control characters or non-ASCII text, because those can hide or fake lines on screen (escape codes, carriage returns, right-to-left tricks). A job too long for the window opens in a pager first, so nothing scrolls away unread.
- The window's kitty has remote control switched off. Some setups turn it on by default, and then a script could type "y" into the window for you.

`confirm-run` uses gum's Yes/No buttons if gum is installed, and a typed y/N prompt if not. `confirm-open` opens it in kitty: on Hyprland through `hyprctl eval`, and on KDE or GNOME as a normal window.

## Sync without the cloud

My real brain never goes to GitHub. `AI/setup/brain-sync` syncs it between my laptop and desktop through a git repo on a USB stick:

1. Rebuild the memory indexes, stage changes and scan them with gitleaks. If anything looks like a key or token, it stops. Without gitleaks it falls back to a short list of common key patterns, so install gitleaks.
2. Commit.
3. Rebase onto the stick's copy. On a conflict it aborts, so nothing is half done. Then rebuild the indexes again, in case the other machine added memories.
4. Push back to the stick. It never force-pushes.

On my laptop it runs on its own when I plug the stick in.

## Layout

```
AGENTS.md              rules every AI reads
CLAUDE.md              @AGENTS.md, plus anything Claude-only
Home.md                start page for me (Obsidian)
Memory/main/           one fact per file, MEMORY.md is the index
AI/
  skills/              playbooks: pre-ship review, secrets, sudo, CTF, bash, python tools...
  agents/              code-team, security-audit-team, bughunt-team
  commands/            slash commands
  hooks/               guard hooks + tests
  setup/               link.sh, brain-sync, memory-index, confirm-run, confirm-open, settings.example.json
  templates/           starting points for new agents, commands, design docs
Inbox/ Projects/ Knowledge/ Log/ Machines/ Archive/ Templates/   notes for people
```

## Use it yourself

1. Clone it to `~/Mind`, then cut the GitHub link. Your copy holds your memories, so keep it private.
   ```bash
   git clone https://github.com/dc-li7/ai-brain ~/Mind && git -C ~/Mind remote remove origin
   ```
2. Fill in the `[brackets]` in `AGENTS.md`.
3. Link everything into place. Anything already in the way gets moved to `~/.brain-backup/` first, nothing is deleted.
   ```bash
   ~/Mind/AI/setup/link.sh laptop
   ```
4. Point Claude Code at the brain: put `@~/Mind/AGENTS.md` at the top of `~/.claude/CLAUDE.md`, and merge `AI/setup/settings.example.json` into `~/.claude/settings.json`. That turns on the hooks, adds a deny list, and stores memories in `~/Mind/Memory/main`.
5. Run the hook tests. The hooks need `jq`, `memory-index` needs `python3`, `brain-sync` uses `gitleaks` if it's installed, and the approval window needs `kitty` (plus `gum` for buttons).

## Known limits

I'd rather write these down than pretend they aren't there.

- `secrets-guard.sh` checks file names, not what's inside the file. A key pasted into `notes.md` gets through the hook. The gitleaks scan in `brain-sync` is the backstop.
- Neither hook can see shell tricks. Anything that can run a shell can escalate or write a file without the word "sudo" or ".env" ever showing up. The hooks stop the honest mistake. The real control is not granting blanket shell permissions in `settings.json`.
- `sudo-block.sh` also blocks harmless commands that mention the word, like `pacman -Qi sudo`. I took the false positive over the bypass.
- The approval window only shows the job script, not the files a job copies in. That's why install jobs carry fingerprints.
- The approval window is a check against mistakes and casual tricks, not a wall against a fully hijacked AI. Anything that can run shell commands can also open a fake window that only looks like this one. The walls that hold are sudo's password and not giving the AI blanket permissions.
- The window can't stop fake keyboard input. A hijacked AI that can run a tool like `wtype` or `ydotool` on the same desktop could press Yes. If that worries you, put those tools on the AI's deny list too.
- `confirm-open`'s Hyprland branch uses the Lua config (`hyprctl eval`). Older Hyprland versions use a different dispatch syntax.

## What's not here

My actual memories, my writing-voice profile, and the skills tied to my own projects stay private. So do the desktop-only pieces: a vector search over the brain and a scoring system that ranks memories and lets old ones fade.

## License

MIT
