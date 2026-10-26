"""Generates the item pickup icons in assets/items/ (64x64).

    python3 tools/make_items.py [contact_sheet.png]
"""
import os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "items")
S = 64
OL = (30, 26, 36, 255)


def shade(im):
    """Glossy look: light from the top left, a white highlight streak."""
    a = np.asarray(im).astype(np.float32)
    h, w = a.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    k = 1.15 - 0.35 * (xx + yy) / (w + h)
    a[..., :3] *= k[..., None]
    out = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))
    return out


def bottle(body, cap, label=None, label_color=(255, 255, 255, 255)):
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([16, 18, 48, 58], radius=10, fill=body, outline=OL, width=3)
    d.rectangle([24, 9, 40, 19], fill=cap, outline=OL, width=3)
    d.rounded_rectangle([17, 30, 47, 46], radius=4, fill=(250, 250, 250, 255), outline=OL, width=2)
    if label:
        d.text((32, 38), label, fill=label_color, anchor="mm", font=None, font_size=11)
    d.line([(21, 22), (21, 52)], fill=(255, 255, 255, 140), width=3)
    return shade(im)


def potion():
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse([12, 22, 52, 60], fill=(160, 80, 220, 255), outline=OL, width=3)
    d.rectangle([24, 8, 40, 26], fill=(220, 220, 230, 255), outline=OL, width=3)
    d.rectangle([20, 4, 44, 11], fill=(120, 120, 130, 255), outline=OL, width=3)
    d.ellipse([18, 28, 30, 40], fill=(230, 200, 255, 200))
    return shade(im)


def pp_up():
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([8, 20, 56, 44], radius=12, fill=(250, 210, 60, 255), outline=OL, width=3)
    d.rounded_rectangle([32, 20, 56, 44], radius=12, fill=(240, 120, 40, 255), outline=OL, width=3)
    d.text((30, 32), "PP", fill=(40, 30, 20, 255), anchor="mm", font_size=14)
    return shade(im)


ITEMS = {
    "potion": potion,
    "protein": lambda: bottle((220, 70, 60, 255), (250, 240, 230, 255), "ATK", (200, 40, 30, 255)),
    "iron": lambda: bottle((70, 120, 220, 255), (250, 240, 230, 255), "DEF", (40, 80, 190, 255)),
    "carbos": lambda: bottle((90, 190, 90, 255), (250, 240, 230, 255), "SPD", (40, 140, 50, 255)),
    "pp_up": pp_up,
    "hp_up": lambda: bottle((240, 200, 70, 255), (90, 200, 120, 255), "HP+", (200, 140, 20, 255)),
}

if __name__ == "__main__":
    for name, fn in ITEMS.items():
        fn().save(os.path.join(OUT, name + ".png"))
    if len(sys.argv) > 1:
        sheet = Image.new("RGBA", (len(ITEMS) * 136, 136), (58, 62, 84, 255))
        for i, name in enumerate(ITEMS):
            sheet.alpha_composite(Image.open(os.path.join(OUT, name + ".png")).resize((128, 128)), (i * 136 + 4, 4))
        sheet.save(sys.argv[1])
    print("items written")
