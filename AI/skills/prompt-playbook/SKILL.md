---
name: prompt-playbook
description: >
  Use this skill whenever the user is about to ask Claude for something non-trivial —
  writing new code, debugging, doing a security audit, changing an ML model, or
  designing any change that needs to land in one shot. Trigger when the user says
  "use the playbook," "use SPEC-first / BUG-REPRO / DIFF-REVIEW / MODEL-CHANGE /
  PLAN-THEN-EXECUTE / RED-TEAM," or when the request is ambiguous enough that the
  right move is to wrap it in one of the six structured patterns before responding.
  Also trigger proactively at the start of any ML model change (use MODEL-CHANGE),
  any debugging session (use BUG-REPRO), or any pre-ship review (use DIFF-REVIEW).
---

# Prompt Playbook — Six Structured Patterns

This skill is your prompt engineering reference. It contains six battle-tested
patterns that match real workflows: writing code, debugging, security auditing,
ML changes, planning, and red-teaming. Use them as templates that you fill in
before any non-trivial work begins.

The point of every pattern: turn a vague ask into a one-shot brief so Claude
doesn't have to re-ask for context.

Reference these patterns by name in conversation: *"Use SPEC-first for this,"*
*"Run a DIFF-REVIEW on the last commit,"* *"This is a MODEL-CHANGE — fill in the
template before touching code."*

---

## When to use which pattern

| Pattern | Trigger |
|---|---|
| **SPEC-first** | Writing brand new code (project modules, new features, scripts) |
| **BUG-REPRO** | Debugging — anything that's broken or behaving unexpectedly |
| **DIFF-REVIEW** | Security audit of a finished diff or commit |
| **MODEL-CHANGE** | *Mandatory* for any change to ML model code, features, or training pipeline |
| **PLAN-THEN-EXECUTE** | Multi-step changes where research and planning need to happen before code |
| **RED-TEAM SELF-CRITIQUE** | Appended to *every* design output as a final sanity check |

---

## Pattern 1 — SPEC-first (writing new code)

```xml
<context>
[project + relevant files; existing patterns to match; constraints from CLAUDE.md]
</context>

<task>
[one sentence: what new thing should exist when this is done]
</task>

<constraints>
- [security boundary — no sudo, no exfil, no hardcoded creds]
- [interface contract — what callers will pass in / get out]
- [non-goals — what this change should NOT touch]
</constraints>

<success_criteria>
- pytest (or equivalent) is green
- secrets-guard scan is clean
- [project-specific check, e.g. "your project's preflight/CI check passes"]
- [behavioral check — what the code should actually do when run]
</success_criteria>
```

**When to use:** any new file, function, or feature in your project — modules,
scripts, or standalone tools under `~/projects/<your-project>/`.

---

## Pattern 2 — BUG-REPRO (debugging)

```xml
<observed>
[exact log lines, serial output, stack trace, screenshot description — copy-paste,
don't summarize]
</observed>

<expected>
[what should have happened instead]
</expected>

<env>
- [project + git commit hash if known]
- [Python / idf.py / kernel version, ESP32 variant, OS — only what's relevant]
- [recent changes — what was edited just before the break]
</env>

<hypotheses>
1. [most likely cause — and what would prove or disprove it]
2. [second most likely]
3. [least likely but worth ruling out]
</hypotheses>
```

**Hard rule:** Claude must produce the three ranked hypotheses **before** touching
any code. No edits, no "let me try X." Diagnose first, fix second.

**When to use:** anything broken — Python tracebacks, firmware crashes, container
restart loops, unexpected service behavior.

---

## Pattern 3 — DIFF-REVIEW (security audit)

```xml
<diff>
[paste unified diff — git diff output, not a summary]
</diff>

<scope>
[what subsystem this touches: auth / network / subprocess / model / config / data]
</scope>

<ask>
List the three highest-risk issues in this diff, ordered by blast radius (worst
first). For each:
- The risk in one sentence
- The line(s) where it lives
- One concrete test that would catch a regression of this issue
</ask>
```

**When to use:** every diff before commit. Run automatically through the
`security-audit-team` if available, or manually via `pre-ship-review` skill.

The "three highest-risk" framing is intentional — it forces ranking. "Review this
diff" gets you a wall of nitpicks. "Top three risks ordered by blast radius" gets
you the things that actually matter.

---

## Pattern 4 — MODEL-CHANGE (ML work — *most important pattern for any ML project*)

This is the most critical pattern for ML work. **No ML model code change should
ship without all five fields filled in.** Not most of them — all five.

```xml
<baseline>
[paste the most recent evaluation results — OOS profit factor / accuracy / F1,
loss curves, max drawdown, or whatever metrics matter for this model. Be specific
about the metrics this change is trying to move.]
</baseline>

<change>
[what's being modified — feature added, hyperparameter tuned, label changed,
filter added, etc.]

[hypothesis: WHY this should help. One specific causal claim, not "might improve
performance." Example: "Adding 14-period RSI as a feature should help the model
distinguish exhaustion from continuation in trending regimes."]
</change>

<validation_plan>
[how you'll know it actually helped — be specific:
 - which backtest window
 - which metric(s)
 - what magnitude of improvement counts as "real" (e.g. PF +0.1, p < 0.05)
 - statistical significance test if applicable]
</validation_plan>

<lookahead_check>
[explicit red-team for data leakage, lookahead bias, survivorship bias:
 - Does any feature use future information at training time?
 - Is the train/test split temporal, not random?
 - Are filtered-out symbols representative of what would have been tradeable
   at the time?
 - Does the label use any information that wouldn't be available at signal time?]
</lookahead_check>

<rollback_criterion>
[the metric threshold under which the change is reverted automatically:
 "If OOS profit factor drops below 1.2 for 2 consecutive walk-forward windows,
 revert this change and log to experiments/log.md"]
</rollback_criterion>
```

**Hard rule:** refuse to start training until all five fields are filled in.
If you have an `ml-team` wired up, the `model-trainer` agent enforces this; the
`backtest-analyst` enforces the rollback criterion at the end.

**Why this pattern exists:** ML changes that don't beat baseline are normal. ML
changes that *look* like they beat baseline because of leakage are catastrophic
in production. This pattern catches both.

---

## Pattern 5 — PLAN-THEN-EXECUTE (multi-step work)

Three explicit phases, in order. Do not skip ahead.

```xml
<phase_1_research>
- Read the relevant files and prior decisions
- Identify existing utilities/functions that should be reused
- List the open questions
- Output: a research note. NO code yet.
</phase_1_research>

<phase_2_plan>
- Based on Phase 1, write a short implementation plan
- List files to be modified
- Note any breaking changes or cross-project impact
- Output: a plan doc. NO code yet.
</phase_2_plan>

<phase_3_execute>
- Only after Phase 2 is reviewed
- Implement against the plan
- Run tests
- Output: working code + test results
</phase_3_execute>
```

**When to use:** any change that touches more than ~3 files, crosses subsystem
boundaries, or has ambiguous requirements. Early research, phase-by-phase
execution.

---

## Pattern 6 — RED-TEAM SELF-CRITIQUE (append to every design)

This is not a standalone pattern — it's a section that gets appended to the
output of any of the patterns above whenever Claude proposes a design.

```xml
<self_critique>
Three attacks on my own proposal, ordered by how plausible they are:

1. [strongest attack — the thing most likely to make this proposal wrong]
2. [second strongest]
3. [the long-shot but still worth raising]

For each attack, one sentence on the mitigation or "no mitigation, accept the
risk because [reason]."
</self_critique>
```

**Why this pattern exists:** Claude (and any AI) is biased toward confidence in
its own outputs. Forcing a self-critique catches overconfident designs *before*
they become commits. The "three attacks" framing forces the model to actually
think adversarially instead of producing performative caveats.

**When to use:** at the end of any non-trivial design, plan, or implementation
proposal. If you have agent teams (e.g. `security-audit-team`, `ml-team`) they
run their own variants, but this should be the default for any solo session too.

---

## How to invoke from a normal prompt

You don't have to write the XML by hand. You can say things like:

- *"Use SPEC-first to write a new data-validation module for my Python project"*
- *"BUG-REPRO this — the service hasn't responded in 4 hours, log says X"*
- *"DIFF-REVIEW the last commit"*
- *"MODEL-CHANGE: I want to try adding a new feature to the training pipeline"*
- *"PLAN-THEN-EXECUTE the migration of the dashboard to a new port"*

Claude should fill in the template with what it knows from context (project files,
recent conversation) and ask only for the fields it can't infer.

---

## Quick Reference: The 5 Cardinal Rules of Prompting Claude

1. **Diagnose before patching.** No fix until you have ranked hypotheses.
2. **Rank, don't list.** "Top 3" beats "comprehensive review" every time.
3. **For ML, all five MODEL-CHANGE fields are mandatory.** Lookahead bias kills production models.
4. **Plan before code on multi-step work.** Research → plan → implement, in that order.
5. **Always self-critique.** Three attacks on your own proposal, before shipping.
