#!/usr/bin/env node
// Frames the App Store scenes: each raw scene from Store scenes goes into a device frame on a Spoonjoy palette
// with its caption from distribution/app-store/frames/spec.json, at the App Store's exact pixel size, with no alpha.
// Deterministic: fonts come from the app (Apps/Spoonjoy/Shared/Fonts), nothing loads from the network, the browser
// is the one pinned in package-lock.json, and --check renders everything twice and fails on any byte that differs.
//
//   node scripts/store-frames/render.mjs --scenes DIR --out DIR [--spec PATH] [--sets iphone-69,ipad-13] [--check]
//
// DIR/<set>/<scene>.png in, OUT/<set>/<id>.png out, plus OUT/manifest.json with every frame's SHA-256.
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { parseArgs } from "node:util";
import { decode, encodeOpaque } from "./png.mjs";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const FONTS = join(ROOT, "Apps/Spoonjoy/Shared/Fonts");

/** The spec with each set's shots resolved ("shots": "iphone-69" borrows that set's list). */
export function loadSpec(path) {
  const spec = JSON.parse(typeof path === "string" ? readFileSync(path, "utf8") : path.text);
  for (const [name, set] of Object.entries(spec.sets)) {
    if (typeof set.shots === "string") {
      const from = spec.sets[set.shots];
      if (!from || typeof from.shots === "string") throw new Error(`${name} borrows shots from ${set.shots}, which has none of its own`);
      set.shots = from.shots;
    }
  }
  return spec;
}

/** Every problem with the spec, as sentences. */
export function validateSpec(spec) {
  const errors = [];
  for (const [name, set] of Object.entries(spec.sets)) {
    if (!Array.isArray(set.size) || set.size.length !== 2) errors.push(`${name}: size is [width, height]`);
    if (!["iphone", "ipad"].includes(set.device)) errors.push(`${name}: device is iphone or ipad`);
    if (!set.shots.length || set.shots.length > 10) errors.push(`${name}: a set has 1 to 10 shots`);
    const ids = new Set();
    for (const shot of set.shots) {
      if (!/^\d\d-[a-z0-9-]+$/.test(shot.id)) errors.push(`${name}: shot id ${shot.id} looks like 01-cook`);
      if (ids.has(shot.id)) errors.push(`${name}: shot id ${shot.id} is used twice`);
      ids.add(shot.id);
      if (!spec.palettes[shot.palette]) errors.push(`${name}/${shot.id}: no palette ${shot.palette}`);
      if (!shot.headline) errors.push(`${name}/${shot.id}: no headline`);
      if (!/^[a-z-]+$/.test(shot.scene ?? "")) errors.push(`${name}/${shot.id}: scene names a Store scene`);
    }
  }
  return errors;
}

/** The scenes a set needs, in shot order, each once. */
export function scenesFor(set) {
  return [...new Set(set.shots.map((shot) => shot.scene))];
}

const escape = (text) => String(text).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);

function fontFaces() {
  const face = (family, file, weight, extra = "") =>
    `@font-face{font-family:'${family}';src:url('${pathToFileURL(join(FONTS, file)).href}');font-weight:${weight};${extra}}`;
  return [
    face("Fraunces", "Fraunces[SOFT,WONK,opsz,wght].ttf", "100 900"),
    face("Source Serif 4", "SourceSerif4[opsz,wght].ttf", "200 900"),
    face("IBM Plex Sans Condensed", "IBMPlexSansCondensed-Medium.ttf", 500),
    face("IBM Plex Sans Condensed", "IBMPlexSansCondensed-SemiBold.ttf", 600),
  ].join("\n");
}

/** The frame's HTML. Every length scales with the canvas width, so each export size keeps one composition. */
export function frameHtml(set, shot, palettes, scenePath) {
  const [w, h] = set.size;
  const [top, bottom, ink, soft] = palettes[shot.palette];
  const ipad = set.device === "ipad";
  const u = w / 1320;
  const deviceWidth = w * 0.8;
  const radius = (ipad ? 60 : 120) * u;
  const bezel = 26 * u;
  const head = (ipad ? 118 : 140) * u;
  const headline = escape(shot.headline).replace(/\n/g, "<br>");
  return `<!doctype html><html><head><meta charset="utf-8"><style>
${fontFaces()}
*{-webkit-font-smoothing:antialiased}
html,body{margin:0;width:${w}px;height:${h}px;overflow:hidden;background:${top}}
.canvas{position:relative;width:${w}px;height:${h}px;background:linear-gradient(165deg,${top} 0%,${bottom} 100%);overflow:hidden}
.grain{position:absolute;inset:0;opacity:.07;background-image:radial-gradient(rgba(0,0,0,.6) 1px,transparent 1px);background-size:${6 * u}px ${6 * u}px}
.copy{position:absolute;left:${92 * u}px;right:${92 * u}px;top:${150 * u}px;color:${ink};z-index:3}
.kicker{font:600 ${34 * u}px/1 'IBM Plex Sans Condensed',sans-serif;letter-spacing:.14em;text-transform:uppercase;color:${soft};margin-bottom:${28 * u}px}
h1{margin:0;font-family:'Fraunces',serif;font-variation-settings:'opsz' 144,'SOFT' 30;font-weight:800;font-size:${head}px;line-height:.98;letter-spacing:-.02em}
p{margin:${30 * u}px 0 0;font:500 ${46 * u}px/1.25 'Source Serif 4',serif;color:${soft};max-width:${(ipad ? 1500 : 1050) * u}px}
.device{position:absolute;left:50%;transform:translateX(-50%);top:${h * (ipad ? 0.26 : 0.245)}px;width:${deviceWidth}px;border-radius:${radius}px;background:#0d0c0b;padding:${bezel}px;
  box-shadow:0 ${40 * u}px ${120 * u}px rgba(0,0,0,.38),0 0 0 ${3 * u}px rgba(255,255,255,.08) inset;z-index:2}
.device img{display:block;width:100%;border-radius:${radius - bezel}px}
.island{position:absolute;left:50%;transform:translateX(-50%);top:${bezel + 30 * u}px;width:${300 * u}px;height:${88 * u}px;border-radius:${44 * u}px;background:#000}
</style></head><body><div class="canvas"><div class="grain"></div>
<div class="copy">${shot.kicker ? `<div class="kicker">${escape(shot.kicker)}</div>` : ""}<h1>${headline}</h1>${shot.subline ? `<p>${escape(shot.subline)}</p>` : ""}</div>
<div class="device"><img src="${pathToFileURL(scenePath).href}">${ipad ? "" : '<div class="island"></div>'}</div>
</div></body></html>`;
}

export const sha256 = (buffer) => createHash("sha256").update(buffer).digest("hex");

/** Checks a raw scene is there and was taken on the set's device; returns its path. */
export function scenePath(scenesDir, setName, set, scene) {
  const path = join(scenesDir, setName, `${scene}.png`);
  if (!existsSync(path)) throw new Error(`${setName} has no scene ${scene} (${path}); run Store scenes`);
  const { width, height } = decode(readFileSync(path));
  const [sw, sh] = set.scene_size ?? set.size;
  if (width !== sw || height !== sh) throw new Error(`${path} is ${width}x${height}; ${setName} scenes are ${sw}x${sh}`);
  return path;
}

async function renderAll({ spec, scenes, out, sets }) {
  const { chromium } = await import("playwright");
  // Fixed rendering: no GPU, no LCD text or hinting differences, sRGB.
  const browser = await chromium.launch({
    args: ["--disable-gpu", "--font-render-hinting=none", "--disable-lcd-text", "--force-color-profile=srgb", "--allow-file-access-from-files"],
  });
  const manifest = {};
  try {
    for (const setName of sets) {
      const set = spec.sets[setName];
      const [w, h] = set.size;
      const page = await browser.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: 1 });
      mkdirSync(join(out, setName), { recursive: true });
      for (const shot of set.shots) {
        const html = join(out, setName, `${shot.id}.html`);
        writeFileSync(html, frameHtml(set, shot, spec.palettes, scenePath(scenes, setName, set, shot.scene)));
        await page.goto(pathToFileURL(html).href, { waitUntil: "load" });
        await page.evaluate(async () => {
          await document.fonts.ready;
          await Promise.all([...document.images].map((img) => img.decode()));
        });
        const missing = await page.evaluate(() => ["Fraunces", "Source Serif 4", "IBM Plex Sans Condensed"].filter((f) => !document.fonts.check(`600 20px '${f}'`)));
        if (missing.length) throw new Error(`fonts did not load: ${missing.join(", ")}`);
        const png = encodeOpaque(decode(await page.screenshot({ type: "png", animations: "disabled" })));
        writeFileSync(join(out, setName, `${shot.id}.png`), png);
        manifest[`${setName}/${shot.id}.png`] = sha256(png);
      }
      await page.close();
    }
  } finally {
    await browser.close();
  }
  return manifest;
}

async function main() {
  const { values } = parseArgs({
    options: {
      spec: { type: "string", default: join(ROOT, "distribution/app-store/frames/spec.json") },
      scenes: { type: "string" },
      out: { type: "string" },
      sets: { type: "string" },
      check: { type: "boolean", default: false },
      "validate-only": { type: "boolean", default: false },
    },
  });
  const spec = loadSpec(values.spec);
  const errors = validateSpec(spec);
  if (errors.length) throw new Error(errors.join("\n"));
  if (values["validate-only"]) return console.log(`spec: ${Object.keys(spec.sets).length} sets, fine`);
  if (!values.scenes || !values.out) throw new Error("--scenes DIR and --out DIR are required");
  const sets = values.sets ? values.sets.split(",") : Object.keys(spec.sets);
  const unknown = sets.filter((s) => !spec.sets[s]);
  if (unknown.length) throw new Error(`no set ${unknown.join(", ")} in the spec`);
  const manifest = await renderAll({ spec, scenes: values.scenes, out: values.out, sets });
  if (values.check) {
    const again = await renderAll({ spec, scenes: values.scenes, out: join(values.out, ".again"), sets });
    const differ = Object.keys(manifest).filter((k) => manifest[k] !== again[k]);
    if (differ.length) throw new Error(`the same scenes rendered different pixels: ${differ.join(", ")}`);
    console.log(`check: ${Object.keys(manifest).length} frames rendered twice, byte for byte the same`);
  }
  const scenes = {};
  for (const setName of sets) {
    for (const scene of scenesFor(spec.sets[setName])) scenes[`${setName}/${scene}.png`] = sha256(readFileSync(join(values.scenes, setName, `${scene}.png`)));
  }
  writeFileSync(join(values.out, "manifest.json"), `${JSON.stringify({ scenes, frames: manifest }, null, 2)}\n`);
  for (const [path, hash] of Object.entries(manifest)) console.log(`${hash}  ${path}`);
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    for (const line of String(error.message).split("\n")) console.error(`::error::${line}`);
    process.exit(1);
  });
}
