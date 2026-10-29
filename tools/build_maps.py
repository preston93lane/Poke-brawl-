"""Builds the 3v3 arena maps from a few Brawl Stars-style layouts.

    python3 tools/build_maps.py

Each layout is the top half of a 36 x 48 map (inside the border), placed
as pieces on the left side and mirrored left-right; the bottom half is the
top half turned 180 degrees, so both teams get the same map. Pieces use
abstract tiles that each arena's theme turns into its own:

    W wall    C breakable    g tall grass    w liquid (water / lava; walls if none)
    F fire vent (cinnabar)   O warp pad (saffron)   . open

Brawl Stars rules of thumb: a few big clusters (L shapes, short bars) rather
than many small blocks; grass hugging the walls for ambushes; open lanes
down the sides; an open, dangerous middle; some cover in front of spawns.
Only the "map" of each arena file is rewritten.
"""
import json, os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
W, H = 34, 23  # Inside width, top-half height (rows 1..23).

# Each arena has its own layout: pieces are (row, col, height, width, tile)
# rectangles on the left side, mirrored to the right; later pieces draw over
# earlier ones (grass first, then walls). Rows count from 1 (top edge of the
# map's inside), columns from 0. Tiles: W wall, C breakable, g grass, w liquid,
# F vent, O warp, S showdown spawn, P crate; any other map tile (T, K, ",")
# is used as is.
ARENAS = {
    # Brock: a rocky quarry. Big boulder clusters, almost no grass, no water.
    "pewter_gym": dict(wall="#", brk="B", pieces=[
        (5, 4, 2, 3, "W"), (5, 7, 1, 2, "W"), (6, 13, 1, 3, "C"),
        (9, 0, 2, 4, "W"), (10, 9, 3, 2, "W"), (12, 9, 1, 4, "W"),
        (14, 15, 2, 2, "C"), (15, 3, 1, 3, "g"), (16, 3, 3, 3, "W"),
        (19, 8, 2, 2, "W"), (19, 13, 1, 2, "C"), (21, 0, 2, 2, "g"), (22, 5, 2, 3, "W"),
    ]),
    # Misty: pools to swim across, walls and grass around the deck.
    "cerulean_gym": dict(wall="#", brk="X", liquid="~", pieces=[
        (5, 1, 2, 6, "w"), (5, 11, 3, 2, "W"), (5, 13, 2, 1, "g"), (6, 15, 1, 2, "C"),
        (9, 4, 5, 3, "w"), (9, 7, 2, 2, "g"),
        (10, 12, 2, 5, "w"), (12, 12, 1, 3, "g"),
        (13, 0, 3, 2, "g"), (15, 8, 4, 1, "g"), (15, 9, 2, 4, "W"), (17, 9, 2, 1, "W"),
        (19, 2, 2, 5, "w"), (21, 2, 1, 5, "g"), (20, 13, 2, 2, "C"),
    ]),
    # Lt. Surge: a metal hall of crates (breakable) with goals for Brawl Ball.
    "vermilion_gym": dict(wall="#", brk="X", goals=True, pieces=[
        (6, 2, 2, 2, "C"), (6, 6, 2, 2, "C"),
        (9, 0, 1, 5, "W"), (10, 0, 2, 5, "g"),
        (9, 10, 2, 4, "C"), (11, 10, 1, 4, "g"),
        (13, 5, 2, 2, "W"), (13, 7, 2, 2, "g"),
        (15, 14, 2, 3, "C"),
        (17, 1, 2, 4, "C"), (18, 9, 2, 2, "W"), (18, 11, 2, 2, "g"),
        (20, 5, 1, 3, "g"), (21, 5, 2, 3, "W"),
    ]),
    # Erika: a garden of hedges wrapped in tall grass.
    "celadon_gym": dict(wall="T", brk="X", pieces=[
        (4, 0, 4, 8, "g"), (5, 2, 2, 4, "W"), (6, 13, 2, 4, "g"),
        (9, 6, 6, 3, "g"), (10, 7, 4, 1, "W"),
        (9, 12, 2, 5, "g"), (11, 12, 1, 5, "W"),
        (14, 0, 5, 3, "g"), (15, 0, 3, 1, "W"),
        (15, 11, 4, 6, "g"), (17, 14, 1, 3, "W"),
        (19, 4, 4, 5, "g"), (20, 5, 2, 2, "W"), (22, 10, 2, 3, "g"),
    ]),
    # Koga: thin dojo screens with grass ambushes behind them.
    "fuchsia_gym": dict(wall="#", brk="X", pieces=[
        (4, 3, 1, 7, "g"), (5, 3, 1, 7, "W"), (6, 15, 2, 2, "C"),
        (8, 10, 4, 1, "W"), (8, 11, 4, 2, "g"),
        (10, 0, 1, 6, "W"), (11, 0, 2, 6, "g"),
        (13, 13, 1, 4, "g"), (14, 13, 1, 4, "W"),
        (16, 2, 4, 1, "W"), (16, 3, 4, 2, "g"),
        (18, 9, 1, 5, "W"), (19, 9, 1, 5, "g"), (21, 4, 2, 2, "C"),
    ]),
    # Sabrina: blocky rooms joined by warp pads.
    "saffron_gym": dict(wall="#", brk="X", pieces=[
        (5, 5, 2, 5, "W"), (7, 5, 1, 5, "g"), (5, 14, 1, 2, "C"),
        (9, 1, 1, 1, "O"),
        (10, 10, 3, 2, "W"), (10, 12, 1, 3, "W"), (11, 12, 2, 3, "g"),
        (12, 2, 2, 3, "g"), (14, 2, 1, 3, "W"),
        (15, 7, 1, 1, "O"),
        (16, 13, 1, 2, "g"), (17, 13, 2, 2, "W"),
        (19, 3, 3, 2, "W"), (19, 5, 3, 2, "g"), (22, 9, 2, 2, "C"),
    ]),
    # Blaine: volcanic rock and fire vents, a little lava, hardly any grass.
    "cinnabar_gym": dict(wall="#", brk="B", liquid="~", pieces=[
        (5, 3, 2, 3, "W"), (6, 13, 1, 4, "C"), (8, 8, 1, 1, "F"),
        (9, 0, 2, 3, "w"), (10, 10, 2, 4, "W"), (12, 10, 1, 1, "W"),
        (13, 4, 1, 1, "F"), (14, 15, 1, 2, "W"),
        (16, 5, 3, 2, "W"), (16, 7, 1, 2, "W"), (17, 12, 1, 1, "F"),
        (19, 0, 1, 2, "g"), (20, 9, 2, 3, "W"), (22, 2, 1, 2, "w"),
    ]),
    # Giovanni: sandy dunes, boulders and rock ridges.
    "viridian_gym": dict(wall="#", brk="B", pieces=[
        (5, 2, 1, 5, "W"), (6, 2, 1, 2, "W"), (6, 14, 2, 2, "C"),
        (9, 6, 2, 6, "g"), (10, 6, 1, 4, "W"),
        (12, 0, 4, 2, "W"), (12, 2, 4, 2, "g"),
        (13, 13, 2, 4, "W"), (15, 13, 1, 4, "g"),
        (17, 6, 3, 2, "W"), (17, 8, 3, 2, "g"), (20, 11, 2, 3, "C"), (21, 0, 2, 4, "g"),
    ]),
    # Brock's old boulder hall: open field, boulders and bushes.
    "boulder_gym": dict(wall="#", brk="B", pieces=[
        (4, 0, 4, 5, "g"),
        (6, 9, 3, 3, "g"), (6, 9, 2, 2, "W"), (6, 15, 1, 2, "C"),
        (10, 3, 4, 8, "g"), (11, 3, 2, 5, "W"),
        (12, 13, 2, 4, "g"), (14, 13, 1, 4, "W"),
        (16, 0, 6, 3, "g"), (17, 0, 3, 1, "W"),
        (17, 7, 4, 4, "g"), (18, 8, 2, 2, "W"), (21, 12, 2, 1, "C"),
    ]),
    # Bruno: a training hall with a long bar and punching posts; goals for Brawl Ball.
    "bruno_dojo": dict(wall="#", brk="B", goals=True, pieces=[
        (5, 3, 2, 2, "W"), (5, 5, 2, 2, "g"), (6, 13, 1, 2, "C"),
        (8, 8, 1, 6, "g"), (9, 8, 1, 8, "W"),
        (12, 0, 3, 3, "g"), (13, 0, 1, 3, "W"), (13, 11, 3, 2, "C"),
        (16, 4, 2, 4, "W"), (18, 4, 1, 4, "g"), (19, 14, 2, 2, "W"), (21, 8, 2, 3, "g"),
    ]),
    # Agatha: rows of gravestones in creeping grass.
    "agatha_crypt": dict(wall="K", brk="X", pieces=[
        (4, 1, 3, 7, "g"), (5, 2, 1, 1, "W"), (5, 4, 1, 1, "W"), (5, 6, 1, 1, "W"), (6, 15, 1, 2, "C"),
        (8, 11, 3, 4, "g"), (9, 12, 1, 2, "W"),
        (11, 0, 4, 4, "g"), (12, 1, 1, 1, "W"), (13, 2, 1, 1, "W"),
        (14, 7, 1, 6, "g"), (15, 7, 1, 6, "W"), (17, 0, 1, 2, "C"),
        (18, 3, 2, 2, "W"), (18, 12, 3, 3, "g"), (19, 13, 1, 1, "W"), (21, 6, 2, 3, "g"),
    ]),
    # Lorelei: a frozen lake, ice blocks to smash.
    "lorelei_chamber": dict(wall="#", brk="I", liquid="~", pieces=[
        (5, 3, 2, 4, "C"), (8, 0, 3, 4, "w"), (8, 10, 3, 6, "w"), (11, 9, 1, 3, "g"),
        (14, 4, 2, 2, "W"), (14, 6, 2, 2, "g"), (16, 12, 1, 4, "C"),
        (19, 0, 2, 3, "g"), (19, 8, 3, 3, "w"), (22, 4, 2, 2, "C"),
    ]),
    # Lance: stone pillars and water channels.
    "lance_hall": dict(wall="#", brk="B", liquid="~", pieces=[
        (5, 5, 2, 2, "W"), (5, 11, 2, 2, "W"),
        (9, 0, 1, 7, "w"), (9, 13, 3, 2, "W"), (9, 15, 3, 2, "g"),
        (12, 4, 3, 2, "g"), (13, 4, 2, 1, "W"), (15, 9, 2, 2, "W"),
        (17, 0, 1, 7, "w"), (17, 14, 2, 3, "C"),
        (20, 4, 2, 2, "W"), (20, 6, 2, 2, "g"), (22, 11, 2, 2, "W"),
    ]),
    # Dragon's Den: rivers across the cave with grassy banks.
    "dragons_den": dict(wall="#", brk="B", liquid="~", pieces=[
        (4, 1, 3, 5, "g"), (5, 2, 2, 3, "W"), (7, 12, 1, 2, "C"),
        (9, 0, 2, 9, "w"), (11, 2, 2, 6, "g"),
        (9, 12, 4, 3, "g"), (9, 12, 3, 1, "W"),
        (14, 15, 2, 2, "w"), (13, 11, 4, 3, "g"),
        (16, 3, 4, 4, "g"), (16, 3, 2, 2, "W"),
        (19, 8, 2, 5, "w"), (21, 8, 2, 5, "g"), (21, 0, 3, 3, "g"), (22, 0, 2, 1, "W"),
    ]),
    # Pokémon Tower graveyard: graves, dead trees, fog-grass.
    "lavender_graveyard": dict(wall="K", brk="X", pieces=[
        (4, 2, 2, 5, "g"), (5, 3, 1, 1, "W"), (5, 5, 1, 1, "W"), (6, 14, 1, 2, "C"),
        (8, 9, 2, 2, "T"), (10, 9, 2, 3, "g"),
        (11, 0, 2, 3, "T"), (13, 0, 3, 3, "g"),
        (13, 13, 3, 4, "g"), (14, 14, 1, 1, "W"), (14, 16, 1, 1, "W"),
        (17, 5, 1, 5, "W"), (16, 5, 1, 5, "g"),
        (20, 1, 2, 2, "T"), (20, 10, 3, 3, "g"), (21, 11, 1, 1, "W"),
    ]),
    # Route 1: a dirt path up the middle, trees and big patches of tall grass.
    "route_1": dict(wall="T", brk="X", liquid="~", border="T", pieces=[
        (4, 0, 5, 6, "g"), (4, 6, 2, 2, "W"), (1, 16, 23, 1, ","),
        (6, 11, 3, 4, "g"), (8, 12, 1, 2, "W"),
        (10, 3, 5, 5, "g"), (12, 3, 1, 2, "W"),
        (14, 11, 3, 3, "g"), (13, 11, 1, 3, "W"),
        (16, 0, 2, 2, "W"), (18, 0, 4, 5, "g"), (19, 7, 2, 2, "w"),
        (21, 11, 3, 3, "g"), (20, 12, 1, 1, "C"),
    ]),
    # Safari Zone: huge fields of tall grass, trees and ponds.
    "safari_zone": dict(wall="T", brk="T", liquid="~", border="T", pieces=[
        (4, 0, 6, 8, "g"), (5, 2, 1, 2, "W"),
        (5, 11, 4, 5, "g"), (6, 13, 1, 1, "W"),
        (10, 9, 2, 3, "w"), (12, 8, 4, 6, "g"),
        (11, 0, 6, 5, "g"), (13, 4, 2, 1, "W"),
        (16, 14, 5, 3, "g"), (17, 15, 1, 2, "W"),
        (18, 5, 6, 6, "g"), (20, 0, 2, 3, "w"), (19, 7, 1, 2, "W"),
    ]),
    # Pallet Pitch (Brawl Ball): an open pitch with bush-and-wall pockets on the wings.
    "pallet_pitch": dict(wall="#", brk="X", goals=True, pieces=[
        (5, 1, 3, 5, "g"), (6, 1, 1, 3, "W"), (6, 12, 1, 4, "C"),
        (9, 6, 4, 3, "g"), (10, 6, 2, 1, "W"),
        (12, 12, 2, 5, "g"), (12, 12, 1, 2, "W"),
        (14, 0, 2, 2, "W"), (14, 2, 2, 2, "g"),
        (17, 7, 1, 4, "W"), (18, 7, 2, 4, "g"), (17, 15, 1, 2, "C"),
        (21, 0, 3, 4, "g"), (22, 0, 1, 2, "W"),
    ]),
    # The S.S. Anne's deck: open sea along both sides (railings break), cabins and cargo.
    "ss_anne": dict(wall="#", brk="X", liquid="~", goals=True, showdown_spots=True, pieces=[
        (1, 0, 23, 2, "w"), (1, 2, 23, 1, "W"), (7, 2, 1, 1, "C"), (15, 2, 1, 1, "C"), (21, 2, 1, 1, "C"),
        (5, 6, 2, 4, "W"), (7, 6, 1, 4, "g"), (6, 14, 1, 3, "C"),
        (4, 4, 1, 1, "P"), (8, 4, 1, 1, "S"),
        (10, 10, 3, 2, "W"), (10, 12, 1, 3, "W"), (11, 12, 2, 3, "g"), (12, 15, 1, 1, "P"),
        (13, 4, 2, 3, "g"), (15, 4, 1, 3, "W"), (16, 8, 1, 1, "S"),
        (18, 12, 2, 2, "C"), (19, 4, 3, 2, "g"), (19, 6, 1, 2, "W"), (21, 9, 1, 1, "P"), (22, 4, 1, 1, "S"),
    ]),
    # Viridian Forest (Showdown): trees, big grass patches and crates; spawns around the edge.
    "viridian_forest": dict(wall="T", brk="X", liquid="~", border="T", showdown=True, pieces=[
        (2, 2, 3, 4, "g"), (3, 3, 1, 1, "S"), (3, 13, 1, 1, "P"),
        (5, 8, 2, 3, "W"), (7, 8, 2, 4, "g"), (4, 15, 1, 2, "C"),
        (9, 1, 1, 1, "P"), (10, 4, 4, 4, "g"), (11, 5, 2, 1, "W"),
        (12, 1, 1, 1, "S"), (12, 12, 3, 5, "g"), (13, 14, 1, 2, "W"), (11, 16, 1, 1, "P"),
        (16, 2, 2, 3, "C"), (16, 8, 1, 1, "P"),
        (18, 6, 4, 5, "g"), (19, 7, 2, 2, "W"), (20, 13, 2, 3, "w"),
        (21, 1, 1, 1, "S"), (22, 15, 1, 1, "P"),
    ]),
}


def build(arena, spec):
    top = [["."] * W for _ in range(H)]
    for r, c, h, w, ch in spec["pieces"]:
        for y in range(r, r + h):
            for x in range(c, c + w):
                top[y - 1][x] = ch
                top[y - 1][W - 1 - x] = ch
    if not spec.get("showdown"):
        for c in (13, 16, 20):
            top[2][c] = "2"
        for r in (21, 22):
            for c in range(15, 19):
                top[r][c] = "Z"
    if spec.get("goals"):
        for r in (0, 1):
            for c in range(12, 22):
                top[r][c] = "W" if c in (12, 21) else "G"
    wall = spec["wall"]
    liquid = spec.get("liquid")
    sub = {"W": wall, "C": spec["brk"], "g": '"', "w": liquid or wall,
           "F": "F" if arena == "cinnabar_gym" else ".", "O": "O" if arena == "saffron_gym" else "."}
    rows = ["".join(sub.get(ch, ch) for ch in row) for row in top]
    bottom = ["".join(reversed(row)).replace("2", "1") for row in reversed(rows)]
    border = spec.get("border", "#")
    inner = rows + bottom
    return [border * (W + 2)] + [border + row + border for row in inner] + [border * (W + 2)]


def check(arena, m):
    import collections
    blocked = set("#TKXBIP~")
    hgt, wid = len(m), len(m[0])
    start = next((x, y) for y in range(hgt) for x in range(wid) if m[y][x] in "1S")
    seen = {start}
    todo = collections.deque([start])
    while todo:
        x, y = todo.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if 0 <= n[0] < wid and 0 <= n[1] < hgt and n not in seen and m[n[1]][n[0]] not in blocked:
                seen.add(n)
                todo.append(n)
    for y in range(hgt):
        for x in range(wid):
            if m[y][x] in "12ZSG" and (x, y) not in seen:
                raise SystemExit(f"{arena}: {m[y][x]} at {x},{y} can't be reached")
    cells = "".join(r[1:-1] for r in m[1:-1])
    n = len(cells)
    solid = sum(cells.count(c) for c in "#TKXBI~")
    grass = cells.count('"')
    print(f"{arena:20s} solid {100 * solid / n:4.1f}%  grass {100 * grass / n:4.1f}%")


def main():
    for arena, spec in ARENAS.items():
        path = os.path.join(ROOT, "data", "arenas", arena + ".json")
        data = json.load(open(path))
        m = build(arena, spec)
        check(arena, m)
        data["map"] = m
        text = json.dumps(data, indent="\t", ensure_ascii=False)
        open(path, "w").write(text + "\n")


if __name__ == "__main__":
    main()
