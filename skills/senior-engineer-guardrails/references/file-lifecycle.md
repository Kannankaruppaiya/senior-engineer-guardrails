# File and asset lifecycle

Choose placement by ownership, trust, runtime and lifecycle; inspect the build
and deployment model first. A name alone does not make a file safe or public.

| Kind | Placement and handling |
|---|---|
| Imported source assets | Feature-local or established assets directory; bundler hashes imports; preserve case-sensitive paths and licenses |
| Public static assets | Framework public/static directory; assume anonymous access and CDN caching; never secrets or tenant documents |
| Templates | Owned source directory with schema/version and escaping; trusted email/PDF templates differ from untrusted user template input |
| Uploads | Private object storage or controlled local storage outside the web root; authorized metadata records, quarantine and validated promotion |
| Generated code | Document generator/version/input and regeneration command; change source schema/template first; commit generated code only when project policy requires it |
| Build/cache output | Ignored build/cache directories; reproducible from source, never canonical application logic |
| Temporary exports | Private, bounded storage with TTL, authorized download, cleanup and audit policy |
| Migrations/fixtures/docs | Canonical versioned locations; synthetic fixtures, immutable applied migrations, owned current docs |

## Names and paths

- Follow existing framework conventions and case sensitivity. Name files by
  responsibility, not `utils2`, `final-new` or a developer's machine. Legitimate
  versioned contracts/assets and canonical PLAN/NOTES docs are not stray files.
- Never use an untrusted filename as a path or object key. Generate an opaque
  server-side ID; retain a sanitized display name separately. Validate resolved
  local paths remain inside the storage root, including symlink boundaries.
- Paths are literal data: NUL-delimited enumeration, quoted arguments and `--`
  protect spaces, quotes, glob characters, Unicode, newlines and leading dashes.
  Never feed discovered names into eval or another shell.

## Upload and download pipeline

Authenticate, authorize tenant/resource, cap size/count/rate, allowlist formats,
verify MIME plus signatures, quarantine, scan where needed, then publish metadata.
Do not trust extension or client Content-Type. Bound archive expansion, image
dimensions and parser CPU; reject traversal, executable content and active HTML
unless an explicit isolated serving policy supports them.

Use private buckets, least-privileged identities, encryption and short-lived
signed URLs scoped to a validated object/operation. Prefixes help organize tenants
but are not authorization. Check ownership on download, delete and URL issuance;
signed URLs remain usable until expiration and can leak through logs/referrers.
Serve risky content as attachment from an isolated origin with safe headers.

## Consistency and cleanup

Database and object writes are not one atomic transaction. Use staged states,
idempotent finalize/cleanup jobs and reconciliation to recover orphaned objects
or metadata. Define retention, deleted-object versions, replication and backups;
deletion must cover these stores according to policy, including legal holds.
Do not write durable uploads to ephemeral containers/serverless filesystems.
Test foreign-tenant downloads, expired URLs, interrupted uploads, duplicate
completion, malicious names and cleanup failure with synthetic objects.
