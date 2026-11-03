#!/usr/bin/env python3
"""Developer tool: compose foliage card textures from CC0 Poly Haven twig/leaf
atlases (assets/polyhaven/foliage). Output: assets/generated/foliage/*.png.
Deterministic (fixed seeds). Requires Pillow. Players never run this.
"""
import os
import random
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "assets", "polyhaven", "foliage")
OUT = os.path.join(HERE, "..", "assets", "generated", "foliage")


def load_rgba(diff, alpha):
    d = Image.open(os.path.join(SRC, diff)).convert("RGB")
    a = Image.open(os.path.join(SRC, alpha)).convert("L")
    d.putalpha(a)
    return d


def crop(img, box):
    c = img.crop(box)
    bb = c.getchannel("A").point(lambda v: 255 if v > 40 else 0).getbbox()
    return c.crop(bb) if bb else c


def stamp(canvas, sprite, center, angle, scale, tint=1.0):
    w, h = sprite.size
    s = sprite.resize((max(1, int(w * scale)), max(1, int(h * scale))), Image.LANCZOS)
    if tint != 1.0:
        r, g, b, a = s.split()
        r = r.point(lambda v: min(255, int(v * tint)))
        g = g.point(lambda v: min(255, int(v * tint)))
        b = b.point(lambda v: min(255, int(v * tint)))
        s = Image.merge("RGBA", (r, g, b, a))
    s = s.rotate(angle, resample=Image.BICUBIC, expand=True)
    x = int(center[0] - s.size[0] / 2)
    y = int(center[1] - s.size[1] / 2)
    canvas.alpha_composite(s, (x, y)) if 0 <= x and 0 <= y and x + s.size[0] <= canvas.size[0] and y + s.size[1] <= canvas.size[1] else _paste_clipped(canvas, s, x, y)


def _paste_clipped(canvas, s, x, y):
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    layer.paste(s, (x, y), s)
    canvas.alpha_composite(layer)


def dilate_color(img):
    # Bleed RGB into transparent pixels so mipmaps don't produce dark fringes.
    base = img.copy()
    rgb = Image.new("RGB", img.size, (0, 0, 0))
    small = img.resize((32, 32), Image.BOX).convert("RGB").resize(img.size, Image.BILINEAR)
    rgb.paste(small)
    rgb.paste(base.convert("RGB"), (0, 0), base.getchannel("A"))
    rgb.putalpha(base.getchannel("A"))
    return rgb


def pine_card(rng):
    atlas = load_rgba("pine_tree_01/pine_tree_01_twig_diff.png", "pine_tree_01/pine_tree_01_twig_alpha.png")
    a = saturated_only(crop(atlas, (20, 30, 225, 400)))
    sprigs = [a, a.transpose(Image.FLIP_LEFT_RIGHT)]
    c = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    # Tufts radiating from bottom-centre: a pine branch-tip clump.
    for k in range(34):
        sp = sprigs[k % 2]
        ang = rng.uniform(-70, 70)
        dist = rng.uniform(30, 150)
        import math
        cx = 256 + math.sin(math.radians(ang)) * dist
        cy = 400 - math.cos(math.radians(ang)) * dist
        stamp(c, sp, (cx, cy), -ang + rng.uniform(-15, 15), rng.uniform(0.55, 0.85), rng.uniform(0.8, 1.15))
    return c


def fir_card(rng):
    atlas = load_rgba("fir_tree_01/fir_tree_01_twig_diff.png", "fir_tree_01/fir_tree_01_twig_alpha.png")
    sprigs = [crop(atlas, (316, 410, 656, 800)), crop(atlas, (646, 460, 1006, 850)),
              crop(atlas, (666, 40, 956, 380)), crop(atlas, (186, 50, 426, 320))]
    c = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    # A drooping spruce branch spray: stem from left edge (x=0) to right tip.
    for k in range(26):
        t = k / 25.0
        x = 20 + t * 450
        y = 256 + (t * t) * 60 + rng.uniform(-60, 60) * (0.4 + 0.6 * (1 - t))
        sp = sprigs[rng.randrange(4)]
        stamp(c, sp, (x, y), -90 + rng.uniform(-35, 35), rng.uniform(0.45, 0.75) * (1.0 - 0.35 * t), rng.uniform(0.85, 1.1))
    return c


def green_only(img):
    # Drop the atlas' pale stem strips: keep clearly green pixels.
    px = img.load()
    for y in range(img.size[1]):
        for x in range(img.size[0]):
            r, g, b, a = px[x, y]
            if a and not (g > r * 1.15 and g > b * 1.1):
                px[x, y] = (r, g, b, 0)
    return img


def saturated_only(img):
    px = img.load()
    for y in range(img.size[1]):
        for x in range(img.size[0]):
            r, g, b, a = px[x, y]
            if a and max(r, g, b) - min(r, g, b) < 22:
                px[x, y] = (r, g, b, 0)
    return img


def leaf_card(rng):
    atlas = green_only(load_rgba("tree_small_02/tree_small_02_leaves_diff.png", "tree_small_02/tree_small_02_leaves_alpha.png"))
    regions = [crop(atlas, (40, 40, 290, 330)), crop(atlas, (60, 330, 300, 620)), crop(atlas, (560, 120, 860, 520)),
               crop(atlas, (560, 480, 900, 700)), crop(atlas, (40, 600, 300, 1000))]
    c = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    import math
    for k in range(30):
        a = rng.uniform(0, 360)
        r = rng.uniform(0, 175) ** 0.9 * 1.1
        cx = 256 + math.cos(math.radians(a)) * r
        cy = 256 + math.sin(math.radians(a)) * r
        # Birch-like lighter, yellower green.
        stamp(c, regions[rng.randrange(len(regions))], (cx, cy), rng.uniform(0, 360), rng.uniform(0.45, 0.7), rng.uniform(1.05, 1.3))
    return c


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, fn, seed in (("pine_card", pine_card, 11), ("spruce_card", fir_card, 23), ("birch_card", leaf_card, 37)):
        img = dilate_color(fn(random.Random(seed)))
        img.save(os.path.join(OUT, name + ".png"))
        print("wrote", name)


if __name__ == "__main__":
    main()
