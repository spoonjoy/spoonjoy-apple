<!-- spoonjoy:brand:start -->
<p align="center">
  <a href="https://spoonjoy.app"><picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/spoonjoy/.github/main/brand/headers/spoonjoy-apple-dark.webp">
    <img src="https://raw.githubusercontent.com/spoonjoy/.github/main/brand/headers/spoonjoy-apple-light.webp" alt="Spoonjoy on a Mac showing the kitchen, beside two iPhones: one in cook mode with a ten-minute timer, one on the Lemon Pantry Pasta recipe" width="100%">
  </picture></a>
</p>
<!-- spoonjoy:brand:end -->

# Spoonjoy Apple

Spoonjoy for iPhone, iPad and Mac, written in SwiftUI.

[spoonjoy.app](https://spoonjoy.app) · [Web app and API](https://github.com/spoonjoy/spoonjoy-v2) · [Design language](docs/native-design-language.md) · [AGENTS.md](AGENTS.md)

**Start:** with Xcode 27, `swift test --disable-xctest --parallel` runs the core tests, and the `Spoonjoy iOS` scheme in `Spoonjoy.xcodeproj` runs the app ([Build and test](#build-and-test)).

The app is in internal TestFlight testing and not on the App Store yet. It talks to the [Spoonjoy](https://spoonjoy.app) web app's `/api/v1` API and signs in through its OAuth flow; the web app and API live in [spoonjoy/spoonjoy-v2](https://github.com/spoonjoy/spoonjoy-v2). `AGENTS.md` holds the product intent and the working rules for agents.

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

Xcode 27 (CI pins `/Applications/Xcode_27.1.app`; 27.0 works locally but compiles out the iPhone Duo hinge code) and Ruby 3.3 with Bundler for the scripts (`bundle install`). The app targets iOS 27 and macOS 27.

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

- `native.yml` (**Native**): runs on every pull request and push to `main`. Required checks on `main` are `Swift tests`, `Native scenario verifier`, `App bundle` and `Contracts`. `Ruby advisory scan` runs alongside them. On pull requests, `App Intents X-ray` (macos-26) runs Ouro AX's X-ray, from the `ourostack/ouro-ui-apple` version `Package.swift` pins, over the App Intents metadata the App bundle job builds and holds it to `config/xray-expected.json` (`ruby scripts/check-xray.rb <report.json>`), and lints the Siri AI app skills in `Apps/Spoonjoy/Shared/Skills.skillsbundle` with `ouro-ax-skills lint --strict`; its behaviour stage is `app-intents-xray.yml`, on `main` pushes only, on `xcode-27`, and never gates Native. To X-ray a local build: `swift package resolve && swift build -c release --package-path .build/checkouts/ouro-ui-apple --product ouro-ax-xray`, then `.build/checkouts/ouro-ui-apple/.build/release/ouro-ax-xray --app <Spoonjoy.app> --out <dir>`.
- `journeys.yml` (**Journeys**): XCUITest against QA. **Live journeys** is the thin live layer (cook-session sync, the edit conflict, sign-in and blocked chefs, plus the UI and OS checks a headless test cannot make); headless Journeys in `SpoonjoyReinsTests` carry the rest. A network or launch failure is retried once on fresh accounts and reported as infrastructure in the job summary (`scripts/live-journeys.rb`); an assertion failure is never retried. Also runs the Duo journeys and shopping UI tests. Not a required check.
- `beta-sdk.yml` (**Beta SDK**): compiles the iOS app with newer beta Xcodes to catch API breakage early. Not a required check.
- `app-intents-xray.yml` (**App Intents X-ray**): the X-ray's behaviour stage, signed out, on `main` pushes. Evidence only, not a required check.
- `testflight.yml` (**TestFlight**): publishes to internal TestFlight after Native succeeds on a `main` push.

## Release

Every green Native run on `main` publishes that exact commit to the internal TestFlight group. `docs/apple-distribution.md` describes the pipeline, the evidence it checks, and how to roll back with a manual dispatch.
