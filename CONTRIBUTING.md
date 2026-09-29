# Contributing

Thanks for helping make coding agents safer to work with.

## What's most useful

- **New or updated evidence.** A study, benchmark or incident report that
  supports, refutes or refines a rule. Add it to `skills/senior-engineer-guardrails/references/evidence.md` with a
  link, publication date and a one-line finding. Label vendor and practitioner
  sources.
- **Corrections.** Wrong figures, dead links, outdated framework advice.
- **Rules for other stacks** (Python/Django, Go, Rails, Vue/Svelte, other
  databases). Add a new `skills/senior-engineer-guardrails/references/<area>.md` and link it from `SKILL.md`.
- **Scanner patterns** in `skills/senior-engineer-guardrails/scripts/scan-ai-smells.sh` for mistakes you have seen
  agents make repeatedly — with a low false-positive rate.
- **Evals** in `tests/skill-evals.json` that show whether a rule changes agent
  behaviour.

## Guidelines

1. **Every rule needs a reason.** Explain *why* it matters (what goes wrong
   without it), and cite evidence where it exists. Prefer explaining over
   capital-letter MUSTs; agents follow reasons better.
2. **Keep `SKILL.md` short** (under ~200 lines). Detail and examples belong in
   `references/`, which the agent reads on demand.
3. **Examples show both sides:** what an agent typically writes and what a senior
   engineer writes, kept short and correct. Test code examples before submitting.
4. **Stay stack-neutral in `SKILL.md`.** Framework-specific advice goes in the
   reference files.
5. **Scripts** must stay dependency-light (Bash, git, grep), pass `bash -n` and
   ShellCheck, and exit non-zero only for real findings or failures.
6. **Frontmatter** must follow the Agent Skills spec: `name` in lowercase with
   hyphens, `description` under 1024 characters.

## Testing a change

- Run the scripts against a sample repository containing both good and bad
  code, and include the output in your PR.
- For wording changes to `SKILL.md`, run the prompts in `tests/skill-evals.json` with
  and without the change and describe the difference.
- Run `claude plugin validate --strict .` in the repository root before
  opening a PR (CI checks the manifests, JSON and scripts).

## Pull requests

- One purpose per PR; describe what changed and why, with sources.
- Update `CHANGELOG.md` under "Unreleased".

## Releasing (maintainers)

1. Move the "Unreleased" notes in `CHANGELOG.md` under a new `## X.Y.Z — date`
   heading.
2. Bump `version` in `.claude-plugin/plugin.json` to `X.Y.Z`. Users on the
   plugin only receive an update when this changes.
3. Commit, then tag and push: `git tag vX.Y.Z && git push origin vX.Y.Z`.
   The Release workflow checks the tag matches `plugin.json`, builds the
   plugin zip and the `.skill` package, and publishes the GitHub release with
   the CHANGELOG notes.

By contributing, you agree that your contributions are licensed under the MIT
License.
