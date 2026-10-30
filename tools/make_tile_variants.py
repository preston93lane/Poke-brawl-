"""Makes 5 variants of each themed floor and wall texture, so tiles don't look copy-pasted:
assets/tiles/<name>_v1.png .. _v5.png, plus grass_3 .. grass_5 (flipped, reshaded copies of
grass_0 .. grass_2). The arena mixes them in per tile (scripts/arena.gd) and shades each
tile a little lighter or darker in soft patches across the map.

    python3 tools/make_tile_variants.py

Each variant: the base turned or mirrored (only the ways that pattern allows: planks and
bricks only flip, so rows stay level), a colour and brightness shift, soft blotches made from tileable noise (so seams
still match), and details that suit the material (cracks, knots, pebbles, frost, rust,
moss, flowers...). Details keep away from the edges, so neighbouring tiles still join.
Deterministic: the same seed always gives the same pictures.
"""
import os, math, random
import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
TILES = os.path.join(ROOT, "assets", "tiles")
SIZE = 64
MARGIN = 7

FLOORS = ["gym_floor", "wood", "sand", "ice", "metal", "dark", "psychic", "volcanic", "pool"]
WALLS = ["rock", "brick", "hedge", "metal_wall", "wood_wall", "ice_block", "cracked", "boulder"]
VARIANTS = 5

# Turns and mirrors each picture allows: (quarter turns, mirrored). Noise-like textures and
# square grids allow all 8; planks, bricks and slabs only flips (rows stay level, and wall
# sides keep their bricks the right way up); the checkerboard keeps its colours in step.
ALL = [(0, True), (1, False), (2, False), (3, False), (1, True), (2, True), (3, True)]
FLIPS = [(0, True), (2, False), (2, True)]
TRANSFORMS = {
    "wood": FLIPS, "brick": FLIPS, "wood_wall": FLIPS, "metal_wall": FLIPS, "gym_floor": FLIPS,
    "psychic": [(2, False), (1, True), (3, True)],
}


def tileable_noise(rng, cells):
    """Smooth noise that wraps around (value noise on a cells x cells lattice, cosine blend)."""
    lattice = rng.random((cells, cells))
    xs = np.arange(SIZE) / SIZE * cells
    x0 = np.floor(xs).astype(int)
    t = xs - x0
    t = (1 - np.cos(t * math.pi)) / 2
    x1 = (x0 + 1) % cells
    a = lattice[np.ix_(x0, x0)]
    b = lattice[np.ix_(x0, x1)]
    c = lattice[np.ix_(x1, x0)]
    d = lattice[np.ix_(x1, x1)]
    ty = t[:, None]
    tx = t[None, :]
    return (a * (1 - tx) + b * tx) * (1 - ty) + (c * (1 - tx) + d * tx) * ty


def blotches(arr, rng, strength, tint=(0, 0, 0)):
    """Darken / tint the picture in soft patches."""
    n = tileable_noise(rng, 4) * 0.6 + tileable_noise(rng, 8) * 0.4
    n = (n - n.mean()) * 2.0
    rgb = arr[..., :3].astype(float)
    rgb *= (1 + n[..., None] * strength)
    rgb += np.array(tint, dtype=float)[None, None, :] * np.clip(n, 0, 1)[..., None]
    arr[..., :3] = np.clip(rgb, 0, 255)
    return arr


def shift(arr, rng, amount):
    """A slight overall brightness / warmth change."""
    k = 1 + rng.uniform(-amount, amount)
    warm = rng.uniform(-amount, amount) * 40
    rgb = arr[..., :3].astype(float) * k
    rgb[..., 0] += warm
    rgb[..., 2] -= warm
    arr[..., :3] = np.clip(rgb, 0, 255)
    return arr


def inner(rng):
    return rng.randint(MARGIN, SIZE - MARGIN), rng.randint(MARGIN, SIZE - MARGIN)


def crack(draw, rng, color, segments=5, width=1):
    x, y = inner(rng)
    angle = rng.uniform(0, math.tau)
    pts = [(x, y)]
    for _ in range(segments):
        angle += rng.uniform(-0.9, 0.9)
        x = min(SIZE - MARGIN, max(MARGIN, x + math.cos(angle) * rng.uniform(3, 7)))
        y = min(SIZE - MARGIN, max(MARGIN, y + math.sin(angle) * rng.uniform(3, 7)))
        pts.append((x, y))
    draw.line(pts, fill=color, width=width)
    if rng.random() < 0.6:  # A small branch.
        i = rng.randint(1, len(pts) - 1)
        bx, by = pts[i]
        a2 = angle + rng.choice([-1.2, 1.2])
        draw.line([(bx, by), (bx + math.cos(a2) * 5, by + math.sin(a2) * 5)], fill=color, width=1)


def dots(draw, rng, colors, count, rmin=1, rmax=2):
    for _ in range(count):
        x, y = inner(rng)
        r = rng.uniform(rmin, rmax)
        draw.ellipse([x - r, y - r, x + r, y + r], fill=rng.choice(colors))


def patch(draw, rng, color, rmin=4, rmax=9):
    x, y = inner(rng)
    for _ in range(rng.randint(3, 6)):
        r = rng.uniform(rmin * 0.5, rmax * 0.6)
        ox, oy = rng.uniform(-rmax * 0.5, rmax * 0.5), rng.uniform(-rmax * 0.5, rmax * 0.5)
        cx = min(SIZE - MARGIN - r, max(MARGIN + r, x + ox))
        cy = min(SIZE - MARGIN - r, max(MARGIN + r, y + oy))
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color)


def details(name, img, rng):
    """Material-specific marks, drawn on a transparent layer and blended in."""
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    if name in ("gym_floor", "rock", "boulder", "cracked"):
        for _ in range(rng.randint(1, 2)):
            crack(d, rng, (60, 50, 40, 150))
        dots(d, rng, [(90, 80, 70, 110), (200, 195, 185, 90)], rng.randint(2, 5))
        if name in ("rock", "boulder") and rng.random() < 0.6:
            patch(d, rng, (70, 120, 50, 90))  # Moss.
    elif name in ("wood", "wood_wall"):
        for _ in range(rng.randint(1, 2)):  # Knots.
            x, y = inner(rng)
            d.ellipse([x - 3, y - 2, x + 3, y + 2], fill=(70, 40, 20, 140))
            d.ellipse([x - 1.5, y - 1, x + 1.5, y + 1], fill=(50, 28, 14, 170))
        for _ in range(rng.randint(1, 3)):  # Scuffs along the grain.
            x, y = inner(rng)
            d.line([(x, y), (min(SIZE - MARGIN, x + rng.randint(6, 14)), y)], fill=(230, 200, 150, 70), width=1)
    elif name in ("sand", "pool"):
        if name == "sand":
            dots(d, rng, [(150, 120, 80, 150), (190, 165, 120, 140), (120, 100, 70, 130)], rng.randint(4, 9), 0.8, 1.8)
            for _ in range(rng.randint(1, 2)):  # Wind ripples.
                x, y = inner(rng)
                d.arc([x - 9, y - 3, x + 9, y + 3], 200, 340, fill=(170, 140, 95, 110), width=1)
        else:
            patch(d, rng, (255, 255, 255, 40), 3, 6)  # Light glints on the water tiles.
    elif name in ("ice", "ice_block"):
        for _ in range(rng.randint(1, 2)):
            crack(d, rng, (255, 255, 255, 150))
        dots(d, rng, [(255, 255, 255, 120), (200, 235, 255, 140)], rng.randint(2, 5), 0.8, 1.6)  # Bubbles.
    elif name in ("metal", "metal_wall"):
        for _ in range(rng.randint(1, 2)):
            patch(d, rng, (140, 80, 40, 70), 3, 7)  # Rust.
        for _ in range(rng.randint(1, 3)):  # Scratches.
            x, y = inner(rng)
            a = rng.uniform(0, math.tau)
            d.line([(x, y), (x + math.cos(a) * 7, y + math.sin(a) * 7)], fill=(220, 225, 235, 110), width=1)
    elif name == "dark":
        crack(d, rng, (20, 15, 30, 150))
        dots(d, rng, [(150, 120, 200, 90)], rng.randint(1, 3), 0.8, 1.4)
    elif name == "psychic":
        dots(d, rng, [(255, 255, 255, 110), (255, 200, 240, 120)], rng.randint(2, 4), 0.6, 1.2)
    elif name == "volcanic":
        for _ in range(rng.randint(1, 2)):
            crack(d, rng, (255, 110, 30, 200), 4, 2)
        dots(d, rng, [(40, 30, 25, 140)], rng.randint(2, 4))
    elif name == "brick":
        if rng.random() < 0.7:
            patch(d, rng, (80, 120, 60, 90), 3, 7)  # Moss.
        for _ in range(rng.randint(1, 3)):  # Chips.
            x, y = inner(rng)
            d.rectangle([x, y, x + rng.randint(1, 3), y + rng.randint(1, 2)], fill=(90, 50, 40, 150))
    elif name == "hedge":
        dots(d, rng, [(255, 240, 120, 200), (255, 255, 255, 200), (250, 150, 190, 200)], rng.randint(2, 5), 0.9, 1.6)
        patch(d, rng, (120, 190, 80, 60), 3, 7)
    return Image.alpha_composite(img, layer)


def turned(img, name, index):
    """The base picture turned / mirrored one of the ways its pattern allows."""
    options = TRANSFORMS.get(name, ALL)
    quarter, mirror = options[(index - 1) % len(options)]
    if mirror:
        img = img.transpose(Image.FLIP_LEFT_RIGHT)
    for _ in range(quarter):
        img = img.transpose(Image.ROTATE_90)
    return img


def variant(name, base, index):
    rng = random.Random(sum(map(ord, name)) * 7919 + index * 104729)
    nrng = np.random.default_rng(sum(map(ord, name)) * 31 + index)
    arr = np.array(turned(base.convert("RGBA"), name, index)).astype(float)
    arr = shift(arr, rng, 0.09)
    tint = {"rock": (-8, 6, -8), "brick": (-6, 4, -6), "metal_wall": (8, -2, -8), "metal": (8, -2, -8),
            "wood": (6, 2, -4), "wood_wall": (6, 2, -4)}.get(name, (0, 0, 0))
    arr = blotches(arr, nrng, 0.11, tint)
    img = Image.fromarray(arr.astype(np.uint8), "RGBA")
    return details(name, img, rng)


def main():
    made = 0
    for name in FLOORS + WALLS:
        path = os.path.join(TILES, name + ".png")
        if not os.path.exists(path):
            continue
        base = Image.open(path)
        for i in range(1, VARIANTS + 1):
            variant(name, base, i).save(os.path.join(TILES, "%s_v%d.png" % (name, i)))
            made += 1
    # Grass: mirrored, reshaded copies of the three hand-made tiles (blades stay upright).
    for i in range(3):
        base = Image.open(os.path.join(TILES, "grass_%d.png" % i)).convert("RGBA")
        img = base.transpose(Image.FLIP_LEFT_RIGHT if i != 1 else Image.FLIP_TOP_BOTTOM)
        rng = random.Random(4242 + i)
        arr = shift(np.array(img).astype(float), rng, 0.07)
        arr = blotches(arr, np.random.default_rng(99 + i), 0.09, (-4, 6, -6))
        Image.fromarray(arr.astype(np.uint8), "RGBA").save(os.path.join(TILES, "grass_%d.png" % (i + 3)))
        made += 1
    print("made %d variants" % made)


if __name__ == "__main__":
    main()
