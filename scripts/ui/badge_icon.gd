class_name BadgeIcon
extends Control
## A gym badge for the Profile screen: a shiny gem in the gym's type colour with
## its type symbol, or a dark outline until that gym is beaten.

var type_name := "normal"
var earned := false


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.44
	var points := PackedVector2Array()
	for i in 8:
		var a := TAU * (i + 0.5) / 8.0
		points.append(c + Vector2(cos(a), sin(a)) * r)
	if not earned:
		draw_colored_polygon(points, Color(0, 0, 0, 0.35))
		points.append(points[0])
		draw_polyline(points, Color(1, 1, 1, 0.25), 2.0, true)
		UiKit.draw_type_icon(self, type_name, c, r * 0.5, Color(1, 1, 1, 0.18))
		return
	var base := GameData.type_color(type_name)
	draw_colored_polygon(points, base.darkened(0.35))
	var inner := PackedVector2Array()
	for p in points:
		inner.append(c + (p - c) * 0.8)
	draw_colored_polygon(inner, base)
	# Shine across the top-left facet.
	draw_colored_polygon(PackedVector2Array([inner[4], inner[5], inner[6], c + (inner[5] - c) * 0.35]), Color(1, 1, 1, 0.35))
	UiKit.draw_type_icon(self, type_name, c, r * 0.5, Color(1, 1, 1, 0.95))
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, Color(1, 0.9, 0.5), 2.5, true)
