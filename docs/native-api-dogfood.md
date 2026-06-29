# Native API Dogfood Guide

This guide records the live Spoonjoy API and native runtime contract that Spoonjoy Apple dogfoods. The source of truth for endpoint behavior remains `spoonjoy-v2`; this file tells native implementors which contracts to preserve when UI, Siri, Spotlight, cache, or sync code changes.

## Source Contracts

- Web docs: `/Users/arimendelow/Projects/spoonjoy-v2/docs/api.md`
- Developer route: `/Users/arimendelow/Projects/spoonjoy-v2/app/routes/developers.tsx`
- OpenAPI source: `/Users/arimendelow/Projects/spoonjoy-v2/app/lib/api-v1-openapi.server.ts`
- Generated playground manifest: `/Users/arimendelow/Projects/spoonjoy-v2/app/lib/generated/api-v1-playground.ts`
- Docs drift tests: `/Users/arimendelow/Projects/spoonjoy-v2/test/docs/native-dogfood-docs.test.tsx`

## OAuth And Links

Spoonjoy Apple uses the HTTPS OAuth redirect `https://spoonjoy.app/oauth/callback` with `ASWebAuthenticationSession.Callback.https(host: "spoonjoy.app", path: "/oauth/callback")`.

The Apple targets declare `applinks:spoonjoy.app` for Universal Links. The custom `spoonjoy` URL scheme is for app navigation and native-only actions only; it is not an OAuth redirect URI.

Must-cite native symbols and files:

- `Sources/SpoonjoyCore/Auth/OAuthRedirectValidator.swift`
- `Sources/SpoonjoyCore/Auth/OAuthRequests.swift`
- `Sources/SpoonjoyCore/Auth/NativeAuthSession.swift`
- `Apps/Spoonjoy/Shared/Auth/SpoonjoyWebAuthenticationSession.swift`
- `Apps/Spoonjoy/Shared/AppShell/SpoonjoyRootView.swift`
- `Sources/SpoonjoyCore/Native/DeepLinkManifest.swift`
- `Sources/SpoonjoyCore/AppState/DeepLinkRouter.swift`
- `Apps/Spoonjoy/Shared/Spoonjoy.entitlements`
- `Apps/Spoonjoy/Shared/Info.plist`

## Keychain And Refresh

Native auth persists `client_id`, `access_token`, and rotating `refresh_token` in Keychain-backed storage. `state` and `code_verifier` are temporary exchange values and must be cleared after a successful token exchange.

Refresh-token rotation must replace the stored refresh token atomically. Concurrent `401` responses use a single-flight refresh so only one refresh token is consumed, then waiting requests retry with the new access token.

Must-cite native symbols and files:

- `Sources/SpoonjoyCore/Auth/KeychainTokenVault.swift`
- `Sources/SpoonjoyCore/Auth/TokenVault.swift`
- `Sources/SpoonjoyCore/Auth/AuthSessionState.swift`
- `Sources/SpoonjoyCore/Auth/NativeAuthSessionRepository.swift`
- `Sources/SpoonjoyCore/Auth/RefreshCoordinator.swift`
- `Tests/SpoonjoyCoreTests/NativeAuthSessionTests.swift`
- `Tests/SpoonjoyCoreTests/TokenRefreshTests.swift`

## REST, Multipart, And Deletes

Native API calls decode Spoonjoy REST envelopes for `/api/v1` resources and keep OAuth token/revoke responses on their OAuth protocol shape.

Profile photo upload/remove dogfoods `POST /api/v1/me/photo` and `DELETE /api/v1/me/photo`. Uploads are `multipart/form-data`; request builders must let the runtime set the multipart boundary instead of manually setting the full `Content-Type` header.

DELETE retries should prefer `X-Client-Mutation-Id`. API v1 also documents JSON body `clientMutationId` for delete-body endpoints and query string `clientMutationId` for shopping item deletes. Native request builders must cover:

- `DELETE /api/v1/shopping-list/items/{itemId}`
- `DELETE /api/v1/recipes/{id}/spoons/{spoonId}`
- `DELETE /api/v1/cookbooks/{id}`

Must-cite native symbols and files:

- `Sources/SpoonjoyCore/API/NativeAPIRequests.swift`
- `Sources/SpoonjoyCore/API/APIRequestBuilder.swift`
- `Sources/SpoonjoyCore/API/APIRequestSupport.swift`
- `Sources/SpoonjoyCore/Features/Settings/SettingsSurfaceViewModel.swift`
- `Sources/SpoonjoyCore/Sync/NativeSyncEngine.swift`
- `Tests/SpoonjoyCoreTests/NativeAPIExpansionTests.swift`
- `Tests/SpoonjoyCoreTests/SettingsTokenConnectionTests.swift`

## Offline Product Contract

Cached records carry `accountId`, `environment`, `schemaVersion`, `fetchedAt`, `lastValidatedAt`, `sourceEndpoint`, and a server revision marker when available. Freshness windows are 15 minutes for account/settings/shopping bootstrap data, 6 hours for details/profile/spoon/cook-mode backing data, and 24 hours for catalog/search pages.

Profile display-field updates, profile photo upload/remove after local media staging, and notification preference updates are queueable. API token create/revoke, OAuth connection disconnect, logout/session revoke, passkey/password/provider-link actions are online-only.

Queued mutations must include stable `clientMutationId`, endpoint path, method, idempotency key, payload schema version, created-at time, dependency ordering key, retry count, and last error. Dismissal may hide only informational offline/stale states; queued work, sync failure, conflict, blocker, and destructive confirmation states remain visible until resolved.

Do not store bearer tokens, refresh tokens, one-time token values, provider secrets, passkey material, or raw credential values in general cache storage.

Must-cite native symbols and files:

- `Sources/SpoonjoyCore/Cache/NativeDurableCache.swift`
- `Sources/SpoonjoyCore/Cache/NativeDurableCacheStore.swift`
- `Sources/SpoonjoyCore/Offline/MutationQueue.swift`
- `Sources/SpoonjoyCore/Cache/NativeCacheFreshnessPolicy.swift`
- `Sources/SpoonjoyCore/Cache/NativeIndicatorDismissalStore.swift`
- `Sources/SpoonjoyCore/Cache/OfflineFreshnessIndicator.swift`
- `Sources/SpoonjoyCore/Sync/NativeSyncEngine.swift`
- `Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift`
- `Tests/SpoonjoyCoreTests/NativeSyncEngineTests.swift`
