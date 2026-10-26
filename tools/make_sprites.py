"""Generates the brawler sprites in assets/brawlers/.

    python3 tools/make_sprites.py

Each Pokemon is described with simple shapes on a 32x32 grid (the functions
below). They're drawn 4x larger, lit like a rounded 3D surface (soft shading,
a highlight, darker edges) and scaled down to 64x64 for smooth edges.

Each PNG is a 192x64 sheet of three views: front (walking toward the camera),
side (facing right; the game flips it for left) and back (walking away).
Replace any PNG with real art in the same layout whenever you like.
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "brawlers")
GRID, K, FINAL = 32, 4, 64
OL = (34, 26, 36, 255)


def rgb(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


class ScaledDraw:
    """ImageDraw-like wrapper: takes 32x32 grid coordinates, draws K times larger."""

    def __init__(self, image):
        self.d = ImageDraw.Draw(image)

    @staticmethod
    def _pts(pts):
        return [(x * K + K / 2, y * K + K / 2) for x, y in pts]

    @staticmethod
    def _box(box):
        x0, y0, x1, y1 = box
        return [x0 * K, y0 * K, (x1 + 1) * K - 1, (y1 + 1) * K - 1]

    def ellipse(self, box, fill=None, outline=None, width=1):
        self.d.ellipse(self._box(box), fill=fill, outline=outline, width=width * K)

    def rectangle(self, box, fill=None, outline=None, width=1):
        self.d.rectangle(self._box(box), fill=fill, outline=outline, width=width * K)

    def polygon(self, pts, fill=None, outline=None):
        pts = self._pts(pts)
        self.d.polygon(pts, fill=fill)
        if outline:
            self.d.line(pts + [pts[0]], fill=outline, width=K, joint="curve")

    def line(self, pts, fill=None, width=1):
        self.d.line(self._pts(pts), fill=fill, width=width * K, joint="curve")

    def point(self, pts, fill=None):
        for x, y in pts:
            self.d.rectangle([x * K, y * K, x * K + K - 1, y * K + K - 1], fill=fill)

    def arc(self, box, start, end, fill=None, width=1):
        self.d.arc(self._box(box), start, end, fill=fill, width=width * K)


def light(image):
    """Shade the flat drawing as if it were a rounded, glossy figure lit from the top left."""
    a = np.asarray(image).astype(np.float32) / 255.0
    alpha = a[..., 3]
    mask = Image.fromarray((alpha * 255).astype(np.uint8))
    height = np.asarray(mask.filter(ImageFilter.GaussianBlur(9))).astype(np.float32) / 255.0
    gy, gx = np.gradient(height)
    n = np.dstack([-gx * 28.0, -gy * 28.0, np.ones_like(height)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    l = np.array([-0.45, -0.65, 0.62]); l /= np.linalg.norm(l)
    h = l + np.array([0, 0, 1.0]); h /= np.linalg.norm(h)
    lam = np.clip(n @ l, 0, 1)
    spec = np.clip(n @ h, 0, 1) ** 24 * 0.32
    size = alpha.shape[0]
    ys = np.linspace(0, 1, size)[:, None]
    shade = (0.58 + 0.55 * lam) * (1.0 - 0.10 * ys)
    rgb_ = np.clip(a[..., :3] * shade[..., None] + spec[..., None], 0, 1)
    out = np.dstack([rgb_, alpha])
    return Image.fromarray((out * 255).astype(np.uint8))


# Which view is being drawn: eyes() reads these to move or hide the face.
FACE_DX = 0
FACE_ON = True


def _draw(draw_fn, face_dx=0, face_on=True):
    global FACE_DX, FACE_ON
    FACE_DX, FACE_ON = face_dx, face_on
    big = Image.new("RGBA", (GRID * K, GRID * K), (0, 0, 0, 0))
    draw_fn(ScaledDraw(big))
    FACE_DX, FACE_ON = 0, True
    return big


def _remove_face(big):
    """Back view: paint over dark lines and white highlights inside the body with nearby body colour."""
    alpha = big.split()[3]
    inside = np.asarray(alpha.filter(ImageFilter.MinFilter(13))) > 0
    a = np.asarray(big).astype(np.int32)
    lum = a[..., :3].sum(axis=2)
    feature = inside & ((lum < 230) | (lum > 720))
    feature = np.asarray(Image.fromarray((feature * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5))) > 0
    feature &= inside
    smooth = np.asarray(big.filter(ImageFilter.MedianFilter(17))).astype(np.int32)
    a[feature] = smooth[feature]
    a[..., :3] = (a[..., :3] * 0.9).astype(np.int32)  # the back is in its own shadow
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def sprite_views(draw_fn):
    """[front, side (facing right), back] as 64x64 images."""
    front = light(_draw(draw_fn)).resize((FINAL, FINAL), Image.LANCZOS)
    side_big = light(_draw(draw_fn, face_dx=3))
    w = int(GRID * K * 0.86)
    side_big = side_big.resize((w, GRID * K), Image.LANCZOS)
    side_canvas = Image.new("RGBA", (GRID * K, GRID * K), (0, 0, 0, 0))
    side_canvas.alpha_composite(side_big, ((GRID * K - w) // 2 + 4, 0))
    side = side_canvas.resize((FINAL, FINAL), Image.LANCZOS)
    back = light(_remove_face(_draw(draw_fn, face_on=False))).resize((FINAL, FINAL), Image.LANCZOS)
    return [front, side, back]


def sprite(draw_fn):
    return sprite_views(draw_fn)[0]

def body(d, box, color, belly=None):
    d.ellipse(box, fill=rgb(color), outline=OL)
    if belly:
        x0, y0, x1, y1 = box; w = x1 - x0
        d.ellipse([x0 + w * 0.28, y0 + (y1 - y0) * 0.5, x1 - w * 0.28, y1 - 1], fill=rgb(belly))

def eyes(d, cx, y, gap=4):
    if not FACE_ON:
        return
    cx += FACE_DX
    for x in (cx - gap, cx + gap - 1):
        d.rectangle([x, y, x + 1, y + 2], fill=OL); d.point([(x, y)], fill=(255, 255, 255, 255))


def flame(d, x, y, s=1):
    d.polygon([(x, y), (x - 2 * s, y - 3 * s), (x, y - 7 * s), (x + 2 * s, y - 3 * s)], fill=rgb("f05020"), outline=OL)
    d.point([(x, y - 3 * s)], fill=rgb("ffd040"))

def pikachu(d):
    d.polygon([(10, 12), (7, 2), (13, 9)], fill=rgb("f8d030"), outline=OL); d.polygon([(7, 2), (8, 5), (9, 4)], fill=OL)
    d.polygon([(21, 12), (24, 2), (18, 9)], fill=rgb("f8d030"), outline=OL); d.polygon([(24, 2), (23, 5), (22, 4)], fill=OL)
    d.polygon([(23, 24), (29, 18), (26, 16), (30, 11), (27, 19), (25, 22)], fill=rgb("f8d030"), outline=OL)
    body(d, [8, 9, 23, 30], "f8d030"); eyes(d, 16, 15)
    d.rectangle([9, 19, 11, 21], fill=rgb("e83828")); d.rectangle([20, 19, 22, 21], fill=rgb("e83828"))

def raichu(d):
    d.polygon([(8, 11), (3, 1), (12, 8)], fill=rgb("f0a030"), outline=OL); d.polygon([(3, 1), (5, 4), (6, 3)], fill=rgb("805020"))
    d.polygon([(23, 11), (28, 1), (19, 8)], fill=rgb("f0a030"), outline=OL); d.polygon([(28, 1), (26, 4), (25, 3)], fill=rgb("805020"))
    d.line([(24, 26), (30, 16)], fill=OL, width=2); d.polygon([(28, 14), (31, 11), (30, 17)], fill=rgb("f8d030"), outline=OL)
    body(d, [5, 7, 26, 31], "f0a030", "f8e0b0"); eyes(d, 16, 14, 5)
    d.rectangle([7, 18, 9, 20], fill=rgb("f8d030")); d.rectangle([22, 18, 24, 20], fill=rgb("f8d030"))

def charmander(d):
    d.line([(22, 26), (27, 20)], fill=rgb("f88838"), width=3); flame(d, 27, 19)
    body(d, [8, 7, 23, 30], "f88838", "f8d890"); eyes(d, 16, 13)

def charmeleon(d):
    d.line([(23, 27), (29, 19)], fill=rgb("e05030"), width=3); flame(d, 29, 18)
    d.polygon([(15, 6), (17, 1), (18, 6)], fill=rgb("e05030"), outline=OL)
    body(d, [6, 5, 24, 31], "e05030", "f0c890"); eyes(d, 15, 11)

def charizard(d):
    d.polygon([(6, 14), (0, 2), (2, 18)], fill=rgb("3888a0"), outline=OL)
    d.polygon([(25, 14), (31, 2), (29, 18)], fill=rgb("3888a0"), outline=OL)
    d.polygon([(11, 5), (10, 0), (13, 4)], fill=rgb("f08030"), outline=OL); d.polygon([(20, 5), (21, 0), (18, 4)], fill=rgb("f08030"), outline=OL)
    body(d, [5, 3, 26, 31], "f08030", "f8d890"); eyes(d, 15, 10, 5); flame(d, 27, 31, 1)

def squirtle(d):
    d.ellipse([7, 12, 24, 30], fill=rgb("a06830"), outline=OL)
    body(d, [9, 6, 22, 29], "78c8f0", "f0e0a0"); eyes(d, 15, 12)

def wartortle(d):
    d.polygon([(7, 8), (3, 1), (11, 6)], fill=rgb("e0e8f8"), outline=OL); d.polygon([(24, 8), (28, 1), (20, 6)], fill=rgb("e0e8f8"), outline=OL)
    d.ellipse([5, 11, 26, 31], fill=rgb("a06830"), outline=OL)
    body(d, [8, 5, 23, 30], "5890e0", "f0e0a0"); eyes(d, 15, 11)

def blastoise(d):
    d.ellipse([3, 9, 28, 31], fill=rgb("8a5a28"), outline=OL)
    d.rectangle([3, 9, 8, 13], fill=rgb("a0a0a8"), outline=OL); d.rectangle([23, 9, 28, 13], fill=rgb("a0a0a8"), outline=OL)
    body(d, [7, 4, 24, 30], "4870c8", "f0e0a0"); eyes(d, 15, 10, 5)

def bulbasaur(d):
    body(d, [5, 14, 26, 30], "70c8a0"); d.ellipse([10, 5, 22, 18], fill=rgb("48a048"), outline=OL)
    d.line([(16, 6), (16, 14)], fill=rgb("287828"))
    d.point([(9, 24), (22, 22), (12, 27)], fill=rgb("408870")); eyes(d, 15, 20, 5)

def ivysaur(d):
    body(d, [4, 15, 27, 31], "60b0a0")
    for pts in ([(16, 10), (4, 6), (10, 13)], [(16, 10), (28, 6), (22, 13)]):
        d.polygon(pts, fill=rgb("389838"), outline=OL)
    d.ellipse([11, 4, 21, 14], fill=rgb("e070a0"), outline=OL); eyes(d, 15, 21, 5)

def venusaur(d):
    body(d, [2, 15, 29, 31], "509890")
    for pts in ([(16, 12), (0, 10), (8, 16)], [(16, 12), (31, 10), (24, 16)]):
        d.polygon(pts, fill=rgb("287828"), outline=OL)
    d.ellipse([6, 3, 26, 15], fill=rgb("e85060"), outline=OL)
    for x in (10, 16, 21):
        d.point([(x, 8), (x + 1, 9)], fill=rgb("f8e0e0"))
    d.ellipse([13, 6, 19, 12], fill=rgb("f8d030"), outline=OL); eyes(d, 15, 21, 6)


def abra(d):
    d.polygon([(10, 9), (8, 2), (13, 7)], fill=rgb("e8c050"), outline=OL); d.polygon([(21, 9), (23, 2), (18, 7)], fill=rgb("e8c050"), outline=OL)
    d.polygon([(22, 26), (30, 22), (28, 27)], fill=rgb("e8c050"), outline=OL)
    body(d, [8, 7, 23, 30], "e8c050", "a07040")
    d.line([(12, 13), (14, 13)], fill=OL); d.line([(17, 13), (19, 13)], fill=OL)
    d.rectangle([6, 20, 9, 25], fill=rgb("a07040"), outline=OL); d.rectangle([22, 20, 25, 25], fill=rgb("a07040"), outline=OL)

def kadabra(d):
    d.polygon([(9, 9), (5, 0), (12, 6)], fill=rgb("e0b040"), outline=OL); d.polygon([(22, 9), (26, 0), (19, 6)], fill=rgb("e0b040"), outline=OL)
    d.line([(26, 12), (26, 26)], fill=rgb("c0c0d0"), width=2); d.ellipse([24, 9, 29, 13], fill=rgb("c0c0d0"), outline=OL)
    body(d, [7, 5, 24, 31], "e0b040", "a06830"); d.rectangle([14, 9, 17, 11], fill=rgb("e03030"))
    eyes(d, 15, 13)

def alakazam(d):
    d.polygon([(9, 8), (4, 0), (12, 5)], fill=rgb("d8a838"), outline=OL); d.polygon([(22, 8), (27, 0), (19, 5)], fill=rgb("d8a838"), outline=OL)
    for x in (2, 28):
        d.line([(x, 10), (x, 26)], fill=rgb("c0c0d0"), width=2); d.ellipse([x - 2, 7, x + 3, 11], fill=rgb("c0c0d0"), outline=OL)
    d.polygon([(10, 24), (16, 31), (21, 24)], fill=rgb("f0e0a0"), outline=OL)
    body(d, [6, 3, 25, 29], "d8a838", "a06030"); eyes(d, 15, 11, 5)

def dratini(d):
    d.ellipse([3, 20, 28, 31], fill=rgb("88a8f0"), outline=OL); d.ellipse([7, 23, 24, 30], fill=rgb("f0f0f8"))
    body(d, [9, 6, 22, 24], "88a8f0")
    for x in (7, 22):
        d.polygon([(x, 10), (x + (-4 if x < 10 else 4), 7), (x + (-2 if x < 10 else 2), 13)], fill=rgb("f0f0f8"), outline=OL)
    eyes(d, 15, 12)

def dragonair(d):
    d.ellipse([1, 22, 30, 31], fill=rgb("5890e8"), outline=OL)
    for x, y in ((6, 27), (25, 27)):
        d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=rgb("48c0f0"), outline=OL)
    body(d, [9, 4, 22, 25], "5890e8", "f0f0f8")
    d.polygon([(15, 4), (14, 0), (17, 0), (16, 4)], fill=rgb("f0f0f8"), outline=OL)
    d.ellipse([13, 18, 18, 22], fill=rgb("48c0f0"), outline=OL)
    eyes(d, 15, 10)

def dragonite(d):
    d.polygon([(6, 14), (0, 6), (3, 20)], fill=rgb("58b0a0"), outline=OL); d.polygon([(25, 14), (31, 6), (28, 20)], fill=rgb("58b0a0"), outline=OL)
    d.line([(12, 4), (10, 0)], fill=OL); d.line([(19, 4), (21, 0)], fill=OL)
    body(d, [5, 3, 26, 31], "f0a050", "f8e0a0"); eyes(d, 15, 10, 5)


def geodude(d):
    for x0, x1 in ((1, 9), (22, 30)):
        d.ellipse([x0, 16, x1, 23], fill=rgb("9a9080"), outline=OL)
    d.ellipse([7, 6, 24, 27], fill=rgb("a89c88"), outline=OL)
    d.point([(11, 9), (19, 22), (21, 11)], fill=rgb("7a7060"))
    d.line([(11, 12), (14, 13)], fill=OL, width=1); d.line([(17, 13), (20, 12)], fill=OL, width=1)
    eyes(d, 15, 14)
    d.arc([12, 18, 19, 23], 20, 160, fill=OL)

def graveler(d):
    d.ellipse([3, 5, 28, 30], fill=rgb("8e8474"), outline=OL)
    for x, y in ((5, 8), (24, 9), (4, 20), (25, 21), (14, 4)):
        d.ellipse([x, y, x + 4, y + 4], fill=rgb("a39884"), outline=OL)
    for x in (1, 27):
        d.rectangle([x, 15, x + 3, 22], fill=rgb("8e8474"), outline=OL)
    eyes(d, 15, 14, 5)
    d.arc([11, 18, 20, 24], 20, 160, fill=OL)

def golem(d):
    d.ellipse([2, 7, 29, 31], fill=rgb("8a7050"), outline=OL)
    for x, y in ((4, 10), (22, 10), (6, 22), (21, 23), (13, 8)):
        d.ellipse([x, y, x + 5, y + 4], fill=rgb("a08868"), outline=OL)
    d.ellipse([10, 1, 21, 11], fill=rgb("88a8a0"), outline=OL)
    eyes(d, 15, 5, 3)
    d.rectangle([0, 17, 3, 25], fill=rgb("88a8a0"), outline=OL); d.rectangle([28, 17, 31, 25], fill=rgb("88a8a0"), outline=OL)

def bellsprout(d):
    d.line([(15, 14), (15, 29)], fill=rgb("6fbf4a"), width=2)
    d.polygon([(15, 22), (6, 18), (9, 24)], fill=rgb("5aa83c"), outline=OL)
    d.polygon([(16, 20), (25, 16), (22, 23)], fill=rgb("5aa83c"), outline=OL)
    d.ellipse([8, 2, 22, 15], fill=rgb("f0e060"), outline=OL)
    d.ellipse([16, 7, 22, 12], fill=rgb("e07060"), outline=OL)
    d.rectangle([10, 7, 11, 9], fill=OL)
    d.ellipse([12, 27, 19, 31], fill=rgb("c89848"), outline=OL)

def weepinbell(d):
    d.ellipse([5, 6, 26, 30], fill=rgb("e8d850"), outline=OL)
    d.polygon([(9, 12), (22, 12), (19, 18), (12, 18)], fill=rgb("e07a6a"), outline=OL)
    d.polygon([(6, 16), (0, 22), (6, 22)], fill=rgb("5aa83c"), outline=OL); d.polygon([(25, 16), (31, 22), (25, 22)], fill=rgb("5aa83c"), outline=OL)
    d.line([(15, 6), (18, 0)], fill=rgb("6fbf4a"), width=2); d.ellipse([17, 0, 21, 3], fill=rgb("5aa83c"), outline=OL)
    eyes(d, 15, 9, 4)

def victreebel(d):
    d.ellipse([3, 3, 28, 31], fill=rgb("d8c840"), outline=OL)
    d.ellipse([6, 10, 25, 22], fill=rgb("e86a5a"), outline=OL)
    d.point([(10, 11), (14, 11), (18, 11), (22, 12)], fill=(255, 255, 255, 255))
    d.polygon([(4, 4), (16, 0), (28, 4), (16, 7)], fill=rgb("5aa83c"), outline=OL)
    d.line([(26, 4), (31, 14)], fill=rgb("6fbf4a"), width=2)
    eyes(d, 15, 7, 6)

def gastly(d):
    d.ellipse([0, 0, 31, 31], fill=rgb("6a3a8a", 150))
    d.ellipse([7, 7, 24, 24], fill=rgb("2a1838"), outline=OL)
    d.polygon([(9, 12), (14, 15), (9, 15)], fill=(255, 255, 255, 255)); d.polygon([(22, 12), (17, 15), (22, 15)], fill=(255, 255, 255, 255))
    d.arc([10, 15, 21, 22], 20, 160, fill=rgb("e05070"), width=1)

def haunter(d):
    d.polygon([(6, 8), (16, 3), (26, 8), (28, 20), (22, 30), (16, 24), (10, 30), (4, 20)], fill=rgb("6a4c9a"), outline=OL)
    d.polygon([(4, 3), (9, 9), (5, 11)], fill=rgb("6a4c9a"), outline=OL); d.polygon([(28, 3), (23, 9), (27, 11)], fill=rgb("6a4c9a"), outline=OL)
    for x in (0, 27):
        d.ellipse([x, 14, x + 5, 19], fill=rgb("6a4c9a"), outline=OL)
    d.polygon([(9, 11), (14, 14), (9, 14)], fill=(255, 255, 255, 255)); d.polygon([(23, 11), (18, 14), (23, 14)], fill=(255, 255, 255, 255))
    d.arc([10, 14, 22, 22], 20, 160, fill=rgb("e05070"), width=1)

def gengar(d):
    for x0, x1 in ((3, 9), (23, 29)):
        d.polygon([(x0, 9), (x0 + 3, 1), (x1, 9)], fill=rgb("5a4090"), outline=OL)
    d.ellipse([3, 5, 28, 30], fill=rgb("5a4090"), outline=OL)
    d.point([(14, 4), (16, 3), (18, 4)], fill=rgb("5a4090"))
    d.polygon([(8, 12), (13, 15), (8, 15)], fill=rgb("f04050")); d.polygon([(23, 12), (18, 15), (23, 15)], fill=rgb("f04050"))
    d.polygon([(9, 18), (22, 18), (20, 23), (11, 23)], fill=(255, 255, 255, 255), outline=OL)

def mankey(d):
    for x in (2, 25):
        d.ellipse([x, 10, x + 4, 15], fill=rgb("f0d8b0"), outline=OL)
    d.ellipse([5, 6, 26, 28], fill=rgb("ece0c8"), outline=OL)
    d.ellipse([9, 11, 22, 23], fill=rgb("f2b8a0"), outline=OL)
    d.ellipse([13, 17, 18, 21], fill=rgb("e07a70"), outline=OL)
    d.line([(10, 12), (14, 14)], fill=OL, width=1); d.line([(21, 12), (17, 14)], fill=OL, width=1)
    eyes(d, 15, 14, 3)
    d.ellipse([4, 26, 10, 31], fill=rgb("a07858"), outline=OL); d.ellipse([21, 26, 27, 31], fill=rgb("a07858"), outline=OL)

def primeape(d):
    for x in (0, 26):
        d.ellipse([x, 12, x + 5, 18], fill=rgb("a07858"), outline=OL)
    d.ellipse([3, 4, 28, 30], fill=rgb("ece0c8"), outline=OL)
    d.ellipse([8, 10, 23, 23], fill=rgb("f2b8a0"), outline=OL)
    d.ellipse([12, 16, 19, 21], fill=rgb("e07a70"), outline=OL)
    d.line([(8, 9), (14, 13)], fill=OL, width=2); d.line([(23, 9), (17, 13)], fill=OL, width=2)
    eyes(d, 15, 13, 3)

def annihilape(d):
    d.ellipse([0, 0, 31, 31], fill=rgb("5a3a8a", 110))
    d.ellipse([4, 4, 27, 30], fill=rgb("b8b0c8"), outline=OL)
    d.ellipse([8, 10, 23, 24], fill=rgb("3a3050"), outline=OL)
    d.line([(4, 18), (0, 12)], fill=rgb("e0e0f0"), width=2); d.line([(27, 18), (31, 12)], fill=rgb("e0e0f0"), width=2)
    d.polygon([(9, 12), (14, 15), (9, 16)], fill=rgb("ff4060")); d.polygon([(22, 12), (17, 15), (22, 16)], fill=rgb("ff4060"))
    d.arc([10, 17, 21, 23], 200, 340, fill=(255, 255, 255, 255), width=1)


# --- Legendaries ----------------------------------------------------------

def zapdos(d):
    for side in (-1, 1):
        x0 = 16 + side * 5
        d.polygon([(x0, 12), (16 + side * 15, 4), (16 + side * 12, 10), (16 + side * 16, 13), (16 + side * 12, 16), (16 + side * 15, 22), (x0, 19)],
                  fill=rgb("f8d030"), outline=OL)
    d.polygon([(13, 7), (11, 0), (15, 4), (16, 0), (18, 4), (21, 0), (19, 7)], fill=rgb("30302a"), outline=OL)
    d.ellipse([9, 6, 22, 28], fill=rgb("f8d030"), outline=OL)
    d.polygon([(16, 13), (21, 15), (16, 17)], fill=rgb("f0a030"), outline=OL)
    eyes(d, 15, 10, 3)
    d.line([(13, 28), (12, 31)], fill=rgb("f0a030"), width=1); d.line([(18, 28), (19, 31)], fill=rgb("f0a030"), width=1)

def moltres(d):
    for side in (-1, 1):
        d.polygon([(16 + side * 5, 11), (16 + side * 16, 3), (16 + side * 13, 11), (16 + side * 16, 15), (16 + side * 6, 20)], fill=rgb("f06030"), outline=OL)
        d.polygon([(16 + side * 7, 12), (16 + side * 13, 7), (16 + side * 11, 13)], fill=rgb("ffd040"))
    d.polygon([(12, 7), (14, 0), (16, 5), (18, 0), (20, 7)], fill=rgb("ff8030"), outline=OL)
    d.ellipse([9, 6, 22, 28], fill=rgb("f0b040"), outline=OL)
    d.polygon([(16, 13), (21, 15), (16, 17)], fill=rgb("f8e070"), outline=OL)
    eyes(d, 15, 10, 3)

def articuno(d):
    for side in (-1, 1):
        d.polygon([(16 + side * 5, 11), (16 + side * 16, 6), (16 + side * 14, 14), (16 + side * 6, 20)], fill=rgb("80c8f0"), outline=OL)
    d.polygon([(14, 26), (16, 31), (18, 26)], fill=rgb("5898d8"), outline=OL)
    d.polygon([(12, 6), (16, 1), (20, 6)], fill=rgb("3a70c0"), outline=OL)
    d.ellipse([9, 5, 22, 27], fill=rgb("90d8f8"), outline=OL)
    d.polygon([(16, 12), (20, 14), (16, 16)], fill=rgb("a0a8b0"), outline=OL)
    eyes(d, 15, 9, 3)

def regirock(d):
    d.ellipse([4, 4, 27, 30], fill=rgb("b0703c"), outline=OL)
    for x, y in ((2, 12), (26, 12)):
        d.ellipse([x, y, x + 4, y + 10], fill=rgb("a06434"), outline=OL)
    for x, y in ((9, 8), (14, 6), (19, 8), (8, 13), (21, 13), (13, 13), (17, 13)):
        d.rectangle([x, y, x + 1, y + 1], fill=rgb("f8b830")) if FACE_ON else None
    d.point([(10, 20), (20, 22), (15, 25)], fill=rgb("805028"))

def rayquaza(d):
    d.ellipse([2, 16, 30, 31], fill=rgb("3a9a58"), outline=OL)
    d.ellipse([7, 20, 25, 28], fill=rgb("2a7a44"))
    for x in (6, 16, 24):
        d.ellipse([x, 18, x + 2, 20], fill=rgb("f0d040"))
    d.ellipse([9, 3, 23, 18], fill=rgb("3a9a58"), outline=OL)
    d.polygon([(10, 6), (4, 0), (11, 3)], fill=rgb("3a9a58"), outline=OL); d.polygon([(22, 6), (28, 0), (21, 3)], fill=rgb("3a9a58"), outline=OL)
    d.line([(12, 15), (20, 15)], fill=rgb("f0d040"), width=1)
    eyes(d, 16, 8, 3)

def celebi(d):
    for side in (-1, 1):
        d.ellipse([16 + side * 8 - 4, 12, 16 + side * 8 + 4, 22], fill=rgb("e8f8f0", 170), outline=OL)
    d.polygon([(12, 6), (13, 0), (15, 5)], fill=rgb("90d060"), outline=OL); d.polygon([(20, 6), (19, 0), (17, 5)], fill=rgb("90d060"), outline=OL)
    d.ellipse([9, 3, 23, 17], fill=rgb("a8e070"), outline=OL)
    d.ellipse([11, 15, 21, 29], fill=rgb("a8e070"), outline=OL)
    eyes(d, 16, 9, 3)


NAMES = ['abra', 'kadabra', 'alakazam', 'dratini', 'dragonair', 'dragonite', 'pikachu', 'raichu', 'charmander', 'charmeleon', 'charizard', 'squirtle', 'wartortle', 'blastoise', 'bulbasaur', 'ivysaur', 'venusaur', 'geodude', 'graveler', 'golem', 'bellsprout', 'weepinbell', 'victreebel', 'gastly', 'haunter', 'gengar', 'mankey', 'primeape', 'annihilape']

NAMES += ["zapdos", "moltres", "articuno", "regirock", "rayquaza", "celebi"]

if __name__ == "__main__":
    import sys
    for name in NAMES:
        views = sprite_views(globals()[name])
        out = Image.new("RGBA", (FINAL * 3, FINAL), (0, 0, 0, 0))
        for i, v in enumerate(views):
            out.alpha_composite(v, (i * FINAL, 0))
        out.save(os.path.join(OUT, name + ".png"))
    if len(sys.argv) > 1:  # Optional contact sheet for reviewing the art: front / side / back.
        cols = 6
        rows = (len(NAMES) + cols - 1) // cols
        sheet = Image.new("RGBA", (cols * 3 * 72 + cols * 8, rows * 76), (58, 62, 84, 255))
        for i, name in enumerate(NAMES):
            im = Image.open(os.path.join(OUT, name + ".png"))
            sheet.alpha_composite(im.resize((216, 72), Image.LANCZOS), ((i % cols) * (216 + 8) + 2, (i // cols) * 76 + 2))
        sheet.save(sys.argv[1])
    print("wrote", len(NAMES), "sprites")
