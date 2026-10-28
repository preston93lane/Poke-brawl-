"""Adds "evolve_level" to every data/brawlers/<id>.json that can evolve.

    python3 tools/add_evolve_levels.py <pokeapi_csv_dir>

<pokeapi_csv_dir> holds pokemon_species.csv and pokemon_evolution.csv from the
PokeAPI repository (data/v2/csv). evolve_level is the main-series level the
Pokémon evolves at (Charmander 16, Charmeleon 32). Stone, trade and friendship
evolutions have no level, so they get FALLBACK[stage] (and never less than 10
above the previous stage). Reaching evolve_level on your profile makes that
evolution take two KOs in a match instead of three.
"""
import csv, json, os, sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
DATA = os.path.join(ROOT, "data", "brawlers")
FALLBACK = {1: 25, 2: 40}


def main(src):
    ids = {r["identifier"]: r["id"] for r in csv.DictReader(open(os.path.join(src, "pokemon_species.csv")))}
    levels = {}
    for r in csv.DictReader(open(os.path.join(src, "pokemon_evolution.csv"))):
        if r["minimum_level"] and r["evolution_trigger_id"] == "1":
            levels.setdefault(r["evolved_species_id"], int(r["minimum_level"]))
    defs = {f[:-5]: json.load(open(os.path.join(DATA, f))) for f in os.listdir(DATA) if f.endswith(".json")}
    done = {}

    def level_for(sid):
        if sid in done:
            return done[sid]
        d = defs[sid]
        nxt = d.get("evolves_to", "")
        nxt = nxt[0] if isinstance(nxt, list) else nxt
        if not nxt:
            return 0
        prev = d.get("evolves_from", "")
        stage = 1 if not prev else 2
        floor = level_for(prev) + 10 if prev else 0
        lvl = levels.get(ids.get(nxt, ""), 0) or max(FALLBACK[stage], floor)
        done[sid] = lvl
        return lvl

    for sid in sorted(defs):
        lvl = level_for(sid)
        path = os.path.join(DATA, sid + ".json")
        lines = [l for l in open(path).read().split("\n") if not l.strip().startswith('"evolve_level"')]
        if lvl:
            for i, line in enumerate(lines):
                # Inserted before evolves_to, which may be the last (comma-less) line.
                if line.strip().startswith('"evolves_to"'):
                    lines.insert(i, f'\t"evolve_level": {lvl},')
                    break
        open(path, "w").write("\n".join(lines))
        if lvl:
            print(sid, lvl)


if __name__ == "__main__":
    main(sys.argv[1])
