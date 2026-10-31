"""Shrinks the built-in maps by removing pairs of rows and columns (a line and its
mirror twin, so the map stays symmetric for both teams).

    python3 tools/shrink_maps.py 3 3        # drop 3 column pairs and 3 row pairs

It drops the lines that lose the least: open floor, or a line that repeats its
neighbour. Lines with spawns, goals, the hill zone, Showdown spawns or crates,
hazards, and the outer two lines are never removed. Removed lines are kept at
least two apart, so no wall or bush disappears entirely.
"""
import glob, json, os, re, sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
KEEP = set("12GZSPFO")


def line_cost(lines, i):
    """How much is lost by removing line i (lines: list of strings)."""
    line = lines[i]
    if KEEP & set(line):
        return 10_000
    prev, nxt = lines[i - 1], lines[i + 1]
    lost = 0
    for k, c in enumerate(line):
        if c == ".":
            continue
        if c != prev[k] and c != nxt[k]:
            lost += 3  # A one-line-thin feature would vanish.
        else:
            lost += 0.4
    return lost


def pick(lines, count):
    n = len(lines)
    costs = []
    for i in range(2, n // 2):
        mirror = n - 1 - i
        if mirror <= i:
            continue
        costs.append((line_cost(lines, i) + line_cost(lines, mirror), i))
    costs.sort()
    chosen = []
    for cost, i in costs:
        if cost >= 10_000:
            break
        if any(abs(i - j) < 2 for j in chosen):
            continue
        chosen.append(i)
        if len(chosen) == count:
            break
    drop = set(chosen) | {n - 1 - i for i in chosen}
    return drop


def shrink(rows, col_pairs, row_pairs):
    width = max(len(r) for r in rows)
    rows = [r.ljust(width, ".") for r in rows]
    cols = ["".join(r[x] for r in rows) for x in range(width)]
    drop_cols = pick(cols, col_pairs)
    cols = [c for x, c in enumerate(cols) if x not in drop_cols]
    rows = ["".join(c[y] for c in cols) for y in range(len(rows))]
    drop_rows = pick(rows, row_pairs)
    rows = [r for y, r in enumerate(rows) if y not in drop_rows]
    return rows, len(drop_cols) // 2, len(drop_rows) // 2


def main():
    col_pairs = int(sys.argv[1]) if len(sys.argv) > 1 else 3
    row_pairs = int(sys.argv[2]) if len(sys.argv) > 2 else 3
    for path in sorted(glob.glob(os.path.join(ROOT, "data", "arenas", "*.json"))):
        text = open(path).read()
        data = json.loads(text)
        new_rows, dc, dr = shrink(data["map"], col_pairs, row_pairs)
        # Rewrite just the map block, keeping the rest of the file as it was.
        block = "\t\"map\": [\n" + ",\n".join("\t\t\"%s\"" % r.replace("\\", "\\\\").replace('"', '\\"') for r in new_rows) + "\n\t]"
        text2 = re.sub(r'\t"map": \[\n.*?\n\t\]', lambda m: block, text, count=1, flags=re.S)
        json.loads(text2)
        open(path, "w").write(text2)
        print("%-22s %dx%d -> %dx%d (dropped %d col pairs, %d row pairs)" % (os.path.basename(path), len(data["map"][0]),
                len(data["map"]), len(new_rows[0]), len(new_rows), dc, dr))


if __name__ == "__main__":
    main()
