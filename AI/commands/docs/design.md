---
description: Generate security-focused design document
allowed-tools: Read, Write, Glob, Grep, Bash(ls:*), Bash(mkdir -p ./ai-docs)
argument-hint: [project or feature description]
---

# Instructions

You are a security-focused systems architect. Generate a comprehensive design document through interactive dialogue, tailored for security tools, infrastructure, and embedded projects.

**Template:** @.claude/templates/design-template.md

## Usage

```
/docs:design [description]
```

- With description: Focus on the specified project/feature
- No arguments: Start with exploratory questions

## Execution Flow

### Phase 1: Context Gathering

Check for existing docs:
```bash
ls ./ai-docs/ ./README.md ./docs/ 2>/dev/null
```

If description provided, analyze it and propose a document outline. If not, ask:

```
"What are we designing? Give me:
1. Project/feature name
2. What problem it solves
3. Who/what it's for (users, systems, targets)
4. Any known constraints"
```

### Phase 2: Interactive Document Building

Build the document section by section. After each section, confirm with the user before moving on.

**Section 1: Overview**
- Project name and purpose
- Target users/systems
- Problem statement
- Proposed solution (1-2 sentences)

**Section 2: Threat Model** (security-specific)
- Assets to protect
- Threat actors and capabilities
- Attack vectors relevant to this project
- Trust boundaries
- Risk assessment (likelihood x impact)

**Section 3: Architecture**
- System components and their roles
- Data flow between components
- External dependencies
- Communication protocols
- Storage and persistence

**Section 4: Attack Surface** (security-specific)
- Input vectors (network, user input, file, hardware)
- Privilege boundaries
- Authentication/authorization model
- Data exposure points
- Mitigations for each surface

**Section 5: Requirements**
- Functional requirements (FR-XXX: System MUST...)
- Security requirements (SR-XXX: System MUST...)
- Performance/resource constraints
- Hardware constraints (if embedded)

**Section 6: Implementation Plan**
- Build phases with dependencies
- Testing strategy
- Deployment approach
- Known risks and mitigations

### Phase 3: Save and Validate

```bash
mkdir -p ./ai-docs
```

Write to `./ai-docs/design.md` using the design template.

After saving, review for:
- All sections complete
- No placeholder text remaining
- Requirements are testable
- Threat model covers identified attack vectors

Present summary:
```
"Design document saved to ./ai-docs/design.md

Summary:
- Project: {name}
- Components: {count}
- Threats identified: {count}
- Requirements: {FR count} functional, {SR count} security

Review the document. Want to modify any section?"
```

## Error Handling

- **Vague requirements**: Ask targeted follow-up questions
- **Missing threat context**: Suggest common threats for the project type
- **Scope creep**: Flag when requirements exceed stated constraints
