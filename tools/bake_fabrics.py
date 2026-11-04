#!/usr/bin/env python3
"""Developer tool (Phase 12): neutral grey versions of Poly Haven CC0 fabric
scans so code can tint them to any colour without inheriting the scan's own
dye (the old blankets multiplied a blue denim photo by red/green/ochre).

Each output keeps the weave detail (luminance) with its mean normalised to
0.5, so a material's albedo_color = 2 x target colour reproduces the target
on average. Derived works of CC0 sources (assets/polyhaven/provenance.json).

Usage: python3 tools/bake_fabrics.py   (needs Pillow)
"""
import os
from PIL import Image, ImageOps, ImageStat

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SRC = os.path.join(ROOT, "assets", "polyhaven", "textures")
OUT = os.path.join(ROOT, "assets", "generated", "fabrics")
NAMES = ["poly_wool_herringbone", "caban", "stretch_poplin", "rough_linen",
         "polar_fleece", "knitted_fleece", "denim_fabric", "fabric_leather_02"]


def main():
    os.makedirs(OUT, exist_ok=True)
    for n in NAMES:
        img = Image.open(os.path.join(SRC, n, f"{n}_diff.jpg")).convert("L")
        # Gentle contrast lift so very flat scans still show their weave.
        img = ImageOps.autocontrast(img, cutoff=1)
        mean = ImageStat.Stat(img).mean[0]
        span = 0.35 if n not in ("fabric_leather_02",) else 0.5
        lut = [int(max(0, min(255, 127.5 + (v - mean) * span))) for v in range(256)]
        img = img.point(lut)
        img.convert("RGB").save(os.path.join(OUT, f"{n}_grey.jpg"), quality=90)
        print("baked", n, "mean", round(mean, 1))


if __name__ == "__main__":
    main()
