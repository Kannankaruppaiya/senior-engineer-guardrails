#!/usr/bin/env bash
# Runs a project's standard checks and reports each one's OWN exit code.
#
# Output goes to log files, never through a pipe, so a failing check can't look
# green because of `| tail`. Exits non-zero if any check failed.
#
# Auto-detects npm / pnpm / yarn / bun and runs whichever of these package.json
# scripts exist: typecheck (or type-check / tsc), lint, test.
# Override with CHECK_COMMANDS, one command per line, e.g.:
#   CHECK_COMMANDS=$'pytest -q\nruff check .' scripts/check.sh
set -u

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"
logdir="${TMPDIR:-/tmp}/senior-guardrails-checks"
mkdir -p "$logdir"
export CI=1   # non-interactive, non-watch mode for most tools

failed=0
ran=0

run() {
  local name="$1"; shift
  local log="$logdir/$name.log"
  ran=1
  "$@" >"$log" 2>&1
  local status=$?
  if [ "$status" -eq 0 ]; then
    echo "PASS  $name"
  else
    echo "FAIL  $name (exit $status) — last 40 lines of $log:"
    tail -n 40 "$log" | sed 's/^/      /'
    failed=1
  fi
}

if [ -n "${CHECK_COMMANDS:-}" ]; then
  i=0
  while IFS= read -r cmd; do
    [ -z "$cmd" ] && continue
    i=$((i + 1))
    run "check-$i" bash -c "$cmd"
  done <<< "$CHECK_COMMANDS"
elif [ -f package.json ]; then
  if   [ -f pnpm-lock.yaml ]; then pm=pnpm
  elif [ -f yarn.lock ]; then pm=yarn
  elif [ -f bun.lockb ] || [ -f bun.lock ]; then pm=bun
  else pm=npm
  fi

  has_script() { node -e "process.exit(require('./package.json').scripts?.['$1'] ? 0 : 1)" 2>/dev/null; }

  if [ ! -d node_modules ]; then
    echo "WARN  node_modules is missing — install dependencies first ($pm install)."
  fi

  for s in typecheck type-check tsc; do
    if has_script "$s"; then run typecheck "$pm" run "$s"; break; fi
  done
  if ! has_script typecheck && ! has_script type-check && ! has_script tsc && [ -f tsconfig.json ]; then
    run typecheck npx --no-install tsc --noEmit
  fi
  has_script lint && run lint "$pm" run lint
  # `test` scripts that start a watcher are neutralised by CI=1 for vitest/jest.
  has_script test && run test "$pm" run test
else
  echo "No package.json found and CHECK_COMMANDS not set — nothing to run."
  exit 2
fi

echo
if [ "$ran" -eq 0 ]; then
  echo "No checks were found to run. Set CHECK_COMMANDS or add typecheck/lint/test scripts."
  exit 2
fi
if [ "$failed" -eq 0 ]; then
  echo "All checks passed. Logs: $logdir"
else
  echo "Some checks FAILED. Logs: $logdir"
fi
exit "$failed"
