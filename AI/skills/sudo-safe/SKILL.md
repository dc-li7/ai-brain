---
name: sudo-safe
description: Use this skill whenever a task requires elevated privileges on Linux — anything involving sudo, root, systemctl start/stop/restart/enable/disable, package installs (pacman/paru/apt/dnf), service file edits, /etc/ modifications, mounting, disk partitioning, network config, firewall rules (ufw/iptables/nftables), chown/chmod on system paths, kernel module loading, or VM/container daemon control. Trigger even if the user doesn't say the word "sudo" — infer from the action. This skill is MANDATORY.
---

# sudo-safe

Environment rule: **Claude never runs `sudo` commands.** The user runs them manually. Your job is to prepare commands cleanly so they can be copied, pasted, and executed without edits.

## Why this matters

This rule isn't about safety paranoia — it's workflow hygiene. When Claude runs sudo, prompts can hang, passwords may be required in unexpected places, and side effects land in a context Claude can't fully observe. Manual execution keeps the root-blast-radius human-supervised and keeps Claude's execution loop deterministic.

## How to respond

When you detect a task that needs elevated privileges:

1. **Do not attempt to run the command.** No `Bash` calls with `sudo`. No workarounds like `echo password | sudo -S`. No writing a script that internally calls sudo and then running the script.

2. **Emit a single fenced bash block** containing only the commands the user should run. Keep it copy-paste clean:

   ```bash
   sudo pacman -Syu
   sudo systemctl restart nginx
   ```

3. **Above the block, one line per command explaining *why*.** Not what — why. The user can read the command; they want context on the intent.

4. **Below the block, state what you'll do once they confirm it ran.** For example: "Once that completes, tell me and I'll verify the service came up."

## Template

```
You'll need to run these yourself — I don't run sudo in your env.

**Why:**
- `pacman -Syu` — sync repos + upgrade; needed before installing the new package so we don't pull mismatched deps.
- `systemctl restart nginx` — pick up the new config we just edited.

```bash
sudo pacman -Syu
sudo systemctl restart nginx
```

Let me know when it's done and I'll check status.
```

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

If uncertain whether a command needs sudo, default to treating it as elevated and emit the copy-paste block.

## Edge cases

- **Already-elevated shell**: Don't assume any shell you spawn is privileged.
- **Passwordless sudoers entries**: Irrelevant — still don't run sudo. The rule is about workflow separation, not auth capability.
- **Read-only elevated commands** (e.g., `sudo journalctl -u foo`, `sudo ss -tlnp`): Still hand these to the user. Consistency over per-command carve-outs.
- **Multi-step operations where later steps depend on earlier sudo output**: Emit the sudo block, pause, and ask the user to paste the output back. Don't try to guess what it said.
- **Service edits needing `systemctl daemon-reload`**: Include the reload + restart in the same block so the user runs them together.

## What good looks like

**Bad:**
```
I'll install nginx for you.
```
*(then runs `sudo pacman -S nginx`)*

**Good:**
```
I can't run sudo in your env — paste this when you're ready:

**Why:** installing nginx so we can serve the static build we just produced.

```bash
sudo pacman -S nginx
```

Once installed, let me know and I'll configure the site.
```
