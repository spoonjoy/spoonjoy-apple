# Unit 0e Evidence Summary

## Commands

All commands ran from canonical checkout `/Users/arimendelow/Projects/spoonjoy-apple`.

```bash
scripts/testflight-feedback-autopilot.mjs doctor
scripts/testflight-feedback-autopilot.mjs install-launchd
scripts/testflight-feedback-autopilot.mjs doctor
scripts/testflight-feedback-autopilot.mjs status --plain
launchctl print gui/$(id -u)/com.spoonjoy.testflight-feedback-listener
launchctl print gui/$(id -u)/com.spoonjoy.testflight-feedback-tunnel
launchctl print gui/$(id -u)/com.spoonjoy.testflight-feedback-reconcile
```

Artifacts:

- `unit-0e-before-doctor.json`
- `unit-0e-install-launchd.log`
- `unit-0e-after-doctor.json`
- `unit-0e-status.txt`
- `unit-0e-launchctl-print.txt`

## Before

`doctor` reported `ok: false`. The installed listener, tunnel, and reconcile services were loaded, but their working directories and/or script paths pointed at retired `/Users/arimendelow/Projects/spoonjoy-apple-cookmode-ui-pass`.

## Repair

`scripts/testflight-feedback-autopilot.mjs install-launchd` rewrote and reloaded:

- `com.spoonjoy.testflight-feedback-listener`
- `com.spoonjoy.testflight-feedback-tunnel`
- `com.spoonjoy.testflight-feedback-reconcile`

The install output reported `ok: true` and zero install issues.

## After

`doctor` reported `ok: true`:

- listener local health: ok
- repo: `/Users/arimendelow/Projects/spoonjoy-apple`
- script path: `/Users/arimendelow/Projects/spoonjoy-apple/scripts/testflight-feedback-autopilot.mjs`
- install items: all ok, no issues

`status --plain` reported:

- install: ok
- local health: ok
- public health: ok
- listener: running
- tunnel: running
- reconcile: interval service, last exit 0 in `launchctl print`
- actionable feedback: 0
- awaiting confirmation: 9

`launchctl print` confirms all service working directories now point at canonical `/Users/arimendelow/Projects/spoonjoy-apple`. The tunnel config path and any sensitive-looking paths were redacted in committed artifacts.

## Next

Unit 0f must re-run the latest feedback gate after the repair with fresh `status --plain`, `doctor`, and `reconcile --dry-run` artifacts before Unit 1 begins.
