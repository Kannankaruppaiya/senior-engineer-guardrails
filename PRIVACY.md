# Privacy policy

_Last updated: 29 September 2026_

**senior-engineer-guardrails** is an open-source agent skill. It consists of
Markdown instructions and two Bash scripts that run on your own machine.

## What the plugin collects

Nothing. The plugin has no server, no account, no telemetry and no analytics.

## What the plugin reads

- The skill's own instruction files, which the AI agent you use loads into its
  context.
- When the agent or you run them, the bundled scripts read files **in your own
  repository**: `scan-ai-smells.sh` runs `git` and `grep` over files you changed,
  and `check.sh` runs your project's existing typecheck, lint and test scripts.

## What the plugin stores or sends

- `check.sh` writes check logs to your system's temporary directory on your
  machine. Nothing else is written.
- Neither script uses the network, and the plugin sends no data to the author or
  to any third party.

Your use of Claude or any other AI agent is covered by that provider's own
privacy policy; this plugin does not change what the agent itself sends.

## Contact

Questions or concerns: open an issue at
https://github.com/Kannankaruppaiya/senior-engineer-guardrails/issues
