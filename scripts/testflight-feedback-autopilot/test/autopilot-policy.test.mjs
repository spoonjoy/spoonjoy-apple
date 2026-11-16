import assert from "node:assert/strict";
import { test } from "node:test";
import {
  DEFAULT_MAX_LAUNCH_ATTEMPTS,
  OURO_DISPATCH_TIMEOUT_MS,
  OURO_FAST_TIMEOUT_MS,
  classifyCodexExit,
  extractQuotaResetHint,
  failedEventState,
  looksLikeCodexQuotaFailure,
  nextLaunchAttemptCount,
  normalizeOuroTimeoutMs,
  reconcileEventId,
  shouldRelaunchFeedback,
} from "../../testflight-feedback-autopilot-policy.mjs";

test("dispatch commands outlast the daemon's 8-minute acknowledgement budget", () => {
  // `ouro event submit` blocks until the managed private-runtime child
  // acknowledges. The daemon budget is 8 minutes (PRIVATE_RUNTIME_DISPATCH_ACK_TIMEOUT_MS);
  // a shorter caller timeout kills a dispatch that is about to succeed.
  assert.ok(OURO_DISPATCH_TIMEOUT_MS > 8 * 60_000, "must outlast the 8 minute ack budget");
  assert.equal(normalizeOuroTimeoutMs(["event", "submit", "--agent", "slugger"]), OURO_DISPATCH_TIMEOUT_MS);
  assert.equal(normalizeOuroTimeoutMs(["msg", "--to", "slugger", "hi"]), OURO_DISPATCH_TIMEOUT_MS);
});

test("fast ouro commands keep the short timeout", () => {
  assert.equal(normalizeOuroTimeoutMs(["version"]), OURO_FAST_TIMEOUT_MS);
  assert.equal(normalizeOuroTimeoutMs(["whoami"]), OURO_FAST_TIMEOUT_MS);
  assert.equal(normalizeOuroTimeoutMs([]), OURO_FAST_TIMEOUT_MS);
});

test("a quota wall is recognised in codex output prose", () => {
  const real = "You've hit your usage limit. Upgrade to Plus to continue using Codex";
  assert.ok(looksLikeCodexQuotaFailure(real));
  assert.ok(looksLikeCodexQuotaFailure("usage limit. Upgrade to Plus to continue using Codex"));
  assert.ok(looksLikeCodexQuotaFailure("Error: insufficient_quota"));
});

test("ordinary codex failures are not mistaken for a quota wall", () => {
  assert.equal(looksLikeCodexQuotaFailure("error: expected `}` but found EOF"), false);
  assert.equal(looksLikeCodexQuotaFailure(""), false);
  assert.equal(looksLikeCodexQuotaFailure(undefined), false);
  // "rate limit" must not swallow a plain network error message.
  assert.equal(looksLikeCodexQuotaFailure("connect ETIMEDOUT while rate limiting disabled"), false);
});

test("the quota reset hint is extracted only when it looks like a date or time", () => {
  const real = "You've hit your usage limit. Upgrade to Plus to continue using Codex (resets Dec 13th, 2026 at 6:30 PM)";
  const hint = extractQuotaResetHint(real);
  assert.ok(hint, "expected a reset hint");
  assert.match(hint, /Dec|13|6:30/i);
  assert.equal(extractQuotaResetHint("upgrade to plus"), null);
  assert.equal(extractQuotaResetHint(""), null);
});

test("a non-zero codex exit is classified as quota only when the output says so", () => {
  assert.deepEqual(classifyCodexExit({ code: 0, output: "" }), { status: "fixed_unconfirmed", quota: false });
  assert.deepEqual(classifyCodexExit({ code: 1, output: "expected `}` but found EOF" }), { status: "failed", quota: false });
  const quota = classifyCodexExit({ code: 1, output: "You've hit your usage limit" });
  assert.equal(quota.status, "failed_quota");
  assert.equal(quota.quota, true);
});

test("a failure never clears the dedup entries", () => {
  // Regression guard: markEventFailed() used to delete the instance id and the
  // event id, which re-opened the event for the next webhook delivery.
  const state = failedEventState({
    handledInstanceIds: ["AKhew2jV5vXu5vxpq55rhd0"],
    launchedEventIds: ["reconcile:betaFeedbackCrashSubmissions:AKhew2jV5vXu5vxpq55rhd0:attempt-1"],
  });
  assert.deepEqual(state.handledInstanceIds, ["AKhew2jV5vXu5vxpq55rhd0"]);
  assert.equal(state.launchedEventIds.length, 1);
});

test("a quota failure is not relaunched until the quota resets", () => {
  assert.equal(shouldRelaunchFeedback({ status: "failed_quota", launchAttempts: 0 }), false);
  assert.equal(shouldRelaunchFeedback({ status: "failed_quota", launchAttempts: 9 }), false);
});

test("an ordinary failure is relaunched only within the retry budget", () => {
  assert.equal(shouldRelaunchFeedback({ status: "failed", launchAttempts: 0 }), true);
  assert.equal(shouldRelaunchFeedback({ status: "failed", launchAttempts: 2 }), true);
  assert.equal(shouldRelaunchFeedback({ status: "failed", launchAttempts: 3 }), false);
  assert.equal(shouldRelaunchFeedback({ status: "failed", launchAttempts: 1, maxLaunchAttempts: 1 }), false);
});

test("finished and human-gated statuses are never relaunched", () => {
  for (const status of ["confirmed", "succeeded", "ignored", "needs_human"]) {
    assert.equal(shouldRelaunchFeedback({ status, launchAttempts: 0 }), false, status);
  }
});

test("the retry budget defaults to three launches per instance", () => {
  assert.equal(DEFAULT_MAX_LAUNCH_ATTEMPTS, 3);
  assert.equal(nextLaunchAttemptCount(0), 1);
  assert.equal(nextLaunchAttemptCount(2), 3);
  assert.equal(nextLaunchAttemptCount(undefined), 1);
});

test("the reconcile event id is stable per instance attempt so dedup can match", () => {
  const first = reconcileEventId({ type: "betaFeedbackCrashSubmissions", instanceId: "AE1H28BYqlu1lSiZnNV2mNI", attempt: 1 });
  const again = reconcileEventId({ type: "betaFeedbackCrashSubmissions", instanceId: "AE1H28BYqlu1lSiZnNV2mNI", attempt: 1 });
  const second = reconcileEventId({ type: "betaFeedbackCrashSubmissions", instanceId: "AE1H28BYqlu1lSiZnNV2mNI", attempt: 2 });
  assert.equal(first, again, "same instance and attempt must produce the same id");
  assert.notEqual(first, second, "a later attempt must produce a different id");
  assert.equal(first, "reconcile:betaFeedbackCrashSubmissions:AE1H28BYqlu1lSiZnNV2mNI:attempt-1");
});

test("the reconcile event id contains no random component", () => {
  // The old id embedded a fresh randomUUID() per cycle, so launchedEventIds
  // could never dedup a repeat and the instance was re-queued forever.
  const id = reconcileEventId({ type: "betaFeedbackCrashSubmissions", instanceId: "AKhew2jV5vXu5vxpq55rhd0", attempt: 1 });
  assert.doesNotMatch(id, /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}/);
  assert.doesNotMatch(id, /[0-9a-f]{32}/);
});

test("the reconcile event id sanitises hostile ids", () => {
  const id = reconcileEventId({ type: "../../etc/passwd", instanceId: "a/b:c", attempt: 1 });
  assert.doesNotMatch(id, /\.\./);
  assert.doesNotMatch(id, /[/\\]/);
});
