# Spoonjoy Apple

The native iOS, iPadOS and macOS app for [Spoonjoy](https://spoonjoy.app), written in SwiftUI. The web app and API live in [spoonjoy/spoonjoy-v2](https://github.com/spoonjoy/spoonjoy-v2); this app talks to its `/api/v1` API and signs in through its OAuth flow. `AGENTS.md` holds the product intent and the working rules for agents.

## Layout

| Path | What lives there |
|---|---|
| `Sources/SpoonjoyCore/` | All app logic that does not need UIKit or AppKit: API client, auth, cache, offline queue, sync engine, view models, deep links. This is where logic goes so it can be unit tested. |
| `Apps/Spoonjoy/Shared/` | SwiftUI views, app shell, design components, assets, `Info.plist` and entitlements shared by both platforms. |
| `Apps/Spoonjoy/iOS/`, `Apps/Spoonjoy/macOS/` | The two app entry points. |
| `Apps/Spoonjoy/LiveActivity/` | The cook-timer Live Activity and widget. |
| `Apps/Spoonjoy/Journeys/`, `Apps/Spoonjoy/UITests/` | XCUITest journeys that drive the real app against the web QA environment, and the shopping UI tests. |
| `Spoonjoy.xcodeproj` | The Xcode project (schemes `Spoonjoy iOS` and `Spoonjoy macOS`). `scripts/generate-xcode-project.rb` generates it. |
| `Sources/SpoonjoyScenarioVerifier/`, `SpoonjoyJourneyRules/`, `SpoonjoyNativeDogfood/` | Command-line tools: the scenario verifier, the lint for journey house rules, and the API dogfood client. |
| `Tests/SpoonjoyCoreTests/` | Swift Testing suite for `SpoonjoyCore` and for the repository's own contracts. |
| `scripts/` | Ruby and shell checks and tooling used by CI and by local validation. |
| `docs/` | Design language, Apple distribution, advisory policy and API dogfood notes. |
| `distribution/` | TestFlight configuration read by the shared [apple-distribution-kit](https://github.com/ourostack/apple-distribution-kit). |

## Requirements

Xcode 27 (CI pins `/Applications/Xcode_27.0.app`) and Ruby 3.3 with Bundler for the scripts (`bundle install`). The app targets iOS 27 and macOS 27.

## Build and test

```sh
# Unit tests for SpoonjoyCore (CI runs this with coverage and requires 100% line coverage of Sources/SpoonjoyCore)
swift test --disable-xctest --parallel

# Build the apps
xcodebuild -project Spoonjoy.xcodeproj -scheme "Spoonjoy iOS" -configuration BootstrapDebug \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Spoonjoy.xcodeproj -scheme "Spoonjoy macOS" -configuration BootstrapDebug \
  -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

UI journeys are validated in CI, not on your machine: they run against the QA mirror of the web app with disposable accounts (see `AGENTS.md`, section Validation). Local simulator runs are for writing code.

## CI

All workflows are in `.github/workflows/`. The xcode-27 jobs run on the scarce `xcode-27` runners and share the `.github/actions/select-xcode` composite action.

- `native.yml` (**Native**): runs on every pull request and push to `main`. Required checks on `main` are `Swift tests`, `Native scenario verifier`, `App bundle` and `Contracts`. `Ruby advisory scan` runs alongside them.
- `journeys.yml` (**Journeys**): XCUITest journeys and shopping UI tests against QA. Not a required check.
- `beta-sdk.yml` (**Beta SDK**): compiles the iOS app with newer beta Xcodes to catch API breakage early. Not a required check.
- `testflight.yml` (**TestFlight**): publishes to internal TestFlight after Native succeeds on a `main` push.

## Release

Every green Native run on `main` publishes that exact commit to the internal TestFlight group. `docs/apple-distribution.md` describes the pipeline, the evidence it checks, and how to roll back with a manual dispatch.
