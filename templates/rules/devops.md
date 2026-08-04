---
paths:
  - ".github/workflows/**"
  - "**/Dockerfile"
  - "**/Dockerfile.*"
  - "docker-compose*.yml"
  - "**/*.tf"
---

# DevOps / DevSecOps standards

**Promotion-aware triggers.** Heavy suites (end-to-end, full matrix builds) run at
protected-branch merge gates, not on every push. Cheap suites (lint, unit, static
analysis) run on every push. Cancel superseded runs on the same ref
(`concurrency: { group: ..., cancel-in-progress: true }`) so minutes are not
spent on commits nobody is waiting on anymore.

**Ephemeral, not shared, infrastructure.** Integration and E2E jobs get their own
service containers (database, cache, queue) scoped to the run, never a shared
persistent environment. A passwordless trust-auth database inside an ephemeral,
localhost-only CI container is acceptable; the same setting anywhere reachable
outside the job is not — state the boundary explicitly if you configure one.

**Dependency and vulnerability scanning.**
- Read the **full** audit output, never a truncated view (`| tail`, `| head` without
  a wide enough count). Table-format audit tools do not reliably sort worst-first;
  truncating can hide a high/critical finding behind a wall of low-severity noise.
- Gate on severity (e.g. `--audit-level=high` / `--audit-level=critical`), not on
  zero findings — a bare "any advisory fails the build" gate trains people to
  suppress the check instead of reading it, on ecosystems where moderate/low
  transitive-dependency advisories are common and frequently false-positive for
  the actual usage.
- A vulnerability with no available fix anywhere in the currently pinned major
  version line is a version-upgrade decision, not something an audit-ignore flag
  resolves. Track it as explicit, named debt (a doc note, a ticket) with the
  advisory ID and the reason it can't be fixed yet. Never add an ignore entry
  just to make a command pass without recording what is being accepted and why.

**Noisy static analysis.** When a type-checker or static analyzer floods
false positives on an existing codebase (e.g. no docblocks/type hints yet, a
partial migration in progress), suppress the existing backlog with a generated
baseline so CI only fails on *new* findings — never by lowering the check level
or disabling the rule. Regenerate the baseline when a baselined finding is
actually fixed, so it shrinks over time instead of becoming permanent cover.

**Secrets.** From the CI provider's secret store only. Never echoed to logs,
never written into a cache key, never baked into an image layer that outlines
its build args. Rotate anything that leaks into a log or a public run.

**Reproducibility.** Package-manager artifacts (vendor/node_modules/etc.) are
cached keyed on the lockfile hash, not restored from an unrelated branch's
cache blindly. Container builds pin base image digests or tags with a stated
update cadence, not floating `latest` in anything that deploys.

**Rollback.** Every deploy or migration job states how to reverse it before it
ships — a workflow with no rollback path is a finding in Verify, not a surprise
in an incident.
