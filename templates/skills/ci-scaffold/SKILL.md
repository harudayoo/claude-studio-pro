---
description: Generates a working CI (and, if the project has a UI, E2E) GitHub Actions pipeline from docs/setup/PROFILE.md. Use once, early in a project's life, or whenever asked to add or repair CI.
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash(git branch --show-current *) Bash(cat docs/setup/PROFILE.md)
---

The studio pipeline enforces process and code quality inside Claude Code, but
none of that is verified independently unless it also runs in CI on every
push. This skill closes that gap. Read `.claude/rules/devops.md` first, then
`docs/setup/PROFILE.md` for the confirmed commands and stack.

## What to produce

`.github/workflows/ci.yml` — one job per fast, always-on check:

1. **Style/lint** — the profile's format/lint command in check mode (not the
   auto-fix mode used locally).
2. **Static analysis / type-check** — the profile's type-check command, if one
   is confirmed. Skip the job with a comment explaining why if none exists —
   do not invent one.
3. **Dependency audit** — the profile's dependency-audit command, gated on
   high/critical severity per `.claude/rules/devops.md`. If no audit tool is
   configured for this ecosystem, say so and suggest the standard one for the
   detected package manager (`npm audit`, `composer audit`, `pip-audit`,
   `cargo audit`, `govulncheck`) rather than skipping silently.
4. **Test** — the profile's non-watching test command. If tests need a
   database, cache, or queue, add it as an ephemeral `services:` container
   scoped to the job, matching whatever the project's local dev stack
   actually uses — check `docker-compose.yml` or `.env.example` for the real
   engine and version rather than defaulting to a generic one.
5. **Build** — the profile's build command, if the project has a build step.

Trigger on push and pull_request to the project's protected branches (read
them from git — `main`/`master` at minimum, plus any staging/development
branches this repo's branch-promotion flow actually uses; ask if it is not
obvious from `git branch -a` or existing docs). Add
`concurrency: { group: ci-${{ github.ref }}, cancel-in-progress: true }`.

If `Has UI` in the profile is yes and a browser test runner is already a
project dependency (Playwright, Cypress, etc.), also produce
`.github/workflows/e2e.yml`: a single job that boots the app plus any
services it needs and runs the browser suite. Gate this one on protected
branches only (or `workflow_dispatch`), not every push — it is the heavier
suite `.claude/rules/devops.md` says belongs at promotion gates. If no
browser test runner is present, do not create this file, and say so.

## Constraints

- Use the exact commands confirmed in `PROFILE.md`. If a needed command is
  still `NEEDS_REVIEW`, stop and say which one — do not guess a plausible
  command for an unconfigured profile field.
- Do not overwrite an existing workflow file with the same name. Show the
  proposed content and ask before replacing it.
- Keep each job minimal and cacheable: cache the package manager's artifacts
  keyed on its lockfile hash.
- Report what was written, what was skipped and why, and what still needs a
  human decision (e.g. which Postgres/MySQL/Redis version matches production).
