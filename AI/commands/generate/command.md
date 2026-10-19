---
description: Command generator
allowed-tools: Read, Write, Bash(ls)
argument-hint: [initial-description]
---

# Instructions

Interactive command generator that guides through creating new slash commands via structured dialogue.

**Template:** read `~/.claude/templates/command-template.md` first (link.sh links it from `AI/templates`).

## Usage

```
/generate:command [initial-description]
```

- With description: Analyze and propose command structure
- No arguments: Start with exploratory questions

## Execution

### Phase 1: Analysis

1. **Parse input** — Extract purpose, implied functionality, tool requirements
2. **Check existing commands:**
   ```bash
   ls .claude/commands/**/*.md 2>/dev/null
   ```
   Flag if similar command exists
3. **Determine if this should be a command or agent** — If multi-turn with complex decision trees, suggest agent instead

If no description provided:
```
"What task should this command automate?
How would you typically invoke it?"
```

### Phase 2: Information Gathering

Collect through dialogue with smart defaults:

1. **Name** — Suggest based on description (lowercase, hyphens)
2. **Description** — One-line summary for `/help`
3. **Tools needed** — Auto-detect, confirm with user
4. **Arguments** — Propose pattern (`$ARGUMENTS`, `$1`/`$2`, `[optional]`)
5. **Task steps** — Propose numbered step structure, confirm
6. **Safety guards** — Identify sensitive operations that need confirmation
7. **Examples** — Generate 2-3 usage examples

### Phase 3: Generate Command File

Write to `.claude/commands/[command-name].md` using the command template.

Ensure:
- Proper YAML frontmatter
- Single `## Task` section with clear numbered steps
- Examples section
- Error handling if applicable

```
"Command created at .claude/commands/[command-name].md

Use it with: /[command-name]
Or create another: /generate:command"
```

## Safety Guards

- Validate command name uniqueness
- Check tool permission compatibility
- Prevent overwriting without confirmation
- Ensure `## Task` section follows template structure
