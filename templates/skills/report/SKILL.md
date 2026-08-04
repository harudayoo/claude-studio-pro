---
description: Generates the monthly codebase and documentation health report. Use at month end or when asked for a project health report.
disable-model-invocation: true
allowed-tools: Bash(python3 ${CLAUDE_SKILL_DIR}/scripts/audit.py *) Bash(git *)
argument-hint: [YYYY-MM]
---

1. Run `python3 ${CLAUDE_SKILL_DIR}/scripts/audit.py . docs/reports/$ARGUMENTS/`
2. Read `audit.json` and write `docs/reports/$ARGUMENTS/SUMMARY.md`:

- **Codebase** — size, module breakdown, and the files that are both large
  and heavily churned. That intersection is where defects concentrate.
- **Docs** — coverage, stale list ranked by risk, specs closed without a
  verification file.
- **Tokens** — from `/usage`, which I will paste in. Report weekly
  consumption, the three largest consumers, features completed, and tokens
  per completed feature against `docs/reports/baseline.md`.
- **Recommendations** — at most five, each with the number behind it.

Interpret, do not restate. Separate what you **measured** from what you
**estimated**, and label each. Never assert a saving you cannot show the
mechanism for.
