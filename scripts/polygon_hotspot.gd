@tool
extends Control

signal activated

@export var service_mode := false:
	set(value):
		service_mode = value
		_update_highlight()

var hovered := false


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	_update_highlight()


func _has_point(point: Vector2) -> bool:
	var shape := get_node_or_null("Highlight") as Polygon2D
	return shape != null and shape.polygon.size() >= 3 and Geometry2D.is_point_in_polygon(point, _transformed_polygon(shape))


func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		activated.emit()
		accept_event()


func _set_hovered(value: bool) -> void:
	hovered = value
	_update_highlight()


func _update_highlight() -> void:
	var shape := get_node_or_null("Highlight") as Polygon2D
	if shape == null:
		return
	shape.visible = hovered or service_mode or Engine.is_editor_hint()
	shape.color = Color(1.0, 0.72, 0.20, 0.25 if hovered else 0.10)
	queue_redraw()


func _draw() -> void:
	if not hovered and not service_mode and not Engine.is_editor_hint():
		return
	var shape := get_node_or_null("Highlight") as Polygon2D
	if shape == null or shape.polygon.size() < 3:
		return
	var outline := _transformed_polygon(shape)
	outline.append(outline[0])
	draw_polyline(outline, Color(1.0, 0.82, 0.42, 0.98 if hovered else 0.72), 3.0 if hovered else 2.0, true)


func _transformed_polygon(shape: Polygon2D) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point in shape.polygon:
		points.append(shape.transform * point)
	return points
