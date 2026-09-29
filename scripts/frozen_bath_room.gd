extends Node2D

const FrozenBathSimulationScript := preload("res://scripts/frozen_bath_simulation.gd")
const EmployeeReactionResolverScript := preload("res://scripts/employee_reaction_resolver.gd")
const FAUCET_ACTIONS := ["diagnose", "repair", "antimagic", "freeze", "heat"]
const BATH_ACTIONS := ["diagnose", "physical_move", "heat", "freeze", "telekinesis", "animate"]

@onready var frozen_bath: TextureRect = $FrozenBath
@onready var broken_bath: TextureRect = $BrokenBath
@onready var broken_empty_bath: TextureRect = $BrokenEmptyBath
@onready var frozen_faucet: TextureRect = $Faucet/Frozen
@onready var faucet_frost: TextureRect = $Faucet/FrostOverlay
@onready var normal_faucet: TextureRect = $Faucet/Normal
@onready var regulated_faucet: TextureRect = $Faucet/Regulated
@onready var bath_interaction_button: Button = $BathInteractionButton
@onready var faucet_interaction_button: Button = $FaucetInteractionButton
@onready var bath_target: Marker2D = $BathTarget
@onready var faucet_target: Marker2D = $FaucetTarget
@onready var employee_actor: Control = $EmployeeActor
@onready var physical_approach: Marker2D = $PhysicalApproach
@onready var tool_bar: Control = $Interface/ToolBar
@onready var repair_hud: Control = $Interface/RepairHUD
@onready var game_state: Node = get_node("/root/GameState")

var simulation: RefCounted
var selected_employee_id: StringName = &""
var action_in_progress := false
var pending_action_id: StringName = &""
var selected_target: StringName = &"faucet"


func _ready() -> void:
	if game_state.active_job_id != &"frozen_bath":
		get_tree().change_scene_to_file("res://scenes/main.tscn")
		return
	simulation = FrozenBathSimulationScript.new()
	var saved_state: Dictionary = game_state.get_job_repair_state(game_state.active_job_id)
	if not saved_state.is_empty():
		simulation.load_state(saved_state)
	bath_interaction_button.pressed.connect(_on_bath_selected)
	faucet_interaction_button.pressed.connect(_on_faucet_selected)
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


func _on_bath_selected() -> void:
	selected_target = &"bath"
	_open_target_actions()


func _on_faucet_selected() -> void:
	selected_target = &"faucet"
	_open_target_actions()


func _open_target_actions() -> void:
	if action_in_progress:
		return
	if simulation.is_fully_resolved():
		repair_hud.show_system_message("Температура воды уже стабилизирована.", false)
		return
	if selected_employee_id.is_empty():
		repair_hud.show_system_message("Сначала выберите сотрудника из бригады.", true)
		return
	var employee: Dictionary = game_state.employees[selected_employee_id]
	var instant_result := _instant_target_result(selected_employee_id, selected_target)
	if not instant_result.is_empty():
		tool_bar.visible = false
		if not repair_hud.show_employee_reaction(selected_employee_id, instant_result):
			repair_hud.show_system_message(instant_result, false)
		return
	tool_bar.configure_for_employee(str(employee["name"]), employee["abilities"], str(employee["core_actions"]))
	if not _employee_has_action_for_target(employee["abilities"], selected_target):
		tool_bar.visible = false
		var refusal := _target_refusal_for_employee(selected_employee_id, selected_target)
		if not repair_hud.show_employee_reaction(selected_employee_id, refusal):
			repair_hud.show_system_message(refusal, false)
		return
	var hidden_actions := _hidden_actions_for_target(selected_target)
	if selected_employee_id == &"boris" and not game_state.has_supply_item(&"thermal_regulator"):
		hidden_actions.append("repair")
	if selected_target == &"faucet":
		tool_bar.show_for_object("Кран", faucet_target.global_position, {
			&"diagnose": "Осмотреть кран",
			&"repair": "Установить терморегулятор воды — 3 мин.",
			&"antimagic": "Снять холодный след",
			&"freeze": "Усилить заморозку",
			&"heat": "Снять след огнём",
		}, [], hidden_actions)
	else:
		tool_bar.show_for_object("Ванна со льдом", bath_target.global_position, {
			&"diagnose": "Осмотреть ванну",
			&"physical_move": "Расколоть лёд",
			&"heat": "Растопить лёд",
			&"freeze": "Усилить заморозку",
			&"telekinesis": "Убрать лёд",
			&"animate": "Оживить ванну",
		}, [], hidden_actions)


func _instant_target_result(employee_id: StringName, target_id: StringName) -> String:
	if employee_id == &"boris" and target_id == &"bath":
		return FrozenBathSimulationScript.BORIS_BATH_DIAGNOSIS
	if employee_id == &"boris" and target_id == &"faucet" and simulation != null and bool(simulation.world_object.get("faucet_diagnosed", false)):
		return simulation.get_employee_reaction(employee_id, &"diagnose", target_id)
	return ""


func _hidden_actions_for_target(target_id: StringName) -> PackedStringArray:
	if target_id == &"faucet":
		return PackedStringArray(["physical_move", "telekinesis", "animate"])
	return PackedStringArray(["repair", "antimagic"])


func _employee_has_action_for_target(ability_ids: PackedStringArray, target_id: StringName) -> bool:
	var supported_actions := FAUCET_ACTIONS if target_id == &"faucet" else BATH_ACTIONS
	for ability_id: String in ability_ids:
		if supported_actions.has(ability_id):
			return true
	return false


func _target_refusal_for_employee(employee_id: StringName, target_id: StringName) -> String:
	if employee_id == &"grog" and target_id == &"faucet":
		return "Лёд я расколю. Кран тоже могу расколоть, но заявка от этого короче не станет."
	if employee_id == &"nika" and target_id == &"faucet":
		return "Кран закреплён, телекинезом двигать его не стану. Лёд нужно убирать из ванны."
	if employee_id == &"felix" and target_id == &"bath":
		return "В самой ванне нет чар, которые нужно подавлять. Холодный след находится на кране."
	return "У меня нет подходящего действия для этой части ванной."


func _on_tool_selected(action_id: StringName) -> void:
	if action_in_progress:
		return
	if repair_hud.is_timed_action_active():
		repair_hud.show_system_message("Сначала дождитесь завершения текущей работы.", true)
		return
	if not game_state.can_employee_work_on_job(selected_employee_id, game_state.active_job_id):
		repair_hud.show_system_message(tr("Сотрудник ещё едет на объект. %s.") % tr(str(game_state.employees[selected_employee_id]["status"])), true)
		return
	tool_bar.visible = false
	var employee: Dictionary = game_state.employees.get(selected_employee_id, {})
	var contextual_reaction: String = simulation.get_employee_reaction(selected_employee_id, action_id, selected_target)
	if _action_already_completed(action_id):
		if action_id == &"heat":
			contextual_reaction = "Здесь уже достаточно тепло. Повторный огонь ничего не исправит."
		if not repair_hud.show_employee_reaction(selected_employee_id, contextual_reaction):
			repair_hud.show_system_message(contextual_reaction, false)
		return
	var reaction: String = EmployeeReactionResolverScript.reaction_for(employee, action_id, simulation.world_object, &"", contextual_reaction, true)
	if action_id != &"diagnose" and not reaction.is_empty() and repair_hud.show_employee_reaction(selected_employee_id, reaction):
		pending_action_id = action_id
		return
	_begin_action(action_id)


func _on_pre_action_dialogue_finished() -> void:
	if pending_action_id.is_empty():
		return
	var action_id := pending_action_id
	pending_action_id = &""
	_begin_action(action_id)


func _begin_action(action_id: StringName) -> void:
	if _action_already_completed(action_id):
		return
	action_in_progress = true
	bath_interaction_button.disabled = true
	faucet_interaction_button.disabled = true
	var is_physical: bool = game_state.employees[selected_employee_id].get("actor_action_style", &"magic") == &"physical"
	var is_equipment: bool = action_id == &"repair" and selected_employee_id == &"boris" and game_state.has_supply_item(&"thermal_regulator")
	if is_physical or is_equipment:
		repair_hud.start_timed_action(selected_employee_id, action_id, _resolve_action.bind(action_id), 3 if is_equipment else -1)
	var action_target := faucet_target.global_position if selected_target == &"faucet" else bath_target.global_position
	employee_actor.play_action(action_id, action_target, physical_approach.position if is_physical else Vector2.INF)


func _on_action_impact(action_id: StringName) -> void:
	if game_state.employees[selected_employee_id].get("actor_action_style", &"magic") == &"magic":
		_resolve_action(action_id)


func _resolve_action(action_id: StringName) -> void:
	var result: Dictionary = simulation.apply_action(selected_employee_id, action_id, game_state.has_supply_item(&"thermal_regulator"), selected_target)
	if bool(result.get("applied", false)) and action_id == &"physical_move":
		_play_audio_cue(&"play_heavy_impact")
		_play_audio_cue(&"play_glass_debris")
	_save_state()
	_apply_visual_state()
	var message := str(result["message"])
	if action_id == &"diagnose":
		var employee: Dictionary = game_state.employees.get(selected_employee_id, {})
		var contextual_reaction: String = simulation.get_employee_reaction(selected_employee_id, action_id, selected_target)
		var diagnosis_reaction: String = EmployeeReactionResolverScript.reaction_for(employee, action_id, simulation.world_object, &"", contextual_reaction, true)
		var showed_reaction: bool = false
		if not diagnosis_reaction.is_empty():
			showed_reaction = bool(repair_hud.show_employee_reaction(selected_employee_id, diagnosis_reaction))
		if not showed_reaction and not message.is_empty():
			repair_hud.show_system_message(message, bool(result["warning"]))
	elif not message.is_empty():
		repair_hud.show_system_message(message, bool(result["warning"]))
	if action_id == &"install_regulator" or action_id == &"repair":
		action_in_progress = false
		_set_interaction_enabled(not simulation.is_fully_resolved())


func _play_audio_cue(method: StringName) -> void:
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager != null and audio_manager.has_method(method):
		audio_manager.call(method)


func _on_action_finished() -> void:
	action_in_progress = false
	_set_interaction_enabled(not simulation.is_fully_resolved())


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
	_set_interaction_enabled(not simulation.is_fully_resolved() and not action_in_progress)
	repair_hud.set_completion_ready(resolved)


func _set_interaction_enabled(enabled: bool) -> void:
	bath_interaction_button.disabled = not enabled
	faucet_interaction_button.disabled = not enabled


func _action_already_completed(action_id: StringName) -> bool:
	if action_id == &"antimagic":
		return bool(simulation.world_object["cold_trace_removed"])
	if action_id == &"telekinesis":
		return bool(simulation.world_object["ice_removed"])
	if action_id == &"heat":
		return bool(simulation.world_object["cold_trace_removed"]) if selected_target == &"faucet" else bool(simulation.world_object["ice_removed"])
	return false


func _resume_pending_action() -> void:
	var pending: Dictionary = game_state.get_pending_job_action(game_state.active_job_id)
	if pending.is_empty():
		return
	selected_employee_id = StringName(str(pending.get("employee_id", "")))
	var action_id := StringName(str(pending.get("action_id", "")))
	selected_target = &"bath" if action_id == &"physical_move" else &"faucet"
	_configure_employee_actor()
	repair_hud.resume_timed_action(_resolve_action.bind(action_id))


func _save_state() -> void:
	game_state.set_job_repair_state(game_state.active_job_id, simulation.get_state())


func _attempt_complete_job() -> void:
	if not simulation.is_resolved():
		repair_hud.show_system_message("Работу нельзя завершить: вода всё ещё замерзает.", true)
		return
	if game_state.complete_active_job(simulation.get_completion_result()):
		get_tree().change_scene_to_file("res://scenes/main.tscn")
