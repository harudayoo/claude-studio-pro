---
title: "Claude Code Studio — Pro Plan Setup Spec"
subtitle: "An executable setup document. Lean agent pipeline, hard token budget, quality gates that produce evidence."
date: "August 2026 · v1.0"
---

# 0. Instructions to Claude Code

**Read this section fully before doing anything.**

You are setting up a governed development pipeline in this repository. This document is a specification, not a discussion. Follow it in order.

## Rules for this setup

1. **One phase per session.** Complete a phase, report what you created, then stop. The user will run `/clear` and start the next phase. Do not attempt multiple phases in one session.
2. **Verify before writing.** Before putting any CLI command, flag, frontmatter field, or setting key into a file, confirm it still exists in the current docs at `code.claude.com/docs`. Claude Code changes weekly. If something in this document no longer matches the docs, **say so and stop** — do not silently substitute an alternative.
3. **Adapt, don't paste.** Every script and glob in this document is a template written for a generic stack. Rewrite each one against the Project Profile in §1 before creating the file. A hook that silently matches nothing is worse than no hook.
4. **Test every hook.** After creating hooks, deliberately trigger each one and show the user the output proving it fired or blocked.
5. **No extra scope.** Do not add agents, skills, MCP servers, or plugins that are not listed here. This roster is deliberately small for token reasons. If you think something is missing, say so; do not add it.
6. **Ask when the profile is incomplete.** If §1 has blanks you cannot infer from the codebase, ask before proceeding.

## Starting prompt for the user

Paste this at the start of each setup session:

```
Read docs/setup/SETUP-SPEC.md. Complete Phase <N> only, then stop and
summarise what you created and what I should verify. Before writing any
command or config key into a file, confirm it against the current docs at
code.claude.com/docs and tell me if anything has changed.
```

---

# 1. Project profile

**Fill this in first.** Claude: read the repository and propose values, then confirm with the user before Phase 1.

| Field | Value |
|---|---|
| Language / framework | |
| Package manager | |
| Dev server command | |
| Test command | |
| Single-test command | |
| Lint / format command | |
| Type-check command | |
| Build command | |
| Source root(s) | |
| Front-end root | |
| Test root | |
| Migration path (if any) | |
| Design token file path | |
| Does this project have a UI? | yes / no |
| Does this project have a public API? | yes / no |

Everything downstream — hook globs, the doc map, the agent rules — is derived from this table. Write it to `docs/setup/PROFILE.md` and keep it current.

---

# 2. Pro plan operating constraints

These are **budget rules, not preferences.** The Pro plan has a rolling 5-hour limit and a weekly limit, and Claude chat usage draws on the same pool. Opus and Sonnet share one bucket on Pro, so an Opus turn costs disproportionately more than its token count suggests.

## 2.1 Hard limits for this setup

| Constraint | Value | Why |
|---|---|---|
| Subagents | **7 maximum** | Each is a fresh context window |
| Opus usage | **one agent, one pass per feature** | Opus and Sonnet share the Pro pool |
| Always-on MCP servers | **2 maximum** | Each costs thousands of tokens per session |
| Agent teams | **never** | ~7× the tokens of a single session |
| Dynamic workflows / `ultracode` | **never** | Spawns dozens of agents per run |
| Verify agents in parallel | **2 maximum** | Each returns a full result into main context |
| CLAUDE.md length | **under 150 lines** | Loaded in full, every session |
| Orchestration | **main session, not a subagent** | Saves one whole context window per feature |

## 2.2 Model policy

Every agent declares `model` in frontmatter. Resolution order is env var → per-invocation → frontmatter → session.

| Tier | Model | Agents |
|---|---|---|
| Scan | `haiku` | doc-writer's inventory pass, report generation |
| Build | `sonnet` | planner, test-designer, implementer, reviewer, qa-runner, doc-writer |
| Reason | `opus` | `critic` only, invoked once per feature at the plan gate |

Set this in `.claude/settings.json` while you are learning the system, then remove it once the workflow is stable:

```json
{ "env": { "CLAUDE_CODE_SUBAGENT_MODEL": "sonnet", "MAX_THINKING_TOKENS": "8000" } }
```

Note: this override forces **every** subagent onto Sonnet, including `critic`. Remove it before running a plan critique on Opus, or invoke `critic` from a session where the variable is unset.

## 2.3 Cost discipline the user must follow

- `/clear` between unrelated tasks. Full conversation history is re-sent on every request; a long session is the single largest avoidable cost.
- `/rename` before clearing so the session is findable with `/resume`.
- Check `/usage` after the first complete feature. That number, as a percentage of the weekly bar, is your features-per-week budget.
- Start plan-mode work right after a 5-hour window resets, not at the end of one.

---

# 3. Target layout

```
CLAUDE.md                       # < 150 lines
.claude/
├── settings.json               # hooks, permissions, env  (committed)
├── settings.local.json         # personal               (gitignored)
├── agents/                     # 7 files
│   ├── planner.md
│   ├── critic.md
│   ├── test-designer.md
│   ├── implementer.md
│   ├── reviewer.md
│   ├── qa-runner.md
│   └── doc-writer.md
├── skills/
│   ├── feature/SKILL.md        # the phase router — runs in main session
│   ├── handoff/SKILL.md
│   ├── codebase-map/SKILL.md
│   ├── web-audit/SKILL.md      # omit if no UI
│   └── report/SKILL.md
├── rules/
│   ├── backend.md
│   ├── frontend.md             # omit if no UI
│   ├── testing.md
│   └── security.md
├── hooks/
│   ├── gate-check.sh
│   ├── filter-output.sh
│   ├── post-edit.sh
│   └── doc-check.sh
├── agent-memory/               # COMMITTED — this is the institutional memory
└── state/gate.json
docs/
├── setup/                      # PROFILE.md, SETUP-SPEC.md, CHECKLIST.md
├── adr/
├── specs/<slug>/               # idea+plan.md, critique.md, acceptance.md,
│                               # verification.md, evidence/
├── handoff/
└── reports/
```

**Design note.** The full version of this system uses 24 agents and a `conductor` subagent. This spec merges idea+plan into `planner`, merges all implementation into one `implementer` (discipline knowledge comes from path-scoped rules, not from separate agents), merges code review and security into `reviewer`, and moves orchestration into the main session as a skill. That is seven context windows instead of twenty-five, with most of the quality retained.

---

# 4. Phase 1 — Foundation

## 4.1 Scaffold

```bash
mkdir -p .claude/{agents,skills,rules,hooks,state,agent-memory}
mkdir -p docs/{setup,adr,specs,handoff,reports}
echo '{"phase":"idle","feature":null,"approved":[]}' > .claude/state/gate.json
printf '%s\n' 'CLAUDE.local.md' '.claude/settings.local.json' >> .gitignore
```

## 4.2 CLAUDE.md

Run `/init` first to generate a draft (set `CLAUDE_CODE_NEW_INIT=1` for the interactive flow), then **cut it down** to this shape. Delete anything Claude can rediscover from the code — directory listings, dependency lists, architecture narration. Keep pitfalls, rationale, and conventions that differ from tool defaults.

```markdown
# <Project name>

<one line: stack>

## Commands
- Dev: <...>
- Test: <...>          Single test: <...>
- Lint: <...>          Types: <...>
- Build: <...>

## Layout
- <source root>: <one line>
- <frontend root>: <one line>
- Specs and decisions: docs/specs/, docs/adr/

## Non-negotiables
- No source edits before an approved plan exists at docs/specs/<slug>/plan.md.
  Check .claude/state/gate.json.
- Every bug fix starts with a failing test.
- Every schema change ships a reversible migration and a test.
- No raw colour, spacing, radius or font-size values in components — use tokens.
- Never edit .env, vendor/, node_modules/, or build output.

## Working agreement
- Start any feature with /feature <description>.
- Run /handoff before ending a session with uncommitted work.
- Use /clear between unrelated tasks.

## Compact instructions
When compacting, preserve: the gate state, decisions made this session, and
file paths already discovered. Discard tool output and exploration transcripts.
```

## 4.3 Rules

Path-scoped rules cost **zero tokens** until a matching file is read. This is where discipline knowledge lives, and it is why this spec needs only one implementer agent.

```markdown
<!-- .claude/rules/frontend.md -->
---
paths:
  - "<frontend root>/**/*.{js,ts,jsx,tsx,vue,svelte}"
  - "<frontend root>/**/*.css"
---

# Front-end standards

**Tokens.** Colour, spacing, radius, shadow and type scale come from the token
file. A literal hex, px or rem in a component is a review blocker.

**States.** Every interactive element implements default, hover, focus-visible,
active, disabled, loading and error. Every collection implements empty and error.

**Responsive.** Breakpoints 390 / 768 / 1024 / 1280 / 1536. Mobile is a designed
layout, not a narrowed desktop. No horizontal scroll at 320px. Touch targets
at least 44×44px.

**Accessibility.** WCAG 2.2 AA. Semantic HTML before ARIA. Visible focus
everywhere. Contrast 4.5:1 body, 3:1 large text and UI boundaries. All motion
respects prefers-reduced-motion.

**Performance.** LCP ≤ 2.5s, INP ≤ 200ms, CLS ≤ 0.1 on a mid-tier mobile
profile. Images get explicit dimensions, modern formats, lazy below the fold.

**SEO.** One h1 per page with correct heading order. Title and meta description
per route. Canonical URL. Open Graph tags. JSON-LD where the page type warrants
it. Navigation crawlable without JavaScript.
```

Write `backend.md` (error handling, validation at the boundary, no business logic in controllers, transaction boundaries, N+1 avoidance, logging without PII), `testing.md` (unit/integration/E2E split, naming, fixtures, no network in unit tests, coverage expectations), and `security.md` (authz checked at every entry point, parameterised queries only, secrets from env only, output encoding, dependency policy). Keep each under 60 lines.

## 4.4 Verify

Run `/context`. CLAUDE.md plus always-on rules should be a small single-digit percentage of the window. If not, cut now.

---

# 5. Phase 2 — The seven agents

## 5.1 `planner`

```markdown
---
name: planner
description: Turns a request into a scoped problem statement and an executable implementation plan. Use at the start of any feature or non-trivial change.
tools: Read, Grep, Glob, Write, Edit
disallowedTools: Bash
model: sonnet
memory: project
color: blue
---

You produce a plan another engineer could execute without asking a question.
You never write implementation code.

Write `docs/specs/<slug>/plan.md`:

- **Problem** — what is wrong or missing, and for whom. Three sentences.
- **Out of scope** — explicit. This is what stops the diff growing later.
- **Acceptance criteria** — numbered, in the form "when X, the system shall Y".
  Each must be observable by a test. If you cannot state how it is observed,
  it is not a criterion.
- **Approach** — the chosen design, 5–10 sentences.
- **Alternatives rejected** — at least one, with the reason it lost. A plan
  with no rejected alternative has been asserted, not designed.
- **File map** — every file to create or modify.
- **Data changes** — schema deltas and migration order.
- **Risks and rollback** — what breaks if this is wrong.

If the plan needs more than ~12 files changed, split it into two features and
say so. If the request is ambiguous, ask rather than assume.

Update your memory with architectural patterns and past decisions you find.
```

## 5.2 `critic` — the only Opus agent

```markdown
---
name: critic
description: Adversarially reviews a plan before implementation. Use once per feature at the plan gate, before any code is written.
tools: Read, Grep, Glob, Write
model: opus
memory: project
color: red
---

Find the reason this plan fails. You are not here to be balanced and not here
to approve. Assume it is wrong and work out how.

Write `docs/specs/<slug>/critique.md` with findings ranked
BLOCKER / MAJOR / MINOR. Each finding: the claim being attacked, the concrete
failure scenario, and the cheapest fix.

Check specifically:
- Unstated assumptions about volume, concurrency, or user behaviour
- Failure modes: partial writes, retries, timeouts, offline, clock skew
- Authorisation designed only for the happy path
- Migrations that are irreversible or unsafe under live traffic
- Acceptance criteria that cannot actually be observed
- A materially simpler design that gets 90% of the value

End with one line: the single change most likely to prevent an incident.
If you find nothing above MINOR, say so plainly. A manufactured BLOCKER is
worse than none.
```

**Budget rule:** exactly one `critic` run per feature. If the plan changes materially after the critique, re-run it — but that should be rare, and it is a signal the plan phase was rushed.

## 5.3 `test-designer`

```markdown
---
name: test-designer
description: Writes failing tests from approved acceptance criteria, before implementation exists. Use in the TEST phase.
tools: Read, Grep, Glob, Write, Edit, Bash
model: sonnet
memory: project
color: yellow
---

Read the approved plan. For each numbered acceptance criterion, write a test
that fails today for the right reason.

1. Choose the level per criterion: unit for logic, integration for boundaries,
   E2E only for the critical user path. Do not write an E2E test for something
   a unit test can prove.
2. Write the tests. Follow the conventions in .claude/rules/testing.md.
3. Run the suite. Capture output to docs/specs/<slug>/evidence/tests-red.txt.
4. Confirm each new test fails because the feature is missing — not because
   of a typo, a missing import, or a bad fixture. State this explicitly.

Report the criterion-to-test mapping as a table. Do not implement anything.

Record fixture locations and flaky tests in your memory.
```

## 5.4 `implementer`

```markdown
---
name: implementer
description: Implements an approved plan against failing tests. Use in the CREATE phase for all code changes.
tools: Read, Grep, Glob, Write, Edit, Bash
model: sonnet
memory: project
color: cyan
---

Implement only what the plan's file map names. If the plan is ambiguous, stop
and ask; do not invent scope.

Loop: implement the smallest slice that turns one red test green, run that
single test, move on. Do not run the full suite after every edit.

Rules that apply to every change:
- The path-scoped rules in .claude/rules/ apply automatically to the files you
  touch. Follow them.
- No new dependency without saying so and why.
- No change outside the plan's file map. If you believe one is needed, stop
  and report it.

When all tests pass, run the full suite once and capture to
docs/specs/<slug>/evidence/tests-green.txt. Report the diff summary: files
touched, lines added and removed, and anything you did that the plan did not
anticipate.

Record code paths, conventions and gotchas you discover in your memory.
```

## 5.5 `reviewer`

```markdown
---
name: reviewer
description: Reviews a diff for correctness, security, and standards conformance. Read-only. Use in the VERIFY phase.
tools: Read, Grep, Glob, Bash
disallowedTools: Write, Edit
model: sonnet
memory: project
color: orange
---

Review the current diff. You cannot modify files.

Start with `git diff HEAD`, then read the plan and the acceptance criteria.

Report findings ranked BLOCKER / MAJOR / MINOR, each with a `file:line`
citation and a concrete fix. Cover, in this order:

1. **Correctness** — does it satisfy each acceptance criterion? Name the
   criterion number for each.
2. **Security** — authorisation at every new entry point; input validated at
   the boundary; parameterised queries; no secret in the diff; no PII in logs;
   output encoded; new dependencies checked.
3. **Contract drift** — does the implementation match the plan's file map and
   interfaces? Anything extra is a finding.
4. **Quality** — error handling, duplication, naming, dead code.
5. **Standards** — conformance to the relevant .claude/rules/ file.

Write docs/specs/<slug>/verification.md. Do not fix anything.

Record recurring defect patterns in your memory. A pattern you have now seen
three times should be proposed as a new rule.
```

## 5.6 `qa-runner`

```markdown
---
name: qa-runner
description: Executes tests and drives a real browser to capture evidence. Use in the VERIFY phase for anything with a UI.
tools: Read, Grep, Glob, Bash, Write
model: sonnet
memory: local
mcpServers:
  - playwright:
      type: stdio
      command: npx
      args: ["-y", "@playwright/mcp@latest"]
color: green
---

Run the suite, then verify in a real browser. Return only failures plus
evidence paths. Never paste full suite output into your report.

1. Run the test command; capture to docs/specs/<slug>/evidence/.
2. Start the app; drive the changed flows.
3. Screenshot at 390, 768, 1280, 1920 into evidence/shots/.
4. Tab through every new interactive element; confirm visible focus.
5. Trigger loading, empty and error states; screenshot each.
6. Capture console errors and failed network requests.

Prefer accessibility-tree snapshots over screenshots for assertions — they are
a fraction of the size. Use screenshots for the visual record only.

Report: pass/fail counts, each failure with assertion and file:line, console
errors, evidence paths. Nothing else.

Record the launch recipe that worked and any flaky tests in your memory.
```

The inline `mcpServers` block is deliberate: it keeps Playwright's tool definitions out of your main session entirely, which is worth several thousand tokens per session on Pro.

## 5.7 `doc-writer`

```markdown
---
name: doc-writer
description: Updates documentation, ADRs and the handoff note after a feature closes. Use in the DOCUMENT phase.
tools: Read, Grep, Glob, Write, Edit, Bash
model: sonnet
memory: project
color: purple
---

Update documentation to match what was actually built, not what was planned.

1. Read the plan, the critique, the verification report and the diff.
2. Update or create the affected docs under docs/. Do not create a new file
   where an existing one should be edited.
3. Write one ADR per decision that is expensive to reverse, using the format
   in docs/adr/TEMPLATE.md. Most features need zero or one.
4. Append to the changelog.
5. Write docs/handoff/<date>-<slug>.md.

Be brief. A doc nobody reads is a doc that failed. Prefer editing three
sentences over adding three paragraphs.
```

---

# 6. Phase 3 — Skills

Skills load on demand and cost roughly a name and description at session start. This is where the process lives.

## 6.1 `/feature` — the phase router

This runs in your **main session**, not a subagent. That is the single biggest Pro-plan saving in this design.

```markdown
<!-- .claude/skills/feature/SKILL.md -->
---
description: Runs a change through the Idea → Plan → Test → Create → Verify → Document pipeline, one gate at a time. Use to start any feature, bug fix, or non-trivial change.
disable-model-invocation: true
argument-hint: [description of the change]
allowed-tools: Bash(git status *) Bash(git diff *) Bash(cat .claude/state/gate.json)
---

Feature: $ARGUMENTS

Current gate: !`cat .claude/state/gate.json 2>/dev/null || echo '{"phase":"idle"}'`
Working tree: !`git status --short`

## Protocol

Run **exactly one phase per turn**, then stop and report which gate needs my
approval. Never skip forward. Never combine phases.

| Phase | Agent | Required artifact before the gate closes |
|---|---|---|
| 1 · idea+plan | `planner` | `docs/specs/<slug>/plan.md` |
| 2 · critique | `critic` | `docs/specs/<slug>/critique.md`, every BLOCKER and MAJOR resolved or explicitly accepted |
| 3 · test | `test-designer` | `evidence/tests-red.txt` showing the new tests failing correctly |
| 4 · create | `implementer` | `evidence/tests-green.txt` |
| 5 · verify | `reviewer`, then `qa-runner` if there is a UI | `verification.md`, zero BLOCKERs |
| 6 · document | `doc-writer` | updated docs + `docs/handoff/<date>-<slug>.md` |

## Delegation briefing template

Subagents start with an empty context and cannot see this conversation. Every
delegation must include:

    TASK: <one imperative sentence>
    SPEC: docs/specs/<slug>/plan.md — read this first
    SCOPE: you may modify only <explicit paths>
    CONTEXT YOU NEED: <3–6 bullets, including file paths already discovered>
    DONE MEANS: <the artifact path that must exist>
    DO NOT: <2–3 things that would make this a rejected result>

The CONTEXT line matters most. Every file path you hand over is a search the
subagent does not have to run.

## Gate discipline

- A summary in chat is not an artifact. Verify the file exists and is
  non-empty before advancing.
- After updating the gate, tell me to run `/clear` before the next phase if
  context is above 50%.
- If an agent reports completion without its artifact, reject and re-dispatch
  naming the missing file.
- Run `critic` **once** per feature. Re-running it is a signal the plan phase
  was rushed.
- Findings that become work re-enter at phase 3, not phase 4. A bug fix gets a
  failing test first.
```

## 6.2 `/handoff`

```markdown
---
description: Writes an end-of-session handoff note capturing state, decisions and next actions. Use before ending a session with uncommitted work.
disable-model-invocation: true
allowed-tools: Bash(git status *) Bash(git diff *) Bash(git log *)
---

- Branch: !`git branch --show-current`
- Uncommitted: !`git status --short`
- Recent: !`git log --oneline -10`
- Gate: !`cat .claude/state/gate.json 2>/dev/null`

Write `docs/handoff/<today>-<slug>.md`:

1. **State** — phase, what is done, what is in progress.
2. **Decisions this session** — each with its reason.
3. **Rejected approaches** — and why. Highest-value section; without it the
   next session re-litigates settled questions.
4. **Open questions** — with who should answer each.
5. **Next actions** — ordered, each with the file path it touches.
6. **Landmines** — anything surprising found in the codebase.

Under 300 words per section. Then append durable lessons to the relevant
agent memories.
```

The `` !`command` `` syntax runs the shell command before Claude sees the skill, so git state arrives already inlined — no tool call spent fetching it.

## 6.3 `/codebase-map`

A single skill describing architecture, key directories and naming conventions. Generated in Phase 6 from the memory-seeding passes. It replaces an exploration pass in every session that invokes it, which is one of the cheapest recurring savings available.

## 6.4 `/web-audit` (omit if no UI)

```markdown
---
description: Runs a performance, accessibility and SEO audit against the running app. Use before closing the verify phase on UI work.
disable-model-invocation: true
---

Audit the current build. Report findings only — do not fix.

**Performance** — LCP, INP, CLS from a cold load on a mid-tier mobile profile
against the budget in .claude/rules/frontend.md. Largest bundles. Unoptimised
images. Render-blocking resources.

**Accessibility** — run axe. Keyboard traversal of every interactive element.
Focus visibility. Contrast. Heading order. Form labels. prefers-reduced-motion.

**SEO** — title and meta description per route with length bounds. One h1,
correct heading order. Canonical. Open Graph. JSON-LD. sitemap.xml, robots.txt.
Image alt text. Navigation crawlable without JavaScript.

**Responsive** — 320, 390, 768, 1024, 1280, 1536. No horizontal overflow.
Touch targets ≥ 44px.

Output a table: check, status, evidence, fix. Rank failures by user impact.
```

## 6.5 `/report`

```markdown
---
description: Generates the monthly codebase and documentation health report. Use at month end.
disable-model-invocation: true
allowed-tools: Bash(python3 ${CLAUDE_SKILL_DIR}/scripts/*) Bash(git *)
---

1. Run `python3 ${CLAUDE_SKILL_DIR}/scripts/audit.py . docs/reports/<month>/`
2. Read the JSON output and write docs/reports/<month>/SUMMARY.md:
   - **Codebase** — size, module breakdown, files that are both large and
     heavily churned (that intersection is where defects concentrate).
   - **Docs** — coverage, stale list ranked by risk, specs closed without a
     verification file.
   - **Tokens** — from `/usage`, which the user pastes in. Report weekly
     consumption, the three largest consumers, and features completed.
     Compute tokens per completed feature.
   - **Recommendations** — at most five, each with the number behind it.

Interpret, do not restate. Separate what you **measured** from what you
**estimated**, and label each. Never assert a saving you cannot show the
mechanism for.
```

---

# 7. Phase 4 — Hooks

Prompts are advisory; hooks are deterministic. These four are what make the pipeline real. **Adapt every path and command to the Project Profile before writing them.**

## 7.1 Gate check — blocks code before an approved plan

```bash
#!/bin/bash
# .claude/hooks/gate-check.sh
INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
[ -z "$FILE" ] && exit 0

# Always writable: docs, config, tests, markdown
case "$FILE" in
  *docs/*|*.claude/*|*test*|*Test*|*spec*|*.md) exit 0 ;;
esac

GATE=".claude/state/gate.json"
[ -f "$GATE" ] || { echo "BLOCKED: no active gate. Start with /feature." >&2; exit 2; }

PHASE=$(jq -r '.phase' "$GATE")
case "$PHASE" in
  create|verify) exit 0 ;;
  *) echo "BLOCKED: phase is '$PHASE'. Source edits are only allowed in 'create'." >&2
     echo "Complete the plan and test phases first." >&2
     exit 2 ;;
esac
```

## 7.2 Output filter — the highest-value token saving here

Rewrites test commands so only failures return. Tens of thousands of tokens become hundreds. **Replace the command pattern with the real test command from the profile.**

```bash
#!/bin/bash
# .claude/hooks/filter-output.sh
INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command')

if [[ "$CMD" =~ ^(<YOUR TEST COMMAND>|<YOUR BUILD COMMAND>) ]]; then
  NEW="$CMD 2>&1 | grep -B2 -A8 -iE '(FAIL|ERROR|✕|✗|assert)' | head -150"
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","updatedInput":{"command":"%s"}}}' "$(echo "$NEW" | sed 's/"/\\"/g')"
  exit 0
fi
echo '{}'
```

Verify with `claude --debug`: the log shows `modified tool input keys: [command]` when a hook rewrites a command.

## 7.3 Post-edit — catch errors in the same turn

```bash
#!/bin/bash
# .claude/hooks/post-edit.sh
INPUT=$(cat); FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
case "$FILE" in
  *.ts|*.tsx) <FORMAT CMD> "$FILE" 2>/dev/null
              <TYPECHECK CMD> 2>&1 | grep "$FILE" | head -20 ;;
  *.js|*.jsx) <FORMAT CMD> "$FILE" 2>/dev/null ;;
  # add cases per the project profile
esac
exit 0
```

## 7.4 Doc check — makes documentation a gate, not a hope

```bash
#!/bin/bash
# .claude/hooks/doc-check.sh
CHANGED=$(git diff --name-only HEAD 2>/dev/null | grep -E '^(<SOURCE ROOTS>)/' || true)
[ -z "$CHANGED" ] && exit 0
if [ -z "$(git status --short docs/ 2>/dev/null)" ]; then
  echo "Source changed but docs/ did not. Run /handoff, or state why no doc change is needed." >&2
  exit 2
fi
exit 0
```

## 7.5 Wiring

```json
// .claude/settings.json
{
  "env": {
    "CLAUDE_CODE_SUBAGENT_MODEL": "sonnet",
    "MAX_THINKING_TOKENS": "8000"
  },
  "permissions": {
    "deny": [
      "Read(./.env)", "Read(./.env.*)", "Read(./**/*.pem)", "Read(./**/*.key)",
      "Write(./.env)", "Write(./vendor/**)", "Write(./node_modules/**)",
      "Bash(rm -rf *)", "Bash(git push --force*)"
    ],
    "allow": [
      "Bash(git status*)", "Bash(git diff*)", "Bash(git log*)"
    ]
  },
  "hooks": {
    "PreToolUse": [
      { "matcher": "Edit|Write", "hooks": [{ "type": "command", "command": ".claude/hooks/gate-check.sh" }] },
      { "matcher": "Bash",       "hooks": [{ "type": "command", "command": ".claude/hooks/filter-output.sh" }] }
    ],
    "PostToolUse": [
      { "matcher": "Edit|Write", "hooks": [{ "type": "command", "command": ".claude/hooks/post-edit.sh" }] }
    ],
    "Stop": [
      { "hooks": [{ "type": "command", "command": ".claude/hooks/doc-check.sh" }] }
    ]
  }
}
```

```bash
chmod +x .claude/hooks/*.sh
```

A non-executable hook fails rather than blocking. Confirm registration with `/hooks`.

## 7.6 Mandatory hook tests

Claude: run each of these and show the user the result.

| Test | Expected |
|---|---|
| Edit a source file while gate phase is `idle` | Blocked with the gate message |
| Create `docs/specs/tmp/idea.md` | Allowed |
| Run the test command | Only failures returned, not full output |
| Edit a source file with a type error | Type-check output appears in the same turn |
| End a session with source changed and docs untouched | Stop hook message appears |

Then delete the temporary files.

---

# 8. Phase 5 — Extensions

Keep this list exactly as written. Every addition has a standing cost.

## 8.1 Plugins

```bash
/plugin marketplace add anthropics/claude-plugins-official
/plugin install security-guidance@claude-plugins-official
/plugin install <language>-lsp@claude-plugins-official
/reload-plugins
```

- **`security-guidance`** — reviews each change Claude makes for common vulnerabilities and has it fix them in the same session. This catches a class of defect before your verify phase, which makes it a token *saving*, not a cost.
- **Code intelligence (LSP)** — the biggest per-session saving in this list. It replaces grep-plus-read-three-files with one "go to definition", and reports type errors automatically after every edit. **Install the language server binary yourself first**; the plugin does not do it. Check `/plugin` → Errors if it does not start.

If the project has a UI:

```bash
claude plugin add anthropic/frontend-design
```

This makes Claude commit to a deliberate aesthetic direction before writing code instead of defaulting to the generic AI-generated look. Then add a five-line theme block to CLAUDE.md so it applies in every session:

```markdown
## Frontend theme
<always_use_<name>_theme>
Always design with a <name> aesthetic:
- <palette direction>
- <typography direction>
- <layout and density direction>
- <motion direction>
</always_use_<name>_theme>
```

If the project has a framework-native MCP server (for example Laravel Boost), install it — it reads your live application rather than your files, which is strictly cheaper than exploration.

## 8.2 MCP servers

**Always on — two maximum:**

```bash
claude mcp add context7 -s user -- npx -y @upstash/context7-mcp@latest
```

Context7 is small, on-demand, and prevents wrong API signatures on unfamiliar library versions. Add the framework-native server as the second if you have one.

**Scoped to one agent, never in `.mcp.json`:** Playwright, already declared in `qa-runner`'s frontmatter.

**Do not install on Pro:** Chrome DevTools MCP, Figma MCP, filesystem MCP (redundant with built-in file tools), or any general-purpose "do everything" server.

## 8.3 Budget check

```bash
/context     # pre-prompt total should be under ~12% of the window
/mcp         # disable anything not in daily use
/doctor      # duplicate agent names, oversized CLAUDE.md, skill listing overflow
```

If `/context` is over budget, cut in this order: MCP servers, then skills, then CLAUDE.md.

---

# 9. Phase 6 — Memory seeding

This is what makes the pipeline improve instead of restarting from zero every week. `memory: project` writes to `.claude/agent-memory/<name>/`, which is **committed to git** — unlike auto memory, which is machine-local and never reaches a subagent.

Run these three read-only passes, one per session:

```
Use the planner agent to survey this codebase's architecture: module
boundaries, the layering convention actually in use, where business logic
lives, and the three most significant design decisions visible in the code.
Write findings to your agent memory. Modify no file.
```

```
Use the reviewer agent to survey this codebase for recurring quality and
security patterns: the error-handling convention, how authorisation is
checked, where validation happens, and the three defect patterns most likely
to recur. Write findings to your agent memory. Modify no file.
```

```
Use the implementer agent to survey conventions: naming, file organisation,
the testing style in use, the utility modules that already exist, and the
three places where new code most often needs to touch existing code.
Write findings to your agent memory. Modify no file.
```

Then build `/codebase-map` from what those three found, and commit `.claude/agent-memory/`.

**Maintenance.** Each agent's prompt already tells it to update its memory as it works. Monthly, ask it to prune: delete entries about code that no longer exists, merge duplicates, and promote anything rediscovered three times into a rule file. A lesson relearned three times is a missing rule, not a memory.

Note the hard limit: only the first 200 lines or 25KB of each memory index loads. Keep one line per entry and push detail into topic files.

---

# 10. Phase 7 — Reporting

One script, run monthly. **Do the counting in the script, not in the model** — walking the tree costs zero tokens; asking Claude to read every file costs a fortune.

```python
#!/usr/bin/env python3
# .claude/skills/report/scripts/audit.py
import json, subprocess, sys
from pathlib import Path
from collections import Counter, defaultdict

IGNORE = {'.git','node_modules','vendor','dist','build','__pycache__','.venv','.next'}
CODE   = {'.php','.js','.ts','.tsx','.jsx','.vue','.py','.go','.rs','.css'}
DOC_MAP = {            # ADAPT: source area -> the doc that describes it
    '<source root>':   'docs/architecture.md',
    '<frontend root>': 'docs/design/components.md',
}

def epoch(root, rel):
    r = subprocess.run(['git','-C',str(root),'log','-1','--format=%ct','--',rel],
                       capture_output=True, text=True)
    try: return int(r.stdout.strip())
    except ValueError: return 0

root = Path(sys.argv[1]).resolve()
out  = Path(sys.argv[2]); out.mkdir(parents=True, exist_ok=True)

files, by_dir = [], defaultdict(lambda: {'files': 0, 'lines': 0})
for p in root.rglob('*'):
    if not p.is_file() or p.suffix.lower() not in CODE: continue
    if any(part in IGNORE for part in p.parts): continue
    try: lines = sum(1 for _ in p.open('r', errors='ignore'))
    except OSError: continue
    rel = p.relative_to(root)
    top = rel.parts[0] if len(rel.parts) > 1 else '(root)'
    files.append({'path': str(rel), 'lines': lines})
    by_dir[top]['files'] += 1; by_dir[top]['lines'] += lines

churn = subprocess.run(['git','-C',str(root),'log','--since=1 month ago',
                        '--name-only','--pretty=format:'],
                       capture_output=True, text=True).stdout
churn = dict(Counter(l for l in churn.splitlines() if l.strip()).most_common(20))

stale, missing = [], []
for area, doc in DOC_MAP.items():
    if not (root/area).exists(): continue
    if not (root/doc).exists(): missing.append({'area': area, 'doc': doc}); continue
    ct, dt = epoch(root, area), epoch(root, doc)
    if ct > dt: stale.append({'doc': doc, 'days_behind': round((ct-dt)/86400, 1)})

specs = [s for s in (root/'docs'/'specs').glob('*') if s.is_dir()] \
        if (root/'docs'/'specs').exists() else []

report = {
  'totals': {'files': len(files), 'lines': sum(f['lines'] for f in files)},
  'by_module': dict(sorted(by_dir.items(), key=lambda x: -x[1]['lines'])),
  'largest': sorted(files, key=lambda f: -f['lines'])[:20],
  'most_churned': churn,
  'stale_docs': sorted(stale, key=lambda d: -d['days_behind']),
  'missing_docs': missing,
  'specs': len(specs),
  'specs_without_verification': [s.name for s in specs if not (s/'verification.md').exists()],
}
(out/'audit.json').write_text(json.dumps(report, indent=2))
print(f"{report['totals']['files']} files, {report['totals']['lines']:,} lines · "
      f"{len(stale)} stale docs · {len(report['specs_without_verification'])} unverified specs")
```

For the token half of the report, run `/usage` and paste the output — it attributes recent usage to skills, subagents, plugins and MCP servers, and flags behaviours like long context or cache misses when they account for 10% or more. Press `d` or `w` to switch between 24-hour and 7-day windows.

The metric to track is **tokens per completed feature**, not tokens per day. Tokens per day rewards doing less work.

---

# 11. Daily operating loop

```
/clear                          # start clean
/feature add invoice CSV export # phase 1 → planner writes plan.md
                                # you read it and approve
run the critique phase          # phase 2 → critic (opus, once)
                                # resolve blockers, approve
/clear                          # context reset before the long phases
run the test phase              # phase 3 → red tests + evidence
run the create phase            # phase 4 → green tests + evidence
/clear
run the verify phase            # phase 5 → reviewer, then qa-runner
/web-audit                      # UI work only
run the document phase          # phase 6 → docs + handoff
/handoff
```

Three `/clear` calls per feature is not excessive — it is the difference between a feature costing one context window and costing four.

---

# 12. Token budget card

Pin this where you can see it.

| Rule | |
|---|---|
| `/clear` between phases and between unrelated tasks | The largest single saving available |
| Never leave a session open across a long break | The first message after the cache lifetime reprocesses everything |
| Opus once per feature, at the plan gate only | Opus and Sonnet share one pool on Pro |
| Two verify agents maximum, run sequentially | Each returns a full result into main context |
| Brief subagents with file paths | 400 tokens of paths saves thousands of searching |
| Plan mode before anything large | Prevents the most expensive failure: building the wrong thing |
| Full test suite once per phase, not per edit | Single-test runs during the create loop |
| No agent teams, no workflows, no `ultracode` | 7× and worse |
| `/usage` after every feature | The only way to know your real budget |

**Escalation trigger.** If one medium feature costs more than ~10% of your weekly bar, cut in this order: (1) drop `qa-runner` to the critical path only, (2) run `critic` on Sonnet and accept a weaker critique, (3) merge the verify and document phases. Do **not** cut the gates themselves — they are nearly free and they are what makes the output trustworthy.

---

# 13. Acceptance checklist

Setup is complete when every line is true. Claude: verify each and report.

| # | Check | How |
|---|---|---|
| 1 | `docs/setup/PROFILE.md` filled and accurate | Read it |
| 2 | CLAUDE.md under 150 lines | `wc -l CLAUDE.md` |
| 3 | Four rule files with correct `paths:` globs | Open one, confirm it loads when a matching file is read |
| 4 | Seven agents, each with correct `model` and `memory` | `/doctor` reports no duplicates |
| 5 | Five skills, side-effect ones set `disable-model-invocation: true` | Type `/` and confirm the list |
| 6 | Four hooks executable and registered | `/hooks` |
| 7 | All five hook tests pass | §7.6 |
| 8 | Two or fewer always-on MCP servers | `/mcp` |
| 9 | `/context` pre-prompt under ~12% | `/context` |
| 10 | Three memory-seeding passes done and committed | `git log .claude/agent-memory/` |
| 11 | `/report` runs end to end | Run it |
| 12 | One pilot feature through all six gates | Every artifact file exists in `docs/specs/<slug>/` |
| 13 | `/usage` recorded after the pilot | Write it to `docs/reports/baseline.md` |

**Do not skip 12 and 13.** A pipeline that has never carried a real feature is a folder of untested config, and without the baseline in 13 you cannot tell later whether any change you make is an improvement.

---

# 14. What to add later, and only later

Once the pipeline has carried five or six features and you know your real budget:

- Split `implementer` into frontend and backend specialists — only if you observe it applying the wrong rules.
- Add a `data-architect` — only if schema work is a recurring bottleneck.
- Add a second proposal agent and a judge for two-way debate — only on decisions you have already regretted once.
- Add Chrome DevTools MCP for performance profiling — only if the `/web-audit` skill is not giving you enough.
- Move up a plan tier — only when `/usage` shows you hitting the weekly cap on work you actually needed to do, not on work the pipeline wasted.

Each of these is a real improvement and each has a real cost. Add them one at a time, and measure with `/usage` before and after. Anything you cannot show a measured benefit for should come back out.
