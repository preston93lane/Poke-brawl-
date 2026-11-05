"""Draws the walking trainers for the town (your trainer, wandering trainers and the
people working in each building) as crisp pixel art in the style of the Pokémon
sprites: a big round head, three flat tones per part (light, base, shadow),
dark outlines round the figure and between parts, and a proper walk.

    python3 tools/make_trainer_sheets.py   ->   assets/trainers/<style>.png

Each sheet is 3 rows (facing down, up, right; the game flips right for left) of
6 frames, CELL pixels each: 2 idle (breathing) then 4 walking (left foot down,
passing, right foot down, passing). Arms swing against the legs and the body
bobs up on the passing steps.

The pixels don't hold final colours: red says which part they belong to (PARTS)
and green how lit they are (100 = the plain colour), so
scripts/data/trainer_look.gd can paint any outfit from data/town.json.
"""
import os
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "trainers")
W, H = 32, 40
PARTS = ["skin", "hair", "hat", "top", "trim", "legs", "shoes", "eye", "mouth", "white", "blush"]
STYLES = ["cap", "short", "spiky", "long", "pigtails", "bun", "beanie", "cap_back", "nurse", "elder"]
LIGHT, BASE, SHADE = 1.2, 1.0, 0.72
OUTLINE = 0.22   # Silhouette outline: a very dark shade of the part it wraps.
CONTOUR = 0.55   # Lines where a part in front meets one behind.
# frame: (body bob, left leg, right leg, arm swing) for the walk; idle frames breathe.
FRAMES = [
    {"bob": 0, "step": 0, "breath": 0},
    {"bob": 0, "step": 0, "breath": 1},
    {"bob": 0, "step": 1, "breath": 0},   # Left foot forward.
    {"bob": -1, "step": 0, "breath": 0},  # Passing, body up.
    {"bob": 0, "step": -1, "breath": 0},  # Right foot forward.
    {"bob": -1, "step": 0, "breath": 0},
]


class Canvas:
    def __init__(self):
        self.px = {}   # (x, y) -> (part, shade, layer)
        self.layer = 0

    def set(self, x, y, part, k=BASE):
        x, y = int(x), int(y)
        if 0 <= x < W and 0 <= y < H:
            self.px[(x, y)] = (part, k, self.layer)

    def next_layer(self):
        self.layer += 1

    def rect(self, x0, y0, x1, y1, part, lit=True):
        """Filled box with a light top/left edge and a shaded bottom/right."""
        for y in range(int(y0), int(y1) + 1):
            for x in range(int(x0), int(x1) + 1):
                k = BASE
                if lit:
                    if x == int(x1) or y == int(y1):
                        k = SHADE
                    elif x == int(x0) or y == int(y0):
                        k = LIGHT
                self.set(x, y, part, k)
        self.next_layer()

    def ellipse(self, cx, cy, rx, ry, part, lit=True):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
                d = dx * dx + dy * dy
                if d > 1.0:
                    continue
                k = BASE
                if lit:
                    light = -0.6 * dx - 0.8 * dy
                    if light > 0.55 and d < 0.8:
                        k = LIGHT
                    elif light < -0.35 or d > 0.82 and (dx > 0.25 or dy > 0.4):
                        k = SHADE
                self.set(x, y, part, k)
        self.next_layer()

    def encode(self):
        img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        # Contours: a pixel next to a part drawn in front of it darkens.
        shades = {}
        for (x, y), (part, k, layer) in self.px.items():
            dark = False
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = self.px.get((x + dx, y + dy))
                if n and n[0] != part and n[2] > layer and part not in ("eye", "mouth", "blush") and n[0] not in ("eye", "mouth", "blush", "white"):
                    dark = True
            shades[(x, y)] = CONTOUR if dark else k
        for (x, y), (part, k, layer) in self.px.items():
            img.putpixel((x, y), (PARTS.index(part) * 20, min(255, int(shades[(x, y)] * 100)), 0, 255))
        # Silhouette outline.
        out = img.copy()
        for y in range(H):
            for x in range(W):
                if img.getpixel((x, y))[3]:
                    continue
                for dx, dy in ((0, 1), (1, 0), (-1, 0), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < W and 0 <= ny < H and img.getpixel((nx, ny))[3]:
                        r = img.getpixel((nx, ny))[0]
                        out.putpixel((x, y), (r, int(OUTLINE * 100), 0, 255))
                        break
        return out


def legs_front(cv, cx, f, skirt):
    """Front/back view: feet step down in turn (the forward one is lower on screen)."""
    left = 1 if f["step"] == 1 else (-1 if f["step"] == -1 else 0)
    right = -left
    base = 33 + f["bob"]
    if skirt:
        cv.rect(cx - 6, 27 + f["bob"], cx + 5, 30 + f["bob"], "trim")
    for side, shift in ((-1, left), (1, right)):
        x0 = cx - 5 if side < 0 else cx + 1
        y1 = base + shift  # Forward foot a pixel lower, back foot lifted.
        cv.rect(x0, 29 + f["bob"] if not skirt else 31 + f["bob"], x0 + 3, y1, "skin" if skirt else "legs")
        cv.rect(x0 - (1 if side < 0 else 0), y1 + 1, x0 + 3 + (1 if side > 0 else 0), y1 + 2, "shoes")
        cv.rect(x0 - (1 if side < 0 else 0), y1 + 3, x0 + 3 + (1 if side > 0 else 0), y1 + 3, "white", False)  # Sole.


def legs_side(cv, cx, f, skirt):
    """Side view: the legs stride apart on the steps, together when passing."""
    stride = 3 if f["step"] != 0 else 0
    top = 29 + f["bob"]
    if skirt:
        cv.rect(cx - 5, 27 + f["bob"], cx + 4, 30 + f["bob"], "trim")
    for i, off in enumerate((-stride, stride) if f["step"] == 1 else (stride, -stride)):
        x0 = cx - 2 + off
        cv.rect(x0, top if not skirt else top + 2, x0 + 3, 35 + f["bob"], "skin" if skirt else "legs", i == 1)
        if i == 0:  # The far leg sits in shadow.
            for y in range(top if not skirt else top + 2, 36 + f["bob"]):
                for x in range(x0, x0 + 4):
                    if (x, y) in cv.px:
                        part, k, layer = cv.px[(x, y)]
                        cv.px[(x, y)] = (part, SHADE, layer)
        cv.rect(x0, 36 + f["bob"], x0 + 4, 37 + f["bob"], "shoes")
        cv.rect(x0, 38 + f["bob"], x0 + 4, 38 + f["bob"], "white", False)


def body(cv, cx, facing, f, style):
    b = f["bob"]
    breath = f["breath"]
    top = 19 + b + breath
    swing = 2 if f["step"] == 1 else (-2 if f["step"] == -1 else 0)
    if facing == "right":
        # Back arm (behind the body) swings opposite the front one.
        cv.rect(cx - 1 - swing, top + 1, cx + 1 - swing, top + 6, "top")
        cv.rect(cx - 1 - swing, top + 7, cx + 1 - swing, top + 8, "skin", False)
        cv.rect(cx - 5, top, cx + 4, 29 + b, "top")
        cv.rect(cx + 3, top + 1, cx + 4, 29 + b, "trim", False)  # Jacket opening.
        cv.rect(cx - 1 + swing, top + 1, cx + 1 + swing, top + 6, "top")
        cv.rect(cx - 1 + swing, top + 7, cx + 1 + swing, top + 8, "skin")
        return
    cv.rect(cx - 6, top, cx + 5, 29 + b, "top")
    if facing == "down":
        cv.rect(cx - 1, top + 1, cx, 29 + b, "trim", False)
        cv.rect(cx - 3, top, cx + 2, top, "white", False)  # Collar.
        if style == "nurse":
            cv.rect(cx - 5, top + 3, cx + 4, 29 + b, "white")  # Apron.
    else:
        cv.rect(cx - 5, top + 1, cx + 4, top + 1, "trim", False)  # Backpack strap / hood line.
    # Arms: in front/back views a swinging arm drops (forward) or rises (back) a little.
    for side, s in ((-1, swing), (1, -swing)):
        x0 = cx - 8 if side < 0 else cx + 6
        lift = 0 if s == 0 else (2 if s > 0 else -1)
        cv.rect(x0, top + 1 + max(0, -lift), x0 + 1, top + 7 + lift, "top")
        cv.rect(x0, top + 8 + lift, x0 + 1, top + 9 + lift, "skin", False)


def hair_back(cv, hx, hy, facing, style):
    if style == "long":
        if facing == "down":
            cv.rect(hx - 8, hy - 2, hx + 7, hy + 10, "hair")
        elif facing == "right":
            cv.rect(hx - 8, hy - 2, hx - 1, hy + 10, "hair")
    if style in ("pigtails", "nurse"):
        spots = [(-9.5, hy + 4), (8.5, hy + 4)] if facing in ("down", "up") else [(-8.5, hy + 4)]
        for (ox, oy) in spots:
            cv.ellipse(hx + ox, oy, 2.6, 3.8 if style == "pigtails" else 3.0, "hair")
    if style == "bun":
        cv.ellipse(hx - (4 if facing == "right" else 0), hy - 8.5, 3.6, 3.0, "hair")


def head(cv, hx, hy, facing, style):
    cv.ellipse(hx, hy, 8.5, 7.8, "skin")
    if facing == "up":
        # From behind the hair covers the head (a hat sits on top of it).
        cv.ellipse(hx, hy + (1.5 if style in ("cap", "cap_back", "beanie") else 0), 8.3, 7.2 if style not in ("cap", "cap_back", "beanie") else 5.6, "hair")
        if style == "long":
            cv.rect(hx - 8, hy, hx + 7, hy + 7, "hair")
    # Hat or hair on top.
    if style in ("cap", "cap_back"):
        cv.ellipse(hx, hy - 3.5, 8.8, 5.2, "hat")
        cv.rect(hx - 8, hy - 3, hx + 8, hy - 2, "hat")
        if facing == "down":
            if style == "cap":
                cv.rect(hx - 8, hy - 1, hx + 7, hy, "trim", False)
            cv.rect(hx - 2, hy - 7, hx + 1, hy - 5, "white", False)  # Badge.
            cv.rect(hx - 8, hy - 1 if style != "cap" else hy + 1, hx - 7, hy + 2, "hair")
            cv.rect(hx + 6, hy - 1 if style != "cap" else hy + 1, hx + 7, hy + 2, "hair")
        elif facing == "right":
            if style == "cap":
                cv.rect(hx + 4, hy - 2, hx + 10, hy - 1, "trim", False)
            else:
                cv.rect(hx - 11, hy - 3, hx - 5, hy - 2, "trim", False)
            cv.rect(hx - 7, hy - 1, hx - 4, hy + 3, "hair")
        else:
            if style == "cap_back":
                cv.rect(hx - 6, hy - 1, hx + 5, hy, "trim", False)
    elif style == "beanie":
        cv.ellipse(hx, hy - 4, 8.6, 5.0, "hat")
        cv.rect(hx - 8, hy - 2, hx + 8, hy - 1, "white")
        cv.ellipse(hx, hy - 9.5, 2.0, 1.6, "white")  # Pom-pom.
    elif style == "spiky":
        cv.ellipse(hx, hy - 4, 8.8, 5.0, "hair")
        for sx in (-8, -4, 0, 4, 8):
            cv.rect(hx + sx - 1, hy - 10 + abs(sx) // 3, hx + sx + 1, hy - 7, "hair")
    elif style == "elder":
        cv.ellipse(hx, hy - 5.5, 6.5, 2.4, "hair")
        if facing != "up":
            cv.rect(hx - 8, hy - 2, hx - 7, hy + 3, "hair")
            if facing == "down":
                cv.rect(hx + 6, hy - 2, hx + 7, hy + 3, "hair")
    elif facing != "up":
        cv.ellipse(hx, hy - 4, 8.8, 5.0, "hair")
        if facing == "down":
            cv.rect(hx - 6, hy - 2, hx - 2, hy - 1, "hair")  # Fringe.
            cv.rect(hx + 2, hy - 2, hx + 5, hy - 1, "hair")
        if style in ("long", "pigtails", "bun", "nurse"):
            cv.rect(hx - 8, hy - 2, hx - 7, hy + 4, "hair")
            if facing == "down":
                cv.rect(hx + 6, hy - 2, hx + 7, hy + 4, "hair")
        if facing == "right":
            cv.rect(hx - 8, hy - 2, hx - 4, hy + 3, "hair")  # Back of the head.
    if style == "nurse":
        cv.rect(hx - 4, hy - 10, hx + 3, hy - 7, "white")  # Nurse's cap...
        cv.rect(hx - 1, hy - 9, hx, hy - 8, "mouth", False)  # ...with its red cross.
    if facing == "up":
        return
    # Face: big dark eyes with a white glint, blush, a little mouth.
    if facing == "down":
        for ex in (hx - 4, hx + 3):
            cv.rect(ex, hy + 1, ex + 1, hy + 3, "eye", False)
            cv.set(ex, hy + 1, "white")
        cv.set(hx - 6, hy + 4, "blush")
        cv.set(hx + 5, hy + 4, "blush")
        cv.rect(hx - 1, hy + 5, hx, hy + 5, "mouth", False)
    else:
        cv.rect(hx + 4, hy + 1, hx + 5, hy + 3, "eye", False)
        cv.set(hx + 5, hy + 1, "white")
        cv.set(hx + 6, hy + 4, "blush")
        cv.set(hx + 7, hy + 5, "mouth")
    cv.next_layer()


def trainer(style, facing, f):
    cv = Canvas()
    cx = 16
    skirt = style in ("long", "pigtails", "bun", "nurse")
    hx = cx + (1 if facing == "right" else 0)
    hy = 11 + f["bob"] + f["breath"]
    hair_back(cv, hx, hy, facing, style) if facing == "up" else None
    if facing == "right":
        legs_side(cv, cx, f, skirt)
    else:
        legs_front(cv, cx, f, skirt)
    body(cv, cx, facing, f, style)
    if facing != "up":
        hair_back(cv, hx, hy, facing, style)
    head(cv, hx, hy, facing, style)
    return cv.encode()


def main():
    os.makedirs(OUT, exist_ok=True)
    for style in STYLES:
        sheet = Image.new("RGBA", (W * len(FRAMES), H * 3), (0, 0, 0, 0))
        for row, facing in enumerate(["down", "up", "right"]):
            for col, f in enumerate(FRAMES):
                sheet.paste(trainer(style, facing, f), (col * W, row * H))
        sheet.save(os.path.join(OUT, style + ".png"))
    print("saved %d sheets (%dx%d frames) to %s" % (len(STYLES), W, H, OUT))


if __name__ == "__main__":
    main()
