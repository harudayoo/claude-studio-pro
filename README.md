# claude-studio

A governed development pipeline for Claude Code, sized to your plan.

Every change goes through **Idea → Plan → Test → Create → Verify → Document**,
and no gate closes on an assertion — each one closes on a file.

At install time you pick your Claude Code plan. The installer builds the roster,
the verification fan-out and the token budget that plan can actually afford:

| Plan | Agents | Skills | Rules | Verify | Debate | Reporting |
|---|---|---|---|---|---|---|
| **Pro** | 7 | 7 | 5 | one reviewer, then QA | single critic | monthly `/report` |
| **Max** | 11 | 9 | 6 | 3 parallel, read-only | + proposal & judge | monthly `/report` |
| **Max 20x** | 24 | 14 | 7 | 5 parallel, read-only | + agent teams / workflows | `/studio-report` on OTel |

All three share the same enforcement layer: four hooks, path-scoped rules, a
committed gate file, and agent memory in version control. The tiers differ in
how many specialists exist and how wide the verification fan-out is — never in
how strict the gates are.

---

## Why this exists

Three claims, and the whole repo is built around them:

1. **CLAUDE.md is advisory. Hooks are deterministic.** Anthropic's own docs say
   Claude reads memory files and *tries* to follow them, without a guarantee of
   compliance. So anything that must hold — no code before an approved plan, no
   undocumented change — is a hook, not a sentence in a prompt.
2. **More agents is not more quality.** Every subagent is a fresh context
   window. A 24-agent roster on a project that needs seven is slower, more
   expensive, and *less* coherent. That is why the plan question exists.
3. **"Done" is a claim, not evidence.** The failure mode that kills spec-driven
   setups is accepting an agent's assertion of completion. Every gate here
   demands an artifact — a passing run, a screenshot, a report file.

---

## Install

```bash
git clone https://github.com/harudayoo/claude-studio-pro.git ~/.claude-studio
cd /path/to/your/project
~/.claude-studio/install.sh
```

The installer asks which plan you are on and installs the matching pipeline:

```
Which Claude Code plan is this pipeline for?
The roster, the verification fan-out and the token budget all follow from this.

  1) Pro     7 agents, sequential, one Opus call per feature
     Lean pipeline for a shared Opus/Sonnet pool. One agent per phase, no
     fan-out, no debate protocol. Roughly one context window per phase.

  2) Max     11 agents, conductor-routed, 3-way parallel verify
     The nine-agent core plus evidence-producing verification. Adds the IDEA
     phase, a conductor that enforces phase order, and the two-proposal debate
     protocol for irreversible decisions.

  3) Max 20x 24 agents, 5-way parallel verify, 3-level debate, telemetry
     The complete roster: specialist designers per surface, five-lens parallel
     verification, agent-team escalation for genuinely uncertain work, and a
     measured monthly report.

Choose [1-3]:
```

Skip the prompt when you already know:

```bash
~/.claude-studio/install.sh --plan max20x --target /path/to/your/project
```

Preview without writing anything:

```bash
~/.claude-studio/install.sh --plan max --target /path/to/project --dry-run
```

**Read `install.sh` before running it.** It writes into your repository. It
takes a backup of anything it touches, but you should still know what it does.
There is deliberately no `curl | bash` one-liner.

### Requirements

| | |
|---|---|
| Required | `bash`, `awk`, `grep`, `sed`, `git` |
| Recommended | `jq` — hooks use it when present and fall back to a shell parser when absent |
| Optional | `python3` — the report scripts. Required in practice on Max 20x. |

Works on Linux, macOS and WSL.

---

## Which plan should I pick?

Pick by what you can afford to run every day, not by what is impressive.

**Pro** — Opus and Sonnet share one usage pool. This roster spends Opus exactly
once per feature, on the plan critique, which is the one place a wrong answer is
expensive to reverse. Everything else is Sonnet, sequential. If you are new to
this, start here even on a bigger plan: it is the smallest thing that still
enforces every gate.

**Max** — you can afford a conductor that never writes code, an IDEA phase with
its own artifact, and three reviewers in parallel instead of one. This is the
blueprint's "start with nine", plus `qa-runner` and `security-auditor` because
verification that produces no evidence is not verification.

**Max 20x** — you can afford specialists per surface (`data-architect`,
`api-designer`, `ui-designer`, `security-architect`, `devops-planner`), a
five-lens verify fan-out, three levels of debate including agent teams, and a
monthly report built on OpenTelemetry rather than anecdote.

You can change your mind:

```bash
~/.claude-studio/install.sh --plan pro --target .   # switches tiers
```

A tier change backs up and removes the agents, skills and rules the old tier
owned and the new one does not, then re-renders `CLAUDE.md` and
`settings.json`. Your `PROFILE.md`, `agent-memory/` and `docs/specs/` are left
alone.

---

## The three-step setup

### 1. Install

```bash
~/.claude-studio/install.sh --plan <pro|max|max20x> --target .
```

Detects your stack, scaffolds `.claude/` and `docs/`, records the chosen tier in
`.claude/state/studio.json`, and writes `docs/setup/PROFILE.md` with its best
guesses. Anything it could not determine is marked `NEEDS_REVIEW`. Existing
files are backed up to `.claude/.backup-<timestamp>/`; `CLAUDE.md` is never
overwritten.

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
~/.claude-studio/configure.sh --target .
```

Substitutes the placeholders throughout `.claude/`. **It refuses to run while
`NEEDS_REVIEW` is present.** That refusal is the point: a half-configured hook
that silently matches nothing is worse than no hook at all.

If you genuinely want to proceed early, `--allow-incomplete` leaves the
unconfigured hooks inert *and loud* — they warn on stderr rather than passing
quietly.

`configure.sh` reads the installed tier and prunes the UI-only pieces when your
profile says the project has no UI. On Pro that is three files; on Max 20x it is
eleven.

---

## Verifying the install

```bash
~/.claude-studio/verify.sh --target .
```

Exercises every hook with synthetic input, checks the installed inventory
against your tier's manifest, and flags any agent left behind by a tier switch.
Expect roughly 36 checks on Pro, 43 on Max, 62 on Max 20x.

**A hook you have not watched fire is a hook you do not have.**

Then, inside Claude Code:

```
/doctor      # duplicate agent names, oversized memory, skill listing overflow
/hooks       # confirm all four registered
/context     # pre-prompt total should sit under ~15% of the window
```

---

## What gets installed

```
.claude/
├── agents/          the tier's roster
├── skills/          the tier's playbooks
├── rules/           path-scoped standards, loaded only when a match is read
├── hooks/           gate-check, filter-output, post-edit, doc-check
├── agent-memory/    committed — this is the institutional memory
├── workflows/       Max 20x only
└── state/           gate.json, studio.json, doc-map.json
docs/
├── setup/           PROFILE.md
├── adr/             TEMPLATE.md
├── specs/<slug>/    idea, plan, critique, acceptance, verification, evidence/
├── design/          direction, tokens, components   (Max, Max 20x)
├── api/             generated reference             (Max 20x)
├── runbooks/        ops procedures                  (Max 20x)
├── handoff/
└── reports/
.github/workflows/   ci.yml (+ e2e.yml if HAS_UI) — written by /ci-scaffold
CLAUDE.md            (or CLAUDE.studio.md if you already had one)
```

### Pro — 7 agents

| Agent | Model | Memory | Writes | Job |
|---|---|---|---|---|
| `planner` | sonnet | project | docs | Scope, acceptance criteria, file map, rejected alternatives |
| `critic` | **opus** | project | docs | Attacks the plan before any code exists. Once per feature. |
| `test-designer` | sonnet | project | tests | Failing tests from the acceptance criteria |
| `implementer` | sonnet | project | source | Turns red tests green, nothing more |
| `reviewer` | sonnet | project | none | Correctness, security, contract drift, standards |
| `qa-runner` | sonnet | local | evidence | Real browser, every breakpoint. Playwright scoped inline. |
| `doc-writer` | sonnet | project | docs | Docs, ADRs, changelog, handoff |

Phases: `plan → critique → test → create → verify → document`.

Discipline knowledge lives in `.claude/rules/`, not in separate agents — which
is how one `implementer` covers front-end and back-end. Rules load automatically
based on which files are touched, and cost nothing until then.

### Max — 11 agents

Adds `conductor` (owns phase order, never writes code) and `product-analyst`
(the IDEA phase), and splits the Pro roster into the blueprint's named
specialists: `system-architect`, `red-team-critic`, `backend-engineer`,
`frontend-engineer`, `code-reviewer`, `security-auditor`.

Phases: `idea → plan → test → create → verify → document`.

Verify dispatches `code-reviewer`, `security-auditor` and `qa-runner` in
parallel from one call. Adds `/debate` and `/design-tokens`, and the
`database.md` rule.

### Max 20x — 24 agents

| Phase | Agents |
|---|---|
| Orchestration | `conductor` |
| Idea | `product-analyst`, `ux-researcher` |
| Plan | `system-architect`, `data-architect`, `api-designer`, `ui-designer`, `security-architect`, `devops-planner`, `red-team-critic` |
| Test | `test-designer`, `a11y-perf-budgeter` |
| Create | `backend-engineer`, `frontend-engineer`, `db-engineer`, `infra-engineer` |
| Verify | `code-reviewer`, `security-auditor`, `qa-runner`, `perf-a11y-auditor`, `seo-auditor` |
| Document | `doc-writer`, `memory-curator`, `report-generator` |

Six phase playbooks (`/phase-idea` … `/phase-document`) instead of one
`/feature`. Adds the `seo.md` rule, `/studio-report` with three Python scripts,
and telemetry keys wired but switched off.

Model routing follows one policy across every tier: **haiku** for mechanical
scan work, **sonnet** for building, **opus** for irreversible decisions and
adversarial reasoning. The installer prints which agents are on Opus, because
that is where the cost is.

### The four hooks — identical on every tier

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
doesn't announce itself the way a test failure does, and a filter that only knew
the test vocabulary would quietly eat a real high/critical finding.

Heavy MCP servers are declared **inline in one agent's frontmatter**, never in
`.mcp.json`: Playwright on `qa-runner`, Chrome DevTools on `perf-a11y-auditor`.
Those tool definitions never enter your main session. This is worth several
thousand tokens per session and is the reason this is an install script rather
than a Claude Code plugin — plugin subagents ignore the `mcpServers` field.

---

## DevSecOps coverage

Session-level rules are advisory the moment the session ends. `devops.md` and
two skills exist so this pipeline's standards are also checked by something that
runs whether or not anyone is in a Claude Code session:

- **`.claude/rules/devops.md`** — loads whenever a workflow, Dockerfile, or
  compose file is touched. Covers promotion-gated triggers, ephemeral test
  infrastructure, reading full (not truncated) audit output, severity-gated
  dependency scanning, the static-analysis-baseline pattern for suppressing an
  existing false-positive backlog without lowering the check, and treating an
  unfixable pinned-dependency CVE as tracked debt rather than a silenced gate.
- **`/ci-scaffold`** — run once, early. Reads the confirmed commands in
  `docs/setup/PROFILE.md` and writes a real `.github/workflows/ci.yml` (lint,
  type-check, dependency audit, test, build) plus `e2e.yml` if the project has a
  UI and a browser test runner. It only proposes commands already confirmed in
  the profile, never a guessed one.
- **`/security-audit`** — run any time, not only at the verify gate. Runs the
  profile's dependency-audit command in full, scans the diff for
  committed-secret patterns, and checks changed authorisation code against two
  recurring failure classes: a raw permission check bypassing a resolver that
  exists specifically to apply an override, and a query that crosses a
  tenant/owner boundary without a server-side scope filter.

`security.md`'s **Authorisation source of truth** and **Cross-tenant scope**
rules are the same two patterns generalised — `/security-audit` is the callable
check, the rule is what the reviewing and implementing agents load automatically
while a session is open.

---

## Daily use

### Pro

```
/ci-scaffold                        # once, early — writes real CI, not just rules
/clear
/feature add invoice CSV export     # → planner writes plan.md; you approve it
run the critique phase              # → critic (opus, once); resolve blockers
/clear
run the test phase                  # → red tests + evidence
run the create phase                # → green tests + evidence
/clear
run the verify phase                # → reviewer, then qa-runner
/security-audit                     # anything touching auth, data scope, or a dependency
run the document phase
/handoff
```

### Max

```
/feature add invoice CSV export     # → conductor takes it from here,
                                    #   one phase and one gate per turn
/debate                             # before approving a plan on the escalation list
/clear                              # after the plan gate and after create
/handoff
```

### Max 20x

```
use the conductor agent to start: add invoice CSV export
/phase-idea → /phase-plan → /debate → /phase-test → /phase-create
            → /phase-verify → /phase-document
/studio-report 2026-08              # month end
```

Three `/clear` calls per feature is not excessive. It is the difference between
a feature costing one context window and costing four.

---

## After install: two things people skip

### Seed the agent memory

`memory: project` writes to `.claude/agent-memory/`, which is **committed to
git** — unlike auto memory, which is machine-local and never reaches a subagent.
One read-only pass per specialist, one per session:

```
Use the system-architect agent to survey this codebase's architecture: module
boundaries, the layering convention actually in use, where business logic
lives, and the three most significant design decisions visible in the code.
Write findings to your agent memory. Modify no file.
```

Repeat for the reviewing, security and implementing agents your tier installed.
Then write `.claude/skills/codebase-map/SKILL.md` from what they found, and
commit `.claude/agent-memory/`. Roughly an hour of wall-clock, and from then on
each agent starts with real knowledge of your code instead of guesses.

### Take a baseline

Read `/usage` immediately before and after your first complete feature — the
*weekly* bar, press `w`. Write it to `docs/reports/baseline.md`.

| Cost per medium feature | What it means |
|---|---|
| under 5% of weekly | Comfortable. Consider widening the verify fan-out. |
| 5–10% | Healthy. Leave it alone for five more features. |
| over 10% | Cut, in this order: narrow the verify fan-out to the critical path, move an Opus agent to Sonnet, merge verify and document. **Never the gates.** |

Without the baseline you cannot tell later whether any change you make is an
improvement or a regression. On Max 20x this matters most: `/studio-report`
compares against `docs/reports/baseline.md`, and with no baseline every saving
it reports is invented.

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

Code-intelligence plugins are a token optimisation, not a convenience: one "go
to definition" replaces a grep plus reading three candidate files.

Two always-on MCP servers maximum. Everything heavier gets scoped to a single
agent's frontmatter, the way `qa-runner` does with Playwright.

---

## Updating

```bash
cd ~/.claude-studio && git pull
cd /path/to/project && ~/.claude-studio/install.sh --target . --force
~/.claude-studio/configure.sh --target .
~/.claude-studio/verify.sh --target .
```

With no `--plan`, the installer reuses the tier recorded in
`.claude/state/studio.json`. It backs up before replacing. Your `PROFILE.md`,
`CLAUDE.md`, `agent-memory/` and everything under `docs/specs/` are left alone.

## Uninstalling

```bash
~/.claude-studio/install.sh --target . --uninstall
```

Removes `.claude/agents`, `skills`, `rules`, `hooks`, `state` and `workflows`
after taking a backup. Leaves `docs/`, `CLAUDE.md` and `settings.json` for you
to clean up deliberately.

---

## Customising

`templates/` is a pool of resources plus one manifest per tier:

```
templates/
├── agents/          every agent definition, pooled
├── skills/          every skill, pooled
├── rules/           every path-scoped rule, pooled
├── common/          hooks and docs scaffolding — shared by all tiers
└── tiers/<tier>/
    ├── manifest.conf     which agents, skills and rules this tier installs
    ├── CLAUDE.md.tmpl    the constitution for this tier's phases
    ├── settings.json.tmpl
    ├── gate.json
    └── {agents,skills,rules}/   optional per-tier overrides
```

`install.sh` contains no per-tier logic. To add an agent to a tier, drop the
file in `templates/agents/` and add its name to that tier's `TIER_AGENTS`. The
installer fails before writing anything if a manifest names a resource that does
not exist.

A file in `templates/tiers/<tier>/skills/<name>/` overrides the pooled one of
the same name — that is how `/feature` means a different playbook on Pro and Max
while keeping the same command name.

Two rules of thumb regardless of tier:

- **Add a rule rather than an agent.** Rules are free until a matching file is
  read; agents cost a context window every time they run.
- **Only add an agent when you can name the failure it prevents.** Measure with
  `/usage` before and after.

---

## Known limitations

- The gate hook protects only the source roots named in your profile. Files
  outside them are not gated, by design.
- `doc-check` is a blunt instrument: it asks whether `docs/` changed at all, not
  whether the *right* doc changed. The monthly report catches the rest.
- The report scripts need `python3`. On Pro and Max you can skip them; on Max
  20x `/studio-report` is a headline feature and will not run without it.
- `tokens.py` falls back to parsing local session transcripts when no OTLP
  collector is configured. That format is internal to Claude Code and changes
  between releases — the script labels those numbers as indicative, and you
  should too. The durable route is a collector.
- Telemetry and agent teams ship **disabled** on Max 20x. Both are opt-in edits
  to `.claude/settings.json`; agent teams cost roughly 7× a single session.
- `/ci-scaffold` proposes a workflow from the profile's confirmed commands; it
  does not run or validate it. Commit it and watch the first real run before
  trusting it as a merge gate.
- The dependency-audit command is detected per ecosystem (`composer audit`,
  `npm`/`pnpm`/`yarn audit`, `pip-audit`, `cargo audit`, `govulncheck`). Some
  are not installed by default for their ecosystem — the profile records the
  command; installing the tool is on you.
- `security.md`'s scope-boundary and resolver-pattern rules describe two
  *shapes* of authorisation bug, not a scanner. They tell a reviewing agent what
  to look for; they do not replace a real SAST or dependency tool.
- Claude Code changes weekly. If a frontmatter field or command in here stops
  matching `code.claude.com/docs`, the docs win. Open an issue.

## Further reading

- [`docs/DESIGN-RATIONALE.md`](docs/DESIGN-RATIONALE.md) — the full architecture
  this repo implements: the primitive-selection heuristic, the token cost model,
  the twelve levers, the three debate levels, and the complete 24-agent roster.
  Read this before changing a tier's shape.
- [`docs/SETUP-SPEC.md`](docs/SETUP-SPEC.md) — the step-by-step build of the Pro
  tier, if you would rather assemble it by hand than run the installer.

## Licence

MIT.
