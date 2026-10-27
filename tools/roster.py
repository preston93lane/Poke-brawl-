"""The full roster: every Pokemon, its family's play style and attack names.

Edit this table, then run   python3 tools/build_roster.py   to regenerate
data/brawlers/*.json and data/moves/generated.json, and
python3 tools/make_sprites.py   for any new sprites.

FAMILIES entries:
    style     : play style from build_roster.STYLES (shotgun, sniper, gunner...)
    mains     : three main attacks [(name, type)] unlocked at levels 1, 2, 3
    members   : evolution order; each is
                (id, name, types, (hp, atk, def, spatk, spdef, speed) base stats,
                 super, sprite)
                super  = existing super id from data/moves/supers.json, or a new
                         super *name* (built from the style's super template)
                sprite = None for hand-drawn sprites in make_sprites.py, else
                         (body plan, colour, accent colour, [features])
    mains_override (optional, per member) lets a branch (Eevee's evolutions) use
    its own attack names.
"""

# Body plans: biped quad bird fish serpent blob bug ball plant humanoid shell
# Features: ears_pointy ears_round ears_long horn horns tail tail_flame wings fins
#           shell spikes leaf flower antenna mane claws tentacles beak crest
#           spots stripes gem whiskers mask fluff

FAMILIES = [
    dict(style="thrower", mains=[("Seed Bomb", "grass"), ("Sludge Bomb", "poison"), ("Petal Blizzard", "grass")], members=[
        ("bulbasaur", "Bulbasaur", ["grass", "poison"], (45, 49, 49, 65, 65, 45), "leech_seed", None),
        ("ivysaur", "Ivysaur", ["grass", "poison"], (60, 62, 63, 80, 80, 60), "poison_powder", None),
        ("venusaur", "Venusaur", ["grass", "poison"], (80, 82, 83, 100, 100, 80), "giga_drain", None)]),
    dict(style="stream", mains=[("Ember", "fire"), ("Flamethrower", "fire"), ("Inferno", "fire")], members=[
        ("charmander", "Charmander", ["fire"], (39, 52, 43, 60, 50, 65), "fire_spin", None),
        ("charmeleon", "Charmeleon", ["fire"], (58, 64, 58, 80, 65, 80), "flame_charge", None),
        ("charizard", "Charizard", ["fire", "flying"], (78, 84, 78, 109, 85, 100), "blast_burn", None)]),
    dict(style="gunner", mains=[("Water Gun", "water"), ("Bubble Beam", "water"), ("Hydro Pump", "water")], members=[
        ("squirtle", "Squirtle", ["water"], (44, 48, 65, 50, 64, 43), "withdraw", None),
        ("wartortle", "Wartortle", ["water"], (59, 63, 80, 65, 80, 58), "aqua_ring", None),
        ("blastoise", "Blastoise", ["water"], (79, 83, 100, 85, 105, 78), "hydro_cannon", None)]),
    dict(style="zone", mains=[("String Shot", "bug"), ("Poison Powder", "poison"), ("Silver Wind", "bug")], members=[
        ("caterpie", "Caterpie", ["bug"], (45, 30, 35, 20, 20, 45), "Sticky Web", ("bug", "78c850", "f8e070", ["antenna", "spots"])),
        ("metapod", "Metapod", ["bug"], (50, 20, 55, 25, 25, 30), "Spore Cocoon", ("blob", "70b048", "a8d070", ["shell"])),
        ("butterfree", "Butterfree", ["bug", "flying"], (60, 45, 50, 90, 80, 70), "Quiver Dance", ("bug", "6a5aa8", "f0f0f8", ["wings", "antenna"]))]),
    dict(style="assassin", mains=[("Poison Sting", "poison"), ("Fury Attack", "bug"), ("Twineedle", "bug")], members=[
        ("weedle", "Weedle", ["bug", "poison"], (40, 35, 30, 20, 20, 50), "Pin Rush", ("bug", "d89850", "f0d0a0", ["horn", "spikes"])),
        ("kakuna", "Kakuna", ["bug", "poison"], (45, 25, 50, 25, 25, 35), "Kakuna Roll", ("blob", "e8c040", "f0e090", ["shell"])),
        ("beedrill", "Beedrill", ["bug", "poison"], (65, 90, 40, 45, 80, 75), "Fell Stinger", ("bug", "f0c830", "302820", ["wings", "stripes", "spikes"]))]),
    dict(style="piercer", mains=[("Gust", "flying"), ("Air Cutter", "flying"), ("Hurricane", "flying")], members=[
        ("pidgey", "Pidgey", ["normal", "flying"], (40, 45, 40, 35, 35, 56), "Wing Gust", ("bird", "b88850", "f0e0c0", ["beak", "wings"])),
        ("pidgeotto", "Pidgeotto", ["normal", "flying"], (63, 60, 55, 50, 50, 71), "Air Slash", ("bird", "a87840", "f0e0c0", ["beak", "wings", "crest"])),
        ("pidgeot", "Pidgeot", ["normal", "flying"], (83, 80, 75, 70, 70, 101), "Hurricane Blast", ("bird", "c89858", "f8e8c8", ["beak", "wings", "crest", "mane"]))]),
    dict(style="assassin", mains=[("Quick Attack", "normal"), ("Hyper Fang", "normal"), ("Super Fang", "normal")], members=[
        ("rattata", "Rattata", ["normal"], (30, 56, 35, 25, 35, 72), "Crunch Rush", ("quad", "9868b0", "f0e0c0", ["ears_round", "whiskers", "tail"])),
        ("raticate", "Raticate", ["normal"], (55, 81, 60, 50, 70, 97), "Super Fang Frenzy", ("quad", "b88850", "f0e0c0", ["ears_round", "whiskers", "tail", "claws"]))]),
    dict(style="gunner", mains=[("Peck", "flying"), ("Fury Attack", "normal"), ("Drill Peck", "flying")], members=[
        ("spearow", "Spearow", ["normal", "flying"], (40, 60, 30, 31, 31, 70), "Aerial Ace", ("bird", "a86848", "e8b890", ["beak", "wings"])),
        ("fearow", "Fearow", ["normal", "flying"], (65, 90, 65, 61, 61, 100), "Drill Run Barrage", ("bird", "b88050", "e8c8a0", ["beak", "wings", "crest"]))]),
    dict(style="lasher", mains=[("Wrap", "normal"), ("Poison Fang", "poison"), ("Poison Tail", "poison")], members=[
        ("ekans", "Ekans", ["poison"], (35, 60, 44, 40, 54, 55), "Glare", ("serpent", "a070b8", "e8d070", ["stripes"])),
        ("arbok", "Arbok", ["poison"], (60, 95, 69, 65, 79, 80), "Coil Crush", ("serpent", "8058a0", "e8c860", ["mask", "stripes"]))]),
    dict(style="chain", mains=[("Thunder Shock", "electric"), ("Thunderbolt", "electric"), ("Thunder", "electric")], members=[
        ("pikachu", "Pikachu", ["electric"], (35, 55, 40, 50, 50, 90), "flash", None),
        ("raichu", "Raichu", ["electric"], (60, 90, 55, 90, 80, 110), "discharge", None)]),
    dict(style="spinner", mains=[("Rapid Spin", "normal"), ("Sand Tomb", "ground"), ("Crush Claw", "normal")], members=[
        ("sandshrew", "Sandshrew", ["ground"], (50, 75, 85, 20, 30, 40), "Sandstorm", ("ball", "e0c060", "f0e0b0", ["ears_round", "claws"])),
        ("sandslash", "Sandslash", ["ground"], (75, 100, 110, 45, 55, 65), "Earthquake Spin", ("ball", "d8b048", "a07840", ["spikes", "claws"]))]),
    dict(style="brawler", mains=[("Double Kick", "fighting"), ("Poison Fang", "poison"), ("Earth Power", "ground")], members=[
        ("nidoran_f", "Nidoran F", ["poison"], (55, 47, 52, 40, 40, 41), "Double Slam", ("quad", "90b8e0", "f0f0f8", ["ears_long", "spikes"])),
        ("nidorina", "Nidorina", ["poison"], (70, 62, 67, 55, 55, 56), "Stomp", ("quad", "78a8d8", "f0f0f8", ["ears_long", "spikes", "claws"])),
        ("nidoqueen", "Nidoqueen", ["poison", "ground"], (90, 92, 87, 75, 85, 76), "Superpower Slam", ("humanoid", "5888c0", "e8e0b8", ["ears_long", "spikes", "tail"]))]),
    dict(style="brawler", mains=[("Horn Attack", "normal"), ("Poison Jab", "poison"), ("Megahorn", "bug")], members=[
        ("nidoran_m", "Nidoran M", ["poison"], (46, 57, 40, 40, 40, 50), "Horn Rush", ("quad", "c088c8", "f0f0f8", ["ears_long", "horn", "spots"])),
        ("nidorino", "Nidorino", ["poison"], (61, 72, 57, 55, 55, 65), "Horn Drill", ("quad", "b070c0", "f0f0f8", ["ears_long", "horn", "spikes"])),
        ("nidoking", "Nidoking", ["poison", "ground"], (81, 102, 77, 85, 75, 85), "Thrash", ("humanoid", "9058b0", "e8e0c8", ["ears_long", "horn", "spikes", "tail"]))]),
    dict(style="healer", mains=[("Disarming Voice", "fairy"), ("Moonlight", "fairy"), ("Dazzling Gleam", "fairy")], members=[
        ("clefairy", "Clefairy", ["fairy"], (70, 45, 48, 60, 65, 35), "Wish", ("biped", "f8c0c8", "f8e0e8", ["ears_pointy", "wings", "tail"])),
        ("clefable", "Clefable", ["fairy"], (95, 70, 73, 95, 90, 60), "Moonlight Waltz", ("biped", "f0a8b8", "f8e0e8", ["ears_pointy", "wings", "fluff"]))]),
    dict(style="homing", mains=[("Ember", "fire"), ("Will-O-Wisp", "fire"), ("Fire Blast", "fire")], members=[
        ("vulpix", "Vulpix", ["fire"], (38, 41, 40, 50, 65, 65), "Flame Wisps", ("quad", "d86838", "f0a050", ["ears_pointy", "tail_flame", "fluff"])),
        ("ninetales", "Ninetales", ["fire"], (73, 76, 75, 81, 100, 100), "Nine Tails Inferno", ("quad", "f0e0a0", "f8f0d0", ["ears_pointy", "tail", "mane"]))]),
    dict(style="tank_wave", mains=[("Hyper Voice", "normal"), ("Round", "normal"), ("Sing Wave", "normal")], members=[
        ("jigglypuff", "Jigglypuff", ["normal", "fairy"], (115, 45, 20, 45, 25, 20), "Lullaby", ("ball", "f8b8c8", "f8d8e0", ["ears_pointy", "crest"])),
        ("wigglytuff", "Wigglytuff", ["normal", "fairy"], (140, 70, 45, 85, 50, 45), "Perish Song", ("biped", "f8b0c0", "f8f0f0", ["ears_long", "crest", "fluff"]))]),
    dict(style="assassin", mains=[("Leech Life", "bug"), ("Bite", "dark"), ("Cross Poison", "poison")], members=[
        ("zubat", "Zubat", ["poison", "flying"], (40, 45, 35, 30, 40, 55), "Supersonic Dive", ("bird", "6088c8", "b090d8", ["wings", "ears_pointy"])),
        ("golbat", "Golbat", ["poison", "flying"], (75, 80, 70, 65, 75, 90), "Leech Frenzy", ("bird", "5878c0", "c080d0", ["wings", "ears_pointy", "fluff"]))]),
    dict(style="zone", mains=[("Acid Spray", "poison"), ("Stun Spore", "grass"), ("Toxic Cloud", "poison")], members=[
        ("oddish", "Oddish", ["grass", "poison"], (45, 50, 55, 75, 65, 30), "Sweet Scent", ("plant", "4868b0", "58a848", ["leaf"])),
        ("gloom", "Gloom", ["grass", "poison"], (60, 65, 70, 85, 75, 40), "Stench Cloud", ("plant", "4860a0", "c05040", ["leaf", "flower"])),
        ("vileplume", "Vileplume", ["grass", "poison"], (75, 80, 85, 110, 90, 50), "Petal Dance Field", ("plant", "3858a0", "e04848", ["flower", "spots"]))]),
    dict(style="brawler", mains=[("Fury Cutter", "bug"), ("Spore Slash", "grass"), ("X-Scissor", "bug")], members=[
        ("paras", "Paras", ["bug", "grass"], (35, 70, 55, 45, 55, 25), "Spore Leap", ("bug", "e88848", "e05040", ["claws", "spots"])),
        ("parasect", "Parasect", ["bug", "grass"], (60, 95, 80, 60, 80, 30), "Mushroom Slam", ("bug", "e06838", "e04838", ["claws", "spots", "shell"]))]),
    dict(style="homing", mains=[("Confusion", "psychic"), ("Signal Beam", "bug"), ("Bug Buzz", "bug")], members=[
        ("venonat", "Venonat", ["bug", "poison"], (60, 55, 50, 40, 55, 45), "Supersonic Swarm", ("ball", "7858a8", "e05050", ["antenna", "fluff"])),
        ("venomoth", "Venomoth", ["bug", "poison"], (70, 65, 60, 90, 75, 90), "Quiver Storm", ("bug", "b090d0", "d8c0e8", ["wings", "antenna"]))]),
    dict(style="assassin", mains=[("Dig", "ground"), ("Mud-Slap", "ground"), ("Drill Run", "ground")], members=[
        ("diglett", "Diglett", ["ground"], (10, 55, 25, 35, 45, 95), "Fissure Dash", ("blob", "a06840", "f09090", ["spots"])),
        ("dugtrio", "Dugtrio", ["ground"], (35, 100, 50, 50, 70, 120), "Triple Dig", ("blob", "905838", "f09090", ["spots", "mane"]))]),
    dict(style="bouncer", mains=[("Pay Day", "normal"), ("Coin Scatter", "normal"), ("Power Gem", "rock")], members=[
        ("meowth", "Meowth", ["normal"], (40, 45, 35, 40, 40, 90), "Jackpot", ("biped", "f0e0b0", "f8d040", ["ears_pointy", "whiskers", "gem", "tail"])),
        ("persian", "Persian", ["normal"], (65, 70, 60, 65, 65, 115), "Power Gem Storm", ("quad", "f0d8a0", "e04848", ["ears_pointy", "whiskers", "gem", "tail"]))]),
    dict(style="homing", mains=[("Confusion", "psychic"), ("Water Pulse", "water"), ("Psychic", "psychic")], members=[
        ("psyduck", "Psyduck", ["water"], (50, 52, 48, 65, 50, 55), "Headache Burst", ("biped", "f0d040", "f0e8a0", ["beak", "crest"])),
        ("golduck", "Golduck", ["water"], (80, 82, 78, 95, 80, 85), "Hydro Mind", ("humanoid", "4880c8", "f0d850", ["beak", "gem", "fins"]))]),
    dict(style="brawler", mains=[("Karate Chop", "fighting"), ("Cross Chop", "fighting"), ("Close Combat", "fighting")], members=[
        ("mankey", "Mankey", ["fighting"], (40, 80, 35, 35, 45, 70), "bulk_up", None),
        ("primeape", "Primeape", ["fighting"], (65, 105, 60, 60, 70, 95), "rampage", None),
        ("annihilape", "Annihilape", ["fighting", "ghost"], (110, 115, 80, 50, 90, 90), "rage_fist", None)]),
    dict(style="assassin", mains=[("Flame Wheel", "fire"), ("Fire Fang", "fire"), ("Extreme Speed", "normal")], members=[
        ("growlithe", "Growlithe", ["fire"], (55, 70, 45, 70, 50, 60), "Flare Rush", ("quad", "f08838", "f0e0b0", ["ears_round", "stripes", "fluff", "tail"])),
        ("arcanine", "Arcanine", ["fire"], (90, 110, 80, 100, 80, 95), "Flare Blitz", ("quad", "f07830", "f0e0b0", ["ears_pointy", "stripes", "mane", "tail"]))]),
    dict(style="shotgun", mains=[("Bubble", "water"), ("Water Pulse", "water"), ("Hydro Burst", "water")], members=[
        ("poliwag", "Poliwag", ["water"], (40, 50, 40, 40, 40, 90), "Belly Drum Charge", ("ball", "5880d0", "f8f8f8", ["tail", "stripes"])),
        ("poliwhirl", "Poliwhirl", ["water"], (65, 65, 65, 50, 50, 90), "Hypnotic Charge", ("biped", "4870c0", "f8f8f8", ["stripes"])),
        ("poliwrath", "Poliwrath", ["water", "fighting"], (90, 95, 95, 70, 90, 70), "Dynamic Punch Charge", ("humanoid", "3858a8", "f8f8f8", ["stripes", "claws"]))]),
    dict(style="sniper", mains=[("Confusion", "psychic"), ("Psycho Cut", "psychic"), ("Psychic", "psychic")], members=[
        ("abra", "Abra", ["psychic"], (25, 20, 15, 105, 55, 90), "teleport", None),
        ("kadabra", "Kadabra", ["psychic"], (40, 35, 30, 120, 70, 105), "reflect", None),
        ("alakazam", "Alakazam", ["psychic"], (55, 50, 45, 135, 95, 120), "future_sight", None)]),
    dict(style="tank_wave", mains=[("Seismic Wave", "fighting"), ("Vital Throw", "fighting"), ("Dynamic Punch", "fighting")], members=[
        ("machop", "Machop", ["fighting"], (70, 80, 50, 35, 35, 35), "Bulk Slam", ("humanoid", "98a8c8", "e0c0a0", ["crest", "claws"])),
        ("machoke", "Machoke", ["fighting"], (80, 100, 70, 50, 60, 45), "Cross Chop Quake", ("humanoid", "8898b8", "302830", ["crest", "stripes"])),
        ("machamp", "Machamp", ["fighting"], (90, 130, 80, 65, 85, 55), "Four-Arm Fury", ("humanoid", "7890b0", "302830", ["crest", "claws", "stripes"]))]),
    dict(style="lasher", mains=[("Vine Whip", "grass"), ("Wrap", "normal"), ("Leaf Blade", "grass")], members=[
        ("bellsprout", "Bellsprout", ["grass", "poison"], (50, 75, 35, 70, 30, 40), "sleep_powder", None),
        ("weepinbell", "Weepinbell", ["grass", "poison"], (65, 90, 50, 85, 45, 55), "stun_spore", None),
        ("victreebel", "Victreebel", ["grass", "poison"], (80, 105, 65, 100, 70, 70), "leaf_storm", None)]),
    dict(style="lasher", mains=[("Poison Sting", "poison"), ("Constrict", "normal"), ("Hydro Lash", "water")], members=[
        ("tentacool", "Tentacool", ["water", "poison"], (40, 40, 35, 50, 100, 70), "Bind", ("blob", "60a8e0", "e04060", ["tentacles", "gem"])),
        ("tentacruel", "Tentacruel", ["water", "poison"], (80, 70, 65, 80, 120, 100), "Wring Out", ("blob", "4890d8", "e04060", ["tentacles", "gem", "spikes"]))]),
    dict(style="thrower", mains=[("Rock Throw", "rock"), ("Stealth Rock", "rock"), ("Rock Slide", "rock")], members=[
        ("geodude", "Geodude", ["rock", "ground"], (40, 80, 100, 30, 30, 20), "defense_curl", None),
        ("graveler", "Graveler", ["rock", "ground"], (55, 95, 115, 45, 45, 35), "earthquake", None),
        ("golem", "Golem", ["rock", "ground"], (80, 120, 130, 55, 65, 45), "explosion", None)]),
    dict(style="spinner", mains=[("Flame Wheel", "fire"), ("Stomp", "normal"), ("Blaze Kick", "fire")], members=[
        ("ponyta", "Ponyta", ["fire"], (50, 85, 55, 65, 65, 90), "Inferno Ring", ("quad", "f8f0d0", "f07830", ["mane", "tail_flame"])),
        ("rapidash", "Rapidash", ["fire"], (65, 100, 70, 80, 80, 105), "Megahorn Blaze", ("quad", "f8f0d8", "f06030", ["mane", "horn", "tail_flame"]))]),
    dict(style="tank_wave", mains=[("Water Pulse", "water"), ("Zen Headbutt", "psychic"), ("Yawn Wave", "psychic")], members=[
        ("slowpoke", "Slowpoke", ["water", "psychic"], (90, 65, 65, 40, 40, 15), "Amnesia Slam", ("quad", "f0a0b0", "f8e0d0", ["ears_round", "tail"])),
        ("slowbro", "Slowbro", ["water", "psychic"], (95, 75, 110, 100, 80, 30), "Shell Quake", ("biped", "f0a0b0", "c0c0c8", ["shell", "ears_round"]))]),
    dict(style="piercer", mains=[("Charge Beam", "electric"), ("Flash Cannon", "steel"), ("Zap Cannon", "electric")], members=[
        ("magnemite", "Magnemite", ["electric", "steel"], (25, 35, 70, 95, 55, 45), "Magnet Bomb", ("ball", "b8c0d0", "f0f0f8", ["horns", "gem"])),
        ("magneton", "Magneton", ["electric", "steel"], (50, 60, 95, 120, 70, 70), "Tri Attack Beam", ("ball", "a8b0c0", "f0f0f8", ["horns", "gem", "spikes"]))]),
    dict(style="spinner", mains=[("Fury Cutter", "bug"), ("Air Slash", "flying"), ("Leaf Blade", "grass")], members=[
        ("farfetchd", "Farfetch'd", ["normal", "flying"], (52, 90, 55, 58, 62, 60), "Leek Tornado", ("bird", "a87850", "f0e0c0", ["beak", "wings", "leaf"]))]),
    dict(style="gunner", mains=[("Peck", "flying"), ("Fury Attack", "normal"), ("Tri Attack", "normal")], members=[
        ("doduo", "Doduo", ["normal", "flying"], (35, 85, 45, 35, 35, 75), "Double Hit Barrage", ("bird", "a87048", "f0d0a0", ["beak", "crest"])),
        ("dodrio", "Dodrio", ["normal", "flying"], (60, 110, 70, 60, 60, 110), "Tri Peck Storm", ("bird", "a06840", "302020", ["beak", "crest", "mane"]))]),
    dict(style="bouncer", mains=[("Ice Shard", "ice"), ("Bubble Bounce", "water"), ("Ice Ball", "ice")], members=[
        ("seel", "Seel", ["water"], (65, 45, 55, 45, 70, 45), "Icy Wind", ("fish", "e8f0f8", "f0c0c0", ["horn", "fins"])),
        ("dewgong", "Dewgong", ["water", "ice"], (90, 70, 80, 70, 95, 70), "Sheer Cold", ("fish", "f0f4f8", "e0e8f0", ["horn", "fins", "tail"]))]),
    dict(style="zone", mains=[("Sludge", "poison"), ("Poison Gas", "poison"), ("Sludge Wave", "poison")], members=[
        ("grimer", "Grimer", ["poison"], (80, 80, 50, 40, 50, 25), "Toxic Puddle", ("blob", "9868b8", "c0a0d0", ["claws"])),
        ("muk", "Muk", ["poison"], (105, 105, 75, 65, 100, 50), "Gunk Flood", ("blob", "8858a8", "b890c8", ["claws", "fluff"]))]),
    dict(style="shotgun", mains=[("Icicle Spear", "ice"), ("Clamp Shot", "water"), ("Spike Cannon", "normal")], members=[
        ("shellder", "Shellder", ["water"], (30, 65, 100, 45, 25, 40), "Shell Smash Charge", ("shell", "9868b0", "f0f0f8", ["shell"])),
        ("cloyster", "Cloyster", ["water", "ice"], (50, 95, 180, 85, 45, 70), "Icicle Crash", ("shell", "7860a0", "e0e0f0", ["shell", "spikes"]))]),
    dict(style="homing", mains=[("Shadow Orbs", "ghost"), ("Hex", "ghost"), ("Shadow Ball", "ghost")], members=[
        ("gastly", "Gastly", ["ghost", "poison"], (30, 35, 30, 100, 35, 80), "hypnosis", None),
        ("haunter", "Haunter", ["ghost", "poison"], (45, 50, 45, 115, 55, 95), "phantom_force", None),
        ("gengar", "Gengar", ["ghost", "poison"], (60, 65, 60, 130, 75, 110), "night_terror", None)]),
    dict(style="tank_wave", mains=[("Rock Tomb Wave", "rock"), ("Iron Tail Spin", "steel"), ("Stone Edge Quake", "rock")], members=[
        ("onix", "Onix", ["rock", "ground"], (35, 45, 160, 30, 45, 70), "Earthquake Coil", ("serpent", "a0a0a8", "707078", ["horn", "spots"]))]),
    dict(style="boomerang", mains=[("Pendulum", "psychic"), ("Dream Swing", "psychic"), ("Zen Pendulum", "psychic")], members=[
        ("drowzee", "Drowzee", ["psychic"], (60, 48, 45, 43, 90, 42), "Hypno Swing", ("biped", "e8c040", "806040", ["ears_round", "stripes"])),
        ("hypno", "Hypno", ["psychic"], (85, 73, 70, 73, 115, 67), "Dream Eater", ("humanoid", "f0d040", "f8f8f8", ["ears_pointy", "fluff"]))]),
    dict(style="brawler", mains=[("Vice Grip", "normal"), ("Crabhammer", "water"), ("Guillotine", "normal")], members=[
        ("krabby", "Krabby", ["water"], (30, 105, 90, 25, 25, 50), "Claw Leap", ("shell", "e05838", "f0e0c0", ["claws", "spikes"])),
        ("kingler", "Kingler", ["water"], (55, 130, 115, 50, 50, 75), "Crabhammer Slam", ("shell", "e04830", "f0e0c0", ["claws", "spikes", "crest"]))]),
    dict(style="spinner", mains=[("Spark", "electric"), ("Discharge", "electric"), ("Gyro Ball", "steel")], members=[
        ("voltorb", "Voltorb", ["electric"], (40, 30, 50, 55, 55, 100), "Self-Destruct", ("ball", "e04040", "f8f8f8", ["stripes"])),
        ("electrode", "Electrode", ["electric"], (60, 50, 70, 80, 80, 150), "Explosion Pulse", ("ball", "f8f8f8", "e04040", ["stripes"]))]),
    dict(style="thrower", mains=[("Egg Bomb", "normal"), ("Leech Seed", "grass"), ("Egg Barrage", "grass")], members=[
        ("exeggcute", "Exeggcute", ["grass", "psychic"], (60, 40, 80, 60, 45, 40), "Barrage", ("blob", "f0d0d0", "f0e8c8", ["spots"])),
        ("exeggutor", "Exeggutor", ["grass", "psychic"], (95, 95, 85, 125, 75, 55), "Solar Bomb", ("plant", "e0c880", "48a040", ["leaf", "spots"]))]),
    dict(style="boomerang", mains=[("Bonemerang", "ground"), ("Bone Rush", "ground"), ("Shadow Bone", "ghost")], members=[
        ("cubone", "Cubone", ["ground"], (50, 50, 95, 40, 50, 35), "Bone Club Storm", ("biped", "b89868", "f0f0e8", ["mask", "tail"])),
        ("marowak", "Marowak", ["ground"], (60, 80, 110, 50, 80, 45), "Bone Tempest", ("biped", "a88858", "f0f0e8", ["mask", "tail", "claws"]))]),
    dict(style="assassin", mains=[("Jump Kick", "fighting"), ("Rolling Kick", "fighting"), ("High Jump Kick", "fighting")], members=[
        ("hitmonlee", "Hitmonlee", ["fighting"], (50, 120, 53, 35, 110, 87), "Mega Kick", ("humanoid", "b88858", "e0c8a0", ["claws"]))]),
    dict(style="brawler", mains=[("Mach Punch", "fighting"), ("Fire Punch", "fire"), ("Thunder Punch", "electric")], members=[
        ("hitmonchan", "Hitmonchan", ["fighting"], (50, 105, 79, 35, 110, 76), "Sky Uppercut", ("humanoid", "c09868", "e04840", ["claws"]))]),
    dict(style="lasher", mains=[("Lick", "ghost"), ("Wrap", "normal"), ("Power Whip", "grass")], members=[
        ("lickitung", "Lickitung", ["normal"], (90, 55, 75, 60, 75, 30), "Tongue Grab", ("biped", "f0a8b8", "f8e0c0", ["tail", "stripes"]))]),
    dict(style="zone", mains=[("Smog", "poison"), ("Poison Gas", "poison"), ("Sludge Cloud", "poison")], members=[
        ("koffing", "Koffing", ["poison"], (40, 65, 95, 60, 45, 35), "Smog Bomb", ("ball", "8868a8", "e0d0a0", ["spots", "fluff"])),
        ("weezing", "Weezing", ["poison"], (65, 90, 120, 85, 70, 60), "Toxic Smog", ("ball", "7858a0", "e0d0a0", ["spots", "fluff", "mane"]))]),
    dict(style="shotgun", mains=[("Rock Blast", "rock"), ("Mud Shot", "ground"), ("Stone Edge", "rock")], members=[
        ("rhyhorn", "Rhyhorn", ["ground", "rock"], (80, 85, 95, 30, 30, 25), "Horn Charge", ("quad", "a0a0a8", "d0d0d8", ["horn", "spikes"])),
        ("rhydon", "Rhydon", ["ground", "rock"], (105, 130, 120, 45, 45, 40), "Drill Charge", ("humanoid", "a8a8b0", "e0d8c8", ["horn", "spikes", "tail"]))]),
    dict(style="healer", mains=[("Soft Pulse", "normal"), ("Egg Toss", "normal"), ("Healing Wave", "fairy")], members=[
        ("chansey", "Chansey", ["normal"], (250, 5, 5, 35, 105, 50), "Softboiled", ("ball", "f8c0c8", "f8f8f0", ["ears_long", "gem"]))]),
    dict(style="lasher", mains=[("Vine Whip", "grass"), ("Bind", "normal"), ("Power Whip", "grass")], members=[
        ("tangela", "Tangela", ["grass"], (65, 55, 115, 100, 40, 60), "Vine Snare", ("ball", "3868b0", "e04848", ["tentacles", "fluff"]))]),
    dict(style="brawler", mains=[("Comet Punch", "normal"), ("Mega Punch", "normal"), ("Dizzy Punch", "normal")], members=[
        ("kangaskhan", "Kangaskhan", ["normal"], (105, 95, 80, 40, 80, 90), "Outrage Stomp", ("humanoid", "a07850", "e8d0a0", ["ears_round", "tail", "spots"]))]),
    dict(style="sniper", mains=[("Water Jet", "water"), ("Octazooka", "water"), ("Dragon Pulse", "dragon")], members=[
        ("horsea", "Horsea", ["water"], (30, 40, 70, 70, 25, 60), "Hydro Lance", ("fish", "70b0e0", "f0e0a0", ["fins", "tail"])),
        ("seadra", "Seadra", ["water"], (55, 65, 95, 95, 45, 85), "Twister Lance", ("fish", "5098d8", "f0e0a0", ["fins", "spikes", "tail"]))]),
    dict(style="assassin", mains=[("Horn Attack", "normal"), ("Waterfall", "water"), ("Megahorn", "bug")], members=[
        ("goldeen", "Goldeen", ["water"], (45, 67, 60, 35, 50, 63), "Horn Drill Dash", ("fish", "f8f8f8", "f08040", ["horn", "fins", "spots"])),
        ("seaking", "Seaking", ["water"], (80, 92, 65, 65, 80, 68), "Waterfall Rush", ("fish", "f0a060", "f8f8f8", ["horn", "fins", "spots"]))]),
    dict(style="boomerang", mains=[("Swift Star", "normal"), ("Water Star", "water"), ("Power Gem", "rock")], members=[
        ("staryu", "Staryu", ["water"], (30, 45, 55, 70, 55, 85), "Swift Storm", ("shell", "d8a858", "f05050", ["gem", "spikes"])),
        ("starmie", "Starmie", ["water", "psychic"], (60, 75, 85, 100, 85, 115), "Cosmic Storm", ("shell", "9068b0", "f05080", ["gem", "spikes"]))]),
    dict(style="healer", mains=[("Psybeam Wave", "psychic"), ("Light Screen", "psychic"), ("Dazzling Wave", "fairy")], members=[
        ("mr_mime", "Mr. Mime", ["psychic", "fairy"], (40, 45, 65, 100, 120, 90), "Barrier", ("humanoid", "f8e0e0", "e05068", ["ears_round", "claws"]))]),
    dict(style="assassin", mains=[("Fury Cutter", "bug"), ("Wing Slash", "flying"), ("X-Scissor", "bug")], members=[
        ("scyther", "Scyther", ["bug", "flying"], (70, 110, 80, 55, 80, 105), "Swords Dance Rush", ("humanoid", "68c058", "f0e8c0", ["claws", "wings", "crest"]))]),
    dict(style="homing", mains=[("Ice Orbs", "ice"), ("Lovely Kiss", "psychic"), ("Blizzard Orb", "ice")], members=[
        ("jynx", "Jynx", ["ice", "psychic"], (65, 50, 35, 115, 95, 95), "Heart Stamp Storm", ("humanoid", "c03868", "f0d050", ["mane", "fluff"]))]),
    dict(style="chain", mains=[("Thunder Punch", "electric"), ("Thunderbolt", "electric"), ("Thunder", "electric")], members=[
        ("electabuzz", "Electabuzz", ["electric"], (65, 83, 57, 95, 85, 105), "Electro Field", ("humanoid", "f0d040", "302820", ["stripes", "ears_pointy"]))]),
    dict(style="stream", mains=[("Ember", "fire"), ("Flamethrower", "fire"), ("Lava Plume", "fire")], members=[
        ("magmar", "Magmar", ["fire"], (65, 95, 57, 100, 85, 93), "Fire Blast Storm", ("humanoid", "f06838", "f0d050", ["tail_flame", "spots"]))]),
    dict(style="brawler", mains=[("Vice Grip", "normal"), ("Storm Throw", "fighting"), ("X-Scissor", "bug")], members=[
        ("pinsir", "Pinsir", ["bug"], (65, 125, 100, 55, 70, 85), "Guillotine Leap", ("humanoid", "a89070", "e8e0d0", ["horns", "spikes", "stripes"]))]),
    dict(style="shotgun", mains=[("Stampede", "normal"), ("Rock Smash Burst", "fighting"), ("Giga Impact Burst", "normal")], members=[
        ("tauros", "Tauros", ["normal"], (75, 100, 95, 40, 70, 110), "Stampede Charge", ("quad", "c08850", "504038", ["horns", "tail", "mane"]))]),
    dict(style="stream", mains=[("Splash", "water"), ("Dragon Breath", "dragon"), ("Hydro Pump", "water")], members=[
        ("magikarp", "Magikarp", ["water"], (20, 10, 55, 15, 20, 80), "Flail", ("fish", "f06838", "f8f0d0", ["fins", "whiskers"])),
        ("gyarados", "Gyarados", ["water", "flying"], (95, 125, 79, 60, 100, 81), "Dragon Rage", ("serpent", "3870c8", "f0e0a0", ["fins", "horn", "whiskers"]))]),
    dict(style="piercer", mains=[("Ice Beam", "ice"), ("Water Pulse Beam", "water"), ("Freeze-Dry", "ice")], members=[
        ("lapras", "Lapras", ["water", "ice"], (130, 85, 80, 85, 95, 60), "Sheer Cold Beam", ("shell", "5898d0", "f0e8d0", ["shell", "horn", "fins"]))]),
    dict(style="shotgun", mains=[("Tackle Spray", "normal"), ("Mimic Shot", "normal"), ("Copycat Burst", "normal")], members=[
        ("ditto", "Ditto", ["normal"], (48, 48, 48, 48, 48, 48), "Transform Charge", ("blob", "c098d0", "d8b8e0", []))]),
    dict(style="shotgun", mains=[("Swift", "normal"), ("Quick Burst", "normal"), ("Last Resort", "normal")], members=[
        ("eevee", "Eevee", ["normal"], (55, 55, 50, 45, 65, 55), "Double-Edge Charge", ("quad", "b88050", "f0e0c0", ["ears_long", "fluff", "tail"])),
        ("vaporeon", "Vaporeon", ["water"], (130, 65, 60, 110, 95, 65), "Hydro Charge", ("quad", "60a8d8", "f0f0f8", ["fins", "tail", "fluff"]),
         [("Water Spray", "water"), ("Aqua Burst", "water"), ("Hydro Burst", "water")]),
        ("jolteon", "Jolteon", ["electric"], (65, 65, 60, 110, 95, 130), "Volt Charge", ("quad", "f0d040", "f8f8f8", ["ears_long", "spikes", "fluff"]),
         [("Pin Missile", "electric"), ("Thunder Fang Burst", "electric"), ("Discharge Burst", "electric")]),
        ("flareon", "Flareon", ["fire"], (65, 130, 60, 95, 110, 65), "Flare Charge", ("quad", "f07040", "f8e8a0", ["ears_long", "mane", "fluff", "tail"]),
         [("Ember Burst", "fire"), ("Fire Fang Burst", "fire"), ("Flare Burst", "fire")])]),
    dict(style="bouncer", mains=[("Tri Attack", "normal"), ("Psybeam Bounce", "psychic"), ("Zap Bounce", "electric")], members=[
        ("porygon", "Porygon", ["normal"], (65, 60, 70, 85, 75, 40), "Conversion Storm", ("bird", "f080a0", "60b0e0", ["beak", "stripes"]))]),
    dict(style="gunner", mains=[("Water Gun", "water"), ("Spike Cannon", "normal"), ("Ancient Burst", "rock")], members=[
        ("omanyte", "Omanyte", ["rock", "water"], (35, 40, 100, 90, 55, 35), "Shell Barrage", ("shell", "60a8d8", "e8e0c0", ["shell", "tentacles"])),
        ("omastar", "Omastar", ["rock", "water"], (70, 60, 125, 115, 70, 55), "Spike Cannon Storm", ("shell", "5098d0", "e8d8b0", ["shell", "tentacles", "spikes"]))]),
    dict(style="assassin", mains=[("Scratch", "normal"), ("Aqua Jet", "water"), ("Razor Shell", "water")], members=[
        ("kabuto", "Kabuto", ["rock", "water"], (30, 80, 90, 55, 45, 55), "Shell Rush", ("shell", "a87040", "302820", ["shell", "gem"])),
        ("kabutops", "Kabutops", ["rock", "water"], (60, 115, 105, 65, 70, 80), "Slash Storm", ("humanoid", "a87848", "e8d8b0", ["claws", "crest", "shell"]))]),
    dict(style="sniper", mains=[("Rock Shot", "rock"), ("Aerial Snipe", "flying"), ("Stone Edge", "rock")], members=[
        ("aerodactyl", "Aerodactyl", ["rock", "flying"], (80, 105, 65, 60, 75, 130), "Ancient Beam", ("bird", "a898b8", "d8c8e0", ["wings", "beak", "spikes"]))]),
    dict(style="tank_wave", mains=[("Body Slam Wave", "normal"), ("Heavy Slam", "steel"), ("Yawn Quake", "normal")], members=[
        ("snorlax", "Snorlax", ["normal"], (160, 110, 65, 65, 110, 30), "Giga Impact", ("ball", "306878", "f0e0c0", ["ears_pointy", "claws"]))]),
    dict(style="lasher", mains=[("Wrap", "normal"), ("Dragon Tail", "dragon"), ("Outrage Whip", "dragon")], members=[
        ("dratini", "Dratini", ["dragon"], (41, 64, 45, 50, 50, 50), "agility", None),
        ("dragonair", "Dragonair", ["dragon"], (61, 84, 65, 70, 70, 70), "dragon_dance", None),
        ("dragonite", "Dragonite", ["dragon", "flying"], (91, 134, 95, 100, 100, 80), "outrage", None)]),
    dict(style="sniper", mains=[("Psycho Cut", "psychic"), ("Aura Sphere", "fighting"), ("Psystrike", "psychic")], members=[
        ("mewtwo", "Mewtwo", ["psychic"], (106, 110, 90, 154, 90, 130), "Mind Storm", ("humanoid", "c8b8d8", "9060b0", ["ears_pointy", "tail"]))]),
    dict(style="homing", mains=[("Psychic Orbs", "psychic"), ("Ancient Orbs", "rock"), ("Aura Orbs", "fighting")], members=[
        ("mew", "Mew", ["psychic"], (100, 100, 100, 100, 100, 100), "Metronome Storm", ("biped", "f8c0d8", "f8e0ec", ["ears_pointy", "tail"]))]),
]

# Legendary raid bosses / shrine guardians: not pickable, but they fight with a style too.
LEGENDARIES = [
    dict(id="zapdos", style="chain", mains=[("Thunder Shock", "electric"), ("Thunderbolt", "electric"), ("Thunder", "electric")]),
    dict(id="moltres", style="stream", mains=[("Ember", "fire"), ("Flamethrower", "fire"), ("Inferno", "fire")]),
    dict(id="articuno", style="sniper", mains=[("Ice Shard", "ice"), ("Ice Beam", "ice"), ("Freeze-Dry", "ice")]),
    dict(id="regirock", style="tank_wave", mains=[("Rock Wave", "rock"), ("Hammer Arm", "fighting"), ("Stone Edge Quake", "rock")]),
    dict(id="rayquaza", style="piercer", mains=[("Dragon Pulse", "dragon"), ("Air Slash", "flying"), ("Dragon Ascent Beam", "flying")]),
    dict(id="celebi", style="healer", mains=[("Leaf Pulse", "grass"), ("Heal Bell", "fairy"), ("Leaf Storm Wave", "grass")]),
]

# Pokemon whose final form is the only form (or that never evolve) are balanced
# like a fully evolved middle stage; these get a little more.
SPECIAL_TARGET = {"mewtwo": 132.0, "mew": 130.0}
