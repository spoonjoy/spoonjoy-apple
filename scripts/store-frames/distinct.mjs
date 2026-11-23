#!/usr/bin/env node
// Every App Store screenshot set must show different pictures. The iPhone Duo listing once carried the same two
// pictures twice, once at the inner screen's size and once at the outer screen's, because App Store Connect keeps
// both sizes in one set. This check catches that and any other repeat: within one folder, no two screenshots may be
// the same file, or the same picture at another size, or so alike that a person would take them for the same shot.
//
//   node scripts/store-frames/distinct.mjs DIR [DIR...]   checks every folder of PNGs under each DIR (and DIR itself)
//
// Two pictures are compared as 48x48 greyscale thumbnails, so size and aspect make no difference: the distance is
// the mean absolute difference of their pixels, 0 to 255. On the listing of November 2026, the Duo's repeated
// pictures (each laid out again for the outer screen's size) scored 5.9 and 8.4, and the closest pair of different
// shots in any set scored 15.5, so the limit sits between them.
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { createHash } from "node:crypto";
import { pathToFileURL } from "node:url";
import { decode } from "./png.mjs";

export const SIDE = 48;
/** Below this distance two screenshots count as the same picture. */
export const LIMIT = 11;

/** A SIDE x SIDE greyscale thumbnail of a decoded PNG, each cell the mean of the pixels it covers. */
export function thumbnail({ width, height, channels, pixels }) {
  const sums = new Float64Array(SIDE * SIDE);
  const counts = new Float64Array(SIDE * SIDE);
  // Every pixel would be exact but slow on 6-megapixel art; a stride of a few pixels changes nothing at this size.
  const step = Math.max(1, Math.floor(Math.min(width, height) / (SIDE * 8)));
  for (let y = 0; y < height; y += step) {
    const row = Math.min(SIDE - 1, Math.floor((y * SIDE) / height));
    for (let x = 0; x < width; x += step) {
      const i = (y * width + x) * channels;
      const cell = row * SIDE + Math.min(SIDE - 1, Math.floor((x * SIDE) / width));
      sums[cell] += 0.299 * pixels[i] + 0.587 * pixels[i + 1] + 0.114 * pixels[i + 2];
      counts[cell] += 1;
    }
  }
  return Float64Array.from(sums, (sum, cell) => sum / counts[cell]);
}

/** Mean absolute difference of two thumbnails, 0 (the same) to 255. */
export function distance(a, b) {
  let total = 0;
  for (let i = 0; i < a.length; i += 1) total += Math.abs(a[i] - b[i]);
  return total / a.length;
}

/** Problems with one folder's screenshots: [{ a, b, why }]. `files` are { name, bytes }. */
export function compareSet(files) {
  const seen = files.map(({ name, bytes }) => ({ name, sha: createHash("sha256").update(bytes).digest("hex"), thumb: thumbnail(decode(bytes)) }));
  const problems = [];
  for (let i = 0; i < seen.length; i += 1) {
    for (let j = i + 1; j < seen.length; j += 1) {
      const [a, b] = [seen[i], seen[j]];
      if (a.sha === b.sha) problems.push({ a: a.name, b: b.name, why: "the same file" });
      else {
        const d = distance(a.thumb, b.thumb);
        if (d < LIMIT) problems.push({ a: a.name, b: b.name, why: `the same picture (distance ${d.toFixed(1)}, limit ${LIMIT})` });
      }
    }
  }
  return problems;
}

/** Every folder under dir (dir included) that holds PNGs, as { folder, files: [{ name, bytes }] }. */
export function pngFolders(dir) {
  const out = [];
  const walk = (folder) => {
    const entries = readdirSync(folder).sort();
    const pngs = entries.filter((name) => name.endsWith(".png"));
    if (pngs.length) out.push({ folder, files: pngs.map((name) => ({ name, bytes: readFileSync(join(folder, name)) })) });
    for (const name of entries) {
      if (!name.startsWith(".") && statSync(join(folder, name)).isDirectory()) walk(join(folder, name));
    }
  };
  walk(dir);
  return out;
}

function main() {
  const dirs = process.argv.slice(2);
  if (!dirs.length) throw new Error("usage: distinct.mjs DIR [DIR...]");
  let failed = 0;
  for (const dir of dirs) {
    for (const { folder, files } of pngFolders(dir)) {
      const problems = compareSet(files);
      const name = relative(process.cwd(), folder) || folder;
      for (const { a, b, why } of problems) console.error(`::error::${name}: ${a} and ${b} are ${why}; every screenshot in a set must show something different`);
      if (!problems.length) console.log(`${name}: ${files.length} screenshots, all different`);
      failed += problems.length;
    }
  }
  if (failed) process.exit(1);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    main();
  } catch (error) {
    console.error(`::error::${error.message}`);
    process.exit(1);
  }
}
