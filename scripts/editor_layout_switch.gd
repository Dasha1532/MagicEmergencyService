@tool
extends Node

## Editor-only switch between office hotspot guides and personnel layout guides.
## Runtime visibility is restored explicitly by office_dashboard.gd.

@export_enum("Офисные зоны", "Кадровый экран") var edit_mode: int = 1:
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
	_set_visible(scene_root, "HotspotEditorPreview", office_mode)
	_set_visible(scene_root, "ObjectHotspots", office_mode)
	_set_visible(scene_root, "BookHotspots", office_mode)
	_set_visible(scene_root, "PersonnelEditorPreview", not office_mode)


func _set_visible(scene_root: Node, node_name: String, value: bool) -> void:
	var target := scene_root.get_node_or_null(node_name) as CanvasItem
	if target != null:
		target.visible = value
