#!/usr/bin/env bash
# Behavioral tests execute real scripts against disposable Git repositories.
set -eu
suite=$(cd -- "$(dirname -- "$0")/.." && pwd)
scan="$suite/skills/senior-engineer-guardrails/scripts/scan-ai-smells.sh"
check="$suite/skills/senior-engineer-guardrails/scripts/check.sh"
fixtures=$(mktemp -d "${TMPDIR:-/tmp}/guardrails-tests.XXXXXXXX")
# Cleanup is restricted to the exact temporary directory created above.
trap 'case "$fixtures" in */guardrails-tests.*) rm -rf -- "$fixtures";; esac' EXIT
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
export GIT_AUTHOR_NAME=Fixture GIT_AUTHOR_EMAIL=fixture@example.invalid
export GIT_COMMITTER_NAME=Fixture GIT_COMMITTER_EMAIL=fixture@example.invalid
export GIT_LITERAL_PATHSPECS=1
mkdir "$fixtures/logs"
export TMPDIR="$fixtures/logs"
unset CHECK_COMMANDS CHECK_PROJECTS SMELL_EXCLUDE SERVER_PATHS CLIENT_PATHS || true
count=0 skips=0
repo() {
  count=$((count + 1))
  mkdir "$fixtures/repo-$count"
  cd "$fixtures/repo-$count"
  git init -q
  git -c core.hooksPath=/dev/null commit -qm initial --allow-empty
}
expect() {
  local wanted=$1 status=0
  shift
  "$@" >"$fixtures/output" 2>&1 || status=$?
  if [ "$status" -ne "$wanted" ]; then
    cat "$fixtures/output"
    printf 'Expected exit %s, got %s: %s\n' "$wanted" "$status" "$*" >&2
    exit 1
  fi
}
contains() { grep -Fq -- "$1" "$fixtures/output" || { cat "$fixtures/output"; echo "Missing: $1" >&2; exit 1; }; }
pass() { echo "PASS $count: $1"; }
commit() { git add -- "$@"; git -c core.hooksPath=/dev/null commit -qm fixture; }

repo
expect 0 bash "$scan"
contains 'No changed files'
pass 'clean working tree'

repo
mkdir -p apps/api/src apps/web/src/app apps/web/src/components
printf 'console.log(body);\n' >apps/api/src/handler.ts
printf "'use client';\n" >apps/web/src/app/page.tsx
printf 'localStorage.setItem("token", value);\n' >apps/web/src/components/Form.tsx
expect 1 bash "$scan"
contains 'console.log in server code'; contains "'use client' on a page"; contains 'Token stored'
pass 'monorepo backend and frontend classification'

repo
mkdir -p 'apps/api/space folder'
for name in 'with space.ts' "it's.ts" '[glob].ts' '-dash.ts' 'தமிழ்.ts'; do
  printf 'console.log(body);\n' >"apps/api/space folder/$name"
done
printf 'const value: any = 1;\n' > ./-root.ts
expect 1 bash "$scan"
contains 'console.log in server code'; contains 'TypeScript/lint escape'
[ "$(grep -c 'file:' "$fixtures/output")" -eq 6 ]
pass 'literal spaces, apostrophes, globs, Unicode and leading dashes'

case "$(uname -s)" in
  MINGW*|MSYS*) skips=$((skips + 1)); echo 'SKIP: newline/double-quote filenames unsupported by Windows filesystem';;
  *)
    repo
    mkdir -p apps/api
    printf 'console.log(body);\n' >"apps/api/line"$'\n'"break.ts"
    printf 'console.log(body);\n' >'apps/api/"quote".ts'
    expect 1 bash "$scan"
    [ "$(grep -c 'file:' "$fixtures/output")" -eq 2 ]
    pass 'newline and double-quote filenames'
    ;;
esac

repo
printf 'const value = 1;\n' >code.ts; commit code.ts
printf 'const value: any = 1;\n' >code.ts; git add code.ts
printf 'const value = 2;\n' >code.ts
expect 1 bash "$scan" --staged; contains 'TypeScript/lint escape'
expect 0 bash "$scan" HEAD
pass 'staged snapshot differs from working tree'

repo
printf 'const value: any = 1;\n' >code.ts; git add code.ts
rm code.ts
expect 1 bash "$scan" --staged
pass 'staged file remains scanable after working-tree deletion'

repo
printf 'const value = 1;\n' >code.ts; commit code.ts
printf 'const value: any = 1;\n' >code.ts
expect 0 bash "$scan" --staged
expect 1 bash "$scan" HEAD
pass 'unstaged selection'

repo
printf 'const value: any = 1;\n' >deleted.ts; commit deleted.ts
rm deleted.ts
expect 0 bash "$scan"
pass 'deleted file ignored'

repo
mkdir -p apps/api
printf 'console.log(body);\n' >plain.ts; commit plain.ts
git mv plain.ts apps/api/renamed.ts
expect 1 bash "$scan"
contains 'console.log in server code'
pass 'renamed target classification'

repo
git branch base
printf 'const value: any = 1;\n' >branch.ts; commit branch.ts
expect 1 bash "$scan" base
expect 0 bash "$scan" HEAD
expect 1 bash "$scan" --all
pass 'committed branch changes and all-file mode'

repo
git branch base; git switch -q -c feature
printf 'const value = 1;\n' >feature.ts; commit feature.ts
git switch -q base
printf 'const value: any = 1;\n' >base-only.ts; commit base-only.ts
git switch -q feature
expect 0 bash "$scan" base
pass 'merge-base excludes changes unique to base branch'

repo
expect 2 bash "$scan" invalid-ref
expect 2 bash "$scan" --unknown
expect 2 bash "$scan" HEAD extra
expect 2 env SERVER_PATHS='[' bash "$scan"
pass 'invalid ref, options, arguments and regex fail visibly'

repo
mkdir -p services
printf 'console.log(body);\n' >services/worker.ts
expect 0 bash "$scan"
expect 1 env SERVER_PATHS='^services/' bash "$scan"
expect 0 env SERVER_PATHS='^services/' SMELL_EXCLUDE='worker\.ts$' bash "$scan"
pass 'custom server paths and exclusions'

repo
mkdir -p migrations docs
printf 'CREATE INDEX idx ON items(id);\n' >migrations/001.sql
expect 1 bash "$scan"; contains 'CREATE INDEX without CONCURRENTLY'
printf 'CREATE INDEX CONCURRENTLY idx ON items(id);\n' >migrations/001.sql
printf 'const value: any = 1;\n' >docs/sample.ts
expect 0 bash "$scan"
pass 'migration detection and documented exclusions'

repo
printf 'safe\n' >Widget_v2.ts
expect 1 bash "$scan"; contains 'Possible stray'
pass 'stray-file review signal'

repo
printf 'VITE_SECRET=synthetic-private-value\n' >.env.local
expect 0 bash "$scan" --all
printf 'VITE_SECRET=placeholder\n' >.env.example
expect 1 bash "$scan" --all
contains 'Possible secret exposed'
if grep -q placeholder "$fixtures/output"; then echo 'Secret line was not redacted' >&2; exit 1; fi
pass 'credential files excluded, public example scanned'

case "$(uname -s)" in
  MINGW*|MSYS*) skips=$((skips + 1)); echo 'SKIP: symlink creation requires Windows privilege';;
  *)
    repo
    printf 'const value: any = 1;\n' >"$fixtures/outside.ts"
    ln -s "$fixtures/outside.ts" link.ts
    expect 2 bash "$scan" --all
    contains 'Refusing symlink'
    git add link.ts
    expect 2 bash "$scan" --staged
    contains 'Refusing index symlink'
    pass 'working tree and index symlinks refused'
    ;;
esac

repo
mkdir -p apps/api
cat >apps/api/patterns.ts <<'CODE'
// ... rest of code unchanged
try {} catch { return []; }
return {error: err.message, stack: err.stack};
const value: any = 1;
const sql = 'SELECT * FROM items';
pool.query(`select id from items where id = ${id}`);
pool.query('BEGIN');
readFileSync('file');
console.log(body);
const VITE_SECRET = 'placeholder';
const options = {rejectUnauthorized: false};
const schema = z.coerce.number();
test.only('case', () => {});
CODE
expect 1 bash "$scan"
for title in 'Elision placeholder' 'silent fallback' 'Error details' 'TypeScript/lint' 'SELECT *' 'SQL built' 'BEGIN on a pool' 'Synchronous crypto' 'console.log' 'Possible secret' 'TLS verification' 'Empty string' 'Skipped or focused'; do contains "$title"; done
pass 'server and general smell patterns preserved'

repo
mkdir -p apps/web/app
cat >apps/web/app/page.tsx <<'CODE'
'use client';
import Router from 'next/router';
localStorage.setItem('jwt', value);
// eslint-disable react-hooks/exhaustive-deps
CODE
expect 1 bash "$scan"
contains 'Pages Router API'; contains 'Disabled hook lint'; contains 'Token stored'; contains "'use client'"
pass 'frontend pattern coverage'

repo
expect 2 bash "$check"
contains 'No checks found'
pass 'no checks is not success'

repo
expect 1 env CHECK_COMMANDS=$'exit 7\nprintf continued' bash "$check"
contains 'exit 7'; contains 'PASS'; contains '2 executed'
expect 1 env CHECK_COMMANDS='false | cat' bash "$check"
pass 'failure statuses preserved and later checks still run'

repo
expect 0 env CHECK_COMMANDS=$'   \n\nprintf custom-ok' bash "$check"
contains 'All 1 checks passed'
first=$(sed -n 's/^Logs: //p' "$fixtures/output")
expect 0 env CHECK_COMMANDS='printf second-ok' bash "$check"
second=$(sed -n 's/^Logs: //p' "$fixtures/output")
[ "$first" != "$second" ]; grep -q custom-ok "$first/check-1.log"; grep -q second-ok "$second/check-1.log"
pass 'unique logs and whitespace command handling'

repo
mkdir -p apps/api 'apps/web space' packages/core node_modules/ignored dist/ignored
printf '{"scripts":{"lint":"fixture", "build":"fixture"}}\n' >package.json
printf '{"scripts":{"type-check":"fixture","test":"fixture"}}\n' >apps/api/package.json
printf '{"scripts":{"tsc":"fixture","lint":"fixture"}}\n' >'apps/web space/package.json'
printf '{"scripts":{"test":"fixture"}}\n' >packages/core/package.json
printf 'invalid-json' >node_modules/ignored/package.json
printf 'invalid-json' >dist/ignored/package.json
mkdir bin
cat >bin/npm <<'MOCK'
#!/usr/bin/env bash
printf '%s|%s|%s\n' "${PWD##*/}" "$*" "$CI" >>"$CALLS"
[ "$1" = run ] || exit 8
case "$PWD:$2" in *api:test) exit 9;; esac
MOCK
chmod +x bin/npm
export CALLS="$fixtures/calls"
expect 1 env PATH="$PWD/bin:$PATH" bash "$check"
contains 'exit 9'; contains '7 executed'
[ "$(wc -l <"$CALLS")" -eq 7 ]; grep -Fq 'api|run type-check|1' "$CALLS"; grep -Fq 'core|run test|1' "$CALLS"
pass 'root and nested packages, aliases, build, exclusions, failures and CI mode'

for manager in pnpm yarn bun npm; do
  repo
  mkdir -p apps/api bin
  printf '{"packageManager":"%s@1.0.0"}\n' "$manager" >package.json
  printf '{"scripts":{"test":"fixture"}}\n' >apps/api/package.json
  printf '#!/usr/bin/env bash\nprintf "manager=%s args=%%s\\n" "$*"\n' "$manager" >"bin/$manager"
  chmod +x "bin/$manager"
  expect 0 env PATH="$PWD/bin:$PATH" bash "$check"
  logdir=$(sed -n 's/^Logs: //p' "$fixtures/output")
  grep -Fq "manager=$manager args=run test" "$logdir/check-1.log"
  pass "inherited $manager packageManager declaration"
done

repo
printf '{not JSON' >package.json
expect 2 bash "$check"; contains 'Invalid manifest'
printf '{"scripts":{"test":42}}' >package.json
expect 2 bash "$check"
printf '{"packageManager":"unknown@1","scripts":{"test":"fixture"}}' >package.json
expect 2 bash "$check"; contains 'Unsupported packageManager'
expect 2 env CHECK_PROJECTS=missing bash "$check"; contains 'Missing package.json'
pass 'malformed manifests and missing/unsupported setup are not green'

repo
mkdir -p apps/api bin
printf '{"scripts":{"test":"fixture"}}' >apps/api/package.json
printf 'broken root' >package.json
printf '#!/usr/bin/env bash\nexit 0\n' >bin/npm; chmod +x bin/npm
expect 0 env CHECK_PROJECTS=apps/api CHECK_COMMANDS='exit 0' PATH="$PWD/bin:$PATH" bash "$check"
contains 'All 1 checks passed'
pass 'custom commands override project discovery'

repo
mkdir -p apps/api bin
printf '{"scripts":{"test":"fixture"}}' >apps/api/package.json
printf '#!/usr/bin/env bash\nprintf "pnpm selected\\n"\n' >bin/pnpm; chmod +x bin/pnpm
touch pnpm-lock.yaml
expect 0 env CHECK_PROJECTS=apps/api PATH="$PWD/bin:$PATH" bash "$check"
logdir=$(sed -n 's/^Logs: //p' "$fixtures/output")
grep -q 'pnpm selected' "$logdir/check-1.log"
pass 'explicit project selection inherits root lockfile'

repo
mkdir -p node_modules/.bin
printf '{}' >package.json; printf '{}' >tsconfig.json
printf '#!/usr/bin/env bash\n[ "$1" = --noEmit ] || exit 9\n' >node_modules/.bin/tsc
chmod +x node_modules/.bin/tsc
expect 0 bash "$check"; contains 'typecheck'
pass 'local TypeScript fallback'

repo
env CHECK_COMMANDS='printf first' bash "$check" >"$fixtures/parallel-1" 2>&1 &
first_pid=$!
env CHECK_COMMANDS='printf second' bash "$check" >"$fixtures/parallel-2" 2>&1 &
second_pid=$!
wait "$first_pid"; wait "$second_pid"
first=$(sed -n 's/^Logs: //p' "$fixtures/parallel-1")
second=$(sed -n 's/^Logs: //p' "$fixtures/parallel-2")
[ "$first" != "$second" ]
grep -q first "$first/check-1.log"; grep -q second "$second/check-1.log"
pass 'concurrent invocation logs do not collide'

echo "Completed $count behavioral fixtures; $skips platform-specific skips."
