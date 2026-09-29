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
source in [`references/evidence.md`](skills/senior-engineer-guardrails/references/evidence.md).

## What's inside

```
.
├── .claude-plugin/
│   ├── plugin.json                   # Claude Code plugin manifest
│   └── marketplace.json              # makes this repo installable as a marketplace
├── skills/
│   └── senior-engineer-guardrails/   # the skill itself
│       ├── SKILL.md                  # the workflow: learn → plan → write → verify
│       ├── references/
│       │   ├── backend.md            # handlers, errors, validation, transactions, races, SQL, migrations
│       │   ├── frontend.md           # server/client components, effects, fetching, forms, a11y, styling
│       │   ├── security.md           # authorization, sessions, secrets, sensitive data, dependencies
│       │   ├── testing.md            # what to test, assertions that catch bugs, test integrity
│       │   ├── structure.md          # file size, layering, reuse, deleting code, stray files
│       │   ├── files-shell-git.md    # safe edits, exit codes, hangs, destructive git
│       │   ├── review-checklist.md   # 11-point self-review before "done"
│       │   └── evidence.md           # sources, dates and caveats
│       └── scripts/
│           ├── check.sh              # runs typecheck/lint/test and reports each real exit code
│           └── scan-ai-smells.sh     # flags AI-typical mistakes in changed files
└── tests/skill-evals.json            # test prompts with assertions for evaluating the skill
```

Each reference shows side-by-side *"AI typically writes"* vs *"senior writes"*
examples.

## Install

### Claude Code — as a plugin (recommended)

Inside a Claude Code session:

```
/plugin marketplace add Kannankaruppaiya/senior-engineer-guardrails
/plugin install senior-engineer-guardrails@kannankaruppaiya
```

Or from your shell:

```bash
claude plugin marketplace add Kannankaruppaiya/senior-engineer-guardrails
claude plugin install senior-engineer-guardrails@kannankaruppaiya
```

The skill then loads automatically whenever a task involves code changes. To
run it explicitly, use `/senior-engineer-guardrails:senior-engineer-guardrails`.

Update later with `claude plugin update senior-engineer-guardrails@kannankaruppaiya`,
or turn on auto-update for the marketplace in `/plugin`.

**For a whole team:** commit this to your project's `.claude/settings.json` so
everyone who opens the repo is offered the plugin:

```json
{
  "extraKnownMarketplaces": {
    "kannankaruppaiya": {
      "source": { "source": "github", "repo": "Kannankaruppaiya/senior-engineer-guardrails" }
    }
  },
  "enabledPlugins": {
    "senior-engineer-guardrails@kannankaruppaiya": true
  }
}
```

### Claude Code — as a plain skill

```bash
git clone https://github.com/Kannankaruppaiya/senior-engineer-guardrails.git /tmp/seg

# for you, in every project
cp -r /tmp/seg/skills/senior-engineer-guardrails ~/.claude/skills/

# or for one project, shared through git
mkdir -p .claude/skills && cp -r /tmp/seg/skills/senior-engineer-guardrails .claude/skills/
```

Invoke it with `/senior-engineer-guardrails`, or let it load automatically.

### Claude.ai and the Claude apps

Download `senior-engineer-guardrails.skill` from the
[latest release](https://github.com/Kannankaruppaiya/senior-engineer-guardrails/releases/latest)
and upload it under **Settings → Capabilities → Skills**.

### Other agents (Codex CLI, Gemini CLI, Cursor, Copilot, OpenHands …)

Copy `skills/senior-engineer-guardrails/` into your repository (e.g.
`tools/senior-engineer-guardrails/`) and add to your `AGENTS.md`:

```markdown
Before changing code, read tools/senior-engineer-guardrails/SKILL.md and follow it.
Read the matching file in its references/ folder for the area you are changing.
```

## Using the scripts directly

When the skill is active, the agent runs these itself. You can also run them by
hand or in CI — the paths below assume the plain-skill install; from a clone of
this repository use `skills/senior-engineer-guardrails/scripts/` instead.

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

## What this plugin runs and sends

- **Nothing runs automatically.** The plugin contains one skill (Markdown
  instructions) and two Bash scripts. It has no hooks, no MCP servers, no
  background processes and no bundled binaries.
- **The scripts run only when the agent or you call them**, inside your own
  repository: `check.sh` runs your project's existing `typecheck`, `lint` and
  `test` package scripts (or the commands you set in `CHECK_COMMANDS`) and
  writes logs to your temp directory; `scan-ai-smells.sh` runs `git` and `grep`
  over files you changed. Neither script uses the network, installs packages,
  or reads credentials.
- **No data leaves your machine** because of this plugin. It collects no
  telemetry.

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
  [`evidence.md`](skills/senior-engineer-guardrails/references/evidence.md).
- `scan-ai-smells.sh` is a heuristic grep: expect some false positives, and it
  cannot see missing authorization — that needs tests.

## Contributing

Issues and pull requests are welcome — especially new evidence, corrected
figures, rules for other stacks, and evals that show a rule helps. See
[CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)
