# Poke Brawl

A mini Brawl Stars–style 1v1 brawler with Pokémon, built in **Godot 4.3+**.

## Running

1. Open Godot 4.3 (or newer 4.x) → **Import** → select `project.godot`.
2. Press **F5**. The first open imports the placeholder PNGs automatically.

### Controls

| Touch | Desktop |
| --- | --- |
| **Left stick** (touch anywhere in the left half) – move | WASD |
| **Right stick** – drag to aim, release to fire. **Quick tap = fire at the nearest enemy you can hit.** Drag back to the centre to cancel. Stream moves (Flamethrower, Hydro Pump…) fire while you hold the stick and use a tank that refills. | F (auto-aim; hold for streams) |
| **MELEE button** – short-range swipe, auto-aims at a nearby enemy | Space |
| **SUPER button** (gold, above MELEE) – fills as you deal damage; tap when it glows. Aims with the right stick if held, otherwise at the nearest enemy | E |

Mouse clicks act as touches (`emulate_touch_from_mouse`), so you can try the sticks on desktop too.
### Play on your phone

Every push to the default branch builds a web version and publishes it to
**https://preston93lane.github.io/Poke-brawl-/** (GitHub Pages). Open it in Safari or Chrome
and hold the phone in landscape. On iPhone, **Share → Add to Home Screen** installs it as a
full-screen app with its own icon.

The web build uses Godot's Compatibility renderer, so lighting is slightly simpler than in the editor.

## How it plays

- The game opens on a menu: **Battle**, **King of the Hill** or **Pokédex**. Then pick your Pokémon, level,
  moves, opponent and arena. Running `scenes/main.tscn` directly in the editor uses the **Main** node's Inspector values instead.
- After every attack there's a short delay before you can attack again. Heavy moves have longer delays.
- **3v3:** you plus two bot teammates against three bots. Pick teammates and opponents in the menu, or leave them random.
- **Battle:** first team to 10 KOs. **King of the Hill:** your team alone in the striped zone fills your meter.
- Every Pokémon has a melee move (MELEE button) and a ranged move (right stick). More moves unlock at levels 2 and 3, and you choose your loadout.
- Every Pokémon *stage* has its own **super**: big attacks, area poison, team heals, shields, teleports, blinding Flash…
- **Types matter:** STAB, an 18-type chart and coverage moves. Super-effective hits pop up orange with "!".
- **Evolve** every 3 KOs (yellow pips next to your health bar; fainting doesn't reset them). Faint and you drop back a stage.
- **Tall grass** hides you until you attack, get hit, or an enemy walks close.
- Health regenerates after 3 s out of combat.

## Project layout

```
data/       JSON content: brawlers/, arenas/, moves.json, types.json, rules.json  (see docs/DATA.md)
scenes/     main.tscn (match setup), brawler.tscn, projectile.tscn, hud.tscn
scripts/    brawler.gd, projectile.gd, arena.gd, main.gd, *_controller.gd, HUD and touch controls
scripts/data/  GameData autoload + MoveData / SpeciesData
assets/     16x16 tiles and 32x32 brawler sprites (placeholders; replace with same file names)
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
