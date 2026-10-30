class_name TutorialPicture
extends Control
## The drawings on the How to Play pages: a mini HUD (sticks and buttons in their
## real colours), Pokémon sprites, a menu sketch, balls and store cards.

var kind := ""


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_style_box(UiKit.box(Color(0.1, 0.13, 0.22), 18, 0), r)
	var c := size * 0.5
	var font := ThemeDB.fallback_font
	match kind:
		"team":
			_sprites(["pikachu", "charmander", "squirtle"], Vector2(c.x, c.y - 60), 80)
			_text(font, Vector2(c.x, c.y + 6), "VS", 34, Color(1, 0.85, 0.3))
			_sprites(["gengar", "onix", "pidgeot"], Vector2(c.x, c.y + 80), 80)
		"sticks":
			_stick(Vector2(size.x * 0.27, size.y * 0.62), "MOVE", Color(0.85, 0.9, 1.0))
			_stick(Vector2(size.x * 0.73, size.y * 0.62), "ATTACK", Color(1, 0.75, 0.3))
			_sprite("pikachu", Vector2(c.x, size.y * 0.24), 70)
			draw_line(Vector2(c.x + 20, size.y * 0.24), Vector2(c.x + 110, size.y * 0.16), Color(1, 1, 1, 0.7), 4)
			for i in 3:
				draw_rect(Rect2(c.x - 34 + i * 24, size.y * 0.24 + 40, 20, 7), Color(1, 0.6, 0.1))
		"buttons":
			_button(Vector2(size.x * 0.3, size.y * 0.32), "SUPER", Color(1, 0.75, 0.15))
			_button(Vector2(size.x * 0.7, size.y * 0.32), "GADGET", Color(0.3, 0.85, 0.55))
			_button(Vector2(size.x * 0.3, size.y * 0.74), "HM", Color(0.6, 0.45, 0.9))
			_button(Vector2(size.x * 0.7, size.y * 0.74), "Z-MOVE", Color(1.0, 0.82, 0.25))
		"moves":
			_sprites(["charmander", "charmeleon", "charizard"], Vector2(c.x, c.y - 40), 90)
			_chip(Vector2(c.x - 110, c.y + 60), "BRN", Color(1, 0.8, 0.3))
			_chip(Vector2(c.x - 30, c.y + 60), "SPE ▾", Color(0.45, 0.72, 1.0))
			_chip(Vector2(c.x + 60, c.y + 60), "ATK ▴", Color(1.0, 0.6, 0.25))
			_text(font, Vector2(c.x, c.y + 120), "EVOLVE WITH KOs", 20, Color(1, 0.85, 0.3))
		"home":
			var rows := [["BATTLE", Color(0.95, 0.6, 0.15)], ["CHALLENGES", Color(0.45, 0.3, 0.75)], ["POKéDEX", Color(0.75, 0.3, 0.3)],
					["BAG", Color(0.25, 0.55, 0.45)], ["POKé MART", Color(0.3, 0.45, 0.8)]]
			for i in rows.size():
				var box := Rect2(Vector2(40, 22 + i * 54), Vector2(size.x - 80, 44))
				draw_style_box(UiKit.box(rows[i][1], 10, 0), box)
				_text(font, box.get_center() + Vector2(0, 6), str(rows[i][0]), 20, Color.WHITE)
		"bag":
			var kinds := ["poke_ball", "great_ball", "ultra_ball", "master_ball"]
			for i in kinds.size():
				BallOpening.draw_ball(self, Vector2(size.x * (0.17 + i * 0.22), c.y - 50), 30, kinds[i])
			for i in 3:
				var icon := UiKit.item_icon(["rare_candy", "protein", "hp_up"][i])
				if icon:
					draw_texture_rect(icon, Rect2(Vector2(size.x * (0.22 + i * 0.28) - 28, c.y + 30), Vector2(56, 56)), false)
		"store":
			for i in 3:
				var box := Rect2(Vector2(26 + i * (size.x - 52) / 3.0, c.y - 70), Vector2((size.x - 52) / 3.0 - 10, 140))
				draw_style_box(UiKit.box([Color(0.3, 0.45, 0.8), Color(0.55, 0.35, 0.8), Color(0.85, 0.6, 0.15)][i], 10, 0), box)
				var icon := UiKit.item_icon(["rare_candy", "carbos", "iron"][i])
				if icon:
					draw_texture_rect(icon, Rect2(box.get_center() - Vector2(26, 46), Vector2(52, 52)), false)
				_text(font, box.get_center() + Vector2(0, 40), ["300 ₽", "450 ₽", "600 ₽"][i], 18, Color.WHITE)
		"ready":
			_sprite("pikachu", c - Vector2(0, 10), 160)


func _sprite(id: String, at: Vector2, px: float) -> void:
	var s: SpeciesData = GameData.species.get(id)
	if s and s.sprite:
		draw_texture_rect(s.sprite, Rect2(at - Vector2(px, px) * 0.5, Vector2(px, px)), false)


func _sprites(ids: Array, center: Vector2, px: float) -> void:
	for i in ids.size():
		_sprite(str(ids[i]), center + Vector2((i - (ids.size() - 1) * 0.5) * px * 1.05, 0), px)


func _stick(at: Vector2, label_text: String, color: Color) -> void:
	draw_circle(at, 62, Color(1, 1, 1, 0.12))
	draw_arc(at, 62, 0, TAU, 40, Color(1, 1, 1, 0.5), 3)
	UiKit.draw_shaded_circle(self, at + Vector2(14, -10), 26, color)
	_text(ThemeDB.fallback_font, at + Vector2(0, 92), label_text, 18, Color.WHITE)


func _button(at: Vector2, label_text: String, color: Color) -> void:
	UiKit.draw_shaded_circle(self, at, 44, color)
	_text(ThemeDB.fallback_font, at + Vector2(0, 70), label_text, 18, Color.WHITE)


func _chip(at: Vector2, text: String, color: Color) -> void:
	draw_style_box(UiKit.box(Color(0, 0, 0, 0.5), 8, 0), Rect2(at - Vector2(36, 16), Vector2(72, 32)))
	_text(ThemeDB.fallback_font, at + Vector2(0, 7), text, 18, color)


func _text(font: Font, at: Vector2, text: String, size: int, color: Color) -> void:
	var w := 400.0
	draw_string_outline(font, at - Vector2(w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_CENTER, w, size, 5, Color(0, 0, 0, 0.8))
	draw_string(font, at - Vector2(w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_CENTER, w, size, color)
