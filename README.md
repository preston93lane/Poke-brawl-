# Poke Brawl

A mini Brawl Stars–style 1v1 brawler with Pokémon, built in **Godot 4.3+**.

## Running

1. Open Godot 4.3 (or newer 4.x) → **Import** → select `project.godot`.
2. Press **F5**. The first open imports the placeholder PNGs automatically.

### Controls

| Touch | Desktop |
| --- | --- |
| **Left stick** (touch anywhere in the left half) – move | WASD |
| **Right stick** – drag to aim, release to fire a projectile. Quick tap = auto-aim at nearest enemy. Drag back to the centre to cancel. | F (auto-aim shot) |
| **MELEE button** – short-range swipe, auto-aims at a nearby enemy | Space |

Mouse clicks act as touches (`emulate_touch_from_mouse`), so you can try the sticks on desktop too.
To test on a phone, use **Remote Debug → Run on device** or an Android/iOS export.

## How it plays

- Pick brawlers, levels, moves, arena and mode on the **Main** node in `scenes/main.tscn` (Inspector).
  A select screen is coming next.
- **Duel:** first to 5 KOs. **King of the Hill:** stand alone in the striped zone to fill your meter (Boulder Gym).
- Every Pokémon has a melee move (MELEE button) and a ranged move (right stick). More moves unlock at levels 2 and 3, and you choose your loadout.
- **Types matter:** STAB, an 18-type chart and coverage moves. Super-effective hits pop up orange with "!".
- **Evolve** on a 3-KO streak (yellow pips next to your health bar). Faint and you drop back a stage.
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
