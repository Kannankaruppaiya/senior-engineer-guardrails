#!/usr/bin/env bash
# Exit 0: pass; 1: check failed; 2: setup error/no checks.
# CHECK_COMMANDS: trusted commands, one per line. CHECK_PROJECTS: optional
# project directories, one per line; otherwise discovers all source packages.
set -u
root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$root" || exit 2
umask 077
logdir=$(mktemp -d "${TMPDIR:-/tmp}/senior-guardrails-checks.XXXXXXXX") || exit 2
echo "Logs: $logdir"
export CI=1
failed=0 ran=0 setup_failed=0 manifest_count=0
run() {
  local directory=$1 name=$2 status log
  shift 2
  ran=$((ran + 1))
  log="$logdir/check-$ran.log"
  (cd "$directory" && "$@") >"$log" 2>&1
  status=$?
  if [ "$status" -eq 0 ]; then
    printf 'PASS  %q / %s (log: %s)\n' "$directory" "$name" "$log"
  else
    printf 'FAIL  %q / %s (exit %s; log: %s)\n' "$directory" "$name" "$status" "$log"
    tail -n 40 "$log"
    failed=1
  fi
}
if [ -n "${CHECK_COMMANDS:-}" ]; then
  while IFS= read -r cmd; do
    [[ $cmd =~ ^[[:space:]]*$ ]] && continue
    run . custom bash -o pipefail -c "$cmd"
  done <<< "$CHECK_COMMANDS"
else
  command -v node >/dev/null || { echo "Node is required to read manifests." >&2; exit 2; }
  paths="$logdir/projects"
  if [ -n "${CHECK_PROJECTS:-}" ]; then
    : >"$paths"
    while IFS= read -r project; do
      [ -n "$project" ] || continue
      if [ ! -f "$project/package.json" ]; then
        printf 'Missing package.json: %q\n' "$project" >&2; setup_failed=1; continue
      fi
      printf '%s\0' "$project/package.json" >>"$paths"
    done <<< "$CHECK_PROJECTS"
  else
    find . -type d \( -name .git -o -name node_modules -o -name dist -o -name build -o -name coverage -o -name .next -o -name generated -o -name vendor \) -prune -o -type f -name package.json -print0 >"$paths" || exit 2
  fi
  while IFS= read -r -d '' manifest; do
    directory=${manifest%/package.json}
    manifest_count=$((manifest_count + 1))
    manifest_log="$logdir/manifest-$manifest_count.log"
    scripts=$(node -e '
      const fs = require("fs");
      const p = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
      if (p.scripts !== undefined && (!p.scripts || typeof p.scripts !== "object" || Array.isArray(p.scripts))) throw Error("Invalid scripts");
      const s = p.scripts || {};
      for (const name of ["typecheck", "type-check", "tsc", "lint", "test", "build"]) {
        if (s[name] !== undefined && typeof s[name] !== "string") throw Error("Invalid script " + name);
      }
      const type = ["typecheck", "type-check", "tsc"].find(k => s[k]);
      console.log([type, ...["lint", "test", "build"].filter(k => s[k])].filter(Boolean).join("\n"));
    ' "$manifest" 2>"$manifest_log")
    if [ "$?" -ne 0 ]; then printf 'Invalid manifest: %q (see %s)\n' "$manifest" "$manifest_log" >&2; setup_failed=1; continue; fi
    pm=npm search=$directory pm_valid=1
    while :; do
      if [ -f "$search/package.json" ]; then
        declared=$(node -e 'const fs=require("fs"); const p=JSON.parse(fs.readFileSync(process.argv[1],"utf8")); console.log(p.packageManager || "")' "$search/package.json" 2>/dev/null)
        if [ "$?" -ne 0 ]; then setup_failed=1; pm_valid=0; break; fi
        if [ -n "$declared" ]; then
          case "$declared" in npm@*) pm=npm;; pnpm@*) pm=pnpm;; yarn@*) pm=yarn;; bun@*) pm=bun;; *) echo "Unsupported packageManager: $declared" >&2; setup_failed=1; pm_valid=0; break;; esac
          break
        fi
      fi
      if [ -f "$search/pnpm-lock.yaml" ]; then pm=pnpm; break
      elif [ -f "$search/yarn.lock" ]; then pm=yarn; break
      elif [ -f "$search/bun.lock" ] || [ -f "$search/bun.lockb" ]; then pm=bun; break
      elif [ -f "$search/package-lock.json" ]; then pm=npm; break; fi
      [ "$search" != . ] && [ "$search" != / ] || break
      search=$(dirname -- "$search")
    done
    [ "$pm_valid" -eq 1 ] || continue
    while IFS= read -r script; do
      [ -n "$script" ] || continue
      run "$directory" "$script" "$pm" run "$script"
    done <<< "$scripts"
    if ! [[ $scripts =~ (^|$'\n')(typecheck|type-check|tsc)($|$'\n') ]] && [ -f "$directory/tsconfig.json" ] && [ -x "$directory/node_modules/.bin/tsc" ]; then
      run "$directory" typecheck ./node_modules/.bin/tsc --noEmit
    fi
  done <"$paths"
fi
[ "$setup_failed" -eq 0 ] || exit 2
if [ "$ran" -eq 0 ]; then echo "No checks found. Set CHECK_COMMANDS or add package scripts."; exit 2; fi
if [ "$failed" -eq 0 ]; then echo "All $ran checks passed."
else echo "Some checks FAILED ($ran executed)."; fi
exit "$failed"
