---
paths:
  - "**/migrations/**"
  - "**/migration/**"
  - "**/models/**"
  - "**/Models/**"
  - "**/entities/**"
  - "**/schema.prisma"
  - "**/schema.rb"
---

# Database standards

**Migrations are reversible.** Every migration has a down path that has been
executed, not just written. A migration whose reversal is "restore from backup"
is flagged before it ships, never after.

**Expand, migrate, contract.** Renames and drops happen in three deploys, not
one. The previous application version must keep working between each step.
A column dropped in the same deploy that stops writing to it is an outage
waiting for a slow rollout.

**Constraints live in the database.** Foreign keys, uniqueness and not-null are
enforced by the engine, not only by a service method. An invariant enforced only
in application code is one background job away from being violated.

**Nullable is a decision.** Every nullable column states why it can be absent.
Most nullable columns are undesigned rather than optional.

**Indexes serve named queries.** Every index is added alongside the query it
serves. An index with no named query is speculation; a hot query with no index
is an incident. Composite index column order follows the query's filter order.

**N+1 is a defect.** Any relation a list view or loop touches is eager-loaded.
This is not a performance nit — it is the difference between one query and one
thousand.

**Backfills are batched and resumable.** They run outside the schema migration,
in bounded chunks, and can be re-run from where they stopped.

**Locking.** State whether a migration takes a lock and for how long, on the
table's real row count — not on the row count in your development database.

**Retention and classification.** Personal data is labelled, has a stated
retention period, and something actually deletes it. A retention policy with no
job behind it is a sentence in a document.

**Money and time.** Money is an integer in minor units or a fixed-point decimal,
never a float. Timestamps are stored in UTC with an explicit type; the display
timezone is a presentation concern.
