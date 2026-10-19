---
name: sudo-safe
description: Use this skill whenever a task requires elevated privileges on Linux — anything involving sudo, root, systemctl start/stop/restart/enable/disable, package installs (pacman/paru/apt/dnf), service file edits, /etc/ modifications, mounting, disk partitioning, network config, firewall rules (ufw/iptables/nftables), chown/chmod on system paths, kernel module loading, or VM/container daemon control. Trigger even if the user doesn't say the word "sudo" — infer from the action. This skill is MANDATORY.
---

# sudo-safe

Environment rule: **Claude never runs `sudo` commands itself.** The user approves and runs them. Your job is to hand them over in a way the user can read, approve with one click, and that Claude can check afterwards.

## Why this matters

When Claude runs sudo, prompts can hang, passwords end up in odd places, and side effects land in a context Claude can't fully observe. Keeping root actions behind a human decision keeps the blast radius human-supervised. The approval window (`confirm-open`) keeps that decision with the user without making them copy and paste.

## How to respond

When you detect a task that needs elevated privileges, or anything else you're blocked from (a deny-listed command, a guarded file):

1. **Don't run it yourself.** No `Bash` calls with `sudo`, no `echo password | sudo -S`, no other workaround.
2. **Write a job script** with the Write tool (not with Bash: the sudo-block hook stops any Bash line containing the word). Put it somewhere with a plain path, such as your scratchpad.
   - Top comments: why, in plain words, one line per step. That's what the user reads first.
   - `set -euo pipefail`, then the commands.
   - **Plain ASCII only, lines under 300 characters.** confirm-run refuses anything else, because control characters, non-ASCII and very long lines can hide text on screen.
   - **If the job installs or copies files,** check their sha256 fingerprints first (`sha256sum --check` with the sums written into the job). The window shows the job, not the files it copies, so the fingerprints are what make sure the files installed are the ones you tested.
3. **Run `confirm-open <job-script>`.** A window shows the job; nothing runs unless the user picks Yes, and sudo asks for the password right there.
4. **Tell the user** what the window does in one or two lines, then wait for them to say they're done. Don't poll.
5. **Read `<job-script>.result`:** the output plus `exit=N`, or `cancelled`, and the job's `job_sha256`. Then check that the change actually landed.

If `confirm-open` isn't installed on this machine, fall back to a single fenced bash block the user can copy, with the same one-line-per-step why above it.

## Template

```bash
#!/usr/bin/env bash
# Install nginx so we can serve the static build we just produced,
# then start it now and on every boot.
set -euo pipefail
sudo pacman -S --needed nginx
sudo systemctl enable --now nginx
systemctl is-active nginx
```

Then: "A window is open to install and start nginx. Pick Yes, type your password, and tell me when it's done. I'll check the site comes up."

## Detection heuristics

Trigger this skill when you notice any of:

- Explicit `sudo` in a command you're about to run
- `systemctl {start,stop,restart,enable,disable,mask}` on a system unit (user units via `--user` are fine)
- Package managers at install/update/remove level: `pacman -S/-Syu/-R`, `paru -S`, `apt {install,update,upgrade,remove}`, `dnf`, `pip install` targeting system python (not a venv)
- Writes under `/etc/`, `/usr/`, `/boot/`, `/opt/` (unless user-owned), `/var/lib/`
- `mount`, `umount`, `fdisk`, `parted`, `mkfs.*`, `cryptsetup`, `lvcreate`
- Network: `ip link/addr/route` changes, `nmcli con up/mod`, `iw`, `wpa_supplicant` config
- Firewall: `ufw`, `iptables`, `nftables`, `firewall-cmd`
- `chown`/`chmod`/`setcap` targeting paths you don't own
- `modprobe`, `insmod`, `rmmod`
- `virsh {start,destroy,define,undefine}`, `docker` daemon ops (socket perms), `podman system` global ops

If uncertain whether a command needs sudo, default to treating it as elevated and hand it over the same way.

## Edge cases

- **Already-elevated shell**: Don't assume any shell you spawn is privileged.
- **Passwordless sudoers entries**: Irrelevant — still don't run sudo. The rule is about workflow separation, not auth capability.
- **Read-only elevated commands** (e.g., `sudo journalctl -u foo`, `sudo ss -tlnp`): Still hand these to the user. Consistency over per-command carve-outs.
- **Multi-step operations where later steps depend on earlier sudo output**: put the first part in one job, read its `.result`, then write the next job. Don't guess what it said.
- **Service edits needing `systemctl daemon-reload`**: put the reload and restart in the same job so they run together.

## What good looks like

**Bad:** "I'll install nginx for you." *(then runs `sudo pacman -S nginx`)*

**Also bad:** a fenced block for the user to copy and paste, when `confirm-open` is installed.

**Good:** a job script with the why in its comments, `confirm-open` on it, one line telling the user what the window does, and a check of the `.result` afterwards.
