class_name Brawler
extends CharacterBody3D
## A Pokémon brawler. Controllers (player or bot) drive it by setting
## move_input and calling use_main() / use_gadget() / use_super().
## Call setup() before adding it to the tree.

signal died(victim: Brawler, killer: Brawler)
signal evolved(brawler: Brawler, from_name: String)

const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
## Horizontal hit radius used by melee checks and shots (a little generous, like Brawl Stars).
const BODY_RADIUS := 0.58
## Radius of the walking collision capsule (smaller than BODY_RADIUS so brawlers
## fit through one-tile gaps between walls and water).
const COLLIDER_RADIUS := 0.36
const SPRITE_HEIGHT := 0.85
## World units per sprite pixel: a 32px sprite is 1.6 units tall.
const PIXEL_SIZE := 0.05
## World units per pixel for front/side/back sheets (96px Black/White frames).
## Keep in sync with tools/import_bw_sprites.py.
const SHEET_PIXEL_SIZE := 0.0253
const DOT_TICK := 0.5
## Physics layers that stop walking and teleports: world + water.
const MOVE_BLOCK_MASK := 1 | 8
const WATER_LAYER := 8
## Walls and obstacles (what stops shots and line of sight).
const WALL_MASK := 1
## How often a stream deals damage, and how long its tank waits before refilling.
const STREAM_TICK := 0.15
const STREAM_REFILL_DELAY := 0.5

var species: SpeciesData
var level := 1
var team := 0
var is_player := false
var arena: Arena
## Main attack (right stick, ammo), picked from the level's variants.
var main_move: MoveData
## Index of the chosen variant, kept when evolving (each stage's own version).
var main_index := 0
var gadget_uses := 3

var max_health := 3000.0
var attack := 100.0
var defense := 100.0
var move_speed := 5.0
var health := 0.0
var ammo := 0.0
## 0..1; the SUPER is ready at 1. Filled by damage dealt with regular moves.
var super_charge := 0.0
## Desired movement in screen space (x = right, y = down), length 0..1.
var move_input := Vector2.ZERO
var facing := Vector3.FORWARD
var is_dead := false
var kills := 0
## Seconds until respawn while fainted (set by the match, shown on the scoreboard).
var respawn_left := 0.0
## Legendary raid boss or summoned ally (no evolving, no KO score, special HUD).
var is_legendary := false
## Boss raid: drawn this many times bigger (and a fatter hitbox).
var size_scale := 1.0
## Supers used this match (daily challenges).
var supers_used := 0
## Multiplies the damage this brawler deals (raid bosses hit softer than their size suggests).
var damage_scale := 1.0
## Multiplies max HP (a gym leader's ace); kept through evolving and Power Ups.
var hp_scale := 1.0
## False for legendaries and raid bosses: no regeneration and no healing of any kind.
var regenerates := true
## Takes no damage (summoned legendary allies).
var invulnerable := false
## Hovers above the ground and flies over walls.
var flying := false
## Water and Flying types walk over water tiles.
var can_swim := false
## Uses the shiny colours (set before it enters the tree).
var shiny := false
## Damage taken per attacking team (raid bosses use this to pick who gets them).
var damage_by_team := {}
## Seconds left before a summoned legendary leaves (shown above it).
var legendary_time_left := 0.0
## Item boosts that last until fainting.
var _boosts := { "attack": 0.0, "defense": 0.0, "speed": 0.0 }
var _extra_ammo := 0
var _hp_bonus := 0.0
## Spawn protection: no damage until it runs out or you attack.
var _protect_time := 0.0
var _shield: MeshInstance3D
## Animation state.
var _anim_phase := 0.0
var _pop := 1.0
var _dead_time := 0.0
## KOs toward the next evolution. Kept when fainting, reset when evolving.
var evolve_kills := 0
## Profile level of this evolution line (kept between matches). High enough and
## the next evolution or Power Up needs fewer KOs (see kills_needed()).
var trainer_level := 1
## Main attack ids unlocked by profile level or TM (empty = go by `level`).
var unlocked_mains: Array[String] = []
## Stat bonuses from active vitamins: { "hp", "attack", "defense", "speed" } fractions.
var vitamin_bonus: Dictionary = {}
## Super picked per stage: { stage id: move id }; stages without a pick use their own.
var super_choices: Dictionary = {}
## Equipped HM ("cut", "fly", "surf", "strength", "flash", "rock_smash"; "" = none).
var hm_id := ""
var _hm_cooldown := 0.0
## Surf: seconds left swimming (kept going while still over water).
var _surf_time := 0.0
var _flying_hm := false
## Branch to take when a line splits (Eevee); "" = random.
var preferred_evolution := ""

# Match stats for the summary screen.
var damage_dealt := 0.0
var healing_done := 0.0
var deaths := 0
var goals := 0
var candies_collected := 0
## Showdown finishing place (1 = winner, 0 = not out yet).
var placement := 0
## Rare Candies carried (Rare Candy Rush); dropped when you faint.
var candies := 0
## Showdown power cubes: each adds max HP and damage.
var power_cubes := 0
## Power Ups from KOs for Pokémon that can't evolve any further (lost on fainting).
var power_ups := 0
## Brawl Ball: the ball while you're carrying it (your attack kicks it).
var ball: Ball

var _gadget_timer := 0.0
## Short shove from knockback (or a pull), applied over a few frames.
var _knock_velocity := Vector3.ZERO
var _knock_time := 0.0
## Short lockout after any attack so attacks can't be chained instantly.
var _attack_lock := 0.0
## Seconds left planting for a telegraphed melee super (see MoveData.windup).
var _windup_time := 0.0
var _windup_dir := Vector3.FORWARD
var _windup_move: MoveData
var _regen_timer := 0.0
var _reveal_timer := 0.0
var _flash_timer := 0.0
var _bob_time := 0.0
var _last_attacker: Brawler

var _dot_time := 0.0
var _dot_dps := 0.0
var _dot_tick := 0.0
## "burn", "poison" or "leech" (leech heals whoever planted it).
var _dot_kind := ""
var _dot_source: Brawler
var _slow_time := 0.0
var _slow_amount := 0.0
var _blind_time := 0.0
## Asleep / stunned: can't move or attack.
var _stun_time := 0.0
var _invisible_time := 0.0
## stat name -> { "amount": float, "time": float }
var _buffs := {}
## Particle auras showing status conditions, created on first use.
var _auras := {}
var _stream_particles: CPUParticles3D
var _dash_trail: CPUParticles3D

var _dash_time := 0.0
var _dash_dir := Vector3.ZERO
var _dash_move: MoveData
var _dash_hit: Array[Brawler] = []
var _dash_broke: Array[Breakable] = []

var _melee_material: StandardMaterial3D
var _melee_tween: Tween

## > 0 while a controller keeps calling stream() (it must call it every frame).
var _stream_hold := 0.0
var _stream_dir := Vector3.FORWARD
var _stream_tick := 0.0
var _stream_idle := 0.0
var _stream_fx: MeshInstance3D
var _stream_material: StandardMaterial3D

@onready var sprite: Sprite3D = $Sprite
@onready var shadow: MeshInstance3D = $Shadow
@onready var team_ring: MeshInstance3D = $TeamRing
@onready var aim_pivot: Node3D = $AimPivot
@onready var aim_indicator: MeshInstance3D = $AimPivot/AimIndicator
@onready var melee_fx: MeshInstance3D = $MeleeFx


## `p_level` is the line's profile level: it decides which main attacks are
## unlocked (unless `unlocked` lists them, e.g. TM unlocks) and how fast it evolves.
func setup(species_id: String, p_level: int, p_team: int, p_is_player: bool, p_arena: Arena,
		main_id := "", unlocked: Array[String] = []) -> void:
	species = GameData.get_species(species_id)
	level = clampi(p_level, 1, int(GameData.rule("trainer/max_level", 60)))
	trainer_level = level
	unlocked_mains = unlocked
	team = p_team
	is_player = p_is_player
	arena = p_arena
	main_move = _pick_move("main", main_id)
	var options := available_moves("main")
	main_index = maxi(0, options.find(main_move))
	gadget_uses = int(GameData.rule("gadget/uses", 3))


func _ready() -> void:
	add_to_group("brawlers")
	var capsule := ($CollisionShape3D as CollisionShape3D).shape as CapsuleShape3D
	if capsule:
		capsule = capsule.duplicate() as CapsuleShape3D
		capsule.radius = COLLIDER_RADIUS
		$CollisionShape3D.shape = capsule
	_build_static_visuals()
	_apply_species()
	_apply_loadout_visuals()
	health = max_health
	ammo = max_ammo()


func _physics_process(delta: float) -> void:
	if is_dead:
		respawn_left = maxf(0.0, respawn_left - delta)
		return
	legendary_time_left = maxf(0.0, legendary_time_left - delta)
	_tick_timers(delta)
	_tick_status(delta)
	if is_stunned():
		_stream_hold = 0.0
		_dash_time = 0.0
		velocity = Vector3.ZERO
		_tick_stream(delta)
		return
	_tick_stream(delta)

	if _dash_time > 0.0:
		_process_dash(delta)
		return
	if _knock_time > 0.0:
		_knock_time -= delta
		velocity = _knock_velocity
		move_and_slide()
		return

	var dir := Vector3(move_input.x, 0.0, move_input.y)
	if dir.length() > 1.0:
		dir = dir.normalized()
	if dir.length_squared() > 0.01:
		facing = dir.normalized()
	_move_with_wall_slide(dir * get_speed(), delta)


func _process(delta: float) -> void:
	_update_sprite(delta)


## move_and_slide, plus a fallback for when it gets stuck on a corner while
## moving diagonally: try each axis of the input on its own so the brawler
## keeps sliding along the wall in the direction that's still open.
func _move_with_wall_slide(desired: Vector3, delta: float) -> void:
	velocity = desired
	var start := global_position
	move_and_slide()
	var expected := desired.length() * delta
	if expected < 0.0001 or global_position.distance_to(start) > expected * 0.3:
		return
	var axes := [Vector3(desired.x, 0, 0), Vector3(0, 0, desired.z)]
	if absf(desired.z) > absf(desired.x):
		axes.reverse()
	for axis: Vector3 in axes:
		if axis.length() < desired.length() * 0.2:
			continue
		var before := global_position
		velocity = axis
		move_and_slide()
		if global_position.distance_to(before) > axis.length() * delta * 0.3:
			return


# --- Stats -----------------------------------------------------------------

func get_attack() -> float:
	return attack * (1.0 + _buff("attack") + _boosts["attack"])


func get_defense() -> float:
	return defense * (1.0 + _buff("defense") + _boosts["defense"])


func get_speed() -> float:
	if _windup_time > 0.0:
		return 0.0  # Planted while winding up a slam.
	var slow := 1.0 - _slow_amount if _slow_time > 0.0 else 1.0
	return move_speed * (1.0 + _buff("speed") + _boosts["speed"]) * slow


## Apply an item from data/items.json. Boosts last until you faint.
func pickup(item: Dictionary) -> void:
	var spawn: Dictionary = GameData.item_spawn
	if item.has("heal"):
		heal(max_health * float(item["heal"]))
	var boost: Dictionary = item.get("boost", {})
	for stat: String in boost:
		_boosts[stat] = minf(float(spawn.get("boost_cap", 0.6)), float(_boosts.get(stat, 0.0)) + float(boost[stat]))
	if item.has("extra_ammo") and _extra_ammo < int(spawn.get("max_extra_ammo", 2)):
		_extra_ammo += int(item["extra_ammo"])
		ammo = minf(max_ammo(), ammo + (0.35 if main_move.kind == "stream" else 1.0))
	if item.has("max_hp"):
		var before := max_health
		_hp_bonus = minf(float(spawn.get("max_hp_cap", 0.6)), _hp_bonus + float(item["max_hp"]))
		_apply_species()
		health += max_health - before
	_spawn_floating_text(str(item.get("name", "Item")).to_upper(), Color(0.7, 1.0, 1.0), 56, 2.4)


## Showdown power cube: more max HP (and healed by the same amount) and more damage.
func add_power_cube() -> void:
	power_cubes += 1
	var before := max_health
	_apply_species()
	health += max_health - before
	_spawn_floating_text("POWER UP!", Color(0.5, 1.0, 0.55), 56, 2.4)
	Vfx.burst(get_parent(), global_position + Vector3(0, 0.9, 0), "fairy", 16, 0.4, 2.0)


func is_protected() -> bool:
	return _protect_time > 0.0


func protect(seconds: float) -> void:
	_protect_time = seconds


func _buff(stat: String) -> float:
	var b: Dictionary = _buffs.get(stat, {})
	return float(b.get("amount", 0.0)) if float(b.get("time", 0.0)) > 0.0 else 0.0


## `source` (if any) gets credit for the healing on the match summary.
func heal(amount: float, source: Brawler = null) -> void:
	if is_dead or amount <= 0.0 or not regenerates:
		return  # Legendaries and raid bosses never heal (drain, gadgets, team heals included).
	var healed := minf(amount, max_health - health)
	health += healed
	if is_instance_valid(source):
		source.healing_done += healed
	if healed >= 1.0:
		_spawn_floating_text("+%d" % roundi(healed), Color(0.5, 1.0, 0.5), 56)
		if healed > max_health * 0.05:
			Vfx.burst(get_parent(), global_position + Vector3(0, 0.9, 0), "grass", 12, 0.5, 1.5)


# --- Loadout & species -----------------------------------------------------

## Moves the player can choose from for a slot at the current level.
func available_moves(slot: String) -> Array[MoveData]:
	if slot == "main" and not unlocked_mains.is_empty():
		var result: Array[MoveData] = []
		for move in species.moves_for(slot, 999):
			if move.id in unlocked_mains:
				result.append(move)
		if not result.is_empty():
			return result
	return species.moves_for(slot, level)


func _pick_move(slot: String, move_id: String) -> MoveData:
	if move_id != "":
		for move in available_moves(slot):
			if move.id == move_id:
				return move
		push_warning("%s can't use '%s' at level %d; using default" % [species.display_name, move_id, level])
	var options := available_moves(slot)
	return options.back() if not options.is_empty() else species.default_move(slot, 999)


## The super in use: an equipped TM super, or this stage's own.
func current_super() -> MoveData:
	var pick := str(super_choices.get(species.id, ""))
	if pick.begins_with("tmsuper_") and pick in Profile.stage_tm_supers(species.id):
		# Shaped to this Pokémon's play style, and about as strong as its own super.
		var shape: String = GameData.STYLE_SHAPES.get(species.style, "shot")
		var move := GameData.scaled_move(pick + "_" + shape, tm_super_scale())
		if move:
			return move
	var own: MoveData = GameData.get_move(pick) if pick != "" and not pick.begins_with("tmsuper_") else null
	return own if own else species.super_move


## TM supers hit softer on early stages: base forms 75%, middle stages 88%,
## single-stage lines 90%, final evolutions full power.
func tm_super_scale() -> float:
	if species.evolves_to == "":
		return 1.0 if species.stage > 1 else 0.9
	return 0.75 if species.stage == 1 else 0.88


## Front-view icon in this brawler's colours (shiny or normal).
func portrait() -> Texture2D:
	return species.shiny_sprite if shiny and species.shiny_sprite else species.sprite


## Damage multiplier from Showdown power cubes (levels unlock moves, they don't add power).
func power_bonus() -> float:
	return (1.0 + float(GameData.rule("modes/showdown/cube_damage", 0.1)) * power_cubes) * damage_scale


## Physics layers that stop this brawler walking (swimmers cross water).
func walk_mask() -> int:
	return WALL_MASK if can_swim or _surf_time > 0.0 else MOVE_BLOCK_MASK


## Re-pick the main attack after changing species (each stage has its own version
## of the chosen variant), and refresh the aim preview.
func _refresh_main_move() -> void:
	var options := available_moves("main")
	if options.is_empty():
		return
	var next := options[mini(main_index, options.size() - 1)]
	if next == main_move:
		return
	var was_stream := main_move != null and main_move.kind == "stream"
	main_move = next
	if was_stream != (main_move.kind == "stream"):
		ammo = max_ammo()
	ammo = minf(ammo, max_ammo())
	if is_inside_tree():
		_apply_loadout_visuals()


## Re-applies stats after changing vitamin_bonus (keeps the same share of health).
func refresh_stats() -> void:
	if not is_inside_tree():
		return
	var ratio := health / max_health if max_health > 0.0 else 1.0
	_apply_species()
	health = max_health * ratio


func _apply_species() -> void:
	var crosses := "fire" if arena != null and arena.liquid == "lava" else "water"
	can_swim = flying or species.has_type(crosses) or species.has_type("flying")
	collision_mask = walk_mask()
	var growth := 1.0 + float(GameData.rule("evolution/power_up_bonus", 0.12)) * power_ups
	var vit := func(stat: String) -> float: return float(vitamin_bonus.get(stat, 0.0))
	max_health = species.hp * hp_scale * growth * (1.0 + vit.call("hp")) * (1.0 + _hp_bonus + float(GameData.rule("modes/showdown/cube_hp", 0.1)) * power_cubes)
	attack = species.attack * growth * (1.0 + vit.call("attack"))
	defense = species.defense * (1.0 + vit.call("defense"))
	move_speed = species.speed * float(GameData.rule("speed_to_meters", 0.05)) \
			* (1.0 + vit.call("speed") * float(Profile.econ("vitamins/speed_factor", 0.5)))
	# Sheets hold front / side / back views; the frame follows the way you're facing.
	var sheet := species.shiny_sheet if shiny and species.shiny_sheet else species.sheet
	sprite.texture = sheet if sheet else species.sprite
	sprite.hframes = 3 if species.sheet else 1
	sprite.frame = 0
	sprite.pixel_size = (SHEET_PIXEL_SIZE if species.sheet else PIXEL_SIZE) * species.sprite_scale * size_scale


## Evolve to the next stage (after enough KOs). Returns false at final stage.
## Branching lines (Eevee) use `preferred_evolution` if it's an option, else a random branch.
func evolve() -> bool:
	if species.evolves_to == "":
		return false
	var next_id := species.evolves_to
	if species.evolutions.size() > 1:
		next_id = preferred_evolution
		if next_id not in species.evolutions:
			next_id = species.evolutions[randi() % species.evolutions.size()]
	var next: SpeciesData = GameData.get_species(next_id)
	if next == null:
		return false
	var from_name := species.display_name
	var health_ratio := health / max_health
	species = next
	evolve_kills = 0
	_apply_species()
	_refresh_main_move()
	# Keep the same share of health, plus a modest heal (a full heal was too big a swing).
	health = minf(max_health, max_health * (health_ratio + float(GameData.rule("evolution/heal_on_evolve", 0.3))))
	Vfx.ring(get_parent(), global_position, 1.2, "fairy", 50)
	Vfx.burst(get_parent(), global_position + Vector3(0, 1, 0), "fairy", 30, 0.6, 3.0)
	_pop = 0.3
	evolved.emit(self, from_name)
	return true


func can_evolve() -> bool:
	return species.evolves_to != ""


func register_kill() -> void:
	kills += 1
	if is_legendary:
		return
	if species.evolves_to == "" and power_ups >= max_power_ups():
		return
	evolve_kills += 1
	if evolve_kills >= kills_needed():
		if species.evolves_to != "":
			evolve()
		else:
			power_up()


## KOs for the next evolution or Power Up: fast_kills (2) once the profile level
## reaches the evolution's main-series level (or the Power Up's level), else 3.
func kills_needed() -> int:
	var slow := int(GameData.rule("evolution/kills_to_evolve", 3))
	return int(GameData.rule("trainer/fast_kills", 2)) if trainer_level >= fast_level() else slow


## Profile level that makes the next growth fast (0 = none left).
func fast_level() -> int:
	if species.evolves_to != "":
		return species.evolve_level if species.evolve_level > 0 else 25
	var levels: Array = GameData.rule("trainer/power_up_levels", [20, 40])
	var step := clampi(species.stage - 1 + power_ups, 0, levels.size() - 1)
	return int(levels[step])


## Every Pokémon grows twice per life: by evolving, or (once it can't evolve any
## further) by Power Ups. A single-stage Pokémon gets 2, a two-stage final form 1.
func max_power_ups() -> int:
	return maxi(0, 3 - species.stage)


## Stronger without evolving: more max HP and attack until you faint.
func power_up() -> void:
	evolve_kills = 0
	power_ups += 1
	var before := max_health
	var ratio := health / max_health
	_apply_species()
	health = minf(max_health, max_health * (ratio + float(GameData.rule("evolution/heal_on_evolve", 0.3))))
	_spawn_floating_text("POWER UP!", Color(1, 0.8, 0.3), 72, 2.6)
	Vfx.ring(get_parent(), global_position, 1.2, "fighting", 50)
	_pop = 0.4
	evolved.emit(self, species.display_name)


func respawn(spawn_position: Vector3) -> void:
	if GameData.rule("evolution/devolve_on_death", true) and species.evolves_from != "":
		var previous: SpeciesData = GameData.get_species(species.evolves_from)
		if previous:
			species = previous
	_boosts = { "attack": 0.0, "defense": 0.0, "speed": 0.0 }
	_extra_ammo = 0
	_hp_bonus = 0.0
	power_cubes = 0
	power_ups = 0
	_apply_species()
	_refresh_main_move()
	protect(float(GameData.rule("spawn_protection", 2.0)))
	_dead_time = 0.0
	_pop = 0.6
	is_dead = false
	health = max_health
	ammo = max_ammo()
	_stream_hold = 0.0
	position = spawn_position
	velocity = Vector3.ZERO
	collision_layer = 2
	_attack_lock = 0.0
	_dash_time = 0.0
	_knock_time = 0.0
	_clear_status()
	_buffs.clear()
	_last_attacker = null
	shadow.scale = Vector3.ONE


# --- Attacks ---------------------------------------------------------------

## Ammo bars for the main attack; for streams, the tank (0..1).
func max_ammo() -> float:
	if main_move.kind == "stream":
		return 1.0 + 0.35 * _extra_ammo  # PP Up makes the tank bigger.
	return float(main_move.ammo + _extra_ammo)


func is_stunned() -> bool:
	return _stun_time > 0.0


func _busy() -> bool:
	return is_dead or _dash_time > 0.0 or is_stunned()


func can_shoot() -> bool:
	if _busy():
		return false
	if main_move.kind == "stream":
		return is_streaming() or (ammo > 0.1 and _attack_lock <= 0.0)
	return ammo >= 1.0 and _attack_lock <= 0.0


func is_streaming() -> bool:
	return _stream_hold > 0.0


## Keep a stream attack firing toward `direction`. Call every physics frame
## while the trigger is held; it stops by itself when calls stop.
func stream(direction: Vector3) -> bool:
	if is_dead:
		return false
	direction.y = 0.0
	if ball != null or main_move.kind != "stream" or direction.length_squared() < 0.0001 or not can_shoot():
		return false
	_stream_dir = direction.normalized()
	facing = _stream_dir
	if not is_streaming():
		_stream_tick = 0.0
	_stream_hold = 0.12
	_regen_timer = 0.0
	_invisible_time = 0.0
	_protect_time = 0.0
	_reveal_timer = float(GameData.rule("tall_grass/reveal_time_after_attack", 1.0))
	return true


## Fire the main attack. `distance` is where lobbed shots land (< 0 = full range).
func use_main(direction: Vector3, distance := -1.0) -> bool:
	if ball != null:
		return _kick(direction, distance)
	if main_move.kind == "stream":
		return stream(direction)
	direction.y = 0.0
	if direction.length_squared() < 0.0001 or not can_shoot():
		return false
	direction = direction.normalized()
	ammo -= 1.0
	_on_attack(direction, main_move)
	_perform(main_move, direction, distance)
	return true


## Brawl Ball: while carrying, the attack kicks the ball (`distance` < 0 = full power).
func _kick(direction: Vector3, distance: float) -> bool:
	direction.y = 0.0
	if _busy() or _attack_lock > 0.0:
		return false
	if direction.length_squared() < 0.0001:
		direction = facing
	direction = direction.normalized()
	facing = direction
	_attack_lock = 0.35
	_pop = 1.15
	_reveal_timer = float(GameData.rule("tall_grass/reveal_time_after_attack", 1.0))
	_invisible_time = 0.0
	_protect_time = 0.0
	ball.kick(self, direction, distance)
	return true


## Does the attack itself for any kind of move.
func _perform(move: MoveData, direction: Vector3, distance: float) -> void:
	match move.kind:
		"projectile":
			_fire_volley(move, direction, distance)
		"melee":
			_melee_swing(move, direction)
		"dash":
			_start_dash(move, direction)
		"area":
			var reach := move.reach if distance < 0.0 else minf(distance, move.reach)
			_area_strike(move, global_position + direction * reach)


func gadget_ready() -> bool:
	return not _busy() and species.gadget_move != null and gadget_uses > 0 and _gadget_timer <= 0.0


## 0 when the gadget is ready, 1 right after using it (stays 1 when out of uses).
func gadget_cooldown_ratio() -> float:
	if gadget_uses <= 0:
		return 1.0
	return _gadget_timer / maxf(0.01, float(GameData.rule("gadget/cooldown", 4.0)))


func use_gadget(direction: Vector3) -> bool:
	if not gadget_ready():
		return false
	var move := species.gadget_move
	direction = _flat_direction(direction)
	gadget_uses -= 1
	_gadget_timer = float(GameData.rule("gadget/cooldown", 4.0))
	_spawn_floating_text(move.display_name.to_upper(), Color(0.6, 1.0, 0.8), 60, 2.4)
	if move.kind != "self":
		_on_attack(direction, move)
		_perform(move, direction, 0.0)
	_apply_support(move, direction)
	return true


func super_ready() -> bool:
	return not is_dead and super_charge >= 1.0 and _dash_time <= 0.0 and _attack_lock <= 0.0 and not is_stunned()


func add_super_charge(damage_dealt: float) -> void:
	var sup := current_super()
	if sup == null or damage_dealt <= 0.0:
		return
	if sup.charge_hits > 0:
		super_charge = minf(1.0, super_charge + 1.0 / sup.charge_hits)  # Counted in hits (Assassins).
	else:
		super_charge = minf(1.0, super_charge + damage_dealt / sup.charge_damage())


## `distance` is where area and lobbed supers land (clamped to their range); < 0 = max range.
func use_super(direction: Vector3, distance := -1.0) -> bool:
	if not super_ready():
		return false
	var move := current_super()
	direction = _flat_direction(direction)
	super_charge = 0.0
	supers_used += 1
	_on_attack(direction, move)
	_spawn_floating_text(move.display_name.to_upper() + "!", Color(1, 0.9, 0.3), 72, 2.6)
	Vfx.ring(get_parent(), global_position, 1.0, move.type, 30)
	if move.self_damage > 0.0:
		health = maxf(1.0, health - max_health * move.self_damage)
	_perform(move, direction, distance)
	_apply_support(move, direction)
	if move.invisible > 0.0:
		_invisible_time = move.invisible
	return true


## True if the super hits enemies (vs. pure heals / buffs), for the bot AI.
func super_is_offensive() -> bool:
	var move := current_super()
	return move != null and (move.kind != "self" or not move.blind.is_empty())


func _flat_direction(direction: Vector3) -> Vector3:
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		direction = facing
	return direction.normalized()


## True while this Pokémon is winding up a slam that would hit `pos` (bots dodge it).
func windup_threatens(pos: Vector3) -> bool:
	if _windup_time <= 0.0 or _windup_move == null:
		return false
	var to := pos - global_position
	to.y = 0.0
	if to.length() > _windup_move.reach + BODY_RADIUS + 0.6:
		return false
	return to.length() < 0.5 or rad_to_deg(absf(_windup_dir.signed_angle_to(to.normalized(), Vector3.UP))) <= _windup_move.arc * 0.5 + 10.0


func _melee_swing(move: MoveData, direction: Vector3) -> void:
	if move.windup > 0.0:
		# Telegraph: plant and show a red cone where the slam will land, so it can be dodged.
		_windup_time = move.windup
		_windup_dir = direction
		_windup_move = move
		_attack_lock = maxf(_attack_lock, move.windup + 0.1)
		var warn := MeshInstance3D.new()
		warn.mesh = _build_fan_mesh(move.reach + BODY_RADIUS, deg_to_rad(move.arc))
		warn.rotation.y = atan2(-direction.x, -direction.z)
		warn.position.y = 0.06
		var mat := _flat_material(Color(1, 0.15, 0.1, 0.15))
		warn.material_override = mat
		add_child(warn)
		var tween := warn.create_tween()
		tween.tween_property(mat, "albedo_color:a", 0.55, move.windup)
		await get_tree().create_timer(move.windup, false, true).timeout
		warn.queue_free()
		if is_dead or is_stunned():
			_windup_time = 0.0
			return  # Interrupted: the slam fizzles.
	_show_melee_fx(direction, move)
	for other in _enemies_in_cone(direction, move.reach, move.arc):
		other.take_hit(self, move)
		other.knock_from(global_position, move.knockback)
	Breakable.hit_cone(get_tree(), global_position, direction, move.reach, move.arc, self, move)


# --- HMs ---------------------------------------------------------------------

func hm_ready() -> bool:
	return hm_id != "" and _hm_cooldown <= 0.0 and not is_dead and not is_stunned() and not _flying_hm


func hm_cooldown_ratio() -> float:
	return _hm_cooldown / maxf(0.1, float(GameData.rule("hm/cooldown", 10.0)))


func hm_move() -> MoveData:
	return GameData.get_move("hm_" + hm_id) if hm_id != "" else null


## Uses the equipped HM toward `direction`. Returns false if it isn't ready.
func use_hm(direction: Vector3) -> bool:
	var move := hm_move()
	if not hm_ready() or move == null:
		return false
	var dir := _flat_direction(direction)
	_reveal_timer = float(GameData.rule("tall_grass/reveal_time_after_attack", 1.0))
	match hm_id:
		"cut":
			for other in _enemies_in_cone(dir, move.reach, move.arc):
				other.take_hit(self, move)
			if arena:
				arena.clear_grass(global_position + dir * 1.2, 1.4)
			_show_melee_fx(dir, move)
		"surf":
			for other in _enemies_in_cone(dir, move.reach, move.arc):
				other.take_hit(self, move)
				other.knock_from(global_position, move.knockback)
			_surf_time = float(GameData.rule("hm/surf_time", 4.0))
			collision_mask = walk_mask()
			Vfx.burst(get_parent(), global_position + dir * 1.5 + Vector3(0, 0.4, 0), "water", 40, 1.0, 4.0)
		"strength":
			for other in _enemies_in_cone(dir, move.reach, move.arc):
				other.take_hit(self, move)
				other.knock_from(global_position, move.knockback)
			for b in Breakable.near(get_tree(), global_position + dir * 1.0, 0.8):
				if arena:
					arena.push_breakable(b, dir)
			_show_melee_fx(dir, move)
		"rock_smash":
			for other in _enemies_in_cone(dir, move.reach, move.arc):
				other.take_hit(self, move)
			for b in Breakable.near(get_tree(), global_position + dir * 1.0, 0.7):
				b.smash()
			_show_melee_fx(dir, move)
		"flash":
			for other in enemies():
				if other.global_position.distance_to(global_position) <= move.reach:
					other.apply_blind(float(GameData.rule("hm/flash_blind", 2.0)))
					other._reveal_timer = float(GameData.rule("hm/flash_reveal", 4.0))
			_flash_fx(move.reach)
		"fly":
			_fly(dir, move)
	_hm_cooldown = float(GameData.rule("hm/cooldown", 10.0))
	return true


## Fly: a leap over walls and water, landing on open ground with a small thump.
func _fly(dir: Vector3, move: MoveData) -> void:
	var target := global_position + dir * float(GameData.rule("hm/fly_distance", 6.0))
	if arena:
		target = arena.nearest_open(target)
	target.y = global_position.y
	_flying_hm = true
	var was_invulnerable := invulnerable
	invulnerable = true
	collision_mask = 0
	var tween := create_tween()
	tween.tween_property(self, "global_position", target, 0.45).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(sprite, "position:y", sprite.position.y + 1.6, 0.22).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(sprite, "position:y", sprite.position.y, 0.2).set_ease(Tween.EASE_IN)
	tween.finished.connect(func() -> void:
		_flying_hm = false
		invulnerable = was_invulnerable
		collision_mask = walk_mask()
		for other in enemies():
			if other.global_position.distance_to(global_position) <= move.reach:
				other.take_hit(self, move)
		Vfx.ring(get_parent(), global_position, move.reach, "flying", 40))


## Push away from `origin` by `distance` metres (negative pulls toward it, stopping short).
func knock_from(origin: Vector3, distance: float) -> void:
	if is_dead or absf(distance) < 0.01 or is_legendary or invulnerable:
		return
	var away := global_position - origin
	away.y = 0.0
	if away.length() < 0.01:
		away = -facing
	var gap := away.length()
	if distance < 0.0:
		distance = -minf(-distance, maxf(0.0, gap - BODY_RADIUS * 2.2))
	_knock_time = 0.18
	_knock_velocity = away.normalized() * distance / _knock_time
	_dash_time = 0.0
	_stream_hold = 0.0


## Enemies within `reach` and inside a cone of `arc` degrees, not behind walls.
func _enemies_in_cone(direction: Vector3, reach: float, arc: float) -> Array[Brawler]:
	var result: Array[Brawler] = []
	var half_arc := deg_to_rad(arc) * 0.5
	for other in enemies():
		var to := other.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if dist > reach + BODY_RADIUS:
			continue
		# Widen the cone by the target's body so grazing hits count.
		var allowance := asin(minf(1.0, BODY_RADIUS / maxf(dist, BODY_RADIUS)))
		if dist > 0.01 and direction.angle_to(to / dist) > half_arc + allowance:
			continue
		if not has_line_of_sight_to(other):
			continue
		result.append(other)
	return result


func _start_dash(move: MoveData, direction: Vector3) -> void:
	_dash_move = move
	_dash_dir = direction
	_dash_time = move.dash_distance / move.dash_speed
	_dash_hit.clear()
	_dash_broke.clear()
	if _dash_trail:
		_dash_trail.queue_free()
	_dash_trail = Vfx.trail(move.type, 0.5)
	_dash_trail.position = Vector3(0, 0.8, 0)
	add_child(_dash_trail)


func _fire_volley(move: MoveData, direction: Vector3, distance := -1.0) -> void:
	for burst in move.burst_count:
		if burst > 0:
			await get_tree().create_timer(move.burst_interval, false, true).timeout
			if is_dead:
				return
		for i in move.count:
			var angle := 0.0
			if move.count > 1:
				angle = lerpf(-move.spread * 0.5, move.spread * 0.5, float(i) / (move.count - 1))
			elif move.spread > 0.0:
				angle = randf_range(-move.spread * 0.5, move.spread * 0.5)
			_spawn_projectile(move, direction.rotated(Vector3.UP, deg_to_rad(angle)), distance)


func _spawn_projectile(move: MoveData, direction: Vector3, distance := -1.0) -> void:
	var chest := global_position + Vector3(0, 0.8, 0)
	var spawn := chest + direction * 0.6
	# Standing against a wall: the shot hits the wall instead of starting past it (lobs go over).
	var query := PhysicsRayQueryParameters3D.create(chest, spawn + direction * move.radius, WALL_MASK)
	if not move.lob and not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		return
	var projectile: Projectile = PROJECTILE_SCENE.instantiate()
	projectile.setup(self, move, direction, distance)
	# Placed before entering the tree, so its trail doesn't start at the map's centre.
	projectile.position = (get_parent() as Node3D).to_local(spawn)
	get_parent().add_child(projectile)
	projectile.global_position = spawn


## Hits every enemy inside a circle, optionally after a delay (Future Sight).
func _area_strike(move: MoveData, center: Vector3) -> void:
	center.y = 0.0
	var parent := get_parent()
	var fx := _area_fx(parent, center, move)
	if move.area_delay > 0.0:
		await get_tree().create_timer(move.area_delay, false, true).timeout
	if not is_inside_tree() or not is_instance_valid(fx):
		return
	if is_dead:
		fx.queue_free()  # Fainted before it landed: it fizzles.
		return
	for node in get_tree().get_nodes_in_group("brawlers"):
		var other := node as Brawler
		if other == null or other.team == team or other.is_dead:
			continue
		var offset := other.global_position - center
		offset.y = 0.0
		if offset.length() <= move.area_radius + BODY_RADIUS and Brawler.clear_between(self, center, other.global_position):
			other.take_hit(self, move)
			other.knock_from(center, move.knockback)
	Breakable.hit_area(get_tree(), center, move.area_radius, self, move)
	Vfx.ring(parent, center, move.area_radius, move.type, 50)
	Vfx.burst(parent, center + Vector3(0, 0.3, 0), move.type, 30, move.area_radius * 0.6, 3.5)
	var mat := fx.material_override as StandardMaterial3D
	mat.albedo_color.a = 0.75
	var tween := fx.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.45)
	tween.tween_callback(fx.queue_free)


## Heals, buffs, teleports, shields, blinding and cleansing attached to a super or gadget.
func _apply_support(move: MoveData, direction: Vector3) -> void:
	if move.cleanse:
		_clear_status()
	if move.protect > 0.0:
		protect(move.protect)
	if move.blink > 0.0:
		_blink(direction, move.blink)
	if move.heal > 0.0:
		heal(max_health * move.heal)
	var allies: Array[Brawler] = []
	if move.support_radius > 0.0:
		allies = allies_within(move.support_radius)
	if move.team_heal > 0.0:
		for ally: Brawler in allies:
			ally.heal(ally.max_health * move.team_heal, self)
	if not move.buff.is_empty():
		apply_buff(move.buff)
		if move.buff.get("allies", false):
			for ally: Brawler in allies:
				ally.apply_buff(move.buff)
	if not move.blind.is_empty():
		var radius := float(move.blind.get("radius", 8.0))
		for other in enemies():
			if other.global_position.distance_to(global_position) <= radius and has_line_of_sight_to(other):
				other.apply_blind(float(move.blind.get("duration", 3.0)))
		_flash_fx(radius)


func _blink(direction: Vector3, distance: float) -> void:
	var from := global_position + Vector3.UP * 0.8
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * distance, walk_mask())
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var travel := distance
	if not hit.is_empty():
		travel = maxf(0.0, from.distance_to(hit["position"]) - BODY_RADIUS - 0.1)
	global_position += direction * travel


func apply_buff(buff: Dictionary) -> void:
	var duration := float(buff.get("duration", 4.0))
	for stat in ["attack", "defense", "speed"]:
		if buff.has(stat):
			_buffs[stat] = { "amount": float(buff[stat]), "time": duration }


func apply_blind(duration: float) -> void:
	if not is_dead:
		_blind_time = maxf(_blind_time, duration)


func is_blind() -> bool:
	return _blind_time > 0.0


func _process_dash(delta: float) -> void:
	_dash_time -= delta
	# Crates in the way take a hit; dashing supers smash through breakable walls.
	for b in Breakable.near(get_tree(), global_position + _dash_dir * 0.7, 0.2):
		if b not in _dash_broke:
			_dash_broke.append(b)
			if not b.take_attack(self, _dash_move):
				_dash_time = 0.0
	velocity = _dash_dir * _dash_move.dash_speed
	move_and_slide()
	for other in enemies():
		if other in _dash_hit:
			continue
		var to := other.global_position - global_position
		to.y = 0.0
		if to.length() <= BODY_RADIUS * 2.0 + 0.3:
			_dash_hit.append(other)
			if _dash_move.explode_radius <= 0.0:
				other.take_hit(self, _dash_move)
				other.knock_from(global_position, _dash_move.knockback)
			if not _dash_move.dash_pierce:
				_dash_time = 0.0  # Stop on the first hit.
	if is_on_wall():
		_dash_time = 0.0
	if _dash_time <= 0.0:
		if _dash_trail:
			_dash_trail.emitting = false
		if _dash_move.explode_radius > 0.0:
			_slam(_dash_move)


## Landing of a slam dash: hits everyone around where it ends.
func _slam(move: MoveData) -> void:
	var parent := get_parent()
	for other in enemies():
		var offset := other.global_position - global_position
		offset.y = 0.0
		if offset.length() <= move.explode_radius + BODY_RADIUS and has_line_of_sight_to(other):
			other.take_hit(self, move)
			other.knock_from(global_position, move.knockback)
	Breakable.hit_area(get_tree(), global_position, move.explode_radius, self, move)
	Vfx.ring(parent, global_position, move.explode_radius, move.type, 50)
	Vfx.burst(parent, global_position + Vector3(0, 0.3, 0), move.type, 30, move.explode_radius * 0.5, 4.0)
	_pop = 0.75


func _on_attack(direction: Vector3, move: MoveData) -> void:
	_attack_lock = move.attack_delay()
	_invisible_time = 0.0  # Attacking reveals you.
	_protect_time = 0.0  # ...and ends spawn protection.
	_pop = 1.15
	_regen_timer = 0.0
	_reveal_timer = float(GameData.rule("tall_grass/reveal_time_after_attack", 1.0))
	facing = direction


## Alive brawlers on other teams.
func enemies() -> Array[Brawler]:
	var result: Array[Brawler] = []
	for node in get_tree().get_nodes_in_group("brawlers"):
		var other := node as Brawler
		if other and other != self and other.team != team and not other.is_dead:
			result.append(other)
	return result


## Alive teammates (not including self) within `radius`.
func allies_within(radius: float) -> Array[Brawler]:
	var result: Array[Brawler] = []
	for node in get_tree().get_nodes_in_group("brawlers"):
		var other := node as Brawler
		if other and other != self and other.team == team and not other.is_dead \
				and other.global_position.distance_to(global_position) <= radius:
			result.append(other)
	return result


## Whether this brawler can currently see `other` (blindness, tall grass).
func can_see(other: Brawler) -> bool:
	return not is_blind() and not other.is_dead and not other.is_hidden_from(team)


## Nearest enemy this brawler can see.
func find_nearest_enemy(max_range: float = INF) -> Brawler:
	var best: Brawler = null
	var best_dist := max_range
	for other in enemies():
		if not can_see(other):
			continue
		var dist := global_position.distance_to(other.global_position)
		if dist <= best_dist:
			best = other
			best_dist = dist
	return best


func has_line_of_sight_to(other: Brawler) -> bool:
	return Brawler.clear_between(self, global_position, other.global_position)


## No wall between two ground points (checked at chest height).
static func clear_between(node: Node3D, a: Vector3, b: Vector3) -> bool:
	var from := Vector3(a.x, 0.8, a.z)
	var to := Vector3(b.x, 0.8, b.z)
	if from.distance_to(to) < 0.01:
		return true
	var query := PhysicsRayQueryParameters3D.create(from, to, WALL_MASK)
	return node.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## How far you can see/shoot from here toward `direction` before a wall.
func clear_distance(direction: Vector3, max_distance: float) -> float:
	var from := global_position + Vector3.UP * 0.8
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * max_distance, WALL_MASK)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return max_distance if hit.is_empty() else from.distance_to(hit["position"])


# --- Damage & status -------------------------------------------------------

## Hit by a move: applies the damage formula, type matchups and side effects.
## Regular moves charge the attacker's super; draining moves heal the attacker.
func take_hit(attacker: Brawler, move: MoveData, multiplier := 1.0) -> void:
	if is_dead or invulnerable or is_protected():
		return
	if move.power <= 0.0:
		_apply_effect(move.effect, attacker)  # Pure status moves (Smokescreen).
		return
	if move.bonus_vs_status > 1.0 and has_status():
		multiplier *= move.bonus_vs_status
	if is_instance_valid(attacker):
		multiplier *= attacker.power_bonus()
	var result: Dictionary = GameData.calc_damage(move, attacker, self, multiplier)
	if multiplier >= 0.5:  # Skip the tiny per-tick stream hits.
		Vfx.burst(get_parent(), global_position + Vector3(0, 0.9, 0), move.type, 10, 0.35, 2.5)
	var amount: float = minf(result["amount"], health)
	take_damage(result["amount"], attacker, result["effectiveness"], result["crit"])
	if is_instance_valid(attacker):
		if move.slot == "main":
			attacker.add_super_charge(amount)
		if move.drain > 0.0:
			attacker.heal(amount * move.drain)
	if not is_dead:
		_apply_effect(move.effect, attacker)


func take_damage(amount: float, source: Brawler = null, effectiveness := 1.0, crit := false) -> void:
	if is_dead or invulnerable or is_protected():
		return
	if source:
		_last_attacker = source
		damage_by_team[source.team] = float(damage_by_team.get(source.team, 0.0)) + minf(amount, health)
		if source != self:
			source.damage_dealt += minf(amount, health)
	_pop = 0.86
	health = maxf(0.0, health - amount)
	_regen_timer = 0.0
	_reveal_timer = float(GameData.rule("tall_grass/reveal_time_after_attack", 1.0))
	_flash_timer = 0.12
	_spawn_damage_number(amount, effectiveness, crit)
	if is_player:
		var camera := get_viewport().get_camera_3d()
		if camera and camera.has_method("shake"):
			camera.shake(clampf(amount / 2500.0, 0.06, 0.35))
	if health <= 0.0:
		_die()


func has_status() -> bool:
	return _dot_time > 0.0 or _slow_time > 0.0 or _stun_time > 0.0 or _blind_time > 0.0


func status_text() -> String:
	var parts: Array[String] = []
	if _stun_time > 0.0:
		parts.append("SLP")
	if _invisible_time > 0.0:
		parts.append("HIDDEN")
	if _blind_time > 0.0:
		parts.append("BLIND")
	if _dot_time > 0.0:
		parts.append({ "burn": "BRN", "poison": "PSN", "leech": "SEED" }.get(_dot_kind, "DOT"))
	if _slow_time > 0.0:
		parts.append("PAR")
	for stat in ["attack", "defense", "speed"]:
		if _buff(stat) > 0.0 or _boosts[stat] > 0.0:
			parts.append("+" + stat.substr(0, 3).to_upper())
	if _extra_ammo > 0:
		parts.append("+PP")
	return " ".join(parts)


func _apply_effect(effect: Dictionary, source: Brawler) -> void:
	if effect.is_empty() or randf() >= float(effect.get("chance", 1.0)):
		return
	var kind := str(effect.get("type", ""))
	match kind:
		"burn", "poison", "leech":
			_dot_kind = kind
			_dot_time = float(effect.get("duration", 3.0))
			_dot_dps = float(effect.get("dps", 100.0))
			_dot_source = source
		"slow":
			_slow_time = float(effect.get("duration", 1.0))
			_slow_amount = clampf(float(effect.get("amount", 0.4)), 0.0, 0.9)
		"stun":
			_stun_time = maxf(_stun_time, float(effect.get("duration", 1.5)))
		"blind":
			apply_blind(float(effect.get("duration", 2.0)))


func _clear_status() -> void:
	_dot_time = 0.0
	_slow_time = 0.0
	_blind_time = 0.0
	_stun_time = 0.0


func _tick_timers(delta: float) -> void:
	_gadget_timer = maxf(0.0, _gadget_timer - delta)
	_attack_lock = maxf(0.0, _attack_lock - delta)
	_windup_time = maxf(0.0, _windup_time - delta)
	_reveal_timer = maxf(0.0, _reveal_timer - delta)
	_blind_time = maxf(0.0, _blind_time - delta)
	_stun_time = maxf(0.0, _stun_time - delta)
	_invisible_time = maxf(0.0, _invisible_time - delta)
	_protect_time = maxf(0.0, _protect_time - delta)
	_hm_cooldown = maxf(0.0, _hm_cooldown - delta)
	if _surf_time > 0.0:
		_surf_time -= delta
		# Don't let it run out in the middle of the water.
		if _surf_time <= 0.0 and arena and not arena.is_walkable(global_position):
			_surf_time = 0.2
		if _surf_time <= 0.0:
			collision_mask = walk_mask()
	for stat: String in _buffs:
		_buffs[stat]["time"] = float(_buffs[stat]["time"]) - delta
	if main_move.kind == "stream":
		if not is_streaming() and _stream_idle >= STREAM_REFILL_DELAY:
			ammo = minf(max_ammo(), ammo + delta / main_move.reload)
	elif ammo < max_ammo():
		ammo = minf(max_ammo(), ammo + delta / main_move.reload)
	_regen_timer += delta
	if regenerates and _regen_timer >= float(GameData.rule("regen_delay", 3.0)) and health < max_health:
		health = minf(max_health, health + max_health * float(GameData.rule("regen_rate", 0.13)) * delta)


func _tick_status(delta: float) -> void:
	_slow_time = maxf(0.0, _slow_time - delta)
	if _dot_time <= 0.0:
		_dot_tick = 0.0
		return
	_dot_time -= delta
	_dot_tick += delta
	if _dot_tick >= DOT_TICK:
		_dot_tick -= DOT_TICK
		var amount := minf(_dot_dps * DOT_TICK, health)
		var source := _dot_source if is_instance_valid(_dot_source) else null
		take_damage(_dot_dps * DOT_TICK, source)
		if _dot_kind == "leech" and source:
			source.heal(amount)


func _tick_stream(delta: float) -> void:
	if not is_streaming():
		_stream_idle += delta
		if _stream_fx:
			_stream_fx.visible = false
			_stream_particles.emitting = false
		return
	var move := main_move
	_stream_hold -= delta
	_stream_idle = 0.0
	_attack_lock = maxf(_attack_lock, 0.2)
	ammo = maxf(0.0, ammo - delta / move.tank)
	_stream_tick -= delta
	if _stream_tick <= 0.0:
		_stream_tick += STREAM_TICK
		for other in _enemies_in_cone(_stream_dir, move.reach, move.arc):
			other.take_hit(self, move, STREAM_TICK)
		Breakable.hit_cone(get_tree(), global_position, _stream_dir, move.reach, move.arc, self, move, STREAM_TICK)
	if ammo <= 0.0:
		_stream_hold = 0.0
	# Visual: a flickering cone, cut short by walls.
	_stream_fx.visible = true
	_stream_fx.rotation.y = atan2(-_stream_dir.x, -_stream_dir.z)
	var length := clear_distance(_stream_dir, move.reach) / move.reach
	_stream_fx.scale = Vector3(length, 1, length)
	_stream_material.albedo_color.a = randf_range(0.08, 0.16)
	# Spray particles along the cone; they stop at walls because they only live as long as it takes to reach one.
	_stream_particles.emitting = true
	_stream_particles.global_basis = Basis.looking_at(_stream_dir, Vector3.UP)
	_stream_particles.spread = move.arc * 0.5
	var speed := move.reach / _stream_particles.lifetime
	_stream_particles.initial_velocity_min = speed * length * 0.8
	_stream_particles.initial_velocity_max = speed * length


func _die() -> void:
	is_dead = true
	deaths += 1
	if ball:
		ball.drop()
	_stream_hold = 0.0
	_invisible_time = 0.0
	if _stream_fx:
		_stream_fx.visible = false
		_stream_particles.emitting = false
	hide_super_aim()
	Vfx.burst(get_parent(), global_position + Vector3(0, 0.6, 0), "normal", 30, 0.5, 3.5)
	velocity = Vector3.ZERO
	_dash_time = 0.0
	_knock_time = 0.0
	set_deferred("collision_layer", 0)
	hide_aim()
	_dead_time = 0.0
	var tween := create_tween()
	tween.tween_property(shadow, "scale", Vector3.ZERO, 0.35)
	died.emit(self, _last_attacker)


# --- Tall grass & visibility -----------------------------------------------

func is_in_grass() -> bool:
	return arena != null and arena.is_tall_grass(global_position)


## True when `viewer_team` can't see this brawler: it's in tall grass, hasn't
## attacked or been hit recently, and no viewer-team brawler is close by.
func is_hidden_from(viewer_team: int) -> bool:
	if viewer_team == team or is_dead:
		return false
	var invisible := _invisible_time > 0.0
	if not invisible and (_reveal_timer > 0.0 or not is_in_grass()):
		return false
	# Invisible brawlers are only given away by someone almost touching them.
	var reveal := 1.2 if invisible else float(GameData.rule("tall_grass/reveal_distance", 2.5))
	for node in get_tree().get_nodes_in_group("brawlers"):
		var other := node as Brawler
		if other and other.team == viewer_team and not other.is_dead \
				and other.global_position.distance_to(global_position) <= reveal:
			return false
	return true


## Whether the person playing can see this brawler on screen.
func visible_to_local_player() -> bool:
	if team == GameData.local_team:
		return true
	var viewer: Brawler = GameData.local_player
	if is_instance_valid(viewer) and viewer.is_blind():
		return false
	return not is_hidden_from(GameData.local_team)


# --- Aim indicator ---------------------------------------------------------

## Preview of the main attack. `distance` (0..range) places lobbed shots; < 0 = full range.
func show_aim(direction: Vector3, distance := -1.0) -> void:
	if is_dead or direction.length_squared() < 0.0001:
		hide_aim()
		return
	direction = Vector3(direction.x, 0, direction.z).normalized()
	aim_pivot.rotation.y = atan2(-direction.x, -direction.z)
	aim_indicator.visible = true
	var m := main_move
	if m.kind == "projectile" and m.lob:
		var d := m.reach if distance < 0.0 else clampf(distance, 1.0, m.reach)
		aim_indicator.scale = Vector3.ONE
		aim_indicator.position = Vector3(0, 0.05, -d)
	elif aim_indicator.mesh is PlaneMesh:
		# Shorten the preview where a wall would stop the attack.
		var reach := _aim_length()
		var clip := clampf(clear_distance(direction, reach + 0.6) / (reach + 0.6), 0.05, 1.0)
		aim_indicator.scale = Vector3(1, 1, clip)
		aim_indicator.position = Vector3(0, 0.05, -(reach * clip) * 0.5 - 0.6)
	else:
		var reach := _aim_length()
		var clip := clampf(clear_distance(direction, reach) / reach, 0.05, 1.0)
		aim_indicator.scale = Vector3(clip, 1, clip)
		aim_indicator.position = Vector3(0, 0.05, 0)
	var mat := aim_indicator.material_override as StandardMaterial3D
	mat.albedo_color.a = 0.45 if can_shoot() else 0.15


func _aim_length() -> float:
	match main_move.kind:
		"dash":
			return main_move.dash_distance
		"melee":
			return main_move.reach + BODY_RADIUS
	return main_move.reach


var _super_aim: MeshInstance3D


## Super preview while dragging the super button: a circle where area and
## exploding supers land, or a strip showing how far shots and dashes go.
func show_super_aim(direction: Vector3, amount: float) -> void:
	var move := current_super()
	if is_dead or move == null or direction.length_squared() < 0.0001:
		hide_super_aim()
		return
	if _super_aim == null:
		_super_aim = MeshInstance3D.new()
		_super_aim.top_level = true
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1, 0.85, 0.2, 0.4)
		_super_aim.material_override = mat
		_super_aim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_super_aim)
	var dir := Vector3(direction.x, 0, direction.z).normalized()
	var radius := move.area_radius if move.kind == "area" else move.explode_radius
	if radius > 0.0:
		var disc := _super_aim.mesh as CylinderMesh
		if disc == null:
			disc = CylinderMesh.new()
			disc.height = 0.03
			_super_aim.mesh = disc
		disc.top_radius = radius
		disc.bottom_radius = radius
		var dist := clampf(amount, 0.0, 1.0) * move.reach
		_super_aim.global_transform = Transform3D(Basis(), global_position + dir * dist + Vector3(0, 0.06, 0))
	else:
		var strip := _super_aim.mesh as BoxMesh
		if strip == null:
			strip = BoxMesh.new()
			_super_aim.mesh = strip
		var length := move.dash_distance if move.kind == "dash" else move.reach
		strip.size = Vector3(maxf(0.4, move.radius * 2.0), 0.03, length)
		_super_aim.global_transform = Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.z)), global_position + dir * length * 0.5 + Vector3(0, 0.06, 0))
	_super_aim.visible = true


func hide_super_aim() -> void:
	if _super_aim:
		_super_aim.visible = false


func hide_aim() -> void:
	aim_indicator.visible = false


# --- Visuals ---------------------------------------------------------------

func _build_static_visuals() -> void:
	var shadow_mesh := CylinderMesh.new()
	shadow_mesh.top_radius = 0.5
	shadow_mesh.bottom_radius = 0.5
	shadow_mesh.height = 0.02
	shadow.mesh = null  # No ground shadow: it hid the Pokémon.
	shadow.material_override = _flat_material(Color(0, 0, 0, 0.35))
	shadow.position.y = 0.02

	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.6
	ring_mesh.outer_radius = 0.72
	team_ring.mesh = null  # No team ring either; health bar colours show teams.
	team_ring.scale = Vector3(1, 0.1, 1)
	team_ring.position.y = 0.04
	var ring_color := Color(1.0, 0.25, 0.25, 0.9)
	if is_player:
		ring_color = Color(0.35, 1.0, 0.45, 0.95)
	elif team == GameData.local_team:
		ring_color = Color(0.25, 0.6, 1.0, 0.9)
	team_ring.material_override = _flat_material(ring_color)

	_melee_material = _flat_material(Color(1, 1, 1, 0.0))
	melee_fx.material_override = _melee_material
	melee_fx.position.y = 0.08
	melee_fx.visible = false
	aim_indicator.material_override = _flat_material(Color(1, 1, 1, 0.45))
	aim_indicator.visible = false


## Rebuild the aim preview (and stream cone) to match the equipped main attack.
func _apply_loadout_visuals() -> void:
	var r := main_move
	if _stream_particles:
		_stream_particles.queue_free()
		_stream_particles = null
	if _stream_fx:
		_stream_fx.queue_free()
		_stream_fx = null
	aim_indicator.scale = Vector3.ONE
	if r.kind == "stream":
		var cone := _build_fan_mesh(r.reach, deg_to_rad(r.arc))
		aim_indicator.mesh = cone
		aim_indicator.position = Vector3(0, 0.05, 0)
		_stream_particles = Vfx.stream(r.type)
		_stream_particles.position = Vector3(0, 0.8, 0)
		add_child(_stream_particles)
		_stream_fx = MeshInstance3D.new()
		_stream_fx.mesh = cone
		_stream_material = _flat_material(Color(GameData.type_color(r.type).lightened(0.3), 0.15))
		_stream_fx.material_override = _stream_material
		_stream_fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_stream_fx.position.y = 0.3
		_stream_fx.visible = false
		add_child(_stream_fx)
	elif r.kind == "melee":
		aim_indicator.mesh = _build_fan_mesh(r.reach + BODY_RADIUS, deg_to_rad(minf(r.arc, 359.0)))
		aim_indicator.position = Vector3(0, 0.05, 0)
	elif r.kind == "dash":
		var lane := PlaneMesh.new()
		lane.size = Vector2(BODY_RADIUS * 2.0, r.dash_distance)
		aim_indicator.mesh = lane
	elif r.lob:
		var disc := CylinderMesh.new()
		var radius := maxf(r.explode_radius, r.linger_radius)
		disc.top_radius = maxf(0.8, radius)
		disc.bottom_radius = disc.top_radius
		disc.height = 0.03
		aim_indicator.mesh = disc
	elif r.count > 1 or r.spread > 0.0:
		aim_indicator.mesh = _build_fan_mesh(r.reach + 0.6, deg_to_rad(maxf(r.spread, 8.0)))
		aim_indicator.position = Vector3(0, 0.05, 0)
	else:
		var plane := PlaneMesh.new()
		plane.size = Vector2(maxf(0.6, r.radius * 2.0), r.reach)
		aim_indicator.mesh = plane
		aim_indicator.position = Vector3(0, 0.05, -r.reach * 0.5 - 0.6)


var _sparkle := 0.0


func _update_sprite(delta: float) -> void:
	# Shiny Pokémon twinkle now and then.
	if shiny and not is_dead and sprite.visible:
		_sparkle -= delta
		if _sparkle <= 0.0:
			_sparkle = randf_range(0.8, 1.6)
			Vfx.burst(get_parent(), global_position + Vector3(randf_range(-0.4, 0.4), randf_range(0.6, 1.4), 0), "fairy", 5, 0.15, 1.2)
	var hidden := not visible_to_local_player()
	sprite.visible = not hidden
	# No ground shadow or team ring: they made it harder to see the Pokémon themselves.
	shadow.visible = false
	team_ring.visible = false
	_animate(delta)
	_update_shield(hidden)
	if is_dead:
		return

	_flash_timer = maxf(0.0, _flash_timer - delta)
	var tint := Color.WHITE
	if _flash_timer > 0.0:
		tint = Color(1, 0.45, 0.45)
	elif _dot_time > 0.0:
		tint = { "burn": Color(1, 0.75, 0.55), "poison": Color(0.85, 0.65, 1), "leech": Color(0.7, 1, 0.6) }.get(_dot_kind, Color.WHITE)
	elif _slow_time > 0.0:
		tint = Color(1, 1, 0.6)
	elif _buff("defense") > 0.0:
		tint = Color(0.75, 0.9, 1.0)
	# Your own team stays visible in grass (or while invisible), just faded.
	var faded := (is_in_grass() or _invisible_time > 0.0) and team == GameData.local_team
	tint.a = 0.55 if faded else 1.0
	if is_stunned():
		tint = tint.darkened(0.25)
	sprite.modulate = tint
	_update_auras(hidden)


## Walk cycle, facing and squash-and-stretch. The sprite stands up facing the
## fixed camera (not a billboard) so it can waddle; its pivot is at the feet.
func _animate(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var tilt := camera.global_rotation.x if camera else -1.0
	var moving := velocity.length_squared() > 0.1 and not is_dead
	var roll := 0.0
	var squash := 1.0
	var lift := 0.0
	if moving:
		_anim_phase += delta * (6.0 + velocity.length() * 1.6)
		roll = sin(_anim_phase) * 0.13  # Waddle side to side...
		lift = absf(sin(_anim_phase)) * 0.12  # ...hopping a little each step...
		squash = 1.0 - absf(cos(_anim_phase)) * 0.07  # ...and squashing as each foot lands.
	else:
		_anim_phase += delta * 2.6
		squash = 1.0 + sin(_anim_phase) * 0.025  # Idle breathing.
	if flying:
		lift += 0.9 + sin(Time.get_ticks_msec() * 0.003) * 0.15
	elif can_swim and arena != null and arena.is_water(global_position):
		lift -= 0.22  # Swimming: sit low in the water.
	_pop = move_toward(_pop, 1.0, delta * 3.5)
	var sx := _pop / sqrt(squash)
	var sy := _pop * squash
	if is_dead:
		_dead_time += delta
		var t := clampf(_dead_time / 0.35, 0.0, 1.0)
		sx *= 1.0 + t * 0.4
		sy *= maxf(0.05, 1.0 - t)

	# Pick the view that matches where we're facing.
	if species.sheet:
		if absf(facing.x) > absf(facing.z) * 0.9:
			sprite.frame = 1
			sprite.flip_h = facing.x < 0.0
		else:
			sprite.frame = 0 if facing.z >= 0.0 else 2
			sprite.flip_h = false
	elif absf(facing.x) > 0.2:
		sprite.flip_h = facing.x < 0.0

	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sprite.offset = Vector2(0, sprite.texture.get_height() * 0.5) if sprite.texture else Vector2.ZERO
	sprite.position = Vector3(0, 0.05 + lift, 0)
	sprite.basis = Basis(Vector3.RIGHT, tilt) * Basis(Vector3.BACK, roll) * Basis.from_scale(Vector3(sx, sy, 1.0))


## Bubble shown during spawn protection; it flickers just before it ends.
func _update_shield(hidden: bool) -> void:
	if not is_protected() and _shield == null:
		return
	if _shield == null:
		var sphere := SphereMesh.new()
		sphere.radius = 0.95
		sphere.height = 1.9
		_shield = MeshInstance3D.new()
		_shield.mesh = sphere
		_shield.material_override = _flat_material(Color(0.6, 0.85, 1.0, 0.28))
		_shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_shield.position.y = 0.85
		add_child(_shield)
	var flicker := _protect_time > 0.6 or int(Time.get_ticks_msec() / 80) % 2 == 0
	_shield.visible = is_protected() and not hidden and flicker


## Particles around the body for each active status (only while it's on screen).
func _update_auras(hidden: bool) -> void:
	var active := {
		"fire": _dot_time > 0.0 and _dot_kind == "burn",
		"poison": _dot_time > 0.0 and _dot_kind == "poison",
		"grass": _dot_time > 0.0 and _dot_kind == "leech",
		"electric": _slow_time > 0.0,
		"psychic": _stun_time > 0.0,
		"flying": _blind_time > 0.0,
	}
	for aura_type: String in active:
		var on: bool = active[aura_type] and not hidden and not is_dead
		if on and not _auras.has(aura_type):
			var p := Vfx.aura(aura_type)
			add_child(p)
			_auras[aura_type] = p
		if _auras.has(aura_type):
			(_auras[aura_type] as CPUParticles3D).emitting = on


func _show_melee_fx(direction: Vector3, move: MoveData) -> void:
	melee_fx.mesh = _build_fan_mesh(move.reach + BODY_RADIUS, deg_to_rad(move.arc))
	melee_fx.rotation.y = atan2(-direction.x, -direction.z)
	melee_fx.visible = true
	if _melee_tween:
		_melee_tween.kill()
	_melee_material.albedo_color = Color(GameData.type_color(move.type).lightened(0.4), 0.6)
	_melee_tween = create_tween()
	_melee_tween.tween_property(_melee_material, "albedo_color:a", 0.0, 0.2)
	_melee_tween.tween_callback(func() -> void: melee_fx.visible = false)


## Flat disc marking an area attack; returned so the caller can fade it.
func _area_fx(parent: Node, center: Vector3, move: MoveData) -> MeshInstance3D:
	var disc := CylinderMesh.new()
	disc.top_radius = move.area_radius
	disc.bottom_radius = move.area_radius
	disc.height = 0.04
	var fx := MeshInstance3D.new()
	fx.mesh = disc
	fx.material_override = _flat_material(Color(GameData.type_color(move.type), 0.3))
	fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(fx)
	fx.global_position = center + Vector3(0, 0.06, 0)
	return fx


func _flash_fx(radius: float) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	var fx := MeshInstance3D.new()
	fx.mesh = sphere
	var mat := _flat_material(Color(1, 1, 0.85, 0.55))
	fx.material_override = mat
	fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(fx)
	fx.global_position = global_position
	fx.scale = Vector3.ONE * 0.1
	var tween := fx.create_tween().set_parallel()
	tween.tween_property(fx, "scale", Vector3.ONE, 0.25)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tween.chain().tween_callback(fx.queue_free)


func _spawn_damage_number(amount: float, effectiveness: float, crit: bool) -> void:
	var text := str(roundi(amount))
	var color := Color.WHITE
	var size := 64
	if effectiveness > 1.01:
		text += "!"
		color = Color(1.0, 0.6, 0.15)
		size = 84
	elif effectiveness < 0.99:
		color = Color(0.75, 0.75, 0.75)
		size = 48
	if crit:
		text = "CRIT " + text
	_spawn_floating_text(text, color, size)


func _spawn_floating_text(text: String, color: Color, size: int, height := 2.0) -> void:
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = size
	label.outline_size = 16
	label.pixel_size = 0.008
	label.modulate = color
	label.outline_modulate = Color(0.15, 0.05, 0.05)
	get_parent().add_child(label)
	label.global_position = global_position + Vector3(randf_range(-0.3, 0.3), height, 0)
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y + 1.0, 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.3)
	tween.tween_property(label, "outline_modulate:a", 0.0, 0.6).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)


static func _flat_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = color
	return mat


static func _build_fan_mesh(radius: float, arc: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 16
	for i in segments:
		var a0 := -arc * 0.5 + arc * float(i) / segments
		var a1 := -arc * 0.5 + arc * float(i + 1) / segments
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(sin(a0), 0, -cos(a0)) * radius)
		st.add_vertex(Vector3(sin(a1), 0, -cos(a1)) * radius)
	return st.commit()
