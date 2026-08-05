---
description: Runs a structured two-proposal debate with a rubric-scored judgement. Use for irreversible or high-blast-radius decisions, or when two agents disagree.
disable-model-invocation: true
argument-hint: [decision to resolve]
---

Resolve: $ARGUMENTS

Debate is valuable and expensive. Tie its intensity to blast radius rather than
running it on everything.

## When each level applies

**Level 1 — single critic (default, cheap).** The producing agent writes the
plan, `red-team-critic` attacks it, the producer revises. Two extra agent runs.
Use for everything not on the escalation list. This is the pipeline's normal
mode; you do not need this skill for it.

**Level 2 — proposal and judge (moderate).** What this skill runs. Roughly four
extra agent runs. Mandatory for: authentication and authorisation, payments and
billing, any destructive migration, public API contracts, PII handling, rate
limiting and abuse controls, and any change whose rollback is not a single
revert.

**Level 3 — adversarial team or workflow (expensive).** For genuinely uncertain
root-cause work where several investigators must pursue competing hypotheses and
actively try to disprove each other. See the bottom of this file.

---

## Step 1 — Independent proposals

Dispatch two general-purpose subagents **in parallel**. Give each the identical
brief. **Do not tell either that another proposal exists** — knowing produces
hedging, and hedged proposals cannot be scored against each other.

Require each to return:

- The approach
- Why it wins
- What it costs
- What it forecloses — the doors this shuts that are expensive to reopen
- The strongest argument against itself

## Step 2 — Judgement

Dispatch a third subagent on **opus** with both proposals and this rubric.
Score each 1–5 per criterion, then total.

| Criterion | Weight |
|---|---|
| Correctness under the stated failure modes | 3 |
| Reversibility / cost to change later | 3 |
| Fit with existing patterns in this codebase | 2 |
| Implementation and review cost | 2 |
| Operational burden (monitoring, oncall, migration) | 2 |
| Security and privacy posture | 3 |

The rubric matters more than the debate. Without it the judge picks the more
confidently-written answer.

The judge must:

- Name the losing proposal's best idea and say whether to graft it on.
- Break ties toward the **more reversible** option. A genuine tie is not a valid
  outcome; "both are fine" means the rubric was not applied.

## Step 3 — Record

Write `docs/adr/NNNN-<slug>.md` containing the decision, both alternatives, the
scores, and the consequences. Then update the plan.

The ADR is the deliverable. A debate that produces a chat conclusion and no file
has cost four agent runs and bought nothing — the next session will re-litigate
it.

---

## Level 3, if you genuinely need it

Two mechanisms, and the second is usually better:

**Dynamic workflows** — the orchestration becomes a script you can rerun, and
intermediate results live in script variables rather than in a context window.
Prefer this for anything you will do more than once.

**Agent teams** — teammates share a task list and message each other directly.
Requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`. Expect roughly **7× the
tokens of a single session**. Keep to 3–5 teammates; three focused ones beat
five scattered ones. Turn the flag back off afterwards.

Reserve level 3 for production incidents and hard bugs — not for design
questions a rubric can settle.
