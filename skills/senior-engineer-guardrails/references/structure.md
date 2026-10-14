# Code structure: AI habits vs senior practice

A single AI generation is usually compact — isolated AI functions were about half
the size of human ones. The problem is accretion over a session: Claude Code's
median PR was 495 changed lines against 52 for humans; one team found a
12,882-line `page.tsx`. Refactoring ("moved") code fell from 21% of changed lines
in 2022 to 3.8% in 2026 while copy/paste rose to 15.7%. More capable models wrote
*more* bloated, coupled code, and detailed prompting did not fix it.

## File and function size

- Aim for files under ~300 lines and functions under ~50. When a file you touch is
  already large, use responsibility and coupling to decide whether extraction
  helps this task; size is a review signal, not permission for unrelated refactors.
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
- Keep compatibility paths/feature flags when a safe migration needs them;
  document their owner, expiry and removal conditions. Avoid permanent parallel
  implementations without a compatibility requirement.
- Remove unused imports, exports and variables you created (`knip`,
  `ts-prune`).

## No stray files

Avoid accidental `*_v2.*`, `*_new.*`, `*.bak`, `*.old`, copy files and debug
output. Keep scratch work outside the repo. Preserve intentional versioned
contracts/assets, maintained tools and canonical planning documents; a scanner
filename hit requires review, not automatic deletion.

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

## Framework-aware folders and names

Inspect the installed framework, route discovery and current tree before
choosing placement. Preserve working structure; these are options, not a demand
to reorganize an existing app. New projects should start with only needed layers.

| Project | Conventional placement and constraints |
|---|---|
| Next.js App Router | `app/` or `src/app/` for `page`, `layout`, `route`, loading/error boundaries; feature code alongside or in established features; private server modules outside client import paths |
| Next.js Pages Router | `pages/` and `pages/api/`; keep its installed conventions, do not migrate routers incidentally |
| React/Vite | `src/` with feature modules, shared UI and API clients; `public/` for intentionally public unbundled files; no invented Next.js routing/server conventions |
| Node APIs | Existing `src/modules/<feature>/` or routes/services/repositories; request adapters depend on services, services on owned data access/contracts |
| Django/Rails | Framework apps/models/views/templates/migrations or established service objects; preserve framework discovery and naming rather than imposing a JavaScript folder tree |
| Go | Existing module/packages; `cmd/` entrypoints and `internal/` where appropriate; avoid unnecessary package splits/circular dependencies |
| Monorepo | `apps/web`, `apps/api`, `packages/<owned capability>` (or existing equivalents); explicit package exports, dependency direction and independent checks |

Example minimal monorepo when both runtimes actually exist:

```text
apps/web/src/features/orders/  # presentation and browser-facing client
apps/api/src/modules/orders/   # request adapter, service, data access
packages/contracts/           # public schemas/types; no server/database imports
```

Keep tests adjacent or in the existing test hierarchy. Keep framework-reserved
filenames exact. Components/types commonly use PascalCase, functions/variables
camelCase and package names kebab-case; Python/SQL often use snake_case. Follow
the repository, including casing on Linux, rather than mixing naming styles.
Name by capability/responsibility; avoid an unowned global `utils` dumping ground.
See [file lifecycle](file-lifecycle.md) for runtime files and generated artifacts.

## SOLID, DRY, KISS and YAGNI in practice

- **Single responsibility:** separate business decisions from transport and
  persistence when they change independently. A service should not render UI.
- **Open/closed:** add an extension point for demonstrated variants, not a
  speculative plugin framework for one implementation.
- **Liskov substitution:** adapters preserve the contract's failures, ordering,
  side effects and semantics; a fake store must not silently ignore constraints.
- **Interface segregation:** callers use small capability contracts rather than
  a giant shared service; share public DTOs, not private ORM entities.
- **Dependency inversion:** domain rules depend on owned interfaces where
  infrastructure variation/testing justifies them; framework adapters live at
  the edge. Do not wrap every function in an interface by default.
- **DRY:** reuse the authoritative business rule, not every coincidental similar
  shape. Two independent domains may need separate models as they evolve.
- **KISS/YAGNI:** choose the simplest complete implementation that meets current
  requirements. Extra layers, generic factories and options need a present use.

Modules own their data and expose deliberate APIs. Avoid deep imports, circular
dependencies and cross-feature writes that bypass invariants. Shared packages
must not pull privileged server dependencies into clients. Use existing boundary
lint/import checks and contract tests; document significant decisions with a
small ADR when alternatives or constraints need to survive the session.
