"""Builds data/brawlers/*.json and data/moves/generated.json from tools/roster.py.

    python3 tools/build_roster.py

Every Pokemon's main attack follows its family's play style (a Brawl Stars
brawler archetype). Each style has three variants (levels 1-3) and a super
template; numbers are set from damage-per-second targets so styles stay
balanced against each other. Hand-made supers live in data/moves/supers.json.
"""
import json, math, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from roster import FAMILIES, LEGENDARIES, SPECIAL_TARGET  # noqa: E402

DATA = os.path.join(HERE, "..", "data")
TIER = {1: 1.0, 2: 1.06, 3: 1.12}

# Flavour effect added to the level 2 attack, by attack type.
TYPE_EFFECT = {
    "fire": {"type": "burn", "chance": 0.2, "duration": 3.0, "dps": 100},
    "electric": {"type": "slow", "chance": 0.2, "duration": 1.2, "amount": 0.4},
    "poison": {"type": "poison", "chance": 0.25, "duration": 4.0, "dps": 100},
    "ice": {"type": "slow", "chance": 0.3, "duration": 1.5, "amount": 0.4},
    "psychic": {"type": "slow", "chance": 0.15, "duration": 1.0, "amount": 0.3},
    "ghost": {"type": "blind", "chance": 0.1, "duration": 1.0},
}

# Play styles. hp = health multiplier (tanks sturdier, assassins/snipers frailer);
# dps = sustained damage target (move power per second before attack/defense);
# gadget = the gadget this style gets; variants = levels 1..3 (power filled in later).
STYLES = {
    "shotgun": dict(label="Shotgun", like="Shelly / Bull", desc="Close-range spread: brutal up close, weak at range.", hp=1.15, dps=520, gadget="gadget_protect", variants=[
        dict(kind="projectile", count=5, spread=38, range=4.2, speed=11, ammo=3, reload=1.6),
        dict(kind="projectile", count=3, spread=18, range=5.6, speed=12, ammo=3, reload=1.6),
        dict(kind="projectile", count=7, spread=55, range=3.6, speed=11, ammo=3, reload=1.8, knockback=1.2)]),
    "sniper": dict(label="Sniper", like="Piper", desc="Long-range shots that hit harder the further they travel.", hp=0.85, dps=330, gadget="gadget_teleport", variants=[
        dict(kind="projectile", range=9.5, speed=15, ammo=3, reload=2.1, distance_bonus=1.5),
        dict(kind="projectile", range=9.0, speed=17, ammo=3, reload=2.2, pierce=True, distance_bonus=1.3),
        dict(kind="projectile", range=9.0, speed=13, ammo=3, reload=2.3, explode_radius=1.4)]),
    "gunner": dict(label="Gunner", like="Colt", desc="Rapid bursts of shots in a line. Reward good aim.", hp=1.0, dps=430, gadget="gadget_teleport", variants=[
        dict(kind="projectile", burst_count=3, burst_interval=0.08, range=7.0, speed=14, ammo=3, reload=1.5),
        dict(kind="projectile", burst_count=5, burst_interval=0.07, spread=8, range=6.0, speed=14, ammo=3, reload=1.8),
        dict(kind="projectile", count=2, spread=6, burst_count=3, burst_interval=0.08, range=7.0, speed=14, ammo=3, reload=1.9)]),
    "bouncer": dict(label="Bouncer", like="Rico", desc="Shots ricochet off walls; great around corners.", hp=0.95, dps=400, gadget="gadget_teleport", variants=[
        dict(kind="projectile", range=7.5, speed=12, ammo=3, reload=1.6, bounces=2),
        dict(kind="projectile", count=3, spread=22, range=6.5, speed=12, ammo=3, reload=1.8, bounces=1),
        dict(kind="projectile", radius=0.45, range=8.0, speed=11, ammo=3, reload=2.0, bounces=3, pierce=True)]),
    "thrower": dict(label="Thrower", like="Barley / Dynamike", desc="Lobs over walls and lands where you aim.", hp=0.9, dps=380, gadget="gadget_smokescreen", variants=[
        dict(kind="projectile", lob=True, range=7.0, speed=9, ammo=3, reload=1.8, explode_radius=1.6),
        dict(kind="projectile", lob=True, range=7.0, speed=9, ammo=3, reload=2.0, explode_radius=1.2, linger=2.5, linger_radius=1.5),
        dict(kind="projectile", lob=True, count=3, spread=30, range=6.5, speed=9, ammo=3, reload=2.2, explode_radius=1.1)]),
    "brawler": dict(label="Brawler", like="El Primo", desc="Heavy close-range punches and lots of health.", hp=1.3, dps=650, gadget="gadget_protect", variants=[
        dict(kind="melee", range=1.9, arc=100, ammo=3, reload=1.1),
        dict(kind="melee", range=2.1, arc=140, ammo=3, reload=1.3, effect_from_type=True),
        dict(kind="melee", range=2.3, arc=90, ammo=3, reload=1.4, knockback=2.5)]),
    "assassin": dict(label="Assassin", like="Mortis / Edgar", desc="Dashes in to strike, then gets out.", hp=0.95, dps=520, gadget="gadget_agility", variants=[
        dict(kind="dash", dash_distance=4.0, dash_speed=18, ammo=3, reload=1.4),
        dict(kind="dash", dash_distance=5.5, dash_speed=20, ammo=3, reload=1.7, dash_pierce=True),
        dict(kind="dash", dash_distance=4.5, dash_speed=18, ammo=3, reload=1.6, drain=0.35)]),
    "spinner": dict(label="Spinner", like="Bibi (all-around swing)", desc="Hits everything around it at once.", hp=1.2, dps=560, gadget="gadget_agility", variants=[
        dict(kind="melee", range=2.0, arc=360, ammo=3, reload=1.3),
        dict(kind="melee", range=2.6, arc=360, ammo=3, reload=1.6, effect_from_type=True),
        dict(kind="melee", range=2.2, arc=360, ammo=3, reload=1.5, drain=0.3)]),
    "lasher": dict(label="Lasher", like="Frank's reach, Gene's pull", desc="Long, narrow whips; some pull enemies in.", hp=1.05, dps=560, gadget="gadget_agility", variants=[
        dict(kind="melee", range=3.4, arc=35, ammo=3, reload=1.2),
        dict(kind="melee", range=3.8, arc=30, ammo=3, reload=1.4, knockback=-1.6),
        dict(kind="melee", range=3.2, arc=70, ammo=3, reload=1.4, crit_chance=0.3)]),
    "stream": dict(label="Stream", like="Amber", desc="Hold to spray a continuous cone from a refilling tank.", hp=1.0, dps=460, gadget="gadget_sitrus", variants=[
        dict(kind="stream", range=3.2, arc=30, tank=2.2, reload=2.6),
        dict(kind="stream", range=4.0, arc=24, tank=2.5, reload=3.0, effect_from_type=True),
        dict(kind="stream", range=3.4, arc=42, tank=2.0, reload=2.6)]),
    "healer": dict(label="Healer", like="Poco / Byron", desc="Waves that hurt enemies and heal teammates.", hp=0.95, dps=330, gadget="gadget_heal_pulse", variants=[
        dict(kind="projectile", pierce=True, radius=0.8, range=6.5, speed=10, ammo=3, reload=1.8, heal_allies=450),
        dict(kind="projectile", lob=True, range=7.0, speed=9, ammo=3, reload=2.2, explode_radius=2.0, heal_allies=600),
        dict(kind="projectile", pierce=True, radius=1.0, range=5.5, speed=9, ammo=3, reload=2.0, heal_allies=600, effect_from_type=True)]),
    "boomerang": dict(label="Boomerang", like="out-and-back throws", desc="Hits on the way out and again on the way back.", hp=1.0, dps=380, gadget="gadget_teleport", variants=[
        dict(kind="projectile", range=6.5, speed=11, ammo=3, reload=1.8, returns=True, radius=0.4),
        dict(kind="projectile", count=2, spread=28, range=6.0, speed=11, ammo=3, reload=2.0, returns=True, radius=0.4),
        dict(kind="projectile", radius=0.5, pierce=True, range=7.0, speed=11, ammo=3, reload=2.2, returns=True)]),
    "chain": dict(label="Chain", like="lightning that jumps", desc="Zaps jump from the first enemy hit to others nearby.", hp=0.95, dps=400, gadget="gadget_sitrus", variants=[
        dict(kind="projectile", range=7.0, speed=16, ammo=3, reload=1.6, chain=2),
        dict(kind="projectile", range=7.0, speed=16, ammo=3, reload=1.9, chain=3),
        dict(kind="projectile", range=7.0, speed=15, ammo=3, reload=2.1, chain=4, effect_from_type=True)]),
    "zone": dict(label="Area denial", like="Emz / Sprout", desc="Lobs clouds that keep hurting anyone standing in them.", hp=1.0, dps=330, gadget="gadget_smokescreen", variants=[
        dict(kind="projectile", lob=True, range=7.0, speed=9, ammo=3, reload=2.2, linger=3.0, linger_radius=1.7),
        dict(kind="projectile", lob=True, range=7.0, speed=9, ammo=3, reload=2.5, linger=3.0, linger_radius=2.2, effect={"type": "slow", "chance": 0.25, "duration": 1.0, "amount": 0.3}),
        dict(kind="projectile", lob=True, range=7.0, speed=9, ammo=3, reload=2.5, linger=4.0, linger_radius=1.8, effect={"type": "poison", "chance": 0.25, "duration": 3.0, "dps": 90})]),
    "homing": dict(label="Orbs", like="Gene / Willow", desc="Fans of slow orbs that cover an area (no homing).", hp=0.95, dps=360, gadget="gadget_smokescreen", variants=[
        dict(kind="projectile", count=2, spread=24, range=7.0, speed=10, ammo=3, reload=1.7),
        dict(kind="projectile", count=3, spread=36, range=6.5, speed=10, ammo=3, reload=2.0, effect_from_type=True),
        dict(kind="projectile", radius=0.5, explode_radius=1.3, range=7.5, speed=9, ammo=3, reload=2.2)]),
    "tank_wave": dict(label="Tank", like="Frank", desc="Slow, wide shockwaves; huge health.", hp=1.35, dps=480, gadget="gadget_protect", variants=[
        dict(kind="projectile", pierce=True, radius=0.9, range=4.5, speed=8, ammo=3, reload=1.6),
        dict(kind="melee", range=2.8, arc=360, ammo=3, reload=1.9),
        dict(kind="projectile", pierce=True, radius=1.1, range=4.0, speed=7, ammo=3, reload=2.0, effect={"type": "stun", "chance": 0.2, "duration": 0.6})]),
    "piercer": dict(label="Piercer", like="Colt / Belle beams", desc="Beams that go straight through every enemy in line.", hp=0.95, dps=400, gadget="gadget_teleport", variants=[
        dict(kind="projectile", pierce=True, range=8.0, speed=18, radius=0.35, ammo=3, reload=1.7),
        dict(kind="projectile", count=2, spread=12, pierce=True, range=7.5, speed=18, radius=0.35, ammo=3, reload=1.9),
        dict(kind="projectile", pierce=True, range=8.5, speed=16, radius=0.5, ammo=3, reload=2.1, effect_from_type=True)]),
}

# Supers for Pokemon that don't have a hand-made one; f = stage strength factor.
def super_template(style, f, type_):
    eff = TYPE_EFFECT.get(type_)
    t = {
        "shotgun": dict(kind="dash", power=1200 * f, dash_distance=6.0, dash_speed=18, dash_pierce=True, knockback=3.0),
        "sniper": dict(kind="projectile", power=1600 * f, range=10.0, speed=20, radius=0.6, pierce=True),
        "gunner": dict(kind="projectile", power=150 * f, burst_count=10, burst_interval=0.06, range=8.0, speed=16, pierce=True),
        "bouncer": dict(kind="projectile", power=300 * f, count=5, spread=50, bounces=2, range=7.0, speed=12, radius=0.4),
        "thrower": dict(kind="projectile", power=1500 * f, lob=True, range=7.5, speed=9, explode_radius=3.0),
        "brawler": dict(kind="dash", power=1100 * f, dash_distance=6.0, dash_speed=16, explode_radius=2.2),
        "assassin": dict(kind="dash", power=1300 * f, dash_distance=8.0, dash_speed=22, dash_pierce=True, drain=0.5),
        "spinner": dict(kind="area", power=1300 * f, range=0.0, area_radius=3.8, effect={"type": "slow", "chance": 1.0, "duration": 1.5, "amount": 0.5}),
        "lasher": dict(kind="melee", power=900 * f, range=6.0, arc=50, knockback=-5.0, effect={"type": "stun", "chance": 1.0, "duration": 0.6}),
        "stream": dict(kind="area", power=1300 * f, range=4.0, area_radius=3.0, effect=eff),
        "healer": dict(kind="self", heal=0.35, team_heal=0.45, support_radius=6.5, cleanse=True),
        "boomerang": dict(kind="projectile", power=450 * f, count=3, spread=40, returns=True, range=7.0, speed=11, radius=0.45),
        "chain": dict(kind="area", power=1200 * f, range=6.0, area_radius=3.0, effect={"type": "stun", "chance": 1.0, "duration": 0.8}),
        "zone": dict(kind="projectile", power=350 * f, lob=True, range=7.5, speed=9, linger=5.0, linger_radius=3.2),
        "homing": dict(kind="projectile", power=260 * f, count=6, spread=120, range=7.0, speed=10, radius=0.4),
        # Frank-style: an aimed 90-degree slam in front, not a full circle.
        "tank_wave": dict(kind="melee", power=1200 * f, range=4.5, arc=90, windup=0.6, effect={"type": "stun", "chance": 1.0, "duration": 1.0}),
        "piercer": dict(kind="projectile", power=1700 * f, range=10.0, speed=20, radius=0.9, pierce=True),
    }[style]
    return {k: (round(v) if k == "power" else v) for k, v in t.items() if v is not None}


GADGETS = {
    "gadget_protect": {"name": "Protect", "type": "normal", "slot": "gadget", "kind": "self", "protect": 1.2},
    "gadget_agility": {"name": "Agility", "type": "psychic", "slot": "gadget", "kind": "self", "cleanse": True, "buff": {"speed": 0.7, "duration": 2.5}},
    "gadget_teleport": {"name": "Teleport", "type": "psychic", "slot": "gadget", "kind": "self", "blink": 4.5},
    "gadget_smokescreen": {"name": "Smokescreen", "type": "dark", "slot": "gadget", "kind": "area", "power": 0, "range": 0.0, "area_radius": 3.0, "effect": {"type": "blind", "chance": 1.0, "duration": 1.6}},
    "gadget_heal_pulse": {"name": "Heal Pulse", "type": "fairy", "slot": "gadget", "kind": "self", "heal": 0.15, "team_heal": 0.25, "support_radius": 5.0},
    "gadget_sitrus": {"name": "Sitrus Berry", "type": "grass", "slot": "gadget", "kind": "self", "heal": 0.3},
}


def main_attack(style_name, level, name, type_):
    style = STYLES[style_name]
    v = dict(style["variants"][level - 1])
    move = {"name": name, "type": type_, "slot": "main"}
    if v.pop("effect_from_type", False) and type_ in TYPE_EFFECT:
        eff = dict(TYPE_EFFECT[type_])
        if v["kind"] == "stream":
            eff["chance"] = round(eff["chance"] / 6.0, 3)  # rolled every 0.15 s tick
        v["effect"] = eff
    move.update(v)
    target = style["dps"] * TIER[level]
    kind = v["kind"]
    if kind == "melee":
        target *= math.sqrt(2.0 / v["range"]) if v["arc"] < 300 else 1.0
        move["power"] = round(target * v["reload"] / 10) * 10
    elif kind == "dash":
        move["power"] = round(target * v["reload"] / 10) * 10
    elif kind == "stream":
        target *= math.sqrt(3.5 / v["range"])
        move["power"] = round(target * (v["tank"] + v["reload"]) / v["tank"] / 10) * 10
    else:
        if style_name not in ("sniper",):
            target *= min(1.15, math.sqrt(6.5 / v["range"]))
        # Multi-shot: power is split as if every pellet hits, so point blank isn't overpowered.
        hits = v.get("count", 1) * v.get("burst_count", 1)
        if v.get("explode_radius"): target *= 0.85
        if v.get("pierce"): target *= 0.9
        if v.get("returns"): target *= 0.7
        if v.get("chain"): target *= 1.0 / (1.0 + 0.35 * (v["chain"] - 1))
        if v.get("distance_bonus"): target /= (1 + v["distance_bonus"]) / 2
        if v.get("linger"):
            # Lingering clouds: power is damage per second while standing in it.
            move["power"] = round(target * v["reload"] / v["linger"] / 10) * 10
            return move
        move["power"] = round(target * v["reload"] / hits / 10) * 10
    return move


def convert(base):
    hp, atk, de, spa, spd, spe = base
    return {
        "hp": min(6200.0, max(2300.0, 2200.0 + hp * 22.0)),
        "attack": 70.0 + max(atk, spa) * 0.55,
        "defense": 60.0 + (de + spd) / 2.0 * 0.6,
        "speed": min(130.0, max(80.0, 75.0 + spe * 0.4)),
    }


def score(st):
    return math.sqrt(st["hp"] * st["defense"] / 100.0 * st["attack"]) / 10.0 + st["speed"] * 0.5


def balance(st, goal, style):
    k = (goal - st["speed"] * 0.5) / (score(st) - st["speed"] * 0.5)
    k = 1 + (k - 1) * 0.75
    return {
        "hp": int(round(st["hp"] * k * STYLES[style]["hp"] / 50.0) * 50),
        "attack": int(round(st["attack"] * math.sqrt(k))),
        "defense": int(round(st["defense"])),
        "speed": int(round(st["speed"])),
    }


def dump_species(path, d):
    order = ["name", "dex", "types", "sprite", "sprite_scale", "sprite_height", "legendary", "style", "stats", "super", "gadget", "evolves_from", "evolves_to", "moves"]
    d = {k: d[k] for k in order if k in d}
    out = ["{"]
    keys = list(d)
    for i, k in enumerate(keys):
        comma = "," if i < len(keys) - 1 else ""
        if k == "moves":
            out.append('\t"moves": [')
            out += ["\t\t" + json.dumps(m) + ("," if j < len(d[k]) - 1 else "") for j, m in enumerate(d[k])]
            out.append("\t]" + comma)
        else:
            out.append(f"\t{json.dumps(k)}: {json.dumps(d[k], ensure_ascii=False)}{comma}")
    out.append("}")
    with open(path, "w") as f:
        f.write("\n".join(out) + "\n")


def build():
    supers = json.load(open(os.path.join(DATA, "moves", "supers.json")))
    generated = {"_comment": "Generated by tools/build_roster.py from tools/roster.py - edit those, not this file."}
    generated.update(GADGETS)
    written = []

    for fam in FAMILIES:
        members = fam["members"]
        base_id = members[0][0]
        branch = len(members) > 2 and len(members[1]) > 6  # Eevee: base + branches with own attacks
        for idx, member in enumerate(members):
            sid, name, types, base, sup, _sprite = member[:6]
            own_mains = member[6] if len(member) > 6 else None
            if branch:
                stage = 1 if idx == 0 else 2
                final = idx > 0
                evolves_from = base_id if idx > 0 else None
                evolves_to = [m[0] for m in members[1:]] if idx == 0 else None
            else:
                stage = idx + 1
                final = idx == len(members) - 1
                evolves_from = members[idx - 1][0] if idx > 0 else None
                evolves_to = members[idx + 1][0] if not final else None
            if sid in SPECIAL_TARGET:
                goal = SPECIAL_TARGET[sid]
            elif len(members) == 1:
                goal = 122.0
            elif final and stage == 2:
                goal = 125.0
            else:
                goal = {1: 104.0, 2: 116.5, 3: 133.0}[stage]
            stats = balance(convert(base), goal, fam["style"])

            if sup in supers:
                super_id = sup
            else:
                super_id = sid + "_super"
                f = {1: 1.0, 2: 1.15, 3: 1.3}[stage] if len(members) > 1 else 1.2
                move = {"name": sup, "type": types[0], "slot": "super"}
                move.update(super_template(fam["style"], f, types[0]))
                generated[super_id] = move

            mains = own_mains if own_mains else (fam["mains"] if idx == 0 else None)
            moves = None
            if mains:
                moves = []
                for level, (mname, mtype) in enumerate(mains, start=1):
                    mid = f"{sid}_main{level}"
                    generated[mid] = main_attack(fam["style"], level, mname, mtype)
                    moves.append({"move": mid, "level": level})

            path = os.path.join(DATA, "brawlers", sid + ".json")
            old = json.load(open(path)) if os.path.exists(path) else {}
            scale = old.get("sprite_scale", {1: 1.0, 2: 1.15, 3: 1.3}[stage] if len(members) > 1 else 1.15)
            d = {"name": name, "types": types, "sprite": f"res://assets/brawlers/{sid}.png", "sprite_scale": scale,
                 "style": fam["style"], "stats": stats, "super": super_id, "gadget": STYLES[fam["style"]]["gadget"]}
            if "sprite_height" in old: d["sprite_height"] = old["sprite_height"]
            if "dex" in old: d["dex"] = old["dex"]
            if evolves_from: d["evolves_from"] = evolves_from
            if evolves_to: d["evolves_to"] = evolves_to
            if moves: d["moves"] = moves
            dump_species(path, d)
            written.append(sid)

    for leg in LEGENDARIES:
        sid = leg["id"]
        path = os.path.join(DATA, "brawlers", sid + ".json")
        d = json.load(open(path))
        d["style"] = leg["style"]
        d["gadget"] = STYLES[leg["style"]]["gadget"]
        d["moves"] = []
        for level, (mname, mtype) in enumerate(leg["mains"], start=1):
            mid = f"{sid}_main{level}"
            generated[mid] = main_attack(leg["style"], level, mname, mtype)
            d["moves"].append({"move": mid, "level": level})
        dump_species(path, d)
        written.append(sid)

    lines = ["{"]
    items = list(generated.items())
    for i, (k, v) in enumerate(items):
        lines.append(f"\t{json.dumps(k)}: {json.dumps(v)}" + ("," if i < len(items) - 1 else ""))
    lines.append("}")
    with open(os.path.join(DATA, "moves", "generated.json"), "w") as f:
        f.write("\n".join(lines) + "\n")
    with open(os.path.join(DATA, "styles.json"), "w") as f:
        json.dump({k: {"label": v["label"], "like": v["like"], "desc": v["desc"]} for k, v in STYLES.items()}, f, indent="\t")
        f.write("\n")
    print(f"wrote {len(written)} Pokemon, {len(generated) - 1} generated moves")


if __name__ == "__main__":
    build()
