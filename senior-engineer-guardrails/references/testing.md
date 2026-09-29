# Testing: AI habits vs senior practice

Measured in 2026: 80.2% of 86,156 agent-written test patches had weak or no
assertions; 50.4% of agent PRs that changed tested code added no tests; 81–86% of
error-handling blocks were untested; and when code was buggy, LLM-written tests
asserted the buggy behaviour. On one benchmark, the gap between visible and
hidden tests grew 28 points per tenfold increase in code size — agents fit the
tests they could see.

## What to test

For every behaviour you change, cover:

- **The happy path** with concrete expected values that come from the
  requirement, not from running the code and copying its output.
- **Authorization:** unauthenticated → 401; another user's/tenant's record →
  404/403.
- **Validation:** missing, malformed, out-of-range and extra fields → 400.
- **Failure of dependencies:** database or upstream error → 5xx (not an empty
  200), and the UI shows an error state, not an empty state.
- **Concurrency and idempotency:** parallel duplicate requests → exactly one
  success; double submit → one record.
- **Boundaries:** empty strings, `null`, zero, max values, time zones and DST,
  locale formatting.

## Assertions that catch bugs

```ts
// AI: passes for almost any implementation
expect(res).toBeDefined();
expect(result.length).toBeGreaterThan(0);
expect(fn).not.toThrow();
```

```ts
// Senior: pins the behaviour the requirement specifies
expect(res.status).toBe(409);
expect(await res.json()).toEqual({ error: 'Email already registered.' });
expect(await countUsers('a@example.com')).toBe(1);
```

- Prefer exact values and full-shape equality over existence checks.
- Assert side effects (rows written, audit entries, emails queued), not just the
  return value.
- Mock only true external boundaries; tests that mock the unit's own
  collaborators mostly test the mocks.
- Coverage is not the goal; a test is useful if it fails when the behaviour
  breaks. Mutation testing on critical modules is a good check.

## Test integrity

- **Never change an assertion to match new behaviour** unless the requirement
  changed and the user agreed. If a test fails after your change, assume your
  change is wrong first.
- Never delete, skip (`.skip`, `xit`), or loosen a test to get green.
- Never special-case test inputs in production code (lookup tables of expected
  outputs, `if (process.env.NODE_ENV === 'test')` branches).
- For end-to-end tests: don't let self-healing tools broaden locators or rewrite
  assertions silently; review those diffs like code.

## Running tests

- Use the non-watch mode (`vitest run`, `jest --ci`, `CI=1`).
- Read the runner's own exit code; don't pipe through `tail`/`head`.
- Integration tests use a throwaway database; never production or real personal
  data.
- Reviewers should read the test diff first: it shows what the change claims.
