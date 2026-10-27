"""Builds the in-game sprite sheets from Pokémon Black/White (Gen 5) sprites.

    python3 tools/import_bw_sprites.py <download_dir>

<download_dir> holds <id>_front.png, <id>_back.png, <id>_front_shiny.png and
<id>_back_shiny.png (96x96 each, e.g. from the PokeAPI sprites repository,
sprites/pokemon/versions/generation-v/black-white/[back/][shiny/]<dex>.png).

Writes assets/brawlers/<id>.png and assets/brawlers/shiny/<id>.png as 288x96
sheets: front | side (the front mirrored to face right) | back. Each view is
trimmed and stood on the bottom edge so the Pokémon's feet sit on the ground.
Also sets "sprite_scale" and "sprite_height" in data/brawlers/<id>.json so tiny
Pokémon stay visible and huge ones don't fill the screen, while keeping their
relative sizes. Pokémon without a Black/White sprite (Annihilape) keep their
generated sheet, upscaled to match, with a hue-shifted shiny.
"""
import colorsys, json, os, sys
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "brawlers")
DATA = os.path.join(ROOT, "data", "brawlers")
FRAME = 96
## Metres per sprite pixel in game (keep in sync with Brawler.SHEET_PIXEL_SIZE).
METRES_PER_PX = 0.0253
MIN_HEIGHT, MAX_HEIGHT = 0.98, 2.65
LEGENDARY_BOOST = 1.15


def stand(im):
    """Trim to the visible pixels and place bottom-centre on a FRAME x FRAME canvas."""
    im = im.convert("RGBA")
    box = im.getchannel("A").getbbox()
    canvas = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    if box is None:
        return canvas, 0
    part = im.crop(box)
    w, h = part.size
    canvas.alpha_composite(part, ((FRAME - w) // 2, FRAME - h - 1))
    return canvas, h


def sheet(front, back):
    f, fh = stand(front)
    b, bh = stand(back)
    out = Image.new("RGBA", (FRAME * 3, FRAME), (0, 0, 0, 0))
    out.alpha_composite(f, (0, 0))
    out.alpha_composite(f.transpose(Image.FLIP_LEFT_RIGHT), (FRAME, 0))  # BW fronts face left
    out.alpha_composite(b, (FRAME * 2, 0))
    return out, max(fh, bh)


def hue_shift(im, amount=0.45):
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            r2, g2, b2 = colorsys.hsv_to_rgb((h + amount) % 1.0, s, v)
            px[x, y] = (int(r2 * 255), int(g2 * 255), int(b2 * 255), a)
    return im


def from_old_sheet(path):
    """Upscale a generated 64px front/side/back sheet into front + back 96px views."""
    old = Image.open(path).convert("RGBA")
    size = old.height
    views = [old.crop((i * size, 0, (i + 1) * size, size)).resize((FRAME, FRAME), Image.NEAREST) for i in range(3)]
    return views[0], views[2]


def update_json(sid, height_px, target_metres=0.0):
    path = os.path.join(DATA, sid + ".json")
    d = json.load(open(path))
    metres = max(1, height_px) * METRES_PER_PX
    scale = min(max(metres, MIN_HEIGHT), MAX_HEIGHT) / metres
    if target_metres > 0.0:
        scale = target_metres / metres
    if d.get("legendary"):
        scale *= LEGENDARY_BOOST
    # Edit the two lines in place so the hand-readable layout is kept.
    lines = [l for l in open(path).read().split("\n") if not l.strip().startswith('"sprite_height"')]
    for i, line in enumerate(lines):
        if line.strip().startswith('"sprite_scale"'):
            lines[i] = f'\t"sprite_scale": {round(scale, 3)},'
            lines.insert(i + 1, f'\t"sprite_height": {height_px},')
            break
    open(path, "w").write("\n".join(lines))


def main(src):
    os.makedirs(os.path.join(OUT, "shiny"), exist_ok=True)
    count = 0
    for f in sorted(os.listdir(DATA)):
        sid = f[:-5]
        front = os.path.join(src, f"{sid}_front.png")
        if os.path.exists(front):
            normal, h = sheet(Image.open(front), Image.open(os.path.join(src, f"{sid}_back.png")))
            shiny, _ = sheet(Image.open(os.path.join(src, f"{sid}_front_shiny.png")),
                             Image.open(os.path.join(src, f"{sid}_back_shiny.png")))
        else:
            old = os.path.join(OUT, sid + ".png")
            fv, bv = from_old_sheet(old)
            normal, h = sheet(fv, bv)
            shiny = hue_shift(normal.copy())
            print(f"{sid}: no Black/White sprite, kept the generated one")
        normal.save(os.path.join(OUT, sid + ".png"))
        shiny.save(os.path.join(OUT, "shiny", sid + ".png"))
        # Generated fallbacks fill their canvas, so size them like a typical final stage.
        update_json(sid, h, 0.0 if os.path.exists(front) else 1.6)
        count += 1
    print(f"wrote {count} sprite sheets (+ shiny)")


if __name__ == "__main__":
    main(sys.argv[1])
