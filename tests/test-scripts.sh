#!/usr/bin/env bash
# Regression tests for the bundled scripts. Each case builds a throwaway git
# repository, runs a script against it and checks the exit code and output.
# Fixture code is written from here (not committed as .ts/.sql files) so the
# scanner does not flag this repository's own test data.
set -u

root="$(cd "$(dirname "$0")/.." && pwd)"
scan="$root/skills/senior-engineer-guardrails/scripts/scan-ai-smells.sh"
check="$root/skills/senior-engineer-guardrails/scripts/check.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

failures=0
pass() { echo "ok    $1"; }
fail() { echo "FAIL  $1"; failures=$((failures + 1)); }

new_repo() {
  local dir="$work/$1"
  mkdir -p "$dir"
  git -C "$dir" init -q
  git -C "$dir" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m init
  echo "$dir"
}

# Runs a script in a repo; sets $out and $status.
run_in() {
  local dir="$1"; shift
  out="$(cd "$dir" && "$@" 2>&1)"
  status=$?
}

expect_status() {
  if [ "$status" -eq "$2" ]; then pass "$1"; else fail "$1 (exit $status, want $2)"; printf '%s\n' "$out" | sed 's/^/      /'; fi
}

expect_hit() {
  if printf '%s\n' "$out" | grep -qF -- "== $1"; then pass "flags: $1"; else fail "flags: $1"; fi
}

# --- scan-ai-smells.sh: every pattern fires on bad code ---------------------
bad="$(new_repo bad)"
mkdir -p "$bad/app/api/orders" "$bad/app/orders" "$bad/components" "$bad/migrations"
cat > "$bad/app/api/orders/route.ts" <<'EOF'
export async function GET(id: string, body: unknown) {
  try { await load(); } catch { return []; }
  const r = await pool.query(`select * from orders where id = ${id}`);
  await pool.query('BEGIN');
  console.log('order', body);
  const h = scryptSync('a', 'b', 64);
  const conn = { rejectUnauthorized: false };
  let v: any = r;
  // ... rest of code unchanged
  return Response.json({ error: e.message });
}
EOF
cat > "$bad/app/orders/page.tsx" <<'EOF'
'use client';
import { useRouter } from 'next/router';
export default function Page() {
  // eslint-disable-next-line react-hooks/exhaustive-deps
  localStorage.setItem('token', t);
}
EOF
cat > "$bad/components/Form.test.tsx" <<'EOF'
const n = z.coerce.number();
it.skip('saves', () => {});
EOF
echo "const k = process.env.NEXT_PUBLIC_STRIPE_SECRET;" > "$bad/components/config.ts"
echo "CREATE INDEX orders_user_idx ON orders (user_id);" > "$bad/migrations/001_idx.sql"
touch "$bad/Orders_v2.ts" "$bad/PLAN.md" "$bad/NOTES.md"

run_in "$bad" bash "$scan"
expect_status "scan exits 1 on bad code" 1
for title in \
  "Elision placeholder written into a file" \
  "catch that returns a default (silent fallback)" \
  "Error details sent to the client" \
  "TypeScript/lint escape hatches" \
  "SELECT * (return explicit columns)" \
  "SQL built by string interpolation" \
  "BEGIN on a pool / manual connect (use the transaction helper)" \
  "Synchronous crypto or I/O in server code" \
  "console.log in server code (log ids, not payloads)" \
  "Possible secret exposed to the browser" \
  "TLS verification disabled" \
  "Token stored in localStorage" \
  "'use client' on a page or layout" \
  "Pages Router API inside the App Router" \
  "Empty string coerced to 0" \
  "Disabled hook lint rule" \
  "Skipped or focused tests" \
  "CREATE INDEX without CONCURRENTLY (locks writes on large tables)" \
  "Stray / duplicate files (delete, or edit the original in place)"
do
  expect_hit "$title"
done
for f in Orders_v2.ts PLAN.md NOTES.md; do
  if printf '%s\n' "$out" | grep -qE "^ +$f\$"; then pass "stray file listed: $f"; else fail "stray file listed: $f"; fi
done

# --- scan-ai-smells.sh: clean code and empty changes pass --------------------
good="$(new_repo good)"
mkdir -p "$good/app/api/orders" "$good/migrations"
cat > "$good/app/api/orders/route.ts" <<'EOF'
export async function GET(id: string) {
  const { rows } = await db.query('select id, status from orders where id = $1', [id]);
  return Response.json(rows);
}
EOF
echo "CREATE INDEX CONCURRENTLY orders_user_idx ON orders (user_id);" > "$good/migrations/001_idx.sql"
echo "# Notes for users" > "$good/README.md"
run_in "$good" bash "$scan"
expect_status "scan exits 0 on clean code" 0

empty="$(new_repo empty)"
run_in "$empty" bash "$scan"
expect_status "scan exits 0 with no changes" 0

# --- check.sh: reports each command's own exit code --------------------------
checks="$(new_repo checks)"
run_in "$checks" env CHECK_COMMANDS=$'true\ntrue' TMPDIR="$work" bash "$check"
expect_status "check.sh exits 0 when all checks pass" 0

run_in "$checks" env CHECK_COMMANDS=$'true\nexit 3' TMPDIR="$work" bash "$check"
expect_status "check.sh exits 1 when a check fails" 1
if printf '%s\n' "$out" | grep -qF "FAIL  check-2 (exit 3)"; then pass "check.sh reports the failing exit code"; else fail "check.sh reports the failing exit code"; fi

cat > "$checks/package.json" <<'EOF'
{ "scripts": { "lint": "node -e \"process.exit(2)\"", "test": "node -e \"process.exit(0)\"" } }
EOF
run_in "$checks" env TMPDIR="$work" bash "$check"
expect_status "check.sh exits 1 when a package script fails" 1
if printf '%s\n' "$out" | grep -qF "FAIL  lint (exit 2)" && printf '%s\n' "$out" | grep -qF "PASS  test"; then
  pass "check.sh runs package.json scripts"
else
  fail "check.sh runs package.json scripts"
fi

rm "$checks/package.json"
run_in "$checks" env TMPDIR="$work" bash "$check"
expect_status "check.sh exits 2 when there is nothing to run" 2

echo
if [ "$failures" -eq 0 ]; then
  echo "All script tests passed."
else
  echo "$failures script test(s) failed."
fi
exit "$failures"
