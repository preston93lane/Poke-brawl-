# Data files

Everything about brawlers, moves, types, arenas and tuning lives in JSON under `data/`.
`GameData` (an autoload) loads it all at startup and prints errors for typos such as unknown
move ids or types. No code changes are needed to add content.

## `data/brawlers/<id>.json` — one file per evolution stage

These files, `data/moves/generated.json` and `data/styles.json` are **generated** by
`python3 tools/build_roster.py` from the roster table in `tools/roster.py` (families, play styles,
base stats, attack names). Edit the roster and re-run it rather than editing the output by hand;
hand-made supers live in `data/moves/supers.json` and are kept.

```json
{
	"name": "Charmander",
	"types": ["fire"],                     // one or two types from types.json
	"sprite": "res://assets/brawlers/charmander.png",
	"sprite_scale": 1.0,                   // evolutions draw bigger (1.15, 1.3…)
	"style": "stream",                     // play style from styles.json (which brawler it plays like)
	"stats": { "hp": 3100, "attack": 104, "defense": 88, "speed": 101 },
	"super": "fire_spin",                  // this stage's own super (a move with slot "super")
	"gadget": "gadget_sitrus",             // limited-use gadget (evolutions inherit it)
	"evolves_to": "charmeleon",            // optional; a list for branching lines (Eevee)
	"evolves_from": "",                    // set on evolved forms
	"moves": [                             // main attack variants; evolved forms may omit this to inherit
		{ "move": "charmander_main1", "level": 1 },
		{ "move": "charmander_main2", "level": 2 },
		{ "move": "charmander_main3", "level": 3 }
	]
}
```

* **Stats:** around 100 is average. `speed` × `rules.speed_to_meters` = metres per second. `hp` is multiplied by
  `rules.hp_multiplier` (1.5) when loaded.
* **Main attack:** one new variant unlocks at each level and the player picks one. Variants share the
  play style but work differently (e.g. a single slug, a fan, or a lob). Higher levels also add
  `rules.level_power_bonus` damage per level.
* **Branching lines:** Eevee lists three evolutions; the player picks one in the menu (or random). Each branch can
  have its own `moves`, which replace the base form's while evolved.

## `data/styles.json`

Play styles, each modelled on a Brawl Stars archetype: `{ "label", "like", "desc" }`. Shown in the menu and Pokédex.

## `data/moves/*.json`

Every `.json` file in `data/moves/` is loaded; ids must be unique across them.

| Field | Used by | Meaning |
| --- | --- | --- |
| `name`, `type` | all | Display name and type (STAB + matchups) |
| `slot` | all | `main` = right stick, uses ammo; `gadget` = GADGET button, `rules.gadget.uses` per match with a cooldown; `super` = SUPER button, charged by main-attack damage |
| `kind` | all | `melee` (arc swipe), `dash` (lunge, hits first enemy), `projectile`, `stream` (continuous cone while the stick is held), `area` (strike a circle), `self` (no attack, just the extras below) |
| `power` | all | Base damage before attack/defense, STAB, type and crit (per second for streams and lingering zones) |
| `crit_chance` | all | 0–1; crits deal `rules.crit_multiplier` |
| `effect` | all | Optional: `{ "type": "burn"/"poison"/"leech", "chance", "duration", "dps" }` (leech heals whoever planted it), `{ "type": "slow", "chance", "duration", "amount" }`, `{ "type": "stun", ... "duration" }` (can't move or attack) or `{ "type": "blind", ... "duration" }` |
| `ammo`, `reload` | main | Ammo bars and seconds to reload one (every main attack kind uses ammo) |
| `range`, `arc` | melee | Reach in metres, swing width in degrees (360 = spin) |
| `dash_distance`, `dash_speed` | dash | How far and fast the lunge goes |
| `dash_pierce` | dash | Keep going through enemies, hitting each once |
| `explode_radius` | dash | Slam: hit everyone this close to where the dash ends |
| `range`, `speed` | projectile | Travel distance and metres per second |
| `count`, `spread` | projectile | Shots per volley fanned across `spread` degrees |
| `burst_count`, `burst_interval` | projectile | Repeat the volley N times |
| `pierce` | projectile | Passes through enemies instead of stopping |
| `radius` | projectile | Hitbox size (bigger is easier to land) |
| `explode_radius` | projectile | Area damage where it lands or hits |
| `lob` | projectile | Arcs over walls and lands where you aim (stick distance), hitting the area there |
| `bounces` | projectile | Ricochets off walls this many times |
| `returns` | projectile | Flies to full range and back to you, hitting on both legs (boomerang) |
| `homing` | projectile | Turn rate (radians/s) toward the nearest visible enemy ahead |
| `chain` | projectile | Jumps to this many more enemies within 3.5 m (80% damage each jump) |
| `distance_bonus` | projectile | Damage multiplier reached at full range (snipers) |
| `heal_allies` | projectile | HP healed on teammates the shot passes through |
| `linger`, `linger_radius` | projectile | Leaves a zone for `linger` seconds that deals `power` per second |
| `knockback` | melee, dash, projectile, area | Metres targets are pushed away (negative pulls them toward you) |
| `power`, `range`, `arc`, `tank`, `reload` | stream | Damage **per second** while firing, reach, cone width in degrees, seconds of fire from a full tank, seconds to refill it. Effect `chance` is rolled every 0.15 s tick, so keep it small |
| `range`, `area_radius`, `area_delay` | area | How far away the circle can land (0 = around you), its size, and a delay before it hits |
| `drain` | all | Heal this fraction of the damage dealt |
| `heal`, `team_heal`, `support_radius` | super, gadget | Heal yourself / allies within `support_radius` by a fraction of max HP |
| `protect` | super, gadget | Seconds of damage immunity |
| `buff` | super, gadget | `{ "attack": 0.3, "defense": 0.5, "speed": 0.4, "duration": 4, "allies": true }` |
| `blink` | super, gadget | Teleport this many metres (stops at walls) |
| `blind` | super | `{ "radius": 8, "duration": 3 }`: enemies with line of sight can't see anyone |
| `cleanse` | super, gadget | Cure burn, poison, slow, stun and blindness |
| `invisible` | super | Seconds of invisibility; enemies only spot you from 1.2 m, and attacking ends it |
| `self_damage` | super | Fraction of your own max HP spent on use; never knocks you out (Explosion) |
| `bonus_vs_status` | all | Damage multiplier against targets that already have a status (Hex) |
| `charge` | super | Damage needed to fill the meter (default `rules.super_charge_damage`) |
| `delay` | all | Seconds before *any* attack can be used again (default `rules.attack_delay`, or `rules.melee_attack_delay` for melee and dash) |

Run `python3 tools/balance_report.py` after changing numbers. It summarises health and damage per second for each
play style and lists main attacks that are far from the average.

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


**Tiles:** `.` floor, `,` path, `"` tall grass, `T` tree and `#` rock wall (permanent), `X` cracked wall and
`B` boulder (breakable: supers smash them), `~` water (Water/Flying types walk on it), `1`/`2` team spawns,
`Z` King of the Hill zone, `G` Brawl Ball goal (each goal belongs to the nearer team), `S` Showdown spawn,
`P` Showdown power-cube crate, `I` ice block (breakable), `K` gravestone (permanent). Optional `"floor"` (grass,
gym_floor, sand, wood, metal, pool, ice, dark, psychic, volcanic, path), `"wall"` (rock, metal_wall, brick, hedge,
ice_block, wood_wall, cracked) and `"liquid"` (`water`: Water/Flying types cross it, `lava`: Fire/Flying types).
Maps made in the map maker are saved to `user://arenas/` and override a built-in map with the same id. Mode tiles are plain floor in other modes. An optional `"modes": [...]` limits an
arena to those modes (Brawl Ball also needs `G` tiles, King of the Hill needs `Z`). Rare Candy Rush puts its mine
in the zone's centre, or the middle of the map. Showdown without `S`/`P` tiles spreads spawns and crates itself.
Mode rules (goals to win, candy countdown, cloud timing and damage, power cube bonuses) are in `rules.json → modes`.
## Art

`assets/brawlers/*.png` (three 64×64 views side by side: front, side facing right, back) and `assets/tiles/*.png` (64×64 per metre) are generated by
`python3 tools/make_sprites.py` and `python3 tools/make_tiles.py`. Each script takes an optional
contact-sheet path for previewing. Replace any PNG with real art (same name) whenever you like.
Effects per type (colours, gravity, glow) are in `scripts/vfx.gd` → `STYLES`.

## `data/items.json`

Pickups that spawn on open floor every `spawn.interval` seconds (at most `spawn.max_on_map` at once).
Anyone except legendaries picks them up by walking over them.

| Field | Meaning |
| --- | --- |
| `heal` | Heal this fraction of max HP (Potion) |
| `boost` | `{ "attack" / "defense" / "speed": bonus }` until you faint; stacks up to `spawn.boost_cap` (Protein, Iron, Carbos) |
| `extra_ammo` | One more ammo bar, or a 35% bigger stream tank, until you faint (PP Up); max `spawn.max_extra_ammo` |
| `max_hp` | More max HP until you faint (HP Up); max `spawn.max_hp_cap` |
| `weight` | Relative spawn chance |

## Legendaries

Legendary Pokémon are normal brawler files with `"legendary": true`. They can't be picked in the menu.
Each arena names a `raid_boss` (Battle) and a `guardian` (King of the Hill). Timings are in
`rules.json → legendary`:

* **Raid (Battle):** with `raid_time_left` seconds to go, the boss lands in the middle with
  `boss_hp_multiplier`× HP and attacks both teams. When it faints, **the team that dealt the most damage
  to it** gets it as an ally for `ally_duration` seconds.
* **Shrine (King of the Hill):** hold the zone with only your team in it for `shrine_hold` seconds straight
  and the guardian joins you for `ally_duration` seconds. The shrine then rests for `shrine_cooldown` seconds.
* Summoned legendaries can't be hurt, fly over walls and fight with their own moves and super.

## `data/rules.json`

Global tuning: `spawn_protection` seconds, match `time_limit` per mode, regen, crit multiplier, stat bonus per level, kills to evolve, whether fainting
devolves you, tall-grass reveal distance, and per-mode settings (KOs to win, zone hold time,
respawn time).
