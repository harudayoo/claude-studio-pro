# claude-studio-pro

A lean, Pro-plan-sized development pipeline for Claude Code.

Seven subagents, seven skills, five path-scoped rules, four enforcement hooks.
Every change goes through **Plan → Critique → Test → Create → Verify → Document**,
and no gate closes on an assertion — each one closes on a file.

Code quality without a working pipeline behind it doesn't ship: `devops.md`
and the `ci-scaffold` / `security-audit` skills exist so that what this
pipeline enforces inside Claude Code is also verified independently, on every
push, by CI — not just asserted in a session. See "DevSecOps coverage" below.

Designed for the Claude **Pro** plan, where Opus and Sonnet share one usage
pool. It uses one Opus agent, once per feature. It works fine on Max too; it
just leaves headroom you can spend elsewhere.

---

## Why this exists

Two claims, both of which this repo is built around:

1. **CLAUDE.md is advisory. Hooks are deterministic.** Anthropic's own docs
   say Claude reads memory files and tries to follow them, without a guarantee
   of compliance. So anything that must hold — no code before an approved plan,
   no undocumented change — is a hook, not a sentence in a prompt.
2. **More agents is not more quality.** Every subagent is a fresh context
   window. The full 24-agent version of this design costs several times more
   for marginal gain. This is the seven that earn their place.

---

## Install

```bash
git clone https://github.com/<you>/claude-studio-pro.git ~/.claude-studio-pro
cd /path/to/your/project
~/.claude-studio-pro/install.sh
```

Or from anywhere:

```bash
~/.claude-studio-pro/install.sh --target /path/to/your/project
```

Preview without writing anything:

```bash
~/.claude-studio-pro/install.sh --target /path/to/project --dry-run
```

**Read `install.sh` before running it.** It writes into your repository. It
takes a backup of anything it touches, but you should still know what it does.
There is deliberately no `curl | bash` one-liner.

### Requirements

| | |
|---|---|
| Required | `bash`, `awk`, `grep`, `sed`, `git` |
| Recommended | `jq` — hooks use it when present and fall back to a shell parser when absent |
| Optional | `python3` — only for the monthly `/report` script |

Works on Linux, macOS and WSL.

---

## The three-step setup

### 1. Install

```bash
~/.claude-studio-pro/install.sh --target .
```

Detects your stack, scaffolds `.claude/` and `docs/`, and writes
`docs/setup/PROFILE.md` with its best guesses. Anything it could not determine
is marked `NEEDS_REVIEW`. Existing files are backed up to
`.claude/.backup-<timestamp>/`; `CLAUDE.md` is never overwritten.

### 2. Confirm the profile

Open `docs/setup/PROFILE.md`. Fill every `NEEDS_REVIEW` field, then **run every
command in the table yourself** and record the exit code in the verification log.

> A field is not confirmed until its command has executed.

Two traps the installer will flag but cannot fix for you:

- **Watching test scripts.** If `npm test` starts a watcher, the output-filter
  hook will hang. You need the non-interactive form (`vitest run`, `jest --ci`,
  `--watch=false`).
- **Lint vs format.** The post-edit hook wants the command that *fixes*, not
  the one that *checks*.

### 3. Configure

```bash
~/.claude-studio-pro/configure.sh --target .
```

Substitutes the placeholders throughout `.claude/`. **It refuses to run while
`NEEDS_REVIEW` is present.** That refusal is the point: a half-configured hook
that silently matches nothing is worse than no hook at all.

If you genuinely want to proceed early, `--allow-incomplete` leaves the
unconfigured hooks inert *and loud* — they warn on stderr rather than passing
quietly.

---

## Verifying the install

```bash
~/.claude-studio-pro/verify.sh --target .
```

Exercises every hook with synthetic input and prints a pass/fail table. Expect
33 passing checks. Run it again after any change to a hook or the profile.

**A hook you have not watched fire is a hook you do not have.**

Then, inside Claude Code:

```
/doctor      # duplicate agent names, oversized memory, skill listing overflow
/hooks       # confirm all four registered
/context     # pre-prompt total should sit under ~12% of the window
```

---

## What gets installed

```
.claude/
├── agents/          planner, critic, test-designer, implementer,
│                    reviewer, qa-runner, doc-writer
├── skills/          /feature /handoff /codebase-map /web-audit /report
│                    /ci-scaffold /security-audit
├── rules/           backend, frontend, testing, security, devops  (path-scoped)
├── hooks/           gate-check, filter-output, post-edit, doc-check
├── agent-memory/    committed — this is the institutional memory
└── state/           gate.json, doc-map.json
docs/
├── setup/           PROFILE.md
├── adr/             TEMPLATE.md
├── specs/<slug>/    plan, critique, acceptance, verification, evidence/
├── handoff/
└── reports/
.github/workflows/   ci.yml (+ e2e.yml if HAS_UI) — written by /ci-scaffold, not by install.sh
CLAUDE.md            (or CLAUDE.studio.md if you already had one)
```

### The seven agents

| Agent | Model | Memory | Writes | Job |
|---|---|---|---|---|
| `planner` | sonnet | project | docs | Scope, acceptance criteria, file map, rejected alternatives |
| `critic` | **opus** | project | docs | Attacks the plan before any code exists. Once per feature. |
| `test-designer` | sonnet | project | tests | Failing tests from the acceptance criteria |
| `implementer` | sonnet | project | source | Turns red tests green, nothing more |
| `reviewer` | sonnet | project | none | Correctness, security, contract drift, standards |
| `qa-runner` | sonnet | local | evidence | Real browser, every breakpoint. Playwright scoped inline. |
| `doc-writer` | sonnet | project | docs | Docs, ADRs, changelog, handoff |

Discipline knowledge lives in `.claude/rules/`, not in separate agents. That is
why one `implementer` can cover front-end and back-end: the rules load
automatically based on which files it touches, and cost nothing until then.

`qa-runner` declares Playwright **inline in its own frontmatter**, so the
browser tool definitions never enter your main session. This is worth several
thousand tokens per session and is the reason this is an install script rather
than a Claude Code plugin — plugin subagents ignore the `mcpServers` field.

### The four hooks

| Hook | Event | Behaviour on misconfiguration |
|---|---|---|
| `gate-check` | PreToolUse (Edit/Write) | **Fails closed** for protected source, open for everything else |
| `filter-output` | PreToolUse (Bash) | Fails open — a broken filter must never block work |
| `post-edit` | PostToolUse (Edit/Write) | Fails open |
| `doc-check` | Stop | Fails open |

`filter-output` is the largest token saving here: it rewrites test and build
commands so only failures return to the model, turning tens of thousands of
tokens into hundreds. It also filters the profile's dependency-audit command,
watching for `vulnerabilit` in addition to `FAIL`/`ERROR` — an audit finding
doesn't announce itself the way a test failure does, and a filter that only
knew the test vocabulary would quietly eat a real high/critical finding.

---

## DevSecOps coverage

Session-level rules are advisory the moment the session ends. `devops.md` and
two skills exist so this pipeline's standards are also checked by something
that runs whether or not anyone is in a Claude Code session:

- **`.claude/rules/devops.md`** — loads whenever a workflow, Dockerfile, or
  compose file is touched. Covers promotion-gated triggers, ephemeral test
  infrastructure, reading full (not truncated) audit output, severity-gated
  dependency scanning, the static-analysis-baseline pattern for suppressing
  an existing false-positive backlog without lowering the check, and treating
  an unfixable pinned-dependency CVE as tracked debt rather than a silenced
  gate.
- **`/ci-scaffold`** — run once, early. Reads the confirmed commands in
  `docs/setup/PROFILE.md` and writes a real `.github/workflows/ci.yml`
  (lint, type-check, dependency audit, test, build) plus `e2e.yml` if the
  project has a UI and a browser test runner. This install script sets up
  Claude Code's side of the pipeline; it does not touch your CI provider —
  `/ci-scaffold` is what closes that gap, and it only proposes commands
  already confirmed in the profile, never a guessed one.
- **`/security-audit`** — run any time, not only at the verify gate. Runs the
  profile's dependency-audit command in full, scans the diff for
  committed-secret patterns, and checks changed authorisation code against
  two recurring failure classes: a raw permission check bypassing a resolver
  that exists specifically to apply an override, and a query that crosses a
  tenant/owner boundary without a server-side scope filter.

`security.md`'s **Authorisation source of truth** and **Cross-tenant scope**
rules are the same two patterns generalised — `/security-audit` is the
callable check, the rule is what `reviewer` and `implementer` load
automatically while a session is open.

---

## Daily use

```
/ci-scaffold                        # once, early — writes real CI, not just rules
/clear
/feature add invoice CSV export     # → planner writes plan.md
                                    #   you read and approve it
run the critique phase              # → critic (opus, once)
                                    #   resolve blockers, approve
/clear
run the test phase                  # → red tests + evidence
run the create phase                # → green tests + evidence
/clear
run the verify phase                # → reviewer, then qa-runner
/security-audit                     # anything touching auth, data scope, or a dependency
/web-audit                          # UI work only
run the document phase
/handoff
```

Three `/clear` calls per feature is not excessive. It is the difference between
a feature costing one context window and costing four.

---

## After install: two things people skip

### Seed the agent memory

`memory: project` writes to `.claude/agent-memory/`, which is **committed to
git** — unlike auto memory, which is machine-local and never reaches a
subagent. Three read-only passes, one per session:

```
Use the planner agent to survey this codebase's architecture: module
boundaries, the layering convention actually in use, where business logic
lives, and the three most significant design decisions visible in the code.
Write findings to your agent memory. Modify no file.
```

Repeat for `reviewer` (defect and security patterns) and `implementer`
(naming, file organisation, existing utilities). Then write
`.claude/skills/codebase-map/SKILL.md` from what they found, and commit
`.claude/agent-memory/`.

### Take a baseline

Read `/usage` immediately before and after your first complete feature — the
*weekly* bar, press `w`. Write it to `docs/reports/baseline.md`.

| Cost per medium feature | What it means |
|---|---|
| under 5% of weekly | Comfortable. Consider adding a second verify agent. |
| 5–10% | Healthy. Leave it alone for five more features. |
| over 10% | Cut: `qa-runner` to the critical path, then `critic` to Sonnet, then merge verify and document. **Never the gates.** |

Without the baseline you cannot tell later whether any change you make is an
improvement or a regression.

---

## Recommended companions

Not installed by this repo — they are Claude Code plugins and MCP servers you
add yourself. Keep the list short; every one has a standing token cost.

```bash
/plugin install security-guidance@claude-plugins-official
/plugin install <language>-lsp@claude-plugins-official   # install the LSP binary first
claude plugin add anthropic/frontend-design              # if the project has a UI
claude mcp add context7 -s user -- npx -y @upstash/context7-mcp@latest
```

Two always-on MCP servers maximum. Everything heavier gets scoped to a single
agent's frontmatter, the way `qa-runner` does with Playwright.

---

## Updating

```bash
cd ~/.claude-studio-pro && git pull
cd /path/to/project && ~/.claude-studio-pro/install.sh --target . --force
~/.claude-studio-pro/configure.sh --target .
~/.claude-studio-pro/verify.sh --target .
```

`install.sh` backs up before replacing. Your `PROFILE.md`, `CLAUDE.md`,
`agent-memory/` and everything under `docs/specs/` are left alone.

## Uninstalling

```bash
~/.claude-studio-pro/install.sh --target . --uninstall
```

Removes `.claude/agents`, `skills`, `rules`, `hooks` and `state` after taking a
backup. Leaves `docs/`, `CLAUDE.md` and `settings.json` for you to clean up
deliberately.

---

## Customising

- **Add a rule** rather than an agent. Rules are free until a matching file is
  read; agents cost a context window every time they run.
- **Split `implementer`** into front-end and back-end specialists only if you
  observe it applying the wrong rules. Measure with `/usage` before and after.
- **Do not add agent teams or dynamic workflows on Pro.** Agent teams use
  roughly seven times the tokens of a single session.

---

## Known limitations

- The gate hook protects only the source roots named in your profile. Files
  outside them are not gated, by design.
- `doc-check` is a blunt instrument: it asks whether `docs/` changed at all,
  not whether the *right* doc changed. The monthly `/report` catches the rest.
- The `report` script needs `python3`. Skip it if you do not have it; nothing
  else depends on it.
- `/ci-scaffold` proposes a workflow from the profile's confirmed commands; it
  does not run or validate it. Commit it and watch the first real run before
  trusting it as a merge gate.
- The dependency-audit command is detected per ecosystem
  (`composer audit`, `npm`/`pnpm`/`yarn audit`, `pip-audit`, `cargo audit`,
  `govulncheck`). Some of these are not installed by default for their
  ecosystem (`pip-audit`, `cargo-audit`) — the profile will still record the
  command; installing the tool itself is on you.
- `security.md`'s scope-boundary and resolver-pattern rules describe two
  *shapes* of authorisation bug, not a scanner. They tell a reviewing agent
  what to look for; they do not replace a real SAST/dependency tool.
- Claude Code changes weekly. If a frontmatter field or command in here stops
  matching `code.claude.com/docs`, the docs win. Open an issue.

## Licence

MIT.
