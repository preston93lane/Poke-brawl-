"""Builds the progression data from the main-series games (PokeAPI CSVs).

    python3 tools/build_progression.py <pokeapi_csv_dir>

<pokeapi_csv_dir> holds pokemon_species.csv, pokemon_moves.csv and moves.csv
from the PokeAPI repository (data/v2/csv).

- Main attack variants: the first is known from the start. The other two unlock
  at a profile level, from the level the line learns that move by levelling up
  in the games (spaced out, see MAIN_LEVELS), or earlier with its TM if the move
  is a TM in any game the line can use it in. Writes "level" and "tm" into the
  base form's "moves" list in data/brawlers/<id>.json.
- TM supers (data/moves/tm_supers.json): two per type; a stage can equip one of
  its own types instead of its super, shaped to its play style.
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

## TM supers: two per type. Only Pokémon of that type can use one (per stage:
## Charizard can use a Flying one, Charmander can't). id -> (display name, type).
TM_SUPERS = {
    "hyper_beam": ("Hyper Beam", "normal"), "giga_impact": ("Giga Impact", "normal"),
    "solar_beam": ("Solar Beam", "grass"), "leaf_storm": ("Leaf Storm", "grass"),
    "fire_blast": ("Fire Blast", "fire"), "overheat": ("Overheat", "fire"),
    "scald": ("Scald", "water"), "muddy_water": ("Muddy Water", "water"),
    "thunder": ("Thunder", "electric"), "zap_cannon": ("Zap Cannon", "electric"),
    "blizzard": ("Blizzard", "ice"), "avalanche": ("Avalanche", "ice"),
    "earthquake": ("Earthquake", "ground"), "earth_power": ("Earth Power", "ground"),
    "psychic": ("Psychic", "psychic"), "psyshock": ("Psyshock", "psychic"),
    "rock_slide": ("Rock Slide", "rock"), "rock_tomb": ("Rock Tomb", "rock"),
    "sludge_bomb": ("Sludge Bomb", "poison"), "gunk_shot": ("Gunk Shot", "poison"),
    "shadow_ball": ("Shadow Ball", "ghost"), "hex": ("Hex", "ghost"),
    "sky_attack": ("Sky Attack", "flying"), "hurricane": ("Hurricane", "flying"),
    "focus_blast": ("Focus Blast", "fighting"), "close_combat": ("Close Combat", "fighting"),
    "bug_buzz": ("Bug Buzz", "bug"), "signal_beam": ("Signal Beam", "bug"),
    "dragon_pulse": ("Dragon Pulse", "dragon"), "draco_meteor": ("Draco Meteor", "dragon"),
    "dazzling_gleam": ("Dazzling Gleam", "fairy"), "moonblast": ("Moonblast", "fairy"),
    "flash_cannon": ("Flash Cannon", "steel"), "iron_head": ("Iron Head", "steel"),
}
## Each TM super takes the shape that fits the user's play style (a stream
## Pokémon's Fire Blast is a burst of flame up close; a sniper's is a long beam; "shot" is a mid-range blast).
SHAPES = {
    "burst": {"kind": "area", "power": 1400, "range": 3.5, "area_radius": 2.4},
    "lob": {"kind": "projectile", "power": 1350, "lob": True, "speed": 9.0, "range": 7.5, "radius": 0.7, "explode_radius": 2.4},
    "beam": {"kind": "projectile", "power": 1600, "speed": 15.0, "range": 10.0, "radius": 0.7, "pierce": True},
    "shot": {"kind": "projectile", "power": 1400, "speed": 10.0, "range": 8.0, "radius": 0.8, "explode_radius": 2.0},
}
## Status effect each type adds to its TM supers.
TYPE_EFFECTS = {
    "fire": {"type": "burn", "chance": 0.6, "duration": 3.0, "dps": 140},
    "poison": {"type": "poison", "chance": 0.8, "duration": 4.0, "dps": 150},
    "electric": {"type": "slow", "chance": 0.5, "duration": 1.5, "amount": 0.5},
    "ice": {"type": "slow", "chance": 0.8, "duration": 2.0, "amount": 0.5},
    "ghost": {"type": "blind", "chance": 0.5, "duration": 1.5},
    "fairy": {"type": "blind", "chance": 0.4, "duration": 1.2},
    "psychic": {"type": "slow", "chance": 0.3, "duration": 1.0, "amount": 0.3},
    "grass": {"type": "leech", "chance": 0.5, "duration": 3.0, "dps": 120},
    "water": {"type": "slow", "chance": 0.7, "duration": 1.5, "amount": 0.4},
}
## Types with no status effect hit 10% harder instead.
NO_EFFECT_BONUS = 1.1


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

    for sid, (name, mtype) in TM_SUPERS.items():
        tm_id = "tm_" + sid
        entry = tms.get(tm_id, {"name": "TM " + name, "move": name, "kind": "super", "type": mtype})
        entry["kind"] = "both" if entry["kind"] == "main" else "super"
        entry["super"] = "tmsuper_" + sid
        tms[tm_id] = entry

    super_defs = {"_comment": "TM supers (tools/build_progression.py): tmsuper_<id> is the one shown in menus; tmsuper_<id>_<shape> is what's used, picked by the user's play style. Only Pokémon of the move's type can use it."}
    for sid, (name, mtype) in TM_SUPERS.items():
        for shape, stats in [("", SHAPES["shot"])] + list(SHAPES.items()):
            d = {"name": name, "type": mtype, "slot": "super"}
            d.update(stats)
            if mtype in TYPE_EFFECTS:
                d["effect"] = TYPE_EFFECTS[mtype]
            else:
                d["power"] = int(round(d["power"] * NO_EFFECT_BONUS / 10) * 10)
            super_defs["tmsuper_" + sid + ("_" + shape if shape else "")] = d
    json.dump(super_defs, open(os.path.join(DATA, "moves", "tm_supers.json"), "w"), indent="\t")

    out = {
        "_comment": "Generated by tools/build_progression.py. tms: catalogue (main = unlocks that main attack variant for every line that has it; super/both = also unlocks the TM super for every Pokémon of its type). hms: one or two per evolution line (base form id).",
        "tms": dict(sorted(tms.items())), "hms": hms,
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
