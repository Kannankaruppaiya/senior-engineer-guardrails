# Self-review checklist

Run on your own `git diff` before saying "done". Read the **test changes first**,
then the code.

1. **Scope** — Every changed line serves the task. No unrequested refactors,
   renames, formatting churn or new dependencies.
2. **Authorization** — Every new or changed entry point authenticates and checks
   record-level access on the server, like its sibling routes.
3. **Validation** — Inputs parsed with strict schemas on the server; identity
   from the session, never the payload.
4. **Errors** — No catch that returns `[]`/`0`/`null`/defaults or a 200; no
   `e.message`/stack in responses; known errors → 4xx, the rest → 5xx.
5. **Data layer** — Transactions via the shared helper; connections released;
   parameterised SQL with explicit columns; invariants as constraints; no
   check-then-insert; no N+1; forward-only, non-blocking migrations.
6. **Sensitive data** — No personal data or secrets in logs, errors, fixtures,
   client bundles or commits.
7. **Frontend** — `'use client'` only on leaves; no derived state in effects;
   loading/error/empty handled separately; forms keep input on error, map `""` to
   `null`, disable submit while pending; accessible labels and focus.
8. **Types and lint** — No new `any`, unchecked `as`, `!`, `@ts-ignore` or
   disabled rules.
9. **Reuse and cleanup** — Existing helpers reused; replaced code deleted; no
   stray `_v2`/`.bak`/plan/debug files; no leftover logs; no elision
   placeholders.
10. **Tests** — Changed behaviour and its unhappy paths covered with specific
    assertions; nothing weakened, skipped or deleted to pass.
11. **Verified** — `scripts/check.sh` and `scripts/scan-ai-smells.sh` were run
    after the last edit, and the summary reports their real results.
