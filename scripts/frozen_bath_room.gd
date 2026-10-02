extends Node2D

const FrozenBathSimulationScript := preload("res://scripts/frozen_bath_simulation.gd")
const EmployeeReactionResolverScript := preload("res://scripts/employee_reaction_resolver.gd")
const FlowRules := preload("res://scripts/object_flow_rules.gd")
const ActionRules := preload("res://scripts/object_interaction_rules.gd")
const FAUCET_ACTIONS := ["diagnose", "repair", "antimagic", "freeze", "heat"]
const BATH_ACTIONS := ["diagnose", "physical_move", "heat", "freeze", "telekinesis", "animate"]

@onready var frozen_bath: TextureRect = $FrozenBath
@onready var ice_stream: TextureRect = $IceStream
@onready var water_stream: TextureRect = $WaterStream
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
var ice_motion: Tween
var water_motion: Tween
var waiting_work_action: StringName = &""
var work_timer_finished := false
var work_actor_finished := false


func _ready() -> void:
	if game_state.active_job_id != &"frozen_bath" and str(game_state.jobs.get(game_state.active_job_id, {}).get("simulation_type", "")) != "cold_trace":
		get_tree().change_scene_to_file("res://scenes/main.tscn")
		return
	simulation = FrozenBathSimulationScript.new()
	simulation.initialize_from_job(game_state.jobs[game_state.active_job_id])
	var saved_state: Dictionary = game_state.get_job_repair_state(game_state.active_job_id)
	if not saved_state.is_empty():
		simulation.load_state(saved_state)
	simulation.advance_flow_until(game_state.time_minutes)
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
	_start_ice_motion()
	_resume_pending_action()
	if not bool(simulation.world_object.get("resident_intro_seen", false)):
		simulation.world_object["resident_intro_seen"] = true
		_save_state()
		if not repair_hud.enable_access_dialogues():
			repair_hud.show_resident_dialogue(game_state.get_resident_greeting(game_state.active_job_id, simulation.get_resident_request()))


func _process(_delta: float) -> void:
	if simulation == null:
		return
	if simulation.advance_flow_until(game_state.time_minutes):
		_save_state()
		_apply_visual_state()


func _start_ice_motion() -> void:
	ice_motion = _start_stream_motion(ice_stream)
	water_motion = _start_stream_motion(water_stream)


func _start_stream_motion(stream: TextureRect) -> Tween:
	var base_position := stream.position
	var motion := create_tween().set_loops()
	motion.tween_property(stream, "position", base_position + Vector2(0, 3), 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	motion.parallel().tween_property(stream, "modulate", Color(0.86, 0.95, 1.0, 0.9), 0.55)
	motion.tween_property(stream, "position", base_position, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	motion.parallel().tween_property(stream, "modulate", Color.WHITE, 0.55)
	if not stream.visible:
		motion.pause()
	return motion


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
	if simulation.is_fully_resolved() and selected_target != &"faucet":
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
	if not _employee_has_action_for_target(employee["abilities"], selected_target) and not (selected_target == &"faucet" and not ActionRules.contextual_actions(simulation.world_object, employee).is_empty()):
		tool_bar.visible = false
		var refusal := _target_refusal_for_employee(selected_employee_id, selected_target)
		if not repair_hud.show_employee_reaction(selected_employee_id, refusal):
			repair_hud.show_system_message(refusal, false)
		return
	var hidden_actions := _hidden_actions_for_target(selected_target)
	if selected_employee_id == &"boris" and not game_state.has_supply_item(&"thermal_regulator"):
		hidden_actions.append("repair")
	if not ActionRules.is_applicable(&"repair", simulation.world_object):
		hidden_actions.append("repair")
	if selected_target == &"faucet":
		tool_bar.show_for_object("Кран", faucet_target.global_position, {
			&"diagnose": "Осмотреть кран",
			&"repair": "Установить терморегулятор",
			&"antimagic": "Снять холодный след",
			&"freeze": "Усилить заморозку",
			&"heat": "Снять след огнём",
		}, ActionRules.contextual_actions(simulation.world_object, employee), hidden_actions)
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
	if action_id == &"turn_valve" and not ActionRules.valve_preflight_reason(simulation.world_object, game_state.get_employee_with_equipment(selected_employee_id)).is_empty():
		_resolve_action(action_id)
		return
	action_in_progress = true
	bath_interaction_button.disabled = true
	faucet_interaction_button.disabled = true
	var is_physical: bool = game_state.employees[selected_employee_id].get("actor_action_style", &"magic") == &"physical"
	var is_equipment: bool = action_id == &"repair" and selected_employee_id == &"boris" and game_state.has_supply_item(&"thermal_regulator")
	if (is_physical or is_equipment) and not ActionRules.resolves_on_impact(action_id):
		waiting_work_action = action_id
		work_timer_finished = false
		work_actor_finished = false
	var action_target := faucet_target.global_position if selected_target == &"faucet" else bath_target.global_position
	employee_actor.play_action(action_id, action_target, physical_approach.position if is_physical else Vector2.INF)


func _on_action_impact(action_id: StringName) -> void:
	if waiting_work_action == action_id:
		var is_equipment: bool = action_id == &"repair" and selected_employee_id == &"boris" and game_state.has_supply_item(&"thermal_regulator")
		repair_hud.start_timed_action(selected_employee_id, action_id, _on_work_timer_finished, 3 if is_equipment else -1)
		return
	if game_state.employees[selected_employee_id].get("actor_action_style", &"magic") == &"magic" or ActionRules.resolves_on_impact(action_id):
		_resolve_action(action_id)


func _on_work_timer_finished() -> void:
	work_timer_finished = true
	_finish_physical_work()


func _finish_physical_work() -> void:
	if waiting_work_action.is_empty() or not work_timer_finished or not work_actor_finished:
		return
	var completed_action := waiting_work_action
	waiting_work_action = &""
	_resolve_action(completed_action)
	action_in_progress = false
	_set_interaction_enabled(not simulation.is_fully_resolved())


func _resolve_action(action_id: StringName) -> void:
	var result: Dictionary = simulation.apply_action(selected_employee_id, action_id, game_state.has_supply_item(&"thermal_regulator"), selected_target, game_state.get_employee_with_equipment(selected_employee_id))
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
	if not waiting_work_action.is_empty():
		work_actor_finished = true
		_finish_physical_work()
		return
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
	frozen_faucet.visible = bool(simulation.world_object.get("frozen", false))
	faucet_frost.visible = frozen_faucet.visible and bool(simulation.world_object.get("extra_frost", false))
	regulated_faucet.visible = resolved and bool(simulation.world_object.get("regulator_installed", false))
	normal_faucet.visible = not frozen_faucet.visible and not regulated_faucet.visible
	# Геометрия задаётся только сценой, чтобы её можно было править в редакторе.
	ice_stream.visible = FlowRules.is_flowing(simulation.world_object, "ice")
	water_stream.visible = FlowRules.is_flowing(simulation.world_object, "water")
	if water_motion != null:
		if water_stream.visible:
			water_motion.play()
		else:
			water_motion.pause()
	if ice_motion != null:
		if ice_stream.visible:
			ice_motion.play()
		else:
			ice_motion.pause()
	_set_interaction_enabled(not simulation.is_fully_resolved() and not action_in_progress)
	repair_hud.set_completion_ready(resolved)


func _set_interaction_enabled(enabled: bool) -> void:
	bath_interaction_button.disabled = not enabled
	faucet_interaction_button.disabled = action_in_progress


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
