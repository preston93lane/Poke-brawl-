"""Draws the stadium crowd: small pixel-art trainers, one row per look, two frames
each (0 = clapping at the chest, 1 = arms up cheering). Our own art.

    python3 tools/make_crowd.py   ->   assets/crowd/trainers.png

The arena's crowd shader picks a row per spectator and flips between the two
frames (scripts/arena_surroundings.gd, assets/shaders/crowd.gdshader).
"""
import os, random
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "crowd", "trainers.png")
W, H = 24, 32
LOOKS = 10

SKIN = [(255, 214, 170), (240, 190, 140), (200, 145, 100), (150, 100, 65), (110, 72, 48)]
HAIR = [(40, 30, 25), (90, 55, 30), (230, 190, 90), (180, 60, 40), (60, 60, 70), (250, 240, 220)]
SHIRT = [(220, 60, 60), (60, 110, 220), (60, 170, 90), (240, 190, 50), (150, 80, 200), (240, 240, 240),
         (240, 130, 40), (50, 180, 190), (230, 100, 160), (90, 90, 100)]
PANTS = [(50, 60, 110), (60, 50, 40), (30, 30, 35), (120, 110, 90), (70, 90, 60)]
OUTLINE = (30, 24, 30)


def trainer(draw, ox, rng, look, cheering):
    skin = SKIN[look % len(SKIN)]
    hair = HAIR[(look * 3) % len(HAIR)]
    shirt = SHIRT[look % len(SHIRT)]
    pants = PANTS[(look * 2) % len(PANTS)]
    cap = look % 3 == 0
    cap_color = SHIRT[(look + 4) % len(SHIRT)]
    long_hair = look % 4 == 1
    cx = ox + W // 2
    # Legs (seated spectators only show a little).
    draw.rectangle([cx - 5, 25, cx - 1, 31], fill=pants, outline=OUTLINE)
    draw.rectangle([cx + 1, 25, cx + 5, 31], fill=pants, outline=OUTLINE)
    # Body.
    draw.rectangle([cx - 6, 15, cx + 6, 26], fill=shirt, outline=OUTLINE)
    # Arms.
    if cheering:
        draw.rectangle([cx - 10, 4, cx - 7, 17], fill=shirt, outline=OUTLINE)
        draw.rectangle([cx + 7, 4, cx + 10, 17], fill=shirt, outline=OUTLINE)
        draw.rectangle([cx - 10, 1, cx - 7, 4], fill=skin, outline=OUTLINE)
        draw.rectangle([cx + 7, 1, cx + 10, 4], fill=skin, outline=OUTLINE)
    else:
        draw.rectangle([cx - 9, 16, cx - 6, 23], fill=shirt, outline=OUTLINE)
        draw.rectangle([cx + 6, 16, cx + 9, 23], fill=shirt, outline=OUTLINE)
        draw.rectangle([cx - 3, 19, cx + 3, 22], fill=skin, outline=OUTLINE)  # Hands together.
    # Head.
    if long_hair:
        draw.rectangle([cx - 6, 5, cx + 6, 17], fill=hair, outline=OUTLINE)
    draw.ellipse([cx - 6, 3, cx + 6, 15], fill=skin, outline=OUTLINE)
    # Hair or cap.
    if cap:
        draw.chord([cx - 6, 2, cx + 6, 12], 180, 360, fill=cap_color, outline=OUTLINE)
        draw.rectangle([cx - 1, 6, cx + 8, 7], fill=cap_color, outline=OUTLINE)  # Brim.
    else:
        draw.chord([cx - 6, 2, cx + 6, 11], 180, 360, fill=hair, outline=OUTLINE)
    # Eyes and an open, cheering mouth.
    draw.point([(cx - 2, 9), (cx + 2, 9)], fill=OUTLINE)
    if cheering:
        draw.rectangle([cx - 1, 11, cx + 1, 12], fill=(150, 40, 40))
    else:
        draw.line([(cx - 1, 12), (cx + 1, 12)], fill=OUTLINE)


def main():
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img = Image.new("RGBA", (W * 2, H * LOOKS), (0, 0, 0, 0))
    rng = random.Random(7)
    for look in range(LOOKS):
        row = Image.new("RGBA", (W * 2, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(row)
        trainer(d, 0, rng, look, False)
        trainer(d, W, rng, look, True)
        img.paste(row, (0, look * H))
    img.save(OUT)
    print("saved", OUT)


if __name__ == "__main__":
    main()
