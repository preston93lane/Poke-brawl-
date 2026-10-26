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

- **Pikachu** (you, blue ring) vs a **Charmander** bot (red ring) on a symmetric arena with a few obstacles.
- Projectile attack: 3 ammo bars that reload over time (shown under your health bar).
- Melee attack: a wide, short arc with a cooldown (sweep shown on the button).
- Health regenerates after 3 s without attacking or taking damage.
- First to faint loses; tap to play again.

## Project layout

```
scenes/   main.tscn (round setup), brawler.tscn, projectile.tscn, hud.tscn
scripts/  brawler.gd          – movement, attacks, damage, visuals
          brawler_data.gd     – per-Pokémon stats resource
          player_controller.gd / bot_controller.gd – who drives a brawler
          virtual_joystick.gd / touch_button.gd   – multi-touch controls
          follow_camera.gd    – fixed-angle follow camera
          arena.gd            – builds floor, walls and obstacles
data/     pikachu.tres, charmander.tres – tweak stats here in the Inspector
assets/brawlers/ – placeholder sprites (replace with real art, same file names)
```

### Common tweaks

- **Camera angle:** `Camera` node in `main.tscn` → `pitch_degrees` (45 by default; higher = more top-down) and `distance`.
- **Stats:** open a `.tres` in `data/` and edit in the Inspector.
- **New brawler:** duplicate a `.tres`, change the art and stats, and point `player_data` / `enemy_data` on the `Main` node at it.
- **Map layout:** edit `OBSTACLES` in `scripts/arena.gd`.
- **Bot difficulty:** `reaction_time` and `aim_error_degrees` in `scripts/bot_controller.gd`.
