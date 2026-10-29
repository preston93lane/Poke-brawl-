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

# Pieces: (row, col, height, width, tile) rectangles on the left side, mirrored
# to the right; later pieces draw over earlier ones (grass first, then walls).
# Rows count from 1 (top edge of the map's inside), columns from 0.
LAYOUTS = {
    "crossfire": [
        (5, 2, 3, 6, "g"), (6, 3, 2, 4, "W"),
        (7, 13, 1, 4, "C"),
        (10, 0, 4, 5, "g"), (11, 0, 2, 3, "W"),
        (9, 8, 5, 4, "g"), (11, 10, 2, 5, "W"),
        (15, 4, 5, 5, "g"), (15, 4, 5, 2, "W"), (15, 6, 1, 3, "W"),
        (17, 14, 2, 3, "W"),
        (19, 10, 4, 3, "g"), (20, 10, 2, 2, "W"),
        (20, 0, 3, 4, "g"),
    ],
    "bushwhack": [
        (4, 0, 5, 7, "g"), (6, 2, 2, 3, "W"),
        (6, 14, 1, 2, "C"),
        (9, 9, 6, 6, "g"), (10, 10, 2, 4, "W"), (12, 13, 2, 1, "W"),
        (13, 0, 6, 4, "g"), (16, 0, 2, 2, "W"),
        (16, 13, 2, 4, "g"), (16, 15, 1, 2, "W"),
        (19, 5, 5, 5, "g"), (20, 6, 2, 2, "W"), (21, 8, 1, 1, "C"),
    ],
    "ponds": [
        (5, 2, 2, 5, "w"),
        (5, 11, 3, 3, "g"), (6, 11, 2, 2, "W"), (6, 15, 1, 2, "C"),
        (9, 16, 1, 1, "F"),
        (10, 0, 4, 4, "g"), (11, 0, 2, 2, "W"),
        (10, 8, 3, 6, "w"), (13, 8, 2, 6, "g"),
        (14, 2, 1, 1, "F"),
        (16, 4, 5, 4, "g"), (16, 4, 5, 2, "W"),
        (17, 14, 2, 3, "W"),
        (19, 10, 2, 4, "w"), (21, 10, 2, 4, "g"),
        (21, 0, 3, 3, "g"),
    ],
    "rooms": [
        (4, 3, 4, 6, "g"), (5, 3, 2, 6, "W"),
        (5, 13, 1, 2, "C"),
        (9, 9, 4, 5, "g"), (9, 9, 2, 8, "W"),
        (10, 0, 4, 3, "g"), (11, 0, 2, 2, "W"),
        (13, 4, 1, 1, "O"),
        (14, 5, 5, 5, "g"), (14, 5, 5, 2, "W"), (18, 5, 1, 5, "W"),
        (15, 14, 3, 3, "g"), (16, 15, 2, 2, "W"),
        (20, 0, 4, 4, "g"), (21, 0, 2, 2, "W"),
        (20, 10, 3, 3, "g"), (21, 11, 2, 1, "W"),
    ],
    "rivers": [
        (4, 1, 3, 5, "g"), (5, 2, 2, 3, "W"),
        (7, 12, 1, 2, "C"),
        (9, 0, 2, 9, "w"), (11, 2, 2, 6, "g"),
        (9, 12, 4, 3, "g"), (9, 12, 3, 1, "W"),
        (14, 15, 2, 2, "w"), (13, 11, 4, 3, "g"),
        (16, 3, 4, 4, "g"), (16, 3, 2, 2, "W"),
        (19, 8, 2, 5, "w"), (21, 8, 2, 5, "g"),
        (21, 0, 3, 3, "g"), (22, 0, 2, 1, "W"),
    ],
    "field": [
        (4, 0, 4, 5, "g"),
        (6, 9, 3, 3, "g"), (6, 9, 2, 2, "W"), (6, 15, 1, 2, "C"),
        (10, 3, 4, 8, "g"), (11, 3, 2, 5, "W"),
        (12, 13, 2, 4, "g"), (14, 13, 1, 4, "W"),
        (16, 0, 6, 3, "g"), (17, 0, 3, 1, "W"),
        (17, 7, 4, 4, "g"), (18, 8, 2, 2, "W"),
        (21, 12, 2, 1, "C"),
    ],
}

# arena -> (layout, wall, breakable, liquid or None, has goals)
THEMES = {
    "pewter_gym": ("crossfire", "#", "B", None, False),
    "vermilion_gym": ("crossfire", "#", "X", None, True),
    "bruno_dojo": ("crossfire", "#", "B", None, True),
    "celadon_gym": ("bushwhack", "T", "X", None, False),
    "route_1": ("bushwhack", "T", "X", "~", False),
    "lavender_graveyard": ("bushwhack", "K", "X", None, False),
    "cerulean_gym": ("ponds", "#", "X", "~", False),
    "cinnabar_gym": ("ponds", "#", "B", "~", False),
    "fuchsia_gym": ("rooms", "#", "X", None, False),
    "saffron_gym": ("rooms", "#", "X", None, False),
    "agatha_crypt": ("rooms", "K", "X", None, False),
    "lorelei_chamber": ("rivers", "#", "I", "~", False),
    "lance_hall": ("rivers", "#", "B", "~", False),
    "dragons_den": ("rivers", "#", "B", "~", False),
    "boulder_gym": ("field", "#", "B", None, False),
    "viridian_gym": ("field", "#", "B", None, False),
    "safari_zone": ("field", "T", "T", "~", False),
}


def build(arena, layout, wall, brk, liquid, goals):
    top = [["."] * W for _ in range(H)]
    for r, c, h, w, ch in LAYOUTS[layout]:
        for y in range(r, r + h):
            for x in range(c, c + w):
                top[y - 1][x] = ch
                top[y - 1][W - 1 - x] = ch
    # Spawns, zone and goals.
    for c in (13, 16, 20):
        top[2][c] = "2"
    for r in (21, 22):
        for c in range(15, 19):
            top[r][c] = "Z"
    if goals:
        for r in (0, 1):
            for c in range(12, 22):
                top[r][c] = "W" if c in (12, 21) else "G"
    sub = {"W": wall, "C": brk, "g": '"', "w": liquid or wall,
           "F": "F" if arena == "cinnabar_gym" else ".", "O": "O" if arena == "saffron_gym" else "."}
    rows = ["".join(sub.get(ch, ch) for ch in row) for row in top]
    bottom = ["".join(reversed(row)).replace("2", "1") for row in reversed(rows)]
    border = wall if wall in "#T" else "#"
    inner = rows + bottom
    return [border * (W + 2)] + [border + row + border for row in inner] + [border * (W + 2)]


def check(arena, m):
    import collections
    blocked = set("#TKXBIP~")
    hgt, wid = len(m), len(m[0])
    start = next((x, y) for y in range(hgt) for x in range(wid) if m[y][x] == "1")
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
            if m[y][x] in "12Z" and (x, y) not in seen:
                raise SystemExit(f"{arena}: {m[y][x]} at {x},{y} can't be reached")
    cells = "".join(r[1:-1] for r in m[1:-1])
    n = len(cells)
    solid = sum(cells.count(c) for c in "#TKXBI~")
    grass = cells.count('"')
    print(f"{arena:20s} solid {100 * solid / n:4.1f}%  grass {100 * grass / n:4.1f}%")


def main():
    for arena, theme in THEMES.items():
        path = os.path.join(ROOT, "data", "arenas", arena + ".json")
        data = json.load(open(path))
        m = build(arena, *theme)
        check(arena, m)
        data["map"] = m
        text = json.dumps(data, indent="\t", ensure_ascii=False)
        open(path, "w").write(text + "\n")


if __name__ == "__main__":
    main()
