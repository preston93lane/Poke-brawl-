"""Draws the stadium crowd: small pixel-art trainers in the style of the handheld
overworld sprites (big round head, bold hair or cap, short body, top-left light,
outlines in a darker shade of each colour rather than black). Our own art, made
here shape by shape; one row per look, two frames each (0 = clapping, 1 = arms
up cheering).

    python3 tools/make_crowd.py   ->   assets/crowd/trainers.png

The sheet also packs in the fan-made spectators from assets/crowd/fan/
(tools/import_crowd_sprites.py). Every look is one row of CELL-sized frames,
feet on the bottom edge; fan sprites have one pose, so their "cheer" frame is
the same figure hopping up. scripts/arena_surroundings.gd reads the row count
from the sheet's height (CELL must match its CROWD_CELL).
"""
import glob, os, random
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "crowd", "trainers.png")
W, H = 20, 28
LOOKS = 16
CELL = (28, 34)
FAN = os.path.join(ROOT, "assets", "crowd", "fan")

SKIN = [(252, 216, 176), (240, 196, 150), (214, 160, 112), (168, 112, 72), (124, 82, 52)]
HAIR = [(52, 40, 36), (112, 64, 32), (232, 196, 88), (200, 72, 48), (72, 72, 96), (236, 236, 240),
        (96, 56, 128), (40, 88, 160), (224, 120, 168), (64, 140, 72)]
CLOTH = [(216, 56, 56), (56, 104, 216), (56, 168, 88), (240, 184, 48), (144, 80, 200), (240, 240, 236),
         (240, 128, 40), (48, 176, 184), (232, 104, 160), (88, 88, 104), (40, 40, 48), (168, 120, 72)]
LEGS = [(48, 56, 104), (72, 56, 44), (36, 36, 44), (128, 116, 96), (64, 96, 64)]
SHOE = [(200, 48, 48), (40, 40, 48), (232, 232, 232), (56, 96, 200)]


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c)


class Canvas:
    def __init__(self):
        self.px = {}

    def set(self, x, y, c):
        if 0 <= x < W and 0 <= y < H:
            self.px[(x, y)] = c

    def rect(self, x0, y0, x1, y1, c, lit=True):
        """Filled box, lit from the top left: a light first row/column, a dark last."""
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                k = 1.0
                if lit and (y == y0 or x == x0):
                    k = 1.15
                if lit and (y == y1 or x == x1):
                    k = 0.78
                self.set(x, y, shade(c, k))

    def ellipse(self, cx, cy, rx, ry, c, lit=True):
        for y in range(int(cy - ry), int(cy + ry) + 1):
            for x in range(int(cx - rx), int(cx + rx) + 1):
                dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
                d = dx * dx + dy * dy
                if d <= 1.0:
                    k = 1.0
                    if lit:
                        light = -0.55 * dx - 0.7 * dy  # Brighter toward the top left.
                        k = 1.0 + 0.16 * light
                        if d > 0.72 and (dx > 0.2 or dy > 0.3):
                            k *= 0.82
                    self.set(x, y, shade(c, k))

    def image(self):
        img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        for (x, y), c in self.px.items():
            img.putpixel((x, y), c + (255,))
        # Outline: every empty pixel touching the figure takes a dark shade of its neighbour.
        out = img.copy()
        for y in range(H):
            for x in range(W):
                if img.getpixel((x, y))[3]:
                    continue
                for dx, dy in ((0, 1), (1, 0), (-1, 0), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < W and 0 <= ny < H and img.getpixel((nx, ny))[3]:
                        c = img.getpixel((nx, ny))
                        out.putpixel((x, y), shade(c[:3], 0.32) + (255,))
                        break
        return out


def trainer(look, cheering):
    rng = random.Random(look * 97 + 13)
    skin = SKIN[look % len(SKIN)]
    hair = HAIR[(look * 3 + 1) % len(HAIR)]
    top = CLOTH[(look * 5) % len(CLOTH)]
    trim = CLOTH[(look * 5 + 3) % len(CLOTH)]
    legs = LEGS[look % len(LEGS)]
    shoe = SHOE[(look * 3) % len(SHOE)]
    style = ["cap", "spiky", "long", "pigtails", "bun", "beanie", "short", "cap_back"][look % 8]
    skirt = style in ("long", "pigtails", "bun") and look % 3 != 0
    cv = Canvas()
    cx = 10
    # Legs and shoes (short: these are seated-up, cheering fans).
    if skirt:
        cv.rect(cx - 4, 20, cx + 3, 22, trim)
        cv.rect(cx - 3, 23, cx - 2, 24, skin, False)
        cv.rect(cx + 1, 23, cx + 2, 24, skin, False)
    else:
        cv.rect(cx - 3, 20, cx - 1, 24, legs)
        cv.rect(cx, 20, cx + 2, 24, legs)
    cv.rect(cx - 4, 25, cx - 1, 26, shoe)
    cv.rect(cx, 25, cx + 3, 26, shoe)
    # Body: a jacket with a stripe of the shirt under it.
    cv.rect(cx - 4, 14, cx + 3, 20, top)
    cv.rect(cx - 1, 15, cx, 19, trim, False)
    # Arms.
    if not cheering:
        cv.rect(cx - 6, 15, cx - 5, 19, top)
        cv.rect(cx + 4, 15, cx + 5, 19, top)
        cv.rect(cx - 2, 18, cx + 1, 19, skin, False)  # Hands clapping in front.
    # Hair behind the head.
    if style in ("long", "pigtails"):
        cv.rect(cx - 6, 7, cx + 5, 16 if style == "long" else 12, hair)
    if style == "pigtails":
        cv.ellipse(cx - 7, 12, 2, 3, hair)
        cv.ellipse(cx + 6.5, 12, 2, 3, hair)
    if style == "bun":
        cv.ellipse(cx, 2.5, 3, 2.5, hair)
    # The big round head.
    cv.ellipse(cx, 9, 6.5, 6, skin)
    # Hair / hat on top.
    if style in ("cap", "cap_back"):
        cap = CLOTH[(look * 7 + 2) % len(CLOTH)]
        cv.ellipse(cx, 6.5, 6.8, 4.2, cap)
        cv.rect(cx - 6, 7, cx + 6, 8, shade(cap, 0.9))
        if style == "cap":
            cv.rect(cx - 6, 8, cx + 2, 9, shade(cap, 0.75), False)  # Brim, tipped forward.
        else:
            cv.rect(cx + 4, 6, cx + 8, 7, shade(cap, 0.75), False)  # Brim turned round.
        cv.rect(cx - 1, 4, cx + 1, 5, (240, 240, 240), False)  # Logo.
    elif style == "beanie":
        bean = CLOTH[(look * 7 + 2) % len(CLOTH)]
        cv.ellipse(cx, 6, 6.5, 4, bean)
        cv.rect(cx - 6, 7, cx + 6, 8, (240, 240, 236))
    elif style == "spiky":
        cv.ellipse(cx, 6, 6.8, 4, hair)
        for sx in (-6, -3, 0, 3, 6):
            cv.rect(cx + sx - 1, 1 + abs(sx) // 3, cx + sx, 3, hair, False)
    else:
        cv.ellipse(cx, 6, 6.8, 4, hair)
        if style in ("long", "pigtails", "bun"):
            cv.rect(cx - 6, 7, cx - 5, 12, hair)  # Side locks framing the face.
            cv.rect(cx + 4, 7, cx + 5, 12, hair)
    # Face: dark eyes, a little blush, an open mouth when cheering.
    eye = (40, 32, 48)
    cv.rect(cx - 3, 10, cx - 3, 11, eye, False)
    cv.rect(cx + 2, 10, cx + 2, 11, eye, False)
    blush = shade((240, 120, 120), 1.0)
    if look % 2:
        cv.set(cx - 5, 12, blush)
        cv.set(cx + 4, 12, blush)
    if cheering:
        cv.rect(cx - 1, 12, cx, 13, (176, 48, 56), False)
        # Arms thrown up either side of the head (drawn last so the head can't hide them).
        cv.rect(cx - 7, 14, cx - 5, 15, top)
        cv.rect(cx + 4, 14, cx + 6, 15, top)
        cv.rect(cx - 9, 4, cx - 8, 15, top)
        cv.rect(cx + 7, 4, cx + 8, 15, top)
        cv.rect(cx - 9, 2, cx - 8, 3, skin, False)
        cv.rect(cx + 7, 2, cx + 8, 3, skin, False)
    return cv.image()


def main():
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    rows = []
    for look in range(LOOKS):
        rows.append((trainer(look, False), trainer(look, True), 0))
    for path in sorted(glob.glob(os.path.join(FAN, "*.png"))):
        fig = Image.open(path).convert("RGBA")
        if fig.width > CELL[0] or fig.height > CELL[1] - 2:
            fig = fig.crop((0, 0, min(fig.width, CELL[0]), min(fig.height, CELL[1] - 2)))
        rows.append((fig, fig, 2))  # Cheering = a 2-pixel hop.
    img = Image.new("RGBA", (CELL[0] * 2, CELL[1] * len(rows)), (0, 0, 0, 0))
    for r, (idle, cheer, hop) in enumerate(rows):
        for f, fig in enumerate((idle, cheer)):
            x = f * CELL[0] + (CELL[0] - fig.width) // 2
            y = r * CELL[1] + CELL[1] - fig.height - (hop if f == 1 else 0)
            img.paste(fig, (x, y), fig)
    img.save(OUT)
    print("%d looks" % len(rows))
    print("saved", OUT)


if __name__ == "__main__":
    main()
