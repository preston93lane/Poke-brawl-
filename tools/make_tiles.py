"""Generates the arena textures in assets/tiles/.

    python3 tools/make_tiles.py [contact_sheet.png]

All floor/wall textures are 64x64 and tile seamlessly (the noise wraps), so
one tile = one metre in game. Swap any PNG for hand-painted art later.
"""
import os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "tiles")
S = 64
rng = np.random.default_rng(7)


def noise(cells, seed, octaves=4):
    """Seamless fractal value noise in 0..1, shape (S, S)."""
    r = np.random.default_rng(seed)
    out = np.zeros((S, S)); amp = 1.0; total = 0.0
    for o in range(octaves):
        n = cells * (2 ** o)
        grid = r.random((n, n))
        xs = np.arange(S) * n / S
        i0 = np.floor(xs).astype(int); t = xs - i0
        t = t * t * (3 - 2 * t)
        i1 = (i0 + 1) % n; i0 %= n
        g = grid[i0][:, i0] * (1 - t)[None, :] + grid[i0][:, i1] * t[None, :]
        h = grid[i1][:, i0] * (1 - t)[None, :] + grid[i1][:, i1] * t[None, :]
        layer = g * (1 - t)[:, None] + h * t[:, None]
        out += layer * amp; total += amp; amp *= 0.5
    return out / total


def colorize(n, stops):
    """Map 0..1 noise through colour stops [(pos, (r,g,b)), ...]."""
    pos = np.array([p for p, _ in stops]); cols = np.array([c for _, c in stops], dtype=float)
    img = np.zeros((S, S, 3))
    for ch in range(3):
        img[..., ch] = np.interp(n, pos, cols[:, ch])
    return img


def save(arr, name, alpha=None):
    arr = np.clip(arr, 0, 255).astype(np.uint8)
    im = Image.fromarray(arr, "RGB")
    if alpha is not None:
        im.putalpha(Image.fromarray(np.clip(alpha, 0, 255).astype(np.uint8)))
    im.save(os.path.join(OUT, name + ".png"))
    return im


def wrap_draw(im, fn):
    """Draw with wrap-around so strokes crossing an edge reappear on the other side."""
    for dx in (-S, 0, S):
        for dy in (-S, 0, S):
            fn(ImageDraw.Draw(im), dx, dy)


def grass(seed):
    n = noise(4, seed)
    img = colorize(n, [(0, (62, 128, 46)), (0.5, (92, 160, 60)), (1, (128, 188, 78))])
    im = Image.fromarray(img.astype(np.uint8))
    r = np.random.default_rng(seed + 100)
    blades = [(r.integers(0, S), r.integers(0, S), r.integers(3, 7), r.uniform(-2, 2), r.uniform(0.7, 1.25)) for _ in range(90)]
    def draw(d, dx, dy):
        for x, y, h, lean, tone in blades:
            c = tuple(int(v * tone) for v in (70, 140, 50))
            d.line([(x + dx, y + dy), (x + dx + lean, y + dy - h)], fill=c, width=1)
    wrap_draw(im, draw)
    save(np.asarray(im).astype(float), "grass_%d" % (seed % 10))


def path():
    n = noise(6, 21)
    img = colorize(n, [(0, (170, 132, 88)), (0.55, (204, 170, 118)), (1, (226, 198, 148))])
    im = Image.fromarray(img.astype(np.uint8))
    r = np.random.default_rng(22)
    stones = [(r.integers(0, S), r.integers(0, S), r.integers(1, 3)) for _ in range(26)]
    def draw(d, dx, dy):
        for x, y, s in stones:
            d.ellipse([x + dx, y + dy, x + dx + s + 1, y + dy + s], fill=(150, 124, 96))
            d.point((x + dx, y + dy), fill=(236, 214, 170))
    wrap_draw(im, draw)
    save(np.asarray(im).astype(float), "path")


def stone_blocks(name, base, rows, seed, bevel=True):
    """Bricks/slabs with grout lines and a light top-left bevel."""
    n = noise(5, seed)
    img = colorize(n, [(0, tuple(v * 0.78 for v in base)), (0.6, base), (1, tuple(min(255, v * 1.12) for v in base))])
    shade = np.ones((S, S))
    h = S // rows
    for row in range(rows):
        y0 = row * h
        offset = (h if row % 2 else 0) if rows > 1 else 0
        for col in range(-1, rows + 1):
            x0 = (col * h * 2 + offset) % (S * 2) - h
            for y in range(y0, y0 + h):
                for x in range(max(0, x0), min(S, x0 + h * 2)):
                    lx, ly = x - x0, y - y0
                    if lx < 2 or ly < 2:
                        shade[y, x] = 0.55  # grout
                    elif bevel and (lx < 5 or ly < 5):
                        shade[y, x] = 1.18
                    elif bevel and (lx > h * 2 - 5 or ly > h - 5):
                        shade[y, x] = 0.82
    save(img * shade[..., None], name)


def boulder():
    n = noise(3, 41) * 0.7 + noise(10, 42, 2) * 0.3
    img = colorize(n, [(0, (96, 84, 70)), (0.5, (138, 122, 100)), (1, (176, 160, 134))])
    cracks = Image.new("L", (S, S), 0)
    r = np.random.default_rng(43)
    pts = [(r.integers(0, S), r.integers(0, S)) for _ in range(5)]
    def draw(d, dx, dy):
        for x, y in pts:
            d.line([(x + dx, y + dy), (x + dx + r.integers(-14, 14), y + dy + r.integers(6, 18))], fill=255, width=1)
    wrap_draw(cracks, draw)
    c = np.asarray(cracks).astype(float) / 255
    save(img * (1 - 0.45 * c[..., None]), "boulder")


def water():
    n = noise(4, 51) * 0.6 + noise(12, 52, 2) * 0.4
    img = colorize(n, [(0, (32, 92, 170)), (0.6, (58, 132, 210)), (1, (130, 196, 240))])
    save(img, "water")


def tall_grass():
    """RGBA blade clump for the crossed-quad bushes: dark at the root, light at the tips."""
    W, H = 64, 64
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    r = np.random.default_rng(61)
    for i in range(34):
        x = r.uniform(2, W - 2); lean = r.uniform(-7, 7); h = r.uniform(34, 62); w = r.uniform(2.5, 4.5)
        tone = r.uniform(0.8, 1.2)
        for seg in range(8):
            t0, t1 = seg / 8, (seg + 1) / 8
            y0, y1 = H - t0 * h, H - t1 * h
            x0, x1 = x + lean * t0 ** 1.5, x + lean * t1 ** 1.5
            k = 0.45 + 0.6 * t1
            col = tuple(int(min(255, c * k * tone)) for c in (60, 150, 52)) + (255,)
            half0, half1 = w * (1 - t0 * 0.85) / 2, w * (1 - t1 * 0.85) / 2
            d.polygon([(x0 - half0, y0), (x0 + half0, y0), (x1 + half1, y1), (x1 - half1, y1)], fill=col)
    im.save(os.path.join(OUT, "tall_grass.png"))


def tree():
    W, H = 96, 120
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.polygon([(42, 76), (54, 76), (58, 118), (38, 118)], fill=(104, 72, 44, 255))
    d.line([(46, 80), (44, 116)], fill=(132, 96, 60, 255), width=3)
    r = np.random.default_rng(71)
    blobs = [(r.uniform(16, 80), r.uniform(14, 74), r.uniform(15, 24)) for _ in range(16)]
    blobs.sort(key=lambda b: b[1])
    for x, y, rad in blobs:  # dark base layer, then lit leaves on top
        d.ellipse([x - rad, y - rad, x + rad, y + rad], fill=(34, 92, 40, 255))
    for x, y, rad in blobs:
        d.ellipse([x - rad * 0.8 - 2, y - rad * 0.8 - 3, x + rad * 0.6, y + rad * 0.5], fill=(58, 134, 54, 255))
        d.ellipse([x - rad * 0.5 - 3, y - rad * 0.55 - 4, x, y - rad * 0.1], fill=(102, 176, 76, 255))
    im = im.filter(ImageFilter.SMOOTH)
    im.save(os.path.join(OUT, "tree.png"))


def zone():
    a = np.zeros((S, S)); yy, xx = np.mgrid[0:S, 0:S]
    a[((xx + yy) // 8) % 2 == 0] = 70
    a[(xx < 3) | (yy < 3) | (xx > S - 4) | (yy > S - 4)] = 200
    save(np.full((S, S, 3), 255.0), "zone", alpha=a + 40)


def edge_shadow():
    """Soft dark gradient laid on floor tiles beside walls (fake ambient occlusion)."""
    yy = np.mgrid[0:S, 0:S][0].astype(float)
    a = np.clip(1 - yy / (S * 0.55), 0, 1) ** 1.6 * 150
    save(np.zeros((S, S, 3)), "edge_shadow", alpha=a)


if __name__ == "__main__":
    for seed in (0, 1, 2):
        grass(seed)
    path(); boulder(); water(); tall_grass(); tree(); zone(); edge_shadow()
    stone_blocks("rock", (150, 144, 140), 2, 31)
    stone_blocks("gym_floor", (210, 196, 160), 2, 33, bevel=False)
    names = ["grass_0", "grass_1", "grass_2", "path", "gym_floor", "rock", "boulder", "water", "tall_grass", "zone", "edge_shadow", "tree"]
    if len(sys.argv) > 1:
        sheet = Image.new("RGBA", (12 * 132, 260), (58, 62, 84, 255))
        for i, n in enumerate(names):
            im = Image.open(os.path.join(OUT, n + ".png")).convert("RGBA")
            im = im.resize((128, 128 if n != "tree" else 160), Image.NEAREST)
            sheet.alpha_composite(im, (i * 132, 0))
        # 2x2 tiling check for the grass
        g = Image.open(os.path.join(OUT, "grass_0.png")).convert("RGBA")
        for tx in range(4):
            sheet.alpha_composite(g, (tx * 64, 180))
        sheet.save(sys.argv[1])
    print("tiles written")
