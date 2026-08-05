---
description: Runs the TEST phase — turns approved acceptance criteria into a test matrix and actual failing tests committed to the repo. Use after the PLAN gate is approved, before any implementation.
disable-model-invocation: true
allowed-tools: Bash(git status *) Bash(git diff *) Bash(cat .claude/state/gate.json)
---

Gate: !`cat .claude/state/gate.json 2>/dev/null || echo '{"phase":"idle"}'`

## Owner

`test-designer`, with `a11y-perf-budgeter` on any UI work.

## Why this phase comes before CREATE

A written test matrix is a promise. A red test run is a contract. Only the
second one is falsifiable, which is why this phase does not close on the
matrix — it closes on the failing run.

## Required output

- `docs/specs/<slug>/acceptance.md` — the test matrix, EARS form, mapping each
  numbered acceptance criterion to the test that proves it and the level it is
  tested at
- **The test files themselves, committed to the repo**
- `docs/specs/<slug>/evidence/tests-red.txt` — the captured failing run
- `docs/specs/<slug>/budget.md` — when `a11y-perf-budgeter` ran

## Level discipline

Unit for logic and branches. Integration for boundaries — database, HTTP,
queue. End-to-end only for the critical user path. Do not write an E2E test for
something a unit test can prove; you will pay for it on every run forever.

## Gate

This phase closes when:

1. Every numbered acceptance criterion maps to at least one test.
2. `evidence/tests-red.txt` shows the new tests failing.
3. Each new test fails **for the right reason** — because the feature is
   missing, not because of a typo, a missing import, or a bad fixture. The
   agent must state this explicitly per test. A test that fails for the wrong
   reason will pass for the wrong reason too.
4. **You approve it.**

Then update `.claude/state/gate.json`: set `phase` to `create` and append `test`
to `approved`.

The gate hook opens source files for writing at this point. That is the whole
purpose of this phase.
