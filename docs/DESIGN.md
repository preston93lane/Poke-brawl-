# Poke Brawl – design & roadmap

Living document: what's built, what's next, and how each big idea will be implemented.

## Pillars

1. **Brawl Stars feel** – twin-stick, short matches, readable at a glance on a phone.
2. **Pokémon depth** – types, coverage and evolution make team building and loadouts matter.
3. **Data-driven** – every creature, move, arena and rule is JSON, so content (or a full rename) needs no code.

## Status

| Feature | State |
| --- | --- |
| Twin-stick touch controls, melee button, desktop fallback | ✅ |
| JSON stat blocks (HP / attack / defense / speed / types) | ✅ |
| 18-type chart, STAB, crits, burn / poison / paralysis | ✅ |
| Move kinds: swipe, dash, projectile (spread, burst, pierce, explode) | ✅ |
| Level-gated movesets (L1 → L3) with free loadout choice | ✅ (level picked in the Inspector for now) |
| Evolution on a 3-KO streak, devolve on faint | ✅ |
| Tall grass hiding, reveal on attack / proximity | ✅ |
| Tile-map arenas (Route 1, Boulder Gym) with 16-bit tiles | ✅ |
| Modes: Duel (first to 5 KOs), King of the Hill | ✅ |
| Menu, mode select, Pokémon / level / loadout / team / arena select | ✅ |
| 3v3 with bot teammates and opponents | ✅ |
| Supers (one per stage) charged by damage dealt | ✅ |
| Bot pathfinding around walls (A* on the tile grid) | ✅ |
| HD shaded sprites, painted tiles, swaying grass, animated water, sky lighting | ✅ |
| Type-themed attack effects (trails, impacts, streams, status auras) | ✅ |
| Brawl Stars-style HUD: scoreboard, timer, kill feed, styled controls | ✅ |
| Pokédex (stats, types, matchups, evolution line, moves) | ✅ |
| Draft screen with type previews for 3v3 | ⏭ |
| Online multiplayer | 🗺 planned (below) |

## Art direction: Brawl Stars × 16-bit Pokémon

* **World:** a 3D grid viewed by a fixed 45° camera, textured with 16×16 pixel tiles (1 tile = 1 metre),
  nearest-neighbour filtering. Trees are upright sprites tilted to face the camera. Rocks and walls are
  boxes with tile textures (an "HD-2D" look). Tall grass is a short alpha-cut box, so you see brawlers sink into it.
* **Brawlers:** 32×32 sprites. Next step: 4-direction walk cycles in an `AnimatedSprite3D`
  (same 32×32 frames, sheet per species) plus attack / hurt frames.
* **Effects:** type-coloured projectiles and explosions today. Later: pixel particle sheets per type (embers, bubbles, leaves, sparks).
* **Replacing art:** drop new PNGs over the files in `assets/` (same names), or point the JSON `sprite` at a new path.

## Combat & balance

Each move trades off **damage, range, rate (cooldown / reload / ammo), hitbox, reliability and utility**.
Examples from the starter kits:

| Move | Strength | Weakness |
| --- | --- | --- |
| Scratch | Fast cooldown, wide arc | Low damage |
| Slash | High crit chance, wide arc | Slower |
| Quick Attack | Gap closer / escape | Long cooldown, only hits one target |
| Ember | Reliable, 3 ammo, can burn | Moderate damage |
| Flamethrower | Huge close-range DPS, pierces | Short range |
| Fire Blast | Big area burst | 2 ammo, slow projectile, slow reload |
| Iron Tail (Pikachu) | **Steel coverage** vs Rock/Ice/Fairy | Slow cooldown |
| Sludge Bomb (Bulbasaur) | **Poison coverage** + area | Slower reload |

**Planned balance tool:** a script that prints each move's sustained DPS
(`power × count × burst ÷ reload`), burst damage (`× ammo`), and effective range, so outliers stand out.
Tuning stays in JSON.

## Progression: levels and loadouts

Moves unlock at levels 1 / 2 / 3, and at any level you choose one unlocked melee and one unlocked ranged move.
**Open question for you:** where do levels come from?

* **Account progression (recommended):** play matches → earn XP per Pokémon → unlock tiers, like Brawl Stars power levels. Saved in `user://save.json`.
* **In-match levelling:** everyone starts at L1 each match and levels from damage dealt/KOs. Fast and arcadey, but it overlaps with evolution.

Each level also gives +5% stats (`rules.level.stat_bonus_per_level`).

## Evolution

* Every 3 KOs evolves you (fainting doesn't reset the count): new sprite, higher stats, full heal, announcement.
* Fainting drops you one stage, so the leader is a target and comebacks are possible.
* All tunable in `rules.json → evolution`.
* **Ideas:** evolved forms could add a signature move (Charizard: Wing Attack), and/or a "Super" meter that charges faster when evolved.

## Type advantages & team building

* Matchups are softened (×1.5 / ×0.67 / ×0.4) so skill still wins, and the damage pop-ups show "!" for super effective and grey for resisted.
* **Coverage moves** (Iron Tail, Sludge Bomb, Bite) let a brawler answer its bad matchups at the cost of STAB.
* **In 3v3:** a draft phase where each player sees the enemy picks' types. The select screen shows each of your moves' effectiveness against them.
* **Later:** team synergy bonuses (e.g. Fire + Grass + Water team gets +5% regen) to reward balanced teams.

## Modes

| Mode | Rules | Status |
| --- | --- | --- |
| Duel | First to N KOs, respawn | ✅ |
| King of the Hill | Stand in the Z zone alone to fill your meter; contested zones pause | ✅ |
| 3v3 Battle / 3v3 KOTH | First to 10 KOs / hold the zone 60 s | ✅ |
| Rare Candy Grab | Collect candies that spawn in the middle and hold 10 to win (Gem Grab analogue) | idea |
| Wild Showdown | Free-for-all; wild Pokémon in grass drop power-ups | idea |
| Gym Challenge | PvE vs a gym-leader boss with phases | idea |

`main.gd` referees the match today. When modes multiply, it will split into a `GameMode` base class with one script per mode.

## Arenas

Arenas are ASCII maps (see `docs/DATA.md`), so new ones are quick to sketch. Each should have one gimmick:

* **Route 1** – starter route with grass patches, a pond and ledges. ✅
* **Boulder Gym** – rocky gym with a central zone and boulders for cover. ✅
* **Viridian Forest** – dense trees and lots of grass; ambush-heavy.
* **Cascade Gym** – a big central pool that splits the map (shots cross it, feet don't).
* **Thunder Gym** – electric barriers that switch on and off on a timer.
* **Rocket Hideout** – spinner tiles that slide you across the floor.

Needed tile features: destructible walls (hits break them), hazards (timed electric tiles), and
moving/spinner floor tiles.

## Legendaries (proposals)

Brawl Stars has no legendaries, so this is where Poke Brawl can be its own game. Options, in the
order I'd recommend:

1. **Legendary Raid (mid-match event).** At 1:30 a legendary bird (Zapdos, Moltres or Articuno,
   picked by arena) lands in the middle as a neutral boss with a big health bar. Both teams fight
   it as well as each other. The team that lands the final hit gets it as an **AI ally for
   25 seconds**: it circles over the field casting its signature move (Thunder, Heat Wave,
   Blizzard) at enemies. It gives the match a comeback moment and a reason to group up.
2. **Legendary Gauge (team meter).** Every hit your team lands fills a shared gauge, more for
   super-effective hits. When it's full, any teammate can tap a **SUMMON** button: the legendary
   swoops in for one devastating move (Mewtwo's Psystrike across the map, Groudon's Precipice
   Blades in a line, Kyogre's Origin Pulse around the zone), then leaves. It rewards type coverage
   and teamwork.
3. **Legendary brawlers (rare picks).** Playable legendaries with high stats but no evolution and
   a longer respawn. Limited to one per match, or unlocked by account progression.
4. **Shrine control (King of the Hill variant).** Holding the zone for 20 s straight awakens the
   arena's guardian legendary for your side (Boulder Gym: Regirock; Dragon's Den: Rayquaza).

Raid and Gauge also fit online play well, because both teams share the same event.

## Other improvements (Brawl Stars baseline)

| Priority | Idea | Why |
| --- | --- | --- |
| High | **Sound and music**: hit sounds per type, super cues, a short music loop | Biggest missing piece of game feel |
| High | **Walk / attack animations** (2–4 frame sprite cycles, squash on hit) | Makes characters feel alive |
| High | **Gadgets**: one active ability with 3 uses per match (Potion, X Speed, Escape Rope) | Brawl Stars' extra decision layer |
| High | **Settings**: stick size, left-handed layout, aim sensitivity, auto-aim on/off | Phone comfort |
| Medium | **Rare Candy Grab** (Gem Grab) and **Showdown** (battle royale with power-up drops) modes | Variety |
| Medium | **Spawn protection** (2 s invulnerable after respawn) and a respawn camera | Fairness |
| Medium | **Trophies / XP per Pokémon** to unlock levels 2–3 (replaces picking the level) | Progression |
| Medium | **Shiny skins** and emotes | Collection and personality |
| Low | **Tutorial** match with prompts, and a training ground with dummies | Onboarding |
| Low | **Mini-map** for the bigger arenas | Awareness |

## Multiplayer plan

The code is already split to make this easier: **controllers** (player / bot) only write `move_input` and
call `use_melee` / `use_ranged`, and `Brawler` and `main` own all game state.

1. **3v3 with bots (local)** ✅ Done: N per team, and bots pick targets by distance, HP and type matchup.
2. **Online with friends (host + join).**
   * Godot's high-level multiplayer: `ENetMultiplayerPeer`, `MultiplayerSpawner` for brawlers and
     projectiles, `MultiplayerSynchronizer` for position, health, ammo and species.
   * **Server-authoritative:** the host runs the real simulation. Clients send stick input and attack
     requests through RPCs, the server validates (cooldown, ammo) and replicates the results.
     Randomness (crits, effects) runs only on the server.
   * Smoothing: interpolate remote brawlers and predict your own movement locally.
   * **Connection:** start with direct IP / LAN, or a free VPN like Tailscale for friends far apart.
     That costs nothing and needs no server.
3. **Online for strangers (later).** A headless Godot server on a small cloud VM, plus a lobby /
   matchmaking service (e.g. Nakama, open source). Only worth it if you go public.

## Original creatures (if you publish)

All Pokémon-specific names, art and move names live in `data/` and `assets/`, and code only uses
internal ids. To make it publishable:

1. Design original creatures that fill the same roles (fire starter line, water line, etc.).
2. Rename `name` fields and move names, and replace the PNGs. Keep or rename the ids.
3. Rename types if desired (`types.json` is the only place they're defined), and rename arenas.
4. Change the project name and icon.

Nothing in the game logic depends on Pokémon IP, so this is a content swap, not a rewrite.

## Roadmap

1. **Now:** you play-test this build. I fix bugs and tune feel (camera, speeds, stick sizes).
2. Character + loadout select screen (pick brawler, level, moves, arena, mode).
3. Walk animations, hit effects, sounds, screen shake.
4. Draft screen with type previews for 3v3.
5. Account progression and save file.
6. More arenas and gimmick tiles. Then online host/join.
