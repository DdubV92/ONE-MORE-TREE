#!/usr/bin/env python3
"""Developer tool: download the CC0 Poly Haven assets this project uses.

Players never run this. Downloaded files are committed under
assets/polyhaven/ together with assets/polyhaven/provenance.json, which
docs/ASSET_PROVENANCE.md summarises. Re-running is idempotent (existing files
are skipped). Requires network access to api.polyhaven.com and dl.polyhaven.org.

Usage: python3 tools/fetch_polyhaven.py
"""
import json
import os
import sys
import urllib.request

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "polyhaven")
API = "https://api.polyhaven.com"
UA = {"User-Agent": "OneMoreTree-asset-fetch/1.0"}

# Models: low-poly props imported as glTF with 1k textures.
MODELS = [
    "stone_fire_pit", "hatchet", "wooden_axe_03", "wooden_axe_02",
    "wooden_crate_01", "wooden_crate_02", "wooden_bucket_01", "Barrel_02",
    "pot_enamel_01", "Rockingchair_01", "propane_tank", "ocean_buoy",
    "painted_wooden_chair_01", "painted_wooden_cabinet", "painted_wooden_nightstand",
    "wooden_bookshelf_worn", "plastic_thermos", "wall_clock", "rubber_boots",
    "wooden_lantern_01", "wooden_picnic_table", "folding_wooden_stool",
    "rusted_spade_01", "sledgehammer_01", "metal_toolbox", "steel_frame_shelves_01",
    "carved_wooden_plate", "wooden_cutting_board",
    "russian_food_cans_01", "plastic_jerrycan", "security_light",
    "industrial_wall_lamp", "throw_pillows_01", "old_bed_frame",
    "tree_stump_01", "fern_02",
    # Phase 12: camper couch, small woodland ground cover, forest-floor debris.
    "sofa_02", "dry_branches_medium_01",
]

# Surface textures: diffuse, OpenGL normal, AO/roughness/metal packed.
TEXTURES = [
    "coast_sand_01", "damp_beach_sand", "forest_leaves_02",
    "leafy_grass", "sparse_grass", "dirt", "mossy_rock",
    "rock_face", "river_small_rocks", "brown_mud_leaves_01",
    "pine_bark", "bark_brown_02", "weathered_planks", "wood_floor_worn",
    "weathered_plank_siding", "denim_fabric", "fabric_leather_01",
    "dry_decay_leaves", "gravel",
    # Phase 12: proper soft furnishings (no more denim stand-ins).
    "poly_wool_herringbone", "caban", "gingham_check", "stretch_poplin",
    "rough_linen", "polar_fleece", "fabric_leather_02", "knitted_fleece",
]
TEXTURE_MAPS = ["diff", "nor_gl", "arm"]

# Foliage cards borrowed from large tree scans (only the texture maps).
FOLIAGE = {
    "pine_tree_01": ["twig_diff", "twig_alpha", "twig_nor_gl", "bark_diff", "bark_nor_gl", "bark_arm"],
    "fir_tree_01": ["twig_diff", "twig_alpha", "twig_nor_gl"],
    "tree_small_02": ["leaves_diff", "leaves_alpha", "leaves_nor_gl", "branch_diff"],
}

RES = "1k"


def get_json(url):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read().decode("utf-8"))


def download(url, dest):
    if os.path.exists(dest) and os.path.getsize(dest) > 0:
        return False
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=300) as r, open(dest + ".part", "wb") as f:
        while True:
            chunk = r.read(1 << 16)
            if not chunk:
                break
            f.write(chunk)
    os.replace(dest + ".part", dest)
    return True


def pick(files_entry, res):
    for r in (res, "1k", "2k", "4k"):
        if r in files_entry:
            return files_entry[r]
    raise KeyError("no resolution")


def main():
    provenance = {}
    for name in MODELS:
        info = get_json(f"{API}/info/{name}")
        files = get_json(f"{API}/files/{name}")
        gltf = pick(files["gltf"], RES)["gltf"]
        d = os.path.join(ROOT, "models", name)
        download(gltf["url"], os.path.join(d, os.path.basename(gltf["url"])))
        for rel, inc in gltf.get("include", {}).items():
            download(inc["url"], os.path.join(d, rel))
        provenance[name] = record(info, "model", f"gltf {RES}")
        print("model", name)
    for name in TEXTURES:
        info = get_json(f"{API}/info/{name}")
        files = get_json(f"{API}/files/{name}")
        d = os.path.join(ROOT, "textures", name)
        for m in TEXTURE_MAPS:
            key = {"diff": "Diffuse", "nor_gl": "nor_gl", "arm": "arm"}[m]
            entry = files.get(key) or files.get(m)
            if entry is None:
                print("  missing map", name, m)
                continue
            f = pick(entry, RES)["jpg"] if "jpg" in pick(entry, RES) else pick(entry, RES)["png"]
            download(f["url"], os.path.join(d, f"{name}_{m}.jpg"))
        provenance[name] = record(info, "texture", f"{RES} jpg: {', '.join(TEXTURE_MAPS)}")
        print("texture", name)
    for name, maps in FOLIAGE.items():
        info = get_json(f"{API}/info/{name}")
        files = get_json(f"{API}/files/{name}")
        d = os.path.join(ROOT, "foliage", name)
        for m in maps:
            e = pick(files[m], RES)
            f = e.get("png") or e.get("jpg")
            ext = os.path.splitext(f["url"])[1]
            download(f["url"], os.path.join(d, f"{name}_{m}{ext}"))
        provenance[name] = record(info, "texture maps from model", f"{RES}: {', '.join(maps)}")
        print("foliage", name)
    with open(os.path.join(ROOT, "provenance.json"), "w") as f:
        json.dump(provenance, f, indent=1, sort_keys=True)
    print("done:", len(provenance), "assets")


def record(info, kind, files):
    return {
        "title": info.get("name"),
        "kind": kind,
        "authors": info.get("authors"),
        "license": "CC0 1.0 (Poly Haven)",
        "source": f"https://polyhaven.com/a/{info.get('slug', '')}" if info.get("slug") else "https://polyhaven.com",
        "files": files,
    }


if __name__ == "__main__":
    sys.exit(main())
