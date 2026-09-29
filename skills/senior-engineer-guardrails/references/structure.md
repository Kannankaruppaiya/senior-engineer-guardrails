# Code structure: AI habits vs senior practice

A single AI generation is usually compact — isolated AI functions were about half
the size of human ones. The problem is accretion over a session: Claude Code's
median PR was 495 changed lines against 52 for humans; one team found a
12,882-line `page.tsx`. Refactoring ("moved") code fell from 21% of changed lines
in 2022 to 3.8% in 2026 while copy/paste rose to 15.7%. More capable models wrote
*more* bloated, coupled code, and detailed prompting did not fix it.

## File and function size

- Aim for files under ~300 lines and functions under ~50. When a file you touch is
  already large, don't append another block — extract the part you are changing
  into a well-named module beside it.
- Pages/controllers stay thin: load data, call services, compose components.
- A module mixing data access, validation, business rules and presentation is a
  signal to split.
- Mechanical backstop: `max-lines` / `max-lines-per-function` lint rules, and a
  CI ratchet that only lets oversized files shrink.

## Layering

- Keep the project's one-way layering, typically
  `route/controller → service → repository/data access → database`.
- SQL lives in the data-access layer only; UI code never talks to the database.
- Shared, pure utilities don't import server-only modules.
- Enforce with `eslint-plugin-boundaries` or `dependency-cruiser` where possible.

## Reuse and duplication

```ts
// AI: a new helper next to an existing, more complete one
export function isValidEmail(s: string) { return s.includes('@'); }
```

```ts
// Senior: reuse (and extend, if it is missing something)
import { emailSchema } from '@/lib/validation';
```

- Search by purpose before writing any helper, hook or component.
- If something close exists, extend it and update callers instead of writing a
  sibling. In one test an agent re-implemented an existing timeout helper inline
  in 5 of 5 runs.
- A duplication detector (`jscpd`) with a threshold in CI catches the rest.

## Delete what you replace ("Guard-and-Go")

Models found the right file for 92% of required deletions but deleted the exact
line in under 52%; in 29% of passing patches they wrapped the old code in a guard
or fallback instead. That leaves two reachable implementations of one rule.

- Replace means delete: remove the old function/component/route and update every
  caller in the same change.
- No feature flags, `legacy` branches or fallbacks unless the task asks for a
  staged rollout.
- Remove unused imports, exports and variables you created (`knip`,
  `ts-prune`).

## No stray files

Never leave `*_v2.*`, `*_new.*`, `*.bak`, `*.old`, "copy" files, `PLAN.md`,
`NOTES.md`, `SUMMARY.md`, debug output or one-off scripts in the repository — the
next agent session reads them as project truth. Keep scratch work outside the
repo; put plans and summaries in your reply.

## Keep diffs reviewable

- One purpose per change; split unrelated fixes.
- Don't reformat, reorder or rename code you didn't need to touch.
- Comments explain *why*; don't narrate each line or restate names in docstrings.
- No speculative options, abstractions or config "for later". Heavy multi-agent
  pipelines made code 50–130% more complex with no accuracy gain.
- Before finishing, remove trial-and-error residue (debug logs, dead branches,
  unused variables). Trimming this residue cut redundant edits 18–33% in one study.
- Adding the instruction "keep as much of the original code as possible" reduced
  excess edits and slightly *raised* pass rates — minimal diffs are not a
  trade-off against correctness.

## Instruction files

- Keep `AGENTS.md`/`CLAUDE.md` short, current and owned by a human. Adding 16
  noisy rules cut compliance with the real ones from 65.6% to 41.5%.
- When a rule keeps being broken, turn it into a lint rule, test or hook instead
  of adding more prose.
