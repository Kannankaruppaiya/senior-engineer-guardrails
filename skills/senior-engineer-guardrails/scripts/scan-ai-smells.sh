#!/usr/bin/env bash
# Heuristic review aid. Exit 0: clean, 1: findings, 2: invocation/read error.
# scan-ai-smells.sh [base-ref | --staged | --all]
# A base ref means merge-base with HEAD plus staged, unstaged and untracked files.
# Default: origin/main, origin/master, or HEAD (working tree only).
# Scans complete current files, not only added lines; multiline syntax can escape grep.
set -u
export LC_ALL=C GIT_LITERAL_PATHSPECS=1
root=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "Not a Git repository." >&2; exit 2; }
cd "$root" || exit 2
[ "$#" -le 1 ] || { echo "Usage: $0 [base-ref | --staged | --all]" >&2; exit 2; }
mode=${1:-}
exclude=${SMELL_EXCLUDE:-(^|/)(docs?|reports?)/|\.md$|(^|/)(package-lock\.json|pnpm-lock\.yaml|yarn\.lock)$|(^|/)scan-ai-smells\.sh$}
# Match conventional backend/frontend directories at any monorepo depth.
server_re=${SERVER_PATHS:-(^|/)(server|api|backend)/|(^|/)src/server/}
client_re=${CLIENT_PATHS:-(^|/)(app|components|hooks|pages)/}
for re in "$exclude" "$server_re" "$client_re"; do
  printf '' | grep -E -- "$re" >/dev/null 2>&1
  [ "$?" -le 1 ] || { echo "Invalid path regex." >&2; exit 2; }
done
tmp=$(mktemp -d "${TMPDIR:-/tmp}/guardrails-scan.XXXXXXXX") || exit 2
trap 'rm -f -- "$tmp/paths"; rmdir -- "$tmp"' EXIT
case "$mode" in
  --staged) git diff --cached --name-only -z --diff-filter=ACMRTUXB -- >"$tmp/paths" || exit 2 ;;
  --all) git ls-files -z --cached --others --exclude-standard >"$tmp/paths" || exit 2 ;;
  --*) echo "Unknown option: $mode" >&2; exit 2 ;;
  *)
    base=$mode
    if [ -z "$base" ]; then
      for candidate in origin/main origin/master HEAD; do
        if git rev-parse --verify -q "$candidate^{commit}" >/dev/null; then base=$candidate; break; fi
      done
    fi
    base_commit=$(git rev-parse --verify --end-of-options "$base^{commit}" 2>/dev/null) || { echo "Invalid base ref: $base" >&2; exit 2; }
    merge_base=$(git merge-base HEAD "$base_commit") || { echo "No merge base: $base" >&2; exit 2; }
    git diff --name-only -z --diff-filter=ACMRTUXB "$merge_base" -- >"$tmp/paths" || exit 2
    git ls-files --others --exclude-standard -z >>"$tmp/paths" || exit 2
    ;;
esac
files=() code=() server=() client=() migrations=() pages=() app_client=()
while IFS= read -r -d '' file; do
  # Array deduplication keeps newline/space/quote/glob/leading-dash paths literal.
  duplicate=0
  for seen in "${files[@]}"; do [ "$seen" != "$file" ] || { duplicate=1; break; }; done
  [ "$duplicate" -eq 0 ] || continue
  [[ ! $file =~ $exclude ]] || continue
  # Never inspect local credential material, even with custom exclusions.
  case "$file" in .env.example|*/.env.example) ;; .env|.env.*|*/.env|*/.env.*|*.pem|*.key|*/credentials.json) continue;; esac
  if [ "$mode" = --staged ]; then
    index_mode=$(git ls-files -s -- "$file") || exit 2
    case "$index_mode" in 120000*) printf 'Refusing index symlink: %q\n' "$file" >&2; exit 2;; esac
  else
    [ -e "$file" ] || continue
    [ ! -L "$file" ] || { printf 'Refusing symlink: %q\n' "$file" >&2; exit 2; }
    [ -f "$file" ] && [ -r "$file" ] || { printf 'Unreadable file: %q\n' "$file" >&2; exit 2; }
  fi
  files+=("$file")
  if [[ $file =~ \.(ts|tsx|js|jsx|mjs|cjs|sql)$ ]]; then
    code+=("$file")
    if [[ $file =~ $server_re ]]; then server+=("$file")
    elif [[ $file =~ $client_re ]]; then
      client+=("$file")
      [[ ! $file =~ /(page|layout)\.(tsx|jsx)$ ]] || pages+=("$file")
      [[ ! $file =~ (^|/)app/ ]] || app_client+=("$file")
    fi
  fi
  [[ ! $file =~ (^|/)migrations?/.*\.sql$ ]] || migrations+=("$file")
done <"$tmp/paths"
if [ "${#files[@]}" -eq 0 ]; then echo "No changed files to scan."; exit 0; fi
hits=0
check() {
  local title=$1 pattern=$2 file out status
  shift 2
  for file in "$@"; do
    # --staged must inspect the index snapshot, not unstaged replacements.
    if [ "$mode" = --staged ]; then
      out=$(git show ":$file") || exit 2
      out=$(printf '%s\n' "$out" | grep -nE -- "$pattern")
    else
      out=$(grep -nE -- "$pattern" "$file")
    fi
    status=$?
    [ "$status" -le 1 ] || { printf 'Scan failed: %q\n' "$file" >&2; exit 2; }
    if [ "$status" -eq 0 ]; then
      if [ "$title" = 'Possible secret exposed to the browser' ]; then
        printf '== %s\n   file: %q\n   matching content redacted\n\n' "$title" "$file"
      else
        printf '== %s\n   file: %q\n%s\n\n' "$title" "$file" "$out"
      fi
      hits=1
    fi
  done
}
check "Elision placeholder written into a file" \
  '(\.\.\.|…) *(existing|rest of|remaining|unchanged|same as before)|rest of (the )?(code|file|component|function|methods?) (unchanged|remains|here)' "${code[@]}"
check "catch that returns a default (silent fallback)" \
  'catch *(\([^)]*\))? *\{ *return *(\[\]|0|null|undefined|false|true|""|'"''"'|\{\})' "${code[@]}"
check "Error details sent to the client" \
  '(error|message|detail): *(e|err|error)\.(message|stack)|stack: *(e|err|error)\.stack' "${server[@]}"
check "TypeScript/lint escape hatches" \
  ':[[:space:]]*any\b|<any>|as[[:space:]]+any\b|@ts-ignore|@ts-nocheck|eslint-disable' "${code[@]}"
check "SELECT * (return explicit columns)" \
  '[Ss][Ee][Ll][Ee][Cc][Tt] +\*' "${code[@]}"
check "SQL built by string interpolation" \
  '(query|execute|raw|sql)\(`[^`]*\$\{' "${server[@]}"
check "BEGIN on a pool / manual connect (use the transaction helper)" \
  "pool\.query\(['\"\`](begin|BEGIN)|pool\.connect\(" "${server[@]}"
check "Synchronous crypto or I/O in server code" \
  '\b(scryptSync|pbkdf2Sync|execSync|readFileSync|writeFileSync)\(' "${server[@]}"
check "console.log in server code (log ids, not payloads)" \
  'console\.log\(' "${server[@]}"
check "Possible secret exposed to the browser" \
  '(NEXT_PUBLIC|VITE|REACT_APP)_[A-Z_]*(SECRET|PRIVATE|TOKEN|PASSWORD|DATABASE|SERVICE_ROLE)' "${files[@]}"
check "TLS verification disabled" \
  'rejectUnauthorized: *false|NODE_TLS_REJECT_UNAUTHORIZED' "${code[@]}"
check "Token stored in localStorage" \
  'localStorage\.setItem\([^)]*(token|jwt|session)' "${client[@]}"
check "'use client' on a page or layout" \
  "^['\"]use client['\"]" "${pages[@]}"
check "Pages Router API inside the App Router" \
  'getServerSideProps|getStaticProps|from .next/router.' "${app_client[@]}"
check "Empty string coerced to 0" \
  'z\.coerce\.number\(' "${code[@]}"
check "Disabled hook lint rule" \
  'eslint-disable.*react-hooks/(exhaustive-deps|rules-of-hooks)' "${client[@]}"
check "Skipped or focused tests" \
  '\b(it|test|describe)\.(skip|only)\(|\bx(it|describe)\(' "${code[@]}"

# PostgreSQL-specific heuristic: other dialects may intentionally omit CONCURRENTLY.
for file in "${migrations[@]}"; do
  if [ "$mode" = --staged ]; then content=$(git show ":$file") || exit 2
  else content=$(cat -- "$file") || exit 2; fi
  idx=$(printf '%s\n' "$content" | grep -niE 'create +(unique +)?index')
  status=$?
  [ "$status" -le 1 ] || exit 2
  idx=$(printf '%s\n' "$idx" | grep -vi concurrently)
  if [ -n "$idx" ]; then
    printf '== CREATE INDEX without CONCURRENTLY\n   file: %q\n%s\n' "$file" "$idx"
    hits=1
  fi
done
for file in "${files[@]}"; do
  if [[ $file =~ (_v[0-9]+|[-_]new|[-_]old|[-_]copy|[-_]backup)(\.[a-zA-Z0-9]+)+$|\.(bak|orig|tmp)$|(^|/)(PLAN|NOTES|SUMMARY|TODO|SCRATCH)\.md$|(^|/)debug[-_][^/]*$ ]]; then
    printf '== Possible stray / duplicate file (review intent)\n   %q\n' "$file"
    hits=1
  fi
done
if [ "$hits" -eq 0 ]; then echo "No AI-smell patterns found."
else echo "Review each hit; fix it or document why it is intentional."; fi
exit "$hits"
