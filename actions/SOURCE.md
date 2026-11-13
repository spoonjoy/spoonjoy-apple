# Where Spoonjoy's actions come from

Spoonjoy declares each action once, in spoonjoy-v2. This app vendors that declaration and Ouro UI core's generator,
and compiles the Swift the generator makes from it. Don't edit anything here by hand; change the declaration in
spoonjoy-v2, then copy it here and run `node tools/ouro-actions/ouro-actions.mts generate actions/spoonjoy.actions.mts actions/generated`.

The Actions workflow (`.github/workflows/actions.yml`, `scripts/check-actions-drift.sh`) fails when any line below stops being true.

- declaration-repo: spoonjoy/spoonjoy-v2
- declaration-path: actions/spoonjoy.actions.mts
- declaration-commit: PENDING
- declaration-sha256: 19e838cda218a83f55eae7aaadf632941523e75378b0de6d622c2768b41c55d9
- generator: ourostack/ouro-ui-core v0.6.0, tools/ouro-actions/ouro-actions.mts
- generator-sha256: 128a284d575a27f47d4e0ccfbe6c241eeaf2c0b0a4f09000564a2e8f8f9bc827
- claims-sha256: 944f48be5f9409dd70e0774dfe4976fef9cc3ba3f4ab4b9231df428700523f1a
