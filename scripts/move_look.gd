class_name MoveLook
extends RefCounted
## How a move looks, from its type and name: the shape of its shots and particles
## (flames, bones, coins, notes...), optional colours, and the style of its hit,
## swipe, charge and area effects. Vfx draws them; MoveLook only decides.
##
## Fields of the returned Dictionary (all optional except "type"):
##   shape    particle / shot shape (Vfx._shape_alpha)      colors   [bright, mid, dark]
##   beam     draws a glowing line behind the shot          orb      big glowing ball with a halo
##   impact   "burst" "star" "splash" "zap" "shatter" "smoke" "petals"
##   melee    "swipe" "claw" "punch" "whip" "bite" "spin"
##   area     "ring" "strike" "quake" "meteor" "pillar" "rings" "nova" "bloom" "frost" "cloud" "wave" "swirl" "notes"
##   dash     "afterimage" plus a trail of `shape`; "drill" adds spinning rings

## First match wins: [name keywords, fields]. Keywords match anywhere in the lower-case name.
const RULES := [
	[["tri attack"], { "shape": "spark", "colors": ["#fff2a0", "#ff7a3a", "#62c8ff"], "orb": true, "impact": "star" }],
	[["bone"], { "shape": "bone", "spin": true, "colors": ["#fbf7ea", "#e2d8bc", "#a89a74"], "impact": "star", "area": "quake" }],
	[["coin", "pay day", "jackpot"], { "shape": "coin", "spin": true, "colors": ["#fff3a0", "#f2c230", "#a87810"], "impact": "star" }],
	[["egg"], { "shape": "egg", "spin": true, "colors": ["#ffffff", "#f4ecd8", "#c8b890"], "impact": "star" }],
	[["sweet scent", "life bloom", "petal", "moonlight", "wish", "heal bell", "healing"], { "shape": "petal", "colors": ["#ffe2f1", "#ff9ccf", "#d0569a"], "impact": "petals", "area": "bloom" }],
	[["leech seed", "seed", "barrage", "bullet"], { "shape": "seed", "colors": ["#e8f59a", "#8cc63e", "#4a7a1c"], "impact": "burst" }],
	[["bubble"], { "shape": "bubble", "colors": ["#e6f7ff", "#8ed2ff", "#3a8ad6"], "impact": "splash" }],
	[["swift", "star", "cosmic", "power gem"], { "shape": "star", "spin": true, "colors": ["#fffbd0", "#ffe14a", "#e09a10"], "impact": "star" }],
	[["solar"], { "beam": true, "shape": "orb", "colors": ["#fffbe0", "#fff07a", "#9ae05a"], "area": "pillar", "impact": "star" }],
	[["hyper beam", "giga impact", "sky attack", "aerial snipe"], { "beam": true, "shape": "orb", "colors": ["#fffef4", "#ffd66e", "#ff8a3a"], "area": "nova", "impact": "star" }],
	[["explosion", "self-destruct"], { "shape": "spark", "colors": ["#ffffff", "#ffcf5a", "#ff5a1a"], "area": "nova", "impact": "star" }],
	[["fire blast"], { "shape": "blast", "colors": ["#fff0a0", "#ff7a1e", "#c21a08"], "area": "pillar", "impact": "burst" }],
	[["thunder punch", "fire punch", "ice punch", "mega punch", "comet punch", "dizzy punch", "mach punch", "dynamic punch", "punch", "fist", "hammer", "crabhammer", "rock smash", "strength", "karate chop", "cross chop", "chop", "close combat", "superpower", "sky uppercut", "uppercut", "seismic"], { "melee": "punch", "impact": "star" }],
	[["kick", "stomp"], { "melee": "punch", "impact": "star", "area": "quake" }],
	[["vine", "whip", "lash", "power whip", "tail", "wrap", "bind", "constrict", "wring", "coil", "tongue", "lick", "snare"], { "melee": "whip" }],
	[["fang", "bite", "crunch", "clamp", "vice grip", "guillotine"], { "melee": "bite", "impact": "star" }],
	[["rapid spin", "spin", "gyro", "heavy slam", "vital throw", "storm throw", "round"], { "melee": "spin" }],
	[["horn drill", "drill", "horn", "megahorn", "peck", "pin rush", "twineedle", "fury attack", "fell stinger"], { "shape": "needle", "dash": "drill", "melee": "claw", "impact": "star" }],
	[["needle", "pin missile", "spike", "sting", "icicle", "ice shard", "stone edge", "spear"], { "shape": "needle", "impact": "shatter" }],
	[["scratch", "slash", "claw", "cut", "fury cutter", "x-scissor", "razor", "leaf blade", "night slash", "air slash", "psycho cut", "aerial ace", "wing"], { "shape": "crescent", "melee": "claw" }],
	[["shadow ball", "shadow orbs", "aura sphere", "aura orbs", "psychic orbs", "ice ball", "ice orbs", "blizzard orb", "sludge bomb", "seed bomb", "magnet bomb", "focus blast", "moonblast", "zap cannon", "energy", "weather ball", "smog bomb", "solar bomb"], { "orb": true, "shape": "orb", "impact": "burst" }],
	[["beam", "cannon", "hydro pump", "lance", "ray", "psystrike", "dragon pulse", "water jet", "pulse beam"], { "beam": true, "shape": "orb", "impact": "burst" }],
	[["thunder", "zap", "shock", "spark", "volt", "discharge", "electro", "charge beam", "flash"], { "shape": "bolt", "impact": "zap", "area": "strike" }],
	[["ember", "flame", "fire", "blaze", "heat", "inferno", "overheat", "flare", "burn", "lava", "will-o-wisp", "nine tails"], { "shape": "flame", "area": "pillar" }],
	[["hurricane", "twister", "tornado", "gust", "leek tornado", "whirl"], { "shape": "crescent", "area": "swirl" }],
	[["air", "sky", "cutter", "aerial"], { "shape": "crescent" }],
	[["psy", "confusion", "psychic", "dream", "hypno", "mind", "future sight", "zen", "light screen", "barrier", "reflect", "pendulum", "metronome", "teleport", "agility"], { "shape": "ring", "area": "rings" }],
	[["shadow", "hex", "night", "phantom", "curse", "nightmare", "rage fist", "dream eater"], { "shape": "wisp", "area": "rings", "impact": "smoke" }],
	[["sludge", "gunk", "toxic", "smog", "acid", "poison gas", "stench", "poison jab", "cross poison"], { "shape": "blob", "impact": "splash", "area": "cloud" }],
	[["sing", "voice", "buzz", "supersonic", "perish", "lullaby", "hyper voice", "growl", "screech", "yawn", "soft pulse", "disarming"], { "shape": "note", "area": "notes" }],
	[["web", "string"], { "shape": "web", "impact": "burst" }],
	[["spore", "powder", "scent", "sleep", "stun spore"], { "shape": "dot", "area": "cloud", "impact": "smoke" }],
	[["sandstorm", "sand", "mud", "earth", "dig", "quake", "fissure", "bulldoze", "earthquake"], { "shape": "chunk", "area": "quake", "impact": "smoke" }],
	[["ice", "blizzard", "freeze", "sheer cold", "icy", "avalanche", "frost", "snow", "hail", "heart stamp"], { "shape": "snowflake", "area": "frost", "impact": "shatter" }],
	[["moon", "dazzling", "fairy", "charm", "draining kiss", "lovely kiss"], { "shape": "star", "colors": ["#fff4fb", "#ffb2dd", "#e05aa8"], "area": "bloom", "impact": "petals" }],
	[["draco meteor", "meteor"], { "shape": "chunk", "area": "meteor" }],
	[["dragon", "draco", "outrage"], { "shape": "flame", "area": "pillar" }],
	[["rock slide", "rock tomb", "rock", "stone", "ancient", "shell", "tomb"], { "shape": "chunk", "area": "meteor", "impact": "shatter" }],
	[["water", "hydro", "aqua", "surf", "splash", "scald", "octazooka", "razor shell", "waterfall", "muddy water", "brine", "dragon rage", "flail"], { "shape": "drop", "impact": "splash", "area": "wave" }],
	[["steel", "iron", "metal", "heavy", "magnet", "flash cannon"], { "shape": "shard", "impact": "star" }],
	[["giga drain", "leaf storm", "leaf", "solar", "grass", "absorb", "drain"], { "shape": "leaf", "area": "bloom" }],
]

## Defaults by type, when no name rule says otherwise.
const TYPE_DEFAULTS := {
	"fire": { "area": "pillar" }, "water": { "impact": "splash", "area": "wave" }, "electric": { "impact": "zap", "area": "strike" },
	"grass": { "area": "bloom" }, "ice": { "impact": "shatter", "area": "frost" }, "rock": { "impact": "shatter", "area": "meteor" },
	"ground": { "impact": "smoke", "area": "quake" }, "poison": { "impact": "splash", "area": "cloud" }, "psychic": { "area": "rings" },
	"ghost": { "impact": "smoke", "area": "rings" }, "dark": { "impact": "smoke", "area": "rings" }, "fighting": { "impact": "star", "melee": "punch", "area": "quake" },
	"fairy": { "impact": "petals", "area": "bloom" }, "dragon": { "area": "pillar" }, "flying": { "melee": "claw", "area": "swirl" },
	"bug": { "melee": "claw", "area": "notes" }, "steel": { "impact": "star", "area": "nova" }, "normal": { "impact": "star" },
}

static var _cache := {}


static func of(move: MoveData) -> Dictionary:
	if move == null:
		return { "type": "normal" }
	var key := "%s|%s" % [move.display_name, move.type]
	if _cache.has(key):
		return _cache[key]
	var look := { "type": move.type, "impact": "burst", "melee": "swipe", "area": "ring", "dash": "afterimage" }
	look.merge(TYPE_DEFAULTS.get(move.type, {}), true)
	var name := move.display_name.to_lower()
	for rule: Array in RULES:
		var hit := false
		for word: String in rule[0]:
			if name.contains(word):
				hit = true
				break
		if hit:
			look.merge(rule[1], true)
			break
	if not look.has("shape"):
		look["shape"] = str(Vfx.style(move.type).get("shape", "dot"))
	_cache[key] = look
	return look
