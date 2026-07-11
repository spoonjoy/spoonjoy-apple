# Unit 2e Red Summary

Command:

```bash
ruby -c scripts/check-native-loading-transition-contract.rb
ruby scripts/check-native-loading-transition-contract.rb > codex-native/tasks/2026-07-09-1243-doing-native-full-moon/unit-2e/check-native-loading-transition-contract-red.log 2>&1
```

Expected failure:

- No shared authored `KitchenTableLoadingStateView` / `KitchenTableRouteErrorView` exists yet.
- Route wrappers still use raw `ProgressView()` loading chrome.
- Several route errors still use generic `unavailable` copy.
- Search image loading uses a fixed animation transaction instead of reduce-motion-aware image phases.
- `OfflineStatusView` quiet informational states still use brass instead of a quiet muted treatment.

This contract targets the TestFlight complaints about snap-in loading, false unavailable states, and loud non-critical status UI.

