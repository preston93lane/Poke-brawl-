"""Lays out the town hub: the ground map (same characters as the arenas: . grass,
, path, T tree, " tall grass, ~ water) plus where each building stands.

    python3 tools/build_town_map.py   ->   data/town_map.json

Buildings are rectangles of cells (x, y, w, h). Every door faces the camera
(the middle of the bottom edge, like the handheld games), so three streets run
across town under each row of buildings, joined by the plaza and two lanes.
scripts/town/town_world.gd builds the 3D town from this.
"""
import json, os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
W, H = 36, 32
BUILDINGS = [
    # id, x, y, w, h
    ("center", 3, 3, 6, 5),
    ("arena", 12, 1, 12, 7),
    ("dept", 27, 1, 6, 7),
    ("mart", 3, 12, 6, 4),
    ("corner", 27, 12, 6, 4),
    ("daycare", 3, 21, 6, 4),
    ("outfitter", 12, 21, 7, 4),
    ("museum", 27, 21, 6, 4),
]
PLAZA = (18, 14)  # Centre of the fountain.
STREETS = [  # x0, y0, x1, y1 (inclusive): paved rectangles
    (4, 9, 31, 10),    # Under the top row.
    (4, 17, 31, 18),   # Under the middle row.
    (4, 26, 31, 27),   # Under the bottom row.
    (9, 18, 10, 26),   # Lane down the west side.
    (22, 18, 23, 26),  # Lane down the east side.
]


def main():
    grid = [["." for _ in range(W)] for _ in range(H)]
    for y in range(H):
        for x in range(W):
            if x < 2 or y < 1 or x >= W - 2 or y >= H - 2:
                grid[y][x] = "T"
    for (x, y) in [(2, 1), (2, 19), (33, 15), (2, 29), (33, 29), (11, 29), (24, 29)]:
        grid[y][x] = "T"
    for (x0, y0, x1, y1) in STREETS:
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                grid[y][x] = ","
    px, py = PLAZA
    for y in range(H):
        for x in range(W):
            d = ((x + 0.5 - px) ** 2 + (y + 0.5 - py) ** 2) ** 0.5
            if d < 4.6:
                grid[y][x] = ","
            if d < 1.9:
                grid[y][x] = "~"
    # Door steps: from each door down to its street.
    for (bid, x, y, w, h) in BUILDINGS:
        dx = x + w // 2 - 1
        yy = y + h
        while yy < H and grid[yy][dx] != ",":
            grid[yy][dx] = grid[yy][dx + 1] = ","
            yy += 1
    # Flower meadows of tall grass on the green.
    for (x0, y0, x1, y1) in [(10, 12, 12, 14), (24, 12, 25, 14), (13, 19, 16, 20), (25, 19, 26, 20), (5, 19, 7, 20), (29, 28, 31, 28)]:
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if grid[y][x] == ".":
                    grid[y][x] = '"'
    for (bid, x, y, w, h) in BUILDINGS:
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                grid[yy][xx] = "."
    data = {
        "name": "Town", "floor": "grass", "modes": ["town"],
        "map": ["".join(r) for r in grid],
        "buildings": [{"id": b[0], "x": b[1], "y": b[2], "w": b[3], "h": b[4]} for b in BUILDINGS],
        "plaza": list(PLAZA),
        "trainer_spots": [[11, 10], [26, 10], [7, 18], [28, 18], [20, 26], [14, 26]],
    }
    out = os.path.join(ROOT, "data", "town_map.json")
    json.dump(data, open(out, "w"), indent="\t")
    print("\n".join(data["map"]))


if __name__ == "__main__":
    main()
