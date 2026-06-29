# Unit 22t Review - Zeno the 3rd

Result: NOT CONVERGED before review-fix patch.

## Findings

- P1: Offline/online-only policy was effectively dead for Siri settings intents. `settingsConnectivity()` always returned `.online`, so token create/revoke, OAuth disconnect, credential handoffs, logout, and session revoke could attempt network or open a handoff instead of returning the required offline/not-queued response.
- P1: Profile settings App Intents did not match the native UI queue policy. Resolver code planned online profile updates but selected queued/offline fallback mutations immediately, so online Siri profile updates were queued instead of remote-first with offline fallback. Optimistic profile/settings cache application was also missing from `applyNativeMutation`.
- P1: Create API Token could create an unrecoverable credential. The intent executed token creation, decoded the one-time token, discarded the outcome, and then opened Settings, making it likely the user would never see or save the secret.
- P1: Revoke Current Session did not revoke the server session. The Siri session operation only cleared local keychain state while the native app path also calls the OAuth revoke endpoint before logout.
- P2: Settings App Entity display leaked raw account IDs into Siri/UI disambiguation. Account IDs belonged in scoped identifiers, not visible subtitles.

## Review-Fix Disposition

- Added a bounded settings connectivity probe and preserved offline/not-queued behavior for online-only settings/security actions.
- Routed profile display/photo/remove through `SettingsActionPlan` execution so Siri uses the same remote-first/offline-fallback policy as native Settings, including cached profile optimistic updates.
- Changed API token creation to open the first-party settings flow with a user-facing handoff message instead of creating and discarding a one-time secret from Siri.
- Changed current-session revoke to call the OAuth revoke endpoint before local keychain/client-id cleanup.
- Removed raw account IDs from visible settings entity subtitles and disambiguation labels.
