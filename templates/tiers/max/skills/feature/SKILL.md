---
description: Runs a change through the Idea, Plan, Test, Create, Verify, Document pipeline one gate at a time. Use to start any feature, bug fix, or non-trivial change.
disable-model-invocation: true
argument-hint: [description of the change]
allowed-tools: Bash(git status *) Bash(git diff *) Bash(git log *) Bash(cat .claude/state/gate.json)
---

Feature: $ARGUMENTS

Gate: !`cat .claude/state/gate.json 2>/dev/null || echo '{"phase":"idle"}'`
Tree: !`git status --short 2>/dev/null | head -20`

Hand this to the `conductor` agent. It owns phase order and the gate file; it
never writes application code.

## Protocol

Run **exactly one phase per turn**, then stop and report which gate needs my
approval. Never skip forward. Never combine phases.

| Phase | Owner | Artifact required before the gate closes |
|---|---|---|
| 1 · idea | `product-analyst` | `docs/specs/<slug>/idea.md` — problem, scope, EARS acceptance criteria, no open questions |
| 2 · plan | `system-architect`, then `red-team-critic` | `plan.md` with a module map + `critique.md` with every BLOCKER and MAJOR resolved or explicitly accepted |
| 3 · test | `test-designer` | `acceptance.md` + `evidence/tests-red.txt` showing the new tests failing **for the right reason** |
| 4 · create | `backend-engineer`, `frontend-engineer` — one owner per file set | `evidence/tests-green.txt`, diff touching only files the plan named |
| 5 · verify | `code-reviewer`, `security-auditor`, `qa-runner` — dispatched **in parallel**, all read-only | `verification.md`, zero BLOCKERs, browser evidence |
| 6 · document | `doc-writer` | updated `docs/` + `docs/handoff/<date>-<slug>.md` |

After each phase, update `.claude/state/gate.json` with the new phase, the slug,
the spec directory, and the approved list.

## Debate escalation

Run `/debate` before approving the plan when the change touches authentication
or authorisation, payments, a destructive migration, a public API contract, PII
handling, or rate limiting — or when two agents disagree. Do not average two
answers; run the rubric and let the judge decide.

## Delegation briefing template

Subagents start with an empty context and cannot see this conversation. Every
delegation must include:

    TASK: <one imperative sentence>
    SPEC: docs/specs/<slug>/plan.md — read this first
    SCOPE: you may modify only <explicit glob list>
    CONTRACT: <the interface or acceptance criterion being satisfied>
    CONTEXT YOU NEED: <3-6 bullets, including file paths already discovered>
    DONE MEANS: <the artifact path that must exist>
    DO NOT: <2-3 things that would make this a rejected result>

The CONTEXT line is the money line. Every file path handed over is a search the
subagent does not run.

## Gate discipline

- A summary in chat is not an artifact. Verify the file exists and is non-empty
  before advancing.
- Run `red-team-critic` **once** per feature. Re-running it signals a rushed plan.
- Findings that become work re-enter at phase 3, not phase 4. A bug fix gets a
  failing test first.
- If an agent reports completion without its artifact, reject and re-dispatch
  naming the missing file.
- After phase 2 and after phase 4, tell me to run `/clear` before continuing.
