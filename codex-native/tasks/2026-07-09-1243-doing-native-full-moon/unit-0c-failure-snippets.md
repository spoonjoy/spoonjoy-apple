# Unit 0c Failure Snippets

These are the relevant excerpts from the verbose per-route smoke logs before the full Xcode logs were pruned from committed evidence.

## Outer Matrix Timeout

Source: `unit-0c-baseline-capture.log`

```text
capturing native route capture (capture)
baseline capture timed out after 900s
-e:10:in `kill': Operation not permitted (Errno::EPERM)
-e:5:in `wait': execution expired (Timeout::Error)
```

## Root Kitchen Capture

Source: `unit-0c-baseline-screenshots/apple/unit-0c-route-matrix.jsonl`

```json
{"name":"kitchen","route":"kitchen","status":"fail","blocked":false,"missingDesignReview":true,"iosScreenshot":{"exists":false},"macosScreenshot":{"exists":false}}
```

Problem: the root `kitchen` route failed before screenshot/design-review artifacts were produced. No `design-review-blocked.json` was emitted.

## Shopping List Capture

Source: pruned `unit-0c-shopping-list-screenshots-smoke-ios.log`

```text
** BUILD SUCCEEDED **
iOS simulator build exit code: 0
Booting simulator: xcrun simctl boot 10C519CA-BBD2-4780-870C-925916412F67
Simulator was already booted; suppressed benign CoreSimulator boot diagnostic.
simulator boot exit code: 0
Uninstalling stale app before fresh install: 10C519CA-BBD2-4780-870C-925916412F67 app.spoonjoy
Installing app: .../shopping-list/DerivedData-iOS/Build/Products/BootstrapDebug-iphonesimulator/Spoonjoy.app
command timed out after 30 seconds
simulator install exit code: 124
```

Problem: the app built, but simulator install timed out and the harness returned a route failure without a terminal blocker artifact.

## Capture Route

Source: pruned `unit-0c-capture-screenshots-smoke-ios.log` and `unit-0c-capture-screenshots-smoke-macos.log`

```text
** BUILD SUCCEEDED **
iOS simulator build exit code: 0
simulator install exit code: 0
Launching app: xcrun simctl launch --terminate-running-process app.spoonjoy
app.spoonjoy: 14712
simulator launch exit code: 0
```

```text
Running macOS launch smoke
** BUILD INTERRUPTED **
```

Problem: iOS launch smoke succeeded, then the outer 900 second wrapper interrupted macOS launch smoke. The matrix did not get a terminal route row for `capture`.
