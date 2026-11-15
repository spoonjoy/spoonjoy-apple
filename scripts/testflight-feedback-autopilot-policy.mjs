// Pure policy helpers for the TestFlight feedback autopilot.
//
// These live apart from scripts/testflight-feedback-autopilot.mjs because that
// script runs main() at import time and cannot be imported by a unit test.
// Everything here is a total function over plain data so the retry/dedup rules
// can be exercised without a daemon, a simulator, or App Store Connect.
//
// Background: `ouro event submit` blocks until the managed private-runtime
// child acknowledges the dispatch (process-manager.js, dispatchToAgent), whose
// own timeout is PRIVATE_RUNTIME_DISPATCH_ACK_TIMEOUT_MS = 8 minutes. The
// autopilot used to spawn every `ouro` call with a 60s timeout, so successful
// dispatches were misreported as "exit null" and the autopilot needlessly fell
// back to `ouro msg` plus a direct Codex run. Worse, markEventFailed() removed
// the dedup entries, and the reconcile loop minted a fresh random eventId every
// cycle, so one instance could be re-queued roughly every 10 minutes forever.

export const OURO_FAST_TIMEOUT_MS = 60_000;

// `ouro event submit` and `ouro msg` both wait for the private-runtime child to
// acknowledge. The daemon's own budget for that acknowledgement is 8 minutes
// (PRIVATE_RUNTIME_DISPATCH_ACK_TIMEOUT_MS in process-manager.js), so the
// caller must outlast it or it will kill a dispatch that is about to succeed.
export const OURO_DISPATCH_TIMEOUT_MS = 9 * 60_000;

// Codex reports account-level quota exhaustion in prose, not as a distinct exit
// code, so the exit code alone cannot tell "quota wall" from "real bug".
const QUOTA_MARKERS = [
  "you've hit your usage limit",
  "you have hit your usage limit",
  "usage limit. upgrade to plus",
  "upgrade to plus to continue using codex",
  "rate limit exceeded",
  "too many requests",
  "insufficient_quota",
  "quota exceeded",
];

const QUOTA_RESET_PATTERN = /(?:reset|until|resets?)\s*:?\s*([^\n]{0,60})/i;

export function normalizeOuroTimeoutMs(args) {
  const list = Array.isArray(args) ? args.map((arg) => String(arg)) : [];
  const isDispatch = list[0] === "event" || list[0] === "msg";
  return isDispatch ? OURO_DISPATCH_TIMEOUT_MS : OURO_FAST_TIMEOUT_MS;
}

export function looksLikeCodexQuotaFailure(text) {
  if (typeof text !== "string" || text.length === 0) return false;
  const haystack = text.toLowerCase();
  return QUOTA_MARKERS.some((marker) => haystack.includes(marker));
}

export function extractQuotaResetHint(text) {
  if (typeof text !== "string") return null;
  const match = text.match(QUOTA_RESET_PATTERN);
  if (!match) return null;
  const hint = match[1].replace(/\s+/g, " ").trim();
  if (!hint) return null;
  if (!/dec|jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|\d{1,2}:\d{2}|\d{4}|pm|am/i.test(hint)) return null;
  return hint;
}

// A retry budget keeps one poisoned instance from looping forever. Each
// instance may be relaunched at most this many times; after that it stays
// parked and visible instead of being re-queued on every reconcile pass.
export const DEFAULT_MAX_LAUNCH_ATTEMPTS = 3;

export function shouldRelaunchFeedback({ status, launchAttempts = 0, maxLaunchAttempts = DEFAULT_MAX_LAUNCH_ATTEMPTS }) {
  if (status === "failed_quota") return false;
  if (status === "confirmed" || status === "succeeded" || status === "ignored") return false;
  if (status === "needs_human") return false;
  if (launchAttempts >= maxLaunchAttempts) return false;
  return true;
}

export function nextLaunchAttemptCount(launchAttempts = 0) {
  return Number(launchAttempts || 0) + 1;
}

// markEventFailed() used to delete the dedup entries, which re-opened the
// event for the very next webhook delivery. A failure must never clear the
// instance's dedup membership; only an explicit reset may.
export function failedEventState({ handledInstanceIds = [], launchedEventIds = [] }) {
  return {
    handledInstanceIds: [...handledInstanceIds],
    launchedEventIds: [...launchedEventIds],
  };
}

export function classifyCodexExit({ code, output = "" }) {
  if (code === 0) return { status: "fixed_unconfirmed", quota: false };
  if (looksLikeCodexQuotaFailure(output)) {
    return { status: "failed_quota", quota: true, resetHint: extractQuotaResetHint(output) };
  }
  return { status: "failed", quota: false };
}

// The reconcile loop used to mint `reconcile:<type>:<instanceId>:<randomUUID()>`
// on every pass, so launchedEventIds could never dedup a repeat. A stable key
// per instance (plus attempt) keeps the dedup meaningful.
// Event ids land in filenames and in the launchedEventIds dedup set, so they
// must not be able to carry path separators or traversal sequences.
function sanitizeEventIdPart(value) {
  return String(value || "unknown")
    .replace(/\.\./g, "")
    .replace(/[^A-Za-z0-9_.-]/g, "-");
}

export function reconcileEventId({ type, instanceId, attempt = 1 }) {
  const safeType = sanitizeEventIdPart(type);
  const safeInstance = sanitizeEventIdPart(instanceId);
  const safeAttempt = Math.max(1, Number(attempt || 1));
  return `reconcile:${safeType}:${safeInstance}:attempt-${safeAttempt}`;
}
