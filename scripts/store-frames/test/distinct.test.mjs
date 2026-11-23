import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdirSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";
import { encodeOpaque } from "../png.mjs";
import { compareSet, LIMIT } from "../distinct.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));

/** A picture drawn from (x, y) in 0..1, at any size: the same drawing at two sizes is the same picture. */
function draw(width, height, paint) {
  const pixels = Buffer.alloc(width * height * 3);
  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) pixels.set(paint(x / width, y / height), (y * width + x) * 3);
  }
  return encodeOpaque({ width, height, channels: 3, pixels });
}

// A caption band over a phone: the shape every App Store frame shares, so "different" here is a fair test.
const frame = (screen) => (x, y) => (y < 0.25 ? [40, 35, 29] : x > 0.1 && x < 0.9 ? screen(x, y) : [120, 60, 40]);
const stripes = frame((x, y) => (Math.floor(y * 24) % 2 ? [250, 248, 240] : [30, 30, 30]));
const photo = frame((x, y) => [Math.round(255 * x), Math.round(255 * (1 - y)), 120]);

test("the same picture at the inner and the outer Duo size is refused", () => {
  const problems = compareSet([{ name: "01-open.png", bytes: draw(201, 285, stripes) }, { name: "02-open-outer.png", bytes: draw(140, 203, stripes) }]);
  assert.equal(problems.length, 1);
  assert.match(problems[0].why, /the same picture \(distance \d+\.\d, limit 11\)/);
});

test("the same file twice is refused", () => {
  const bytes = draw(60, 130, photo);
  assert.deepEqual(compareSet([{ name: "01-a.png", bytes }, { name: "02-b.png", bytes }]).map((p) => p.why), ["the same file"]);
});

test("different shots in the same frame pass", () => {
  assert.deepEqual(compareSet([{ name: "01-a.png", bytes: draw(132, 287, stripes) }, { name: "02-b.png", bytes: draw(132, 287, photo) }]), []);
  assert.equal(LIMIT, 11);
});

test("the command checks every folder and fails on a repeat", () => {
  const dir = mkdtempSync(join(tmpdir(), "distinct-"));
  mkdirSync(join(dir, "iphone-duo"));
  mkdirSync(join(dir, "iphone-69"));
  writeFileSync(join(dir, "iphone-duo/01-open.png"), draw(201, 285, stripes));
  writeFileSync(join(dir, "iphone-duo/02-again.png"), draw(140, 203, stripes));
  writeFileSync(join(dir, "iphone-69/01-a.png"), draw(132, 287, stripes));
  writeFileSync(join(dir, "iphone-69/02-b.png"), draw(132, 287, photo));
  assert.throws(() => execFileSync(process.execPath, [join(HERE, "../distinct.mjs"), dir], { encoding: "utf8", stdio: "pipe", cwd: dir }),
    (error) => /iphone-duo: 01-open.png and 02-again.png are the same picture/.test(error.stderr) && /iphone-69: 2 screenshots, all different/.test(error.stdout));
});
