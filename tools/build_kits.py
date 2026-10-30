"""Writes data/kits.json: two signature gadgets and two Abilities for every evolution line.

    python3 tools/build_kits.py

Gadgets come from the line's types (first type's signature gadget, then the second
type's, or the first type's other one). Abilities: one from the base form's type, one
from its play style, unless HAND lists the line. Edit HAND / the tables, not the output.
"""
import json, os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")

TYPE_GADGETS = {
    "fire": ["gadget_ember_charge", "gadget_will_o_wisp"],
    "water": ["gadget_aqua_jet", "gadget_rain_dance"],
    "electric": ["gadget_thunder_wave", "gadget_charge"],
    "grass": ["gadget_spore", "gadget_leech_seed"],
    "ice": ["gadget_icy_wind", "gadget_mist"],
    "fighting": ["gadget_detect", "gadget_bulk_up"],
    "poison": ["gadget_toxic_spikes", "gadget_acid_armor"],
    "ground": ["gadget_dig", "gadget_sand_attack"],
    "flying": ["gadget_tailwind", "gadget_roost"],
    "psychic": ["gadget_teleport", "gadget_light_screen"],
    "bug": ["gadget_string_shot", "gadget_sticky_web"],
    "rock": ["gadget_stealth_rock", "gadget_rock_polish"],
    "ghost": ["gadget_shadow_sneak", "gadget_curse"],
    "dragon": ["gadget_dragon_dance", "gadget_dragon_tail"],
    "steel": ["gadget_iron_defense", "gadget_gyro_spin"],
    "normal": ["gadget_quick_claw", "gadget_protect"],
    "fairy": ["gadget_charm", "gadget_heal_pulse"],
    "dark": ["gadget_sucker_punch", "gadget_smokescreen"],
}

TYPE_ABILITIES = {
    "fire": ["blaze", "flame_body"], "water": ["torrent", "swift_swim"], "grass": ["overgrow", "chlorophyll"],
    "bug": ["swarm", "shed_skin"], "electric": ["static", "speed_boost"], "rock": ["sturdy", "clear_body"],
    "ground": ["sturdy", "guts"], "normal": ["guts", "serene_grace"], "fighting": ["guts", "iron_fist"],
    "poison": ["poison_point", "shed_skin"], "psychic": ["inner_focus", "serene_grace"], "ghost": ["levitate", "pressure"],
    "dragon": ["shed_skin", "inner_focus"], "flying": ["speed_boost", "sniper"], "ice": ["thick_fat", "inner_focus"],
    "steel": ["clear_body", "sturdy"], "fairy": ["serene_grace", "regenerator"], "dark": ["pressure", "intimidate"],
}

STYLE_ABILITIES = {
    "sniper": "sniper", "piercer": "sniper", "shotgun": "technician", "gunner": "technician", "spinner": "technician",
    "bouncer": "technician", "boomerang": "technician", "chain": "technician", "homing": "technician",
    "tank_wave": "sturdy", "assassin": "speed_boost", "brawler": "iron_fist", "lasher": "rough_skin",
    "healer": "regenerator", "zone": "serene_grace", "thrower": "serene_grace", "stream": "hustle",
}

# Classic pairings that beat the generic rules: line root -> {"abilities": [...], "gadgets": [...]}.
HAND = {
    "bulbasaur": {"abilities": ["overgrow", "chlorophyll"]},
    "charmander": {"abilities": ["blaze", "hustle"], "gadgets": ["gadget_ember_charge", "gadget_will_o_wisp"]},
    "squirtle": {"abilities": ["torrent", "regenerator"]},
    "pikachu": {"abilities": ["static", "speed_boost"], "gadgets": ["gadget_thunder_wave", "gadget_charge"]},
    "pidgey": {"abilities": ["sniper", "speed_boost"]},
    "rattata": {"abilities": ["guts", "hustle"]},
    "ekans": {"abilities": ["intimidate", "shed_skin"]},
    "growlithe": {"abilities": ["intimidate", "flame_body"]},
    "machop": {"abilities": ["guts", "iron_fist"], "gadgets": ["gadget_detect", "gadget_bulk_up"]},
    "geodude": {"abilities": ["sturdy", "rough_skin"], "gadgets": ["gadget_stealth_rock", "gadget_dig"]},
    "onix": {"abilities": ["sturdy", "rough_skin"], "gadgets": ["gadget_stealth_rock", "gadget_dig"]},
    "gastly": {"abilities": ["levitate", "pressure"], "gadgets": ["gadget_shadow_sneak", "gadget_curse"]},
    "magikarp": {"abilities": ["intimidate", "swift_swim"]},
    "snorlax": {"abilities": ["thick_fat", "guts"]},
    "lapras": {"abilities": ["thick_fat", "regenerator"]},
    "tauros": {"abilities": ["intimidate", "guts"]},
    "scyther": {"abilities": ["technician", "swarm"]},
    "pinsir": {"abilities": ["hustle", "guts"]},
    "dratini": {"abilities": ["shed_skin", "inner_focus"]},
    "koffing": {"abilities": ["levitate", "poison_point"]},
    "slowpoke": {"abilities": ["regenerator", "thick_fat"]},
    "staryu": {"abilities": ["regenerator", "sniper"]},
    "shellder": {"abilities": ["technician", "clear_body"]},
    "magnemite": {"abilities": ["sturdy", "static"]},
    "voltorb": {"abilities": ["static", "speed_boost"]},
    "cubone": {"abilities": ["sturdy", "guts"]},
    "kangaskhan": {"abilities": ["guts", "intimidate"]},
    "electabuzz": {"abilities": ["static", "speed_boost"]},
    "magmar": {"abilities": ["flame_body", "hustle"]},
    "eevee": {"abilities": ["technician", "guts"], "gadgets": ["gadget_quick_claw", "gadget_charm"]},
    "abra": {"abilities": ["inner_focus", "serene_grace"]},
    "hitmonlee": {"abilities": ["iron_fist", "inner_focus"]},
    "hitmonchan": {"abilities": ["iron_fist", "inner_focus"]},
    "jigglypuff": {"abilities": ["serene_grace", "regenerator"]},
    "clefairy": {"abilities": ["serene_grace", "regenerator"]},
    "chansey": {"abilities": ["serene_grace", "regenerator"]},
    "aerodactyl": {"abilities": ["pressure", "rough_skin"]},
    "mewtwo": {"abilities": ["pressure", "inner_focus"]},
    "mew": {"abilities": ["serene_grace", "regenerator"]},
    "articuno": {"abilities": ["pressure", "thick_fat"]},
    "zapdos": {"abilities": ["pressure", "static"]},
    "moltres": {"abilities": ["pressure", "flame_body"]},
}


def main():
    folder = os.path.join(ROOT, "data", "brawlers")
    brawlers = {f[:-5]: json.load(open(os.path.join(folder, f))) for f in os.listdir(folder) if f.endswith(".json")}

    def line(root):
        out, todo = [], [root]
        while todo:
            sid = todo.pop(0)
            out.append(sid)
            nxt = brawlers[sid].get("evolves_to", [])
            todo += [nxt] if isinstance(nxt, str) and nxt else list(nxt)
        return out

    kits = {"_comment": "Generated by tools/build_kits.py: per line (base form id), two signature gadgets (data/moves/gadgets.json) and two Abilities (data/abilities.json). Unlock levels: rules.json kits."}
    for root in sorted(s for s, b in brawlers.items() if not b.get("evolves_from")):
        types = []
        for sid in line(root):
            for t in brawlers[sid]["types"]:
                if t not in types:
                    types.append(t)
        t1 = types[0]
        gadgets = [TYPE_GADGETS[t1][0], TYPE_GADGETS[types[1]][0] if len(types) > 1 else TYPE_GADGETS[t1][1]]
        if gadgets[0] == gadgets[1]:
            gadgets[1] = TYPE_GADGETS[t1][1]
        first = TYPE_ABILITIES[t1][0]
        second = STYLE_ABILITIES.get(brawlers[root].get("style", ""), TYPE_ABILITIES[t1][1])
        if second == first:
            second = TYPE_ABILITIES[t1][1]
        kit = {"gadgets": gadgets, "abilities": [first, second]}
        kit.update(HAND.get(root, {}))
        kits[root] = kit
    path = os.path.join(ROOT, "data", "kits.json")
    with open(path, "w") as f:
        f.write("{\n")
        items = list(kits.items())
        for i, (k, v) in enumerate(items):
            f.write("\t%s: %s%s\n" % (json.dumps(k), json.dumps(v, ensure_ascii=False), "," if i < len(items) - 1 else ""))
        f.write("}\n")
    print("wrote %d lines" % (len(kits) - 1))


if __name__ == "__main__":
    main()
