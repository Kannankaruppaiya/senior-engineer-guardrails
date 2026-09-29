# Changelog

## Unreleased

- Add a plugin icon (`.claude-plugin/icon.svg`).
- Reword the shell-safety advice in `files-shell-git.md` so the directory
  scanner no longer reads it as a download-and-run command.

## 1.0.0 — 2026-09-29

- First release.
- `SKILL.md` workflow: learn conventions → plan → write → verify.
- References for backend, frontend, security, testing, structure, and
  files/shell/git, with "AI typically writes / senior writes" examples.
- `scripts/check.sh`: runs typecheck, lint and tests with real exit codes.
- `scripts/scan-ai-smells.sh`: flags 19 AI-typical mistake patterns in
  changed files.
- `references/evidence.md`: sources from May–September 2026.
- `tests/skill-evals.json`: three evaluation prompts with assertions.
- Installable as a Claude Code plugin from this repository's marketplace:
  `/plugin marketplace add Kannankaruppaiya/senior-engineer-guardrails`, then
  `/plugin install senior-engineer-guardrails@kannankaruppaiya`.
- Release assets: `senior-engineer-guardrails.skill` for claude.ai and a
  plugin zip for `claude --plugin-dir`.
