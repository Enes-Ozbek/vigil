"""Assemble the Dreadknight Rotmaws pack into horizontal sprite strips.

The pack ships one PNG per frame, one folder per animation, on a 256x256
canvas holding a sprite roughly 54x57. Keeping that canvas would mean a
17-frame strip 4352px wide that is over 90% empty.

So every frame is cropped to the SAME window before assembly -- the same
window for every animation, which is what preserves the relative position of
the sprite between them. Measured across the frames actually used:

    run    x  97..151   y 111..168
    attack x 104..147   y 107..162
    crit   x 103..157   y  96..175
    death  x 113..153   y 113..158

CROP covers all of that with margin, and puts the feet at a consistent y.

Run from the project root:

    python tools/build_dreadknight_strips.py "<path to the unzipped pack>"
"""

import os
import sys
import glob
from PIL import Image

CROP = (88, 88, 168, 184)          # left, top, right, bottom -> an 80x96 cell
OUT_DIR = os.path.join("assets", "foes", "dreadknight")

# our name -> folder in the pack
ANIMS = {
    "run": "Run 2",
    "run_alt": "Run 1",
    "attack": "Attack 1",
    "death": "Death",
    "idle": "Idle 1",
}


def build(pack_root: str) -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    cw = CROP[2] - CROP[0]
    ch = CROP[3] - CROP[1]

    for our_name, folder in ANIMS.items():
        src = os.path.join(pack_root, folder)
        frames = sorted(
            glob.glob(os.path.join(src, "*.png")),
            key=lambda p: int(os.path.splitext(os.path.basename(p))[0]),
        )
        if not frames:
            print(f"  !! no frames for {folder}")
            continue

        strip = Image.new("RGBA", (cw * len(frames), ch), (0, 0, 0, 0))
        for i, path in enumerate(frames):
            cell = Image.open(path).convert("RGBA").crop(CROP)
            strip.paste(cell, (i * cw, 0), cell)

        out = os.path.join(OUT_DIR, f"{our_name}.png")
        strip.save(out)
        print(f"  {our_name:8s} {len(frames):3d} frames of {cw}x{ch} -> {out}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit("usage: python tools/build_dreadknight_strips.py <path to unzipped pack>")
    build(sys.argv[1])
