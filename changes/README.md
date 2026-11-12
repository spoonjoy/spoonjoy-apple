# Changelog fragments

Every pull request that changes something a person using Spoonjoy could notice adds one fragment here: a short tale for the App Store's What's New and one plain line for TestFlight. Parallel pull requests never touch the same lines, and nobody writes release notes at release time.

The required `Changelog fragment` check fails a pull request that changes the app (`Apps/Spoonjoy/iOS`, `macOS`, `Shared`, `LiveActivity`, `Sources/SpoonjoyCore`, `Package.swift`, `Package.resolved`) without adding or editing a fragment. If nobody using the app could notice the change (a refactor, a test, a fix to an unreleased screen that a fragment already covers), label the pull request `no-user-facing-change` instead.

## Write one

Name the file after the change, such as `amber-after-dark.md`: lowercase letters, digits and hyphens. Then:

```markdown
---
testflight: At night, the main button on a screen (Cook, Start cooking, Next step, Add item) fills amber.
platforms: [ios, mac]
order: 30
---
After dark, the one button that matters, Cook or Next step, used to fade into a pale bone colour you had to hunt for. It now glows amber, like a pilot light, so you can find it with flour on your glasses.
```

- `testflight` (required): one plain line, at most 160 characters, saying what changed and where to look. Testers read it in TestFlight's What to Test. Front matter is read literally, one `key: value` per line, so a `#270` or a colon in it is just text.
- `platforms` (optional, default both): `ios` (iPhone and iPad), `mac`, or both. A tale for both must be true on both: the check refuses Lock Screen, Dynamic Island, Duo, hinge, tap, swipe, iPhone and iPad in a tale the Mac shows. A tale is told against the version people on that platform have now, so a change Mac users already got in Mac 1.1 is `platforms: [ios]` in 1.2 (iOS went from 1.0 to 1.2).
- `order` (optional, default 50): where the tale sits in What's New, lowest first. Ties go by file name. Give the change people will care about most a low number.
- The body is the tale, in the voice of [docs/whats-new-voice.md](../docs/whats-new-voice.md). Plain text only: the App Store shows Markdown as stray symbols, so no headings, bold, links, backticks or `-` lists. Start a bullet with `•`.

A release can also have one `kind: prologue` and one `kind: epilogue` per platform. They open and close the tale and have no `testflight` line. Whoever cuts the release, or the first pull request of the version, usually writes them.

Edit a fragment that is still waiting here when a later pull request changes the same feature before it ships. Leave `released/` alone.

`ruby scripts/changelog.rb validate` checks every fragment and each platform's What's New against the App Store's 4000-character limit. `ruby scripts/changelog.rb whats-new --platform IOS` (or `MAC_OS`) prints the assembled text.

## At release

Nothing here is written at release time, and no model runs.

- **TestFlight:** every green build of `main` gets What to Test from `scripts/changelog.rb testflight-notes`: the lines of the fragments that build added, then every other line waiting for the version.
- **App Store:** "Stage App Store listing" fills What's New from the fragments of the commit it stages: the prologue, the tales by `order` then name, then the epilogue. A `whatsNew` written in `listing.json` wins for that platform only, and `null` there leaves What's New out (a platform's first version cannot have one).
- **Archive:** the pull request that moves `main` to the next version runs `ruby scripts/changelog.rb archive --version <the old version>`. It moves the fragments to `released/<version>/` beside the What's New each platform shipped. A `whatsNew` written in `listing.json` is what that platform shipped, so archive records it and removes it from the listing, where it would otherwise win over the next version's fragments. The check refuses a version change that leaves the old version's fragments waiting, in the pull request and again in the merge queue against main as it is then.

A release branch (`release/<version>`) carries the fragments it was cut with, so a fix there adds its own fragment on that branch.
