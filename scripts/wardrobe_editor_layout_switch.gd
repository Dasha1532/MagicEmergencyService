@tool
extends Node

## Показывает в редакторе либо общий дом, либо крупную комнату.
## В режиме обзора узлы RoomPreviewBackdrop, RoomPreview, RoomHotspot и
## ProblemRoomMarker можно выделять и двигать мышью как обычные Control.
## В режиме комнаты так же можно двигать Wardrobe и EmployeeActor.

@export_enum("Обзор дома", "Комната крупно") var edit_mode: int = 0:
	set(value):
		edit_mode = value
		if Engine.is_editor_hint() and is_inside_tree():
			call_deferred("_apply_editor_mode")

@export var show_action_origin_setup: bool = true:
	set(value):
		show_action_origin_setup = value
		if Engine.is_editor_hint() and is_inside_tree():
			call_deferred("_apply_editor_mode")

func _ready() -> void:
	if Engine.is_editor_hint():
		call_deferred("_apply_editor_mode")


func _apply_editor_mode() -> void:
	if not Engine.is_editor_hint():
		return
	var scene_root: Node = get_parent()
	if scene_root == null:
		return
	var overview_mode: bool = edit_mode == 0
	_set_visible(scene_root, "Background", overview_mode)
	_set_visible(scene_root, "RoomPreviewBackdrop", overview_mode)
	_set_visible(scene_root, "RoomPreview", overview_mode)
	_set_visible(scene_root, "RoomHotspot", overview_mode)
	_set_visible(scene_root, "ProblemRoomMarker", overview_mode)
	_set_visible(scene_root, "RoomCloseup", not overview_mode)
	_set_visible(scene_root, "Wardrobe", not overview_mode)
	_set_visible(scene_root, "EmployeeActor", not overview_mode)
	_set_visible(scene_root, "CrewPlacementGuide", not overview_mode)
	_set_visible(scene_root, "WardrobePositions/LeftWall/PlacementGuide", not overview_mode)
	_set_visible(scene_root, "WardrobePositions/CenterWall/PlacementGuide", not overview_mode)
	var show_work_pose: bool = not overview_mode and show_action_origin_setup
	_set_visible(scene_root, "EmployeeActor/NeutralPose", not show_work_pose)
	_set_visible(scene_root, "EmployeeActor/WorkPose", show_work_pose)
	_set_visible(scene_root, "EmployeeActor/ActionOrigin", show_work_pose)
	var work_pose: CanvasItem = scene_root.get_node_or_null("EmployeeActor/WorkPose") as CanvasItem
	if work_pose != null:
		work_pose.modulate = Color.WHITE if show_work_pose else Color(1, 1, 1, 0)


func _set_visible(scene_root: Node, node_path: String, value: bool) -> void:
	var target: CanvasItem = scene_root.get_node_or_null(node_path) as CanvasItem
	if target != null:
		target.visible = value
