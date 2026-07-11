# Unit 2c Red Summary

Command:

```bash
ruby -c scripts/check-native-shell-contract.rb
ruby scripts/check-native-shell-contract.rb > codex-native/tasks/2026-07-09-1243-doing-native-full-moon/unit-2c/check-native-shell-contract-red.log 2>&1
```

Expected failure:

- `SpoonDock` has no centralized `SpoonDockMetrics`.
- The mobile dock uses a raw `351` max width.
- Icon/text target sizes are magic numbers instead of shared metrics.
- The whole mobile dock is painted as a dark `photoCharcoal` capsule.
- The dock shadow is too heavy at opacity/radius `0.22/16`.

The same contract also locks in:

- `SpoonDock` remains an iOS compact affordance for cook mode, with macOS excluded.
- Cook mode keeps a bottom safe-area inset for compact dock controls.
- The shared toolbar keeps a native primary-action `Menu` with share/edit/search actions.

