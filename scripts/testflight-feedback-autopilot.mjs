#!/usr/bin/env node
import { createHmac, createSign, randomUUID, timingSafeEqual } from "node:crypto";
import { createServer } from "node:http";
import { spawn } from "node:child_process";
import { appendFileSync, chmodSync, existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import path from "node:path";

const APP_ID = process.env.SPOONJOY_ASC_APP_ID || "6787505444";
const APP_BUNDLE_ID = process.env.SPOONJOY_BUNDLE_ID || "app.spoonjoy";
const APP_NAME = "Spoonjoy";
const DEFAULT_PORT = Number(process.env.SPOONJOY_TESTFLIGHT_FEEDBACK_PORT || 48973);
const DEFAULT_HOST = process.env.SPOONJOY_TESTFLIGHT_FEEDBACK_HOST || "127.0.0.1";
const DEFAULT_REPO = process.env.SPOONJOY_NATIVE_REPO || "/Users/arimendelow/Projects/spoonjoy-apple-testflight-native-publish";
const DEFAULT_THREAD_ID = process.env.SPOONJOY_CODEX_THREAD_ID || "019f2e25-2fc3-75b2-8ba3-335f3777115a";
const DEFAULT_CODEX = process.env.CODEX_CLI_PATH || "/opt/homebrew/bin/codex";
const SUPPORT_DIR = path.join(homedir(), "Library/Application Support/Spoonjoy/TestFlightFeedbackAutopilot");
const DEFAULT_SECRET_PATH = process.env.SPOONJOY_TESTFLIGHT_WEBHOOK_SECRET_PATH || path.join(SUPPORT_DIR, "webhook-secret");
const DEFAULT_STATE_PATH = process.env.SPOONJOY_TESTFLIGHT_FEEDBACK_STATE_PATH || path.join(SUPPORT_DIR, "state.json");
const DEFAULT_EVENT_DIR = process.env.SPOONJOY_TESTFLIGHT_FEEDBACK_EVENT_DIR || path.join(SUPPORT_DIR, "events");
const ASC_CONFIG = process.env.APPLE_DISTRIBUTION_KIT_CONFIG || path.join(homedir(), "Library/Application Support/AppleDistributionKit/app-store-connect/config.json");
const FEEDBACK_EVENTS = new Set(["betaFeedbackScreenshotSubmissionCreated", "betaFeedbackCrashSubmissionCreated"]);
const FEEDBACK_INSTANCE_TYPES = new Set(["betaFeedbackScreenshotSubmissions", "betaFeedbackCrashSubmissions"]);

const command = process.argv[2] || "help";
const args = process.argv.slice(3);

main().catch((error) => {
  console.error(error?.stack || String(error));
  process.exit(1);
});

async function main() {
  if (command === "listen") return listen();
  if (command === "register") return registerWebhook();
  if (command === "seed-current") return seedCurrentFeedback();
  if (command === "smoke") return smokeWebhook();
  if (command === "ping") return pingWebhook();
  if (command === "doctor") return doctor();
  help();
}

function help() {
  console.log(`Usage:
  scripts/testflight-feedback-autopilot.mjs listen
  scripts/testflight-feedback-autopilot.mjs register --url https://testflight-feedback.spoonjoy.app/app-store-connect/webhook
  scripts/testflight-feedback-autopilot.mjs seed-current
  scripts/testflight-feedback-autopilot.mjs smoke [--run-agent]
  scripts/testflight-feedback-autopilot.mjs ping [--id webhook-id]
  scripts/testflight-feedback-autopilot.mjs doctor

Environment:
  SPOONJOY_TESTFLIGHT_WEBHOOK_SECRET_PATH  ${DEFAULT_SECRET_PATH}
  SPOONJOY_TESTFLIGHT_FEEDBACK_STATE_PATH  ${DEFAULT_STATE_PATH}
  SPOONJOY_TESTFLIGHT_FEEDBACK_EVENT_DIR   ${DEFAULT_EVENT_DIR}
  SPOONJOY_CODEX_THREAD_ID                 ${DEFAULT_THREAD_ID}
  SPOONJOY_NATIVE_REPO                     ${DEFAULT_REPO}
  CODEX_CLI_PATH                           ${DEFAULT_CODEX}
`);
}

async function listen() {
  ensureRuntime();
  const secret = readSecret();
  const server = createServer(async (request, response) => {
    try {
      const url = new URL(request.url || "/", `http://${request.headers.host || "localhost"}`);
      if (request.method === "GET" && url.pathname === "/health") {
        return sendJson(response, 200, { ok: true, appId: APP_ID, bundleId: APP_BUNDLE_ID });
      }
      if (request.method !== "POST" || url.pathname !== "/app-store-connect/webhook") {
        return sendJson(response, 404, { ok: false, error: "not_found" });
      }

      const raw = await readBody(request);
      const signature = String(request.headers["x-apple-signature"] || request.headers["x-apple-signature".toLowerCase()] || "");
      if (!verifyAppleSignature(raw, signature, secret)) {
        return sendJson(response, 401, { ok: false, error: "invalid_signature" });
      }

      const payload = JSON.parse(raw.toString("utf8"));
      const events = extractFeedbackEvents(payload);
      if (events.length === 0) {
        return sendJson(response, 202, { ok: true, ignored: true });
      }
      if (request.headers["x-spoonjoy-smoke"] === "no-agent") {
        return sendJson(response, 202, { ok: true, smoke: true, events: events.length });
      }

      const state = loadState();
      const queued = [];
      for (const event of events) {
        if (state.handledInstanceIds.includes(event.instance.id) || state.launchedEventIds.includes(event.eventId)) {
          continue;
        }
        state.launchedEventIds.push(event.eventId);
        state.handledInstanceIds.push(event.instance.id);
        queued.push(event);
      }
      saveState(state);
      sendJson(response, 202, { ok: true, queued: queued.length });

      for (const event of queued) {
        void handleFeedbackEvent(event, payload).catch((error) => {
          appendRuntimeLog(`event ${event.instance.id} failed: ${error?.stack || String(error)}`);
        });
      }
    } catch (error) {
      appendRuntimeLog(`request failed: ${error?.stack || String(error)}`);
      if (!response.headersSent) sendJson(response, 500, { ok: false, error: "listener_error" });
    }
  });

  server.listen(DEFAULT_PORT, DEFAULT_HOST, () => {
    appendRuntimeLog(`listening on http://${DEFAULT_HOST}:${DEFAULT_PORT}`);
    console.log(`Spoonjoy TestFlight feedback listener on http://${DEFAULT_HOST}:${DEFAULT_PORT}`);
  });
}

async function handleFeedbackEvent(event, rawPayload) {
  const eventDir = path.join(DEFAULT_EVENT_DIR, `${new Date().toISOString().replace(/[:.]/g, "-")}-${event.instance.id}`);
  mkdirSync(eventDir, { recursive: true });
  writeJson(path.join(eventDir, "webhook.json"), redactForDisk(rawPayload));
  writeJson(path.join(eventDir, "event.json"), event);

  const detail = await ascRequest("GET", `/v1/${event.instance.type}/${event.instance.id}`);
  writeJson(path.join(eventDir, "detail.json"), detail);

  const imagePaths = [];
  if (event.instance.type === "betaFeedbackScreenshotSubmissions") {
    const screenshots = detail?.data?.attributes?.screenshots || [];
    for (const [index, screenshot] of screenshots.entries()) {
      if (!screenshot?.url) continue;
      const file = path.join(eventDir, `screenshot-${index + 1}.jpg`);
      await downloadFile(screenshot.url, file);
      imagePaths.push(file);
    }
  }

  const promptPath = path.join(eventDir, "codex-prompt.md");
  writeFileSync(promptPath, buildCodexPrompt(event, eventDir, imagePaths), { mode: 0o600 });

  if (process.env.SPOONJOY_TESTFLIGHT_AUTOPILOT_DRY_RUN === "1") {
    appendRuntimeLog(`dry-run queued ${event.instance.id} at ${eventDir}`);
    return;
  }

  const logPath = path.join(eventDir, "codex-exec.jsonl");
  const outputPath = path.join(eventDir, "codex-last-message.md");
  const codexArgs = [
    "exec",
    "-C",
    DEFAULT_REPO,
    "resume",
    "--dangerously-bypass-approvals-and-sandbox",
    "-o",
    outputPath,
  ];
  for (const imagePath of imagePaths) {
    codexArgs.push("-i", imagePath);
  }
  codexArgs.push(DEFAULT_THREAD_ID, "-");

  const child = spawn(DEFAULT_CODEX, codexArgs, {
    cwd: DEFAULT_REPO,
    stdio: ["pipe", "pipe", "pipe"],
    env: {
      ...process.env,
      SPOONJOY_TESTFLIGHT_FEEDBACK_EVENT_DIR: eventDir,
    },
    detached: true,
  });
  child.stdin.end(readFileSync(promptPath));
  const log = createAppendWriter(logPath);
  child.stdout.on("data", (chunk) => log.write(chunk));
  child.stderr.on("data", (chunk) => log.write(chunk));
  child.on("exit", (code, signal) => {
    appendRuntimeLog(`codex event ${event.instance.id} exited code=${code} signal=${signal || ""}`);
    log.end();
  });
  child.unref();
  appendRuntimeLog(`launched codex for ${event.instance.id}; event dir ${eventDir}`);
}

function buildCodexPrompt(event, eventDir, imagePaths) {
  const images = imagePaths.map((file) => `- ${file}`).join("\n") || "- none";
  return `Automated App Store Connect TestFlight feedback webhook event for Spoonjoy.

Feedback instance:
- event type: ${event.type}
- instance type: ${event.instance.type}
- instance id: ${event.instance.id}
- app id: ${APP_ID}
- bundle id: ${APP_BUNDLE_ID}

Telemetry-first rules:
- Treat this as an unhandled bug report.
- Inspect the event files before guessing: ${eventDir}
- Detail JSON: ${path.join(eventDir, "detail.json")}
- Screenshots/crash artifacts:
${images}
- Use the Spoonjoy Apple repo at ${DEFAULT_REPO}; use backend/native repos as needed.
- Do not print secrets, JWTs, private key contents, passwords, signed screenshot URLs, or API key paths.
- If actionable, fix autonomously on a dedicated branch/worktree as needed, add missing telemetry/tests, deploy backend if needed, build/upload/publish an internal TestFlight build only, and verify the build is attached to Spoonjoy Internal.
- Do not submit to the public App Store.
- Only stop early for an unavoidable human-only auth/provider step, and then produce one compact blocker report with all required human actions.
`;
}

async function registerWebhook() {
  ensureRuntime();
  const url = requiredArg("--url");
  const secret = readSecret();
  const eventTypes = ["BETA_FEEDBACK_SCREENSHOT_SUBMISSION_CREATED", "BETA_FEEDBACK_CRASH_SUBMISSION_CREATED"];
  const existing = await ascRequest("GET", `/v1/apps/${APP_ID}/webhooks`);
  const current = (existing.data || []).find((webhook) => webhook?.attributes?.name === "Spoonjoy TestFlight Feedback Autopilot");
  const body = {
    data: {
      type: "webhooks",
      attributes: {
        enabled: true,
        eventTypes,
        name: "Spoonjoy TestFlight Feedback Autopilot",
        secret,
        url,
      },
      relationships: {
        app: {
          data: {
            type: "apps",
            id: APP_ID,
          },
        },
      },
    },
  };

  const result = current
    ? await ascRequest("PATCH", `/v1/webhooks/${current.id}`, { ...body, data: { ...body.data, id: current.id } })
    : await ascRequest("POST", "/v1/webhooks", body);
  const webhookId = result?.data?.id || current?.id;
  writeJson(path.join(SUPPORT_DIR, "registered-webhook.json"), {
    id: webhookId,
    url,
    appId: APP_ID,
    bundleId: APP_BUNDLE_ID,
    eventTypes,
    registeredAt: new Date().toISOString(),
  });
  console.log(JSON.stringify({ ok: true, webhookId, url, eventTypes }, null, 2));
}

async function seedCurrentFeedback() {
  ensureRuntime();
  const state = loadState();
  for (const resource of ["betaFeedbackScreenshotSubmissions", "betaFeedbackCrashSubmissions"]) {
    const result = await ascRequest("GET", `/v1/apps/${APP_ID}/${resource}`, undefined, [["limit", "50"]]);
    for (const item of result.data || []) {
      if (!state.handledInstanceIds.includes(item.id)) state.handledInstanceIds.push(item.id);
    }
  }
  state.seededAt = new Date().toISOString();
  saveState(state);
  console.log(JSON.stringify({
    ok: true,
    handledInstanceIds: state.handledInstanceIds.length,
    launchedEventIds: state.launchedEventIds.length,
  }, null, 2));
}

async function smokeWebhook() {
  ensureRuntime();
  const runAgent = args.includes("--run-agent");
  const secret = readSecret();
  const id = `SMOKE-${randomUUID()}`;
  const payload = {
    data: {
      type: "betaFeedbackScreenshotSubmissionCreated",
      id: randomUUID(),
      version: 1,
      attributes: {
        timestamp: new Date().toISOString(),
      },
      relationships: {
        instance: {
          data: {
            type: "betaFeedbackScreenshotSubmissions",
            id,
          },
          links: {
            self: `https://api.appstoreconnect.apple.com/v1/betaFeedbackScreenshotSubmissions/${id}`,
          },
        },
      },
    },
  };
  const raw = Buffer.from(JSON.stringify(payload));
  const signature = createHmac("sha256", secret).update(raw).digest("base64");
  const response = await fetch(`http://${DEFAULT_HOST}:${DEFAULT_PORT}/app-store-connect/webhook`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-apple-signature": signature,
      "x-spoonjoy-smoke": runAgent ? "run-agent" : "no-agent",
    },
    body: raw,
  });
  const text = await response.text();
  console.log(JSON.stringify({ ok: response.ok, status: response.status, body: safeJson(text) || text }, null, 2));
}

async function pingWebhook() {
  ensureRuntime();
  const webhookId = args.includes("--id")
    ? requiredArg("--id")
    : JSON.parse(readFileSync(path.join(SUPPORT_DIR, "registered-webhook.json"), "utf8")).id;
  const result = await ascRequest("POST", "/v1/webhookPings", {
    data: {
      type: "webhookPings",
      relationships: {
        webhook: {
          data: {
            type: "webhooks",
            id: webhookId,
          },
        },
      },
    },
  });
  console.log(JSON.stringify({
    ok: true,
    webhookId,
    pingId: result?.data?.id,
    state: result?.data?.attributes?.state,
  }, null, 2));
}

async function doctor() {
  ensureRuntime();
  const state = loadState();
  const webhooks = await ascRequest("GET", `/v1/apps/${APP_ID}/webhooks`);
  const status = {
    ok: true,
    listener: `http://${DEFAULT_HOST}:${DEFAULT_PORT}`,
    health: await fetchHealth(),
    appId: APP_ID,
    bundleId: APP_BUNDLE_ID,
    statePath: DEFAULT_STATE_PATH,
    eventDir: DEFAULT_EVENT_DIR,
    handledInstanceIds: state.handledInstanceIds.length,
    launchedEventIds: state.launchedEventIds.length,
    registeredWebhooks: (webhooks.data || []).map((webhook) => ({
      id: webhook.id,
      name: webhook.attributes?.name,
      enabled: webhook.attributes?.enabled,
      eventTypes: webhook.attributes?.eventTypes,
      url: webhook.attributes?.url,
    })),
  };
  console.log(JSON.stringify(status, null, 2));
}

function extractFeedbackEvents(payload) {
  const nodes = Array.isArray(payload?.data) ? payload.data : [payload?.data].filter(Boolean);
  const events = [];
  for (const node of nodes) {
    const type = node.type;
    if (!FEEDBACK_EVENTS.has(type)) continue;
    const instance = node.relationships?.instance?.data || node.relationships?.instance;
    if (!instance?.id || !FEEDBACK_INSTANCE_TYPES.has(instance.type)) continue;
    events.push({
      eventId: node.id || `${type}:${instance.type}:${instance.id}`,
      type,
      timestamp: node.attributes?.timestamp || new Date().toISOString(),
      instance: {
        type: instance.type,
        id: instance.id,
        url: node.relationships?.instance?.links?.self,
      },
    });
  }
  return events;
}

function verifyAppleSignature(raw, header, secret) {
  if (!header) return false;
  const expectedBase64 = createHmac("sha256", secret).update(raw).digest("base64");
  const expectedHex = createHmac("sha256", secret).update(raw).digest("hex");
  const candidates = [header, header.replace(/^sha256=/i, "")].map((value) => value.trim());
  return candidates.some((candidate) => safeEqual(candidate, expectedBase64) || safeEqual(candidate, expectedHex));
}

function safeEqual(a, b) {
  const left = Buffer.from(a);
  const right = Buffer.from(b);
  return left.length === right.length && timingSafeEqual(left, right);
}

async function ascRequest(method, apiPath, body, query = []) {
  const config = JSON.parse(readFileSync(ASC_CONFIG, "utf8"));
  const token = createAscJwt(config);
  const url = new URL(`https://api.appstoreconnect.apple.com${apiPath}`);
  for (const [name, value] of query) url.searchParams.append(name, value);
  const response = await fetch(url, {
    method,
    headers: {
      authorization: `Bearer ${token}`,
      accept: "application/json",
      ...(body ? { "content-type": "application/json" } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await response.text();
  const parsed = safeJson(text);
  if (!response.ok) {
    const message = parsed?.errors?.[0]?.detail || parsed?.errors?.[0]?.title || text || response.statusText;
    throw new Error(`ASC ${method} ${apiPath} failed ${response.status}: ${message}`);
  }
  return parsed || {};
}

function createAscJwt(config) {
  const now = Math.floor(Date.now() / 1000);
  const header = base64Url(JSON.stringify({ alg: "ES256", kid: config.keyId, typ: "JWT" }));
  const payload = base64Url(JSON.stringify({
    iss: config.issuerId,
    iat: now - 30,
    exp: now + 19 * 60,
    aud: "appstoreconnect-v1",
  }));
  const signingInput = `${header}.${payload}`;
  const privateKey = readFileSync(config.privateKeyPath, "utf8");
  const signer = createSign("sha256");
  signer.update(signingInput);
  signer.end();
  const der = signer.sign(privateKey);
  return `${signingInput}.${base64Url(derToJose(der))}`;
}

function derToJose(der) {
  let offset = 0;
  if (der[offset++] !== 0x30) throw new Error("Invalid ES256 DER signature");
  const seqLength = readDerLength(der, offset);
  offset += seqLength.bytes;
  if (der[offset++] !== 0x02) throw new Error("Invalid ES256 DER signature: missing r");
  const rLength = readDerLength(der, offset);
  offset += rLength.bytes;
  const r = der.subarray(offset, offset + rLength.length);
  offset += rLength.length;
  if (der[offset++] !== 0x02) throw new Error("Invalid ES256 DER signature: missing s");
  const sLength = readDerLength(der, offset);
  offset += sLength.bytes;
  const s = der.subarray(offset, offset + sLength.length);
  return Buffer.concat([leftPad(stripLeadingZeroes(r), 32), leftPad(stripLeadingZeroes(s), 32)]);
}

function readDerLength(buffer, offset) {
  const first = buffer[offset];
  if (first < 0x80) return { length: first, bytes: 1 };
  const bytes = first & 0x7f;
  let length = 0;
  for (let index = 0; index < bytes; index += 1) {
    length = (length << 8) | buffer[offset + 1 + index];
  }
  return { length, bytes: bytes + 1 };
}

function stripLeadingZeroes(buffer) {
  let offset = 0;
  while (offset < buffer.length - 1 && buffer[offset] === 0) offset += 1;
  return buffer.subarray(offset);
}

function leftPad(buffer, size) {
  if (buffer.length > size) return buffer.subarray(buffer.length - size);
  if (buffer.length === size) return buffer;
  return Buffer.concat([Buffer.alloc(size - buffer.length), buffer]);
}

function base64Url(value) {
  const buffer = Buffer.isBuffer(value) ? value : Buffer.from(value);
  return buffer.toString("base64").replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

async function downloadFile(url, file) {
  const response = await fetch(url);
  if (!response.ok) throw new Error(`download failed ${response.status}`);
  const bytes = Buffer.from(await response.arrayBuffer());
  writeFileSync(file, bytes, { mode: 0o600 });
}

function readBody(request) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    request.on("data", (chunk) => chunks.push(chunk));
    request.on("end", () => resolve(Buffer.concat(chunks)));
    request.on("error", reject);
  });
}

function ensureRuntime() {
  mkdirSync(SUPPORT_DIR, { recursive: true });
  mkdirSync(DEFAULT_EVENT_DIR, { recursive: true });
  if (!existsSync(DEFAULT_STATE_PATH)) saveState({ handledInstanceIds: [], launchedEventIds: [], createdAt: new Date().toISOString() });
}

function readSecret() {
  if (!existsSync(DEFAULT_SECRET_PATH)) {
    throw new Error(`Missing webhook secret at ${DEFAULT_SECRET_PATH}`);
  }
  return readFileSync(DEFAULT_SECRET_PATH, "utf8").trim();
}

function loadState() {
  return {
    handledInstanceIds: [],
    launchedEventIds: [],
    ...JSON.parse(readFileSync(DEFAULT_STATE_PATH, "utf8")),
  };
}

function saveState(state) {
  mkdirSync(path.dirname(DEFAULT_STATE_PATH), { recursive: true });
  writeJson(DEFAULT_STATE_PATH, state);
  chmodSync(DEFAULT_STATE_PATH, 0o600);
}

function writeJson(file, value) {
  mkdirSync(path.dirname(file), { recursive: true });
  writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`, { mode: 0o600 });
}

function sendJson(response, status, value) {
  response.writeHead(status, { "content-type": "application/json" });
  response.end(`${JSON.stringify(value)}\n`);
}

function safeJson(text) {
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

function createAppendWriter(file) {
  mkdirSync(path.dirname(file), { recursive: true });
  const child = spawn("tee", ["-a", file], { stdio: ["pipe", "ignore", "ignore"] });
  return child.stdin;
}

function appendRuntimeLog(message) {
  const line = `${new Date().toISOString()} ${message}\n`;
  const logFile = path.join(SUPPORT_DIR, "listener.log");
  mkdirSync(path.dirname(logFile), { recursive: true });
  appendFileSync(logFile, line, { mode: 0o600 });
}

function redactForDisk(payload) {
  return JSON.parse(JSON.stringify(payload, (_key, value) => {
    if (typeof value === "string" && value.includes("Signature=")) return "[REDACTED_SIGNED_URL]";
    return value;
  }));
}

function requiredArg(name) {
  const index = args.indexOf(name);
  if (index === -1 || !args[index + 1]) throw new Error(`Missing ${name}`);
  return args[index + 1];
}

async function fetchHealth() {
  try {
    const response = await fetch(`http://${DEFAULT_HOST}:${DEFAULT_PORT}/health`);
    return { ok: response.ok, status: response.status, body: await response.json() };
  } catch (error) {
    return { ok: false, error: error.message };
  }
}
