# Enterprise tenancy, security and privacy

Apply controls according to the product's threat model and obligations; this is
universal guidance, not a mandate for a particular industry or compliance badge.

## Tenant and authorization context

Derive tenant membership from verified identity and server-side membership.
Selecting a tenant ID is a request, not proof of access. Explicitly separate
platform administration from tenant roles, with audited support access and
least privilege. Centralize policy decisions without relying solely on middleware.

- Scope reads/writes/joins by tenant, including exports, search, aggregate counts,
  cache keys, filenames, queues, notifications, websocket subscriptions and logs.
- Tenant-aware unique constraints and foreign keys prevent cross-tenant links.
  RLS is defense in depth: test the actual app role, connection pooling/context
  reset, bypass roles and both read and write behavior.
- Background jobs carry authenticated/validated tenant context and re-check
  permissions when stale authorization could change the outcome.
- Rate limits, quotas and workload budgets prevent one tenant starving others.
  Cache keys include tenant and relevant access context; do not cache private
  responses under public/shared keys.

Example: a valid tenant-A session requesting tenant-B's opaque object ID must
fail through HTTP, search/export, storage download and async work. A UI filter
or a mocked repository assertion does not prove this boundary.

## Security surfaces

Use deny-by-default permissions; explicit public endpoints still validate input
and limit abuse. Protect cookie-authenticated state changes against CSRF;
SameSite is defense in depth, CORS is not authorization. Allowlist CORS origins.
Prevent SSRF in URL fetching with destination validation, controlled egress,
redirect revalidation and private/metadata-network rejection. Add suitable CSP
and security headers, bounded request bodies/timeouts and safe error mapping.
Verify webhook signatures over raw bytes, timestamps and replay protection.
Manage SSO/MFA/session revocation when required; test role changes and logout.

## Privacy and lifecycle

Inventory data categories, purpose, owner, authorized recipients and retention.
Minimize collection; separate operational logs from access-controlled audit
events. Encrypt in transit/at rest and define key rotation/revocation procedures.
Never log tokens, private documents or raw request payloads; use synthetic tests.

Define export, correction, deletion and account closure across primary DB,
objects, caches, indexes, analytics and backups; record legal-hold exceptions and
restoration handling. Deletion is an idempotent workflow, not merely a hidden row.
Review external processors and AI inputs for consent/authorization, residency,
retention and training policy. Do not assert legal compliance from a checklist;
record applicable jurisdictions and obtain qualified review where needed.

Validate using two synthetic tenants, ordinary app credentials, real requests
and storage/queue boundaries. Include forbidden access, privileged-role misuse,
revocation, pool reuse, rate/quota exhaustion and deletion/recovery scenarios.
