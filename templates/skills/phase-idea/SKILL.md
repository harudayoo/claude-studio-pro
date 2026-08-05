---
description: Runs the IDEA phase — frames a raw request into a problem statement, scope boundaries, success metrics and EARS acceptance criteria. Use as the first phase of any feature, bug or change request.
disable-model-invocation: true
argument-hint: [description of the change]
allowed-tools: Bash(git status *) Bash(git log *) Bash(cat .claude/state/gate.json)
---

Request: $ARGUMENTS

Gate: !`cat .claude/state/gate.json 2>/dev/null || echo '{"phase":"idle"}'`

## Owner

`product-analyst`, plus `ux-researcher` when this touches a user-facing surface.
Permission mode: **plan** — this phase reads and writes documents only.

## Required output

- `docs/specs/<slug>/idea.md`
- `docs/specs/<slug>/ux.md` when `ux-researcher` ran

Pick the slug from the request: lowercase, hyphenated, stable. It names the spec
directory for the whole cycle.

## Delegation

Brief each agent with the template below. They start with an empty context and
cannot see this conversation.

    TASK: <one imperative sentence>
    SPEC: docs/specs/<slug>/  (create it)
    SCOPE: you may write only docs/specs/<slug>/**
    CONTEXT YOU NEED: <3-6 bullets, including file paths already discovered>
    DONE MEANS: docs/specs/<slug>/idea.md exists and is non-empty
    DO NOT: propose an implementation; invent an answer to an open question

## Gate

This phase closes when:

1. `idea.md` exists and is non-empty.
2. Every acceptance criterion is stated as "when X, the system shall Y" and is
   observable by a test.
3. The open questions list is empty, or every remaining question is explicitly
   deferred with a named owner.
4. **You approve it.** Read it. An idea gate you rubber-stamp is a gate that
   does not exist.

Then update `.claude/state/gate.json`: set `phase` to `plan`, `slug`,
`spec_dir`, and append `idea` to `approved`.

Stop after this phase. Report what needs my approval.
