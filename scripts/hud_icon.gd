extends Control

@export_enum("Монеты", "Репутация") var kind: int = 0:
	set(value):
		kind = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	if kind == 0:
		_draw_coin()
	else:
		_draw_star()


func _draw_coin() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.43
	draw_circle(center + Vector2(1.5, 2.0), radius, Color(0.08, 0.045, 0.015, 0.85), true, -1.0, true)
	draw_circle(center, radius, Color(0.86, 0.57, 0.16), true, -1.0, true)
	draw_circle(center, radius * 0.78, Color(0.96, 0.72, 0.28), true, -1.0, true)
	draw_arc(center, radius * 0.66, 0.0, TAU, 32, Color(0.55, 0.31, 0.08), 1.6, true)
	var rune_color := Color(0.48, 0.26, 0.06)
	draw_line(center + Vector2(0, -radius * 0.48), center + Vector2(0, radius * 0.48), rune_color, 2.2, true)
	draw_line(center + Vector2(-radius * 0.27, -radius * 0.22), center + Vector2(radius * 0.25, -radius * 0.22), rune_color, 2.2, true)
	draw_line(center + Vector2(-radius * 0.25, radius * 0.22), center + Vector2(radius * 0.27, radius * 0.22), rune_color, 2.2, true)


func _draw_star() -> void:
	var center := size * 0.5
	var outer_radius := minf(size.x, size.y) * 0.45
	var inner_radius := outer_radius * 0.44
	var points := PackedVector2Array()
	for index in range(10):
		var radius := outer_radius if index % 2 == 0 else inner_radius
		var angle := -PI * 0.5 + index * PI / 5.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, Color(0.94, 0.69, 0.25))
	points.append(points[0])
	draw_polyline(points, Color(1.0, 0.88, 0.52), 1.5, true)
