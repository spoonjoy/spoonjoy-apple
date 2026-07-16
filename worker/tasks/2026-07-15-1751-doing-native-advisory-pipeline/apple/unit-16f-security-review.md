# Unit 16f Security Review

Verdict: APPROVE.

Scope reviewed:
- `scripts/scan-ruby-advisories.rb`
- `scripts/check-native-advisory-pipeline.rb`
- `.github/workflows/native.yml`
- `scripts/validate-native-local.sh`
- `scripts/bundle-check.sh`
- `scripts/bundle-exec.sh`
- `Gemfile` / `Gemfile.lock`
- `security/native-advisory-*.yml`
- `docs/native-advisory-policy.md`
- `Tests/SpoonjoyCoreTests/NativeAuthSessionTests.swift`

Checks:
- Scanner is pinned to `bundler-audit` 0.9.3 and verifies gem SHA256 before scanning.
- Ruby Advisory Database is fetched by exact SHA and scanned with `--no-update --database`.
- `Gemfile.lock` is explicitly required and passed through `--gemfile-lock`.
- Network/update, scanner, actionable finding, missing lockfile, and expired allowlist paths fail closed.
- Allowlists are explicit, empty by default, and require `id`, `gem`, `reason`, `owner`, and future `expires_on` within 45 days.
- The advisory dependency is isolated in Bundler group `advisory`; normal Xcode generator checks default to `BUNDLE_WITHOUT=advisory`, while the scanner clears that exclusion for its own process.
- CI uses pinned checkout/setup/upload actions already present in the repo style and does not expose secrets.
- Secret scan over touched source/policy files found only the existing test fixture password string in `NativeAuthSessionTests.swift`.

Findings:
- BLOCKER/MAJOR: none.
- MINOR fixed during review: removed stale failed full-Swift diagnostic log that broke `git diff --check`; retained focused repair evidence and final green full-suite evidence.
