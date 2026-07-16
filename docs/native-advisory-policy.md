# Native Advisory Policy

The native repo scans Ruby tooling dependencies with `bundler-audit` because the scanner is maintained by RubySec, checks `Gemfile.lock` against the Ruby Advisory Database, supports JSON output, and can run in CI without relying on GitHub security-alert API visibility.

The scanner is fail closed:

- `Gemfile.lock` must exist and is the only lockfile scanned.
- `bundler-audit` is pinned in `Gemfile`/`Gemfile.lock`.
- The scanner gem artifact SHA256 and Ruby Advisory Database commit are recorded in `security/native-advisory-pipeline.yml`.
- Scanner execution, advisory database update/network errors, missing reports, malformed reports, and actionable findings fail CI.
- Allowlist entries live in `security/native-advisory-allowlist.yml`; every entry must include `id`, `gem`, `reason`, `owner`, and `expires_on`.
- `expires_on` must be a future ISO date no more than 45 days from the scan date. Expired, malformed, or overlong allowlist entries fail before the scanner runs.

Real findings must be fixed in the dependency graph. If an immediate fix is impossible, add a narrowly scoped allowlist entry with the review owner, reason, and expiry, then remove it before or at expiry.
