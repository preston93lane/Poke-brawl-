"""Prints a balance report for moves and Pokémon from the JSON data.

    python3 tools/balance_report.py

Damage figures are raw move power per second before attack/defense, STAB and
type, so they compare like with like. Use it after editing data/moves.json or
data/brawlers/*.json to spot outliers.
"""
import json, math, os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data")
moves = json.load(open(os.path.join(ROOT, "moves.json")))
rules = json.load(open(os.path.join(ROOT, "rules.json")))
species = {f[:-5]: json.load(open(os.path.join(ROOT, "brawlers", f)))
           for f in sorted(os.listdir(os.path.join(ROOT, "brawlers")))}


def hit_factor(m):
    """Rough share of a volley that lands on one target."""
    f = 1.0
    if m.get("count", 1) > 1:
        f *= 0.75 if m.get("spread", 0) <= 15 else 0.55
    return f


def move_dps(m):
    if m["slot"] == "super":
        return 0.0  # one-off; compare supers by burst
    kind = m["kind"]
    if kind == "stream":
        # power is damage per second while firing; sustained = share of time the tank allows
        return m["power"] * m["tank"] / (m["tank"] + m["reload"])
    if kind in ("melee", "dash"):
        return m["power"] / max(m.get("cooldown", 1.0), rules.get("melee_attack_delay", 0.35))
    if kind == "projectile":
        per_shot = m["power"] * m.get("count", 1) * m.get("burst_count", 1) * hit_factor(m)
        cycle = max(m["reload"], m.get("delay", rules.get("attack_delay", 0.45)))
        return per_shot / cycle
    return 0.0


def move_burst(m):
    if m["slot"] == "super":
        return m.get("power", 0) * m.get("count", 1)
    if m["kind"] == "stream":
        return m["power"] * m.get("tank", 2.0)
    if m["kind"] == "projectile":
        return m["power"] * m.get("count", 1) * m.get("burst_count", 1) * hit_factor(m) * m.get("ammo", 3)
    return m.get("power", 0)


def reach(m):
    if m["kind"] == "dash":
        return m["dash_distance"]
    if m["kind"] == "area":
        return m.get("range", 0) + m.get("area_radius", 0)
    return m.get("range", 0) + m.get("explode_radius", 0)


def stat_score(st):
    """One number per Pokémon: survivability x damage, plus a little for speed."""
    return math.sqrt(st["hp"] * st["defense"] / 100 * st["attack"]) / 10 + st["speed"] * 0.5


if __name__ == "__main__":
    print(f"{'move':15} {'slot':6} {'kind':10} {'dps':>6} {'burst':>6} {'reach':>5}  speed")
    for slot in ("melee", "ranged", "super"):
        for mid, m in moves.items():
            if mid.startswith("_") or m["slot"] != slot:
                continue
            spd = m.get("speed", m.get("dash_speed", ""))
            print(f"{mid:15} {slot:6} {m['kind']:10} {move_dps(m):6.0f} {move_burst(m):6.0f} {reach(m):5.1f}  {spd}")
        print()
    print(f"{'pokemon':12} stage  {'hp':>5} {'atk':>4} {'def':>4} {'spd':>4}  score")
    for sid, s in species.items():
        st = s["stats"]
        stage = 1 if "evolves_from" not in s else (3 if "evolves_to" not in s and species[s["evolves_from"]].get("evolves_from") else 2)
        print(f"{sid:12} {stage:5}  {st['hp']:5} {st['attack']:4} {st['defense']:4} {st['speed']:4}  {stat_score(st):6.1f}")
