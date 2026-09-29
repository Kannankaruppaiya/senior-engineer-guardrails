# senior-engineer-guardrails

An [Agent Skill](https://agentskills.io) that makes AI coding agents work like a
careful senior engineer on full-stack web apps — and avoid the specific mistakes
that 2026 research measured in AI-written code.

It targets React / Next.js frontends, Node/TypeScript APIs and SQL (PostgreSQL)
databases, but most rules apply to any web stack.

## Why

Studies and incident reports from May–September 2026 show that coding agents
rarely fail by writing code that doesn't compile. They fail by **adding when a
senior would reuse, delete or constrain**, and by skipping rules nobody wrote down:

| What agents do | Measured |
|---|---|
| Skip server-side authorization | Broken access control in 75.5% of 200 audited AI-built apps |
| Pass lenient checks, fail strict ones | ~90% → 18–29% once API contracts were tested strictly |
| Write tests that don't test | 80% of agent test patches had weak or no assertions |
| Lose code and data mechanically | Whole-file rewrites, `cmd \| tail` hiding failures, `git reset --hard` on user work, production databases deleted |
| Grow code instead of reusing it | Copy/paste up; refactoring ("moved" code) down from 21% to 3.8% of changes |

Prompt rules alone decay over a session. This skill pairs a working method with
two scripts that make the important checks mechanical. Every rule is traced to a
source in [`references/evidence.md`](senior-engineer-guardrails/references/evidence.md).

## What's inside

```
.
├── senior-engineer-guardrails/       # the skill — copy this folder
│   ├── SKILL.md                      # the workflow: learn → plan → write → verify
│   ├── references/
│   │   ├── backend.md                # handlers, errors, validation, transactions, races, SQL, migrations
│   │   ├── frontend.md               # server/client components, effects, fetching, forms, a11y, styling
│   │   ├── security.md               # authorization, sessions, secrets, sensitive data, dependencies
│   │   ├── testing.md                # what to test, assertions that catch bugs, test integrity
│   │   ├── structure.md              # file size, layering, reuse, deleting code, stray files
│   │   ├── files-shell-git.md        # safe edits, exit codes, hangs, destructive git
│   │   ├── review-checklist.md       # 11-point self-review before "done"
│   │   └── evidence.md               # sources, dates and caveats
│   └── scripts/
│       ├── check.sh                  # runs typecheck/lint/test and reports each real exit code
│       └── scan-ai-smells.sh         # flags AI-typical mistakes in changed files
└── evals/evals.json                  # test prompts with assertions for evaluating the skill
```

Each reference shows side-by-side *"AI typically writes"* vs *"senior writes"*
examples.

## Install

### Claude Code

Personal (all projects):

```bash
git clone https://github.com/Kannankaruppaiya/senior-engineer-guardrails.git /tmp/seg
cp -r /tmp/seg/senior-engineer-guardrails ~/.claude/skills/
```

Per project (shared with your team through git):

```bash
mkdir -p .claude/skills
cp -r /tmp/seg/senior-engineer-guardrails .claude/skills/
```

The skill loads automatically when a task involves code changes. You can also
invoke it explicitly with `/senior-engineer-guardrails`.

### Claude.ai / Claude apps

Zip the inner `senior-engineer-guardrails/` folder and upload it under
**Settings → Capabilities → Skills**.

### Other agents (Codex CLI, Gemini CLI, Cursor, Copilot, OpenHands …)

Copy the folder into your repository (e.g. `tools/senior-engineer-guardrails/`)
and add to your `AGENTS.md`:

```markdown
Before changing code, read tools/senior-engineer-guardrails/SKILL.md and follow it.
Read the matching file in its references/ folder for the area you are changing.
```

## Using the scripts directly

```bash
# Run the project's checks; exit code is non-zero if any check failed
bash .claude/skills/senior-engineer-guardrails/scripts/check.sh

# Custom commands (any language)
CHECK_COMMANDS=$'pytest -q\nruff check .' bash .claude/skills/senior-engineer-guardrails/scripts/check.sh

# Scan files changed since the merge-base with origin/main
bash .claude/skills/senior-engineer-guardrails/scripts/scan-ai-smells.sh
bash .claude/skills/senior-engineer-guardrails/scripts/scan-ai-smells.sh origin/develop
SERVER_PATHS='^(src/server|services)/' bash .claude/skills/senior-engineer-guardrails/scripts/scan-ai-smells.sh
```

Both scripts are plain Bash with `git`, `grep` and (for `check.sh`) Node to read
`package.json`. They are safe to run in CI.

## Make it stick

The research is clear that mechanical enforcement beats instructions. For best
results, also:

- add ESLint rules: `react-hooks/*` as errors, `@typescript-eslint/no-floating-promises`,
  `no-explicit-any`, `max-lines`;
- run `scan-ai-smells.sh` in CI or a pre-commit hook;
- in Claude Code, add PreToolUse hooks that block destructive git commands and
  piping test commands into `tail`/`head`;
- keep agents away from production credentials and databases.

## Limitations

- The evidence window is May–September 2026; most sources are preprints.
- No study yet compares agents with *senior* developers specifically; some rules
  (e.g. about `useEffect` and forms) rest on consistent practitioner reports
  rather than measured rates. See the gaps section of
  [`evidence.md`](senior-engineer-guardrails/references/evidence.md).
- `scan-ai-smells.sh` is a heuristic grep: expect some false positives, and it
  cannot see missing authorization — that needs tests.

## Contributing

Issues and pull requests are welcome — especially new evidence, corrected
figures, rules for other stacks, and evals that show a rule helps. See
[CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)
