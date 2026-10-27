extends Control
## Pre-match intro: your team on a blue banner sliding in from the left along the
## bottom, the other team on a red banner from the right along the top, and the
## mode and arena in the middle. Runs while the game is paused, then frees itself.

signal finished

const BLUE := Color(0.16, 0.42, 0.95)
const RED := Color(0.9, 0.2, 0.22)
## About 4 seconds in all: slide in, hold, slide out.
const SLIDE := 0.6
const HOLD := 3.0

var _hold_left := 0.0


## Tap anywhere to skip, once the banners have been up for a second (so the
## tap that started the match can't skip it).
func _input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch or event is InputEventKey) and event.is_pressed():
		if _hold_left > 0.0 and _hold_left < HOLD - 1.0:
			_hold_left = 0.0


func play(allies: Array, enemies: Array, mode_title: String, arena_name: String) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var view := get_viewport().get_visible_rect().size
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var banner_h := clampf(view.y * 0.24, 120.0, 190.0)
	var top := _banner(enemies, RED, banner_h, view.x, false)
	top.position = Vector2(view.x, view.y * 0.1)
	var bottom := _banner(allies, BLUE, banner_h, view.x, true)
	bottom.position = Vector2(-view.x, view.y * 0.9 - banner_h)
	add_child(top)
	add_child(bottom)

	var middle := VBoxContainer.new()
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.size = Vector2(view.x, 160)
	middle.position = Vector2(0, view.y * 0.5 - 80)
	middle.pivot_offset = middle.size * 0.5
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := UiKit.label(mode_title, 56, Color(1, 0.88, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 14)
	middle.add_child(title)
	var where := UiKit.label(arena_name.to_upper(), 30, Color.WHITE)
	where.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	where.add_theme_constant_override("outline_size", 10)
	middle.add_child(where)
	middle.modulate.a = 0.0
	middle.scale = Vector2(0.6, 0.6)
	add_child(middle)

	var tween := create_tween()
	tween.set_parallel()
	tween.tween_property(top, "position:x", 0.0, SLIDE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(bottom, "position:x", 0.0, SLIDE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(middle, "modulate:a", 1.0, 0.3).set_delay(SLIDE * 0.6)
	tween.tween_property(middle, "scale", Vector2.ONE, 0.35).set_delay(SLIDE * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished
	# Hold on a real-time timer (runs while paused); a tap after the first second skips it.
	_hold_left = HOLD
	while _hold_left > 0.0:
		await get_tree().process_frame
		_hold_left -= get_process_delta_time()
	tween = create_tween()
	tween.set_parallel()
	tween.tween_property(top, "position:x", -view.x, 0.35).set_ease(Tween.EASE_IN)
	tween.tween_property(bottom, "position:x", view.x, 0.35).set_ease(Tween.EASE_IN)
	tween.tween_property(middle, "modulate:a", 0.0, 0.3)
	tween.tween_property(dim, "color:a", 0.0, 0.35)
	await tween.finished
	finished.emit()
	queue_free()


## A slanted team-coloured strip with each Pokémon's sprite and name.
func _banner(members: Array, color: Color, height: float, width: float, ours: bool) -> Control:
	var strip := Panel.new()
	strip.size = Vector2(width, height)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = color.lightened(0.45)
	sb.border_width_top = 5
	sb.border_width_bottom = 5
	sb.skew = Vector2(0.25 if ours else -0.25, 0)
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 10
	strip.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size = strip.size
	row.add_theme_constant_override("separation", int(clampf(width / maxf(1, members.size()) * 0.12, 16, 60)))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tag := UiKit.label("YOUR TEAM" if ours else "OPPONENTS", 22, Color(1, 1, 1, 0.85))
	tag.add_theme_constant_override("outline_size", 6)
	row.add_child(tag)
	for b in members:
		if not is_instance_valid(b):
			continue
		var brawler := b as Brawler
		var card := VBoxContainer.new()
		card.alignment = BoxContainer.ALIGNMENT_CENTER
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(UiKit.sprite(brawler.portrait(), height * 0.58))
		var name_text := brawler.species.display_name + ("  (YOU)" if brawler.is_player else "")
		var label := UiKit.label(name_text, 20, Color(1, 0.95, 0.55) if brawler.is_player else Color.WHITE)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_constant_override("outline_size", 6)
		card.add_child(label)
		row.add_child(card)
	strip.add_child(row)
	return strip
