---
description: System and infrastructure management
allowed-tools: Bash(df:*), Bash(du:*), Bash(free:*), Bash(sensors:*), Bash(nvidia-smi:*), Bash(pacman -Q:*), Bash(pacman -Ss:*), Bash(systemctl status:*), Bash(systemctl list-units:*), Bash(systemctl --failed), Bash(journalctl:*), Bash(virsh list:*), Bash(virsh dominfo:*)
argument-hint: [action]
---

# Instructions

System administration helper for Arch-based Linux. Manages disk, packages, services, VMs, and hardware status.

## Usage

```
/sys [action]
```

## Task

Based on [action], perform the appropriate system operation:

### Disk Usage

**Overview:**
```bash
df -h --output=source,size,used,avail,pcent,target | grep -v tmpfs
```

**Largest files/dirs (current directory):**
```bash
du -sh ./* 2>/dev/null | sort -rh | head -20
```

**Storage health (smartctl needs root: hand it over with confirm-open):**
```bash
smartctl -a /dev/nvme0n1 2>/dev/null | grep -E "Critical|Temperature|Available Spare|Percentage Used"
smartctl -a /dev/sda 2>/dev/null | grep -E "Reallocated|Current_Pending|Temperature|Power_On"
```

### Package Management

**Search:**
```bash
pacman -Ss [query]
```

**Install (needs root: hand it over with confirm-open):**
```bash
pacman -S [package]
```

**AUR install (needs root: hand it over with confirm-open):**
```bash
paru -S [package]
```

**Update system (needs root: hand it over with confirm-open):**
```bash
pacman -Syu
```

**List explicitly installed:**
```bash
pacman -Qe | head -30
```

**Check for orphans:**
```bash
pacman -Qdt
```

### Service Management

**Status:**
```bash
systemctl status [service]
```

**List running services:**
```bash
systemctl list-units --type=service --state=running
```

**Start/stop/restart (needs root: hand it over with confirm-open):**
```bash
systemctl restart [service]
```

**Check failed:**
```bash
systemctl --failed
```

**Journal logs:**
```bash
journalctl -u [service] --no-pager -n 50
```

### VM Management

**List VMs:**
```bash
virsh list --all
```

**VM info:**
```bash
virsh dominfo [vm-name]
```

**Start/stop VM (confirm first):**
```bash
virsh start [vm-name]
virsh shutdown [vm-name]
```

### Hardware Status

**GPU:**
```bash
nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total --format=csv,noheader
```

**System overview:**
```bash
fastfetch
```

**CPU temps:**
```bash
sensors 2>/dev/null | grep -E "Core|Tctl|Package"
```

**Memory:**
```bash
free -h
```

## No Prompt / Help Mode

If run with no arguments, show system overview:
```bash
echo "=== Disk ===" && df -h / --output=source,size,used,avail,pcent 2>/dev/null && echo "=== Memory ===" && free -h && echo "=== GPU ===" && nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,memory.used --format=csv,noheader 2>/dev/null && echo "=== Failed Services ===" && systemctl --failed --no-pager
```

## Safety Guards

- **Confirm before**: package installs/updates, service start/stop, VM operations
- **Never**: `rm -rf /`, `pacman -Rns` on critical packages, force-kill system services
- **Warn**: if disk usage exceeds 90% on any mount
