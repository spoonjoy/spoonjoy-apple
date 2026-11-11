import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { test } from "node:test";
import * as zlib from "node:zlib";
import { fileURLToPath } from "node:url";
import { decode, encodeOpaque } from "../png.mjs";
import { frameHtml, loadSpec, posterHtml, scenesFor, sha256, validateSpec } from "../render.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(HERE, "../../..");
const SPEC = join(ROOT, "distribution/app-store/frames/spec.json");

function solid(width, height, rgba) {
  const pixels = Buffer.alloc(width * height * 4);
  for (let i = 0; i < width * height; i += 1) pixels.set(rgba, i * 4);
  return { width, height, channels: 4, pixels };
}

test("an opaque RGBA image comes back as RGB with the same pixels", () => {
  const png = encodeOpaque(solid(5, 3, [162, 74, 56, 255]));
  const back = decode(png);
  assert.deepEqual([back.width, back.height, back.channels], [5, 3, 3]);
  assert.deepEqual([...back.pixels.subarray(0, 3)], [162, 74, 56]);
  assert.equal(png[25], 2, "colour type 2 is RGB, no alpha");
  assert.equal(sha256(png), sha256(encodeOpaque(decode(png))), "re-encoding is stable");
});

test("a pixel that is not opaque fails instead of being flattened", () => {
  assert.throws(() => encodeOpaque(solid(2, 2, [0, 0, 0, 128])), /not opaque/);
});

test("the checked-in spec is valid and matches the App Store sizes in listing.json", () => {
  const spec = loadSpec(SPEC);
  assert.deepEqual(validateSpec(spec), []);
  const listing = JSON.parse(readFileSync(join(ROOT, "distribution/app-store/listing.json"), "utf8"));
  for (const [name, set] of Object.entries(spec.sets)) {
    const sizes = listing.screenshots[name]?.sizes ?? [];
    assert.ok(sizes.some(([w, h]) => w === set.size[0] && h === set.size[1]), `${name} ${set.size} is an App Store size`);
    assert.ok(set.shots.slice(0, 3).every((shot) => !shot.scene.endsWith("-dark")), `${name} leads with light scenes`);
  }
  assert.ok(scenesFor(spec.sets["iphone-69"]).includes("cook-mode-dark"), "one Dark Mode shot");
  assert.equal(spec.sets["iphone-61"].shots, spec.sets["iphone-69"].shots);
});

test("the spec refuses bad shots", () => {
  const spec = { palettes: { a: ["#000", "#000", "#fff", "#eee"] },
    sets: { x: { size: [1, 2], device: "watch", shots: [{ id: "cook", scene: "Cook", palette: "b" }, { id: "cook", scene: "x", palette: "a", headline: "h" }] } } };
  spec.sets.y = { size: [1, 2], device: "iphone", keep: ["05-duo.png", "duo.png"], shots: [{ id: "05-cook", scene: "x", palette: "a", headline: "h" }] };
  const errors = validateSpec(spec).join("\n");
  assert.match(errors, /keep duo.png looks like 05-duo.png/);
  assert.match(errors, /y: shot id 05-cook is used twice, or shares its number/);
  for (const what of ["device is iphone or ipad", "looks like 01-cook", "used twice", "no palette b", "no headline", "names a Store scene"]) {
    assert.match(errors, new RegExp(what));
  }
});

test("captions are escaped and loaded from the app's own fonts", () => {
  const spec = loadSpec(SPEC);
  const html = frameHtml(spec.sets["iphone-69"], { headline: "A <b>\nB", subline: "x & y", palette: "tomato" }, spec.palettes, "/tmp/s.png");
  assert.match(html, /A &lt;b&gt;<br>B/);
  assert.match(html, /x &amp; y/);
  assert.match(html, /Apps\/Spoonjoy\/Shared\/Fonts\/Fraunces/);
  assert.doesNotMatch(html, /https?:\/\//, "nothing loads from the network");
});

test("rendering the same scenes twice gives the same bytes, at the exact size, without alpha", { timeout: 120000 }, () => {
  const dir = mkdtempSync(join(tmpdir(), "store-frames-"));
  const spec = {
    palettes: { tomato: ["#A24A38", "#7E3628", "#FBFAF4", "#F3D9CF"] },
    sets: { tiny: { size: [264, 574], scene_size: [60, 130], device: "iphone",
      shots: [{ id: "01-cook", scene: "cook-mode", palette: "tomato", kicker: "Cook mode", headline: "One big step\nat a time", subline: "Say next." }] } },
  };
  writeFileSync(join(dir, "spec.json"), JSON.stringify(spec));
  mkdirSync(join(dir, "scenes/tiny"), { recursive: true });
  writeFileSync(join(dir, "scenes/tiny/cook-mode.png"), encodeOpaque(solid(60, 130, [251, 250, 244, 255])));
  const out = execFileSync(process.execPath, [join(HERE, "../render.mjs"), "--spec", join(dir, "spec.json"), "--scenes", join(dir, "scenes"), "--out", join(dir, "out"), "--check"], { encoding: "utf8" });
  assert.match(out, /rendered twice, byte for byte the same/);
  const frame = decode(readFileSync(join(dir, "out/tiny/01-cook.png")));
  assert.deepEqual([frame.width, frame.height, frame.channels], [264, 574, 3]);
  const manifest = JSON.parse(readFileSync(join(dir, "out/manifest.json"), "utf8"));
  assert.equal(manifest.frames["tiny/01-cook.png"], sha256(readFileSync(join(dir, "out/tiny/01-cook.png"))));
  assert.ok(manifest.scenes["tiny/cook-mode.png"]);
});

test("a scene taken on the wrong device is refused", { timeout: 60000 }, () => {
  const dir = mkdtempSync(join(tmpdir(), "store-frames-"));
  mkdirSync(join(dir, "scenes/iphone-69"), { recursive: true });
  writeFileSync(join(dir, "scenes/iphone-69/cook-mode.png"), encodeOpaque(solid(10, 10, [0, 0, 0, 255])));
  assert.throws(() => execFileSync(process.execPath, [join(HERE, "../render.mjs"), "--scenes", join(dir, "scenes"), "--out", join(dir, "out"), "--sets", "iphone-69"], { encoding: "utf8", stdio: "pipe" }),
    (error) => /is 10x10; iphone-69 scenes are 1320x2868/.test(error.stderr));
});

test("the header and search art use Apple's sizes and scenes the source set takes", () => {
  const spec = loadSpec(SPEC);
  assert.deepEqual(spec.creative.posters.map((p) => p.id), ["header", "search"]);
  const broken = structuredClone(spec);
  broken.creative.posters[0].size = [4000, 2000];
  broken.creative.posters[0].headline = "Hi";
  broken.creative.posters[1].scenes = ["cook-mode", "settings"];
  const errors = validateSpec(broken).join("\n");
  assert.match(errors, /creative\/header: size is one of 5244x2950, 3840x1646/);
  assert.match(errors, /creative\/header: no caption/);
  assert.match(errors, /iphone-69 takes no scene settings/);
});

test("a poster without a caption puts the phones in the middle; with one, beside it", () => {
  const spec = loadSpec(SPEC);
  const [header, search] = spec.creative.posters;
  const bare = posterHtml(header, spec.palettes, ["/a.png", "/b.png", "/c.png"]);
  assert.doesNotMatch(bare, /<h1>/);
  assert.equal((bare.match(/class="phone"/g) ?? []).length, 3);
  const captioned = posterHtml(search, spec.palettes, ["/a.png"]);
  assert.match(captioned, /<h1>Recipes, passed<br>hand to hand<\/h1>/);
  const left = Number(captioned.match(/class="phone" style="left:([\d.]+)px/)[1]);
  assert.ok(left > search.size[0] * 0.42, "the phone stays right of the caption");
});

test("the scene key changes with the screens, not with captions or version numbers", async () => {
  const { sceneKey } = await import("../scene-key.mjs");
  const repo = mkdtempSync(join(tmpdir(), "scene-key-"));
  const git = (...args) => execFileSync("git", ["-C", repo, ...args], { encoding: "utf8" });
  const write = (path, text) => {
    mkdirSync(dirname(join(repo, path)), { recursive: true });
    writeFileSync(join(repo, path), text);
  };
  const commit = () => {
    git("add", "-A");
    git("-c", "user.name=t", "-c", "user.email=t@example.com", "commit", "-qm", "c", "--allow-empty");
    return sceneKey("HEAD", repo);
  };
  git("init", "-q");
  write("distribution/app-store/frames/spec.json", readFileSync(SPEC, "utf8"));
  write("Spoonjoy.xcodeproj/project.pbxproj", "\t\t\t\tMARKETING_VERSION = 1.2;\n\t\t\t\tCURRENT_PROJECT_VERSION = 32;\n\t\t\t\tSWIFT_VERSION = 6.0;\n");
  write("Apps/Spoonjoy/Shared/View.swift", "struct A {}\n");
  const first = commit();
  assert.match(first, /^store-scenes-[0-9a-f]{20}$/);
  write("distribution/app-store/frames/spec.json", readFileSync(SPEC, "utf8").replace("One big step", "One huge step"));
  write("Spoonjoy.xcodeproj/project.pbxproj", "\t\t\t\tMARKETING_VERSION = 1.3;\n\t\t\t\tCURRENT_PROJECT_VERSION = 40;\n\t\t\t\tSWIFT_VERSION = 6.0;\n");
  assert.equal(commit(), first, "captions and version bumps keep the key");
  write("Apps/Spoonjoy/Shared/View.swift", "struct B {}\n");
  const screens = commit();
  assert.notEqual(screens, first, "a screen change makes a new key");
  write("Spoonjoy.xcodeproj/project.pbxproj", "\t\t\t\tMARKETING_VERSION = 1.3;\n\t\t\t\tCURRENT_PROJECT_VERSION = 40;\n\t\t\t\tSWIFT_VERSION = 6.1;\n");
  assert.notEqual(commit(), screens, "a build setting change makes a new key");
  write(".github/workflows/store-scenes.yml", "status bar 10:41\n");
  assert.notEqual(commit(), screens, "a change to how scenes are taken makes a new key");
});

test("a truncated PNG fails instead of decoding as black", () => {
  const png = encodeOpaque(solid(40, 40, [10, 20, 30, 255]));
  const idat = png.indexOf("IDAT");
  const length = png.readUInt32BE(idat - 4);
  const { deflateSync, inflateSync } = zlib;
  const short = deflateSync(inflateSync(png.subarray(idat + 4, idat + 4 + length)).subarray(0, 100));
  const head = Buffer.from(png.subarray(0, idat - 4));
  const chunk = Buffer.alloc(12 + short.length);
  chunk.writeUInt32BE(short.length, 0);
  chunk.write("IDAT", 4, "ascii");
  short.copy(chunk, 8);
  assert.throws(() => decode(Buffer.concat([head, chunk])), /PNG data is 100 bytes/);
});
