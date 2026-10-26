# Data files

Everything about brawlers, moves, types, arenas and tuning lives in JSON under `data/`.
`GameData` (an autoload) loads it all at startup and prints errors for typos such as unknown
move ids or types. No code changes are needed to add content.

## `data/brawlers/<id>.json` — one file per evolution stage

```json
{
	"name": "Charmander",
	"types": ["fire"],                     // one or two types from types.json
	"sprite": "res://assets/brawlers/charmander.png",
	"sprite_scale": 1.0,                   // evolutions draw bigger (1.15, 1.3…)
	"stats": { "hp": 2900, "attack": 105, "defense": 85, "speed": 105 },
	"super": "fire_spin",                  // this stage's own super (a move with slot "super")
	"evolves_to": "charmeleon",            // optional
	"evolves_from": "",                    // set on evolved forms
	"moves": [                             // evolved forms may omit this to inherit the base form's list
		{ "move": "scratch", "level": 1 },
		{ "move": "ember",   "level": 1 }
	]
}
```

* **Stats:** around 100 is average. `speed` × `rules.speed_to_meters` = metres per second (100 → 5 m/s).
* **Sprite:** 32×32 pixel art (drawn at 1.6 m tall). If the file is missing, a coloured blob is generated from the first type.
* **Moves:** at each level the player picks one unlocked **melee** move and one unlocked **ranged** move.
  The default loadout is the newest move in each slot.

## `data/moves.json`

| Field | Used by | Meaning |
| --- | --- | --- |
| `name`, `type` | all | Display name and type (STAB + matchups) |
| `slot` | all | `melee` = MELEE button with a cooldown, `ranged` = right stick with ammo, `super` = SUPER button |
| `kind` | all | `melee` (arc swipe), `dash` (lunge, hits first enemy), `projectile`, `stream` (continuous cone while the stick is held), `area` (strike a circle), `self` (no attack, just the extras below) |
| `power` | all | Base damage before attack/defense, STAB, type and crit |
| `crit_chance` | all | 0–1; crits deal `rules.crit_multiplier` |
| `effect` | all | Optional: `{ "type": "burn"/"poison"/"leech", "chance", "duration", "dps" }` (leech heals whoever planted it) or `{ "type": "slow", "chance", "duration", "amount" }` (slow = paralysis) |
| `range`, `arc`, `cooldown` | melee | Reach in metres, swing width in degrees, seconds between uses |
| `dash_distance`, `dash_speed`, `cooldown` | dash | How far and fast the lunge goes |
| `range`, `speed` | projectile | Travel distance and metres per second |
| `ammo`, `reload` | projectile | Ammo bars and seconds to reload one |
| `count`, `spread` | projectile | Shots per volley fanned across `spread` degrees (e.g. Bubble Beam) |
| `burst_count`, `burst_interval` | projectile | Repeat the volley N times (e.g. Flamethrower's stream) |
| `pierce` | projectile | Passes through enemies instead of stopping |
| `radius` | projectile | Hitbox size (bigger is easier to land) |
| `explode_radius` | projectile | Area damage where it lands or hits (e.g. Fire Blast) |
| `power`, `range`, `arc`, `tank`, `reload` | stream | Damage **per second** while firing, reach, cone width in degrees, seconds of fire from a full tank, seconds to refill it. Effect `chance` is rolled every 0.15 s tick, so keep it small |
| `dash_pierce` | dash | Keep going through enemies, hitting each once (Outrage) |
| `range`, `area_radius`, `area_delay` | area | How far away the circle can land (0 = around you), its size, and a delay before it hits (Future Sight) |
| `drain` | super | Heal this fraction of the damage dealt (Giga Drain) |
| `heal`, `team_heal`, `support_radius` | super | Heal yourself / allies within `support_radius` by a fraction of max HP |
| `buff` | super | `{ "attack": 0.3, "defense": 0.5, "speed": 0.4, "duration": 4, "allies": true }` |
| `blink` | super | Teleport this many metres (stops at walls) |
| `blind` | super | `{ "radius": 8, "duration": 3 }`: enemies with line of sight can't see anyone |
| `cleanse` | super | Cure burn, poison, paralysis and blindness |
| `charge` | super | Damage needed to fill the meter (default `rules.super_charge_damage`) |
| `delay` | all | Seconds before *any* attack can be used again (default `rules.attack_delay` 0.45 s for ranged, `rules.melee_attack_delay` 0.35 s for melee). Heavy moves use longer delays |

Run `python3 tools/balance_report.py` after changing numbers. It lists every move's damage per second,
burst and reach, plus a strength score per Pokémon, so outliers stand out.

**Damage** = `power × attacker.attack ÷ defender.defense × STAB × type multiplier × crit × rules.damage_scale`.
Burn and poison deal flat `dps`, so defense doesn't reduce them.

## `data/types.json`

Full 18-type chart. Multipliers are softened from the main games (`1.5 / 0.67 / 0.4`) so a bad
matchup is a disadvantage, not an auto-loss. Dual types multiply (×2.25 and ×0.45 are the extremes).
`stab` is the same-type attack bonus.

## `data/arenas/<id>.json`

```json
{ "name": "Route 1", "floor": "grass", "map": ["TTTT…", "…"] }
```

| Char | Tile |
| --- | --- |
| `.` | Floor (`floor` texture: `grass` or `gym_floor`) |
| `,` | Dirt path |
| `"` | Tall grass – hides brawlers |
| `T` | Tree (blocks everything) |
| `#` | Rock wall (blocks everything) |
| `B` | Boulder (blocks everything) |
| `~` | Water (blocks walking, shots fly over) |
| `1` / `2` | Team spawns, one tile per teammate |
| `Z` | King-of-the-hill zone |

The map's top is the enemy side. Keep it 180°-symmetric for fairness.

## `data/rules.json`

Global tuning: regen, crit multiplier, stat bonus per level, kills to evolve, whether fainting
devolves you, tall-grass reveal distance, and per-mode settings (KOs to win, zone hold time,
respawn time).
