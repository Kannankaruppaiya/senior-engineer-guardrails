# API, data, queues and delivery operations

## API contracts and compatibility

Define request/response/error schemas, authorization, status codes, side effects,
pagination, limits and idempotency in the project's contract format. Test malformed
JSON, unsupported content types, missing/extra fields and dependency failures.
Keep private persistence models out of public DTOs. Bound query complexity.

Version externally consumed breaking changes; choose the existing URI/header/
schema convention rather than inventing a second one. Additive fields can still
break strict clients. Document compatibility window, deprecation date, migration
path and owner. Run consumer/contract tests against old and new supported clients.
Scope idempotency keys to tenant, operation and payload, expire them deliberately
and atomically persist the result to prevent duplicate side effects.

## Data evolution

Use expand/backfill/validate/contract across separate compatible deployments.
Bound backfill batches, checkpoint progress, budget locks/IO, reconcile counts
and provide a halt/resume procedure. Keep applied migrations immutable; test an
upgrade from a realistic prior schema, not only a blank database.
Define retention/archive/delete and recovery semantics with dependencies and
object storage. Backups need encryption, restore drills and measured RPO/RTO.
Restoring a database alone may leave objects, queues and indexes inconsistent.

## Queues and external effects

Assume at-least-once delivery; make consumers idempotent and transactional where
possible. Use an outbox to bridge DB commits to broker publication rather than
unsafe fire-and-forget. Define job schema/version, tenant context, deduplication,
timeouts, cancellation, bounded retries/backoff/jitter and dead-letter handling.
Retry only transient failures; poison messages need triage and controlled replay.
External payment/email effects need provider idempotency and reconciliation;
do not claim exactly-once delivery merely because a queue supports deduplication.
Test crashes before/after commit/ack, duplicates, ordering and partial failure.

## Observability and performance

Use structured redacted logs, correlation/trace IDs through jobs, useful error
codes, bounded-cardinality metrics and tracing. Measure latency, errors, saturation,
queue lag and business invariants; choose SLOs and actionable owned alerts.
Test that injected failures produce diagnostic signals. Set budgets for query
count, payload size and upstream concurrency; validate indexes/query plans and
representative load before claiming performance improvements.

## CI, deployment and recovery

- Run formatting/types/lint, behavioral/integration/contract tests, build,
  dependency/secret scanning and relevant migration/boundary checks. Missing
  credentials or tools are unknown checks, not green checks.
- For a changed-file gate, fetch sufficient Git history and compare merge-base
  of the PR base/head, excluding deleted paths but including renamed targets.
  Never trust a scanner's clean output as proof of security.
- Keep PR jobs least-privileged. Never run untrusted PR code with production
  secrets or write tokens (`pull_request_target` plus head checkout is dangerous).
  Pin third-party actions/images and use reviewed lockfiles/artifact provenance.
- Build once and promote an immutable artifact; validate configuration on startup.
  Use environment protection, readiness/liveness checks, staged rollout and smoke
  verification. Coordinate schema compatibility before rollback.
- Have an owner and tested runbook for rollback/roll-forward, feature disable,
  draining jobs, incident escalation and restoring data. Define recovery time
  and loss targets; verify backup restoration in an isolated environment.

An agent may prepare deployment configuration and a reviewable plan. Execution
against production requires existing explicit authorization and suitable access;
never infer it from permission to fix code or push a PR.
