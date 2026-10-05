extends Node2D

const PortalMirrorSimulationScript := preload("res://scripts/portal_mirror_simulation.gd")
const EmployeeReactionResolverScript := preload("res://scripts/employee_reaction_resolver.gd")
const COLOR_PANEL := Color(0.07, 0.045, 0.03, 0.94)
const COLOR_GOLD := Color(0.96, 0.68, 0.28)

@onready var overview_background: TextureRect = $Background
@onready var room_placement: Control = $RoomPlacement
@onready var room_hotspot: Button = $RoomPlacement/RoomHotspot
@onready var closeup_background: TextureRect = $RoomCloseup
@onready var fireplace_glow: Node2D = $FireplaceGlow
@onready var portal_mirror: Control = $PortalMirror
@onready var lunnopuh_cage: Control = $CagePlacement
@onready var lunnopuh: TextureRect = $LunnopuhPlacement
@onready var employee_actor: Control = $EmployeeActor
@onready var physical_approach: Marker2D = $PhysicalApproach
@onready var back_to_house_button: Button = $Interface/BackToHouseButton
@onready var tool_bar: Control = $Interface/ToolBar
@onready var repair_hud: Control = $Interface/RepairHUD
@onready var game_state: Node = get_node("/root/GameState")

const LunnopuhDefinition := preload("res://data/objects/lunnopuh.tres")
var selected_object_id: StringName = &"portal_mirror"

var lunnopuh_home_position := Vector2.ZERO
var lunnopuh_motion: Tween
var returning_creature: bool = false
var simulation: PortalMirrorSimulation
var selected_employee_id: StringName = &""
var action_in_progress: bool = false
var pending_dialogue_action: StringName = &""
var last_action_intro: String = ""
var pending_physical_action: StringName = &""
var physical_timer_finished: bool = false
var physical_impact_reached: bool = false


func _ready() -> void:
	if game_state.active_job_id != &"portal_mirror":
		get_tree().change_scene_to_file("res://scenes/main.tscn")
		return
	lunnopuh_home_position = lunnopuh.position
	simulation = PortalMirrorSimulationScript.new()
	simulation.initialize_from_job(game_state.jobs.get(game_state.active_job_id, {}))
	var saved_state: Dictionary = game_state.get_job_repair_state(game_state.active_job_id)
	if not saved_state.is_empty():
		simulation.load_state(saved_state)
	_configure_room_button()
	_style_button(back_to_house_button)
	room_hotspot.pressed.connect(_open_room)
	back_to_house_button.pressed.connect(_show_house_overview)
	repair_hud.employee_selected.connect(_on_employee_selected)
	repair_hud.completion_requested.connect(_attempt_complete_job)
	repair_hud.long_action_started.connect(_on_long_action_started)
	repair_hud.long_action_finished.connect(_on_long_action_finished)
	repair_hud.dialogue_finished.connect(_on_pre_action_dialogue_finished)
	portal_mirror.selected.connect(_on_mirror_selected)
	lunnopuh.selected.connect(_on_lunnopuh_selected)
	lunnopuh_cage.selected.connect(_on_lunnopuh_selected)
	tool_bar.tool_selected.connect(_on_tool_selected)
	tool_bar.intent_selected.connect(_on_lunnopuh_intent_selected)
	employee_actor.action_impact.connect(_on_action_impact)
	employee_actor.physical_target_reached.connect(_on_lunnopuh_approach_finished)
	employee_actor.action_finished.connect(_on_action_finished)
	selected_employee_id = repair_hud.get_selected_employee_id()
	_apply_visual_state()
	_resume_pending_action()
	call_deferred("_open_room")


func _on_long_action_started(employee_id: StringName) -> void:
	if employee_id == selected_employee_id and employee_actor.visible:
		employee_actor.call("set_persistent_work_pose", true)


func _on_long_action_finished(employee_id: StringName) -> void:
	if employee_id == selected_employee_id:
		employee_actor.call("set_persistent_work_pose", false)


func _open_room() -> void:
	room_hotspot.disabled = true
	closeup_background.visible = true
	closeup_background.modulate = Color(1, 1, 1, 0)
	portal_mirror.visible = true
	_apply_visual_state()
	fireplace_glow.visible = true
	employee_actor.visible = _configure_employee_actor()
	var tween: Tween = create_tween()
	tween.tween_property(closeup_background, "modulate", Color.WHITE, 0.24)
	await tween.finished
	overview_background.visible = false
	room_placement.visible = false
	back_to_house_button.visible = false
	tool_bar.visible = false
	if repair_hud.has_method("set_work_ui_visible"):
		repair_hud.call("set_work_ui_visible", true)
	if not bool(simulation.world_object.get("resident_intro_seen", false)):
		simulation.world_object["resident_intro_seen"] = true
		game_state.set_job_repair_state(game_state.active_job_id, simulation.get_state())
		repair_hud.show_resident_dialogue(game_state.get_resident_greeting(game_state.active_job_id, simulation.get_resident_request()))


func _show_house_overview(animated: bool = true) -> void:
	overview_background.visible = true
	room_placement.visible = true
	fireplace_glow.visible = false
	portal_mirror.visible = false
	lunnopuh_cage.visible = false
	lunnopuh.visible = false
	employee_actor.visible = false
	room_hotspot.disabled = false
	back_to_house_button.visible = false
	tool_bar.visible = false
	if repair_hud.has_method("set_work_ui_visible"):
		repair_hud.call("set_work_ui_visible", false)
	if not animated:
		closeup_background.visible = false
		closeup_background.modulate = Color.WHITE
		return
	var tween: Tween = create_tween()
	tween.tween_property(closeup_background, "modulate", Color(1, 1, 1, 0), 0.24)
	await tween.finished
	closeup_background.visible = false
	closeup_background.modulate = Color.WHITE


func _on_employee_selected(employee_id: StringName) -> void:
	if action_in_progress or not pending_dialogue_action.is_empty():
		if employee_id != selected_employee_id:
			repair_hud.call("_select_employee", selected_employee_id)
		return
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


func _on_mirror_selected() -> void:
	if action_in_progress or not pending_dialogue_action.is_empty():
		return
	if selected_employee_id.is_empty():
		repair_hud.show_system_message("Сначала выберите сотрудника из бригады.", true)
		return
	selected_object_id = &"portal_mirror"
	simulation.interaction_target = selected_object_id
	var employee: Dictionary = game_state.employees[selected_employee_id]
	var contextual_actions: Array[Dictionary] = []
	if selected_employee_id == &"boris" and bool(simulation.world_object.get("inspected", false)) and not bool(simulation.world_object["destroyed"]):
		if bool(simulation.world_object.get("covered", false)):
			contextual_actions.append({"id": &"uncover", "label": "Снять защитное полотно"})
		else:
			contextual_actions.append({"id": &"cover", "label": "Закрыть защитным полотном"})
		if game_state.has_supply_item(&"lunnopuh_cage") and str(simulation.world_object.get("cage_state", "packed")) == "packed":
			contextual_actions.append({"id": &"install_cage", "label": "Установить клетку"})
	var hidden := PackedStringArray(["animate"])
	for action: String in ["diagnose", "repair", "physical_move", "telekinesis", "antimagic", "freeze", "heat", "cover", "uncover"]:
		if not simulation.available_actions(selected_employee_id).has(action):
			hidden.append(action)
	tool_bar.configure_for_employee(str(employee["name"]), employee["abilities"], str(employee["core_actions"]))
	tool_bar.show_for_object("Зеркало", portal_mirror.target_global_position(), {
		&"diagnose": "Осмотреть",
		&"physical_move": "Разбить зеркало",
		&"telekinesis": "Сдвинуть зеркало",
		&"antimagic": "Закрыть портал",
		&"freeze": "Заморозить",
		&"heat": "Нагреть",
	}, contextual_actions, hidden)


func _on_lunnopuh_selected() -> void:
	if action_in_progress or not pending_dialogue_action.is_empty():
		return
	if str(simulation.world_object.get("lunnopuh_state", "absent")) not in ["free", "caged"]:
		return
	if selected_employee_id.is_empty():
		repair_hud.show_system_message("Сначала выберите сотрудника из бригады.", true)
		return
	selected_object_id = &"lunnopuh"
	simulation.interaction_target = selected_object_id
	var employee: Dictionary = game_state.employees[selected_employee_id]
	var supported := PackedStringArray()
	for action: String in simulation.lunnopuh_actions(selected_employee_id):
		if PackedStringArray(employee["abilities"]).has(action):
			supported.append(action)
	if selected_employee_id == &"grog":
		supported.erase("physical_move")
	var contextual_actions: Array[Dictionary] = []
	for action: String in simulation.lunnopuh_actions(selected_employee_id):
		var profile: Dictionary = (LunnopuhDefinition.base_properties.get("object_actions", {}) as Dictionary).get(action, {})
		if action == "install_cage" and (not game_state.has_supply_item(&"lunnopuh_cage") or str(simulation.world_object.get("cage_state", "packed")) != "packed"):
			continue
		if action in ["catch_hand", "catch_into_cage"]:
			var catch_action := "catch_into_cage" if str(simulation.world_object.get("cage_state", "packed")) == "installed" else "catch_hand"
			if action != catch_action:
				continue
		if action in ["catch_lunnopuh", "return_lunnopuh"]:
			continue
		if profile.is_empty():
			continue
		var compatible := true
		for ability: String in profile.get("abilities", []):
			if not PackedStringArray(employee["abilities"]).has(ability):
				compatible = false
		if compatible:
			contextual_actions.append({"id": StringName(action), "label": str(profile["label"])})
	if supported.is_empty() and contextual_actions.is_empty():
		tool_bar.visible = false
		repair_hud.show_system_message("У выбранного сотрудника пока нет действий с лунопухом.", false)
		return
	var hidden := PackedStringArray()
	for action: String in ["diagnose", "repair", "physical_move", "telekinesis", "antimagic", "animate", "freeze", "heat"]:
		if not supported.has(action):
			hidden.append(action)
	tool_bar.configure_for_employee(str(employee["name"]), employee["abilities"], str(employee["core_actions"]))
	tool_bar.show_for_object("Лунопух", _selected_target_position(), {&"diagnose": "Осмотреть", &"freeze": "Заморозить", &"heat": "Нагреть"}, contextual_actions, hidden)


func _lunnopuh_missing_cage_reaction() -> String:
	if game_state.has_supply_item(&"lunnopuh_cage") or str(simulation.world_object.get("cage_state", "packed")) != "packed":
		return ""
	if not bool(simulation.world_object.get("portal_open", false)) or bool(simulation.world_object.get("destroyed", false)):
		return str(LunnopuhDefinition.base_properties.get("missing_cage_closed_portal_reaction", ""))
	return str((LunnopuhDefinition.base_properties.get("missing_cage_reactions", {}) as Dictionary).get("nika", ""))


func _lunnopuh_telekinesis_choices() -> Array:
	var choices: Array = []
	if str(simulation.world_object.get("lunnopuh_state", "absent")) == "free" and (game_state.has_supply_item(&"lunnopuh_cage") or str(simulation.world_object.get("cage_state", "packed")) == "installed"):
		choices.append({"id": &"catch_lunnopuh", "label": "Посадить в клетку"})
	if bool(simulation.lunnopuh_properties().get("portal_available", false)):
		choices.append({"id": &"return_lunnopuh", "label": "Отправить в портал"})
	return choices


func _on_lunnopuh_intent_selected(intent_id: StringName) -> void:
	if selected_object_id == &"lunnopuh":
		_on_tool_selected(intent_id)


func _selected_target_position() -> Vector2:
	if selected_object_id == &"lunnopuh":
		return lunnopuh_cage.target_global_position() if str(simulation.world_object.get("lunnopuh_state", "absent")) == "caged" else lunnopuh.target_global_position()
	return portal_mirror.target_global_position()


func _on_tool_selected(action_id: StringName) -> void:
	if action_in_progress:
		return
	if repair_hud.is_timed_action_active():
		repair_hud.show_system_message("Сначала дождитесь завершения текущей работы.", true)
		return
	if not game_state.can_employee_work_on_job(selected_employee_id, game_state.active_job_id):
		repair_hud.show_system_message(tr("Сотрудник ещё едет на объект. %s.") % tr(str(game_state.employees[selected_employee_id]["status"])), true)
		return
	if selected_object_id == &"lunnopuh":
		if str(simulation.world_object.get("lunnopuh_state", "absent")) not in ["free", "caged"]:
			return
		if action_id == &"telekinesis":
			var missing_cage_reply := _lunnopuh_missing_cage_reaction()
			if not missing_cage_reply.is_empty():
				repair_hud.show_employee_reaction(selected_employee_id, missing_cage_reply)
			var choices := _lunnopuh_telekinesis_choices()
			if choices.is_empty():
				tool_bar.hide()
			else:
				tool_bar.show_intents("Телекинез", choices)
			return
		if action_id == &"physical_move":
			tool_bar.show_intents("Силовая работа", [{"id": &"catch_hand", "label": "Поймать руками"}, {"id": &"catch_into_cage", "label": "Загнать в клетку"}])
			return
		tool_bar.visible = false
		if not simulation.lunnopuh_actions(selected_employee_id).has(String(action_id)):
			return
		var creature_refusal := simulation.lunnopuh_refusal(action_id, game_state.has_supply_item(&"lunnopuh_cage"))
		if not creature_refusal.is_empty():
			if action_id in [&"freeze", &"heat", &"animate", &"antimagic"]:
				repair_hud.show_employee_reaction(selected_employee_id, creature_refusal)
			elif action_id in [&"install_cage", &"catch_lunnopuh", &"catch_into_cage"] and not game_state.has_supply_item(&"lunnopuh_cage"):
				var replies: Dictionary = LunnopuhDefinition.base_properties.get("missing_cage_reactions", {})
				repair_hud.show_employee_reaction(selected_employee_id, str(replies.get(String(selected_employee_id), creature_refusal)))
			else:
				repair_hud.show_system_message(creature_refusal, true)
			return
		last_action_intro = simulation.lunnopuh_reaction(action_id)
		if not last_action_intro.is_empty() and repair_hud.show_employee_reaction(selected_employee_id, last_action_intro):
			pending_dialogue_action = action_id
			return
		_begin_action(action_id)
		return
	if not simulation.available_actions(selected_employee_id).has(String(action_id)):
		return
	var contextual: String = simulation.get_employee_reaction(selected_employee_id, action_id, game_state.has_supply_item(&"protective_cloth"))
	var reaction: String = contextual
	last_action_intro = reaction
	if not simulation.refusal_message(action_id, game_state.has_supply_item(&"protective_cloth")).is_empty():
		tool_bar.visible = false
		repair_hud.show_employee_reaction(selected_employee_id, reaction)
		return
	if not reaction.is_empty() and repair_hud.show_employee_reaction(selected_employee_id, reaction):
		pending_dialogue_action = action_id
		return
	_begin_action(action_id)


func _on_pre_action_dialogue_finished() -> void:
	if pending_dialogue_action.is_empty():
		return
	var action_id := pending_dialogue_action
	pending_dialogue_action = &""
	_begin_action(action_id)


func _begin_action(action_id: StringName) -> void:
	if selected_object_id == &"lunnopuh" and (not simulation.lunnopuh_actions(selected_employee_id).has(String(action_id)) or not simulation.lunnopuh_refusal(action_id, game_state.has_supply_item(&"lunnopuh_cage")).is_empty()):
		return
	if selected_object_id != &"lunnopuh" and (not simulation.available_actions(selected_employee_id).has(String(action_id)) or not simulation.refusal_message(action_id, game_state.has_supply_item(&"protective_cloth")).is_empty()):
		return
	simulation.pending_actor_action = {"employee_id": String(selected_employee_id), "action_id": String(action_id), "target_id": String(selected_object_id)}
	game_state.set_job_repair_state(game_state.active_job_id, simulation.get_state())
	game_state.save_autosave()
	action_in_progress = true
	portal_mirror.set_interaction_enabled(false)
	tool_bar.visible = false
	var is_physical: bool = game_state.employees[selected_employee_id].get("actor_action_style", &"magic") == &"physical"
	var target_position: Vector2 = lunnopuh_cage.target_global_position() if action_id == &"install_cage" else _selected_target_position()
	var approach := _lunnopuh_approach_position(action_id) if is_physical and (selected_object_id == &"lunnopuh" or action_id == &"install_cage") else physical_approach.position if is_physical else Vector2.INF
	if is_physical:
		pending_physical_action = action_id
		# Удар не требует длительной работы; состояние меняется после анимации
		# и не расходует две игровые минуты на условную долгую работу.
		physical_timer_finished = _is_instant_physical_action(action_id)
		physical_impact_reached = false

	if selected_object_id == &"lunnopuh" and action_id in [&"return_lunnopuh", &"catch_lunnopuh"]:
		employee_actor.set_persistent_work_pose(true)
	var attempt_pose: StringName = &"neutral" if action_id in [&"catch_hand", &"catch_into_cage"] else &"work"
	employee_actor.play_action(action_id, target_position, approach, attempt_pose)


func _lunnopuh_approach_position(action_id: StringName) -> Vector2:
	if action_id == &"install_cage" or str(simulation.world_object.get("lunnopuh_state", "absent")) == "caged":
		return $LunnopuhRoutes/CageApproach.position
	return $LunnopuhRoutes/LeftApproach.position if float(simulation.world_object.get("lunnopuh_offset_x", 0.0)) != 0.0 else $LunnopuhRoutes/RightApproach.position


func _is_instant_physical_action(action_id: StringName) -> bool:
	return action_id in [&"physical_move", &"catch_hand", &"catch_into_cage"]


func _on_lunnopuh_approach_finished(action_id: StringName) -> void:
	if selected_object_id == &"lunnopuh" and action_id in [&"catch_hand", &"catch_into_cage"] and not bool(simulation.world_object.get("lunnopuh_escape_pending", false)):
		var escape_position: Vector2 = to_local($LunnopuhRoutes/EscapeLeft.global_position) - Vector2(lunnopuh.size.x * 0.5, lunnopuh.size.y)
		simulation.escape_lunnopuh(escape_position.x - lunnopuh_home_position.x, escape_position.y - lunnopuh_home_position.y)
		_apply_visual_state(true)
		game_state.set_job_repair_state(game_state.active_job_id, simulation.get_state())
		game_state.save_autosave()


func _on_action_impact(action_id: StringName) -> void:
	if selected_object_id == &"lunnopuh" and action_id in [&"return_lunnopuh", &"catch_lunnopuh"]:
		_animate_lunnopuh_transfer(action_id)
		return
	if game_state.employees[selected_employee_id].get("actor_action_style", &"magic") == &"magic":
		_resolve_timed_action(action_id)
	else:
		if not _is_instant_physical_action(action_id):
			repair_hud.start_timed_action(selected_employee_id, action_id, _on_physical_timer_finished.bind(action_id))


func _animate_lunnopuh_return() -> void:
	_animate_lunnopuh_transfer(&"return_lunnopuh")


func _animate_lunnopuh_transfer(action_id: StringName) -> void:
	if returning_creature:
		return
	returning_creature = true
	if lunnopuh_motion != null and lunnopuh_motion.is_valid():
		lunnopuh_motion.kill()
	if action_id == &"return_lunnopuh" and str(simulation.world_object.get("lunnopuh_state", "absent")) == "caged":
		lunnopuh_cage.show_state(&"installed")
		lunnopuh.position = to_local(lunnopuh_cage.target_global_position()) - lunnopuh.size * 0.5
		lunnopuh.modulate.a = 1.0
		lunnopuh.visible = true
	lunnopuh_motion = create_tween()
	var target: Vector2 = lunnopuh_cage.target_global_position() if action_id == &"catch_lunnopuh" else portal_mirror.target_global_position()
	var destination := to_local(target) - lunnopuh.size * 0.5
	lunnopuh_motion.tween_property(lunnopuh, "position", lunnopuh.position + Vector2(0, -75), 0.35)
	lunnopuh_motion.tween_property(lunnopuh, "position", destination, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	lunnopuh_motion.tween_property(lunnopuh, "modulate:a", 0.0, 0.3)
	await lunnopuh_motion.finished
	employee_actor.set_persistent_work_pose(false)
	returning_creature = false
	_resolve_timed_action(action_id)
	action_in_progress = false
	portal_mirror.set_interaction_enabled(true)


func _on_physical_timer_finished(action_id: StringName) -> void:
	physical_timer_finished = true
	_try_resolve_physical_action(action_id)


func _try_resolve_physical_action(action_id: StringName) -> void:
	if action_id != pending_physical_action or not physical_timer_finished or not physical_impact_reached:
		return
	pending_physical_action = &""
	physical_timer_finished = false
	physical_impact_reached = false
	_resolve_timed_action(action_id)
	action_in_progress = false
	portal_mirror.set_interaction_enabled(true)


func _resolve_timed_action(action_id: StringName) -> void:
	simulation.pending_actor_action = {}
	if selected_object_id == &"lunnopuh":
		simulation.world_object["cage_available"] = game_state.has_supply_item(&"lunnopuh_cage")
		var creature_result := simulation.apply_lunnopuh_action(selected_employee_id, action_id)
		game_state.set_job_repair_state(game_state.active_job_id, simulation.get_state())
		game_state.save_autosave()
		_apply_visual_state()
		if action_id == &"diagnose":
			repair_hud.queue_dialogue("Результат осмотра", str(creature_result["message"]), bool(creature_result["warning"]))
		else:
			var after_reaction := simulation.lunnopuh_reaction(action_id, true, selected_employee_id)
			if not after_reaction.is_empty():
				repair_hud.show_employee_reaction(selected_employee_id, after_reaction)
			elif str(creature_result["message"]) != last_action_intro:
				repair_hud.show_system_message(str(creature_result["message"]), bool(creature_result["warning"]))
		return
	var portal_was_open := bool(simulation.world_object.get("portal_open", true))
	var previous_damage := int(simulation.world_object.get("damage", 0))
	var result: Dictionary = simulation.install_cage(selected_employee_id, game_state.has_supply_item(&"lunnopuh_cage")) if action_id == &"install_cage" else simulation.apply_action(selected_employee_id, action_id, game_state.has_supply_item(&"protective_cloth"))
	if bool(result.get("applied", false)) and action_id == &"cover":
		game_state.consume_supply_item(&"protective_cloth")
	elif bool(result.get("applied", false)) and action_id == &"uncover":
		game_state.return_supply_item(&"protective_cloth")
	if bool(result.get("applied", false)):
		if action_id == &"install_cage":
			_play_audio_cue(&"play_trap_install")
		elif action_id == &"physical_move":
			_play_audio_cue(&"play_heavy_impact")
			_play_audio_cue(&"play_mirror_shatter")
		elif action_id == &"antimagic" and portal_was_open and not bool(simulation.world_object.get("portal_open", true)):
			_play_audio_cue(&"play_portal_close")
	game_state.set_job_repair_state(game_state.active_job_id, simulation.get_state())
	if action_id in [&"cover", &"uncover", &"install_cage"] and bool(result.get("applied", false)):
		game_state.save_autosave()
	_apply_visual_state()
	var resident_reaction: String = simulation.get_resident_reaction(action_id)
	var current_damage := int(simulation.world_object.get("damage", 0))
	if action_id == &"diagnose":
		repair_hud.show_dialogue("РЕЗУЛЬТАТ ОСМОТРА", str(result["message"]))
	elif _should_show_resident_damage_reaction(action_id, result, previous_damage, current_damage, resident_reaction):
		repair_hud.show_resident_dialogue(resident_reaction)
	elif action_id == &"heat":
		# Хозяйка реагирует на два реальных перехода: исчезновение холода и
		# первое повреждение рамы. Повторный огонь состояние уже не меняет.
		if bool(result.get("applied", false)) and previous_damage == 0 and current_damage <= 1 and not resident_reaction.is_empty():
			repair_hud.show_resident_dialogue(resident_reaction)
		else:
			repair_hud.clear_all_dialogues()
	elif not bool(result.get("applied", false)):
		_show_failed_action(result)
	elif action_id == &"freeze":
		if not bool(simulation.world_object.get("freeze_reaction_seen", false)) and not resident_reaction.is_empty():
			simulation.world_object["freeze_reaction_seen"] = true
			game_state.set_job_repair_state(game_state.active_job_id, simulation.get_state())
			repair_hud.show_resident_dialogue(resident_reaction)
		else:
			repair_hud.clear_all_dialogues()
	elif action_id == &"cover" and bool(result.get("applied", false)) and not resident_reaction.is_empty():
		repair_hud.show_resident_dialogue(resident_reaction)
	elif action_id == &"antimagic" and bool(result.get("applied", false)) and not resident_reaction.is_empty():
		repair_hud.show_resident_dialogue(resident_reaction)
	elif str(result.get("message", "")) != last_action_intro:
		repair_hud.show_system_message(str(result["message"]), bool(result["warning"]))
	else:
		repair_hud.clear_all_dialogues()


func _should_show_resident_damage_reaction(action_id: StringName, result: Dictionary, previous_damage: int, current_damage: int, resident_reaction: String) -> bool:
	return (
		action_id == &"physical_move"
		and bool(result.get("applied", false))
		and current_damage > previous_damage
		and not resident_reaction.is_empty()
	)


func _show_failed_action(result: Dictionary) -> void:
	var message := str(result.get("message", ""))
	if message == last_action_intro:
		repair_hud.clear_all_dialogues()
		return
	if message.begins_with("Действие не изменило"):
		repair_hud.show_employee_reaction(selected_employee_id, EmployeeReactionResolverScript.no_effect_for(selected_employee_id))
	else:
		repair_hud.show_system_message(message, true)


func _play_audio_cue(method: StringName) -> void:
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager != null and audio_manager.has_method(method):
		audio_manager.call(method)


func _resume_pending_action() -> void:
	selected_object_id = StringName(str(simulation.pending_actor_action.get("target_id", "portal_mirror")))
	simulation.interaction_target = selected_object_id
	var pending: Dictionary = game_state.get_pending_job_action(game_state.active_job_id)
	if pending.is_empty():
		pending = simulation.pending_actor_action.duplicate(true)
		if pending.is_empty():
			return
		selected_employee_id = StringName(str(pending.get("employee_id", "")))
		_configure_employee_actor()
		_begin_action(StringName(str(pending.get("action_id", ""))))
		return
	selected_employee_id = StringName(str(pending.get("employee_id", "")))
	_configure_employee_actor()
	var action_id := StringName(str(pending.get("action_id", "")))
	action_in_progress = true
	portal_mirror.set_interaction_enabled(false)
	pending_physical_action = action_id
	physical_timer_finished = false
	# После загрузки уже начатого действия не повторяем путь сотрудника с начала.
	physical_impact_reached = true
	repair_hud.resume_timed_action(_on_physical_timer_finished.bind(action_id))


func _on_action_finished() -> void:
	if pending_physical_action in [&"catch_hand", &"catch_into_cage"] and lunnopuh_motion != null and lunnopuh_motion.is_running():
		await lunnopuh_motion.finished
	if returning_creature:
		return
	if not pending_physical_action.is_empty():
		physical_impact_reached = true
		_try_resolve_physical_action(pending_physical_action)
		if not pending_physical_action.is_empty():
			return
	action_in_progress = false
	portal_mirror.set_interaction_enabled(true)


func _apply_visual_state(animate_creature: bool = false) -> void:
	portal_mirror.show_state(simulation.visual_state(), bool(simulation.world_object["cold_aura"]), bool(simulation.world_object.get("portal_silhouette", false)))
	var creature_state := str(simulation.world_object.get("lunnopuh_state", "absent"))
	lunnopuh.visible = creature_state == "free"
	if creature_state == "free":
		lunnopuh.modulate.a = 1.0
	var destination := lunnopuh_home_position + Vector2(float(simulation.world_object.get("lunnopuh_offset_x", 0.0)), float(simulation.world_object.get("lunnopuh_offset_y", 0.0)))
	if lunnopuh_motion != null and lunnopuh_motion.is_valid():
		lunnopuh_motion.kill()
	if animate_creature and lunnopuh.visible:
		lunnopuh_motion = create_tween()
		lunnopuh_motion.tween_property(lunnopuh, "position", destination, 1.1).set_trans(Tween.TRANS_SINE)
	else:
		lunnopuh.position = destination
	lunnopuh_cage.show_state(&"occupied" if creature_state == "caged" else StringName(str(simulation.world_object.get("cage_state", "packed"))))
	if repair_hud.has_method("set_completion_ready"):
		repair_hud.call("set_completion_ready", simulation.is_resolved())


func _attempt_complete_job() -> void:
	if action_in_progress or repair_hud.is_timed_action_active():
		return
	if not simulation.is_resolved():
		repair_hud.show_system_message("Работу нельзя завершить: портал нужно закрыть или изолировать, а свободного лунопуха — поймать либо вернуть в его мир." if str(simulation.world_object.get("lunnopuh_state", "absent")) == "free" else "Работу нельзя завершить: портал всё ещё открыт.", true)
		return
	if game_state.complete_active_job(simulation.get_completion_result()):
		get_tree().change_scene_to_file("res://scenes/main.tscn")


func _configure_room_button() -> void:
	var empty_style := StyleBoxEmpty.new()
	room_hotspot.add_theme_stylebox_override("normal", empty_style)
	room_hotspot.add_theme_stylebox_override("pressed", empty_style)
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(0.95, 0.65, 0.2, 0.08)
	hover_style.border_color = COLOR_GOLD
	hover_style.set_border_width_all(3)
	hover_style.set_corner_radius_all(8)
	room_hotspot.add_theme_stylebox_override("hover", hover_style)
	room_hotspot.add_theme_stylebox_override("focus", hover_style)


func _style_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = COLOR_PANEL
	normal.border_color = COLOR_GOLD
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(8)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.15, 0.10, 0.055, 0.98)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
