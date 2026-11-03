#!/usr/bin/env python3
"""Developer tool: stack CC0 Poly Haven surface textures into vertical strips
that Godot imports as Texture2DArray (albedo / normal / ARM) for the terrain
shader. Layer order is the contract with shaders/terrain.gdshader.
"""
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "assets", "polyhaven", "textures")
OUT = os.path.join(HERE, "..", "assets", "generated", "terrain")

LAYERS = [
    "coast_sand_01",        # 0 dry sand
    "damp_beach_sand",      # 1 damp / wet sand
    "leafy_grass",          # 2 meadow grass
    "sparse_grass",         # 3 sparse grass
    "forest_leaves_02",     # 4 needle-and-moss forest floor
    "dry_decay_leaves",     # 5 broadleaf litter
    "dirt",                 # 6 packed dirt (camp, trails)
    "mossy_rock",           # 7 lichen/moss rock
    "rock_face",            # 8 earthy rock / banks
    "gravel",               # 9 dark shore gravel
    "river_small_rocks",    # 10 riverbed pebbles
    "brown_mud_leaves_01",  # 11 pond-edge mud
]
SIZE = 1024

IMPORT = """[remap]

importer="2d_array_texture"
type="CompressedTexture2DArray"

[deps]

source_file="res://assets/generated/terrain/{name}"

[params]

compress/mode=2
compress/high_quality=false
compress/lossy_quality=0.7
compress/hdr_compression=1
compress/channel_pack={pack}
mipmaps/generate=true
mipmaps/limit=-1
slices/horizontal=1
slices/vertical={n}
"""


def main():
    os.makedirs(OUT, exist_ok=True)
    for kind, suffix, pack in (("albedo", "diff", 0), ("normal", "nor_gl", 0), ("arm", "arm", 0)):
        strip = Image.new("RGB", (SIZE, SIZE * len(LAYERS)))
        for i, name in enumerate(LAYERS):
            im = Image.open(os.path.join(SRC, name, f"{name}_{suffix}.jpg")).convert("RGB").resize((SIZE, SIZE), Image.LANCZOS)
            strip.paste(im, (0, i * SIZE))
        fname = f"terrain_{kind}.jpg"
        strip.save(os.path.join(OUT, fname), quality=92)
        with open(os.path.join(OUT, fname + ".import"), "w") as f:
            f.write(IMPORT.format(name=fname, n=len(LAYERS), pack=pack))
        print("wrote", fname)


if __name__ == "__main__":
    main()
