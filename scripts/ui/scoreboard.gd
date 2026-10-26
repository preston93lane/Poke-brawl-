extends Control
## Top-of-screen match info, Brawl Stars style: team portraits (greyed with a
## respawn countdown when fainted), the score and match timer in the middle,
## and a kill feed underneath.

const PORTRAIT := 46.0
const BLUE := Color(0.2, 0.5, 1.0)
const RED := Color(0.95, 0.25, 0.25)
const FEED_TIME := 4.0

## team -> Array[Brawler]
var teams := {}
var mode := "duel"
var scores := [0.0, 0.0]
var target := 10.0
var time_left := 0.0
## [{ "killer": Brawler, "victim": Brawler, "time": float }]
var _feed: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func add_kill(killer: Brawler, victim: Brawler) -> void:
	_feed.push_front({ "killer": killer, "victim": victim, "time": FEED_TIME })
	if _feed.size() > 4:
		_feed.pop_back()


func _process(delta: float) -> void:
	for entry in _feed:
		entry["time"] = float(entry["time"]) - delta
	_feed.assign(_feed.filter(func(e: Dictionary) -> bool: return float(e["time"]) > 0.0))
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var mid := size.x * 0.5
	var top := 10.0

	# Centre panel: blue score | timer | red score (or zone percentages).
	var panel := Rect2(mid - 150, top, 300, 62)
	_box(panel, Color(0.06, 0.07, 0.12, 0.8), 16)
	_box(Rect2(panel.position + Vector2(4, 4), Vector2(96, 54)), BLUE.darkened(0.2), 12)
	_box(Rect2(panel.position + Vector2(200, 4), Vector2(96, 54)), RED.darkened(0.2), 12)
	var left_text: String
	var right_text: String
	if mode == "king_of_the_hill":
		left_text = "%d%%" % (100.0 * scores[0] / target)
		right_text = "%d%%" % (100.0 * scores[1] / target)
	else:
		left_text = str(int(scores[0]))
		right_text = str(int(scores[1]))
	_text(font, Vector2(panel.position.x + 4, top + 44), 96, left_text, 36, Color.WHITE)
	_text(font, Vector2(panel.position.x + 200, top + 44), 96, right_text, 36, Color.WHITE)
	var seconds := maxi(0, ceili(time_left))
	var clock_color := Color(1, 0.4, 0.35) if seconds <= 20 else Color.WHITE
	_text(font, Vector2(mid - 50, top + 38), 100, "%d:%02d" % [seconds / 60, seconds % 60], 28, clock_color)
	var goal := "HOLD THE ZONE" if mode == "king_of_the_hill" else "FIRST TO %d" % int(target)
	_text(font, Vector2(mid - 50, top + 56), 100, goal, 11, Color(1, 1, 1, 0.7))
	if mode == "king_of_the_hill":
		for team in [0, 1]:
			var bar := Rect2(panel.position + Vector2(8 + team * 196, 50), Vector2(88, 5))
			_box(bar, Color(0, 0, 0, 0.5), 3)
			_box(Rect2(bar.position, Vector2(bar.size.x * clampf(scores[team] / target, 0, 1), bar.size.y)), Color.WHITE, 3)

	# Team portraits either side of the panel.
	for team: int in teams:
		var members: Array = teams[team]
		for i in members.size():
			if not is_instance_valid(members[i]):
				continue
			var b := members[i] as Brawler
			var x := panel.position.x - 12 - PORTRAIT - i * (PORTRAIT + 8) if team == 0 \
					else panel.end.x + 12 + i * (PORTRAIT + 8)
			_portrait(Rect2(x, top + 8, PORTRAIT, PORTRAIT), b, BLUE if team == 0 else RED, font)

	# Kill feed under the panel.
	var y := top + 80.0
	for entry in _feed:
		var alpha := clampf(float(entry["time"]), 0.0, 1.0)
		_feed_row(Vector2(mid, y), entry["killer"], entry["victim"], alpha)
		y += 34.0


func _portrait(rect: Rect2, b: Brawler, team_color: Color, font: Font) -> void:
	var ring := Color(1, 0.95, 0.5) if b.is_player else team_color
	_box(rect.grow(3), ring, 12)
	_box(rect, Color(0.12, 0.13, 0.2), 10)
	var tint := Color(0.35, 0.35, 0.35) if b.is_dead else Color.WHITE
	draw_texture_rect(b.species.sprite, rect.grow(-3), false, tint)
	if b.is_dead:
		_text(font, Vector2(rect.position.x, rect.position.y + rect.size.y * 0.68), rect.size.x, str(ceili(b.respawn_left)), 24, Color.WHITE)
	else:
		var hp := Rect2(rect.position.x + 3, rect.end.y - 7, (rect.size.x - 6) * b.health / b.max_health, 4)
		draw_rect(hp, Color(0.4, 1, 0.45) if b.team == GameData.local_team else Color(1, 0.4, 0.4))


func _feed_row(center: Vector2, killer: Brawler, victim: Brawler, alpha: float) -> void:
	if not is_instance_valid(victim):
		return
	var w := 120.0
	var row := Rect2(center.x - w / 2, center.y, w, 30)
	_box(row, Color(0, 0, 0, 0.5 * alpha), 10)
	var icon := 26.0
	if is_instance_valid(killer):
		var kc := BLUE if killer.team == GameData.local_team else RED
		_box(Rect2(row.position + Vector2(6, 2), Vector2(icon, icon)), Color(kc, 0.8 * alpha), 6)
		draw_texture_rect(killer.species.sprite, Rect2(row.position + Vector2(6, 2), Vector2(icon, icon)), false, Color(1, 1, 1, alpha))
	# Crossed swords between them.
	var c := row.get_center()
	draw_line(c + Vector2(-9, -9), c + Vector2(9, 9), Color(1, 1, 1, alpha), 3.0, true)
	draw_line(c + Vector2(9, -9), c + Vector2(-9, 9), Color(1, 1, 1, alpha), 3.0, true)
	var vc := BLUE if victim.team == GameData.local_team else RED
	var vr := Rect2(row.end.x - 6 - icon, row.position.y + 2, icon, icon)
	_box(vr, Color(vc, 0.8 * alpha), 6)
	draw_texture_rect(victim.species.sprite, vr, false, Color(0.6, 0.6, 0.6, alpha))


func _box(rect: Rect2, color: Color, radius: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	draw_style_box(sb, rect)


func _text(font: Font, pos: Vector2, width: float, text: String, size_px: int, color: Color) -> void:
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, size_px, 6, Color(0, 0, 0, 0.85))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, size_px, color)
