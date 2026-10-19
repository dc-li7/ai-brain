---
description: Agent generator
allowed-tools: Read, Write, Bash(ls)
argument-hint: [initial-description]
---

# Instructions

Interactive agent generator that analyzes requirements and creates autonomous agents with decision trees, error recovery, and intelligent tool selection.

**Template:** @.claude/templates/agent-template.md

## Usage

```
/generate:agent [initial-description]
```

- With description: Analyze and propose agent structure
- No arguments: Start with exploratory questions

## Execution

### Phase 1: Requirements Analysis

1. **Parse input** — Extract core purpose, implied behaviors, workflow complexity, decision points
2. **Check for duplicates:**
   ```bash
   ls .claude/agents/ 2>/dev/null
   ls .claude/commands/**/*.md 2>/dev/null
   ```
   If similar solution exists, present options: use existing, modify existing, or create new
3. **Classify complexity** — Simple (single-phase) / Moderate (2-3 phases) / Complex (4+ phases with branching)

If no description provided:
```
"What complex or repetitive task should this agent automate?
What decisions should the agent make autonomously?"
```

### Phase 2: Information Gathering

Collect through dialogue, proposing smart defaults at each step:

1. **Name and objective** — Suggest based on description, confirm with user
2. **Model selection** — Recommend based on complexity:
   - `sonnet` (default) — Balanced performance
   - `opus` — Complex reasoning and analysis
   - `haiku` — Fast, simple operations
3. **Tools needed** — Auto-detect from workflow, confirm with user
4. **Decision criteria** — When does the agent act autonomously vs ask?
5. **Workflow phases** — Present proposed phase structure for approval
6. **Constraints and safety** — What the agent must never do, what requires confirmation
7. **Success criteria** — How to know the agent completed successfully

### Phase 3: Generate Agent File

After user confirms the summary, write to `.claude/agents/[agent-name].md` using the agent template.

Include:
- YAML frontmatter (name, description, tools, model)
- Core responsibilities and boundaries
- Structured workflow with decision points
- Autonomous decision criteria
- Constraints and safety guards
- Error handling and recovery
- Success criteria

```
"Agent created at .claude/agents/[agent-name].md

Test it with: use [agent-name]
Or create another: /generate:agent"
```

## Safety Guards

- Validate name uniqueness before creation
- Prevent overwriting existing agents without confirmation
- Ensure decision trees have no infinite loops
- Confirm tool permissions match operations
