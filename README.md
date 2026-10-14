# senior-engineer-guardrails

An [Agent Skill](https://agentskills.io) that makes AI coding agents work like a
careful senior engineer on full-stack web apps — and avoid the specific mistakes
that 2026 research measured in AI-written code.

It includes React/Next.js, Node/TypeScript and PostgreSQL examples, while the
core workflow adapts to the installed framework and existing architecture.
Enterprise and tenant guidance is generic, without domain-specific requirements.

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
two scripts that make important checks mechanical. Historical research claims
are collected in [`references/evidence.md`](skills/senior-engineer-guardrails/references/evidence.md);
additional architecture and operational guidance reflects engineering judgment.

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
│       │   ├── file-lifecycle.md     # assets, templates, uploads, storage, generated files
│       │   ├── enterprise.md         # tenancy, security surfaces, privacy lifecycle
│       │   ├── delivery-operations.md # contracts, queues, CI, deployment, recovery
│       │   ├── agent-safety.md       # untrusted inputs, permissions, verification
│       │   ├── files-shell-git.md    # safe edits, exit codes, hangs, destructive git
│       │   ├── review-checklist.md   # 11-point self-review before "done"
│       │   └── evidence.md           # sources, dates and caveats
│       └── scripts/
│           ├── check.sh              # runs typecheck/lint/test and reports each real exit code
│           └── scan-ai-smells.sh     # flags AI-typical mistakes in changed files
└── tests/                           # runnable script fixtures, validation and agent eval strategy
```

Existing backend/frontend references retain side-by-side examples. Targeted
references add decision guidance without enlarging the skill entrypoint.

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

# Limit monorepo checks when the root already orchestrates its packages
CHECK_PROJECTS=$'.\napps/api' bash .claude/skills/senior-engineer-guardrails/scripts/check.sh

# Scan files changed since the merge-base with origin/main
bash .claude/skills/senior-engineer-guardrails/scripts/scan-ai-smells.sh
bash .claude/skills/senior-engineer-guardrails/scripts/scan-ai-smells.sh origin/develop
SERVER_PATHS='^(src/server|services)/' bash .claude/skills/senior-engineer-guardrails/scripts/scan-ai-smells.sh

# Inspect the exact index snapshot, or every tracked/untracked source file
bash .claude/skills/senior-engineer-guardrails/scripts/scan-ai-smells.sh --staged
bash .claude/skills/senior-engineer-guardrails/scripts/scan-ai-smells.sh --all
```

Both scripts use Bash 4.4+, Git and standard shell tools; `check.sh` also uses Node
to parse package manifests. Repository tests require Node 22+ and Bash. The
check runner discovers source packages, skips dependency/build/generated folders,
uses the nearest package-manager declaration or lockfile and runs existing
typecheck/lint/test/build scripts. Root orchestrators can duplicate child work;
use `CHECK_PROJECTS` to choose a reviewed set. Custom commands take precedence.
`CI=1` is set, but scripts must still use non-watch commands themselves.

Checks exit 0 on pass, 1 on a failed check and 2 on setup failure/no checks.
Logs are unique per invocation/check and kept in a private temporary directory.
`CHECK_PROJECTS` uses newline-separated directories; automatic discovery supports
newline names on filesystems that allow them.

The scanner uses NUL-separated paths and literal arguments. Explicit refs use
the merge-base with HEAD plus current working changes; the default tries
origin/main, origin/master, then HEAD. Deleted files are excluded, renamed targets
included, and `--staged` reads index content. It scans complete selected files,
so unchanged lines in those files may produce hits. Exit 2 reports invalid refs,
regexes or read errors. Conventional backend/frontend folders are detected at
any monorepo depth, including `apps/api`; custom path regexes remain supported.
Credential files are excluded and possible exposed-secret content is redacted.

See [evaluation strategy](tests/EVALUATION.md) for deterministic regression tests
and the separate baseline/candidate agent evaluation procedure.

## What this plugin runs and sends

- **Nothing runs automatically.** The plugin contains one skill (Markdown
  instructions) and two Bash scripts. It has no hooks, no MCP servers, no
  background processes and no bundled binaries.
- **The scripts run only when the agent or you call them**, inside your own
  repository: `check.sh` runs your project's existing `typecheck`, `lint`,
  `test` and `build` package scripts (or commands set in `CHECK_COMMANDS`) and
  writes logs to your temp directory; `scan-ai-smells.sh` runs `git` and `grep`
  over selected files. The helpers do not install packages or contact a service
  themselves. Project scripts/custom commands execute with your permissions and
  may use the network, access files or emit sensitive logs; review them first.
- The plugin collects no telemetry. Your project's commands and AI provider have
  their own data handling behavior.

[Privacy](PRIVACY.md): the full privacy policy.

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
