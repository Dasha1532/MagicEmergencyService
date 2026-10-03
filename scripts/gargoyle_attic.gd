extends Node2D

const GargoyleSimulationScript := preload("res://scripts/gargoyle_simulation.gd")
const EmployeeReactionResolverScript := preload("res://scripts/employee_reaction_resolver.gd")

@onready var gargoyle: Control = $GargoylePlacement
@onready var flooding: TextureRect = $Flooding
@onready var frozen_flooding: TextureRect = $FrozenFlooding
@onready var employee_actor: Control = $EmployeeActor
@onready var physical_approach: Marker2D = $PhysicalApproach
@onready var tool_bar: Control = $Interface/ToolBar
@onready var repair_hud: Control = $Interface/RepairHUD
@onready var game_state: Node = get_node("/root/GameState")

var simulation: GargoyleSimulation
var selected_employee_id: StringName = &""
var action_in_progress: bool = false
var pending_dialogue_action: StringName = &""
var action_had_intro: bool = false
var physical_action: StringName = &""
var physical_timer_finished := false
var physical_actor_finished := false


func _ready() -> void:
	if game_state.active_job_id.is_empty() or game_state.get_job_repair_scene(game_state.active_job_id) != "res://scenes/GargoyleAttic.tscn":
		get_tree().change_scene_to_file("res://scenes/main.tscn")
		return
	simulation = GargoyleSimulationScript.new()
	simulation.initialize_from_job(game_state.jobs[game_state.active_job_id])
	var saved_state: Dictionary = game_state.get_job_repair_state(game_state.active_job_id)
	if not saved_state.is_empty():
		simulation.load_state(saved_state)
	repair_hud.employee_selected.connect(_on_employee_selected)
	repair_hud.completion_requested.connect(_attempt_complete_job)
	repair_hud.long_action_started.connect(_on_long_action_started)
	repair_hud.long_action_finished.connect(_on_long_action_finished)
	repair_hud.dialogue_finished.connect(_on_pre_action_dialogue_finished)
	gargoyle.selected.connect(_on_gargoyle_selected)
	tool_bar.tool_selected.connect(_on_tool_selected)
	employee_actor.action_impact.connect(_on_action_impact)
	employee_actor.action_finished.connect(_on_action_finished)
	selected_employee_id = repair_hud.get_selected_employee_id()
	_configure_employee_actor()
	_apply_visual_state()
	_resume_pending_action()
	if not bool(simulation.world_object.get("resident_intro_seen", false)):
		simulation.world_object["resident_intro_seen"] = true
		game_state.set_job_repair_state(game_state.active_job_id, simulation.get_state())
		repair_hud.show_resident_dialogue(game_state.get_resident_greeting(game_state.active_job_id, simulation.get_resident_request()))
	_set_audio_loop(&"set_rain_playing", true)


func _exit_tree() -> void:
	_set_audio_loop(&"set_rain_playing", false)
	_set_audio_loop(&"set_running_water_playing", false)


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


func _configure_employee_actor() -> bool:
	if selected_employee_id.is_empty() or not game_state.employees.has(selected_employee_id):
		employee_actor.visible = false
		return false
	employee_actor.visible = employee_actor.configure_employee(selected_employee_id, game_state.employees[selected_employee_id])
	if employee_actor.visible and employee_actor.has_method("set_horizontal_flip"):
		employee_actor.call("set_horizontal_flip", true)
	return employee_actor.visible


func _on_gargoyle_selected() -> void:
	if action_in_progress:
		return
	if selected_employee_id.is_empty():
		repair_hud.show_system_message("Сначала выберите сотрудника из бригады.", true)
		return
	var employee: Dictionary = game_state.employees[selected_employee_id]
	var hidden := PackedStringArray()
	var contextual_actions: Array = []
	if selected_employee_id != &"boris":
		var has_work := false
		for ability: String in employee["abilities"]:
			if ability != "diagnose" and simulation.available_actions().has(ability):
				has_work = true
		if not has_work:
			contextual_actions.append({"id": &"diagnose", "label": "Осмотр"})
	for action: String in ["diagnose", "repair", "physical_move", "telekinesis", "animate", "antimagic", "freeze", "heat"]:
		if not simulation.available_actions().has(action):
			hidden.append(action)
	tool_bar.configure_for_employee(str(employee["name"]), employee["abilities"], str(employee["core_actions"]))
	tool_bar.show_for_object("Водосточная горгулья", gargoyle.target_global_position(), {
		&"diagnose": "Осмотреть водосток",
		&"repair": "Открыть обходной канал",
		&"physical_move": "Выбить засор силой" if bool(simulation.world_object["clogged"]) else "Проломить водосток",
		&"telekinesis": "Вытащить листья",
		&"animate": "Разбудить горгулью",
		&"antimagic": "Подавить чары",
		&"freeze": "Заморозить воду",
		&"heat": "Нагреть камень",
	}, contextual_actions, hidden)


func _on_tool_selected(action_id: StringName) -> void:
	if action_in_progress:
		return
	if repair_hud.is_timed_action_active():
		repair_hud.show_system_message("Сначала дождитесь завершения текущей работы.", true)
		return
	if not game_state.can_employee_work_on_job(selected_employee_id, game_state.active_job_id):
		repair_hud.show_system_message(tr("Сотрудник ещё едет на объект. %s.") % tr(str(game_state.employees[selected_employee_id]["status"])), true)
		return
	var employee: Dictionary = game_state.employees.get(selected_employee_id, {})
	var contextual: String = simulation.get_employee_reaction(selected_employee_id, action_id)
	var reaction: String = EmployeeReactionResolverScript.reaction_for(employee, action_id, simulation.world_object, &"", contextual)
	var has_variant_pool := selected_employee_id == &"liliya" and action_id in [&"freeze", &"heat"]
	if not reaction.is_empty() and repair_hud.show_employee_reaction(selected_employee_id, reaction, has_variant_pool):
		pending_dialogue_action = action_id
		return
	action_had_intro = false
	_begin_action(action_id)


func _on_pre_action_dialogue_finished() -> void:
	if pending_dialogue_action.is_empty():
		return
	var action_id := pending_dialogue_action
	pending_dialogue_action = &""
	action_had_intro = true
	_begin_action(action_id)


func _begin_action(action_id: StringName) -> void:
	action_in_progress = true
	gargoyle.set_interaction_enabled(false)
	tool_bar.visible = false
	var is_physical: bool = game_state.employees[selected_employee_id].get("actor_action_style", &"magic") == &"physical"
	var approach := physical_approach.position if is_physical else Vector2.INF
	if is_physical:
		physical_action = action_id
		physical_timer_finished = false
		physical_actor_finished = false
	employee_actor.play_action(action_id, gargoyle.target_global_position(), approach)


func _on_action_impact(action_id: StringName) -> void:
	if not physical_action.is_empty():
		if game_state.start_job_action(game_state.active_job_id, selected_employee_id, physical_action, &"", game_state.get_action_duration(physical_action)):
			repair_hud.resume_timed_action(_on_physical_timer_finished)
			game_state.set_clock_paused(false)
		else:
			physical_action = &""
		return
	if game_state.employees[selected_employee_id].get("actor_action_style", &"magic") == &"magic":
		_resolve_action(action_id)


func _resolve_action(action_id: StringName) -> void:
	var was_awake := bool(simulation.world_object.get("awake", false))
	var previous_damage := int(simulation.world_object.get("damage", 0))
	var result: Dictionary = simulation.apply_action(selected_employee_id, action_id)
	if bool(result.get("applied", false)):
		if action_id == &"physical_move":
			_play_audio_cue(&"play_heavy_impact")
		elif action_id == &"animate" and not was_awake and bool(simulation.world_object.get("awake", false)):
			_play_audio_cue(&"play_gargoyle_wake")
	game_state.set_job_repair_state(game_state.active_job_id, simulation.get_state())
	_apply_visual_state()
	var resident_reaction: String = simulation.get_resident_reaction(action_id)
	if action_id == &"diagnose" and selected_employee_id in [&"grog", &"nika", &"felix"]:
		repair_hud.show_employee_reaction(selected_employee_id, str(result["message"]), true)
	elif action_id == &"diagnose":
		repair_hud.show_dialogue("РЕЗУЛЬТАТ ОСМОТРА", str(result["message"]))
	elif int(simulation.world_object.get("damage", 0)) > previous_damage and not resident_reaction.is_empty():
		repair_hud.show_resident_dialogue(resident_reaction)
	elif not bool(result.get("applied", false)):
		_show_failed_action(result)
	elif (action_id in [&"repair", &"animate"] or (action_id == &"antimagic" and was_awake)) and not resident_reaction.is_empty():
		repair_hud.show_resident_dialogue(resident_reaction)
	elif not action_had_intro or action_id in [&"heat", &"antimagic"]:
		repair_hud.show_system_message(str(result["message"]), bool(result["warning"]))
	else:
		repair_hud.clear_all_dialogues()
	action_had_intro = false


func _show_failed_action(result: Dictionary) -> void:
	var message := str(result.get("message", ""))
	if message.begins_with("Действие не изменило"):
		repair_hud.show_employee_reaction(selected_employee_id, EmployeeReactionResolverScript.no_effect_for(selected_employee_id))
	else:
		repair_hud.show_system_message(message, true)


func _resume_pending_action() -> void:
	var pending: Dictionary = game_state.get_pending_job_action(game_state.active_job_id)
	if pending.is_empty():
		return
	selected_employee_id = StringName(str(pending.get("employee_id", "")))
	_configure_employee_actor()
	action_in_progress = true
	gargoyle.set_interaction_enabled(false)
	var action := StringName(str(pending.get("action_id", "")))
	repair_hud.resume_timed_action(func() -> void:
		_resolve_action(action)
		_on_action_finished()
	)


func _on_action_finished() -> void:
	if not physical_action.is_empty():
		physical_actor_finished = true
		_finish_physical_action()
		return
	action_in_progress = false
	gargoyle.set_interaction_enabled(true)


func _on_physical_timer_finished() -> void:
	physical_timer_finished = true
	_finish_physical_action()


func _finish_physical_action() -> void:
	if physical_action.is_empty() or not physical_timer_finished or not physical_actor_finished:
		return
	var action := physical_action
	physical_action = &""
	_resolve_action(action)
	_on_action_finished()


func _apply_visual_state() -> void:
	gargoyle.show_state(simulation.visual_state())
	$GargoylePlacement/MouthFrost.visible = bool(simulation.world_object.get("frozen", false)) and bool(simulation.world_object.get("clogged", false)) and simulation.visual_state() == &"frozen"
	var water_state: StringName = simulation.flooding_state()
	flooding.visible = water_state == &"water"
	frozen_flooding.visible = bool(simulation.world_object.get("room_frozen", false))
	# Звук следует за видимыми протечками, а не за листьями в пасти:
	# после телекинетической очистки вода всё ещё течёт до ремонта или оживления.
	_set_audio_loop(&"set_running_water_playing", water_state == &"water")
	gargoyle.set_interaction_enabled(not action_in_progress)
	if repair_hud.has_method("set_completion_ready"):
		repair_hud.call("set_completion_ready", simulation.is_resolved())


func _play_audio_cue(method: StringName) -> void:
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager != null and audio_manager.has_method(method):
		audio_manager.call(method)


func _set_audio_loop(method: StringName, enabled: bool) -> void:
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager != null and audio_manager.has_method(method):
		audio_manager.call(method, enabled)


func _attempt_complete_job() -> void:
	if not simulation.is_resolved():
		repair_hud.show_system_message("Работу нельзя завершить: вода всё ещё затапливает чердак.", true)
		return
	if game_state.complete_active_job(simulation.get_completion_result()):
		get_tree().change_scene_to_file("res://scenes/main.tscn")
