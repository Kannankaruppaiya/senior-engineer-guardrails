---
name: senior-engineer-guardrails
description: Implement or review changes in existing web applications with careful repository discovery, framework-aware structure, reusable architecture, security and tenant boundaries, safe file and Git handling, and evidence-based verification. Use for features, fixes, APIs, UI, data, tests, infrastructure and deployment preparation; adapt to the project's stack and task scope.
license: MIT
metadata:
  version: "1.0.0"
  evidence-window: "May–September 2026"
---

# Senior engineer guardrails

Open-source skill by [Kannankaruppaiya](https://github.com/Kannankaruppaiya),
licensed MIT. Report methodology issues in the
[repository](https://github.com/Kannankaruppaiya/senior-engineer-guardrails/issues).
Research context and its limitations are in [evidence](references/evidence.md);
new guidance also reflects engineering judgment, not measured guarantees.

## Discover before changing

- Read applicable project instructions, manifests, lockfiles, framework versions,
  source folders, callers, tests and CI. If documentation and code disagree,
  investigate and report the mismatch; do not silently override an instruction.
- Inspect Git status and existing work. Preserve architecture and functionality.
  Find canonical auth, permissions, validation, transaction, error, date, form
  and UI helpers by purpose before creating another implementation.
- Identify executable checks and deployment constraints. Restate the outcome and
  material assumptions. Ask only when a missing rule changes correctness,
  permission, data meaning or an irreversible decision.
- Plan the smallest complete change. Avoid unrelated refactors, dependencies,
  speculative options and domain-specific requirements in universal guidance.

## Read the relevant references

Load only the references that apply to the change:

| Area | Reference |
|---|---|
| Framework folders, names, SOLID/DRY/KISS/YAGNI, module boundaries | [structure](references/structure.md) |
| Assets, templates, uploads, object storage, generated output | [file lifecycle](references/file-lifecycle.md) |
| Handlers, SQL, transactions, races, errors, dates, migrations | [backend](references/backend.md) |
| React/Next.js, forms, effects, UI states, accessibility | [frontend](references/frontend.md) |
| Auth, secrets, sessions, dependencies, request threats | [security](references/security.md) |
| Tenant isolation, enterprise controls, privacy lifecycle | [enterprise](references/enterprise.md) |
| API contracts/versioning, data lifecycle, queues, operations | [delivery and operations](references/delivery-operations.md) |
| Behavioral tests, unhappy paths, test integrity | [testing](references/testing.md) |
| Safe edits, shell exit codes, Git and secrets on disk | [files, shell and Git](references/files-shell-git.md) |
| Untrusted inputs, tool permissions, agents, verification | [agent safety](references/agent-safety.md) |

## Implement with explicit boundaries

- Each protected entry point verifies identity and record/tenant permission on
  the server. Public endpoints need an explicit access policy and abuse controls.
  Middleware and hidden UI alone are insufficient.
- Validate bodies, query, params and external events with appropriate schemas;
  reject unknown writable fields to prevent mass assignment. Derive identity and
  tenancy from trusted context, never accept them merely because a body says so.
- Keep handlers thin; reuse services/data access and parameterized SQL with
  explicit columns, capped pagination and database-enforced invariants.
  Multi-step writes share one transaction; connections are released on failure.
- Map known errors to appropriate statuses; unexpected failures stay failures.
  No silent empty/default results or success responses for outages. Explicit
  product fallbacks must remain observable.
- Use installed framework conventions. Keep server-only modules out of browser
  bundles. Derive UI values during render; distinguish loading/error/empty/data.
  Forms retain input after failure, treat empty numbers explicitly, prevent
  duplicate submit and validate again on the server.
- Narrow unknown values; do not silence defects with unchecked assertions,
  `any`, non-null assertions, ignored type errors or disabled lint rules.
- Log diagnostic codes/correlation identifiers without secrets or personal
  payloads. Use synthetic fixtures and redact user-facing errors.
- Edit source in place with precise anchors after reading it. Re-read after a
  failed edit or context compaction. Never write elision placeholders; replace
  whole files only after reading them completely and reviewing preservation.
- Wire new files into callers/configuration. Remove replaced code once safe;
  keep required compatibility paths for staged rollouts with an owner/expiry.
  Respect canonical docs and versioned assets; keep scratch/backup residue out.
- Commands retain their own exit codes and use noninteractive modes. Do not
  run watchers indefinitely. Preserve user work; no destructive Git cleanup,
  force pushes or production credentials/databases in an agent session.
  Explicit commit/push authorization permits those actions within task scope.

## Verify before delivering

1. Add meaningful tests proportional to risk, including authorization, invalid
   input, dependency failure, concurrent/repeated side effects where applicable.
   Never weaken, skip or delete assertions to manufacture a pass. Investigate a
   wrong test and confirm changed requirements before changing its contract.
2. Run project checks after the final edit. [check.sh](scripts/check.sh) runs
   discovered package typecheck/lint/test/build scripts with isolated logs;
   non-Node projects use trusted `CHECK_COMMANDS`. Exit 2 means no checks or a
   setup failure, never a pass. Review package commands before executing them.
3. Run [scan-ai-smells.sh](scripts/scan-ai-smells.sh), fixing or justifying each
   hit. It scans complete selected files; it is heuristic and cannot prove
   authorization, multiline behavior, correctness or security.
4. Read [review checklist](references/review-checklist.md), inspect tests first
   and the final diff for missing callers, leaked data and unrelated changes.
   Re-read applicable rules against the completed output.
5. Report changes, commands and real results, assumptions, justified scanner
   findings and pending checks. Distinguish static/mock/local evidence from live
   behavior. Never claim deployment, recovery or agent evaluations were run
   unless there is execution evidence.

When challenged, re-check evidence. Correct actual mistakes; do not change
verified behavior merely because a question is repeated.
