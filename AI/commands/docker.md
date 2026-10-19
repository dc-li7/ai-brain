---
description: Docker/Compose container management
allowed-tools: Bash(docker:*), Bash(docker compose:*)
argument-hint: [action]
---

# Instructions

Manage Docker containers and Compose services. Set `$COMPOSE_FILE` to your project's compose file path, or pass `-f <compose-file>` explicitly.

## Usage

```
/docker [action]
```

Natural language actions: status, logs, restart, debug, disk, shell, pull, up, down

## Task

Based on [action], perform the appropriate Docker operation. When a compose file is needed, use `$COMPOSE_FILE` if set, otherwise ask the user for the path.

### Status / Overview
- `docker compose -f <compose-file> ps` — Show all Compose services
- `docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"` — Show all running containers
- `docker stats --no-stream` — Resource usage snapshot

### Logs
- `docker compose -f <compose-file> logs --tail 50 [service]` — Recent logs
- `docker compose -f <compose-file> logs -f [service]` — Follow logs (warn user this is blocking)

### Restart / Start / Stop
- `docker compose -f <compose-file> restart [service]`
- `docker compose -f <compose-file> up -d [service]`
- `docker compose -f <compose-file> down` — **Confirm before running** (stops everything)

### Debug
- `docker inspect [container]` — Container config
- `docker compose -f <compose-file> exec [service] sh` — Shell into container
- `docker logs --tail 100 [container]` — Recent container logs
- Check for crash loops: `docker ps -a --filter "status=restarting"`

### Disk Usage
- `docker system df` — Overall Docker disk usage
- `docker volume ls` — List volumes

### Cleanup (confirm before any of these)
- `docker system prune` — Remove unused data
- `docker image prune` — Remove dangling images

## No Prompt / Help Mode

If run with no arguments, show container status:
```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

## Safety Guards

- **Confirm before**: `down`, `prune`, `rm`, `rmi`, any destructive operation
- **Never**: `docker system prune -a --volumes` without explicit user request
- **Always**: Show what will be affected before destructive ops

## Examples

```
/docker status              → Show all container status
/docker logs myservice      → Tail logs for a service
/docker restart myservice   → Restart a service
/docker debug myservice     → Inspect container, check logs
/docker disk                → Show Docker storage usage
/docker shell myservice     → Open shell in a container
```
