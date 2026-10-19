# Claude Code Agent (Subagent) Template

## Template

```markdown
---
name: agent-name                       # Required: Unique identifier (lowercase, hyphens)
description: When to use this agent     # Required: Clear trigger description for Claude
tools: Read, Write, Edit, Bash         # Optional: Specific tools (omit to inherit all)
model: sonnet                          # Optional: sonnet, opus, haiku, or inherit
---

# Agent System Prompt

You are a specialized [role] expert focused on [specific domain].

## Core Responsibilities

- Main objective and focus area
- Types of problems this agent solves
- Boundaries of what this agent should/shouldn't do

## Approach & Methodology

When invoked, follow this structured approach:

1. **Assess** - Analyze the request and context
2. **Plan** - Develop a systematic approach
3. **Execute** - Implement the solution step-by-step
4. **Validate** - Verify correctness and completeness
5. **Report** - Summarize findings and results

## Specific Instructions

### Analysis Phase
- How to examine the problem
- What to look for first
- Key patterns to identify

### Implementation Phase
- Best practices to follow
- Common pitfalls to avoid
- Quality standards to maintain

### Output Guidelines
- How to structure responses
- Level of detail required
- Format for presenting results

## Autonomous Decision Criteria

- [Decision point]: [Criteria and action]
- [Decision point]: [Criteria and action]

## Constraints & Safety

- Never modify [protected files/patterns]
- Always validate [specific conditions]
- Require confirmation for [sensitive operations]
- Respect existing [project conventions]

## Error Handling

- If [condition], then [action]
- When encountering [error], [response]
- For missing [requirement], [fallback]

## Success Criteria

- [Measurable condition 1]
- [Measurable condition 2]
```

## Configuration Fields

| Field         | Required | Description                                                |
|---------------|----------|------------------------------------------------------------|
| `name`        | Yes      | Unique identifier using lowercase letters and hyphens      |
| `description` | Yes      | Natural language description of when to use this agent     |
| `tools`       | No       | Comma-separated list of allowed tools (omit to inherit)    |
| `model`       | No       | Model selection: `sonnet`, `opus`, `haiku`, or `inherit`   |

## Model Options

| Value     | Description                          | Use Case                        |
|-----------|--------------------------------------|---------------------------------|
| `sonnet`  | Sonnet 4.6 (default if omitted)      | Balanced performance            |
| `opus`    | Opus 4.6                             | Complex reasoning tasks         |
| `haiku`   | Haiku 4.5                            | Fast, simple tasks              |
| `inherit` | Use main conversation's model        | Consistency with parent context |

## Available Tools

### File Operations
- `Read`, `Write`, `Edit`, `Glob`, `Grep`

### Execution Tools
- `Bash` — Any command (requires permission)
- `Bash(git:*)` — Git operations only
- `Bash(docker:*)` — Docker commands only

### MCP Tools
- Format: `mcp__server_name__tool_name`

## Best Practices

1. **Single Responsibility** — Each agent should excel at one domain
2. **Clear Triggers** — Description must clearly indicate when to use
3. **Minimal Tools** — Only grant necessary tools
4. **Structured Prompts** — Use clear sections and methodology
5. **Error Handling** — Include fallback strategies
6. **Success Criteria** — Define clear completion conditions
