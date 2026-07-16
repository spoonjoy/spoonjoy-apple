# Native Cover Image Normalization N2

Status: in_progress
Execution Mode: direct

Host: `ouroboros-host` / user: `arimendelow` / cwd: `/Users/arimendelow/Projects/spoonjoy-apple-native-cover-normalization` / OS: `Darwin` / probed: 2026-07-15 19:56 -0700

## Source

- Upstream doing doc: `/Users/arimendelow/Projects/spoonjoy-v2-audit-remediation/worker/tasks/2026-07-15-1152-doing-audit-remediation.md`
- Units: 4a, 4b, 4c only
- Prerequisite: web native-upload matrix W6 is merged and live at Worker `c96a8c97-abb0-4d41-8b0b-c075d9b54ae3`
- Branch: `worker/native-cover-normalization-n2`
- Worktree: `/Users/arimendelow/Projects/spoonjoy-apple-native-cover-normalization`

## Scope

- Normalize native recipe cover selections, including HEIC/HEIF/default-camera input, into server-accepted JPEG.
- Apply orientation-safe conversion and bound the longest edge to 2048 px.
- Enforce the exact 5 MiB server upload ceiling before immediate upload and before queued replay.
- Preserve previous staged cover state on corrupt, unsupported, empty, or unfit replacement input.
- Cover immediate upload, offline durable staging, and queued replay request contracts.

Out of scope: mutation single-flight, Photo Studio UI/visual changes, TestFlight publishing, web worktrees, production mutation, and any `clem-feedback` worktree.

## Native Justification Note

Native cover selection is better in the Apple app because camera/photo-library inputs arrive as real local image bytes, commonly HEIC/HEIF with orientation metadata, and users need offline staging plus later replay. Image I/O is the intentional Apple framework for this slice because it decodes HEIC/HEIF, applies source transforms, scales safely, and writes JPEG without adding a capture/UI framework. Photos, camera, OCR, Vision, and Photo Studio UI changes are deferred to later units. The backend remains the canonical byte/MIME contract: native adapts selected media to the existing JPEG <= 5 MiB upload boundary instead of duplicating server policy. iOS/iPadOS/macOS share the same core normalizer and queued replay contract; platform UI differences are out of scope here.

## Units

### [ ] Unit 4a: Native Cover Image Normalization Tests
What: Add failing tests for real HEIC/HEIF/default-camera samples, orientation, corrupt input, JPEG/PNG/WebP, oversized input, 2048-pixel longest edge, adaptive JPEG quality, exact 5 MiB boundary, prior-stage preservation, immediate upload, offline durable staging, replay, and emitted filename/MIME/bytes.
Output: Cover transcoder tests plus cover surface, staging, API request, and sync replay contract updates.
Acceptance: Tests fail because raw HEIC and over-contract bytes can currently reach staging/transport.

### [ ] Unit 4b: Native Cover Image Normalization Implementation
What: Add a cover-specific ImageIO normalizer that applies orientation, bounds dimensions, emits JPEG, adaptively fits the 5 MiB contract, and leaves prior state untouched on failure; route both immediate and queued paths through it.
Output: Dedicated cover image normalization module and narrow caller changes; atomic native PR N2.
Acceptance: Unit 4a passes; no native cover request or queued replay emits HEIC/HEIF or bytes above the server ceiling.

### [ ] Unit 4c: Native Cover Image Verification
What: Run focused cover/cache/sync/API tests, Swift coverage, scenario verifier, app-target builds, and fresh implementation/performance review.
Acceptance: 100% new-code coverage, zero warnings, reviewer PASS, N2 CI green. Do not merge.

## Evidence Index

Generated validation artifacts are stored under ignored local path `artifacts/apple/native-cover-normalization-n2/`.

## Progress Log

- 2026-07-15 19:56 Created native-local N2 doing doc from upstream Units 4a-4c, with scope boundaries and native justification note.
