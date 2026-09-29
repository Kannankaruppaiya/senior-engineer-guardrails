#!/usr/bin/env bash
# Flags common AI-agent mistakes in files changed on the current branch and in
# the working tree. It is a heuristic grep, not proof: fix each hit, or state
# why it is intentional.
#
# Usage: scan-ai-smells.sh [base-ref]
#   base-ref defaults to the merge-base with origin/main (or origin/master),
#   falling back to HEAD (working-tree changes only).
# Environment:
#   SMELL_EXCLUDE  extended regex of paths to skip (default skips docs and markdown)
#   SERVER_PATHS   regex for server-side code   (default: server/, api/, app/api/, pages/api/, src/server/, backend/)
#   CLIENT_PATHS   regex for client-side code   (default: app/, components/, src/components/, src/app/, hooks/)
set -u

cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" || exit 2

base="${1:-}"
if [ -z "$base" ]; then
  for b in origin/main origin/master; do
    if git rev-parse --verify -q "$b" >/dev/null; then base="$(git merge-base HEAD "$b")"; break; fi
  done
  [ -z "$base" ] && base="HEAD"
fi

exclude="${SMELL_EXCLUDE:-(^|/)(docs?|reports?)/|\.md$|(^|/)(package-lock\.json|pnpm-lock\.yaml|yarn\.lock)$|(^|/)scan-ai-smells\.sh$}"
server_re="${SERVER_PATHS:-^(server|api|app/api|pages/api|src/server|src/app/api|backend)/}"
client_re="${CLIENT_PATHS:-^(app|components|hooks|src/app|src/components|src/hooks|src/pages)/}"

files=$(
  { git diff --name-only --diff-filter=d "$base" -- 2>/dev/null; git ls-files --others --exclude-standard; } \
    | sort -u | grep -Ev "$exclude" || true
)

if [ -z "$files" ]; then
  echo "No changed files to scan (base: $base)."
  exit 0
fi

code=$(printf '%s\n' "$files" | grep -E '\.(ts|tsx|js|jsx|mjs|cjs|sql)$' || true)
server=$(printf '%s\n' "$code" | grep -E "$server_re" || true)
client=$(printf '%s\n' "$code" | grep -E "$client_re" | grep -Ev "$server_re" || true)
migrations=$(printf '%s\n' "$files" | grep -E '(^|/)migrations?/.*\.sql$' || true)
pages=$(printf '%s\n' "$client" | grep -E '/(page|layout)\.(tsx|jsx)$' || true)

hits=0
check() {
  local title="$1" pattern="$2" list="$3"
  [ -z "$list" ] && return 0
  local out
  out=$(printf '%s\n' "$list" | xargs -r grep -HnE -- "$pattern" 2>/dev/null || true)
  if [ -n "$out" ]; then
    echo "== $title"
    printf '%s\n' "$out" | sed 's/^/   /'
    echo
    hits=1
  fi
}

check "Elision placeholder written into a file" \
  '(\.\.\.|…) *(existing|rest of|remaining|unchanged|same as before)|rest of (the )?(code|file|component|function|methods?) (unchanged|remains|here)' "$code"
check "catch that returns a default (silent fallback)" \
  'catch *(\([^)]*\))? *\{ *return *(\[\]|0|null|undefined|false|true|""|'"''"'|\{\})' "$code"
check "Error details sent to the client" \
  '(error|message|detail): *(e|err|error)\.(message|stack)|stack: *(e|err|error)\.stack' "$server"
check "TypeScript/lint escape hatches" \
  ': any\b|<any>|as any\b|@ts-ignore|@ts-nocheck|eslint-disable' "$code"
check "SELECT * (return explicit columns)" \
  '[Ss][Ee][Ll][Ee][Cc][Tt] +\*' "$code"
check "SQL built by string interpolation" \
  '(query|execute|raw|sql)\(`[^`]*\$\{' "$server"
check "BEGIN on a pool / manual connect (use the transaction helper)" \
  "pool\.query\(['\"\`](begin|BEGIN)|pool\.connect\(" "$server"
check "Synchronous crypto or I/O in server code" \
  '\b(scryptSync|pbkdf2Sync|execSync|readFileSync|writeFileSync)\(' "$server"
check "console.log in server code (log ids, not payloads)" \
  'console\.log\(' "$server"
check "Possible secret exposed to the browser" \
  '(NEXT_PUBLIC|VITE|REACT_APP)_[A-Z_]*(SECRET|PRIVATE|TOKEN|PASSWORD|DATABASE|SERVICE_ROLE)' "$files"
check "TLS verification disabled" \
  'rejectUnauthorized: *false|NODE_TLS_REJECT_UNAUTHORIZED' "$code"
check "Token stored in localStorage" \
  'localStorage\.setItem\([^)]*(token|jwt|session)' "$client"
check "'use client' on a page or layout" \
  "^['\"]use client['\"]" "$pages"
check "Pages Router API inside the App Router" \
  'getServerSideProps|getStaticProps|from .next/router.' "$(printf '%s\n' "$client" | grep -E '(^|/)app/' || true)"
check "Empty string coerced to 0" \
  'z\.coerce\.number\(' "$code"
check "Disabled hook lint rule" \
  'eslint-disable.*react-hooks/(exhaustive-deps|rules-of-hooks)' "$client"
check "Skipped or focused tests" \
  '\b(it|test|describe)\.(skip|only)\(|\bx(it|describe)\(' "$code"
if [ -n "$migrations" ]; then
  idx=$(printf '%s\n' "$migrations" | xargs -r grep -HniE 'create +(unique +)?index' 2>/dev/null | grep -vi 'concurrently' || true)
  if [ -n "$idx" ]; then
    echo "== CREATE INDEX without CONCURRENTLY (locks writes on large tables)"
    printf '%s\n' "$idx" | sed 's/^/   /'
    echo
    hits=1
  fi
fi

stray=$(printf '%s\n' "$files" \
  | grep -Ei '(_v[0-9]+|[-_]new|[-_]old|[-_]copy|[-_]backup)(\.[a-z0-9]+)+$|\.(bak|orig|tmp)$|(^|/)(PLAN|NOTES|SUMMARY|TODO|SCRATCH)\.md$|(^|/)debug[-_][^/]*$' || true)
if [ -n "$stray" ]; then
  echo "== Stray / duplicate files (delete, or edit the original in place)"
  printf '%s\n' "$stray" | sed 's/^/   /'
  echo
  hits=1
fi

if [ "$hits" -eq 0 ]; then
  echo "No AI-smell patterns found in changed files (base: $base)."
else
  echo "Review each hit: fix it, or state in your summary why it is intentional."
fi
exit "$hits"
