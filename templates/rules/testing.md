---
paths:
  - "{{TEST_GLOB}}"
---

# Testing standards

**Level.** Unit for logic and branches. Integration for boundaries — database,
HTTP, queue. End-to-end only for the critical user path. Do not write an E2E
test for something a unit test can prove.

**Naming.** Test names state the behaviour, not the method: "rejects an
expired token", not "testValidate".

**Isolation.** No network in unit tests. No shared mutable state between
tests. Each test builds and tears down its own fixtures.

**Assertions.** Assert on behaviour and outputs, not on internal call order.
One logical assertion per test where practical.

**Red first.** Every bug fix begins with a test that fails for the reported
reason. Every acceptance criterion has a test that failed before the feature
existed.

**Coverage.** Coverage is a smoke detector, not a goal. An untested branch in
auth, money, or data loss paths is a blocker regardless of the percentage.
