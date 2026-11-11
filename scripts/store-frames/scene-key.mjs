#!/usr/bin/env node
// The Store scenes key of a commit: a hash of everything that can change what the scenes show (the app's screens,
// the scene test, the demo kitchen it photographs) and of which scenes each set takes. Two commits with the same
// key show the same screens, so Store scenes photographs a key once and every later release reuses it; a caption
// or palette change re-frames the same scenes without a Mac.
//
//   node scripts/store-frames/scene-key.mjs [REV]      prints store-scenes-<key> for REV (default HEAD)
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { dirname, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { loadSpec, scenesFor } from "./render.mjs";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
export const SCREEN_PATHS = [
  "Apps/Spoonjoy/iOS",
  "Apps/Spoonjoy/Shared",
  "Sources/SpoonjoyCore",
  "Package.swift",
  "Spoonjoy.xcodeproj",
  "Apps/Spoonjoy/UITests/StoreScenesUITests.swift",
  "Apps/Spoonjoy/UITests/ShellNavigationDriver.swift",
  "distribution/app-store/review-demo-kitchen.json",
];

export function sceneKey(rev = "HEAD", root = ROOT) {
  const git = (...args) => execFileSync("git", ["-C", root, ...args], { encoding: "utf8", maxBuffer: 64 * 1024 * 1024 });
  const tree = git("ls-tree", "-r", rev, "--", ...SCREEN_PATHS);
  const spec = loadSpec({ text: git("show", `${rev}:distribution/app-store/frames/spec.json`) });
  const sets = Object.fromEntries(Object.entries(spec.sets).map(([name, set]) => [name, { simulator: set.simulator, scene_size: set.scene_size, scenes: scenesFor(set) }]));
  return `store-scenes-${createHash("sha256").update(tree).update(JSON.stringify(sets)).digest("hex").slice(0, 20)}`;
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  console.log(sceneKey(process.argv[2] ?? "HEAD"));
}
