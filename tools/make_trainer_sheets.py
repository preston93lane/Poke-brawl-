"""Draws the walking trainers for the town (your trainer, wandering trainers and the
people working in each building), in the same handheld overworld style as the
stadium crowd (tools/make_crowd.py): big round head, bold hair or hat, short body,
light from the top left, outlines in a darker shade rather than black.

    python3 tools/make_trainer_sheets.py   ->   assets/trainers/<style>.png

Each sheet is 3 rows (facing down, up, right; the game flips right for left) of 3
frames (standing, left foot, right foot), CELL pixels each. The pixels don't hold
final colours: red says which part they belong to (PARTS) and green how lit they
are (100 = the plain colour), so scripts/data/trainer_look.gd can paint any outfit
from data/town.json in the game.
"""
import os
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "trainers")
W, H = 24, 32
PARTS = ["skin", "hair", "hat", "top", "trim", "legs", "shoes", "eye", "mouth", "white", "blush"]
STYLES = ["cap", "short", "spiky", "long", "pigtails", "bun", "beanie", "cap_back", "nurse", "elder"]


class Canvas:
    def __init__(self):
        self.px = {}

    def set(self, x, y, part, k=1.0):
        if 0 <= x < W and 0 <= y < H:
            self.px[(x, y)] = (part, k)

    def rect(self, x0, y0, x1, y1, part, lit=True):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                k = 1.0
                if lit and (y == y0 or x == x0):
                    k = 1.15
                if lit and (y == y1 or x == x1):
                    k = 0.78
                self.set(x, y, part, k)

    def ellipse(self, cx, cy, rx, ry, part, lit=True):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
                d = dx * dx + dy * dy
                if d <= 1.0:
                    k = 1.0
                    if lit:
                        k = 1.0 + 0.16 * (-0.55 * dx - 0.7 * dy)
                        if d > 0.72 and (dx > 0.2 or dy > 0.3):
                            k *= 0.82
                    self.set(x, y, part, k)

    def encode(self):
        img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        for (x, y), (part, k) in self.px.items():
            img.putpixel((x, y), (PARTS.index(part) * 20, min(255, int(k * 100)), 0, 255))
        # Outline: empty pixels touching the figure take a dark shade of that neighbour.
        out = img.copy()
        for y in range(H):
            for x in range(W):
                if img.getpixel((x, y))[3]:
                    continue
                for dx, dy in ((0, 1), (1, 0), (-1, 0), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < W and 0 <= ny < H and img.getpixel((nx, ny))[3]:
                        r, g, _, _ = img.getpixel((nx, ny))
                        out.putpixel((x, y), (r, int(g * 0.32), 0, 255))
                        break
        return out


def legs(cv, cx, facing, frame, skirt):
    """Legs and shoes; frame 1 / 2 step one foot forward (down) or apart (side)."""
    lift = [0, 0, 0]
    if facing in ("down", "up"):
        left_y = 25 - (1 if frame == 1 else 0)
        right_y = 25 - (1 if frame == 2 else 0)
        if skirt:
            cv.rect(cx - 5, 21, cx + 4, 23, "trim")
            cv.rect(cx - 3, 24, cx - 2, left_y + 1, "skin", False)
            cv.rect(cx + 1, 24, cx + 2, right_y + 1, "skin", False)
        else:
            cv.rect(cx - 4, 21, cx - 1, left_y + 1, "legs")
            cv.rect(cx, 21, cx + 3, right_y + 1, "legs")
        cv.rect(cx - 5, left_y + 2, cx - 1, left_y + 3, "shoes")
        cv.rect(cx, right_y + 2, cx + 4, right_y + 3, "shoes")
    else:
        spread = [0, 3, -3][frame]
        if skirt:
            cv.rect(cx - 4, 21, cx + 3, 23, "trim")
        back, front = cx - 1 - spread // 2, cx - 1 + spread // 2
        for lx in (back, front):
            cv.rect(lx, 21 if not skirt else 24, lx + 2, 26, "skin" if skirt else "legs")
            cv.rect(lx, 27, lx + 3, 28, "shoes")
    return lift


def trainer(style, facing, frame):
    cv = Canvas()
    cx = 12
    bob = 1 if frame else 0  # A little dip on each step.
    skirt = style in ("long", "pigtails", "bun", "nurse")
    legs(cv, cx, facing, frame, skirt)
    top = 15 + bob
    # Hair hanging behind the body (seen from behind it covers the back).
    if style in ("long", "pigtails", "nurse") and facing == "up":
        cv.rect(cx - 6, 8 + bob, cx + 5, 18 + bob if style == "long" else 14 + bob, "hair")
    # Body: a jacket with the shirt showing down the front.
    if facing == "right":
        cv.rect(cx - 4, top, cx + 3, 21, "top")
        swing = [0, 2, -2][frame]
        cv.rect(cx - 1 + swing, top + 1, cx + 1 + swing, top + 5, "top")  # Arm swinging.
        cv.rect(cx - 1 + swing, top + 6, cx + 1 + swing, top + 6, "skin", False)
    else:
        cv.rect(cx - 5, top, cx + 4, 21, "top")
        if facing == "down":
            cv.rect(cx - 1, top + 1, cx, 20, "trim", False)
        if style == "nurse" and facing == "down":
            cv.rect(cx - 4, top + 3, cx + 3, 21, "white", False)  # Apron.
        swing = [0, 1, -1][frame]
        cv.rect(cx - 7, top + 1 + swing, cx - 6, top + 5 + swing, "top")
        cv.rect(cx + 5, top + 1 - swing, cx + 6, top + 5 - swing, "top")
        cv.rect(cx - 7, top + 6 + swing, cx - 6, top + 6 + swing, "skin", False)
        cv.rect(cx + 5, top + 6 - swing, cx + 6, top + 6 - swing, "skin", False)
    hy = 9 + bob
    hx = cx + (1 if facing == "right" else 0)
    # Hair behind the head (front and side views).
    if facing != "up":
        if style == "long":
            cv.rect(hx - 6, hy - 2, hx + (5 if facing == "down" else -1), hy + 8, "hair")
        if style in ("pigtails", "nurse"):
            side = [(-7.5, hy + 3), (6.5, hy + 3)] if facing == "down" else [(-6.5, hy + 3)]
            for (ox, oy) in side:
                cv.ellipse(hx + ox, oy, 2.2, 3.2 if style == "pigtails" else 2.6, "hair")
    if style == "bun":
        cv.ellipse(hx - (3 if facing == "right" else 0), hy - 6.5, 3, 2.5, "hair")
    # Head.
    cv.ellipse(hx, hy, 6.5, 6, "skin")
    # Hair or hat on top.
    if style in ("cap", "cap_back"):
        cv.ellipse(hx, hy - 2.5, 6.8, 4.2, "hat")
        cv.rect(hx - 6, hy - 2, hx + 6, hy - 1, "hat")
        if facing == "down":
            if style == "cap":
                cv.rect(hx - 6, hy - 1, hx + 5, hy, "trim", False)  # Brim towards you.
            cv.rect(hx - 1, hy - 5, hx + 1, hy - 4, "white", False)
        elif facing == "right":
            if style == "cap":
                cv.rect(hx + 3, hy - 1, hx + 8, hy, "trim", False)
            else:
                cv.rect(hx - 9, hy - 2, hx - 4, hy - 1, "trim", False)
        else:
            if style == "cap_back":
                cv.rect(hx - 5, hy - 1, hx + 5, hy, "trim", False)
        cv.rect(hx - 6, hy - 1, hx - 5, hy + 1, "hair")
        cv.rect(hx + 4, hy - 1, hx + 5, hy + 1, "hair")
    elif style == "beanie":
        cv.ellipse(hx, hy - 3, 6.5, 4, "hat")
        cv.rect(hx - 6, hy - 1, hx + 6, hy, "white")
    elif style == "spiky":
        cv.ellipse(hx, hy - 3, 6.8, 4, "hair")
        for sx in (-6, -3, 0, 3, 6):
            cv.rect(hx + sx - 1, hy - 8 + abs(sx) // 3, hx + sx, hy - 6, "hair", False)
    elif style == "elder":
        cv.ellipse(hx, hy - 4, 5.5, 2.2, "hair")  # Thin grey hair.
        cv.rect(hx - 6, hy - 2, hx - 5, hy + 2, "hair")
        cv.rect(hx + 4, hy - 2, hx + 5, hy + 2, "hair")
    else:
        cv.ellipse(hx, hy - 3, 6.8, 4, "hair")
        if style in ("long", "pigtails", "bun", "nurse") and facing != "up":
            cv.rect(hx - 6, hy - 2, hx - 5, hy + 3, "hair")
            if facing == "down":
                cv.rect(hx + 4, hy - 2, hx + 5, hy + 3, "hair")
        if style == "nurse":
            cv.rect(hx - 3, hy - 7, hx + 3, hy - 5, "white")  # Nurse's cap.
            cv.rect(hx - 1, hy - 7, hx, hy - 6, "mouth", False)  # Its little red cross.
    if facing == "up":
        # From behind: the hair (or hat) covers the head.
        if style not in ("cap", "cap_back", "beanie"):
            cv.ellipse(hx, hy, 6.4, 5.6, "hair")
        else:
            cv.ellipse(hx, hy + 1.5, 6.2, 4, "hair")
        return cv.encode()
    # Face.
    if facing == "down":
        cv.rect(hx - 3, hy + 1, hx - 3, hy + 2, "eye", False)
        cv.rect(hx + 2, hy + 1, hx + 2, hy + 2, "eye", False)
        cv.set(hx - 5, hy + 3, "blush")
        cv.set(hx + 4, hy + 3, "blush")
        cv.rect(hx - 1, hy + 4, hx, hy + 4, "mouth", False)
    else:
        cv.rect(hx + 3, hy + 1, hx + 3, hy + 2, "eye", False)
        cv.set(hx + 4, hy + 3, "blush")
        cv.set(hx + 5, hy + 4, "mouth")
        # Hair at the back of the head, seen from the side.
        if style not in ("cap", "cap_back", "beanie", "elder"):
            cv.rect(hx - 6, hy - 2, hx - 3, hy + 3, "hair")
    return cv.encode()


def main():
    os.makedirs(OUT, exist_ok=True)
    for style in STYLES:
        sheet = Image.new("RGBA", (W * 3, H * 3), (0, 0, 0, 0))
        for row, facing in enumerate(["down", "up", "right"]):
            for frame in range(3):
                sheet.paste(trainer(style, facing, frame), (frame * W, row * H))
        sheet.save(os.path.join(OUT, style + ".png"))
    print("saved %d sheets to %s" % (len(STYLES), OUT))


if __name__ == "__main__":
    main()
