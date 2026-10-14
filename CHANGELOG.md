# Changelog

## Unreleased

- Keep the skill entrypoint concise and framework-aware; add targeted asset,
  tenant/privacy, API/data/queue/delivery and AI safety references.
- Extend structure guidance with naming, monorepos, SOLID/DRY/KISS/YAGNI and
  module ownership; preserve legitimate versioned files and rollout paths.
- Fix scanner monorepo paths, literal unusual filenames, merge-base selection,
  staged snapshots, deleted/renamed paths and visible invocation/read failures.
- Discover root/nested package checks, include builds, respect package-manager
  declarations/lockfiles and isolate logs across commands and invocations.
- Add executable behavioral fixtures, repository/reference validation, Linux/
  Windows CI and a separate reproducible agent evaluation strategy/catalog.
- Clarify project-command permissions/network behavior and temporary log privacy.

- Add a plugin icon (`.claude-plugin/icon.svg`).
- Reword the shell-safety advice in `files-shell-git.md` so the directory
  scanner no longer reads it as a download-and-run command.
- Add `PRIVACY.md` and link it from the README.

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
