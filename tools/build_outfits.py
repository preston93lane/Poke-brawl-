"""Builds the Trainer Outfitter's catalog (data/outfits.json) and paints the fixed
looks (trainers in town, people in the buildings, Team Rocket) into finished
sheets (assets/trainers/looks/<id>.png), so the game only has to stack layers
for your own trainer. Run after tools/make_trainer_sheets.py.

    python3 tools/build_outfits.py

Shop items: everyday hats, tops, bottoms and shoes, each sold in a few colours.
Each colour is its own purchase (buying the red cap doesn't give you the blue
one). Trainer class outfits (Hiker, Swimmer, Black Belt...) can't be bought: beat
CLASS_WINS trainers of that class (in town or the Trainer Tower) and the whole
outfit is yours in every colourway; their signature pieces (EARNED) only come that
way. The Pokémon Trainer outfit is sold as a set. Team Rocket's uniform comes
from the Rocket Hideout.
The stacking and outlines match scripts/data/trainer_look.gd.
"""
import json, os
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
LAYERS = os.path.join(ROOT, "assets", "trainers")
LOOKS = os.path.join(LAYERS, "looks")

COLORS = ["#d83838", "#3868d8", "#38a858", "#f0b830", "#9050c8", "#f0f0ec", "#f08028", "#30b0b8",
          "#e868a0", "#585868", "#282830", "#a87848", "#704020", "#88c8f0", "#c8a0e8", "#c84860"]
SKINS = ["#ffe4c8", "#fcd8b0", "#f0c496", "#e0b080", "#d6a070", "#b88050", "#a87048", "#7c5234", "#5c3a24"]
HAIR_COLORS = ["#342824", "#704020", "#e8c458", "#c84830", "#484860", "#ececf0", "#603880", "#2858a0", "#f58cb4", "#38a858"]
HAIRS = ["short", "spiky", "long", "pigtails", "bun", "buzz"]
NAMES = {
    "hat": {"cap": "Trainer Cap", "cap_back": "Backwards Cap", "beanie": "Beanie", "sun_hat": "Sun Hat", "straw_hat": "Straw Hat",
            "headband": "Headband", "hood": "Hood", "bandana": "Bandana", "swim_cap": "Swim Cap", "rocket_cap": "Rocket Cap"},
    "top": {"jacket": "Trainer Jacket", "tshirt": "T-Shirt", "tank": "Tank Top", "vest": "Explorer Vest", "gi": "Karate Gi",
            "robe": "Robe", "blouse": "Blouse", "striped": "Striped Shirt", "leather": "Leather Jacket", "cape": "Psychic Cape",
            "coat": "Ace Coat", "rocket": "Rocket Uniform"},
    "bottom": {"trousers": "Trousers", "shorts": "Shorts", "skirt": "Skirt", "long_skirt": "Long Skirt", "gi_pants": "Gi Pants",
               "cargo": "Cargo Pants"},
    "shoes": {"sneakers": "Sneakers", "boots": "Boots", "sandals": "Sandals"},
}
# Everyday clothes, only sold in the shop.
SHOP = {
    "hat": {"beret": "Beret", "bucket_hat": "Bucket Hat", "visor": "Sun Visor", "bow": "Hair Bow", "cowboy": "Cowboy Hat"},
    "top": {"hoodie": "Hoodie", "sweater": "Sweater", "polo": "Polo Shirt", "puffer": "Puffer Jacket", "hawaiian": "Island Shirt",
            "track": "Track Jacket"},
    "bottom": {"jeans": "Jeans", "joggers": "Joggers", "pleated": "Pleated Skirt", "capris": "Capris"},
    "shoes": {"high_tops": "High-Tops", "rain_boots": "Rain Boots", "loafers": "Loafers"},
}
for _slot, _names in SHOP.items():
    NAMES[_slot].update(_names)
# Trainer class pieces you can only get by earning the class's outfit.
EARNED = {"straw_hat", "sun_hat", "headband", "hood", "bandana", "swim_cap", "tank", "vest", "gi", "robe", "blouse", "striped",
          "leather", "cape", "coat", "long_skirt", "gi_pants", "cargo"}
CLASS_WINS = 15
PRICES = {"hat": 800, "top": 1200, "bottom": 900, "shoes": 600}
SPECIAL = {"leather": 1600, "cape": 1600, "coat": 1600, "gi": 1400, "robe": 1400}
# Colours each item comes in (indices into COLORS), on top of those its sets use.
EXTRA = {
    "cap": [0, 1, 2, 4, 10], "cap_back": [0, 1, 3, 6], "beanie": [11, 0, 2, 9], "sun_hat": [5, 8, 13], "straw_hat": [2, 0, 1],
    "headband": [0, 1, 10], "hood": [9, 4, 10], "bandana": [10, 0, 1], "swim_cap": [7, 1, 8],
    "jacket": [1, 0, 2, 4, 9], "tshirt": [3, 0, 1, 2, 8], "tank": [7, 1, 0], "vest": [11, 2, 9], "gi": [10, 0, 11],
    "robe": [4, 9, 10], "blouse": [8, 5, 13], "striped": [10, 1, 0], "leather": [10, 12, 0], "cape": [4, 10, 15],
    "coat": [5, 1, 10], "trousers": [9, 10, 1, 12], "shorts": [2, 1, 11, 10], "skirt": [1, 0, 8, 10],
    "long_skirt": [4, 9, 8], "gi_pants": [5], "cargo": [9, 11, 2], "sneakers": [0, 1, 5, 10], "boots": [12, 10, 0, 1],
    "sandals": [11, 6, 3],
    "beret": [0, 10, 4, 15, 13], "bucket_hat": [11, 2, 3, 9, 1], "visor": [5, 0, 1, 8, 3], "bow": [0, 8, 1, 5, 4, 3],
    "cowboy": [11, 12, 10, 5],
    "hoodie": [9, 0, 1, 2, 4, 10, 8], "sweater": [15, 2, 1, 11, 14, 5], "polo": [5, 1, 0, 2, 3, 13], "puffer": [0, 1, 10, 3, 4, 7],
    "hawaiian": [6, 7, 8, 3, 1], "track": [1, 0, 2, 10, 4],
    "jeans": [1, 10, 9, 13], "joggers": [9, 10, 1, 0, 2], "pleated": [15, 1, 9, 10, 14], "capris": [5, 13, 3, 8],
    "high_tops": [0, 1, 10, 5, 3], "rain_boots": [3, 0, 1, 2, 8], "loafers": [12, 10, 11, 15],
}
SHOP_PRICES = {"cowboy": 1500, "puffer": 1800, "hawaiian": 1400, "track": 1400, "hoodie": 1300, "jeans": 1100, "high_tops": 900,
               "rain_boots": 800}
# Trainer classes as outfits: pieces, then colourways {name: [hat, top, bottom, shoes]}.
SETS = [
    ("trainer", "Pokémon Trainer", ["cap", "jacket", "trousers", "sneakers"], {"Red": [0, 1, 9, 0], "Blue": [1, 10, 9, 1], "Green": [2, 9, 10, 2]}),
    ("bug_catcher", "Bug Catcher", ["straw_hat", "tshirt", "shorts", "sneakers"], {"Meadow": [2, 3, 2, 1], "Sky": [1, 13, 1, 5], "Sunset": [0, 6, 11, 0]}),
    ("hiker", "Hiker", ["beanie", "vest", "cargo", "boots"], {"Trail": [11, 11, 9, 12], "Forest": [2, 2, 11, 12], "Summit": [0, 0, 10, 10]}),
    ("swimmer", "Swimmer", ["swim_cap", "tank", "shorts", "sandals"], {"Lagoon": [7, 7, 1, 6], "Coral": [8, 0, 8, 3], "Deep": [1, 1, 10, 11]}),
    ("psychic", "Psychic", ["", "cape", "trousers", "boots"], {"Mystic": [0, 4, 10, 10], "Crimson": [0, 15, 10, 10], "Midnight": [0, 10, 1, 1]}),
    ("blackbelt", "Black Belt", ["headband", "gi", "gi_pants", "sandals"], {"Dojo": [0, 10, 5, 11], "Champion": [10, 0, 5, 11], "Master": [1, 11, 5, 6]}),
    ("channeler", "Channeler", ["hood", "robe", "long_skirt", "sandals"], {"Lavender": [9, 4, 4, 11], "Ghost": [10, 9, 9, 11], "Spirit": [4, 14, 4, 3]}),
    ("picnicker", "Picnicker", ["sun_hat", "blouse", "skirt", "sneakers"], {"Daisy": [5, 8, 1, 5], "Berry": [8, 13, 8, 0], "Blossom": [13, 5, 0, 1]}),
    ("burglar", "Burglar", ["bandana", "striped", "trousers", "boots"], {"Classic": [10, 10, 9, 10], "Navy": [1, 1, 10, 10], "Scarlet": [0, 0, 12, 12]}),
    ("rocker", "Rocker", ["", "leather", "trousers", "boots"], {"Black": [0, 10, 10, 0], "Brown": [0, 12, 1, 12], "Red": [0, 0, 10, 10]}),
    ("bird_keeper", "Bird Keeper", ["cap_back", "vest", "cargo", "boots"], {"Pidgey": [3, 11, 9, 12], "Fearow": [0, 2, 11, 12], "Sky": [1, 9, 11, 10]}),
    ("cooltrainer", "Ace Trainer", ["", "coat", "trousers", "boots"], {"Ace": [0, 5, 1, 1], "Elite": [0, 10, 10, 0], "Royal": [0, 1, 10, 10]}),
]
# Town trainer classes drawn as girls (the rest as boys), like the handheld games.
GIRLS = {"swimmer", "psychic", "channeler", "picnicker"}
ROCKET = [("rocket_grunt", "Team Rocket Grunt", 10), ("rocket_executive", "Rocket Executive", 5)]
# Each town trainer class wears its set's first colourway with this hairstyle.
CLASS_HAIR = {"bug_catcher": "short", "hiker": "buzz", "swimmer": "long", "psychic": "long", "blackbelt": "spiky",
              "channeler": "long", "picnicker": "pigtails", "burglar": "short", "rocker": "spiky", "bird_keeper": "short",
              "cooltrainer": "short"}
STAFF = {
    "nurse": {"gender": "girl", "skin": "#fcd8b0", "hair": "pigtails", "hair_color": "#f58cb4", "hat": ["nurse_cap", "#ffffff"], "top": ["nurse", "#fab8cc"],
              "bottom": ["long_skirt", "#fab8cc"], "shoes": ["sneakers", "#f8f8f8"]},
    "elder": {"skin": "#f0c496", "hair": "elder", "hair_color": "#d8d8e0", "hat": None, "top": ["vest", "#8a6a4a"],
              "bottom": ["trousers", "#4a4640"], "shoes": ["sandals", "#704020"]},
    "clerk": {"skin": "#d6a070", "hair": "short", "hair_color": "#342824", "hat": ["cap", "#3373d8"], "top": ["jacket", "#3373d8"],
              "bottom": ["trousers", "#282830"], "shoes": ["sneakers", "#282830"]},
    "dealer": {"skin": "#f0c496", "hair": "short", "hair_color": "#484860", "hat": None, "top": ["vest", "#202028"],
               "bottom": ["trousers", "#202028"], "shoes": ["boots", "#202028"]},
    "guide": {"gender": "girl", "skin": "#a87048", "hair": "bun", "hair_color": "#603880", "hat": None, "top": ["blouse", "#8c4ca0"],
              "bottom": ["long_skirt", "#585868"], "shoes": ["boots", "#282830"]},
    "stylist": {"gender": "girl", "skin": "#fcd8b0", "hair": "long", "hair_color": "#c84830", "hat": ["sun_hat", "#f0f0ec"], "top": ["blouse", "#f278a8"],
                "bottom": ["skirt", "#30b0b8"], "shoes": ["sneakers", "#f0f0ec"]},
}
PARTS = ["skin", "hair", "main", "trim", "dark", "white", "red", "eye", "mouth", "blush", "gold"]
FIXED = {"dark": "#28262f", "white": "#f5f5f5", "red": "#dc2830", "eye": "#282030", "mouth": "#b03038", "blush": "#f07878", "gold": "#e1be5a"}
COVERING = {"cap", "cap_back", "beanie", "sun_hat", "straw_hat", "hood", "swim_cap", "rocket_cap", "bandana", "beret", "bucket_hat", "cowboy"}
CELL = (32, 40)


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def trim_of(c):
    # A lighter shade of the item's colour (a darker one for white/very light items).
    if sum(c) > 600:
        return tuple(int(v * 0.8) for v in c)
    return tuple(int(v + (255 - v) * 0.35) for v in c)


def compose(look):
    """Stacks and paints the layers like TrainerLook.compose does in the game."""
    hat = look.get("hat")
    hair = look["hair"]
    order = [("hairback_" + hair, None), ("bottom_" + look["bottom"][0], look["bottom"][1]),
             ("shoes_" + look["shoes"][0], look["shoes"][1]), ("top_" + look["top"][0], look["top"][1]), ("head", None),
             ("hair_%s%s" % (hair, "_under" if hat and hat[0] in COVERING else ""), None)]
    if look.get("gender") == "girl":
        order[4] = ("head_girl", None)
    if hat:
        order.append(("hat_" + hat[0], hat[1]))
    size = Image.open(os.path.join(LAYERS, "head.png")).size
    px = {}
    for li, (name, col) in enumerate(order):
        im = Image.open(os.path.join(LAYERS, name + ".png")).convert("RGBA")
        data = im.load()
        for y in range(size[1]):
            for x in range(size[0]):
                r, g, b, a = data[x, y]
                if a > 127:
                    px[(x, y)] = (PARTS[round(r / 20)], g / 100.0, li, col)
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    o = out.load()
    for (x, y), (part, k, li, col) in px.items():
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if nx // CELL[0] != x // CELL[0] or ny // CELL[1] != y // CELL[1]:
                continue
            n = px.get((nx, ny))
            if n and n[2] > li and n[0] != part and part not in ("eye", "mouth", "blush") and n[0] not in ("eye", "mouth", "blush", "white", "red"):
                k = 0.55
                break
        if part == "main":
            c = rgb(col)
        elif part == "trim":
            c = trim_of(rgb(col))
        elif part == "skin":
            c = rgb(look["skin"])
        elif part == "hair":
            c = rgb(look["hair_color"])
        else:
            c = rgb(FIXED[part])
        o[x, y] = tuple(min(255, int(v * k)) for v in c) + (255,)
    final = out.copy()
    f = final.load()
    for y in range(size[1]):
        for x in range(size[0]):
            if o[x, y][3]:
                continue
            for dx, dy in ((0, 1), (1, 0), (-1, 0), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < size[0] and 0 <= ny < size[1] and nx // CELL[0] == x // CELL[0] and ny // CELL[1] == y // CELL[1] and o[nx, ny][3]:
                    f[x, y] = tuple(int(v * 0.25) for v in o[nx, ny][:3]) + (255,)
                    break
    return final


def main():
    items = {slot: {} for slot in NAMES}
    for slot, names in NAMES.items():
        for item, name in names.items():
            items[slot][item] = {"name": name, "price": SHOP_PRICES.get(item, SPECIAL.get(item, PRICES[slot])),
                                 "colors": [] if item in EARNED else list(EXTRA.get(item, []))}
            if item in EARNED:
                items[slot][item]["earn"] = True  # Only in a trainer class outfit.
            if item in SHOP[slot]:
                items[slot][item]["new"] = True
    slots = ["hat", "top", "bottom", "shoes"]
    sets = []
    for sid, name, pieces, ways in SETS:
        variants = []
        for wname, cols in ways.items():
            for slot, item, c in zip(slots, pieces, cols):
                if item and c not in items[slot][item]["colors"]:
                    items[slot][item]["colors"].append(c)
            variants.append({"name": wname, "colors": cols})
        price = int(sum(items[s][p]["price"] for s, p in zip(slots, pieces) if p) * 0.8)
        entry = {"id": sid, "name": name, "pieces": pieces, "variants": variants, "price": price}
        if sid in CLASS_HAIR:
            # A trainer class's outfit: earned by beating CLASS_WINS of them, every colourway at once.
            entry = {"id": sid, "name": name, "pieces": pieces, "variants": variants, "earn": sid, "wins": CLASS_WINS}
        sets.append(entry)
    for slot, item in (("hat", "rocket_cap"), ("top", "rocket")):
        items[slot][item]["colors"] = [10, 5]
        items[slot][item]["unlock"] = "rocket"
    rocket_sets = []
    for sid, name, c in ROCKET:
        rocket_sets.append({"id": sid, "name": name, "pieces": ["rocket_cap", "rocket", "trousers", "boots"],
                            "variants": [{"name": name, "colors": [c, c, c, c]}], "unlock": "rocket"})
        for slot, item in (("bottom", "trousers"), ("shoes", "boots")):
            if c not in items[slot][item]["colors"]:
                items[slot][item]["colors"].append(c)
    data = {
        "_comment": "Built by tools/build_outfits.py. Prices in Pokédollars; colours are indices into colors. Every item colour is a separate purchase. Sets give their four pieces in one colourway. Sets with earn: <class> are a trainer class's outfit, given (every colourway) for beating wins trainers of that class; items with earn: true only come that way. Items or sets with unlock: rocket come from the Rocket Hideout, not the shop.",
        "colors": COLORS, "skins": SKINS, "hair_colors": HAIR_COLORS, "hairs": HAIRS,
        "genders": ["boy", "girl"],
        "default": {"gender": "boy", "skin": 1, "hair": "short", "hair_color": 1, "hat": ["cap", 0], "top": ["jacket", 1], "bottom": ["trousers", 9], "shoes": ["sneakers", 0]},
        "items": items, "sets": sets + rocket_sets,
        "class_looks": {cid: {"set": cid, "hair": hair} for cid, hair in CLASS_HAIR.items()},
    }
    json.dump(data, open(os.path.join(ROOT, "data", "outfits.json"), "w"), indent="\t", ensure_ascii=False)
    # Finished sheets for the fixed looks.
    os.makedirs(LOOKS, exist_ok=True)
    by_id = {s["id"]: s for s in data["sets"]}
    looks = dict(STAFF)
    for cid, hair in CLASS_HAIR.items():
        s = by_id[cid]
        cols = s["variants"][0]["colors"]
        pieces = s["pieces"]
        looks["class_" + cid] = {"gender": "girl" if cid in GIRLS else "boy", "skin": SKINS[[1, 2, 4, 6][sum(map(ord, cid)) % 4]], "hair": hair, "hair_color": HAIR_COLORS[len(cid) % 6],
                                 "hat": [pieces[0], COLORS[cols[0]]] if pieces[0] else None, "top": [pieces[1], COLORS[cols[1]]],
                                 "bottom": [pieces[2], COLORS[cols[2]]], "shoes": [pieces[3], COLORS[cols[3]]]}
    for sid, _, c in ROCKET:
        looks[sid] = {"skin": "#f0c496", "hair": "short", "hair_color": "#704020" if c == 10 else "#c84830", "hat": ["rocket_cap", COLORS[c]],
                      "top": ["rocket", COLORS[c]], "bottom": ["trousers", COLORS[c]], "shoes": ["boots", COLORS[c]]}
    for lid, look in looks.items():
        compose(look).save(os.path.join(LOOKS, lid + ".png"))
    print("%d items, %d sets, %d looks" % (sum(len(v) for v in items.values()), len(data["sets"]), len(looks)))


if __name__ == "__main__":
    main()
