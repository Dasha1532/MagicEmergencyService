extends Node2D

const FrozenBathSimulationScript := preload("res://scripts/frozen_bath_simulation.gd")
const EmployeeReactionResolverScript := preload("res://scripts/employee_reaction_resolver.gd")

@onready var frozen_bath: TextureRect = $FrozenBath
@onready var broken_bath: TextureRect = $BrokenBath
@onready var broken_empty_bath: TextureRect = $BrokenEmptyBath
@onready var frozen_faucet: TextureRect = $Faucet/Frozen
@onready var faucet_frost: TextureRect = $Faucet/FrostOverlay
@onready var normal_faucet: TextureRect = $Faucet/Normal
@onready var regulated_faucet: TextureRect = $Faucet/Regulated
@onready var interaction_button: Button = $InteractionButton
@onready var target: Marker2D = $Target
@onready var employee_actor: Control = $EmployeeActor
@onready var physical_approach: Marker2D = $PhysicalApproach
@onready var tool_bar: Control = $Interface/ToolBar
@onready var repair_hud: Control = $Interface/RepairHUD
@onready var game_state: Node = get_node("/root/GameState")

var simulation: RefCounted
var selected_employee_id: StringName = &""
var action_in_progress := false
var pending_action_id: StringName = &""


func _ready() -> void:
	if game_state.active_job_id != &"frozen_bath":
		get_tree().change_scene_to_file("res://scenes/main.tscn")
		return
	simulation = FrozenBathSimulationScript.new()
	var saved_state: Dictionary = game_state.get_job_repair_state(game_state.active_job_id)
	if not saved_state.is_empty():
		simulation.load_state(saved_state)
	interaction_button.pressed.connect(_on_problem_selected)
	tool_bar.tool_selected.connect(_on_tool_selected)
	repair_hud.employee_selected.connect(_on_employee_selected)
	repair_hud.completion_requested.connect(_attempt_complete_job)
	repair_hud.long_action_started.connect(_on_long_action_started)
	repair_hud.long_action_finished.connect(_on_long_action_finished)
	repair_hud.dialogue_finished.connect(_on_pre_action_dialogue_finished)
	employee_actor.action_impact.connect(_on_action_impact)
	employee_actor.action_finished.connect(_on_action_finished)
	selected_employee_id = repair_hud.get_selected_employee_id()
	_configure_employee_actor()
	_apply_visual_state()
	_resume_pending_action()
	if not bool(simulation.world_object.get("resident_intro_seen", false)):
		simulation.world_object["resident_intro_seen"] = true
		_save_state()
		repair_hud.show_resident_dialogue(simulation.get_resident_request())


func _on_long_action_started(employee_id: StringName) -> void:
	if employee_id == selected_employee_id and employee_actor.visible:
		employee_actor.call("set_persistent_work_pose", true)


func _on_long_action_finished(employee_id: StringName) -> void:
	if employee_id == selected_employee_id:
		employee_actor.call("set_persistent_work_pose", false)


func _on_employee_selected(employee_id: StringName) -> void:
	selected_employee_id = employee_id
	tool_bar.visible = false
	_configure_employee_actor()


func _configure_employee_actor() -> void:
	if selected_employee_id.is_empty() or not game_state.employees.has(selected_employee_id):
		employee_actor.visible = false
		return
	employee_actor.visible = employee_actor.configure_employee(selected_employee_id, game_state.employees[selected_employee_id])
	if employee_actor.visible and employee_actor.has_method("set_horizontal_flip"):
		employee_actor.call("set_horizontal_flip", false)


func _on_problem_selected() -> void:
	if action_in_progress:
		return
	if simulation.is_fully_resolved():
		repair_hud.show_system_message("Температура воды уже стабилизирована.", false)
		return
	if selected_employee_id.is_empty():
		repair_hud.show_system_message("Сначала выберите сотрудника из бригады.", true)
		return
	var employee: Dictionary = game_state.employees[selected_employee_id]
	tool_bar.configure_for_employee(str(employee["name"]), employee["abilities"], str(employee["core_actions"]))
	var repair_label := "Осмотреть соединения крана"
	if selected_employee_id == &"boris" and game_state.has_supply_item(&"thermal_regulator"):
		repair_label = "Установить терморегулятор воды • 3 мин."
	tool_bar.show_for_object("Замёрзшая ванна", target.global_position, {
		&"diagnose": "Осмотреть кран и лёд",
		&"repair": repair_label,
		&"physical_move": "Расколоть лёд",
		&"heat": "Растопить лёд",
		&"antimagic": "Снять холодный след",
		&"freeze": "Усилить заморозку",
		&"telekinesis": "Убрать осколки",
		&"animate": "Оживить ванну",
	}, [])


func _on_tool_selected(action_id: StringName) -> void:
	if action_in_progress:
		return
	if repair_hud.is_timed_action_active():
		repair_hud.show_system_message("Сначала дождитесь завершения текущей работы.", true)
		return
	if not game_state.can_employee_work_on_job(selected_employee_id, game_state.active_job_id):
		repair_hud.show_system_message("Сотрудник ещё едет на объект. %s." % game_state.employees[selected_employee_id]["status"], true)
		return
	tool_bar.visible = false
	var employee: Dictionary = game_state.employees.get(selected_employee_id, {})
	var contextual_reaction: String = simulation.get_employee_reaction(selected_employee_id, action_id)
	var reaction: String = EmployeeReactionResolverScript.reaction_for(employee, action_id, simulation.world_object, &"", contextual_reaction, true)
	if selected_employee_id == &"boris" and action_id == &"repair" and not game_state.has_supply_item(&"thermal_regulator"):
		reaction = "Проверю соединения. Если трубы целы, придётся ставить терморегулятор — голыми руками температуру не прикрутишь."
	if action_id != &"diagnose" and not reaction.is_empty():
		pending_action_id = action_id
		repair_hud.show_employee_reaction(selected_employee_id, reaction)
		return
	_begin_action(action_id)


func _on_pre_action_dialogue_finished() -> void:
	if pending_action_id.is_empty():
		return
	var action_id := pending_action_id
	pending_action_id = &""
	_begin_action(action_id)


func _begin_action(action_id: StringName) -> void:
	action_in_progress = true
	interaction_button.disabled = true
	var is_physical: bool = game_state.employees[selected_employee_id].get("actor_action_style", &"magic") == &"physical"
	var is_equipment: bool = action_id == &"repair" and selected_employee_id == &"boris" and game_state.has_supply_item(&"thermal_regulator")
	if is_physical or is_equipment:
		repair_hud.start_timed_action(selected_employee_id, action_id, _resolve_action.bind(action_id), 3 if is_equipment else -1)
	employee_actor.play_action(action_id, target.global_position, physical_approach.position if is_physical else Vector2.INF)


func _on_action_impact(action_id: StringName) -> void:
	if game_state.employees[selected_employee_id].get("actor_action_style", &"magic") == &"magic":
		_resolve_action(action_id)


func _resolve_action(action_id: StringName) -> void:
	var result: Dictionary = simulation.apply_action(selected_employee_id, action_id, game_state.has_supply_item(&"thermal_regulator"))
	_save_state()
	_apply_visual_state()
	var message := str(result["message"])
	if not message.is_empty():
		repair_hud.show_system_message(message, bool(result["warning"]))
	elif action_id == &"diagnose":
		var employee: Dictionary = game_state.employees.get(selected_employee_id, {})
		var contextual_reaction: String = simulation.get_employee_reaction(selected_employee_id, action_id)
		var diagnosis_reaction: String = EmployeeReactionResolverScript.reaction_for(employee, action_id, simulation.world_object, &"", contextual_reaction, true)
		if not diagnosis_reaction.is_empty():
			repair_hud.show_employee_reaction(selected_employee_id, diagnosis_reaction)
	if action_id == &"install_regulator" or action_id == &"repair":
		action_in_progress = false
		interaction_button.disabled = simulation.is_fully_resolved()


func _on_action_finished() -> void:
	action_in_progress = false
	interaction_button.disabled = simulation.is_fully_resolved()


func _apply_visual_state() -> void:
	var resolved: bool = simulation.is_resolved()
	var damaged: bool = bool(simulation.world_object.get("bath_damaged", false))
	var bath_still_frozen: bool = bool(simulation.world_object.get("bath_still_frozen", false))
	var ice_removed: bool = bool(simulation.world_object.get("ice_removed", false))
	frozen_bath.visible = not damaged and not ice_removed and ((not resolved) or bath_still_frozen)
	broken_bath.visible = damaged and not ice_removed
	broken_empty_bath.visible = damaged and ice_removed
	frozen_faucet.visible = not resolved and not bool(simulation.world_object.get("cold_trace_removed", false))
	faucet_frost.visible = frozen_faucet.visible and bool(simulation.world_object.get("extra_frost", false))
	regulated_faucet.visible = resolved and bool(simulation.world_object.get("regulator_installed", false))
	normal_faucet.visible = resolved and not regulated_faucet.visible
	interaction_button.disabled = simulation.is_fully_resolved() or action_in_progress
	repair_hud.set_completion_ready(resolved)


func _resume_pending_action() -> void:
	var pending: Dictionary = game_state.get_pending_job_action(game_state.active_job_id)
	if pending.is_empty():
		return
	selected_employee_id = StringName(str(pending.get("employee_id", "")))
	_configure_employee_actor()
	repair_hud.resume_timed_action(_resolve_action.bind(StringName(str(pending.get("action_id", "")))))


func _save_state() -> void:
	game_state.set_job_repair_state(game_state.active_job_id, simulation.get_state())


func _attempt_complete_job() -> void:
	if not simulation.is_resolved():
		repair_hud.show_system_message("Работу нельзя завершить: вода всё ещё замерзает.", true)
		return
	if game_state.complete_active_job(simulation.get_completion_result()):
		get_tree().change_scene_to_file("res://scenes/main.tscn")
