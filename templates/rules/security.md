---
paths:
  - "{{BACKEND_GLOB}}"
  - "{{FRONTEND_GLOB}}"
---

# Security standards

**Authorisation.** Checked at every entry point, not only in the UI. A new
route, job, command, or webhook without an explicit authorisation check is a
blocker.

**Input.** Validated and typed at the boundary. Allowlist over denylist.
Never build a query, path, command, or URL from unvalidated input.

**Secrets.** From environment only. Never in source, fixtures, logs, error
messages, or client bundles. Never read or write `.env` from application code.

**Output.** Encoded for its destination — HTML, SQL, shell, URL. Rely on the
framework's escaping; do not disable it for convenience.

**Dependencies.** A new dependency needs a stated reason, a maintenance
check, and a licence check. Prefer the standard library.

**Data.** Classify anything personal. Minimise what is stored. State the
retention period. Redact in logs and in error reporting.
