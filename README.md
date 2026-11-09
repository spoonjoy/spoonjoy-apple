<!-- spoonjoy:brand:start -->
<p align="center">
  <a href="https://spoonjoy.app"><picture>
    <source media="(max-width: 600px) and (prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/spoonjoy/.github/main/brand/headers/spoonjoy-apple-narrow-dark.webp">
    <source media="(max-width: 600px)" srcset="https://raw.githubusercontent.com/spoonjoy/.github/main/brand/headers/spoonjoy-apple-narrow-light.webp">
    <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/spoonjoy/.github/main/brand/headers/spoonjoy-apple-dark.webp">
    <img src="https://raw.githubusercontent.com/spoonjoy/.github/main/brand/headers/spoonjoy-apple-light.webp" alt="Spoonjoy on a Mac showing the kitchen, beside two iPhones: one in cook mode with a ten-minute timer, one on the Lemon Pantry Pasta recipe" width="100%">
  </picture></a>
</p>
<!-- spoonjoy:brand:end -->

# Spoonjoy for iPhone, iPad and Mac

The native SwiftUI app, with a cook mode that walks you through a recipe one step at a time.

[spoonjoy.app](https://spoonjoy.app) · [Web app and API](https://github.com/spoonjoy/spoonjoy-v2) · [Design language](docs/native-design-language.md) · [AGENTS.md](AGENTS.md)

**Start:** with Xcode 27, run the core tests with `swift test --disable-xctest --parallel`, then open `Spoonjoy.xcodeproj` and run the `Spoonjoy iOS` scheme ([Build and test](#build-and-test)).

Not on the App Store yet: the app is with App Review, and the open [`app-review` issues](https://github.com/spoonjoy/spoonjoy-apple/issues?q=is%3Aopen+label%3Aapp-review) show where each version stands. Until then, cook on [spoonjoy.app](https://spoonjoy.app).

Internal testers get every green build of `main` through TestFlight. The app talks to the Spoonjoy web app's `/api/v1` API and signs in through its OAuth flow; the web app and API live in [spoonjoy/spoonjoy-v2](https://github.com/spoonjoy/spoonjoy-v2). `AGENTS.md` holds the product intent and the working rules for agents.

## Layout

| Path | What lives there |
|---|---|
| `Sources/SpoonjoyCore/` | All app logic that does not need UIKit or AppKit: API client, auth, cache, offline queue, sync engine, view models, deep links. This is where logic goes so it can be unit tested. |
| `Apps/Spoonjoy/Shared/` | SwiftUI views, app shell, design components, assets, `Info.plist` and entitlements shared by both platforms. |
| `Apps/Spoonjoy/iOS/`, `Apps/Spoonjoy/macOS/` | The two app entry points. |
| `Apps/Spoonjoy/LiveActivity/` | The cook-timer Live Activity and widget. |
| `Apps/Spoonjoy/Journeys/`, `Apps/Spoonjoy/UITests/` | XCUITest journeys that drive the real app against the web QA environment, and the shopping UI tests. |
| `Spoonjoy.xcodeproj` | The Xcode project (schemes `Spoonjoy iOS` and `Spoonjoy macOS`). `scripts/generate-xcode-project.rb` generates it. |
| `Sources/SpoonjoyReins/`, `Sources/spoonjoy-reins/`, `Tests/SpoonjoyReinsTests/` | Ouro Reins: Spoonjoy's shell driven headless over the fixture kitchen with the network blocked, its command-line runner, and the headless journeys behind the required `Reins journeys` check. |
| `Sources/SpoonjoyScenarioVerifier/`, `SpoonjoyJourneyRules/`, `SpoonjoyNativeDogfood/` | Command-line tools: the scenario verifier, the lint for journey house rules, and the API dogfood client. |
| `Tests/SpoonjoyCoreTests/` | Swift Testing suite for `SpoonjoyCore` and for the repository's own contracts. |
| `scripts/` | Ruby and shell checks and tooling used by CI and by local validation. |
| `docs/` | Design language, Apple distribution, advisory policy and API dogfood notes. |
| `distribution/` | TestFlight configuration read by the shared [apple-distribution-kit](https://github.com/ourostack/apple-distribution-kit). |

## Requirements

Xcode 27 (CI pins `/Applications/Xcode_27.1.app`; 27.0 works locally but compiles out the iPhone Duo hinge code) and Ruby 3.3 with Bundler for the scripts (`bundle install`). The Debug and Release builds target iOS 27 and macOS 27; the `BootstrapDebug` configuration used below targets iOS 26.5 and macOS 26.2.

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

All workflows are in `.github/workflows/`. The jobs that need the iOS 27 SDK run on the scarce `xcode-27` runners and share the `.github/actions/select-xcode` composite action. The SwiftPM-only required jobs (Swift tests, Native scenario verifier) run on `macos-26` with Xcode 26.x via `.github/actions/select-swift-toolchain`, so they never wait for an `xcode-27` runner.

- `native.yml` (**Native**): runs on every pull request and push to `main`. Required checks on `main` are `Swift tests`, `Native scenario verifier`, `App bundle`, `Contracts` and `Reins journeys`. `Ruby advisory scan` runs alongside them. On pull requests, `App Intents X-ray` (macos-26) runs Ouro AX's X-ray, from the `ourostack/ouro-ui-apple` version `Package.swift` pins, over the App Intents metadata the App bundle job builds and holds it to `config/xray-expected.json` (`ruby scripts/check-xray.rb <report.json>`), and lints the Siri AI app skills in `Apps/Spoonjoy/Shared/Skills.skillsbundle` with `ouro-ax-skills lint --strict`; its behaviour stage is `app-intents-xray.yml`, on `main` only (after TestFlight), on `xcode-27`, and never gates Native. To X-ray a local build: `swift package resolve && swift build -c release --package-path .build/checkouts/ouro-ui-apple --product ouro-ax-xray`, then `.build/checkouts/ouro-ui-apple/.build/release/ouro-ax-xray --app <Spoonjoy.app> --out <dir>`.
- Optional checks wait for the required ones. On a pull request, Native calls `journeys.yml`, `launch-smoke.yml`, `feel.yml` and `beta-sdk.yml` only after all five required checks pass, and the `App Intents X-ray` job waits for them too, so a required job never queues behind optional work for a macOS runner. They show on the pull request as `Journeys / Live journeys`, `Feel / Feel (...)` and so on. A new macOS workflow that runs on pull requests must be called from Native the same way (`scripts/test/optional_checks_wait_test.rb` checks this). On `main`, `after-testflight.yml` runs them, with the X-ray's behaviour stage, once the TestFlight run for that commit has finished (Native, then TestFlight, then these), so TestFlight never queues behind them. A commit main has already moved past is skipped, since the newer commit's chain covers it. With auto-merge, the required checks passing is also the merge, so `pr-closed.yml` cancels a closed pull request's unfinished Native run and main's chain runs the optional checks instead.
- `journeys.yml` (**Journeys**): XCUITest against QA. **Live journeys** is the thin live layer (cook-session sync, the edit conflict, sign-in and blocked chefs, plus the UI and OS checks a headless test cannot make); headless Journeys in `SpoonjoyReinsTests` carry the rest. A network or launch failure is retried once on fresh accounts and reported as infrastructure in the job summary (`scripts/live-journeys.rb`); an assertion failure is never retried. Also runs the Duo journeys and shopping UI tests. Not a required check.
- `beta-sdk.yml` (**Beta SDK**): compiles the iOS app with newer beta Xcodes to catch API breakage early. Not a required check.
- `app-intents-xray.yml` (**App Intents X-ray**): the X-ray's behaviour stage, signed out, on `main` after TestFlight. Evidence only, not a required check.
- `testflight.yml` (**TestFlight**): publishes to internal TestFlight after Native succeeds on a `main` push.
- `submit-app-store-review.yml`, `app-store-release.yml` and `app-review-watch.yml` (**App Store**): submit a version to App Review, release it, and keep one `app-review` issue per platform and version while it is in review ([App Review](docs/apple-distribution.md#app-review)).

## Release

Every green Native run on `main` publishes that exact commit to the internal TestFlight group. `docs/apple-distribution.md` describes the pipeline, the evidence it checks, and how to roll back with a manual dispatch.

`main` is version 1.2. A fix for a version with App Review goes on that version's release branch: today `release/1.0-resubmit` for iOS 1.0 and `release/1.1` for Mac 1.1 (the open `app-review` issues show each platform's version under review). Open the pull request against that branch, then dispatch TestFlight, "Stage App Store listing" or "Submit for App Review" with `release_branch` set to it; all three build or read from that branch ([Release branches](docs/apple-distribution.md#release-branches)).
