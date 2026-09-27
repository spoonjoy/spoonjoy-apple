# AGENTS.md — Spoonjoy Apple

This repo contains the native iOS and macOS app for Spoonjoy.

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

- Preserve the Spoonjoy web product language documented in `spoonjoy-v2/docs/design-language.md`.
- Treat the native translation in `docs/native-design-language.md` as the local design brief.
- Use native controls for navigation, lists, toolbars, sheets, search, share, edit mode, steppers, disclosure, and confirmations when they feel premium and platform-correct.
- Do not let default SwiftUI grouped screens erase Spoonjoy's authored cookbook feel.
- Food leads. Cards are only for real objects or overlays. No dashboard-neutral equal grids as the primary experience.

## Platform Baseline

- Target iOS 27 and macOS 27 forward.
- Use one SwiftUI project with shared domain/API/cache/App Intents code and separate iOS/macOS targets unless planning proves a split is necessary.
- Use the reverse-DNS namespace for `spoonjoy.app`; use `app.spoonjoy` for the primary iOS app and `app.spoonjoy.mac` for the macOS companion.
- Do not depend on paid Apple Developer Program signing before local simulator and device validation. TestFlight waits until Apple Developer Program membership is available.

## Work Suite Autopilot

- Human gates are waived by default.
- Use `$work-planner` for planning and planning-to-doing conversion.
- Use `$work-doer` for execution.
- Do not self-approve. When approval is needed, use unbiased harsh sub-agent reviewers.
- Ask the human only for true human-only blockers: credentials, billing/subscription changes, private account actions, unavailable hardware, secrets, destructive production operations with no safe staged path, or product decisions the user has not already delegated.
- Completion standard is full moon: defer nothing that is part of the accepted scope. Use multiple atomic PRs until the app is complete and validated.

## Git Workflow

- Work on agent-scoped branches like `slugger/native-apple-bootstrap`.
- Keep commits atomic and push after each commit.
- Required checks on `main` intentionally mirror the native repo posture from `ourostack/ouro-md`: `Swift tests`, `Native scenario verifier`, `App bundle`, and `Coverage`.

## Validation

Spoonjoy is built for agentic developers end to end, and so is its validation.

- **App behaviour is validated in CI, against the web QA mirror, not on your machine.** The QA mirror is `spoonjoy-v2-qa` (`https://spoonjoy-v2-qa.mendelow-studio.workers.dev`): its own Worker, D1, R2 and Durable Objects, in production mode. Native UI journeys run as XCUITests on GitHub's macOS runners (`.github/workflows/journeys.yml`) with the app pointed at QA. Each run creates two disposable `codex-native-*` accounts through QA's `/signup` (`scripts/journey-qa-accounts.sh`), rotates their passwords when the run ends, and QA's cleanup removes them after 3 hours; journeys never use the web personas. Journeys live in `Apps/Spoonjoy/Journeys/`, follow the house rules enforced by `swift run SpoonjoyJourneyRules Apps/Spoonjoy/Journeys .github/workflows/journeys.yml scripts/journey-qa-accounts.sh`, and failures are read from the `journeys-xcresult-*` artifact. Local simulator runs are for writing code, not for proving it works.
- **Test outcomes, not source text.** A check passes only when a real user action produces a result that survives relaunching the app or shows up on another screen. Scripts that only confirm a type name or string exists in a source file are not validation; replace them with behaviour tests as journeys land. Flaky is failing: no retry loops around taps.
- **Every bug becomes a failing journey step first**, then a fix. Read failures from the CI artifacts (`.xcresult` bundles and screenshots).
- **Coverage is not validation.** Coverage reporting stays, but green coverage says nothing about whether a user can use the app.
- The native journey harness is being built after the web harness (tracked on Ari's desk as `spoonjoy/real-validation-layer`). Until it lands, the protected checks (`Swift tests`, `Native scenario verifier`, `App bundle`, `Coverage`) remain required, and new work should add XCUITest behaviour coverage rather than more source-text contract scripts.
