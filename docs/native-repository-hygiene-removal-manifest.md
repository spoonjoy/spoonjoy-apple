# Native Repository Hygiene Removal Manifest

## Scope

Unit 10d/e/f removes tracked generated validation evidence from the native repository and keeps durable product/source material in git.

Pre-cleanup refs:
- Base audited/current `origin/main`: `b910c11101a81bc950d8dcf8d2046804ca60d0ae`
- Branch: `worker/native-repository-hygiene`
- Red-test commit: `e02c0c5735facdef1317c43ce69362b3cf27658a`

Owner: `worker`

External evidence root: `artifacts/apple/native-repository-hygiene` (ignored by git).

## Removal Authority

The pre-cleanup audit wrote `artifacts/apple/native-repository-hygiene/pre-cleanup-hygiene.json`.
It found 4,065 tracked generated files approved for removal:

| Category | Count |
| --- | ---: |
| tracked validation logs | 3,076 |
| tracked generated JSON/JSONL | 668 |
| tracked screenshot artifacts | 256 |
| tracked environment backups | 58 |
| tracked generated patches/diffs | 7 |

Approved generated roots:
- `apple/*` generated evidence: 141 files
- `tasks/*` non-Markdown generated evidence: 2,040 files
- `codex-native/tasks/*` non-Markdown generated evidence: 1,864 files
- `slugger/tasks/*` non-Markdown generated evidence: 20 files

## Preserved Classes

The cleanup preserves:
- Durable Markdown: task docs, planning/doing docs, review notes, evidence summaries, visual ledgers, and integration notes.
- App assets: `Apps/Spoonjoy/Shared/Assets.xcassets/**`.
- Source fixtures: `Sources/SpoonjoyCore/Fixtures/*.json`.
- Test image fixtures under `Tests/*/Fixtures/**`.
- Source, docs, workflows, scripts, app targets, and package metadata.

Environment backup files are treated as private generated evidence. Their values were not printed in logs or this manifest.

## Recovery

No history rewrite is authorized or required.

Restore a removed file from the pre-cleanup base:

```bash
git restore --source b910c11101a81bc950d8dcf8d2046804ca60d0ae -- <path>
```

Restore all removed generated artifacts into a scratch branch:

```bash
git switch -c recovery/native-generated-artifacts b910c11101a81bc950d8dcf8d2046804ca60d0ae
```

Verify the guard after cleanup:

```bash
ruby scripts/audit-native-validation-artifacts.rb \
  --repo-hygiene-only \
  --artifact-root artifacts/apple/native-repository-hygiene \
  --manifest artifacts/apple/native-repository-hygiene/post-cleanup-hygiene.json
```
