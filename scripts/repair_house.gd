extends Node2D

const RepairSimulationScript := preload("res://scripts/repair_simulation.gd")

const COLOR_PANEL := Color(0.07, 0.045, 0.03, 0.94)
const COLOR_GOLD := Color(0.96, 0.78, 0.46)
const COLOR_PARCHMENT := Color(0.92, 0.84, 0.69)

@onready var overview_background: TextureRect = $Background
@onready var bathroom_preview_backdrop: ColorRect = $BathroomPreviewBackdrop
@onready var bathroom_preview: TextureRect = $BathroomPreview
@onready var closeup_background: TextureRect = $BathroomCloseup
@onready var bathroom_hotspot: Button = $BathroomHotspot
@onready var problem_room_marker: Panel = $ProblemRoomMarker
@onready var lower_floor_consequence: Panel = $LowerFloorConsequence
@onready var lava_faucet: Control = $InteractiveObjects/LavaFaucet
@onready var employee_actor: Control = $EmployeeActor
@onready var back_to_house_button: Button = $Interface/BackToHouseButton
@onready var tool_bar: Control = $Interface/ToolBar
@onready var repair_hud: Control = $Interface/RepairHUD
@onready var feedback_panel: Panel = $Interface/ActionFeedback
@onready var feedback_label: Label = $Interface/ActionFeedback/Message
@onready var game_state: Node = get_node("/root/GameState")

var simulation: RepairSimulation
var selected_tool_id: StringName = &"freeze"
var selected_employee_id: StringName = &""
var feedback_revision: int = 0
var action_in_progress: bool = false


func _ready() -> void:
	if game_state.active_job_id != &"lava_leak":
		get_tree().change_scene_to_file("res://scenes/main.tscn")
		return
	simulation = RepairSimulationScript.new()
	simulation.load_state(game_state.get_job_repair_state(game_state.active_job_id))
	_configure_buttons()
	bathroom_hotspot.pressed.connect(_open_bathroom)
	back_to_house_button.pressed.connect(_show_house_overview)
	tool_bar.tool_selected.connect(_on_tool_selected)
	repair_hud.employee_selected.connect(_on_employee_selected)
	repair_hud.completion_requested.connect(_attempt_complete_job)
	lava_faucet.selected.connect(_apply_selected_action)
	employee_actor.action_impact.connect(_on_employee_action_impact)
	employee_actor.action_finished.connect(_on_employee_action_finished)
	selected_tool_id = tool_bar.get_selected_tool_id()
	selected_employee_id = repair_hud.get_selected_employee_id()
	_configure_employee_actor()
	_restore_repair_state()
	_show_house_overview(false)


func _open_bathroom() -> void:
	bathroom_hotspot.disabled = true
	bathroom_hotspot.visible = false
	problem_room_marker.visible = false
	lower_floor_consequence.visible = false
	closeup_background.visible = true
	closeup_background.modulate = Color(1, 1, 1, 0)
	closeup_background.scale = Vector2.ONE
	lava_faucet.visible = true
	lava_faucet.self_modulate = Color(1, 1, 1, 0)
	employee_actor.visible = _configure_employee_actor()
	employee_actor.self_modulate = Color(1, 1, 1, 0)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(closeup_background, "modulate", Color.WHITE, 0.24)
	tween.tween_property(lava_faucet, "self_modulate", Color.WHITE, 0.24)
	if employee_actor.visible:
		tween.tween_property(employee_actor, "self_modulate", Color.WHITE, 0.24)
	await tween.finished
	overview_background.visible = false
	bathroom_preview_backdrop.visible = false
	bathroom_preview.visible = false
	back_to_house_button.visible = true
	tool_bar.visible = true
	if repair_hud.has_method("set_work_ui_visible"):
		repair_hud.call("set_work_ui_visible", true)
	feedback_panel.visible = false


func _show_house_overview(animated: bool = true) -> void:
	overview_background.visible = true
	bathroom_preview_backdrop.visible = true
	bathroom_preview.visible = true
	bathroom_hotspot.visible = true
	bathroom_hotspot.disabled = false
	problem_room_marker.visible = not simulation.is_resolved()
	lower_floor_consequence.visible = _has_damage()
	lava_faucet.visible = false
	employee_actor.visible = false
	back_to_house_button.visible = false
	tool_bar.visible = false
	if repair_hud.has_method("set_work_ui_visible"):
		repair_hud.call("set_work_ui_visible", false)
	feedback_panel.visible = false
	if not animated:
		closeup_background.visible = false
		return
	var tween := create_tween()
	tween.tween_property(closeup_background, "modulate", Color(1, 1, 1, 0), 0.24)
	await tween.finished
	closeup_background.visible = false
	closeup_background.modulate = Color.WHITE


func _configure_buttons() -> void:
	var empty_style := StyleBoxEmpty.new()
	bathroom_hotspot.add_theme_stylebox_override("normal", empty_style)
	bathroom_hotspot.add_theme_stylebox_override("pressed", empty_style)
	bathroom_hotspot.add_theme_stylebox_override("focus", empty_style)
	var room_hover := StyleBoxFlat.new()
	room_hover.bg_color = Color(1.0, 0.42, 0.08, 0.08)
	room_hover.border_color = Color(1.0, 0.68, 0.24, 0.88)
	room_hover.set_border_width_all(3)
	room_hover.set_corner_radius_all(12)
	bathroom_hotspot.add_theme_stylebox_override("hover", room_hover)

	back_to_house_button.add_theme_font_size_override("font_size", 17)
	back_to_house_button.add_theme_color_override("font_color", COLOR_PARCHMENT)
	back_to_house_button.add_theme_stylebox_override("normal", _button_style(COLOR_PANEL, Color(0.76, 0.54, 0.27), 2))
	back_to_house_button.add_theme_stylebox_override("hover", _button_style(Color(0.21, 0.14, 0.075, 0.98), COLOR_GOLD, 3))
	feedback_panel.add_theme_stylebox_override("panel", _button_style(COLOR_PANEL, Color(0.76, 0.54, 0.27), 2))
	var problem_style := _button_style(Color(0.15, 0.08, 0.025, 0.08), COLOR_GOLD, 3)
	problem_style.shadow_color = Color(1.0, 0.58, 0.12, 0.24)
	problem_style.shadow_size = 10
	problem_room_marker.add_theme_stylebox_override("panel", problem_style)
	var consequence_style := _button_style(Color(0.18, 0.035, 0.015, 0.12), Color(1.0, 0.32, 0.08, 0.9), 3)
	consequence_style.shadow_color = Color(1.0, 0.18, 0.03, 0.28)
	consequence_style.shadow_size = 12
	lower_floor_consequence.add_theme_stylebox_override("panel", consequence_style)


func _on_tool_selected(tool_id: StringName) -> void:
	selected_tool_id = tool_id


func _on_employee_selected(employee_id: StringName) -> void:
	selected_employee_id = employee_id
	if closeup_background.visible and not overview_background.visible:
		employee_actor.visible = _configure_employee_actor()
		employee_actor.self_modulate = Color.WHITE


func _apply_selected_action() -> void:
	if action_in_progress:
		return
	if selected_employee_id.is_empty():
		_show_feedback("Сначала выберите сотрудника из бригады.", true)
		return
	if selected_tool_id.is_empty():
		_show_feedback("У выбранного сотрудника нет подходящего действия для этого объекта.", true)
		return
	if employee_actor.visible:
		action_in_progress = true
		lava_faucet.set_interaction_enabled(false)
		employee_actor.play_action(selected_tool_id, _faucet_target_global())
		return
	_resolve_action(selected_tool_id)


func _configure_employee_actor() -> bool:
	if selected_employee_id.is_empty() or not game_state.employees.has(selected_employee_id):
		return false
	return employee_actor.configure_employee(selected_employee_id, game_state.employees[selected_employee_id])


func _on_employee_action_impact(action_id: StringName) -> void:
	_resolve_action(action_id)


func _on_employee_action_finished() -> void:
	action_in_progress = false
	lava_faucet.set_interaction_enabled(true)


func _resolve_action(action_id: StringName) -> void:
	var result: Dictionary = simulation.apply_action(selected_employee_id, action_id)
	var visual_state: StringName = result.get("visual_state", &"emergency")
	if visual_state == &"repaired":
		lava_faucet.show_repaired_state()
	elif visual_state == &"overheated":
		lava_faucet.show_overheated_state()
	lava_faucet.set_damage_visible(_has_damage())
	_show_feedback(str(result["message"]), not bool(result["applied"]))
	repair_hud.set_completion_ready(bool(result["resolved"]))
	game_state.set_job_repair_state(game_state.active_job_id, simulation.get_state())


func _faucet_target_global() -> Vector2:
	return lava_faucet.global_position + Vector2(-96, 34)


func _attempt_complete_job() -> void:
	if not simulation.is_resolved():
		_show_feedback("Работу нельзя завершить: лава всё ещё течёт.", true)
		return
	if game_state.complete_active_job(simulation.get_completion_result()):
		get_tree().change_scene_to_file("res://scenes/main.tscn")


func _restore_repair_state() -> void:
	var visual_state: StringName = simulation.world_object.get("visual_state", &"emergency")
	if visual_state == &"repaired":
		lava_faucet.show_repaired_state()
		_show_feedback("Кран исправен. Работу можно завершить.")
	elif visual_state == &"overheated":
		lava_faucet.show_overheated_state()
		_show_feedback("Кран перегрет. Остановите поток лавы перед завершением работы.", true)
	else:
		lava_faucet.show_emergency_state()
		_show_feedback("Выберите действие сотрудника и примените его к аварийному крану.")
	lava_faucet.set_damage_visible(_has_damage())
	repair_hud.set_completion_ready(simulation.is_resolved())


func _has_damage() -> bool:
	return int(simulation.world_object.get("damage", 0)) > 0


func _show_feedback(message: String, is_warning: bool = false) -> void:
	feedback_revision += 1
	var shown_revision := feedback_revision
	feedback_label.text = message
	feedback_label.add_theme_color_override("font_color", Color(1.0, 0.58, 0.35) if is_warning else COLOR_PARCHMENT)
	feedback_panel.visible = true
	await get_tree().create_timer(3.2).timeout
	if shown_revision == feedback_revision:
		feedback_panel.visible = false


func _button_style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(8)
	return style
