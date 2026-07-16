# Native Cover Image Normalization N2 Evidence

Generated validation artifacts live under ignored local path `artifacts/apple/native-cover-normalization-n2/`.

## Red Evidence

- `artifacts/apple/native-cover-normalization-n2/unit-4a-cover-red.log`: focused `swift test --filter CoverControlSurfaceTests --disable-xctest -Xswiftc -warnings-as-errors` compiled, then failed because current staging/transport still preserves source HEIC/WebP/PNG MIME, filename, dimensions, and bytes instead of normalized JPEG.

## Green Evidence

- `artifacts/apple/native-cover-normalization-n2/unit-4b-cover-green.log`: focused `swift test --filter CoverControlSurfaceTests --disable-xctest -Xswiftc -warnings-as-errors` passed after the ImageIO normalizer routed staging, immediate upload, durable staging, and queued replay through JPEG normalization.
- `artifacts/apple/native-cover-normalization-n2/unit-4b-cover-warning-scan.log`: warning scan over the focused cover test log passed.
- `artifacts/apple/native-cover-normalization-n2/unit-4b-swift-build.log`: `swift build -Xswiftc -warnings-as-errors` passed.
- `artifacts/apple/native-cover-normalization-n2/unit-4b-build-warning-scan.log`: warning scan over the focused Swift build log passed.

## Final Validation Evidence

- Pending.

## Reviewer Disposition

- Pending.
