extends MatchMode
## Showdown: every Pokémon for itself, no respawns, last one standing wins.
## Smash crates for power cubes (more HP and damage); fainted Pokémon drop
## theirs. A poison cloud closes in from the edges and hurts anyone caught in it.

const CLOUD_TICK := 0.5

var elapsed := 0.0
## Safe area (world x/z) that shrinks over time; outside it the cloud hurts.
var safe := Rect2()
var _full := Rect2()
var _cloud_tick := 0.0
var _cloud_walls: Array[MeshInstance3D] = []
var _cloud_material: StandardMaterial3D


func start() -> void:
	var arena: Arena = main.arena
	var size: Vector2 = arena.world_size()
	_full = Rect2(-size * 0.5, size)
	safe = _full
	# Maps without crate tiles get some scattered around.
	var crates := get_tree().get_nodes_in_group("breakables").filter(func(n: Node) -> bool: return (n as Breakable).kind == "crate")
	if crates.is_empty():
		for i in int(rules.get("crates_if_none", 12)):
			var cell := arena.world_to_cell(arena.random_open_point())
			if arena.is_walkable(arena.cell_center(cell)):
				crates.append(arena.add_crate(cell))
	for node in crates:
		(node as Breakable).broken.connect(_on_crate_broken)
	_build_cloud()


func _build_cloud() -> void:
	_cloud_material = StandardMaterial3D.new()
	_cloud_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cloud_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cloud_material.albedo_color = Color(0.35, 0.85, 0.3, 0.32)
	for i in 4:
		var wall := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3.ONE
		wall.mesh = box
		wall.material_override = _cloud_material
		wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wall.visible = false
		main.arena.add_child(wall)
		_cloud_walls.append(wall)


func tick(delta: float) -> void:
	elapsed += delta
	var start_at := float(rules.get("cloud_start", 25.0))
	var end_at := float(rules.get("cloud_end", 110.0))
	var t := clampf((elapsed - start_at) / maxf(1.0, end_at - start_at), 0.0, 1.0)
	var min_size := Vector2(float(rules.get("safe_width", 6.0)), float(rules.get("safe_depth", 8.0)))
	var safe_size := _full.size.lerp(min_size, t)
	safe = Rect2(-safe_size * 0.5, safe_size)
	_update_cloud_visuals(t > 0.0)
	_cloud_tick -= delta
	if _cloud_tick > 0.0 or t <= 0.0:
		return
	_cloud_tick = CLOUD_TICK
	var dps := float(rules.get("cloud_dps", 450.0)) * (1.0 + maxf(0.0, elapsed - start_at) / 40.0)
	for team: int in main.teams:
		for b: Brawler in main.teams[team]:
			if not b.is_dead and not in_safe(b.global_position):
				b.take_damage(dps * CLOUD_TICK)


func in_safe(pos: Vector3, margin := 0.0) -> bool:
	return safe.grow(-margin).has_point(Vector2(pos.x, pos.z))


## Four big green boxes around the safe rectangle.
func _update_cloud_visuals(active: bool) -> void:
	var outer := _full.grow(20.0)
	var rects := [
		Rect2(outer.position, Vector2(outer.size.x, safe.position.y - outer.position.y)),
		Rect2(Vector2(outer.position.x, safe.end.y), Vector2(outer.size.x, outer.end.y - safe.end.y)),
		Rect2(Vector2(outer.position.x, safe.position.y), Vector2(safe.position.x - outer.position.x, safe.size.y)),
		Rect2(Vector2(safe.end.x, safe.position.y), Vector2(outer.end.x - safe.end.x, safe.size.y)),
	]
	for i in 4:
		var r: Rect2 = rects[i]
		var wall := _cloud_walls[i]
		wall.visible = active and r.size.x > 0.01 and r.size.y > 0.01
		wall.scale = Vector3(maxf(0.01, r.size.x), 2.4, maxf(0.01, r.size.y))
		wall.position = Vector3(r.get_center().x, 1.2, r.get_center().y)
	_cloud_material.albedo_color.a = 0.28 + 0.06 * sin(elapsed * 2.0)


func _on_crate_broken(crate: Breakable) -> void:
	spawn_cube(crate.global_position, crate.global_position)


func spawn_cube(from: Vector3, at: Vector3) -> Collectible:
	var cube := Collectible.new()
	cube.setup("power_cube", from, at)
	cube.collected.connect(func(_c: Collectible, by: Brawler) -> void: by.add_power_cube())
	main.arena.add_child(cube)
	return cube


func alive() -> Array[Brawler]:
	var result: Array[Brawler] = []
	for team: int in main.teams:
		for b: Brawler in main.teams[team]:
			if not b.is_dead:
				result.append(b)
	return result


func on_died(victim: Brawler, _killer: Brawler) -> bool:
	var left := alive()
	victim.placement = left.size() + 1
	for i in maxi(1, victim.power_cubes):
		var offset := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * randf_range(0.5, 1.4)
		spawn_cube(victim.global_position, main.arena.nearest_open(victim.global_position + offset))
	if victim == main.player:
		main.end_round("defeat", "You placed #%d" % victim.placement)
	elif left.size() == 1:
		left[0].placement = 1
		main.end_round("victory" if left[0] == main.player else "defeat", "#1 — you won Showdown!" if left[0] == main.player else "")
	return true


## Still alive when the clock runs out: rank by health left.
func time_up() -> String:
	var player: Brawler = main.player
	var rank := 1
	for b in alive():
		if b != player and b.health / b.max_health > player.health / player.max_health:
			rank += 1
	player.placement = rank
	return "victory" if rank == 1 else "defeat"


func spawn_position(b: Brawler) -> Vector3:
	return main.arena.showdown_point(b.team, main.teams.size())


func plan_for(b: Brawler) -> Dictionary:
	var arena: Arena = main.arena
	var center := Vector3(safe.get_center().x, 0, safe.get_center().y)
	if not in_safe(b.global_position, 2.0):
		return { "go": arena.nearest_open(center) }
	var threat := b.find_nearest_enemy(8.0)
	if threat:
		return {}
	var best_cube: Collectible = null
	var best := 11.0
	for node in get_tree().get_nodes_in_group("collectibles"):
		var c := node as Collectible
		if c and c.kind == "power_cube" and c.is_landed() and in_safe(c.global_position, 1.0):
			var d := b.global_position.distance_to(c.global_position)
			if d < best:
				best = d
				best_cube = c
	if best_cube:
		return { "go": best_cube.global_position }
	var crate: Breakable = null
	best = 14.0
	for node in get_tree().get_nodes_in_group("breakables"):
		var br := node as Breakable
		if br and br.kind == "crate" and not br.is_broken and in_safe(br.global_position, 1.0):
			var d := b.global_position.distance_to(br.global_position)
			if d < best:
				best = d
				crate = br
	if crate:
		return { "go": crate.global_position, "shoot": crate.global_position }
	return { "go": arena.nearest_open(center) } if b.find_nearest_enemy() == null else {}


func scoreboard_info() -> Dictionary:
	var start_at := float(rules.get("cloud_start", 25.0))
	return { "left": alive().size(), "cloud_in": maxf(0.0, start_at - elapsed), "cubes": main.player.power_cubes }


func stat_name() -> String:
	return "CUBES"


func stat_value(b: Brawler) -> int:
	return b.power_cubes


func player_team() -> int:
	return 0
