# Poke Brawl

A mini Brawl Stars–style 3v3 brawler with all 151 original Pokémon, built in **Godot 4.3+**.

## Running

1. Open Godot 4.3 (or newer 4.x) → **Import** → select `project.godot`.
2. Press **F5**. The first open imports the placeholder PNGs automatically.

### Controls

| Touch | Desktop |
| --- | --- |
| **Left stick** (touch anywhere in the left half) – move | WASD |
| **Right stick** – your main attack: drag to aim, release to fire. **Quick tap = auto-aim at the nearest enemy.** Drag back to the centre to cancel. Lobbed attacks land where the stick points (pull it less to throw shorter). Streams fire while you hold the stick and use a tank that refills. | F (auto-aim; hold for streams) |
| **GADGET button** – 3 uses per match (pips around the button): Protect, Agility, Teleport, Smokescreen, Heal Pulse or Sitrus Berry depending on the play style | Space |
| **SUPER button** (gold) – fills as your main attack deals damage; tap when it glows. Aims with the right stick if held, otherwise at the nearest enemy | E |

Mouse clicks act as touches (`emulate_touch_from_mouse`), so you can try the sticks on desktop too.
### Play on your phone

Every push to the default branch builds a web version and publishes it to
**https://preston93lane.github.io/Poke-brawl-/** (GitHub Pages). Open it in Safari or Chrome
and hold the phone in landscape. On iPhone, **Share → Add to Home Screen** installs it as a
full-screen app with its own icon.

The web build uses Godot's Compatibility renderer, so lighting is slightly simpler than in the editor.

## How it plays

- The game opens on a menu: **Battle**, **King of the Hill**, **Brawl Ball**, **Rare Candy Rush**, **Showdown** or **Pokédex**. Then pick your Pokémon, level,
  moves, opponent and arena. Running `scenes/main.tscn` directly in the editor uses the **Main** node's Inspector values instead.
- After every attack there's a short delay before you can attack again. Heavy moves have longer delays.
- **3v3:** you plus two bot teammates against three bots. Pick teammates and opponents in the menu, or leave them random.
- **Battle:** most KOs in 2:30, or first to 25 (a legendary raid boss lands at 1:30). **King of the Hill:** your team alone in the striped zone fills your meter.
  Matches last 2:30; when time runs out the team ahead wins, or it's a draw.
- **Play styles:** every family fights like a Brawl Stars archetype: brawlers (Bull/El Primo), assassins (Mortis/Edgar),
  throwers who lob over walls (Barley/Dynamike), snipers (Piper), healers (Poco/Byron), boomerangs, bouncers (Rico),
  chain lightning, homing orbs, lingering zones, lashes that pull, spinners and more. The menu shows who each one plays like.
- **Main attack variants:** a new variant of your main attack unlocks at levels 2 and 3 (same style, different trick),
  and attacks get a little stronger each level. You choose which one to bring.
- **Water and Flying** types walk over water.
- Every Pokémon *stage* has its own **super**: big attacks, area poison, team heals, shields, teleports, blinding Flash…
- **Types matter:** STAB, an 18-type chart and coverage moves. Super-effective hits pop up orange with "!".
- **Evolve** every 3 KOs (yellow pips next to your health bar; fainting doesn't reset them). Faint and you drop back a stage.
- **Brawl Ball:** touch the Poké Ball to pick it up; your attack kicks it. First to 2 goals.
  **Rare Candy Rush:** candies pop out of the mine; hold 10 as a team with the lead for 10 s. Fainting drops yours.
  **Showdown:** 6 Pokémon, everyone for themselves, no respawns. Smash crates for power cubes (+HP, +damage);
  the poison cloud closes in. After every match a summary shows KOs, damage, healing and the MVP.
- **Walls:** rock walls, trees and gravestones are permanent; cracked walls, boulders and ice blocks break when a
  super hits them. Lava (Cinnabar Gym) can only be crossed by Fire and Flying types.
- **Arenas:** Route 1, Boulder Gym, Dragon's Den, Pallet Pitch, Viridian Forest, all eight Kanto gyms, the Elite Four,
  the Pokémon Tower graveyard and the Safari Zone.
- **Map maker** (home screen): paint tiles, pick floor / wall / liquid, mirror top↔bottom or in quadrants, name and
  save, edit or revert the built-in maps, and test straight away. Maps are saved on your device.
- **Settings:** drag the sticks and buttons where you like them, resize them, swap sides, toggle aim assist.
- **Tall grass** hides you until you attack, get hit, or an enemy walks close.
- Health regenerates after 3 s out of combat. You respawn inside a protective bubble for 2 s (attacking pops it).
- **Items** appear around the map: Potion (heal), Protein / Iron / Carbos (attack / defense / speed until you faint),
  PP Up (an extra ammo bar) and HP Up (more max HP).
- **Legendaries:** in Battle a wild raid boss (Zapdos, Moltres or Articuno) lands at 1:30, and the team that deals the
  most damage to it gets it as an ally for 25 s. In King of the Hill, hold the zone alone for 20 s to awaken the
  arena's guardian (Celebi, Regirock or Rayquaza).

## Project layout

```
data/       JSON content: brawlers/, moves/, arenas/, styles.json, types.json, rules.json  (see docs/DATA.md)
scenes/     main.tscn (match setup), brawler.tscn, projectile.tscn, hud.tscn
scripts/    brawler.gd, projectile.gd, arena.gd, main.gd, *_controller.gd, HUD and touch controls
scripts/data/  GameData autoload + MoveData / SpeciesData
assets/     64x64 painted tiles (tools/make_tiles.py), brawler sheets from the Pokémon Black/White sprites with shiny
            versions in brawlers/shiny/ (tools/import_bw_sprites.py), item icons, shaders, font
tools/      roster.py + build_roster.py (generates brawlers and attacks), make_sprites.py, make_tiles.py, balance_report.py
tests/      headless smoke test (runs in GitHub Actions on every push)
docs/       DATA.md (file formats), DESIGN.md (roadmap: progression, 3v3, multiplayer, renaming)
```

## Exporting

JSON files aren't Godot resources, so in **Project → Export → Resources → Filters to export
non-resource files** add `*.json`, or the data won't be in the build.

## Automated check

`.github/workflows/godot-check.yml` downloads Godot 4.3, imports the project and runs
`tests/smoke_test.tscn`, which validates the data, the damage maths and evolution, then plays both
modes headless. Run it locally with:

```
godot --headless --path . res://tests/smoke_test.tscn
```

## Credits

Pokémon and the Black/White sprites are © Nintendo / Game Freak / The Pokémon Company. The sprites come from
the PokeAPI sprites collection. This is a non-commercial fan project.
