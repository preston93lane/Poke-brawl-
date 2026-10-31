"""Imports fan-made trainer sprite sheets (upscaled pixel art on a flat background,
PNG or JPG) as crowd spectators: finds each sheet's pixel grid, samples it back
to native size, cuts the background away from the edges inwards, splits the
figures apart and saves each one to assets/crowd/fan/<sheet>_<n>.png.

    python3 tools/import_crowd_sprites.py sheet1.png sheet2.jpg ...

Then run tools/make_crowd.py, which packs these together with our own drawn
spectators into assets/crowd/trainers.png. Credit the artists in the game's
About & Legal screen (scripts/ui/menu.gd CREDITS) and the README. The current
ones are by Sira Gone (@insoffnio on Instagram).
"""
import os, sys
import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "crowd", "fan")
# Figures bigger than this (wings, giant hair) don't fit on a stand; smaller is a stray bit.
MAX_W, MAX_H, MIN_H = 30, 36, 14


def grid(img):
    """Pixel size and where the first whole block starts, from where colours change."""
    a = img.astype(float)
    out = []
    for axis in (1, 0):
        d = np.abs(np.diff(a, axis=axis)).sum(axis=2)
        sig = d.sum(axis=0 if axis == 1 else 1)
        xs = np.arange(len(sig))
        best = (0.0, 5.0, 0.0)
        for s in np.arange(3.0, 8.0, 0.005):
            v = (sig * np.exp(2j * np.pi * xs / s)).sum()
            if abs(v) > best[0]:
                best = (abs(v), s, np.angle(v))
        s, phase = best[1], best[2]
        edge = (-phase / (2 * np.pi) * s) % s  # A boundary falls after this diff index.
        out.append((s, edge + 1.0))
    return out  # [(x scale, x start), (y scale, y start)]


def sample(img, gx, gy):
    sx, x0 = gx
    sy, y0 = gy
    w = int((img.shape[1] - x0) / sx)
    h = int((img.shape[0] - y0) / sy)
    native = np.zeros((h, w, 3), dtype=np.uint8)
    for j in range(h):
        for i in range(w):
            cx = int(x0 + (i + 0.5) * sx)
            cy = int(y0 + (j + 0.5) * sy)
            patch = img[max(0, cy - 1):cy + 2, max(0, cx - 1):cx + 2].reshape(-1, 3)
            native[j, i] = np.median(patch, axis=0)
    return native


def cut_background(native):
    """Pixels like the background colour that connect to the sheet's edge become clear."""
    h, w, _ = native.shape
    bg = np.median(np.concatenate([native[0], native[-1], native[:, 0], native[:, -1]]), axis=0)
    near = np.abs(native.astype(int) - bg.astype(int)).sum(axis=2) < 60
    clear = np.zeros((h, w), dtype=bool)
    stack = [(y, x) for y in range(h) for x in (0, w - 1)] + [(y, x) for x in range(w) for y in (0, h - 1)]
    while stack:
        y, x = stack.pop()
        if 0 <= y < h and 0 <= x < w and not clear[y, x] and near[y, x]:
            clear[y, x] = True
            stack += [(y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)]
    solid = ~clear
    # JPEG fringe: edge pixels still tinted toward the background go too.
    fringe = np.abs(native.astype(int) - bg.astype(int)).sum(axis=2) < 130
    edge = np.zeros_like(solid)
    edge[1:, :] |= clear[:-1, :]
    edge[:-1, :] |= clear[1:, :]
    edge[:, 1:] |= clear[:, :-1]
    edge[:, :-1] |= clear[:, 1:]
    solid &= ~(edge & fringe)
    return solid


def figures(solid):
    """Groups of touching solid pixels (with a 1-pixel gap allowed), as bounding boxes."""
    h, w = solid.shape
    seen = np.zeros_like(solid)
    boxes = []
    for y in range(h):
        for x in range(w):
            if not solid[y, x] or seen[y, x]:
                continue
            stack = [(y, x)]
            seen[y, x] = True
            x0 = x1 = x
            y0 = y1 = y
            while stack:
                cy, cx = stack.pop()
                x0, x1, y0, y1 = min(x0, cx), max(x1, cx), min(y0, cy), max(y1, cy)
                for dy in (-2, -1, 0, 1, 2):
                    for dx in (-2, -1, 0, 1, 2):
                        ny, nx = cy + dy, cx + dx
                        if 0 <= ny < h and 0 <= nx < w and solid[ny, nx] and not seen[ny, nx]:
                            seen[ny, nx] = True
                            stack.append((ny, nx))
            boxes.append((x0, y0, x1, y1))
    return boxes


def main(paths):
    os.makedirs(OUT, exist_ok=True)
    total = 0
    for path in paths:
        img = np.array(Image.open(path).convert("RGB"))
        gx, gy = grid(img)
        native = sample(img, gx, gy)[3:-3, 3:-3]  # Trim any frame drawn round the sheet.
        solid = cut_background(native)
        name = os.path.splitext(os.path.basename(path))[0][:8]
        kept = 0
        for (x0, y0, x1, y1) in sorted(figures(solid), key=lambda b: (b[1] // 10, b[0])):
            w, h = x1 - x0 + 1, y1 - y0 + 1
            if h < MIN_H or h > MAX_H or w > MAX_W:
                continue
            rgba = np.zeros((h, w, 4), dtype=np.uint8)
            rgba[..., :3] = native[y0:y1 + 1, x0:x1 + 1]
            rgba[..., 3] = solid[y0:y1 + 1, x0:x1 + 1] * 255
            Image.fromarray(rgba, "RGBA").save(os.path.join(OUT, "%s_%02d.png" % (name, kept)))
            kept += 1
        print("%s: pixel %.2f x %.2f, %d figures" % (os.path.basename(path), gx[0], gy[0], kept))
        total += kept
    print("imported", total)


if __name__ == "__main__":
    main(sys.argv[1:])
