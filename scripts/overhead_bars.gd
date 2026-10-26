extends Control
## Draws name, health bar and (for the player) ammo bars above each brawler.

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
		if brawler == null or brawler.is_dead:
			continue
		var world_pos := brawler.global_position + Vector3.UP * HEAD_HEIGHT
		if camera.is_position_behind(world_pos):
			continue
		var p := camera.unproject_position(world_pos)
		var bar := Rect2(p - Vector2(BAR_SIZE.x * 0.5, 0), BAR_SIZE)
		var ratio := brawler.health / brawler.data.max_health
		var fill_color := Color(0.3, 0.85, 0.35) if brawler.is_player else Color(0.95, 0.25, 0.25)

		draw_rect(bar.grow(2), Color(0, 0, 0, 0.75))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), fill_color)

		var hp_text := str(ceili(brawler.health))
		var hp_pos := Vector2(bar.position.x, bar.position.y - 4)
		draw_string_outline(font, hp_pos, hp_text, HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 18, 5, Color.BLACK)
		draw_string(font, hp_pos, hp_text, HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 18, Color.WHITE)
		var name_pos := Vector2(bar.position.x - 40, bar.position.y - 24)
		var name_color := Color(0.6, 0.85, 1.0) if brawler.is_player else Color(1.0, 0.7, 0.7)
		draw_string_outline(font, name_pos, brawler.data.display_name, HORIZONTAL_ALIGNMENT_CENTER, bar.size.x + 80, 16, 5, Color.BLACK)
		draw_string(font, name_pos, brawler.data.display_name, HORIZONTAL_ALIGNMENT_CENTER, bar.size.x + 80, 16, name_color)

		if brawler.is_player:
			_draw_ammo(brawler, Vector2(bar.position.x, bar.end.y + 4))


func _draw_ammo(brawler: Brawler, origin: Vector2) -> void:
	var count := brawler.data.max_ammo
	var gap := 3.0
	var seg_w := (BAR_SIZE.x - gap * (count - 1)) / count
	for i in count:
		var seg := Rect2(origin + Vector2(i * (seg_w + gap), 0), Vector2(seg_w, 7))
		draw_rect(seg.grow(1), Color(0, 0, 0, 0.75))
		var fill := clampf(brawler.ammo - i, 0.0, 1.0)
		var c := Color(1.0, 0.6, 0.1) if fill >= 1.0 else Color(0.7, 0.45, 0.2)
		draw_rect(Rect2(seg.position, Vector2(seg.size.x * fill, seg.size.y)), c)
