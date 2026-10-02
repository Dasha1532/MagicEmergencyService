extends Node2D

const GhostSimulationScript := preload("res://scripts/ghost_followup_simulation.gd")

@onready var ghost: Control = $GhostPlacement
@onready var mirror: Control = $MirrorPlacement
@onready var empty_trap: TextureRect = $TrapPlacement/Empty
@onready var occupied_trap: TextureRect = $TrapPlacement/Occupied
@onready var employee_actor: Control = $EmployeeActor
@onready var physical_approach: Marker2D = $PhysicalApproach
@onready var mirror_physical_approach: Marker2D = $MirrorPhysicalApproach
@onready var tool_bar: Control = $Interface/ToolBar
@onready var repair_hud: Control = $Interface/RepairHUD
@onready var game_state: Node = get_node("/root/GameState")

var simulation: RefCounted
var selected_employee_id: StringName = &""
var selected_target: StringName = &"ghost"
var pending_action_id: StringName = &""
var action_in_progress := false
var angry_tween: Tween


func _ready() -> void:
	if game_state.active_job_id != &"escaped_ghost":
		get_tree().change_scene_to_file("res://scenes/main.tscn")
		return
	simulation = GhostSimulationScript.new()
	var saved_state: Dictionary = game_state.get_job_repair_state(game_state.active_job_id)
	if not saved_state.is_empty():
		simulation.load_state(saved_state)
	else:
		simulation.apply_source_follow_up(game_state.get_follow_up_data(&"escaped_ghost"))
	ghost.selected.connect(_on_ghost_selected)
	mirror.selected.connect(_on_mirror_selected)
	tool_bar.tool_selected.connect(_on_tool_selected)
	repair_hud.employee_selected.connect(_on_employee_selected)
	repair_hud.completion_requested.connect(_attempt_complete_job)
	employee_actor.action_impact.connect(_on_action_impact)
	employee_actor.action_finished.connect(_on_action_finished)
	selected_employee_id = repair_hud.get_selected_employee_id()
	_configure_employee_actor()
	_apply_visual_state()
	var pending: Dictionary = game_state.get_pending_job_action(game_state.active_job_id)
	if not pending.is_empty():
		repair_hud.resume_timed_action(_resolve_action.bind(StringName(str(pending.get("action_id", "")))))
	if not bool(simulation.world_object.get("resident_intro_seen", false)):
		simulation.world_object["resident_intro_seen"] = true
		_save_state()
		repair_hud.show_resident_dialogue(game_state.get_resident_greeting(game_state.active_job_id, simulation.get_resident_request()))


func _exit_tree() -> void:
	_set_ghost_flight_audio(false, false)


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
		employee_actor.call("set_horizontal_flip", true)


func _on_ghost_selected() -> void:
	if action_in_progress:
		return
	if not _has_selected_employee():
		return
	selected_target = &"ghost"
	var employee: Dictionary = game_state.employees[selected_employee_id]
	tool_bar.configure_for_employee(str(employee["name"]), employee["abilities"], str(employee["core_actions"]))
	var custom_actions: Array[Dictionary] = []
	if game_state.has_supply_item(&"ghost_trap"):
		if StringName(simulation.world_object.get("trap_state", &"packed")) == &"packed":
			custom_actions.append({"id": &"install_trap", "label": "Установить ловушку — 2 мин."})
		elif StringName(simulation.world_object.get("trap_state", &"packed")) == &"installed":
			custom_actions.append({"id": &"trap", "label": "Загнать в ловушку"})
	tool_bar.show_for_object("Привидение", ghost.target_global_position(), {
		&"diagnose": "Определить связь",
		&"physical_move": "Попытаться схватить",
		&"telekinesis": "Удержать телекинезом",
		&"antimagic": "Изгнать в портал",
		&"freeze": "Заморозить",
		&"heat": "Нагреть",
		&"animate": "Воздействовать чарами",
	}, custom_actions, PackedStringArray(["repair"]))


func _on_mirror_selected() -> void:
	if action_in_progress:
		return
	if not _has_selected_employee():
		return
	selected_target = &"mirror"
	var employee: Dictionary = game_state.employees[selected_employee_id]
	tool_bar.configure_for_employee(str(employee["name"]), employee["abilities"], str(employee["core_actions"]))
	var actions: Array[Dictionary] = []
	if StringName(simulation.world_object["mirror_state"]) == &"covered":
		actions.append({"id": &"uncover", "label": "Снять полотно"})
	tool_bar.show_for_object("Зеркало", mirror.target_global_position(), {
		&"antimagic": "Закрыть портал",
		&"physical_move": "Разбить зеркало",
	}, actions, PackedStringArray(["diagnose", "repair", "telekinesis", "freeze", "heat", "animate"]))


func _has_selected_employee() -> bool:
	if selected_employee_id.is_empty():
		repair_hud.show_system_message("Сначала выберите сотрудника из бригады.", true)
		return false
	return true


func _on_tool_selected(action_id: StringName) -> void:
	if action_in_progress:
		return
	if repair_hud.is_timed_action_active():
		repair_hud.show_system_message("Сначала дождитесь завершения текущей работы.", true)
		return
	if not game_state.can_employee_work_on_job(selected_employee_id, game_state.active_job_id):
		repair_hud.show_system_message(tr("Сотрудник ещё едет на объект. %s.") % tr(str(game_state.employees[selected_employee_id]["status"])), true)
		return
	if selected_target == &"mirror" and action_id == &"uncover" and not _antimagic_specialist_is_present():
		tool_bar.visible = false
		_resolve_action(action_id)
		return
	# Недопустимая антимагия должна закончиться сообщением, а не ложным кастом.
	# Состояние повторно проверяется самой симуляцией в _resolve_action().
	if action_id == &"antimagic" and (
		(selected_target == &"ghost" and not simulation.can_return_ghost_to_portal())
		or (selected_target == &"mirror" and not simulation.can_close_portal())
	):
		tool_bar.visible = false
		_resolve_action(action_id)
		return
	action_in_progress = true
	pending_action_id = action_id
	ghost.set_interaction_enabled(false)
	mirror.set_interaction_enabled(false)
	tool_bar.visible = false
	var target: Vector2 = mirror.target_global_position() if selected_target == &"mirror" else ghost.target_global_position()
	var is_physical: bool = game_state.employees[selected_employee_id].get("actor_action_style", &"magic") == &"physical"
	var is_timed: bool = is_physical or action_id == &"install_trap"
	var approach := (mirror_physical_approach.position if selected_target == &"mirror" else physical_approach.position) if is_physical else Vector2.INF
	if is_timed:
		repair_hud.start_timed_action(selected_employee_id, action_id, _resolve_action.bind(action_id), 2 if action_id == &"install_trap" else -1)
	if action_id == &"install_trap":
		return
	employee_actor.play_action(action_id, target, approach)


func _on_action_impact(action_id: StringName) -> void:
	if game_state.employees[selected_employee_id].get("actor_action_style", &"magic") == &"magic" and action_id != &"install_trap":
		_resolve_action(action_id)


func _resolve_action(action_id: StringName) -> void:
	var previous_ghost_state := StringName(simulation.world_object.get("ghost_state", &"calm"))
	var previous_mirror_state := StringName(simulation.world_object.get("mirror_state", &"covered"))
	var result: Dictionary
	if selected_target == &"mirror":
		if action_id == &"uncover":
			result = simulation.uncover_mirror(selected_employee_id, _antimagic_specialist_is_present())
		elif action_id == &"physical_move":
			result = simulation.break_mirror(selected_employee_id)
		else:
			result = simulation.close_portal(selected_employee_id, _selected_employee_has(&"antimagic"))
	else:
		result = simulation.install_trap(selected_employee_id, game_state.has_supply_item(&"ghost_trap")) if action_id == &"install_trap" else simulation.apply_ghost_action(selected_employee_id, action_id)
	if bool(result.get("applied", false)) and action_id == &"uncover":
		game_state.return_supply_item(&"protective_cloth")
	if bool(result.get("applied", false)):
		if action_id == &"install_trap":
			_play_audio_cue(&"play_trap_install")
		elif action_id == &"trap":
			_play_audio_cue(&"play_ghost_trap")
		elif action_id == &"physical_move" and StringName(simulation.world_object.get("mirror_state", &"")) == &"destroyed":
			_play_audio_cue(&"play_heavy_impact")
			_play_audio_cue(&"play_mirror_shatter")
		elif previous_mirror_state == &"open" and StringName(simulation.world_object.get("mirror_state", &"")) == &"closed":
			_play_audio_cue(&"play_portal_close")
		if previous_ghost_state != &"angry" and StringName(simulation.world_object.get("ghost_state", &"")) == &"angry":
			_play_audio_cue(&"play_ghost_scream")
	_save_state()
	if bool(result.get("applied", false)) and action_id == &"uncover":
		game_state.save_autosave()
	_apply_visual_state()
	repair_hud.show_system_message(str(result["message"]), bool(result["warning"]))
	if action_id == &"install_trap":
		action_in_progress = false
		pending_action_id = &""
		ghost.set_interaction_enabled(true)
		mirror.set_interaction_enabled(true)
	if bool(result["applied"]) and simulation.is_resolved() and action_id in [&"trap", &"antimagic", &"physical_move"]:
		if action_id == &"antimagic" and StringName(simulation.world_object["ghost_state"]) == &"captured":
			repair_hud.queue_resident_dialogue("Теперь и привидение поймано, и портал закрыт. Вот так гораздо лучше.")
		elif action_id == &"physical_move":
			repair_hud.queue_resident_dialogue("Это было фамильное зеркало! Теперь из него действительно больше никто не выйдет — как и моё отражение.")
		else:
			repair_hud.queue_resident_dialogue("Вот так гораздо лучше. Теперь оно хотя бы не носится по моей гостиной.")


func _selected_employee_has(ability_id: StringName) -> bool:
	if selected_employee_id.is_empty() or not game_state.employees.has(selected_employee_id):
		return false
	return (game_state.employees[selected_employee_id]["abilities"] as PackedStringArray).has(String(ability_id))


func _antimagic_specialist_is_present() -> bool:
	var assigned: PackedStringArray = game_state.jobs[game_state.active_job_id]["assigned"]
	for employee_id: String in assigned:
		var id := StringName(employee_id)
		if game_state.can_employee_work_on_job(id, game_state.active_job_id) and (game_state.employees[id]["abilities"] as PackedStringArray).has("antimagic"):
			return true
	return false


func _on_action_finished() -> void:
	action_in_progress = false
	pending_action_id = &""
	ghost.set_interaction_enabled(true)
	mirror.set_interaction_enabled(true)


func _save_state() -> void:
	game_state.set_job_repair_state(game_state.active_job_id, simulation.get_state())


func _apply_visual_state() -> void:
	var ghost_state := StringName(simulation.world_object["ghost_state"])
	ghost.show_state(ghost_state)
	mirror.show_state(simulation.mirror_visual_state())
	var trap_state := StringName(simulation.world_object.get("trap_state", &"packed"))
	empty_trap.visible = trap_state == &"installed"
	occupied_trap.visible = trap_state == &"occupied"
	_update_angry_motion(ghost_state == &"angry")
	_set_ghost_flight_audio(ghost_state in [&"calm", &"angry"], ghost_state == &"angry")
	repair_hud.set_completion_ready(simulation.is_resolved())


func _play_audio_cue(method: StringName) -> void:
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager != null and audio_manager.has_method(method):
		audio_manager.call(method)


func _set_ghost_flight_audio(enabled: bool, is_angry: bool) -> void:
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager != null and audio_manager.has_method(&"set_ghost_flight_playing"):
		audio_manager.call(&"set_ghost_flight_playing", enabled, is_angry)


func _update_angry_motion(is_angry: bool) -> void:
	if angry_tween != null and angry_tween.is_valid():
		angry_tween.kill()
	ghost.position = Vector2(625, 96)
	if not is_angry:
		return
	angry_tween = create_tween().set_loops()
	angry_tween.tween_property(ghost, "position", Vector2(685, 68), 0.32).set_trans(Tween.TRANS_SINE)
	angry_tween.tween_property(ghost, "position", Vector2(580, 125), 0.42).set_trans(Tween.TRANS_SINE)
	angry_tween.tween_property(ghost, "position", Vector2(625, 96), 0.28).set_trans(Tween.TRANS_SINE)


func _attempt_complete_job() -> void:
	if not simulation.is_resolved():
		repair_hud.show_system_message("Работу нельзя завершить: привидение всё ещё находится в комнате.", true)
		return
	if game_state.complete_active_job(simulation.get_completion_result()):
		get_tree().change_scene_to_file("res://scenes/main.tscn")
