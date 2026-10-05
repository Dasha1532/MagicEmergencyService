extends Node2D

const GhostSimulationScript := preload("res://scripts/ghost_followup_simulation.gd")

@onready var ghost: Control = $GhostPlacement
@onready var mirror: Control = $MirrorPlacement
@onready var empty_trap: TextureRect = $TrapPlacement/Empty
@onready var occupied_trap: TextureRect = $TrapPlacement/Occupied
@onready var lunnopuh_cage: Control = $LunnopuhTablePlacement/LunnopuhCagePlacement
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
var pending_dialogue_action: StringName = &""
var actor_finished := false
var effect_finished := false
var transfer_in_progress := false
var transfer_tween: Tween
var ghost_home_position: Vector2


func _ready() -> void:
	if game_state.active_job_id != &"escaped_ghost":
		get_tree().change_scene_to_file("res://scenes/main.tscn")
		return
	ghost_home_position = ghost.position
	simulation = GhostSimulationScript.new()
	simulation.apply_source_follow_up(game_state.get_follow_up_data(&"escaped_ghost"))
	var saved_state: Dictionary = game_state.get_job_repair_state(game_state.active_job_id)
	if not saved_state.is_empty():
		simulation.load_state(saved_state)
	ghost.selected.connect(_on_ghost_selected)
	mirror.selected.connect(_on_mirror_selected)
	tool_bar.tool_selected.connect(_on_tool_selected)
	repair_hud.employee_selected.connect(_on_employee_selected)
	repair_hud.completion_requested.connect(_attempt_complete_job)
	repair_hud.dialogue_finished.connect(_on_dialogue_finished)
	repair_hud.long_action_started.connect(_on_long_action_started)
	repair_hud.long_action_finished.connect(_on_long_action_finished)
	employee_actor.action_impact.connect(_on_action_impact)
	employee_actor.action_finished.connect(_on_action_finished)
	selected_employee_id = repair_hud.get_selected_employee_id()
	_configure_employee_actor()
	_apply_visual_state()
	var pending: Dictionary = game_state.get_pending_job_action(game_state.active_job_id)
	if not pending.is_empty():
		var saved_actor: Dictionary = simulation.pending_actor_action
		selected_employee_id = StringName(str(pending.get("employee_id", "")))
		selected_target = StringName(str(saved_actor.get("target_id", "mirror" if str(pending.get("action_id", "")) == "uncover" else "ghost")))
		pending_action_id = StringName(str(pending.get("action_id", "")))
		action_in_progress = true
		actor_finished = true
		_configure_employee_actor()
		repair_hud.resume_timed_action(_resolve_action.bind(pending_action_id))
	elif not simulation.pending_actor_action.is_empty():
		selected_employee_id = StringName(str(simulation.pending_actor_action["employee_id"]))
		selected_target = StringName(str(simulation.pending_actor_action["target_id"]))
		_configure_employee_actor()
		_begin_action(StringName(str(simulation.pending_actor_action["action_id"])))
	if not bool(simulation.world_object.get("resident_intro_seen", false)):
		simulation.world_object["resident_intro_seen"] = true
		_save_state()
		repair_hud.show_resident_dialogue(game_state.get_resident_greeting(game_state.active_job_id, simulation.get_resident_request()))


func _exit_tree() -> void:
	_set_ghost_flight_audio(false, false)


func _on_employee_selected(employee_id: StringName) -> void:
	if action_in_progress or not pending_dialogue_action.is_empty():
		return
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
	if action_in_progress or not pending_dialogue_action.is_empty():
		return
	if not _has_selected_employee():
		return
	selected_target = &"ghost"
	simulation.interaction_target = selected_target
	var employee: Dictionary = game_state.employees[selected_employee_id]
	tool_bar.configure_for_employee(str(employee["name"]), employee["abilities"], str(employee["core_actions"]))
	var custom_actions: Array[Dictionary] = []
	if game_state.has_supply_item(&"ghost_trap") and (selected_employee_id != &"boris" or simulation.can_begin_action(&"install_trap")):
		if StringName(simulation.world_object.get("trap_state", &"packed")) == &"packed" and simulation.can_employee_perform(&"ghost", &"install_trap", selected_employee_id):
			custom_actions.append({"id": &"install_trap", "label": "Установить ловушку"})
		elif StringName(simulation.world_object.get("trap_state", &"packed")) == &"installed":
			custom_actions.append({"id": &"trap", "label": "Затянуть в ловушку"})
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
	if action_in_progress or not pending_dialogue_action.is_empty():
		return
	if not _has_selected_employee():
		return
	selected_target = &"mirror"
	simulation.interaction_target = selected_target
	var employee: Dictionary = game_state.employees[selected_employee_id]
	tool_bar.configure_for_employee(str(employee["name"]), employee["abilities"], str(employee["core_actions"]))
	var actions: Array[Dictionary] = []
	if str(simulation.world_object["mirror_state"]) == "open" and simulation.can_employee_perform(&"mirror", &"cover", selected_employee_id) and (selected_employee_id != &"boris" or simulation.can_begin_action(&"cover")):
		actions.append({"id": &"cover", "label": "Закрыть защитным полотном"})
	if simulation.can_employee_perform(&"mirror", &"uncover", selected_employee_id) and StringName(simulation.world_object["mirror_state"]) == &"covered" and (selected_employee_id != &"boris" or simulation.can_begin_action(&"uncover")):
		actions.append({"id": &"uncover", "label": "Снять полотно"})
	tool_bar.show_for_object("Зеркало", mirror.target_global_position(), {
		&"diagnose": "Осмотреть",
		&"antimagic": "Закрыть портал",
		&"physical_move": "Разбить зеркало",
		&"telekinesis": "Сдвинуть зеркало",
		&"freeze": "Заморозить",
		&"heat": "Нагреть",
	}, actions, PackedStringArray(["repair", "animate"]))


func _has_selected_employee() -> bool:
	if selected_employee_id.is_empty():
		repair_hud.show_system_message("Сначала выберите сотрудника из бригады.", true)
		return false
	return true


func _on_tool_selected(action_id: StringName) -> void:
	if action_in_progress or not pending_dialogue_action.is_empty():
		return
	if repair_hud.is_timed_action_active():
		repair_hud.show_system_message("Сначала дождитесь завершения текущей работы.", true)
		return
	if not game_state.can_employee_work_on_job(selected_employee_id, game_state.active_job_id):
		repair_hud.show_system_message(tr("Сотрудник ещё едет на объект. %s.") % tr(str(game_state.employees[selected_employee_id]["status"])), true)
		return
	simulation.interaction_target = selected_target
	if not simulation.can_employee_perform(selected_target, action_id, selected_employee_id):
		return
	if selected_employee_id == &"boris" and not simulation.can_begin_action(action_id):
		return
	var context := {"has_trap": game_state.has_supply_item(&"ghost_trap"), "antimagic_present": _antimagic_specialist_is_present(), "has_antimagic": _selected_employee_has(&"antimagic"), "protective_cloth_available": game_state.has_supply_item(&"protective_cloth")}
	var refusal: String = simulation.refusal_message(selected_target, action_id, context)
	if not refusal.is_empty():
		tool_bar.visible = false
		if selected_target == &"mirror" and simulation.is_shared_mirror_action(action_id):
			simulation.perform(selected_target, selected_employee_id, action_id, context)
			_save_state()
			game_state.save_autosave()
			repair_hud.show_employee_reaction(selected_employee_id, refusal)
		else:
			_resolve_action(action_id)
		return
	if selected_employee_id == &"boris" and action_id == &"diagnose":
		var intro := "Посмотрю, что связывает его с зеркалом." if selected_target == &"ghost" else "Зеркало показывает потусторонний мир. Гарантия, полагаю, уже закончилась."
		if (selected_target == &"ghost" or str(simulation.world_object["mirror_state"]) == "open") and repair_hud.show_employee_reaction(selected_employee_id, intro):
			pending_dialogue_action = action_id
			tool_bar.visible = false
			return
	if selected_target == &"mirror" and action_id in [&"freeze", &"heat", &"cover", &"physical_move"]:
		var reaction: String = simulation.get_mirror_reaction(selected_employee_id, action_id, game_state.has_supply_item(&"protective_cloth"))
		if not reaction.is_empty() and repair_hud.show_employee_reaction(selected_employee_id, reaction):
			pending_dialogue_action = action_id
			tool_bar.visible = false
			return
	_begin_action(action_id)


func _on_dialogue_finished() -> void:
	if pending_dialogue_action.is_empty():
		return
	var action_id := pending_dialogue_action
	pending_dialogue_action = &""
	_begin_action(action_id)


func _on_long_action_started(_employee_id: StringName) -> void:
	employee_actor.set_persistent_work_pose(true)


func _on_long_action_finished(_employee_id: StringName) -> void:
	employee_actor.set_persistent_work_pose(false)


func _begin_action(action_id: StringName) -> void:
	actor_finished = false
	effect_finished = false
	simulation.pending_actor_action = {"employee_id": String(selected_employee_id), "action_id": String(action_id), "target_id": String(selected_target)}
	_save_state()
	game_state.save_autosave()
	action_in_progress = true
	pending_action_id = action_id
	ghost.set_interaction_enabled(false)
	mirror.set_interaction_enabled(false)
	tool_bar.visible = false
	var target: Vector2 = _trap_target_position() if action_id in [&"trap", &"install_trap"] else mirror.target_global_position() if selected_target == &"mirror" else ghost.target_global_position()
	var is_physical: bool = game_state.employees[selected_employee_id].get("actor_action_style", &"magic") == &"physical"
	var approach := (mirror_physical_approach.position if selected_target == &"mirror" else physical_approach.position) if is_physical else Vector2.INF
	if is_physical and action_id in [&"trap", &"install_trap"]:
		approach = to_local($TrapPlacement/PhysicalApproach.global_position)
	var pose: StringName = &"activate" if action_id == &"trap" else &"catch" if selected_target == &"ghost" and action_id == &"physical_move" else &"work"
	if selected_target == &"ghost" and action_id == &"antimagic":
		employee_actor.set_persistent_work_pose(true)
	employee_actor.play_action(action_id, target, approach, pose)


func _on_action_impact(action_id: StringName) -> void:
	if selected_target == &"ghost" and action_id in [&"trap", &"antimagic"]:
		_animate_ghost_transfer(action_id)
		return
	if selected_target == &"ghost" and action_id == &"physical_move":
		_resolve_action(action_id)
		return
	var physical: bool = game_state.employees[selected_employee_id].get("actor_action_style", &"magic") == &"physical"
	if physical or action_id == &"install_trap":
		repair_hud.start_timed_action(selected_employee_id, action_id, _resolve_action.bind(action_id), 2 if action_id == &"install_trap" else -1)
		_save_state()
		game_state.save_autosave()
	else:
		_resolve_action(action_id)


func _trap_target_position() -> Vector2:
	return empty_trap.global_position + empty_trap.size * 0.5


func _animate_ghost_transfer(action_id: StringName) -> void:
	if transfer_in_progress:
		return
	var context := {"has_antimagic": _selected_employee_has(&"antimagic"), "protective_cloth_available": game_state.has_supply_item(&"protective_cloth")}
	if not simulation.refusal_message(&"ghost", action_id, context).is_empty():
		employee_actor.set_persistent_work_pose(false)
		_resolve_action(action_id)
		return
	transfer_in_progress = true
	ghost.pivot_offset = ghost.size * 0.5
	simulation.pending_actor_action["phase"] = "transfer"
	_save_state()
	game_state.save_autosave()
	if angry_tween != null and angry_tween.is_valid():
		angry_tween.kill()
	var destination: Vector2 = to_local(_trap_target_position() if action_id == &"trap" else mirror.target_global_position()) - ghost.size * 0.5
	transfer_tween = create_tween()
	transfer_tween.tween_property(ghost, "position", ghost.position + Vector2(0, -45), 0.25)
	transfer_tween.tween_property(ghost, "position", destination, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	transfer_tween.parallel().tween_property(ghost, "scale", Vector2(0.35, 0.35) if action_id == &"trap" else Vector2(0.7, 0.7), 1.0)
	transfer_tween.tween_property(ghost, "modulate:a", 0.0, 0.3)
	await transfer_tween.finished
	employee_actor.set_persistent_work_pose(false)
	transfer_in_progress = false
	_resolve_action(action_id)
	ghost.scale = Vector2.ONE
	ghost.modulate.a = 1.0


func _resolve_action(action_id: StringName) -> void:
	var previous_ghost_state := StringName(simulation.world_object.get("ghost_state", &"calm"))
	var previous_mirror_state := StringName(simulation.world_object.get("mirror_state", &"covered"))
	var result: Dictionary = simulation.perform(selected_target, selected_employee_id, action_id, {"has_trap": game_state.has_supply_item(&"ghost_trap"), "antimagic_present": _antimagic_specialist_is_present(), "has_antimagic": _selected_employee_has(&"antimagic"), "protective_cloth_available": game_state.has_supply_item(&"protective_cloth")})
	simulation.pending_actor_action = {}
	effect_finished = true
	if bool(result.get("applied", false)) and action_id == &"uncover":
		game_state.return_supply_item(&"protective_cloth")
	if bool(result.get("applied", false)) and action_id == &"cover":
		game_state.consume_supply_item(&"protective_cloth")
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
	game_state.save_autosave()
	_apply_visual_state()
	repair_hud.show_system_message(str(result["message"]), bool(result["warning"]))
	_try_finish_action()
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
	actor_finished = true
	_try_finish_action()


func _try_finish_action() -> void:
	if not actor_finished or not effect_finished:
		return
	action_in_progress = false
	pending_action_id = &""
	ghost.set_interaction_enabled(true)
	mirror.set_interaction_enabled(true)


func _save_state() -> void:
	game_state.set_job_repair_state(game_state.active_job_id, simulation.get_state())


func _apply_visual_state() -> void:
	var pet_caged := str(simulation.world_object.get("lunnopuh_state", "absent")) == "caged"
	lunnopuh_cage.show_state(&"occupied" if pet_caged else &"packed")
	$LunnopuhTablePlacement.visible = pet_caged
	# The pet is decoration in this job; do not leave an inactive target cursor.
	lunnopuh_cage.get_node("InteractionButton").visible = false
	lunnopuh_cage.get_node("InteractionButton").mouse_filter = Control.MOUSE_FILTER_IGNORE
	$TrapPlacement.position = Vector2(760, 555) if pet_caged else Vector2(1050, 555)
	var ghost_state := StringName(simulation.world_object["ghost_state"])
	ghost.show_state(ghost_state)
	mirror.show_state(simulation.mirror_visual_state())
	var trap_state := StringName(simulation.world_object.get("trap_state", &"packed"))
	empty_trap.visible = trap_state == &"installed"
	occupied_trap.visible = trap_state == &"occupied"
	_update_ghost_motion(ghost_state)
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


func _update_ghost_motion(state: StringName) -> void:
	if angry_tween != null and angry_tween.is_valid():
		angry_tween.kill()
	ghost.position = ghost_home_position
	if transfer_in_progress or state not in [&"calm", &"angry"]:
		return
	angry_tween = create_tween().set_loops()
	if state == &"calm":
		angry_tween.tween_property(ghost, "position", ghost_home_position + Vector2(7, -10), 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		angry_tween.tween_property(ghost, "position", ghost_home_position + Vector2(-5, 6), 2.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		angry_tween.tween_property(ghost, "position", ghost_home_position, 1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		angry_tween.tween_property(ghost, "position", ghost_home_position + Vector2(60, -28), 0.32).set_trans(Tween.TRANS_SINE)
		angry_tween.tween_property(ghost, "position", ghost_home_position + Vector2(-45, 29), 0.42).set_trans(Tween.TRANS_SINE)
		angry_tween.tween_property(ghost, "position", ghost_home_position, 0.28).set_trans(Tween.TRANS_SINE)


func _attempt_complete_job() -> void:
	if action_in_progress or repair_hud.is_timed_action_active():
		return
	if not simulation.is_resolved():
		repair_hud.show_system_message("Работу нельзя завершить: привидение всё ещё находится в комнате.", true)
		return
	if game_state.complete_active_job(simulation.get_completion_result()):
		get_tree().change_scene_to_file("res://scenes/main.tscn")
