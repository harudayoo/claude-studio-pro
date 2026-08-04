---
paths:
  - "{{BACKEND_GLOB}}"
---

# Backend standards

**Boundaries.** Controllers and route handlers stay thin: validate, delegate,
respond. Business logic lives in the service/domain layer. No queries in
controllers.

**Validation.** Validate at the boundary, once, with an explicit schema.
Never trust a value that crossed a process or network edge.

**Errors.** One error envelope shape for the whole API. Never leak stack
traces, SQL, or internal paths to a client. Log the cause, return a code.

**Transactions.** Any multi-write operation is transactional. State the
isolation assumption in a comment where it matters.

**Data access.** Parameterised queries only. Eager-load relations that a loop
will touch — an N+1 in a request path is a defect, not a nit.

**Logging.** Structured. No PII, tokens, or secrets in log lines, ever.

**Idempotency.** Anything a client can retry must be safe to retry.
