extends Node

const CURSOR_SIZE := Vector2i(64, 64)
const DEFAULT_CURSOR := preload("res://assets/ui/cursors/default.png")
const INTERACT_CURSOR := preload("res://assets/ui/cursors/interact.png")
const FORBIDDEN_CURSOR := preload("res://assets/ui/cursors/forbidden.png")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_set_cursor_image(DEFAULT_CURSOR, Input.CURSOR_ARROW, Vector2(12, 6))
	_set_cursor_image(INTERACT_CURSOR, Input.CURSOR_POINTING_HAND, Vector2(23, 25))
	_set_cursor_image(FORBIDDEN_CURSOR, Input.CURSOR_FORBIDDEN, Vector2(12, 6))
	get_tree().node_added.connect(_on_node_added)
	_connect_controls_in(get_tree().root)


func _set_cursor_image(source: Texture2D, shape: Input.CursorShape, hotspot: Vector2) -> void:
	var image := source.get_image()
	image.resize(CURSOR_SIZE.x, CURSOR_SIZE.y, Image.INTERPOLATE_LANCZOS)
	Input.set_custom_mouse_cursor(ImageTexture.create_from_image(image), shape, hotspot)


func _on_node_added(node: Node) -> void:
	if node is Control:
		_connect_control_by_id.call_deferred(node.get_instance_id())


func _connect_control_by_id(instance_id: int) -> void:
	var node := instance_from_id(instance_id)
	if node is Node:
		_connect_control(node as Node)


func _connect_controls_in(node: Node) -> void:
	if node is Control:
		_connect_control(node as Control)
	for child in node.get_children():
		_connect_controls_in(child)


func _connect_control(node: Node) -> void:
	if not is_instance_valid(node) or not node is Control:
		return
	var control := node as Control
	if control.has_meta(&"custom_cursor_connected"):
		return
	control.set_meta(&"custom_cursor_connected", true)
	control.mouse_entered.connect(_on_control_mouse_entered.bind(control))
	control.mouse_exited.connect(_on_control_mouse_exited)


func _on_control_mouse_entered(control: Control) -> void:
	if control is BaseButton and (control as BaseButton).disabled:
		Input.set_default_cursor_shape(Input.CURSOR_FORBIDDEN)
	elif control.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND:
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	else:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _on_control_mouse_exited() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
