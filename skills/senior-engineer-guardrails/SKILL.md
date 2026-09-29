---
name: senior-engineer-guardrails
description: Makes a coding agent work like a careful senior engineer on full-stack web apps (React/Next.js, Node/TypeScript APIs, SQL/PostgreSQL) and avoid the failure patterns 2026 research measured in AI-written code — missing server-side authorization, silent catch-and-return-default errors, check-then-write races, leaked DB connections, useEffect misuse, forms that lose input or turn "" into 0, 'use client' creep, god components, cloned helpers, stray _v2 files, truncated rewrites, `cmd | tail` hiding failures, destructive git, and unverified "done" claims. Use it for any code change or review in a web app — features, bug fixes, API routes, services, queries, migrations, components, forms, tests, scripts, shell and git work — even when the change looks trivial.
license: MIT
metadata:
  version: "1.0.0"
  evidence-window: "May–September 2026"
---

# Senior engineer guardrails

Research on AI coding agents published between May and September 2026 found a
consistent pattern (sources in `references/evidence.md`). Agents now rarely fail
by writing code that does not compile. They fail by **adding when a senior would
reuse, delete or constrain**, and by skipping the rules nobody wrote down:

- In an audit of 200 deployed AI-built apps, 90% had a vulnerability and 75.5%
  had broken access control, mostly missing server-side checks. In about a
  third of replayed cases the agent noticed the risk and shipped anyway.
- On strict API-contract tests, frontier agents dropped from roughly 90% to
  18–29%; failures were authorization, validation, state and side effects, not
  syntax.
- 80% of agent-written test patches had weak or no assertions; half of agent PRs
  that changed tested code added no tests.
- The costliest incidents were mechanical: whole-file rewrites that dropped code,
  `| tail` hiding a failing check, and `git checkout --` / `reset --hard`
  destroying uncommitted work.

Prompt rules alone decayed over long sessions. What worked was a method plus
mechanical checks. This skill gives both.

## Step 0 — Learn the project's conventions

Before the first change in a repository, spend a minute building a picture of it:

- Read `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md` and any engineering-standards
  doc. If a doc conflicts with what the code clearly does now, follow the code
  and tell the user about the mismatch.
- Identify the **canonical helpers** — how this project authenticates a request,
  checks permissions, validates input, opens a transaction, returns errors,
  formats dates, and builds form fields. Note their file paths. You will reuse
  them instead of writing new ones.
- Note the layering (e.g. route → service → repository) and where SQL is allowed.
- Note the check commands (typecheck, lint, test) from `package.json` or the
  project's docs.

## Step 1 — Before writing code

- **Restate the task and list assumptions.** If a business rule, unit, allowed
  range, permission or field meaning is neither stated nor in the code, ask.
  Agents that guess produce plausible wrong data; a senior asks one question.
- **Read before you edit.** Open the files you will change and their callers.
  Find how the same kind of thing is already done and follow that pattern.
- **Search before you create.** Look for an existing helper or component by
  purpose (`grep -rn "formatDate\|isValid" src lib`). Cloned helpers mean the
  next bug fix lands in only one copy.
- **Plan the smallest change that solves the task.** No unrequested refactors,
  renames, dependencies or "while I'm here" improvements — mention them at the
  end instead.

## Step 2 — While writing code

| Rule | The mistake it prevents |
|---|---|
| Every API route, server action and RPC handler authenticates the caller **and** checks they may access *this* record, on the server | Missing authorization — the most common flaw in AI-built apps; trusting middleware or hidden UI |
| Validate every request body at the boundary with a strict schema; take identity from the session, never from the body | Trusting client input, mass assignment, client-only validation |
| Let errors propagate. No `catch { return [] }`, `return null`, default values or 200-with-error. Map known errors to 4xx, the rest to 5xx | An outage that looks like "no data" |
| Multi-step writes run in one transaction via the project's helper; connections are always released | Leaked connections, half-applied writes, `BEGIN` on a pool |
| Put invariants in the database (unique/check constraints, `ON CONFLICT`, conditional `UPDATE … WHERE`) | Check-then-insert races and duplicates |
| Parameterised SQL with explicit columns; paginate lists | Injection, over-exposed data, N+1 and unbounded queries |
| Frontend: derive values during render; fetch on the server where possible; `'use client'` only on leaf components; handle loading, error and empty separately | useEffect bugs, bundle bloat, errors rendered as empty lists |
| Forms: empty numeric input becomes `null`, not 0; keep input after a failed submit; disable submit while pending; validate again on the server | Corrupted data, lost user input, duplicate records |
| No `any`, unchecked `as`, `!`, `@ts-ignore` or disabled lint rules to make errors go away | Type debt that hides real bugs |
| No personal or sensitive data in logs, error responses or fixtures; no secrets in client-exposed env vars | Data leaks |
| Delete what you replace; leave no `*_v2`, `.bak`, `PLAN.md` or debug files | Two live implementations; stale files misleading the next session |

Detail and "AI typically writes / senior writes" examples — read the file for
the area you are changing before you start:

- APIs, services, SQL, transactions, migrations, errors, logging → `references/backend.md`
- React, Next.js App Router, forms, state, styling, a11y, TypeScript → `references/frontend.md`
- Authorization, validation, secrets, sensitive data, dependencies → `references/security.md`
- Tests: what to test, weak assertions, test gaming → `references/testing.md`
- File size, layering, reuse, deleting code, stray files → `references/structure.md`
- Editing files, shell commands, git, secrets on disk → `references/files-shell-git.md`

## Step 3 — Editing files and running commands

- Make small, exact, anchored edits. If an edit fails, re-read that region and
  retry with a smaller hunk. Never fall back to rewriting a whole file or running
  `sed` over content you have not read.
- Never write elision placeholders (`// ... rest of code unchanged`) into a file.
- Edit the existing file instead of creating a parallel one; never edit
  generated output.
- Run checks **without pipes** so you see the tool's own exit code, or use
  `scripts/check.sh` (runs the project's typecheck, lint and tests and reports
  each exit code). `npm test | tail` reports `tail`'s exit code, so failures
  look green.
- Don't run servers, watch modes or prompting commands in the foreground.
- Use git read-only for inspection (`status`, `diff`, `log`, `show`). Don't run
  `checkout -- <path>`, `restore`, `reset --hard`, `clean`, `stash` or
  `push --force` to tidy up or undo — they destroy uncommitted work, including
  the user's. Stage files by name.
- Don't read `.env` files or print secrets. Never point an agent session at a
  production database.

## Step 4 — "Done" means verified

1. Run `scripts/check.sh` after your last edit and read the result. If anything
   failed or could not run, say so with the output — never describe unverified
   work as complete.
2. Run `scripts/scan-ai-smells.sh` and fix or justify each hit in files you
   touched.
3. Add or update tests for the changed behaviour **including the unhappy paths**
   (unauthenticated, someone else's record, invalid input, dependency failure,
   duplicate submit). Never weaken or delete an assertion to make a test pass; if
   a test looks wrong, say so and ask.
4. Review your own diff with `references/review-checklist.md` and remove
   trial-and-error residue.
5. Summarise: what changed, which commands you ran and their results,
   assumptions made, and anything noticed but deliberately left alone.

## When the user pushes back

Re-check with evidence (run the test, read the code). If the evidence supports
your answer, hold it and show the evidence; don't change correct code because a
question was repeated. If you were wrong, say so plainly and fix it.
