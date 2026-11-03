"""Copies the nature models the arenas use from Quaternius' Stylized Nature MegaKit
(free Standard version, CC0: https://quaternius.com/packs/stylizednaturemegakit.html,
also on https://opengameart.org/content/stylized-nature-megakit) into
assets/models/nature/, shrinking their textures so the web build stays small.

    python3 tools/import_nature_models.py <path to the kit's glTF folder>

scripts/nature_kit.gd loads them (rocks for rock walls and boulders, bushes for
hedges, pebbles / mushrooms / flowers as scattered decoration).
"""
import json, os, shutil, sys
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "models", "nature")
MODELS = [
    "Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3",
    "Bush_Common", "Bush_Common_Flowers",
    "Pebble_Round_1", "Pebble_Round_2", "Pebble_Round_3",
    "Mushroom_Common", "Flower_3_Group", "Flower_4_Group", "Clover_1",
]
TEXTURE_SIZE = 512


def main(src):
    os.makedirs(OUT, exist_ok=True)
    textures = set()
    for name in MODELS:
        gltf = json.load(open(os.path.join(src, name + ".gltf")))
        for buf in gltf.get("buffers", []):
            shutil.copy(os.path.join(src, buf["uri"]), OUT)
        for img in gltf.get("images", []):
            textures.add(img["uri"])
        shutil.copy(os.path.join(src, name + ".gltf"), OUT)
    for tex in sorted(textures):
        im = Image.open(os.path.join(src, tex))
        im.thumbnail((TEXTURE_SIZE, TEXTURE_SIZE), Image.LANCZOS)
        im.save(os.path.join(OUT, tex), optimize=True)
    print("copied %d models, %d textures to %s" % (len(MODELS), len(textures), OUT))


if __name__ == "__main__":
    main(sys.argv[1])
