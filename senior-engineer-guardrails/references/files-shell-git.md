# Files, shell commands and git

Most real data loss from coding agents in 2026 came from these mechanics rather
than from the code they wrote.

## Editing files

**The escalation chain that loses code:** an exact-match edit fails (whitespace,
CRLF, non-breaking spaces, a stale view of the file) → the agent retries → falls
back to `sed`, a heredoc or a whole-file write → content it never read is
overwritten.

Instead:
1. Re-read the exact region (the file may have changed, including by the user).
2. Retry with a smaller, unique anchor — a few lines, not a whole function.
3. If it still fails, stop and report. Don't rewrite the file.

Also:
- Never write elision placeholders into a file: `// ... existing code ...`,
  `// rest of the component unchanged`, `/* same as before */`. Tools write
  exactly what you give them.
- Write a whole file only when creating it, or when you have read all of it in
  this session and are intentionally replacing it. A rewrite that makes a file
  much shorter is a red flag.
- Edit the existing file rather than creating `FooV2.ts` beside it; if two files
  look like the same thing, find which is imported before editing either.
- Don't edit generated output (`dist/`, `.next/`, `build/`, `coverage/`,
  generated clients) — the next build overwrites it.
- Wire new files in: imports/exports, route location, migration numbering,
  registration. An unregistered file is dead code.
- If output was truncated, read the specific part you need; never infer the rest.
- After context is compacted or summarised, re-read files before editing — agents
  have lost track of their own earlier writes and blamed them on the user.

## Shell commands

**Exit codes and pipes.** `npm test 2>&1 | tail -20` returns `tail`'s exit code
(0), so a failing test run reads as success.

```bash
# AI
npx tsc --noEmit 2>&1 | tail -30

# Senior
npx tsc --noEmit > /tmp/tsc.log 2>&1; status=$?; tail -30 /tmp/tsc.log; echo "exit=$status"
```

`set -o pipefail` helps in scripts you own but can cause false failures with
`head` (SIGPIPE, exit 141), so redirecting to a file is the more reliable habit.
`scripts/check.sh` does this for the project's standard checks.

**No hangs.** Don't run in the foreground anything that waits forever or prompts:
dev servers, watch modes (`vitest` → `vitest run`), pagers (`git --no-pager log`),
interactive installers (`--yes`, `CI=1`, `DEBIAN_FRONTEND=noninteractive`). Run
servers in the background with a log file and a health check, and stop them after.

**Keep commands simple.** Long one-liners with nested quotes, heredocs and `&&`
chains fail invisibly (and differently on Windows). Put multi-step logic in a
script file. Prefer the project's package scripts.

**Portability.** `sed -i` differs between GNU and BSD/macOS; prefer the editor
tool for file edits.

**Never:** `rm -rf` on computed or broad paths, `curl … | sh`, global installs,
`chmod -R 777`, or commands against production systems. If something
destructive seems necessary, stop and ask. When an obstacle appears, don't reach
for the broadest credential or flag available — that is the causal chain behind
every 2026 destructive incident reviewed.

## Git

Treat git as read-only unless the user asked you to commit.

Safe: `git status`, `git diff`, `git diff --staged`, `git --no-pager log`,
`git show`, `git blame`, `git show HEAD:path` (to view an original).

Don't run these to tidy, compare or undo: `git checkout -- <path>`,
`git restore`, `git reset --hard`, `git clean -f`, `git stash` / `pop` / `drop`,
`git push --force`, rebase of shared branches. They discard uncommitted work —
the user's included — and it cannot be recovered. To undo your own edit, edit
the file back.

When asked to commit: stage files by name (not `git add -A` / `.`), inspect
`git diff --staged` for secrets, env files, large binaries and stray files, and
follow the project's commit style with one purpose per commit.

## Secrets on disk

- Don't open `.env*`, private keys or credential files; to learn which keys
  exist, read `.env.example`.
- Never paste secrets into commands, logs, commit messages or replies.

## Optional hardening (for maintainers)

These make the rules above mechanical in Claude Code-style harnesses:
- A PreToolUse hook that rejects destructive git commands and piping test/build
  commands into `head`/`tail`.
- Read-before-write enforcement and a check that blocks writes shrinking a file
  sharply.
- A pre-commit grep for elision placeholders and stray file names
  (`scripts/scan-ai-smells.sh` covers both).
- Deny read access to `.env*` and key files.
