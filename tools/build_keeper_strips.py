"""Assemble the Moonstone Keeper pack into horizontal sprite strips.

The pack ships one PNG per frame, in per-animation folders, and it mixes two
cell sizes: 150x150 for most animations and 200x150 for the two attacks. The
attack cells are the same drawing with 25px of extra canvas on each side --
verified by measuring the character's cyan gem, which sits at x=75 in a 150
cell and x=100 in a 200 cell.

So: pad every 150-wide frame by 25px per side and everything lands on one
uniform 200x150 grid with a single pivot. Run from the project root:

    python tools/build_keeper_strips.py "<path to the unzipped pack>"
"""

import os
import sys
import glob
from PIL import Image

CELL_W, CELL_H = 200, 150
OUT_DIR = os.path.join("assets", "keeper")

# our name -> folder in the pack
ANIMS = {
    "idle": "Idle",
    "walk": "Walk",
    "run": "Run",
    "attack": "Attack1",
    "hurt": "Hit",
    "death": "Death",
}


def build(pack_root: str) -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    for our_name, folder in ANIMS.items():
        src = os.path.join(pack_root, f"{folder}-MoonstoneKeeper-SUCART", "No BG")
        frames = sorted(glob.glob(os.path.join(src, "*.png")))
        if not frames:
            print(f"  !! no frames found for {folder} in {src}")
            continue

        strip = Image.new("RGBA", (CELL_W * len(frames), CELL_H), (0, 0, 0, 0))
        for i, path in enumerate(frames):
            im = Image.open(path).convert("RGBA")
            # centre a narrow cell inside the uniform one; wide cells already fit
            dx = (CELL_W - im.width) // 2
            dy = (CELL_H - im.height) // 2
            strip.paste(im, (i * CELL_W + dx, dy), im)

        out = os.path.join(OUT_DIR, f"{our_name}.png")
        strip.save(out)
        print(f"  {our_name:7s} {len(frames):3d} frames -> {out}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit("usage: python tools/build_keeper_strips.py <path to unzipped pack>")
    build(sys.argv[1])
