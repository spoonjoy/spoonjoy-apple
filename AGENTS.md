# AGENTS.md — Spoonjoy Apple

This repo contains the native Spoonjoy app for iPhone, iPad and Mac.

## Start here

- Needs Xcode 27, and Ruby 3.3 with `bundle install` for the scripts ([Requirements](README.md#requirements)).
- Unit tests: `swift test --disable-xctest --parallel`. Build: `xcodebuild -project Spoonjoy.xcodeproj -scheme "Spoonjoy iOS" -configuration BootstrapDebug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`.
- The app talks to the web app's `/api/v1` API; the API and MCP server are described at [spoonjoy.app/developers](https://spoonjoy.app/developers), and their source is in [spoonjoy/spoonjoy-v2](https://github.com/spoonjoy/spoonjoy-v2).
- Layout, CI and release: [README.md](README.md#layout).

## Pull requests merge within 30 minutes

Spoonjoy follows ourostack's shared rule, [every PR merges within 30 minutes](https://github.com/ourostack/.github/blob/main/agents/prs-merge-within-30-minutes.md). Finish, review and validate on your branch first, then publish with `gh ouro-pr`, which turns auto-merge on so green means merged. When a PR here shows on the [PR clock](https://github.com/ourostack/.github/issues?q=is%3Aissue+is%3Aopen+label%3Apr-clock), act on it now: merge it if green, fix the cause if red (file an issue before any rerun), rebase it if conflicted, or close it with a reason if it isn't going anywhere.

## Product Intent

Spoonjoy Apple must justify being native. Do not build a thin web clone.

Native value should come from platform capabilities:

- SwiftUI iOS and macOS surfaces that feel at home on each platform.
- App Intents and Siri actions for recipes, shopping lists, cook mode, and cook logging.
- Spotlight indexing for recipes, cookbooks, shopping items, and cook history.
- Camera, Photos, OCR, barcode, and Foundation Models workflows for recipe capture and grocery use.
- Offline-capable recipe, cook mode, and shopping-list flows.
- Widgets, Watch, notifications, and lock-screen-adjacent surfaces where they make cooking or shopping materially better.

## Design Language

The app must feel native and still unmistakably Spoonjoy.

- Preserve the Spoonjoy web product language documented in [`spoonjoy-v2/docs/design-language.md`](https://github.com/spoonjoy/spoonjoy-v2/blob/main/docs/design-language.md).
- Treat the native translation in `docs/native-design-language.md` as the local design brief.
- Use native controls for navigation, lists, toolbars, sheets, search, share, edit mode, steppers, disclosure, and confirmations when they feel premium and platform-correct.
- Do not let default SwiftUI grouped screens erase Spoonjoy's authored cookbook feel.
- Food leads. Cards are only for real objects or overlays. No dashboard-neutral equal grids as the primary experience.

## Platform Baseline

- Target iOS 27 and macOS 27 forward.
- Use one SwiftUI project with shared domain/API/cache/App Intents code and separate iOS/macOS targets unless planning proves a split is necessary.
- Use the reverse-DNS namespace for `spoonjoy.app`; use `app.spoonjoy` for both the iOS and macOS apps, so one App Store record sells them together (universal purchase).
- Signing is live: TestFlight builds ship through `testflight.yml` (internal testing) and App Review submissions through `submit-app-store-review.yml`.

## Work Suite Autopilot

- Human gates are waived by default.
- Plan before coding: with the work-suite skills, `$work-planner` writes the planning doc and turns it into a doing doc, and `$work-doer` carries the doing doc out unit by unit. Without them, write the plan in the task's doc first.
- Do not self-approve. When approval is needed, use unbiased harsh sub-agent reviewers.
- Ask the human only for true human-only blockers: credentials, billing/subscription changes, private account actions, unavailable hardware, secrets, destructive production operations with no safe staged path, or product decisions the user has not already delegated.
- While a version is with App Review, check for open `app-review` issues and the release workflow's `status` at the start of every session; see `docs/apple-distribution.md#app-review`.
- `main` builds the next version (1.3). A fix for a version already with App Review goes by pull request to that version's release branch (today `release/1.1` for Mac 1.1 and `release/1.2` for iOS 1.2 and Mac 1.2; the open `app-review` issues show each platform's version), never by holding `main` back; TestFlight, "Stage App Store listing" and "Submit for App Review" take `release_branch` set to that branch to build, stage and submit from it. Port the fix to `main` too when it still applies. See `docs/apple-distribution.md#release-branches`.
- Completion standard is full moon: defer nothing that is part of the accepted scope. Use multiple atomic PRs until the app is complete and validated.

## Git Workflow

- Work on agent-scoped branches like `slugger/native-apple-bootstrap`.
- Keep commits atomic and push after each commit.
- Required checks on `main` are `Swift tests`, `Native scenario verifier`, `App bundle`, `Contracts`, and `Reins journeys` from Native, and `Changelog fragment` from `changelog.yml`.
- A pull request that changes what someone using the app could notice adds a changelog fragment in `changes/`: a short harrowing tale for What's New and one plain line for TestFlight ([changes/README.md](changes/README.md), voice in [docs/whats-new-voice.md](docs/whats-new-voice.md)). Every sentence must be true of the change. The `Changelog fragment` check (`changelog.yml`) fails an app change without one; label the pull request `no-user-facing-change` when nobody could notice it.
- Optional macOS checks never run beside the required ones on a pull request: Native calls them after every required check passes (README, CI). Never add a `pull_request` trigger to a macOS workflow; add a call in `native.yml` instead.

## Validation

Spoonjoy is built for agentic developers end to end, and so is its validation.

- **App behaviour is validated in CI, against the web QA mirror, not on your machine.** The QA mirror is `spoonjoy-v2-qa` (`https://spoonjoy-v2-qa.mendelow-studio.workers.dev`): its own Worker, D1, R2 and Durable Objects, in production mode. Native UI journeys run as XCUITests on GitHub's macOS runners (`.github/workflows/journeys.yml`) with the app pointed at QA. Each run creates two disposable `codex-native-*` accounts through QA's `/signup` (`scripts/journey-qa-accounts.sh`), rotates their passwords when the run ends, and QA's cleanup removes them after 3 hours; journeys never use the web personas. Journeys live in `Apps/Spoonjoy/Journeys/`, follow the house rules enforced by `swift run SpoonjoyJourneyRules Apps/Spoonjoy/Journeys .github/workflows/journeys.yml scripts/journey-qa-accounts.sh`, and failures are read from the `journeys-xcresult-*` artifact. Local simulator runs are for writing code, not for proving it works.
- **Test outcomes, not source text.** A check passes only when a real user action produces a result that survives relaunching the app or shows up on another screen. Scripts that only confirm a type name or string exists in a source file are not validation; replace them with behaviour tests as journeys land. Flaky is failing: no retry loops around taps. The one retry is the Live journeys job's second attempt after a network or launch failure (`scripts/lib/live_journey_failure.rb` decides the class); an assertion failure never gets one.
- **Every bug becomes a failing journey step first**, then a fix. Read failures from the CI artifacts (`.xcresult` bundles and screenshots).
- **Coverage is not validation.** Coverage reporting stays, but green coverage says nothing about whether a user can use the app.
- Native journeys run in CI: the required headless `Reins journeys` check (`SpoonjoyReinsTests`, in `native.yml`) and the live XCUITest layer in `journeys.yml`. New work adds behaviour coverage there rather than more source-text contract scripts.
