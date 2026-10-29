class_name UnlockReveal
extends Control
## Full-screen reveal for a newly unlocked line, like the old evolution scenes:
## a Poké Ball drops and pops open, a black silhouette comes out, flashes white
## faster and faster, then bursts into colour with "Congrats!". Tap to close
## once it's shown (or tap early to skip to the reveal). Emits `finished`.

signal finished

const SHADER := """
shader_type canvas_item;
uniform vec4 fill : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float amount = 1.0;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(mix(tex.rgb, fill.rgb, amount), tex.a * COLOR.a);
}
"""

var species: SpeciesData
var _t := 0.0
var _phase := "drop"  # drop → open → shadow → flash → reveal
var _sprite: TextureRect
var _mat: ShaderMaterial
var _text: VBoxContainer


func _ready() -> void:
	add_to_group("modal_overlay")
	mouse_filter = Control.MOUSE_FILTER_STOP
	_mat = ShaderMaterial.new()
	_mat.shader = Shader.new()
	_mat.shader.code = SHADER
	_sprite = TextureRect.new()
	_sprite.texture = species.sprite
	_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.material = _mat
	_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sprite.visible = false
	add_child(_sprite)
	_fit()
	get_viewport().size_changed.connect(_fit)


func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size


func _center() -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.42)


func _process(delta: float) -> void:
	_t += delta
	match _phase:
		"drop":
			if _t > 0.7:
				_go("open")
		"open":
			if _t > 0.35:
				_go("shadow")
		"shadow":
			if _t > 0.9:
				_go("flash")
		"flash":
			if _t > 2.6:
				_reveal()
	_update_sprite()
	queue_redraw()


func _go(phase: String) -> void:
	_phase = phase
	_t = 0.0


func _update_sprite() -> void:
	var side := minf(size.x, size.y) * 0.5
	var grow := 1.0
	var amount := 1.0
	var fill := Color.BLACK
	match _phase:
		"drop", "open":
			_sprite.visible = false
			return
		"shadow":
			grow = clampf(_t / 0.5, 0.15, 1.0)  # Pops out of the ball.
		"flash":
			# Flashes white, faster and faster; the last one stays white.
			var rate := 2.0 + _t * 5.0
			var on := fmod(_t * rate, 1.0) < 0.5 or _t > 2.3
			fill = Color.WHITE if on else Color.BLACK
		"reveal":
			amount = clampf(1.0 - _t / 0.5, 0.0, 1.0)
			fill = Color.WHITE
			grow = 1.0 + 0.08 * sin(clampf(_t / 0.5, 0.0, 1.0) * PI)
	_sprite.visible = true
	_mat.set_shader_parameter("fill", fill)
	_mat.set_shader_parameter("amount", amount)
	var s := side * grow
	_sprite.size = Vector2(s, s)
	_sprite.position = _center() - Vector2(s, s) * 0.5


func _reveal() -> void:
	if _phase == "reveal":
		return
	_go("reveal")
	_text = VBoxContainer.new()
	_text.alignment = BoxContainer.ALIGNMENT_CENTER
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := UiKit.label("CONGRATS!", 54, Color(1, 0.85, 0.25))
	title.add_theme_constant_override("outline_size", 12)
	var line := UiKit.label("You unlocked %s!" % species.display_name, 34)
	line.add_theme_constant_override("outline_size", 8)
	var hint := UiKit.label("Tap to continue", 18, Color(1, 1, 1, 0.7))
	for l: Label in [title, line, hint]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_text.add_child(l)
	add_child(_text)
	_text.size = Vector2(size.x, 0)
	_text.position = Vector2(0, size.y * 0.72)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.is_pressed()):
		return
	accept_event()
	if _phase != "reveal":
		_reveal()
	elif _t > 0.6:
		remove_from_group("modal_overlay")
		finished.emit()
		queue_free()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.08, 0.92))
	var c := _center()
	var r := minf(size.x, size.y) * 0.09
	match _phase:
		"drop":
			var d := clampf(_t / 0.7, 0.0, 1.0)
			var b := (1.0 - d) * (1.0 - d)
			BallOpening.draw_ball(self, c + Vector2(0, size.y * 0.2 - b * size.y * 0.6), r, "poke_ball")
		"open":
			BallOpening.draw_ball(self, c + Vector2(0, size.y * 0.2), r, "poke_ball", clampf(_t / 0.2, 0.0, 1.0))
			# White burst from the ball.
			var k := _t / 0.35
			draw_circle(c + Vector2(0, size.y * 0.2), r * (1.0 + k * 8.0), Color(1, 1, 1, 1.0 - k))
		"flash":
			if _t > 2.3:  # The light builds before the reveal.
				draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, (_t - 2.3) / 0.3 * 0.8))
		"reveal":
			draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, clampf(0.8 - _t / 0.4, 0.0, 1.0)))
			# Light rays behind the Pokémon.
			for i in 12:
				var a := i * TAU / 12.0 + _t * 0.4
				var p1 := c + Vector2(cos(a - 0.08), sin(a - 0.08)) * size.length()
				var p2 := c + Vector2(cos(a + 0.08), sin(a + 0.08)) * size.length()
				draw_colored_polygon(PackedVector2Array([c, p1, p2]), Color(1, 0.85, 0.3, 0.12))
