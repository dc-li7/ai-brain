---
description: Workflow optimization analyzer
allowed-tools: Read, Glob, Grep, Bash(ls:*)
argument-hint: [prompt]
---

# Instructions

Analyzes workflow patterns to identify automation opportunities through new commands, agents, and optimizations.

## Usage

```
/self-improve [prompt]
```

- With prompt: Focus analysis on specific task workflows
- No prompt: Comprehensive workflow analysis

## Execution

### 1. Pattern Analysis

Examine current workflow:
- Check existing commands: `ls .claude/commands/**/*.md 2>/dev/null`
- Check existing agents: `ls .claude/agents/ 2>/dev/null`
- Review recent git history for repetitive patterns: `git log --oneline -20 2>/dev/null`

Identify:
- Repetitive tasks and commands
- Multi-step workflows that could be automated
- Time-consuming manual operations
- Missing tooling gaps

### 2. Categorize by Priority

**High Priority:**
- Daily repetitive tasks
- Workflows >10 min that could be automated
- Simple implementation, high value

**Medium Priority:**
- Weekly tasks
- Workflow improvements
- Moderate complexity

**Low Priority:**
- Occasional workflows
- Advanced features
- Complex implementation

### 3. Output Report

```
Workflow Analysis Summary
- Patterns identified: [X]
- Recommended implementations: [Z]

HIGH PRIORITY:
1. Create command /[name] — [what it does]
   Automates: [current manual process]
   Frequency: [X times/day]

2. Create agent [name] — [what it handles]
   Replaces: [current manual steps]

MEDIUM PRIORITY:
[...]

LOW PRIORITY:
[...]

Implementation Roadmap:
Week 1: [highest impact items]
Week 2-3: [second priority items]
```

## Next Steps

After presenting analysis, offer:
1. Create a specific command or agent from the recommendations
2. Deep-dive into a specific workflow area
3. Export the analysis to a file
