# Security and sensitive data

The largest audit of deployed AI-built apps in 2026 (200 apps, 1,471 validated
vulnerabilities) found broken access control in 75.5% of apps, 63% of flaws in
backend code, and 82.8% of access-control flaws being *missing server-side
checks*. The biggest root cause (43.9%) was a security rule the user never
stated. Treat the rules below as always stated.

## Authorization

- Every entry point that reads or changes data checks, on the server:
  1. who the caller is (session/token verified), and
  2. whether they may access **this specific record** (ownership, tenant, role).
- Checks live in the handler or service, not only in middleware, route matchers
  or the UI. Hidden buttons are not access control.
- When adding a route next to existing ones, copy their guard — "incomplete
  change propagation" (a new route missing its siblings' auth) is a named AI
  failure mode that type checks, tests and scanners miss.
- Never remove or bypass an auth check to make a feature or test work; never add
  a debug/bypass login route. If auth blocks you, stop and ask.
- Defence in depth where available: database row-level security, and an app
  database role without DDL rights.

## Input and output

- Validate all input server-side with strict schemas (reject unknown fields).
- Parameterised queries only.
- Escape output by default; avoid `dangerouslySetInnerHTML` / raw HTML. If
  unavoidable, sanitise with a vetted library.
- Return only the fields the caller needs.

## Sessions, tokens, passwords

- Session tokens in `HttpOnly`, `Secure`, `SameSite` cookies — not
  `localStorage`. Don't trust role or permission flags stored on the client.
- Verify JWT signature, algorithm, expiry and audience; don't accept `alg: none`
  or unsigned tokens.
- Hash passwords with a memory-hard KDF (argon2id or scrypt), asynchronously;
  cap input length; compare with constant-time functions.
- Rate-limit login, password reset and other enumerable endpoints; don't reveal
  whether an account exists.
- Webhook signatures: compare with `timingSafeEqual`; reject missing or empty
  secrets.

## Secrets

- Never hard-code secrets; never put them in client-exposed env vars
  (`NEXT_PUBLIC_*`, `VITE_*`) or return them from server actions.
- Don't read or print `.env` files; don't paste secrets into commands, logs or
  commit messages.
- A secret removed in a later commit is still in git history — tell the user so
  it gets rotated. (Reviewers missed 81% of leaked credentials in agent PRs.)
- Agents should not hold production credentials. The destructive 2026 incidents
  (production databases and backups deleted) all involved an agent finding a
  broad credential and using it.

## Sensitive and personal data

For health, financial or other personal data (GDPR, HIPAA, national health
standards):

- No personal data in logs, error messages, analytics, test fixtures or
  snapshots; use synthetic data.
- Audit who read or changed sensitive records, where the domain requires it.
- Least privilege per record, not just per role.
- No third-party trackers on authenticated pages.
- Don't send real personal data to external services (including AI tools)
  without the user's explicit instruction.

## Dependencies

Frontier models invent non-existent package names 4.6–6.1% of the time, and some
invented names are shared across models — attackers can register them
("slopsquatting").

- Before adding a dependency, confirm it exists, is the intended package, and is
  maintained; prefer what the project already uses.
- Don't add dependencies the task doesn't need. Pin versions via the lockfile.
- In CI config, pin actions and images to a digest or SHA; unpinned actions,
  images and installs made up 82% of security smells in agent PRs.
