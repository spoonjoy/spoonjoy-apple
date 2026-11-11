#!/usr/bin/env python3
"""Turns the scene attachments of a Store scenes result bundle into OUT/<scene>.png.

Usage: export-store-scenes.py RESULT_BUNDLE OUT SCENE...

StoreScenesUITests names each attachment scene-<scene>; xcresulttool exports it under a generated file name and lists
the name it was given in manifest.json. Fails unless every SCENE asked for came out exactly once.
"""
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

NAME = re.compile(r"^scene-([a-z0-9-]+?)(?:_\d+_[0-9A-Fa-f-]+)?(?:\.png)?$")


def scenes_in(manifest):
    """{scene: exported file name} from xcresulttool's manifest, and the names seen twice."""
    found, twice = {}, []
    for test in manifest:
        for attachment in test.get("attachments", []):
            match = NAME.match(attachment.get("suggestedHumanReadableName", ""))
            if not match:
                continue
            scene = match.group(1)
            if scene in found:
                twice.append(scene)
            found[scene] = attachment["exportedFileName"]
    return found, twice


def main():
    if len(sys.argv) < 4:
        raise SystemExit(__doc__)
    bundle, out, wanted = sys.argv[1], sys.argv[2], sys.argv[3:]
    with tempfile.TemporaryDirectory() as exported:
        subprocess.run(["xcrun", "xcresulttool", "export", "attachments", "--path", bundle, "--output-path", exported],
                       check=True)
        with open(os.path.join(exported, "manifest.json")) as handle:
            found, twice = scenes_in(json.load(handle))
        missing = [scene for scene in wanted if scene not in found]
        if missing or twice:
            raise SystemExit(f"Store scenes: missing {missing}, taken twice {twice}; found {sorted(found)}")
        os.makedirs(out, exist_ok=True)
        for scene in wanted:
            shutil.copyfile(os.path.join(exported, found[scene]), os.path.join(out, f"{scene}.png"))
            print(f"{scene}.png")


if __name__ == "__main__":
    main()
