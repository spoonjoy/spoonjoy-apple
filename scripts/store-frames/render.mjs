#!/usr/bin/env node
// Frames the App Store scenes: each raw scene from Store scenes goes into a device frame on a Spoonjoy palette
// with its caption from distribution/app-store/frames/spec.json, at the App Store's exact pixel size, with no alpha.
// Deterministic: fonts come from the app (Apps/Spoonjoy/Shared/Fonts), nothing loads from the network, the browser
// is the one pinned in package-lock.json, and --check renders everything twice and fails on any byte that differs.
//
//   node scripts/store-frames/render.mjs --scenes DIR --out DIR [--spec PATH] [--sets iphone-69,ipad-13] [--check]
//                                        [--keep-from DIR]
//
// DIR/<set>/<scene>.png in, OUT/<set>/<id>.png out, plus OUT/manifest.json with every frame's SHA-256. A set with
// "scenes_from" reads its scenes from that checked-in folder instead (the iPhone Duo, whose scenes the Duo tour
// photographs in each pose). A set's "keep" files are copied as they are from --keep-from, by default
// distribution/app-store/screenshots beside the spec.
import { createHash } from "node:crypto";
import { copyFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
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

/**
 * The iPhone Duo's poses: which display the Duo tour photographs for each, at what size, and how the frame holds it.
 * Closed is the outer screen; the rest are the inner screen, held sideways, held tall, or half-open on the counter.
 */
export const DUO_POSES = {
  closed: { size: [1398, 2034] },
  "open-wide": { size: [2853, 2007] },
  "open-tall": { size: [2007, 2853] },
  "half-open": { size: [2007, 2853] },
};

/** Every problem with the spec, as sentences. */
export function validateSpec(spec) {
  const errors = [];
  for (const [name, set] of Object.entries(spec.sets)) {
    if (!Array.isArray(set.size) || set.size.length !== 2) errors.push(`${name}: size is [width, height]`);
    if (!["iphone", "ipad", "duo"].includes(set.device)) errors.push(`${name}: device is iphone, ipad or duo`);
    if (set.scenes_from !== undefined && !/^distribution\/app-store\/[a-z0-9/-]+$/.test(set.scenes_from)) errors.push(`${name}: scenes_from is a folder under distribution/app-store`);
    if (set.orientation !== undefined && !["portrait", "landscape"].includes(set.orientation)) errors.push(`${name}: orientation is portrait or landscape`);
    // Every shot in a set shows something different: the iPhone Duo listing once showed two pictures twice each.
    const scenes = set.shots.map((shot) => shot.scene);
    for (const scene of new Set(scenes.filter((scene, i) => scenes.indexOf(scene) !== i))) errors.push(`${name}: scene ${scene} is in two shots; every shot shows something different`);
    const headlines = set.shots.map((shot) => shot.headline);
    for (const headline of new Set(headlines.filter((h, i) => h && headlines.indexOf(h) !== i))) errors.push(`${name}: headline "${headline}" is on two shots`);
    if (!set.shots.length) errors.push(`${name}: a set has at least one shot`);
    const ids = new Set();
    for (const file of set.keep ?? []) {
      if (!/^\d\d-[a-z0-9-]+\.png$/.test(file)) errors.push(`${name}: keep ${file} looks like 05-duo.png`);
      ids.add(file.replace(/\.png$/, ""));
    }
    if ((set.keep ?? []).length + set.shots.length > 10) errors.push(`${name}: the App Store takes at most 10 screenshots`);
    for (const shot of set.shots) {
      if (!/^\d\d-[a-z0-9-]+$/.test(shot.id)) errors.push(`${name}: shot id ${shot.id} looks like 01-cook`);
      if (ids.has(shot.id) || [...ids].some((id) => id.slice(0, 2) === shot.id.slice(0, 2))) errors.push(`${name}: shot id ${shot.id} is used twice, or shares its number`);
      ids.add(shot.id);
      if (!spec.palettes[shot.palette]) errors.push(`${name}/${shot.id}: no palette ${shot.palette}`);
      if (!shot.headline) errors.push(`${name}/${shot.id}: no headline`);
      if (!/^[a-z-]+$/.test(shot.scene ?? "")) errors.push(`${name}/${shot.id}: scene names a Store scene`);
      if (set.device === "duo" && !DUO_POSES[shot.pose]) errors.push(`${name}/${shot.id}: pose is one of ${Object.keys(DUO_POSES).join(", ")}`);
      if (shot.siri !== undefined && !(typeof shot.siri === "string" && shot.siri.includes("Spoonjoy"))) errors.push(`${name}/${shot.id}: siri is a phrase that names Spoonjoy`);
    }
  }
  if (spec.creative) {
    const source = spec.sets[spec.creative.source_set];
    if (!source) errors.push(`creative: source_set ${spec.creative.source_set} is not a set`);
    for (const poster of spec.creative.posters ?? []) {
      const sizes = POSTER_SIZES[poster.id];
      if (!sizes) errors.push(`creative: poster ${poster.id} is header or search`);
      else if (!sizes.some(([sw, sh]) => sw === poster.size?.[0] && sh === poster.size?.[1])) errors.push(`creative/${poster.id}: size is one of ${sizes.map((s) => s.join("x")).join(", ")}`);
      if (!spec.palettes[poster.palette]) errors.push(`creative/${poster.id}: no palette ${poster.palette}`);
      if (poster.id === "header" && poster.headline) errors.push("creative/header: no caption; the App Store sets the app's name over the header");
      if (!poster.scenes?.length || poster.scenes.length > 5) errors.push(`creative/${poster.id}: 1 to 5 scenes`);
      const known = source ? scenesFor(source) : [];
      for (const scene of poster.scenes ?? []) if (!known.includes(scene)) errors.push(`creative/${poster.id}: ${spec.creative.source_set} takes no scene ${scene}`);
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

/**
 * A Siri request over the frame: the phrase someone says, in the words of one of the app's App Shortcuts
 * (Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift), so the caption stays true of the build.
 */
function siriHtml(phrase, u, bottomPx) {
  if (!phrase) return "";
  return `<div class="siri" style="bottom:${bottomPx}px"><div class="orb"></div><div class="said">“${escape(phrase)}”</div></div>`;
}

function siriCss(u) {
  return `.siri{position:absolute;left:50%;transform:translateX(-50%);z-index:5;display:flex;align-items:center;gap:${28 * u}px;padding:${30 * u}px ${48 * u}px ${30 * u}px ${30 * u}px;
  border-radius:${70 * u}px;corner-shape:squircle;background:rgba(24,20,17,.86);color:#FBFAF4;white-space:nowrap;
  box-shadow:0 ${30 * u}px ${90 * u}px rgba(0,0,0,.45),0 0 0 ${3 * u}px rgba(255,255,255,.12) inset;font:600 ${50 * u}px/1.1 'Source Serif 4',serif}
.siri .orb{flex:none;width:${84 * u}px;height:${84 * u}px;border-radius:50%;background:conic-gradient(from 200deg,#ff6a3d,#ff3d8b,#8b5cff,#3db7ff,#46e3b0,#ffb13d,#ff6a3d);
  box-shadow:0 0 ${40 * u}px rgba(255,120,180,.55)}`;
}

/** The frame's HTML. Every length scales with the canvas width, so each export size keeps one composition. */
export function frameHtml(set, shot, palettes, scenePath) {
  if (set.device === "duo") return duoFrameHtml(set, shot, palettes, scenePath);
  const [w, h] = set.size;
  if (set.device === "ipad" && w > h) return landscapeFrameHtml(set, shot, palettes, scenePath);
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
${siriCss(u)}
${stackCss(u, { copyTop: 150 * u, left: 92 * u, deviceTop: h * (ipad ? 0.26 : 0.245), gap: 56 * u })}
</style></head><body><div class="canvas"><div class="grain"></div>
<div class="stack"><div class="copy">${copyHtml(shot)}</div>
<div class="device"><img src="${pathToFileURL(scenePath).href}">${ipad ? "" : '<div class="island"></div>'}</div></div>
${siriHtml(shot.siri, u, h * 0.06)}
</div></body></html>`;
}

/**
 * The caption and the device in one column: the device starts a gap below the caption however many lines it takes,
 * and never higher than `deviceTop` from the top of the canvas, so a short caption keeps the usual composition.
 */
function stackCss(u, { copyTop, left, deviceTop, gap }) {
  return `.stack{position:absolute;left:0;right:0;top:${copyTop}px;display:flex;flex-direction:column;align-items:center}
.stack .copy{position:relative;left:auto;right:auto;top:auto;align-self:stretch;margin:0 ${left}px;width:auto;min-height:${deviceTop - copyTop - gap}px}
.stack > .device{position:relative;left:auto;top:auto;transform:none;margin-top:${gap}px;flex:none}`;
}

function copyHtml(shot) {
  const headline = escape(shot.headline).replace(/\n/g, "<br>");
  return `${shot.kicker ? `<div class="kicker">${escape(shot.kicker)}</div>` : ""}<h1>${headline}</h1>${shot.subline ? `<p>${escape(shot.subline)}</p>` : ""}`;
}

function baseCss(w, h, u, palette, { head, sub, left, top: copyTop, width }) {
  const [top, bottom, ink, soft] = palette;
  return `${fontFaces()}
*{-webkit-font-smoothing:antialiased}
html,body{margin:0;width:${w}px;height:${h}px;overflow:hidden;background:${top}}
.canvas{position:relative;width:${w}px;height:${h}px;background:linear-gradient(165deg,${top} 0%,${bottom} 100%);overflow:hidden}
.grain{position:absolute;inset:0;opacity:.07;background-image:radial-gradient(rgba(0,0,0,.6) 1px,transparent 1px);background-size:${6 * u}px ${6 * u}px}
.copy{position:absolute;left:${left}px;top:${copyTop}px;width:${width}px;color:${ink};z-index:6}
.kicker{font:600 ${34 * u}px/1 'IBM Plex Sans Condensed',sans-serif;letter-spacing:.14em;text-transform:uppercase;color:${soft};margin-bottom:${28 * u}px}
h1{margin:0;font-family:'Fraunces',serif;font-variation-settings:'opsz' 144,'SOFT' 30;font-weight:800;font-size:${head}px;line-height:.98;letter-spacing:-.02em}
p{margin:${30 * u}px 0 0;font:500 ${sub}px/1.25 'Source Serif 4',serif;color:${soft}}
${siriCss(u)}`;
}

/** The iPad held sideways: the caption across the top, the iPad below it, running off the bottom edge. */
function landscapeFrameHtml(set, shot, palettes, scenePath) {
  const [w, h] = set.size;
  const u = h / 1450;
  const deviceWidth = w * 0.76;
  const bezel = 24 * u;
  const radius = 64 * u;
  return `<!doctype html><html><head><meta charset="utf-8"><style>
${baseCss(w, h, u, palettes[shot.palette], { head: 128 * u, sub: 46 * u, left: 150 * u, top: 120 * u, width: w - 300 * u })}
.device{position:absolute;left:50%;transform:translateX(-50%);top:${h * 0.34}px;width:${deviceWidth}px;border-radius:${radius}px;background:#0d0c0b;padding:${bezel}px;
  box-shadow:0 ${40 * u}px ${120 * u}px rgba(0,0,0,.38),0 0 0 ${3 * u}px rgba(255,255,255,.08) inset;z-index:2}
.device img{display:block;width:100%;border-radius:${radius - bezel}px}
${stackCss(u, { copyTop: 120 * u, left: 150 * u, deviceTop: h * 0.34, gap: 60 * u })}
</style></head><body><div class="canvas"><div class="grain"></div>
<div class="stack"><div class="copy">${copyHtml(shot)}</div>
<div class="device"><img src="${pathToFileURL(scenePath).href}"></div></div>
${siriHtml(shot.siri, u, h * 0.06)}
</div></body></html>`;
}

/**
 * The iPhone Duo in one of its poses (DUO_POSES), on the inner screen's canvas. Closed, it is a phone showing the
 * outer screen; open wide, a landscape spread with the hinge down the middle; open tall, a tall page with the hinge
 * across it; half-open, the top half stands up and the bottom half lies on the counter.
 */
const DUO_STAGE = 0.27;

function duoFrameHtml(set, shot, palettes, scenePath) {
  const [w, h] = set.size;
  const u = w / 1320;
  const src = pathToFileURL(scenePath).href;
  const bezel = 20 * u;
  const radius = 70 * u;
  const copyTop = 150 * u;
  let device;
  let css;
  if (shot.pose === "closed") {
    const dw = w * 0.62;
    css = `.device{left:${(w - dw) / 2}px;top:${h * (0.29 - DUO_STAGE)}px;width:${dw}px;padding:${bezel}px;border-radius:${radius}px}`;
    device = `<div class="device"><img src="${src}" style="border-radius:${radius - bezel}px"><div class="island" style="top:${bezel + 26 * u}px;width:${200 * u}px;height:${60 * u}px"></div></div>`;
  } else if (shot.pose === "open-wide") {
    const dw = w * 0.94;
    const dh = (dw - 2 * bezel) * (2007 / 2853) + 2 * bezel;
    const top = Math.max(h * 0.36, (h * 0.33 + h - dh) / 2 - h * 0.04) - h * DUO_STAGE;
    css = `.device{left:${(w - dw) / 2}px;top:${top}px;width:${dw}px;padding:${bezel}px;border-radius:${radius}px;transform:rotate(-3deg)}
.hinge{position:absolute;top:${bezel}px;bottom:${bezel}px;left:50%;width:${16 * u}px;transform:translateX(-50%);
  background:linear-gradient(90deg,rgba(0,0,0,0),rgba(0,0,0,.16) 45%,rgba(255,255,255,.12) 55%,rgba(0,0,0,0))}`;
    device = `<div class="device"><img src="${src}" style="border-radius:${radius - bezel}px"><div class="hinge"></div></div>`;
  } else if (shot.pose === "open-tall") {
    const dw = w * 0.8;
    css = `.device{left:${(w - dw) / 2}px;top:${h * (0.3 - DUO_STAGE)}px;width:${dw}px;padding:${bezel}px;border-radius:${radius}px}
.hinge{position:absolute;left:${bezel}px;right:${bezel}px;top:50%;height:${16 * u}px;transform:translateY(-50%);
  background:linear-gradient(180deg,rgba(0,0,0,0),rgba(0,0,0,.14) 45%,rgba(255,255,255,.12) 55%,rgba(0,0,0,0))}`;
    device = `<div class="device"><img src="${src}" style="border-radius:${radius - bezel}px"><div class="hinge"></div></div>`;
  } else {
    // Half-open on the counter: the top half of the inner screen stands, the bottom half tilts back in perspective.
    const dw = w * 0.74;
    const half = ((dw - 2 * bezel) * (2853 / 2007)) / 2;
    const top = h * (0.31 - DUO_STAGE);
    css = `.stand{position:absolute;left:${(w - dw) / 2}px;top:${top}px;width:${dw}px}
.half{background:#0d0c0b;box-sizing:border-box;width:${dw}px}
.upright{height:${half + bezel}px;padding:${bezel}px ${bezel}px 0;border-radius:${radius}px ${radius}px 0 0;position:relative;z-index:2}
.flat{height:${half + bezel}px;padding:0 ${bezel}px ${bezel}px;border-radius:0 0 ${radius}px ${radius}px;transform-origin:top center;transform:perspective(${dw * 2.2}px) rotateX(52deg)}
.screen{width:100%;height:100%;background-image:url("${src}");background-size:100% 200%}
.upright .screen{background-position:top;border-radius:${radius - bezel}px ${radius - bezel}px 0 0}
.flat .screen{background-position:bottom;border-radius:0 0 ${radius - bezel}px ${radius - bezel}px}
.counter{position:absolute;left:${(w - dw * 1.2) / 2}px;width:${dw * 1.2}px;top:${top + half * 1.55}px;height:${half * 0.5}px;border-radius:50%;
  background:radial-gradient(closest-side,rgba(0,0,0,.42),rgba(0,0,0,0));z-index:0}`;
    device = `<div class="counter"></div><div class="stand"><div class="half upright"><div class="screen"></div></div><div class="half flat"><div class="screen"></div></div></div>`;
  }
  return `<!doctype html><html><head><meta charset="utf-8"><style>
${baseCss(w, h, u, palettes[shot.palette], { head: 140 * u, sub: 46 * u, left: 92 * u, top: copyTop, width: w - 184 * u })}
.device{position:absolute;background:#0d0c0b;box-shadow:0 ${40 * u}px ${120 * u}px rgba(0,0,0,.38),0 0 0 ${3 * u}px rgba(255,255,255,.08) inset;z-index:2;box-sizing:content-box}
.device img{display:block;width:100%}
.island{position:absolute;left:50%;transform:translateX(-50%);border-radius:${30 * u}px;background:#000}
${css}
${stackCss(u, { copyTop, left: 92 * u, deviceTop: h * DUO_STAGE, gap: 56 * u })}
.stage{position:relative;align-self:stretch;height:${h}px;margin-top:${56 * u}px;flex:none}
</style></head><body><div class="canvas"><div class="grain"></div>
<div class="stack"><div class="copy">${copyHtml(shot)}</div>
<div class="stage">${device}</div></div>
${siriHtml(shot.siri, u, h * 0.05)}
</div></body></html>`;
}

// Apple's sizes for the iOS 27 product page header and search results art (GET /v1/appAssetLibraryRefData).
export const POSTER_SIZES = {
  header: [[5244, 2950], [3840, 1646]],
  search: [[5244, 2950], [3840, 2560], [3000, 2000], [1920, 1280]],
};

/**
 * A wide poster: the palette, an optional caption on the left, and the scenes as phones fanned across the right.
 * The header carries no caption, because the App Store sets the app's name and icon over it.
 */
export function posterHtml(poster, palettes, scenePaths) {
  const [w, h] = poster.size;
  const [top, bottom, ink, soft] = palettes[poster.palette];
  const u = h / 1646;
  const caption = Boolean(poster.headline);
  // The phones share the space the caption leaves: the right 56% beside a caption, the middle 70% without one.
  const [from, to] = caption ? [0.42 * w, 0.98 * w] : [0.15 * w, 0.85 * w];
  const n = scenePaths.length;
  const phoneW = Math.min(560 * u, (to - from) / (n * 0.92 + 0.3), (h * 0.8) / 2.2);
  const radius = phoneW * 0.15;
  const bezel = phoneW * 0.032;
  const phoneH = phoneW * 2.17 + 2 * bezel;
  const phones = scenePaths.map((path, i) => {
    const offset = i - (n - 1) / 2;
    const x = (from + to) / 2 + offset * phoneW * 0.92 - phoneW / 2;
    const y = (h - phoneH) / 2 + Math.abs(offset) * phoneW * 0.16;
    const tilt = offset * 4;
    return `<div class="phone" style="left:${x}px;top:${y}px;transform:rotate(${tilt}deg);z-index:${10 - Math.abs(offset) * 2}"><img src="${pathToFileURL(path).href}"><div class="island"></div></div>`;
  });
  const headline = caption ? escape(poster.headline).replace(/\n/g, "<br>") : "";
  return `<!doctype html><html><head><meta charset="utf-8"><style>
${fontFaces()}
*{-webkit-font-smoothing:antialiased}
html,body{margin:0;width:${w}px;height:${h}px;overflow:hidden;background:${top}}
.canvas{position:relative;width:${w}px;height:${h}px;background:radial-gradient(120% 140% at 70% 30%,${top} 0%,${bottom} 100%);overflow:hidden}
.grain{position:absolute;inset:0;opacity:.07;background-image:radial-gradient(rgba(0,0,0,.6) 1px,transparent 1px);background-size:${6 * u}px ${6 * u}px}
.copy{position:absolute;left:${180 * u}px;top:50%;transform:translateY(-50%);width:${w * 0.36}px;color:${ink};z-index:20}
.kicker{font:600 ${44 * u}px/1 'IBM Plex Sans Condensed',sans-serif;letter-spacing:.14em;text-transform:uppercase;color:${soft};margin-bottom:${36 * u}px}
h1{margin:0;font-family:'Fraunces',serif;font-variation-settings:'opsz' 144,'SOFT' 30;font-weight:800;font-size:${150 * u}px;line-height:.98;letter-spacing:-.02em}
p{margin:${40 * u}px 0 0;font:500 ${58 * u}px/1.25 'Source Serif 4',serif;color:${soft}}
.phone{position:absolute;width:${phoneW}px;border-radius:${radius}px;background:#0d0c0b;padding:${bezel}px;box-shadow:0 ${50 * u}px ${140 * u}px rgba(0,0,0,.45),0 0 0 ${3 * u}px rgba(255,255,255,.08) inset}
.phone img{display:block;width:100%;border-radius:${radius - bezel}px}
.island{position:absolute;left:50%;transform:translateX(-50%);top:${bezel + phoneW * 0.04}px;width:${phoneW * 0.23}px;height:${phoneW * 0.068}px;border-radius:${phoneW * 0.034}px;background:#000}
</style></head><body><div class="canvas"><div class="grain"></div>
${caption ? `<div class="copy">${poster.kicker ? `<div class="kicker">${escape(poster.kicker)}</div>` : ""}<h1>${headline}</h1>${poster.subline ? `<p>${escape(poster.subline)}</p>` : ""}</div>` : ""}
${phones.join("\n")}
</div></body></html>`;
}

export const sha256 = (buffer) => createHash("sha256").update(buffer).digest("hex");

/** Where a set's raw scene is: the Store scenes folder, or the set's own checked-in folder. */
export function sceneFile(scenesDir, setName, set, scene) {
  return set.scenes_from ? join(ROOT, set.scenes_from, `${scene}.png`) : join(scenesDir, setName, `${scene}.png`);
}

/** Checks a raw scene is there and was taken on the set's device (or in the shot's Duo pose); returns its path. */
export function scenePath(scenesDir, setName, set, scene, shot) {
  const path = sceneFile(scenesDir, setName, set, scene);
  if (!existsSync(path)) throw new Error(`${setName} has no scene ${scene} (${path}); run Store scenes`);
  const { width, height } = decode(readFileSync(path));
  const [sw, sh] = set.device === "duo" && shot ? DUO_POSES[shot.pose].size : set.scene_size ?? set.size;
  if (width !== sw || height !== sh) throw new Error(`${path} is ${width}x${height}; ${setName} scenes are ${sw}x${sh}`);
  return path;
}

/** Loads the page, waits for its fonts and images, and writes it as an opaque PNG; returns the PNG's SHA-256. */
async function shoot(page, html, png) {
  await page.goto(pathToFileURL(html).href, { waitUntil: "load" });
  await page.evaluate(async () => {
    // Load every face even where a page sets no text in it, so a missing font file fails here, not as a fallback.
    await Promise.all(["Fraunces", "Source Serif 4", "IBM Plex Sans Condensed"].map((f) => document.fonts.load(`600 20px '${f}'`)));
    await document.fonts.ready;
    await Promise.all([...document.images].map((img) => img.decode()));
  });
  const missing = await page.evaluate(() => ["Fraunces", "Source Serif 4", "IBM Plex Sans Condensed"].filter((f) => !document.fonts.check(`600 20px '${f}'`)));
  if (missing.length) throw new Error(`fonts did not load: ${missing.join(", ")}`);
  const bytes = encodeOpaque(decode(await page.screenshot({ type: "png", animations: "disabled" })));
  writeFileSync(png, bytes);
  return sha256(bytes);
}

async function renderAll({ spec, scenes, out, sets, keepFrom }) {
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
        writeFileSync(html, frameHtml(set, shot, spec.palettes, scenePath(scenes, setName, set, shot.scene, shot)));
        manifest[`${setName}/${shot.id}.png`] = await shoot(page, html, join(out, setName, `${shot.id}.png`));
      }
      await page.close();
      for (const file of set.keep ?? []) {
        const from = join(keepFrom, setName, file);
        if (!existsSync(from)) throw new Error(`${setName} keeps ${file}, but ${from} is missing`);
        copyFileSync(from, join(out, setName, file));
        manifest[`${setName}/${file}`] = sha256(readFileSync(from));
      }
    }
    const creative = spec.creative;
    if (creative && sets.includes(creative.source_set)) {
      const source = spec.sets[creative.source_set];
      mkdirSync(join(out, "creative"), { recursive: true });
      for (const poster of creative.posters) {
        const [w, h] = poster.size;
        const page = await browser.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: 1 });
        const html = join(out, "creative", `${poster.id}.html`);
        const paths = poster.scenes.map((scene) => scenePath(scenes, creative.source_set, source, scene));
        writeFileSync(html, posterHtml(poster, spec.palettes, paths));
        manifest[`creative/${poster.id}.png`] = await shoot(page, html, join(out, "creative", `${poster.id}.png`));
        await page.close();
      }
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
      "keep-from": { type: "string" },
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
  const keepFrom = values["keep-from"] ?? join(dirname(values.spec), "../screenshots");
  const manifest = await renderAll({ spec, scenes: values.scenes, out: values.out, sets, keepFrom });
  if (values.check) {
    const again = await renderAll({ spec, scenes: values.scenes, out: join(values.out, ".again"), sets, keepFrom });
    const differ = Object.keys(manifest).filter((k) => manifest[k] !== again[k]);
    if (differ.length) throw new Error(`the same scenes rendered different pixels: ${differ.join(", ")}`);
    console.log(`check: ${Object.keys(manifest).length} frames rendered twice, byte for byte the same`);
  }
  const scenes = {};
  for (const setName of sets) {
    const set = spec.sets[setName];
    for (const scene of scenesFor(set)) scenes[`${setName}/${scene}.png`] = sha256(readFileSync(sceneFile(values.scenes, setName, set, scene)));
  }
  writeFileSync(join(values.out, "manifest.json"), `${JSON.stringify({ scenes, frames: manifest }, null, 2)}\n`);
  for (const [path, hash] of Object.entries(manifest)) console.log(`${hash}  ${path}`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    for (const line of String(error.message).split("\n")) console.error(`::error::${line}`);
    process.exit(1);
  });
}
