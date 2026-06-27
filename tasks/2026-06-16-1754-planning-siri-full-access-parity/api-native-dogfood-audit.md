# Spoonjoy API And Native Dogfood Audit

Date: 2026-06-16

This audit records the API contract the native app can honestly dogfood today and the backend/API gaps that must be closed for native parity.

## REST API v1 Available Today

Source: `/Users/arimendelow/Projects/spoonjoy-v2/app/lib/api-v1-contract.server.ts`

- `GET /api/v1`
- `GET /api/v1/health`
- `GET /api/v1/openapi.json`
- `GET /api/v1/openapi.sdk.json`
- `GET /api/v1/openapi.connector.json`
- `GET /api/v1/recipes`
- `GET /api/v1/recipes/{id}`
- `GET /api/v1/cookbooks`
- `GET /api/v1/cookbooks/{id}`
- `GET /api/v1/shopping-list`
- `GET /api/v1/shopping-list/sync`
- `POST /api/v1/shopping-list/items`
- `PATCH /api/v1/shopping-list/items/{itemId}`
- `DELETE /api/v1/shopping-list/items/{itemId}`
- `GET /api/v1/tokens`
- `POST /api/v1/tokens`
- `DELETE /api/v1/tokens/{credentialId}`

Normal v1 success uses `{ ok: true, requestId, data }`. Normal v1 errors use `{ ok: false, requestId, error: { code, message, status } }`. Raw OpenAPI documents, OAuth routes, delegated approval helpers, and MCP intentionally use their own protocol shapes.

## Auth And OAuth Facts For Native

- Public recipe/cookbook reads work anonymously.
- If a bearer token is sent to optional public endpoints, it must be valid and scoped; Spoonjoy does not fall back to anonymous after a bad token.
- Bearer auth wins over a browser session when `Authorization` is present.
- OAuth supports dynamic public-client registration, authorization code + PKCE S256, refresh-token rotation, and revoke.
- OAuth access tokens expire after 900 seconds.
- Native clients must use an HTTPS universal-link redirect. Current OAuth validation rejects custom-scheme redirect URIs except localhost/127.0.0.1 development URLs.
- OAuth `resource` is for MCP (`https://spoonjoy.app/mcp`) and resource-bound MCP tokens are rejected by REST v1.
- Recommended first native REST scopes today are `shopping_list:read shopping_list:write`; public recipes/cookbooks can remain anonymous unless the client needs authenticated cache/private policy later.

## Shopping Mutation Contract

- Shopping mutations require `clientMutationId`.
- Idempotency is chef/client scoped and retained for 24 hours.
- Same idempotency key and same request replays with a fresh `requestId` and replay metadata.
- Same key with different method/path/body returns `409 idempotency_conflict`.
- In-flight duplicate returns `409 idempotency_in_progress` with `Retry-After: 2`.
- `POST /shopping-list/items` deduplicates by shopping list plus ingredient ref plus unit, restores deleted/checked rows, adds quantities when present, and may return `200 updated` or `201 created`.
- `PATCH /shopping-list/items/{itemId}` only accepts `checked`.
- `DELETE /shopping-list/items/{itemId}` soft-deletes. It accepts idempotency through JSON body, `X-Client-Mutation-Id`, or query parameter; docs should recommend the header for DELETE because bodies are fragile.

## API Gaps For Native Parity

REST v1 does not currently expose:

- Signed-in bootstrap identity (`/api/v1/me`).
- Private/current chef kitchen sync.
- Recipe create/edit/delete.
- Step create/edit/delete/reorder.
- Ingredient add/delete and parser-backed ingredient parsing.
- Step-output dependency writes.
- Recipe fork.
- Recipe import/capture.
- Recipe image upload and cover lifecycle actions.
- Spoon create/update/delete/list outside recipe detail web loaders.
- Cookbook create/rename/delete.
- Cookbook recipe membership add/remove.
- Account profile updates, profile photo updates, password/passkey/OAuth-provider management, API credential creation via native OAuth context, or notification preferences.
- Push/APNs registration for native devices.
- Public/private recipe/cookbook sync with tombstones for offline caches.

Legacy `/api/*` and MCP/tool code contain richer product writes, but the docs mark legacy `/api/*` as app-only and not the external contract. Native should not build parity by quietly depending on legacy app-only routes. The parity path is to add REST v1 endpoints with the same envelope, scope, idempotency, telemetry, and tests.

## Docs Drift To Fix

- Native quickstart should persist `client_id`, access token, and refresh token in Keychain. `state` and `code_verifier` are temporary callback-exchange values and should be cleared after token exchange.
- DELETE shopping docs should state that body/query idempotency is accepted, while `X-Client-Mutation-Id` is recommended.
- OAuth consent copy for `kitchen:write` should be resource-aware. REST expansion is currently shopping-list write only, while MCP kitchen write is broader.
- A test name says empty OAuth scope defaults to read+write, but code defaults to `kitchen:read`; docs are correct.

## Native API Dogfood Requirements

- Add a native-client docs section with universal-link callback path, Associated Domains/AASA requirements, Keychain storage, token refresh/retry, and envelope decoding.
- Add real native transport over `URLSession` with request/response tests that assert outgoing method, path, query, headers, body, idempotency keys, and retry behavior.
- Add REST v1 endpoints for every native parity write rather than relying on app-only legacy routes.
- Add sync APIs for offline caches where native needs durable offline access and reconciliation.
