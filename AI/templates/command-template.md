# Claude Code Command Template

## Template

```markdown
---
name: command-name                     # Optional: Uses filename if not specified
description: Brief one-line description # Optional: Uses first line if not specified
allowed-tools: Read, Write, Edit, Bash(git:*), Grep, Glob  # Optional: Inherits from conversation
argument-hint: [prompt]                 # Optional: Shows expected arguments in autocomplete
---

# Command Title

Brief description of what this command does.

## Usage
/command-name [arguments]

**Argument patterns:**
- `[optional]` - Optional arguments in brackets
- `$ARGUMENTS` - Captures all arguments as single string
- `$1`, `$2`, `$3` - Individual positional arguments

## Task

Clear instructions for what Claude should do:

1. **Analyze** - Examine the provided context
2. **Execute** - Perform specific actions
3. **Report** - Summarize results

## Examples

### Basic Usage
/command-name

### With Arguments
/command-name feature-branch

## Error Handling (Optional)

- **Missing files:** Check paths and permissions
- **Invalid arguments:** Verify format and requirements

## Safety Guards (Optional)

- Protected patterns: `*.env`, `secrets/*`
- Confirmation required for: destructive operations
```

## Argument Variables

| Variable        | Description                      |
|-----------------|----------------------------------|
| `$ARGUMENTS`    | All arguments as single string   |
| `$1`, `$2`      | Positional arguments             |
| `${1:-default}` | Argument with default value      |

## Special Syntax

| Syntax    | Description                          |
|-----------|--------------------------------------|
| `` !`cmd` `` | Execute bash command, include output |
| `@path`   | Include file or directory content    |
| `/command` | Invoke another slash command         |

## Best Practices

1. **Single Purpose** — One command, one job
2. **Clear Naming** — Name indicates function
3. **Minimal Tools** — Only necessary permissions
4. **Provide Examples** — Show usage patterns
