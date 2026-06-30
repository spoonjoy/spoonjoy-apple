# Unit 24b Reviewer Fix

Cold reviewer: Kierkegaard the 3rd

## Findings Addressed

- Native mobile OAuth docs registered `https://spoonjoy.app/oauth/callback` but the token exchange sample still used an encoded `example.com` callback.
- DELETE idempotency metadata did not match runtime behavior across native-relevant generated surfaces. Runtime accepts `clientMutationId` in JSON body, query string, or `X-Client-Mutation-Id`, but OpenAPI/playground metadata exposed only subsets for recipe spoon, cookbook, cookbook recipe, recipe cover, and shopping-list item deletes.

## Fix

- Web commit: `4cfdaa37 docs: align delete idempotency metadata`
- Corrected the native mobile OAuth token exchange sample to the Spoonjoy universal-link callback.
- Added optional JSON request bodies, optional header/query idempotency parameters, and matching idempotency policy metadata for DELETE operations used by native clients.
- Regenerated `app/lib/generated/api-v1-playground.ts`.
- Strengthened docs, OpenAPI, SDK-profile, playground, and route tests.
- Added build-only Vite `optimizeDeps.noDiscovery` config to prevent the handled dependency-scan cancellation diagnostic from polluting production build logs.

## Validation

- `unit-24b-review-fix-docs-green.log`: native dogfood docs tests passed.
- `unit-24b-review-fix-playground-green.log`: developer playground route tests passed.
- `unit-24b-review-fix-openapi-lib-green.log`: OpenAPI server tests passed.
- `unit-24b-review-fix-focused-green.log`: focused Unit 24b suite plus build-output hygiene passed.
- `unit-24b-review-fix-typecheck.log`: `pnpm run typecheck` passed.
- `unit-24b-review-fix-build.log`: `pnpm run build` passed with no canceled-build diagnostic.
- `unit-24b-review-fix-warning-scan.log`: final logs had no warning/error/failure diagnostics.
