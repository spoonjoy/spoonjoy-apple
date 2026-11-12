# Mac browser sign-in proof (proof branch only)

This branch holds a macOS XCUITest and a hand-run workflow. Together they prove that the Mac app gets
`https://spoonjoy.app/oauth/callback` back from ASWebAuthenticationSession after one click and lands signed in. The
branch is never merged.

- Test: `Apps/Spoonjoy/MacUITests/MacBrowserSignInCallbackUITests.swift`, in target `SpoonjoyMacBrowserSignInUITests`,
  which the `Spoonjoy macOS` scheme runs.
- Workflow: `.github/workflows/browser-signin-callback-mac.yml`. It runs only through `workflow_dispatch`, on a
  hosted `xcode-27` runner in the `mac-signin-proof` environment. Its first step stops the job if any secret is
  missing.

## Secrets the `mac-signin-proof` environment needs (exact names)

| Secret | Value |
| --- | --- |
| `APPLE_DEVELOPER_ID_CERTIFICATE_BASE64` | Developer ID Application certificate (.p12), base64 |
| `APPLE_DEVELOPER_ID_CERTIFICATE_PASSWORD` | the .p12 password |
| `APP_STORE_CONNECT_API_KEY_ID` | App Store Connect API key ID, used to find or create the Developer ID profile for `app.spoonjoy` |
| `APP_STORE_CONNECT_API_ISSUER_ID` | its issuer ID |
| `APP_STORE_CONNECT_API_KEY_BASE64` | the .p8 key, base64 |
| `SPOONJOY_BROWSER_CALLBACK_ACCOUNT_MAC` | `{"email","username","password"}` of a throwaway `@example.com` account seeded by spoonjoy-v2's Sim Callback Throwaway workflow |

macOS enforces `com.apple.developer.associated-domains`, and the https callback depends on it, so unlike the iOS
simulator proof this one needs a real Developer ID provisioning profile. Delete the throwaway account after each run.
