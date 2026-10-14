# Privacy policy

_Last updated: 14 October 2026_

**senior-engineer-guardrails** is an open-source agent skill. It consists of
Markdown instructions and two Bash scripts that run on your own machine.

## What the plugin collects

Nothing. The plugin has no server, no account, no telemetry and no analytics.

## What the plugin reads

- The skill's own instruction files, which the AI agent you use loads into its
  context.
- When the agent or you run them, the bundled scripts read files **in your own
  repository**: `scan-ai-smells.sh` runs `git` and `grep` over files you changed,
  and `check.sh` runs existing typecheck, lint, test and build scripts in source
  packages (or trusted custom commands).

## What the plugin stores or sends

- `check.sh` retains per-command logs in a unique private temporary directory.
  Treat them as potentially sensitive and delete them according to local policy.
  The scanner creates a temporary path inventory and cleans it up on exit.
- The helpers do not send telemetry or make service calls themselves. Project
  scripts/custom commands run with your permissions and may write files, access
  credentials or contact services; review them before running. The scanner skips
  credential filenames and redacts possible exposed-secret matches, but is not
  a comprehensive secret detector.

Your use of Claude or any other AI agent is covered by that provider's own
privacy policy; this plugin does not change what the agent itself sends.

## Contact

Questions or concerns: open an issue at
https://github.com/Kannankaruppaiya/senior-engineer-guardrails/issues
