class_name PauseMenu
extends Control
## Pause overlay for a match: the game freezes behind a dim screen with Resume,
## quick settings (haze, aim assist), How to Play and Quit to Menu.

signal resumed
signal quit_requested
signal help_requested


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiKit.make_theme()
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.08, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var title := UiKit.label("PAUSED", 40, Color(1, 0.85, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var resume := UiKit.button("RESUME", func() -> void: resumed.emit(), 28)
	resume.custom_minimum_size.y = 64
	resume.add_theme_stylebox_override("normal", UiKit.box(Color(0.25, 0.65, 0.35)))
	v.add_child(resume)
	v.add_child(_toggle("HAZE", "haze_blur"))
	v.add_child(_toggle("AIM ASSIST", "aim_assist"))
	v.add_child(UiKit.button("HOW TO PLAY", func() -> void: help_requested.emit(), 22))
	var quit := UiKit.button("QUIT TO MENU", func() -> void: quit_requested.emit(), 22)
	quit.add_theme_stylebox_override("normal", UiKit.box(Color(0.7, 0.25, 0.25)))
	v.add_child(quit)
	var note := UiKit.label("Quitting counts as a loss in gyms and boss raids.", 14, Color(1, 1, 1, 0.6))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(note)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode in [KEY_ESCAPE, KEY_P]:
		get_viewport().set_input_as_handled()
		resumed.emit()


func _toggle(text: String, key: String) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.button_pressed = bool(GameData.setting(key, true))
	b.text = "%s: %s" % [text, "ON" if b.button_pressed else "OFF"]
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_stylebox_override("normal", UiKit.box(Color(0.35, 0.38, 0.5)))
	b.add_theme_stylebox_override("pressed", UiKit.box(Color(0.22, 0.48, 0.9)))
	b.add_theme_stylebox_override("hover_pressed", UiKit.box(Color(0.3, 0.55, 0.95)))
	b.toggled.connect(func(on: bool) -> void:
		GameData.set_setting(key, on)
		b.text = "%s: %s" % [text, "ON" if on else "OFF"]
		if key == "haze_blur":
			var haze := get_tree().current_scene.get_node_or_null("Haze") as CanvasLayer
			if haze:
				haze.visible = on)
	return b
