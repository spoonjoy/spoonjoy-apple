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

Before merging native app work, run the most specific local checks available, then the full protected checks in GitHub.

Expected validation grows with the app:

- Swift unit tests.
- Native scenario verification for core user flows.
- App bundle build for iOS and macOS targets.
- Coverage reporting.
- Simulator validation on mobile and desktop-class layouts.
- Manual screenshot review for the Spoonjoy design language.

