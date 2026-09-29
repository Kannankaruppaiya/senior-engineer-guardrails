# Backend: AI habits vs senior practice

Applies to API routes (Next.js route handlers, Express/Fastify/Hono handlers,
server actions), services, data-access code and SQL migrations. Examples use
TypeScript, `zod` and node-postgres (`pg`); the principles carry to other stacks.
Where an example names a helper (`requireUser`, `withTransaction`), use the
project's own equivalent found in Step 0.

## Contents
1. Handler shape
2. Errors propagate; no silent defaults
3. Validate at the boundary
4. Connections and transactions
5. Races: let the database enforce invariants
6. Queries: N+1, SELECT *, pagination
7. Async work, crypto, retries
8. Logging and error responses
9. Configuration
10. Numbers, units, dates and time zones
11. Migrations

---

## 1. Handler shape

A handler is thin: **authenticate → authorise → validate → call service → map errors**.

```ts
// AI typically writes: no auth, trusts the body, SQL in the handler
export async function PATCH(req: Request, { params }: { params: { id: string } }) {
  const body = await req.json();
  await pool.query(`UPDATE orders SET status = '${body.status}' WHERE id = '${params.id}'`);
  return Response.json({ ok: true });
}
```

```ts
// Senior writes
const UpdateOrder = z.object({ status: z.enum(['pending', 'paid', 'cancelled']) }).strict();

export async function PATCH(req: Request, ctx: { params: Promise<{ id: string }> }) {
  const user = await requireUser();                     // 401 if no session
  if (user instanceof Response) return user;

  const { id } = await ctx.params;
  const parsed = UpdateOrder.safeParse(await req.json().catch(() => null));
  if (!parsed.success) return Response.json({ error: 'Invalid request.' }, { status: 400 });

  try {
    await orders.updateStatus(user.id, id, parsed.data.status);   // service checks ownership
  } catch (err) {
    if (err instanceof NotFoundOrForbidden) return Response.json({ error: 'Not found.' }, { status: 404 });
    throw err;                                            // becomes a 500 and is logged
  }
  return Response.json({ ok: true });
}
```

Why: the handler is the trust boundary. Middleware is not a security boundary on
its own (Next.js CVE-2025-29927 bypassed it), and server actions are public POST
endpoints even when no button calls them. Every entry point checks the session
and the record-level permission itself. Returning 404 for "exists but not yours"
avoids disclosing that the record exists.

## 2. Errors propagate; no silent defaults

The most documented AI backend smell of 2026 is the silent fallback.

```ts
// AI
async function listInvoices(userId: string) {
  try { return await repo.listInvoices(userId); }
  catch { return []; }                 // DB outage now looks like "no invoices"
}
```

```ts
// Senior: let it throw; the edge maps known cases, the rest is a 500 + log
async function listInvoices(userId: string) {
  return repo.listInvoices(userId);
}
```

- Catch only what you can handle (a known error class, a specific DB error code).
- Never return 200 with `{ error }`. 4xx for caller mistakes, 5xx for server faults.
- A fallback value is fine only when it is a stated product rule, with a comment
  saying so — never to make an error disappear.
- Prefer one shared error-mapping wrapper over ad-hoc try/catch in every handler.

## 3. Validate at the boundary

- Parse every body, query and param with a schema; use `.strict()` (or the
  equivalent) so unknown fields are rejected — this prevents mass assignment
  (`{ "role": "admin" }`).
- Identity and tenancy come from the session, never from the request payload.
- Encode allowed values and ranges in the schema, and invariants also as database
  constraints.
- Validate on the server even when the form validates in the browser.

## 4. Connections and transactions

```ts
// AI: leaks a client on error; BEGIN on the pool is not a transaction
const client = await pool.connect();
const r = await client.query('select …');
client.release();                 // skipped if query throws → pool exhaustion, app hangs

await pool.query('BEGIN');        // each pool.query may use a different connection
await pool.query('insert …');
await pool.query('COMMIT');
```

```ts
// Senior: one helper owns connect / begin / commit / rollback / release
export async function withTransaction<T>(fn: (c: PoolClient) => Promise<T>): Promise<T> {
  const client = await pool.connect();
  try {
    await client.query('begin');
    const result = await fn(client);
    await client.query('commit');
    return result;
  } catch (err) {
    await client.query('rollback');
    throw err;
  } finally {
    client.release();
  }
}

await withTransaction(async (c) => {
  await repo.insertOrder(c, order);
  await repo.reserveStock(c, order.items);
});
```

Pass the `client` into data-access functions; don't call `pool.query` inside a
transaction. If the project already has such a helper (often also setting a
row-level-security context), use it.

## 5. Races: let the database enforce invariants

```ts
// AI: check-then-insert — two parallel requests both pass the check
if (await repo.findUserByEmail(c, email)) return conflict();
await repo.insertUser(c, input);
```

```sql
-- Senior: the constraint is the check
CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS users_email_key ON users (lower(email));
```

```ts
try {
  await repo.insertUser(c, input);
} catch (err) {
  if ((err as { code?: string }).code === '23505') return conflict('Email already registered.');
  throw err;
}
```

For updates, put the condition in one statement:
`UPDATE accounts SET balance = balance - $1 WHERE id = $2 AND balance >= $1 RETURNING balance`
instead of read → check in JS → write. Test with parallel requests and assert
exactly one succeeds.

## 6. Queries: N+1, SELECT *, pagination

```ts
// AI: one query per item
const rows = await Promise.all(ids.map((id) => c.query('select * from items where order_id = $1', [id])));
```

```ts
// Senior: one query, explicit columns
const { rows } = await c.query(
  'select order_id, sku, quantity from items where order_id = any($1::uuid[])',
  [ids]
);
```

- Explicit column lists; return a DTO shaped for the caller, not the whole row.
- List endpoints have a capped `limit` and a stable order (cursor pagination for
  large sets).
- Always parameterise; never interpolate values into SQL strings.

## 7. Async work, crypto, retries

- Await every promise or hand it to something that tracks it
  (`@typescript-eslint/no-floating-promises`). Agents drop `await` on side effects
  to make handlers "faster", and the write is lost on error.
- Never use synchronous crypto (`scryptSync`, `pbkdf2Sync`) or sync file I/O on
  the request path — it blocks the event loop and turns login into a
  denial-of-service vector. Compare secrets with `crypto.timingSafeEqual`.
- Every retry has a limit, backoff with jitter, and a timeout.

## 8. Logging and error responses

```ts
// AI
console.log('creating user', body);                                       // personal data in logs
return Response.json({ error: e.message, stack: e.stack }, { status: 500 });
```

```ts
// Senior
logger.error({ requestId, op: 'user.create', code: (err as { code?: string }).code }, 'create failed');
return Response.json({ error: 'Something went wrong.', requestId }, { status: 500 });
```

- Structured logs with a request/correlation id; log identifiers and error codes,
  not personal data or secrets.
- Error responses never include SQL, stack traces, table names or file paths.
- Log where failures are *diagnosable*: one study found AI-built systems surfaced
  a fault-specific signal for at most 14% of injected faults despite plenty of
  log lines.

## 9. Configuration

- Validate required environment variables once at startup (e.g. a zod schema in
  `env.ts`) and fail fast; no scattered `process.env.X!`.
- Secrets are server-only. In Next.js, anything prefixed `NEXT_PUBLIC_` is
  inlined into the browser bundle at build time — never put secrets there.
- Never disable TLS verification (`rejectUnauthorized: false`).

## 10. Numbers, units, dates and time zones

- Money and measurements use exact types (`numeric`, integer minor units) with
  the unit in the name (`amount_pence`, `duration_min`), not floats.
- Instants are `timestamptz`; date-only values stay `YYYY-MM-DD` strings; compute
  "today" in the business time zone, not with `new Date().toISOString().slice(0,10)`
  (UTC, wrong around midnight and DST).
- Bound percentages, scores and counts in the schema and the database.

## 11. Migrations

- Add a new, forward-only migration; never edit one that has been applied.
- Postgres: `CREATE INDEX CONCURRENTLY`; add constraints as `NOT VALID` then
  `VALIDATE CONSTRAINT`; set `lock_timeout`; index foreign-key columns; avoid
  table-rewriting type changes on large tables.
- Destructive changes follow expand → migrate → contract, in separate deploys,
  with human approval.
- Lint migrations (e.g. `squawk`) in CI. Never run migrations against production
  from an agent session.
