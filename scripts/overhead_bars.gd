extends Control
## Draws name, health bar, status and (for the player) ammo bars above each brawler.

const BAR_SIZE := Vector2(96, 14)
const HEAD_HEIGHT := 2.2


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var font := ThemeDB.fallback_font
	for node in get_tree().get_nodes_in_group("brawlers"):
		var brawler := node as Brawler
		if brawler == null or brawler.is_dead or not brawler.visible_to_local_player():
			continue
		var head := HEAD_HEIGHT * brawler.species.sprite_scale
		if brawler.species.sprite_height > 0:
			# Well clear of the sprite so the bar never covers the Pokémon.
			head = brawler.species.sprite_height * Brawler.SHEET_PIXEL_SIZE * brawler.species.sprite_scale + 1.15
		var world_pos := brawler.global_position + Vector3.UP * (head + (0.9 if brawler.flying else 0.0))
		if camera.is_position_behind(world_pos):
			continue
		var p := camera.unproject_position(world_pos)
		if brawler.is_legendary:
			_draw_legendary(brawler, p, font)
			continue
		var bar := Rect2(p - Vector2(BAR_SIZE.x * 0.5, 0), BAR_SIZE)
		var ratio := brawler.health / brawler.max_health
		var friendly := brawler.team == GameData.local_team
		var fill_color := Color(0.95, 0.25, 0.25)
		if brawler.is_player:
			fill_color = Color(0.3, 0.85, 0.35)
		elif friendly:
			fill_color = Color(0.3, 0.6, 1.0)

		_round_rect(bar.grow(3), Color(0, 0, 0, 0.7), 7)
		if ratio > 0.0:
			_round_rect(Rect2(bar.position, Vector2(maxf(bar.size.x * ratio, 8.0), bar.size.y)), fill_color, 5)
			_round_rect(Rect2(bar.position, Vector2(maxf(bar.size.x * ratio, 8.0), bar.size.y * 0.45)), Color(1, 1, 1, 0.25), 5)

		_text(font, Vector2(bar.position.x, bar.position.y - 4), bar.size.x, str(ceili(brawler.health)), 18, Color.WHITE)
		var name_color := Color(0.6, 0.85, 1.0) if friendly else Color(1.0, 0.7, 0.7)
		var title := "%s Lv%d" % [brawler.species.display_name, brawler.level]
		_text(font, Vector2(bar.position.x - 60, bar.position.y - 24), bar.size.x + 120, title, 16, name_color)

		# Type pips to the left of the bar.
		for i in brawler.species.types.size():
			var pip := Vector2(bar.position.x - 10 - i * 12, bar.position.y + bar.size.y * 0.5)
			draw_circle(pip, 5, Color.BLACK)
			draw_circle(pip, 4, GameData.type_color(brawler.species.types[i]))

		var status := brawler.status_text()
		if status != "":
			_text(font, Vector2(bar.end.x + 4, bar.end.y), 40, status, 14, Color(1, 0.8, 0.3), HORIZONTAL_ALIGNMENT_LEFT)
		# Rare Candies carried / power cubes, left of the name.
		var counter := ""
		var counter_color := Color.WHITE
		if brawler.candies > 0:
			counter = "%d" % brawler.candies
			counter_color = Color(0.5, 0.75, 1.0)
		elif brawler.power_cubes > 0:
			counter = "%d" % brawler.power_cubes
			counter_color = Color(0.5, 1.0, 0.55)
		if counter != "":
			var icon_path := "res://assets/items/rare_candy.png" if brawler.candies > 0 else "res://assets/items/power_cube.png"
			var at := Vector2(bar.position.x - 52, bar.position.y - 46)
			draw_texture_rect(load(icon_path), Rect2(at, Vector2(26, 26)), false)
			_text(font, at + Vector2(-4, 44), 34, counter, 18, counter_color)
		if brawler.ball != null:
			_text(font, Vector2(bar.position.x - 30, bar.position.y - 44), bar.size.x + 60, "HAS THE BALL", 16, Color(1, 1, 1))
		# One pip per KO toward the next evolution, with dim pips for the ones still needed.
		if brawler.species.evolves_to != "" or brawler.power_ups < brawler.max_power_ups():
			for i in brawler.kills_needed():
				var pip := Vector2(bar.end.x + 8 + i * 10, bar.position.y - 4)
				draw_circle(pip, 3.5, Color(1, 0.85, 0.2) if i < brawler.evolve_kills else Color(0, 0, 0, 0.45))

		if brawler.is_player:
			_draw_ammo(brawler, Vector2(bar.position.x, bar.end.y + 4))
		elif brawler.super_charge >= 1.0:
			# Super ready: a gold dot left of the name, so you can see it coming.
			draw_circle(Vector2(bar.position.x - 10, bar.position.y - 30), 6, Color.BLACK)
			draw_circle(Vector2(bar.position.x - 10, bar.position.y - 30), 5, Color(1, 0.85, 0.2))


## Raid boss: wide gold bar plus a blue-vs-red bar of who has hurt it most.
## Summoned ally: its team colour and the seconds it has left.
func _draw_legendary(b: Brawler, p: Vector2, font: Font) -> void:
	var bar_size := Vector2(190, 16)
	var bar := Rect2(p - Vector2(bar_size.x * 0.5, 0), bar_size)
	var neutral := b.team >= 9
	var fill := Color(1.0, 0.78, 0.2)
	if not neutral:
		fill = Color(0.3, 0.6, 1.0) if b.team == GameData.local_team else Color(0.95, 0.25, 0.25)
	_round_rect(bar.grow(4), Color(0.35, 0.25, 0.05, 0.9), 9)
	_round_rect(Rect2(bar.position, Vector2(maxf(bar_size.x * b.health / b.max_health, 8.0), bar_size.y)), fill, 6)
	var title := ("WILD %s" % b.species.display_name.to_upper()) if neutral \
			else "%s  %ds" % [b.species.display_name.to_upper(), ceili(b.legendary_time_left)]
	_text(font, Vector2(bar.position.x - 40, bar.position.y - 8), bar_size.x + 80, title, 20, Color(1, 0.92, 0.55))
	if neutral:
		var blue := float(b.damage_by_team.get(GameData.local_team, 0.0))
		var red := float(b.damage_by_team.get(1 - GameData.local_team, 0.0))
		var share := Rect2(bar.position + Vector2(0, bar_size.y + 6), Vector2(bar_size.x, 6))
		_round_rect(share.grow(1), Color(0, 0, 0, 0.6), 3)
		if blue + red > 0.0:
			var split := bar_size.x * blue / (blue + red)
			_round_rect(Rect2(share.position, Vector2(split, 6)), Color(0.3, 0.6, 1.0), 3)
			_round_rect(Rect2(share.position + Vector2(split, 0), Vector2(bar_size.x - split, 6)), Color(0.95, 0.3, 0.3), 3)


func _round_rect(rect: Rect2, color: Color, radius: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	draw_style_box(sb, rect)


func _text(font: Font, pos: Vector2, width: float, text: String, size: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	draw_string_outline(font, pos, text, align, width, size, 5, Color.BLACK)
	draw_string(font, pos, text, align, width, size, color)


func _draw_ammo(brawler: Brawler, origin: Vector2) -> void:
	if brawler.main_move.kind == "stream":
		# One long tank that drains while firing and refills when you stop.
		var tank := Rect2(origin, Vector2(BAR_SIZE.x, 7))
		draw_rect(tank.grow(1), Color(0, 0, 0, 0.75))
		var c := Color(1.0, 0.6, 0.1) if brawler.ammo > 0.1 else Color(0.7, 0.45, 0.2)
		draw_rect(Rect2(tank.position, Vector2(tank.size.x * brawler.ammo / brawler.max_ammo(), tank.size.y)), c)
		return
	var count := int(brawler.max_ammo())
	var gap := 3.0
	var seg_w := (BAR_SIZE.x - gap * (count - 1)) / count
	for i in count:
		var seg := Rect2(origin + Vector2(i * (seg_w + gap), 0), Vector2(seg_w, 7))
		draw_rect(seg.grow(1), Color(0, 0, 0, 0.75))
		var fill := clampf(brawler.ammo - i, 0.0, 1.0)
		var c := Color(1.0, 0.6, 0.1) if fill >= 1.0 else Color(0.7, 0.45, 0.2)
		draw_rect(Rect2(seg.position, Vector2(seg.size.x * fill, seg.size.y)), c)
