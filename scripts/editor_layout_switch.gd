@tool
extends Node

## Editor-only switch between office, personnel and demo completion layouts.
## Runtime visibility is restored explicitly by office_dashboard.gd.

@export_enum("Офис", "Кадровый экран", "Финальная книга") var edit_mode: int = 0:
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
	var office_mode := edit_mode == 0
	var personnel_mode := edit_mode == 1
	var demo_mode := edit_mode == 2
	_set_visible(scene_root, "HotspotEditorPreview", office_mode)
	_set_visible(scene_root, "ObjectHotspots", office_mode)
	_set_visible(scene_root, "BookHotspots", office_mode)
	_set_visible(scene_root, "CupSteam", office_mode)
	_set_visible(scene_root, "OfficeCat", office_mode)
	_set_visible(scene_root, "PersonnelEditorPreview", personnel_mode)
	_set_visible(scene_root, "DemoCompletionLayer", demo_mode)


func _set_visible(scene_root: Node, node_name: String, value: bool) -> void:
	var target := scene_root.get_node_or_null(node_name) as CanvasItem
	if target != null:
		target.visible = value
