"""Builds the progression data from the main-series games (PokeAPI CSVs).

    python3 tools/build_progression.py <pokeapi_csv_dir>

<pokeapi_csv_dir> holds pokemon_species.csv, pokemon_moves.csv and moves.csv
from the PokeAPI repository (data/v2/csv).

- Main attack variants: the first is known from the start. The other two unlock
  at a profile level, from the level the line learns that move by levelling up
  in the games (spaced out, see MAIN_LEVELS), or earlier with its TM if the move
  is a TM in any game the line can use it in. Writes "level" and "tm" into the
  base form's "moves" list in data/brawlers/<id>.json.
- TM supers (data/moves/tm_supers.json): big signature moves any line that can
  learn them by TM may equip instead of its own super.
- HMs: one or two per line that fit it, out of Cut, Fly, Surf, Strength,
  Flash and Rock Smash (compatible in the games, then picked by type).
- Writes data/progression.json (TM catalogue, TM supers and HMs per line).
  The unlock order lives in data/unlocks.json (hand-written).
"""
import csv, json, os, sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
DATA = os.path.join(ROOT, "data")
LEVEL_UP, MACHINE = "1", "4"
## (min, max, default when the line never learns it by levelling up) per variant index.
MAIN_LEVELS = {1: (8, 30, 14), 2: (20, 50, 32)}
MIN_GAP = 8

## TM supers: id -> (move identifier in PokeAPI, display name, type).
TM_SUPERS = {
    "hyper_beam": ("hyper-beam", "Hyper Beam", "normal"),
    "solar_beam": ("solar-beam", "Solar Beam", "grass"),
    "fire_blast": ("fire-blast", "Fire Blast", "fire"),
    "scald": ("scald", "Scald", "water"),
    "thunder": ("thunder", "Thunder", "electric"),
    "blizzard": ("blizzard", "Blizzard", "ice"),
    "earthquake": ("earthquake", "Earthquake", "ground"),
    "psychic": ("psychic", "Psychic", "psychic"),
    "rock_slide": ("rock-slide", "Rock Slide", "rock"),
    "sludge_bomb": ("sludge-bomb", "Sludge Bomb", "poison"),
    "shadow_ball": ("shadow-ball", "Shadow Ball", "ghost"),
    "sky_attack": ("sky-attack", "Sky Attack", "flying"),
    "focus_blast": ("focus-blast", "Focus Blast", "fighting"),
    "bug_buzz": ("bug-buzz", "Bug Buzz", "bug"),
    "dragon_pulse": ("dragon-pulse", "Dragon Pulse", "dragon"),
    "dazzling_gleam": ("dazzling-gleam", "Dazzling Gleam", "fairy"),
}
## Super templates by move: kind and numbers in the same scale as supers.json.
TM_SUPER_STATS = {
    "hyper_beam": {"kind": "projectile", "power": 2100, "speed": 11.0, "range": 9.0, "radius": 0.9, "pierce": True},
    "solar_beam": {"kind": "projectile", "power": 1900, "speed": 12.0, "range": 10.0, "radius": 0.8, "pierce": True},
    "fire_blast": {"kind": "projectile", "power": 1700, "speed": 8.5, "range": 7.5, "radius": 0.8, "explode_radius": 2.6,
                   "effect": {"type": "burn", "chance": 0.6, "duration": 3.0, "dps": 160}},
    "scald": {"kind": "projectile", "power": 1300, "speed": 10.0, "range": 7.5, "radius": 0.7, "count": 3, "spread": 18,
              "effect": {"type": "burn", "chance": 0.5, "duration": 3.0, "dps": 120}},
    "thunder": {"kind": "area", "power": 1700, "range": 8.0, "area_radius": 2.0,
                "effect": {"type": "slow", "chance": 0.6, "duration": 1.5, "amount": 0.5}},
    "blizzard": {"kind": "area", "power": 900, "range": 6.5, "area_radius": 3.0,
                 "effect": {"type": "slow", "chance": 1.0, "duration": 2.5, "amount": 0.5}},
    "earthquake": {"kind": "area", "power": 1500, "range": 0.0, "area_radius": 3.6},
    "psychic": {"kind": "projectile", "power": 1600, "speed": 10.0, "range": 8.5, "radius": 0.9, "knockback": 2.0},
    "rock_slide": {"kind": "projectile", "power": 900, "speed": 9.0, "range": 7.0, "radius": 0.7, "count": 3, "spread": 30},
    "sludge_bomb": {"kind": "projectile", "power": 1200, "speed": 8.0, "range": 7.5, "radius": 0.7, "explode_radius": 2.4,
                    "effect": {"type": "poison", "chance": 1.0, "duration": 4.0, "dps": 180}},
    "shadow_ball": {"kind": "projectile", "power": 1600, "speed": 9.0, "range": 8.0, "radius": 0.9,
                    "effect": {"type": "blind", "chance": 0.5, "duration": 1.5}},
    "sky_attack": {"kind": "dash", "power": 1800, "dash_distance": 8.0, "dash_speed": 20.0, "dash_pierce": True},
    "focus_blast": {"kind": "projectile", "power": 2200, "speed": 8.0, "range": 7.5, "radius": 0.9, "knockback": 2.5},
    "bug_buzz": {"kind": "area", "power": 1100, "range": 0.0, "area_radius": 3.2,
                 "effect": {"type": "slow", "chance": 0.5, "duration": 1.5, "amount": 0.4}},
    "dragon_pulse": {"kind": "projectile", "power": 1800, "speed": 10.5, "range": 9.0, "radius": 1.0, "pierce": True},
    "dazzling_gleam": {"kind": "area", "power": 1300, "range": 0.0, "area_radius": 3.4,
                       "effect": {"type": "blind", "chance": 0.6, "duration": 1.2}},
}

HMS = {"cut": "cut", "fly": "fly", "surf": "surf", "strength": "strength", "flash": "flash", "rock_smash": "rock-smash"}
## Type -> HM bonus (HMs that fit a type come first).
HM_FIT = {
    "water": {"surf": 3}, "flying": {"fly": 3}, "grass": {"cut": 3}, "bug": {"cut": 3},
    "electric": {"flash": 3}, "psychic": {"flash": 3}, "ghost": {"flash": 2}, "fairy": {"flash": 2},
    "fighting": {"rock_smash": 3, "strength": 2}, "rock": {"rock_smash": 3, "strength": 2},
    "ground": {"rock_smash": 2, "strength": 2}, "normal": {"strength": 1, "cut": 1}, "dragon": {"surf": 1, "strength": 1},
    "fire": {"strength": 1}, "poison": {"cut": 1}, "ice": {"surf": 1},
}
FALLBACK_HM = {"water": "surf", "bug": "cut", "grass": "cut", "electric": "flash", "psychic": "flash", "ghost": "flash", "flying": "fly"}


def slug(name):
    return name.lower().replace(" ", "-").replace("'", "").replace(".", "")


def main(src):
    species_ids = {r["identifier"]: r["id"] for r in csv.DictReader(open(os.path.join(src, "pokemon_species.csv")))}
    move_ids = {r["identifier"]: r["id"] for r in csv.DictReader(open(os.path.join(src, "moves.csv")))}
    learn = {}  # (pokemon_id, move_id) -> min level-up level
    machine = set()  # (pokemon_id, move_id)
    for r in csv.DictReader(open(os.path.join(src, "pokemon_moves.csv"))):
        key = (r["pokemon_id"], r["move_id"])
        if r["pokemon_move_method_id"] == LEVEL_UP:
            lvl = int(r["level"] or 1)
            if lvl > 0:
                learn[key] = min(learn.get(key, 999), lvl)
        elif r["pokemon_move_method_id"] == MACHINE:
            machine.add(key)

    defs = {f[:-5]: json.load(open(os.path.join(DATA, "brawlers", f))) for f in os.listdir(os.path.join(DATA, "brawlers")) if f.endswith(".json")}
    moves = {}
    for f in os.listdir(os.path.join(DATA, "moves")):
        for k, v in json.load(open(os.path.join(DATA, "moves", f))).items():
            if not k.startswith("_"):
                moves[k] = v

    def line_of(base):
        out, todo = [], [base]
        while todo:
            sid = todo.pop(0)
            out.append(sid)
            nxt = defs[sid].get("evolves_to", "")
            todo += nxt if isinstance(nxt, list) else ([nxt] if nxt else [])
        return out

    def pid(sid):
        return species_ids.get(sid.replace("_", "-"), species_ids.get(sid, ""))

    bases = sorted([s for s, d in defs.items() if not d.get("evolves_from") and not d.get("legendary")], key=lambda s: defs[s]["dex"])
    tms = {}
    tm_supers = {}
    hms = {}
    for base in bases:
        line = line_of(base)
        pids = [pid(s) for s in line if pid(s)]
        types = set(t for s in line for t in defs[s]["types"])

        def game_level(move_slug):
            mid = move_ids.get(move_slug)
            levels = [learn[(p, mid)] for p in pids if (p, mid) in learn] if mid else []
            return min(levels) if levels else 0

        def has_tm(move_slug):
            mid = move_ids.get(move_slug)
            return bool(mid) and any((p, mid) in machine for p in pids)

        # Main attack variants.
        entries = defs[base]["moves"]
        prev = 1
        new_entries = []
        for i, entry in enumerate(entries):
            move = moves[entry["move"]]
            e = {"move": entry["move"], "level": 1}
            if i > 0:
                lo, hi, default = MAIN_LEVELS[min(i, 2)]
                lvl = game_level(slug(move["name"])) or default
                lvl = max(min(max(lvl, lo), hi), prev + MIN_GAP)
                e["level"] = lvl
                prev = lvl
                if has_tm(slug(move["name"])):
                    tm_id = "tm_" + slug(move["name"]).replace("-", "_")
                    e["tm"] = tm_id
                    tms.setdefault(tm_id, {"name": "TM " + move["name"], "move": move["name"], "kind": "main", "type": move["type"]})
            new_entries.append(e)
        _write_moves(os.path.join(DATA, "brawlers", base + ".json"), new_entries)

        # TM supers this line can learn.
        tm_supers[base] = [sid for sid, (ms, _, _) in TM_SUPERS.items() if has_tm(ms)]

        # HMs: compatible in the games, best fits first, at most two.
        compatible = [h for h, ms in HMS.items() if has_tm(ms)]
        if "fly" in compatible and "flying" not in types:
            compatible.remove("fly")  # Charizard aside, only flyers fly.
        score = {h: sum(HM_FIT.get(t, {}).get(h, 0) for t in types) for h in compatible}
        picked = sorted(compatible, key=lambda h: (-score[h], list(HMS).index(h)))[:2]
        picked = [h for h in picked if score[h] > 0] or picked[:1]
        if not picked:
            picked = [next((FALLBACK_HM[t] for t in defs[base]["types"] if t in FALLBACK_HM), "strength")]
        hms[base] = picked

    for sid, (_, name, mtype) in TM_SUPERS.items():
        tm_id = "tm_" + sid
        entry = tms.get(tm_id, {"name": "TM " + name, "move": name, "kind": "super", "type": mtype})
        entry["kind"] = "both" if entry["kind"] == "main" else "super"
        entry["super"] = "tmsuper_" + sid
        tms[tm_id] = entry

    super_defs = {"_comment": "TM supers (tools/build_progression.py): any line that learns the move by TM in the games can equip it instead of its own super."}
    for sid, (_, name, mtype) in TM_SUPERS.items():
        d = {"name": name, "type": mtype, "slot": "super"}
        d.update(TM_SUPER_STATS[sid])
        super_defs["tmsuper_" + sid] = d
    json.dump(super_defs, open(os.path.join(DATA, "moves", "tm_supers.json"), "w"), indent="\t")

    out = {
        "_comment": "Generated by tools/build_progression.py. tms: catalogue (main = unlocks that main attack variant for every line that has it; super/both = also unlocks the TM super for the lines in tm_supers). hms: one or two per evolution line (base form id).",
        "tms": dict(sorted(tms.items())), "tm_supers": tm_supers, "hms": hms,
    }
    json.dump(out, open(os.path.join(DATA, "progression.json"), "w"), indent="\t")
    print(f"{len(bases)} lines, {len(tms)} TMs, HMs: " + ", ".join(f"{b}={'/'.join(h)}" for b, h in list(hms.items())[:12]))


def _write_moves(path, entries):
    """Rewrites the "moves" list in place, keeping the rest of the file's layout."""
    text = open(path).read()
    start = text.index('"moves": [')
    end = text.index("]", start) + 1
    body = ",\n".join("\t\t" + json.dumps(e) for e in entries)
    open(path, "w").write(text[:start] + '"moves": [\n' + body + "\n\t]" + text[end:])


if __name__ == "__main__":
    main(sys.argv[1])
