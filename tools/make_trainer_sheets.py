"""Draws the town trainers as layers that stack into one figure: the head, hair,
a hat, a top, bottoms and shoes, each as its own sheet, in the style of the
Pokémon sprites (big round head, three flat tones per part). The game picks one
of each (scripts/data/trainer_look.gd), paints them and adds the dark outlines
round the figure and between layers, so any hat goes with any top, in any colour.

    python3 tools/make_trainer_sheets.py   ->   assets/trainers/<layer>.png

Every sheet is 3 rows (facing down, up, right; the game flips right for left) of
6 frames, CELL pixels each: 2 idle (breathing) then 4 walking (left foot down,
passing, right foot down, passing). Arms swing against the legs and the body
bobs up on the passing steps.

Pixels don't hold colours: red says which part they are (PARTS), green how lit
(100 = the plain colour). "main" is the item's colour, "trim" a lighter shade of
it; skin and hair come from the outfit; the rest are fixed colours.
Stacking order (back to front): hairback, bottom, shoes, top, head, hair, hat.
"""
import os
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "trainers")
W, H = 32, 40
PARTS = ["skin", "hair", "main", "trim", "dark", "white", "red", "eye", "mouth", "blush", "gold"]
LIGHT, BASE, SHADE = 1.2, 1.0, 0.72
FRAMES = [
    {"bob": 0, "step": 0, "breath": 0},
    {"bob": 0, "step": 0, "breath": 1},
    {"bob": 0, "step": 1, "breath": 0},
    {"bob": -1, "step": 0, "breath": 0},
    {"bob": 0, "step": -1, "breath": 0},
    {"bob": -1, "step": 0, "breath": 0},
]
FACINGS = ["down", "up", "right"]
CX = 16

HAIRS = ["short", "spiky", "long", "pigtails", "bun", "buzz", "elder"]
HATS = ["cap", "cap_back", "beanie", "sun_hat", "straw_hat", "headband", "hood", "bandana", "swim_cap", "rocket_cap", "nurse_cap"]
TOPS = ["jacket", "tshirt", "tank", "vest", "gi", "robe", "blouse", "striped", "leather", "cape", "coat", "rocket", "nurse"]
BOTTOMS = ["trousers", "shorts", "skirt", "long_skirt", "gi_pants", "cargo"]
SHOES = ["sneakers", "boots", "sandals"]
# Hats that cover the top of the head: hair under them is drawn without its top.
COVERING = {"cap", "cap_back", "beanie", "sun_hat", "straw_hat", "hood", "swim_cap", "rocket_cap", "bandana"}


class Canvas:
    def __init__(self):
        self.px = {}

    def set(self, x, y, part, k=BASE):
        x, y = int(x), int(y)
        if 0 <= x < W and 0 <= y < H:
            self.px[(x, y)] = (part, k)

    def erase(self, x, y):
        self.px.pop((int(x), int(y)), None)

    def rect(self, x0, y0, x1, y1, part, lit=True):
        for y in range(int(y0), int(y1) + 1):
            for x in range(int(x0), int(x1) + 1):
                k = BASE
                if lit:
                    if x == int(x1) or y == int(y1):
                        k = SHADE
                    elif x == int(x0) or y == int(y0):
                        k = LIGHT
                self.set(x, y, part, k)

    def ellipse(self, cx, cy, rx, ry, part, lit=True, keep=None):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
                d = dx * dx + dy * dy
                if d > 1.0 or (keep and not keep(x, y)):
                    continue
                k = BASE
                if lit:
                    light = -0.6 * dx - 0.8 * dy
                    if light > 0.55 and d < 0.8:
                        k = LIGHT
                    elif light < -0.35 or d > 0.82 and (dx > 0.25 or dy > 0.4):
                        k = SHADE
                self.set(x, y, part, k)

    def image(self):
        img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        for (x, y), (part, k) in self.px.items():
            img.putpixel((x, y), (PARTS.index(part) * 20, min(255, int(k * 100)), 0, 255))
        return img


def head_pos(facing, f):
    return CX + (1 if facing == "right" else 0), 11 + f["bob"] + f["breath"]


def top_y(f):
    return 19 + f["bob"] + f["breath"]


def swing(f):
    return 2 if f["step"] == 1 else (-2 if f["step"] == -1 else 0)


# --- Head ------------------------------------------------------------------------

def head(cv, facing, f):
    hx, hy = head_pos(facing, f)
    cv.ellipse(hx, hy, 8.5, 7.8, "skin")
    if facing == "down":
        for ex in (hx - 4, hx + 3):
            cv.rect(ex, hy + 1, ex + 1, hy + 3, "eye", False)
            cv.set(ex, hy + 1, "white")
        cv.set(hx - 6, hy + 4, "blush")
        cv.set(hx + 5, hy + 4, "blush")
        cv.rect(hx - 1, hy + 5, hx, hy + 5, "mouth", False)
    elif facing == "right":
        cv.rect(hx + 4, hy + 1, hx + 5, hy + 3, "eye", False)
        cv.set(hx + 5, hy + 1, "white")
        cv.set(hx + 6, hy + 4, "blush")
        cv.set(hx + 7, hy + 5, "mouth")


# --- Hair --------------------------------------------------------------------------

def hairback(cv, style, facing, f):
    """Hair hanging behind the body (front and side views only)."""
    hx, hy = head_pos(facing, f)
    if facing == "up":
        return
    if style == "long":
        if facing == "down":
            cv.rect(hx - 8, hy - 2, hx + 7, hy + 10, "hair")
        else:
            cv.rect(hx - 8, hy - 2, hx - 1, hy + 10, "hair")
    if style == "pigtails":
        for ox in ((-9.5, 8.5) if facing == "down" else (-8.5,)):
            cv.ellipse(hx + ox, hy + 4, 2.6, 3.8, "hair")
    if style == "bun" and facing == "right":
        cv.ellipse(hx - 4, hy - 8.5, 3.6, 3.0, "hair")


def hair(cv, style, facing, f, under):
    """Hair on the head; `under` leaves off the top (a hat covers it)."""
    hx, hy = head_pos(facing, f)
    keep = (lambda x, y: y >= hy - 2) if under else None
    if facing == "up":
        cv.ellipse(hx, hy, 8.3, 7.2, "hair", keep=keep)
        if style == "long":
            cv.rect(hx - 8, hy, hx + 7, hy + 7, "hair")
        if style == "pigtails":
            for ox in (-9.5, 8.5):
                cv.ellipse(hx + ox, hy + 4, 2.6, 3.8, "hair")
        if style == "bun" and not under:
            cv.ellipse(hx, hy - 8.5, 3.6, 3.0, "hair")
        if style == "elder":
            cv.px = {p: v for p, v in cv.px.items() if p[1] >= hy - 1}  # Thin on top.
        return
    if style == "elder":
        if not under:
            cv.ellipse(hx, hy - 5.5, 6.5, 2.4, "hair")
        cv.rect(hx - 8, hy - 2, hx - 7, hy + 3, "hair")
        if facing == "down":
            cv.rect(hx + 6, hy - 2, hx + 7, hy + 3, "hair")
        return
    if style == "buzz":
        cv.ellipse(hx, hy - 3.5, 8.6, 4.4, "hair", keep=keep)
    elif style == "spiky" and not under:
        cv.ellipse(hx, hy - 4, 8.8, 5.0, "hair")
        for sx in (-8, -4, 0, 4, 8):
            cv.rect(hx + sx - 1, hy - 10 + abs(sx) // 3, hx + sx + 1, hy - 7, "hair")
    else:
        cv.ellipse(hx, hy - 4, 8.8, 5.0, "hair", keep=keep)
        if style == "bun" and facing == "down" and not under:
            cv.ellipse(hx, hy - 8.5, 3.6, 3.0, "hair")
    if facing == "down" and style != "buzz":
        cv.rect(hx - 6, hy - 2, hx - 2, hy - 1, "hair")  # Fringe.
        cv.rect(hx + 2, hy - 2, hx + 5, hy - 1, "hair")
    if style in ("long", "pigtails", "bun"):
        cv.rect(hx - 8, hy - 2, hx - 7, hy + 4, "hair")
        if facing == "down":
            cv.rect(hx + 6, hy - 2, hx + 7, hy + 4, "hair")
    if facing == "right":
        cv.rect(hx - 8, hy - 2, hx - 4, hy + 3, "hair")
    if facing == "down" and style == "pigtails":
        for ox in (-9.5, 8.5):
            cv.ellipse(hx + ox, hy + 4, 2.6, 3.8, "hair")


# --- Hats --------------------------------------------------------------------------

def hat(cv, kind, facing, f):
    hx, hy = head_pos(facing, f)
    if kind in ("cap", "cap_back", "rocket_cap"):
        cv.ellipse(hx, hy - 3.5, 8.8, 5.2, "main")
        cv.rect(hx - 8, hy - 3, hx + 8, hy - 2, "main")
        back = kind == "cap_back"
        if facing == "down":
            if not back:
                cv.rect(hx - 8, hy - 1, hx + 7, hy, "trim", False)
            if kind == "rocket_cap":
                cv.rect(hx - 2, hy - 8, hx + 1, hy - 4, "white", False)
                for (x, y) in [(hx - 1, hy - 7), (hx - 1, hy - 6), (hx - 1, hy - 5), (hx, hy - 7), (hx, hy - 6), (hx, hy - 4)]:
                    cv.set(x, y, "red")  # The big red R.
            else:
                cv.rect(hx - 2, hy - 7, hx + 1, hy - 5, "white", False)
        elif facing == "right":
            if back:
                cv.rect(hx - 11, hy - 3, hx - 5, hy - 2, "trim", False)
            else:
                cv.rect(hx + 4, hy - 2, hx + 10, hy - 1, "trim", False)
        elif back:
            cv.rect(hx - 6, hy - 1, hx + 5, hy, "trim", False)
    elif kind == "beanie":
        cv.ellipse(hx, hy - 4, 8.6, 5.0, "main")
        cv.rect(hx - 8, hy - 2, hx + 8, hy - 1, "trim")
        cv.ellipse(hx, hy - 9.5, 2.0, 1.6, "white")
    elif kind == "sun_hat":
        cv.ellipse(hx, hy - 2.5, 12.0, 2.6, "main")  # Wide brim.
        cv.ellipse(hx, hy - 5.5, 7.0, 4.0, "main")
        cv.rect(hx - 7, hy - 4, hx + 7, hy - 3, "trim", False)  # Ribbon.
    elif kind == "straw_hat":
        cv.ellipse(hx, hy - 2.5, 11.0, 2.4, "gold")
        cv.ellipse(hx, hy - 5.5, 7.0, 4.0, "gold")
        cv.rect(hx - 7, hy - 4, hx + 7, hy - 3, "main", False)
    elif kind == "headband":
        cv.rect(hx - 8, hy - 4, hx + 8, hy - 2, "main")
        if facing == "right":
            cv.rect(hx - 12, hy - 3, hx - 8, hy - 2, "main")  # Tails flying back.
            cv.rect(hx - 13, hy - 1, hx - 10, hy, "main")
        elif facing == "up":
            cv.rect(hx - 1, hy - 2, hx, hy + 3, "main")  # Knot tails.
    elif kind == "hood":
        cv.ellipse(hx, hy - 0.5, 9.8, 9.0, "main", keep=(lambda x, y: True) if facing == "up" else None)
        if facing == "down":
            for y in range(int(hy - 3), int(hy + 7)):
                for x in range(int(hx - 6), int(hx + 6)):
                    cv.erase(x, y)  # Face opening.
        elif facing == "right":
            for y in range(int(hy - 3), int(hy + 7)):
                for x in range(int(hx + 1), int(hx + 10)):
                    cv.erase(x, y)
    elif kind == "bandana":
        cv.ellipse(hx, hy - 3.5, 8.8, 5.0, "main", keep=lambda x, y: y < hy - 1)
        cv.rect(hx - 8, hy - 2, hx + 8, hy - 2, "trim", False)
        if facing in ("up", "right"):
            cv.rect(hx - 10, hy - 2, hx - 7, hy + 1, "main")  # The knot.
    elif kind == "swim_cap":
        cv.ellipse(hx, hy - 2.5, 8.7, 6.0, "main", keep=lambda x, y: y < hy)
        if facing == "down":
            cv.rect(hx - 6, hy - 1, hx - 2, hy, "trim")  # Goggles.
            cv.rect(hx + 1, hy - 1, hx + 5, hy, "trim")
    elif kind == "nurse_cap":
        cv.rect(hx - 4, hy - 10, hx + 3, hy - 7, "white")
        cv.rect(hx - 1, hy - 9, hx, hy - 8, "red", False)


# --- Tops --------------------------------------------------------------------------

def top(cv, kind, facing, f):
    t = top_y(f)
    b = f["bob"]
    s = swing(f)
    bottom = 29 + b
    sleeves = {"tshirt": "short", "tank": "none", "vest": "short", "gi": "long", "robe": "long", "blouse": "puff",
               "striped": "long", "leather": "long", "cape": "long", "coat": "long", "rocket": "long", "nurse": "short", "jacket": "long"}[kind]
    if kind in ("robe", "coat", "cape"):
        bottom = 32 + b  # Long hem over the legs.
    if kind == "nurse":
        bottom = 31 + b
    body_part = "white" if kind == "gi" else "main"
    arm_part = "skin" if sleeves == "none" else ("white" if kind == "gi" else "main")

    def arm(x0, y0, length, hand_y):
        if sleeves == "short":
            cv.rect(x0, y0, x0 + 1, y0 + 2, "main" if kind != "vest" else "trim")
            cv.rect(x0, y0 + 3, x0 + 1, y0 + length, "skin")
        elif sleeves == "puff":
            cv.rect(x0 - (1 if x0 < CX else 0), y0, x0 + 1 + (1 if x0 > CX else 0), y0 + 2, "white")
            cv.rect(x0, y0 + 3, x0 + 1, y0 + length, "skin")
        else:
            cv.rect(x0, y0, x0 + 1, y0 + length, arm_part)
        glove = "white" if kind == "rocket" else "skin"
        cv.rect(x0, hand_y, x0 + 1, hand_y + 1, glove, False)

    if facing == "right":
        # Back arm, body, front arm.
        if sleeves in ("short", "puff", "none"):
            cv.rect(CX - 1 - s, t + 1, CX + 1 - s, t + 6, "skin" if sleeves == "none" else ("white" if sleeves == "puff" else "main"))
        else:
            cv.rect(CX - 1 - s, t + 1, CX + 1 - s, t + 6, arm_part)
        cv.rect(CX - 1 - s, t + 7, CX + 1 - s, t + 8, "white" if kind == "rocket" else "skin", False)
        cv.rect(CX - 5, t, CX + 4, bottom, body_part)
        if kind in ("jacket", "coat", "leather", "vest"):
            cv.rect(CX + 3, t + 1, CX + 4, bottom, "trim", False)
        if kind == "striped":
            for y in range(t + 1, bottom, 2):
                cv.rect(CX - 5, y, CX + 4, y, "white", False)
        if kind == "gi":
            cv.rect(CX - 5, t + 7, CX + 4, t + 8, "dark", False)
        if kind == "cape":
            cv.rect(CX - 6, t - 1, CX - 4, bottom, "trim")
        if kind == "nurse":
            cv.rect(CX + 1, t + 3, CX + 4, bottom, "white")
        if kind == "rocket":
            cv.rect(CX + 1, t + 2, CX + 3, t + 5, "red", False)
        sl = "skin" if sleeves == "none" else ("main" if sleeves != "long" else arm_part)
        cv.rect(CX - 1 + s, t + 1, CX + 1 + s, t + 6, sl)
        cv.rect(CX - 1 + s, t + 7, CX + 1 + s, t + 8, "white" if kind == "rocket" else "skin")
        return
    cv.rect(CX - 6, t, CX + 5, bottom, body_part)
    front = facing == "down"
    if kind == "jacket" and front:
        cv.rect(CX - 1, t + 1, CX, bottom, "trim", False)
        cv.rect(CX - 3, t, CX + 2, t, "white", False)
    elif kind == "tshirt" and front:
        cv.rect(CX - 2, t, CX + 1, t, "trim", False)
    elif kind == "tank" and front:
        cv.rect(CX - 3, t, CX + 2, t + 1, "skin", False)
    elif kind == "vest":
        cv.rect(CX - 6, t, CX - 3 if front else CX + 5, bottom, "main")
        if front:
            cv.rect(CX + 2, t, CX + 5, bottom, "main")
            cv.rect(CX - 2, t, CX + 1, bottom, "trim", False)  # Shirt under the vest.
            cv.set(CX - 5, t + 3, "dark")
            cv.set(CX + 4, t + 3, "dark")  # Pockets.
    elif kind == "gi":
        if front:
            for i in range(5):
                cv.set(CX - 1 - i // 2, t + i, "skin")
                cv.set(CX + i // 2, t + i, "skin")
        cv.rect(CX - 6, t + 7, CX + 5, t + 8, "main", False)  # The belt (in the outfit's colour).
    elif kind == "robe" and front:
        cv.rect(CX - 1, t, CX, bottom, "trim", False)
        cv.rect(CX - 6, t + 7, CX + 5, t + 7, "trim", False)
    elif kind == "blouse" and front:
        cv.rect(CX - 2, t, CX + 1, t + 1, "white", False)
        cv.rect(CX - 1, t + 2, CX, t + 2, "red", False)  # Bow.
    elif kind == "striped":
        for y in range(t + 1, bottom, 2):
            cv.rect(CX - 6, y, CX + 5, y, "white", False)
    elif kind == "leather":
        if front:
            cv.rect(CX - 1, t + 1, CX - 1, bottom, "white", False)  # Zip.
            cv.set(CX - 5, t + 1, "white")
            cv.set(CX + 4, t + 1, "white")  # Studs.
        cv.rect(CX - 6, t, CX + 5, t, "trim", False)
    elif kind == "cape":
        cv.rect(CX - 7, t - 1, CX + 6, t + 1, "trim")  # High collar.
        if not front:
            cv.rect(CX - 7, t + 2, CX + 6, bottom + 1, "trim")
    elif kind == "coat":
        if front:
            cv.rect(CX - 1, t + 1, CX, bottom, "trim", False)
            cv.rect(CX - 4, t, CX + 3, t + 1, "white", False)
        cv.rect(CX - 6, t + 6, CX + 5, t + 6, "trim", False)
    elif kind == "rocket":
        if front:
            # A big red R on the chest.
            for (x, y) in [(-2, 2), (-2, 3), (-2, 4), (-2, 5), (-2, 6), (-1, 2), (0, 2), (1, 3), (0, 4), (-1, 4), (0, 5), (1, 6)]:
                cv.set(CX + x, t + y, "red")
        cv.rect(CX - 6, t + 8, CX + 5, t + 8, "dark", False)  # Belt.
    elif kind == "nurse":
        if front:
            cv.rect(CX - 5, t + 3, CX + 4, bottom, "white")
            cv.rect(CX - 3, t, CX + 2, t, "white", False)
    # Arms swing: forward drops a little, back rises.
    for side, sw in ((-1, s), (1, -s)):
        x0 = CX - 8 if side < 0 else CX + 6
        lift = 0 if sw == 0 else (2 if sw > 0 else -1)
        arm(x0, t + 1 + max(0, -lift), 6 + lift, t + 8 + lift)


# --- Bottoms and shoes ---------------------------------------------------------------

def leg_ends(f, side):
    """Front/back view: how far down each leg reaches (forward foot lower)."""
    left = 1 if f["step"] == 1 else (-1 if f["step"] == -1 else 0)
    shift = left if side < 0 else -left
    return 33 + f["bob"] + shift


def side_legs(f):
    stride = 3 if f["step"] != 0 else 0
    return [(CX - 2 - stride, True), (CX - 2 + stride, False)] if f["step"] == 1 else [(CX - 2 + stride, True), (CX - 2 - stride, False)]


def bottom(cv, kind, facing, f):
    b = f["bob"]
    skin_from = {"trousers": 99, "cargo": 99, "gi_pants": 99, "shorts": 31, "skirt": 31, "long_skirt": 34}[kind]
    leg_part = "white" if kind == "gi_pants" else "main"
    if facing == "right":
        for x0, far in side_legs(f):
            for y in range(29 + b, 36 + b):
                part = "skin" if y - b >= skin_from else leg_part
                for x in range(x0, x0 + 4):
                    k = SHADE if far or x == x0 + 3 else (LIGHT if x == x0 else BASE)
                    cv.set(x, y, part, k)
        if kind in ("skirt", "long_skirt"):
            cv.rect(CX - 5, 27 + b, CX + 4, (30 if kind == "skirt" else 34) + b, "main")
        if kind == "cargo":
            for x0, far in side_legs(f):
                cv.set(x0 + 1, 32 + b, "dark")
        return
    for side in (-1, 1):
        x0 = CX - 5 if side < 0 else CX + 1
        end = leg_ends(f, side)
        for y in range(29 + b, end + 1):
            part = "skin" if y - b >= skin_from else leg_part
            for x in range(x0, x0 + 4):
                k = SHADE if x == x0 + 3 or y == end else (LIGHT if x == x0 else BASE)
                cv.set(x, y, part, k)
        if kind == "gi_pants":
            cv.rect(x0 - (1 if side < 0 else 0), end - 1, x0 + 3 + (1 if side > 0 else 0), end, "white")
        if kind == "cargo":
            cv.set(x0 + 1, 31 + b, "dark")
    if kind == "skirt":
        cv.rect(CX - 7, 27 + b, CX + 6, 30 + b, "main")
    elif kind == "long_skirt":
        cv.rect(CX - 7, 27 + b, CX + 6, 34 + b, "main")
        cv.rect(CX - 7, 34 + b, CX + 6, 34 + b, "trim", False)


def shoes(cv, kind, facing, f):
    b = f["bob"]
    if facing == "right":
        for x0, far in side_legs(f):
            if kind == "boots":
                cv.rect(x0, 33 + b, x0 + 4, 37 + b, "main")
            elif kind == "sandals":
                cv.rect(x0, 36 + b, x0 + 4, 37 + b, "skin")
                cv.rect(x0, 36 + b, x0 + 4, 36 + b, "main", False)
            else:
                cv.rect(x0, 36 + b, x0 + 4, 37 + b, "main")
            cv.rect(x0, 38 + b, x0 + 4, 38 + b, "white" if kind == "sneakers" else "dark", False)
        return
    for side in (-1, 1):
        x0 = CX - 5 if side < 0 else CX + 1
        end = leg_ends(f, side)
        xa, xb = x0 - (1 if side < 0 else 0), x0 + 3 + (1 if side > 0 else 0)
        if kind == "boots":
            cv.rect(xa, end - 2, xb, end + 2, "main")
        elif kind == "sandals":
            cv.rect(xa, end + 1, xb, end + 2, "skin")
            cv.rect(xa, end + 1, xb, end + 1, "main", False)
        else:
            cv.rect(xa, end + 1, xb, end + 2, "main")
        cv.rect(xa, end + 3, xb, end + 3, "white" if kind == "sneakers" else "dark", False)


def sheet(draw):
    img = Image.new("RGBA", (W * len(FRAMES), H * 3), (0, 0, 0, 0))
    for row, facing in enumerate(FACINGS):
        for col, f in enumerate(FRAMES):
            cv = Canvas()
            draw(cv, facing, f)
            img.paste(cv.image(), (col * W, row * H))
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    for old in os.listdir(OUT):
        if old.endswith(".png") or old.endswith(".png.import"):
            os.remove(os.path.join(OUT, old))
    layers = {"head": lambda cv, fa, f: head(cv, fa, f)}
    for s in HAIRS:
        layers["hair_" + s] = lambda cv, fa, f, s=s: hair(cv, s, fa, f, False)
        layers["hair_%s_under" % s] = lambda cv, fa, f, s=s: hair(cv, s, fa, f, True)
        layers["hairback_" + s] = lambda cv, fa, f, s=s: hairback(cv, s, fa, f)
    for k in HATS:
        layers["hat_" + k] = lambda cv, fa, f, k=k: hat(cv, k, fa, f)
    for k in TOPS:
        layers["top_" + k] = lambda cv, fa, f, k=k: top(cv, k, fa, f)
    for k in BOTTOMS:
        layers["bottom_" + k] = lambda cv, fa, f, k=k: bottom(cv, k, fa, f)
    for k in SHOES:
        layers["shoes_" + k] = lambda cv, fa, f, k=k: shoes(cv, k, fa, f)
    for name, draw in layers.items():
        sheet(draw).save(os.path.join(OUT, name + ".png"))
    print("saved %d layers (%dx%d frames) to %s" % (len(layers), W, H, OUT))


if __name__ == "__main__":
    main()
