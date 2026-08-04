---
description: Runs a change through the Idea, Plan, Test, Create, Verify, Document pipeline one gate at a time. Use to start any feature, bug fix, or non-trivial change.
disable-model-invocation: true
argument-hint: [description of the change]
allowed-tools: Bash(git status *) Bash(git diff *) Bash(git log *) Bash(cat .claude/state/gate.json)
---

Feature: $ARGUMENTS

Gate: !`cat .claude/state/gate.json 2>/dev/null || echo '{"phase":"idle"}'`
Tree: !`git status --short 2>/dev/null | head -20`

## Protocol

Run **exactly one phase per turn**, then stop and report which gate needs my
approval. Never skip forward. Never combine phases.

| Phase | Agent | Artifact required before the gate closes |
|---|---|---|
| 1 · plan | `planner` | `docs/specs/<slug>/plan.md` |
| 2 · critique | `critic` | `critique.md`, every BLOCKER and MAJOR resolved or explicitly accepted |
| 3 · test | `test-designer` | `evidence/tests-red.txt` showing the new tests failing correctly |
| 4 · create | `implementer` | `evidence/tests-green.txt` |
| 5 · verify | `reviewer`, then `qa-runner` if there is a UI | `verification.md`, zero BLOCKERs |
| 6 · document | `doc-writer` | updated docs plus `docs/handoff/<date>-<slug>.md` |

After each phase, update `.claude/state/gate.json` with the new phase, the
slug, and the approved list.

## Delegation briefing template

Subagents start with an empty context and cannot see this conversation.
Every delegation must include:

    TASK: <one imperative sentence>
    SPEC: docs/specs/<slug>/plan.md — read this first
    SCOPE: you may modify only <explicit paths>
    CONTEXT YOU NEED: <3-6 bullets, including file paths already discovered>
    DONE MEANS: <the artifact path that must exist>
    DO NOT: <2-3 things that would make this a rejected result>

The CONTEXT line matters most. Every file path handed over is a search the
subagent does not have to run.

## Gate discipline

- A summary in chat is not an artifact. Verify the file exists and is
  non-empty before advancing.
- Run `critic` **once** per feature. Re-running it signals a rushed plan.
- Findings that become work re-enter at phase 3, not phase 4. A bug fix gets
  a failing test first.
- If an agent reports completion without its artifact, reject and re-dispatch
  naming the missing file.
- After phase 2 and after phase 4, tell me to run `/clear` before continuing.
