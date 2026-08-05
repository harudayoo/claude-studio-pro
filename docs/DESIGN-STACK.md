---
title: "The design stack"
subtitle: "Which taste skills to add to a studio pipeline, how to adopt them without breaking the gates, and how to tell whether they earned their place."
date: "August 2026"
---

# 0. Why this document exists

This pipeline enforces *that* a design spec exists, *that* it names states and
breakpoints, and *that* the result is verified against a budget. It has no
opinion on whether the design is any good.

That gap is real and it is not closable from inside the repo. `ui-designer`
currently offers a menu — editorial, Swiss minimal, brutalist, glassmorphic —
which is a list of words, not judgement. Third-party design skills supply the
judgement.

They also cost something, and the cost is not obvious. This document is the
decision procedure.

---

# 1. The candidates

| Skill | Supplies | Licence |
|---|---|---|
| [`anthropic/frontend-design`](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/frontend-design) | Committing to an aesthetic direction before code; the baseline | Official |
| [`emilkowalski/skills`](https://github.com/emilkowalski/skills) → `emil-design-eng` | Motion: easing, duration ceilings, what should *not* animate | MIT |
| [`pbakaus/impeccable`](https://github.com/pbakaus/impeccable) | Design-system **enforcement**: 59 deterministic detectors, OKLCH, live in-browser editing | Apache-2.0 |
| [`nextlevelbuilder/ui-ux-pro-max-skill`](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) | Design-system **generation**: searchable style / palette / font-pairing databases | MIT |
| [`nxpatterns/claude-taste-skill`](https://github.com/nxpatterns/claude-taste-skill) | A lighter all-rounder with per-style variants | MIT |

None of these is installed by this repo. Read each manifest before installing;
a skill that ships hooks executes arbitrary code with your privileges.

---

# 2. Take two, then at most one more

**`frontend-design` + `emil-design-eng`.**

These two cover the two things the pipeline is actually missing — a committed
aesthetic direction, and motion — and they overlap almost nothing. They are also
the two lightest listings.

**Then add *either* Impeccable *or* UI-UX Pro Max. Never both.**

| Pick | If you want |
|---|---|
| **Impeccable** | Enforcement. Deterministic detectors, a design vocabulary shared with the model, live editing. Philosophically native to this pipeline: a detector rule is closer to a hook than to a prompt. Costs a hook on every edit — see §5. |
| **UI-UX Pro Max** | Generation. Reference databases and a design-system generator for greenfield work. Its databases are searched by script rather than loaded, which keeps the per-session cost down. |

`taste-skill` is a reasonable substitute for either when you want something
lighter, but it occupies the same slot. It is not a third pick.

## Why not all of them

They contradict each other in ways nothing arbitrates. Concretely: Impeccable
rejects Inter and DM Sans on principle; UI-UX Pro Max ships a 74-entry
font-pairing database that includes them. Load both and the model averages two
aesthetics.

The pipeline has a rule for exactly this shape of problem — *"two agents
disagree → do not average their answers, run `/debate` and let the judge decide
against a written rubric"* — and there is **no judge for skills**. They all land
in the same context with equal authority. The arbitration has to happen at
install time, by you, by not installing both.

---

# 3. Lock the direction above the skills

Before installing anything, fill in the frontend-direction block in `CLAUDE.md`:

```markdown
<!-- studio:frontend-direction:start -->
## Frontend direction
<always_use_this_direction>
Always design with this aesthetic:
- <the direction, named>
- <three to five concrete consequences of it>
</always_use_this_direction>
<!-- studio:frontend-direction:end -->
```

`CLAUDE.md` loads every session, in full, ahead of any skill body. A direction
stated there is the thing every design skill is decorating rather than deciding.
Six lines, and it resolves the font-and-aesthetic conflict **once, structurally**
— instead of per component, forever.

Name a direction the model interprets reliably: editorial, Swiss minimal,
brutalist, glassmorphic, neumorphic, dark OLED luxury, retro-futurist, organic,
art deco, SaaS minimal. Then write the consequences, because the label alone is
not actionable:

```markdown
## Frontend direction
<always_use_this_direction>
Always design with an editorial aesthetic:
- Serif display headlines, generous line height, restrained palette
- Asymmetric magazine grid; content-first hierarchy
- One accent colour used sparingly; no gradients
- Motion is subtle and purposeful; nothing decorative
</always_use_this_direction>
```

`configure.sh` removes this block when your profile says the project has no UI,
so it costs nothing on a service or a library.

---

# 4. Do not touch the gate

`gate-check.sh` blocks writes to your protected source roots outside the
`create` phase. That is the guarantee you installed this pipeline for.

Impeccable's live in-browser editing writes component files directly, so during
PLAN it will be blocked. **This is the gate working, not a bug.** Two correct
resolutions:

1. **Iterate during CREATE.** The gate is already open there. Design exploration
   that produces the real component belongs in the phase where real components
   get written.
2. **Iterate in a sandbox outside the protected roots.** The gate only guards
   the source roots named in `docs/setup/PROFILE.md`. A scratch route — a
   `sandbox/` or `playground/` directory not listed there — is writable in every
   phase, by design. Explore there, then port the result into a real component
   during CREATE.

The wrong resolution is widening `SOURCE_ROOTS_REGEX` or adding an exemption to
the hook. The first time you do that to make a design tool comfortable, the
pipeline stops being able to make its central promise.

Sandbox output is exploration, not a deliverable. Nothing in `sandbox/` ships,
and `code-reviewer` should flag an import that reaches into it from real source.

---

# 5. The token layer is the contract

`.claude/rules/frontend.md` says every visual value comes from `{{TOKEN_FILE}}`
and a raw hex in a component is a review blocker. Every skill here generates its
own colour and type system. These reconcile in exactly one direction:

> **A design skill writes the token layer. Components consume tokens.**

When a skill proposes a palette, a scale or a set of radii, that output lands in
`{{TOKEN_FILE}}` — or in `docs/specs/<slug>/design.md` as a proposed token —
never as a literal in a component. Done this way the two systems reinforce each
other: Impeccable's OKLCH-and-one-hue model *is* what `design-tokens/SKILL.md`
already prescribes.

Done the other way, `code-reviewer` flags the diff, and it is right to.

`verify.sh` does not check this — it is a property of a diff, not of an install.
It is enforced by the rule, at review time, which is where it belongs.

---

# 6. Audit the hooks before you keep one

Impeccable installs hooks that run design detection on file edits. `post-edit.sh`
already runs the formatter and type-checker on every Edit and Write.

Two hooks on the hottest path in the pipeline is a deliberate decision, not a
default. Ask:

- Does design detection need to fire on **every edit**, or at the **VERIFY
  gate**? Correctness feedback is worth interrupting for because it is cheap to
  act on immediately. Design critique usually is not — it is worth more against
  a finished surface than against a half-written component.
- Is the detector's output **filtered**? `filter-output.sh` exists because
  unfiltered tool output is the fourth-largest driver of token cost. A detector
  that writes its full report into context on every edit is exactly that
  problem, reintroduced.

Run `./verify.sh --target .` after installing anything. Its **hook audit**
section reports hooks per event, flags foreign hooks, and warns when more than
one fires on the same event and matcher.

If you decide design detection belongs at VERIFY, move it: remove the entry from
`PreToolUse`/`PostToolUse` in `.claude/settings.json` and invoke the skill's
audit command from the verify phase instead. `install.sh` preserves foreign hook
entries across upgrades, so it will not come back on its own.

---

# 7. Adopt one at a time, and measure

You already own the instrumentation. Use it.

```bash
# 0. Baseline — before anything
#    In Claude Code:  /context      → record the pre-prompt total
#                     /usage        → weekly bar, press w
#    Write both into docs/reports/baseline.md if they are not there already.

# 1. Install exactly ONE skill.

# 2. Immediately:
./verify.sh --target .          # context budget + hook audit
#    In Claude Code:  /doctor    → reports skill-listing overflow
#                     /context   → compare against step 0
```

Then run **one complete feature** through the pipeline and compare:

| Signal | Where | What a regression looks like |
|---|---|---|
| Pre-prompt total | `/context` | Over ~15% of the window, or listing truncation |
| Skill listing | `/doctor` | Any overflow warning at all |
| Tokens per feature | `/usage` vs `docs/reports/baseline.md` | A jump you cannot attribute |
| Verify findings | `verification.md` | More design findings, not fewer |
| Rework | phases re-entered | Design churn moving *into* CREATE |

**The last one is the point.** These skills earn their keep by moving design
decisions *earlier* — into PLAN, where they are cheap. If your verify phase is
still full of design findings after adopting one, it is decorating the output
rather than improving the input, and it should come back out.

## Rolling one back

Uninstalling is a first-class outcome, not a failure:

```bash
rm -rf .claude/skills/<name>
# remove any hook entries it added from .claude/settings.json
./verify.sh --target .
```

`install.sh --uninstall` removes only what the tier manifest listed, so studio
and third-party skills are always separable in both directions.

---

# 8. Per tier

| Tier | Skills already installed | Add | Reasoning |
|---|---|---|---|
| **Pro** | 7 | `frontend-design` | The listing budget is the binding constraint, and one Opus call per feature leaves no room for design debate |
| **Max** | 9 | `frontend-design` + `emil-design-eng` | Two narrow additions sit comfortably |
| **Max 20x** | 14 | those two, **plus at most one** system skill | Already near the listing cap — the third must either displace something or justify itself with `/context` numbers |

Max 20x is the tier where this discipline matters most, which is the opposite of
what the roster size suggests. Twenty-four agents and fourteen skills is already
a large standing cost; the temptation to add five more because the plan can
afford the tokens is precisely the anti-pattern in
[`DESIGN-RATIONALE.md`](DESIGN-RATIONALE.md) §14: *more agents is not more
quality*, and it applies to skills without modification.
