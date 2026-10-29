"""Downloads animated Pokémon sprites from PMD SpriteCollab (CC BY-NC 4.0).

    python3 tools/import_pmd_sprites.py [species_id ...]     # default: every brawler

For each Pokémon (normal and shiny) it picks the animations the game uses,
downloads their sheets from https://github.com/PMDCollab/SpriteCollab and writes:

    assets/pmd/<id>/<anim>.png           sheet: frames across, 8 directions down
    assets/pmd/<id>/shiny/<anim>.png     the shiny colours (when there is one)
    assets/pmd/<id>/anims.json           per anim: frame size, frame durations
                                         (seconds), hit frame, ground point
    assets/pmd/credits.json              sprite artists per Pokémon (shown in
                                         Settings → About & Legal)

Direction rows (PMD order): down, down-right, right, up-right, up, up-left,
left, down-left.
"""
import io, json, os, sys, urllib.request
import xml.etree.ElementTree as ET
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "pmd")
BASE = "https://raw.githubusercontent.com/PMDCollab/SpriteCollab/master"
# The game's animation -> SpriteCollab animations to try, best first.
WANT = {
    "walk": ["Walk"],
    "idle": ["Idle", "Walk"],
    "attack": ["Attack", "Strike", "QuickStrike", "Swing", "Double", "Shoot"],
    "shoot": ["Shoot", "Shock", "SpAttack", "Charge", "Attack"],
    "special": ["SpAttack", "Charge", "Shoot", "Shock", "Attack"],
    "hurt": ["Hurt", "Pain"],
    "faint": ["Faint", "Hurt"],
}
FRAME_SECONDS = 1.0 / 60.0  # SpriteCollab durations are in game frames.


def fetch(path):
    try:
        with urllib.request.urlopen(f"{BASE}/{path}", timeout=30) as r:
            return r.read()
    except Exception:
        return None


def anim_table(xml_bytes):
    root = ET.fromstring(xml_bytes)
    anims = {}
    for a in root.iter("Anim"):
        name = a.findtext("Name")
        anims[name] = {
            "copy": a.findtext("CopyOf"),
            "fw": int(a.findtext("FrameWidth") or 0),
            "fh": int(a.findtext("FrameHeight") or 0),
            "hit": int(a.findtext("HitFrame") or -1),
            "durations": [int(d.text) for d in a.iter("Duration")],
        }
    return anims


def resolve(anims, name):
    seen = set()
    while name in anims and anims[name]["copy"] and name not in seen:
        seen.add(name)
        name = anims[name]["copy"]
    return name if name in anims else None


def ground_y(shadow_png, fw, fh):
    """Pixel row (from the top of a frame) where the Pokémon stands, from the shadow sheet."""
    if shadow_png is None:
        return fh * 0.75
    im = Image.open(io.BytesIO(shadow_png)).convert("RGBA").crop((0, 0, fw, fh))
    box = im.getchannel("A").getbbox()
    return (box[1] + box[3]) / 2.0 if box else fh * 0.75


def feet(png, fw, fh):
    """Lowest drawn pixel of the walk cycle, facing down, as pixels below the frame's centre.
    Every SpriteCollab animation shares the frame centre, so this lines all of them up."""
    im = Image.open(io.BytesIO(png)).convert("RGBA")
    bottom = 0
    for c in range(im.width // fw):
        box = im.crop((c * fw, 0, (c + 1) * fw, fh)).getchannel("A").getbbox()
        if box:
            bottom = max(bottom, box[3])
    return bottom - fh / 2.0


def body_height(png, fw, fh, gy):
    """How tall the Pokémon is above its ground point, in pixels (first frame, facing down)."""
    im = Image.open(io.BytesIO(png)).convert("RGBA").crop((0, 0, fw, fh))
    box = im.getchannel("A").getbbox()
    return max(8.0, gy - box[1]) if box else fh * 0.6


def import_one(sid, dex):
    folder = f"sprite/{dex:04d}"
    xml = fetch(f"{folder}/AnimData.xml")
    if xml is None:
        print(f"  {sid}: no SpriteCollab sprite, keeping the current one")
        return None
    anims = anim_table(xml)
    out = os.path.join(OUT, sid)
    os.makedirs(os.path.join(out, "shiny"), exist_ok=True)
    meta = {}
    shiny_ok = fetch(f"{folder}/0000/0001/AnimData.xml") is not None
    for key, options in WANT.items():
        src = next((resolve(anims, o) for o in options if resolve(anims, o)), None)
        if src is None:
            continue
        a = anims[src]
        png = fetch(f"{folder}/{src}-Anim.png")
        if png is None:
            continue
        open(os.path.join(out, key + ".png"), "wb").write(png)
        if shiny_ok:
            shiny = fetch(f"{folder}/0000/0001/{src}-Anim.png")
            if shiny:
                open(os.path.join(out, "shiny", key + ".png"), "wb").write(shiny)
        sheet = Image.open(io.BytesIO(png))
        gy = ground_y(fetch(f"{folder}/{src}-Shadow.png"), a["fw"], a["fh"])
        meta[key] = {
            "source": src, "fw": a["fw"], "fh": a["fh"],
            "cols": sheet.width // a["fw"], "rows": sheet.height // a["fh"],
            "durations": [round(d * FRAME_SECONDS, 4) for d in a["durations"]],
            "hit": a["hit"], "ground": gy,
            "height": body_height(png, a["fw"], a["fh"], gy),
        }
    if "walk" in meta:
        walk = anims[meta["walk"]["source"]]
        png = open(os.path.join(out, "walk.png"), "rb").read()
        meta["walk"]["feet"] = feet(png, walk["fw"], walk["fh"])
        meta["walk"]["height"] = body_height(png, walk["fw"], walk["fh"], walk["fh"] / 2.0 + meta["walk"]["feet"])
    json.dump(meta, open(os.path.join(out, "anims.json"), "w"), indent="\t")
    credits = fetch(f"{folder}/credits.txt")
    names = sorted({line.split("\t")[1] for line in (credits or b"").decode().splitlines() if "\t" in line})
    print(f"  {sid}: {', '.join(sorted(meta))}{' + shiny' if shiny_ok else ''}")
    return names


def main(ids):
    os.makedirs(OUT, exist_ok=True)
    brawlers = os.path.join(ROOT, "data", "brawlers")
    if not ids:
        ids = sorted(f[:-5] for f in os.listdir(brawlers) if f.endswith(".json"))
    credits_path = os.path.join(OUT, "credits.json")
    credits = json.load(open(credits_path)) if os.path.exists(credits_path) else {}
    for sid in ids:
        dex = json.load(open(os.path.join(brawlers, sid + ".json")))["dex"]
        names = import_one(sid, dex)
        if names is not None:
            credits[sid] = names
    json.dump(dict(sorted(credits.items())), open(credits_path, "w"), indent="\t")


if __name__ == "__main__":
    main(sys.argv[1:])
