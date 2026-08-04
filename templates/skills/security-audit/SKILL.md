---
description: Runs a dependency, secret, and authorisation-pattern sweep against the current diff or the whole repo. Use before closing the verify phase, or any time asked to check for security weak points outside the normal per-feature review.
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash({{DEPENDENCY_AUDIT_COMMAND}} *) Bash(git diff *) Bash(git log *)
---

Audit for security weak points. Report findings only — fix nothing unless asked.

## 1. Dependency and vulnerability scan

Run `{{DEPENDENCY_AUDIT_COMMAND}}` and read the **entire** output, not a
truncated view. Report every high/critical finding with the package, the
installed version, and the fixed version if one exists.

For any finding with no fix available in the current pinned major version
line: state plainly that this is a version-upgrade decision, not something
this audit can resolve, and check whether it is already tracked as known debt
(search `docs/` for the advisory ID) before flagging it as new.

## 2. Secret scan

Grep the diff (or, on a full sweep, the tracked tree) for patterns that look
like committed secrets: private keys, API tokens, connection strings with
embedded credentials, `.env` files that are tracked instead of ignored. A
match in a test fixture using an obviously fake value is not a finding; say
so explicitly rather than staying silent about why it was excluded.

## 3. Authorisation pattern check

Read `.claude/rules/security.md` and `.claude/rules/backend.md` first, then
check the changed code against these two recurring failure classes:

- **Split-source-of-truth authorisation.** If the app has more than one way to
  arrive at "what can this actor do" (a stored role plus a session override, a
  cached permission plus a live one), every authorisation check must go
  through the single resolved value, never a raw field read. A new check
  reading the raw field where a resolver function already exists is a finding.
- **Scope bypass (IDOR).** Any query reachable with a client-supplied ID that
  crosses a tenant/org/team/owner boundary must filter server-side by the
  resolved scope of the requester, not rely on the UI not offering another
  entity's ID. Trace one example query per new endpoint and confirm the scope
  filter is actually applied, not just present elsewhere in the file.

## 4. Static analysis noise check

If a type-checker or static analyzer is configured and uses a baseline file,
confirm new code does not add entries to it (a new finding suppressed into
the baseline is a defect hidden, not fixed) and that the baseline shrank if
this change claims to have fixed a previously baselined issue.

## Report

Findings ranked BLOCKER / MAJOR / MINOR, each with a `file:line` citation
(or the audit's package/advisory ID) and a concrete fix direction. State
explicitly which of the four checks above ran clean versus which found
nothing to check (e.g. no dependency manifest changed) — don't let an
unrun check read as a passed one.
