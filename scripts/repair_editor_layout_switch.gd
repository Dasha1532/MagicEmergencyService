@tool
extends Node

## Editor-only switch between the house overview and the close-up bathroom.
## Runtime visibility is restored by repair_house.gd.

@export_enum("Обзор дома", "Ванная крупно") var edit_mode: int = 0:
	set(value):
		edit_mode = value
		if Engine.is_editor_hint() and is_inside_tree():
			call_deferred("_apply_editor_mode")


func _ready() -> void:
	if Engine.is_editor_hint():
		call_deferred("_apply_editor_mode")


func _apply_editor_mode() -> void:
	if not Engine.is_editor_hint():
		return
	var scene_root := get_parent()
	if scene_root == null:
		return
	var overview_mode := edit_mode == 0
	_set_visible(scene_root, "Background", overview_mode)
	_set_visible(scene_root, "BathroomPreviewBackdrop", overview_mode)
	_set_visible(scene_root, "BathroomPreview", overview_mode)
	_set_visible(scene_root, "BathroomHotspot", overview_mode)
	_set_visible(scene_root, "ProblemRoomMarker", overview_mode)
	_set_visible(scene_root, "BathroomCloseup", not overview_mode)
	_set_visible(scene_root, "InteractiveObjects/LavaFaucet", not overview_mode)


func _set_visible(scene_root: Node, node_path: String, value: bool) -> void:
	var target := scene_root.get_node_or_null(node_path) as CanvasItem
	if target != null:
		target.visible = value
