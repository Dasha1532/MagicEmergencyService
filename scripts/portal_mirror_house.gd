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
@onready var employee_actor: Control = $EmployeeActor
@onready var physical_approach: Marker2D = $PhysicalApproach
@onready var back_to_house_button: Button = $Interface/BackToHouseButton
@onready var tool_bar: Control = $Interface/ToolBar
@onready var repair_hud: Control = $Interface/RepairHUD
@onready var game_state: Node = get_node("/root/GameState")

var simulation: PortalMirrorSimulation
var selected_employee_id: StringName = &""
var action_in_progress: bool = false
var pending_dialogue_action: StringName = &""
var action_had_intro: bool = false
var freeze_resident_reaction_shown: bool = false
var pending_physical_action: StringName = &""
var physical_timer_finished: bool = false
var physical_impact_reached: bool = false


func _ready() -> void:
	if game_state.active_job_id != &"portal_mirror":
		get_tree().change_scene_to_file("res://scenes/main.tscn")
		return
	simulation = PortalMirrorSimulationScript.new()
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
	tool_bar.tool_selected.connect(_on_tool_selected)
	employee_actor.action_impact.connect(_on_action_impact)
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
		repair_hud.show_resident_dialogue(simulation.get_resident_request())


func _show_house_overview(animated: bool = true) -> void:
	overview_background.visible = true
	room_placement.visible = true
	fireplace_glow.visible = false
	portal_mirror.visible = false
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
	if action_in_progress:
		return
	if selected_employee_id.is_empty():
		repair_hud.show_system_message("Сначала выберите сотрудника из бригады.", true)
		return
	var employee: Dictionary = game_state.employees[selected_employee_id]
	var contextual_actions: Array[Dictionary] = []
	if selected_employee_id == &"boris":
		if bool(simulation.world_object.get("covered", false)):
			contextual_actions.append({"id": &"uncover", "label": "Снять защитное полотно"})
		else:
			contextual_actions.append({"id": &"cover", "label": "Закрыть защитным полотном"})
	tool_bar.configure_for_employee(str(employee["name"]), employee["abilities"], str(employee["core_actions"]))
	tool_bar.show_for_object("Зеркало", portal_mirror.target_global_position(), {
		&"diagnose": "Осмотреть",
		&"physical_move": "Разбить зеркало",
		&"telekinesis": "Сдвинуть зеркало",
		&"antimagic": "Закрыть портал",
		&"freeze": "Заморозить",
		&"heat": "Нагреть",
	}, contextual_actions, PackedStringArray(["repair", "animate"]))


func _on_tool_selected(action_id: StringName) -> void:
	if action_in_progress:
		return
	if repair_hud.is_timed_action_active():
		repair_hud.show_system_message("Сначала дождитесь завершения текущей работы.", true)
		return
	if not game_state.can_employee_work_on_job(selected_employee_id, game_state.active_job_id):
		repair_hud.show_system_message("Сотрудник ещё едет на объект. %s." % game_state.employees[selected_employee_id]["status"], true)
		return
	var employee: Dictionary = game_state.employees.get(selected_employee_id, {})
	var contextual: String = simulation.get_employee_reaction(selected_employee_id, action_id)
	if selected_employee_id == &"boris" and action_id == &"cover" and not game_state.has_supply_item(&"protective_cloth"):
		pending_dialogue_action = &""
		tool_bar.visible = false
		repair_hud.show_employee_reaction(selected_employee_id, "Могу закрыть зеркало защитным полотном, но у нас его нет. Полотно можно купить в лавке снабжения.")
		return
	if selected_employee_id == &"felix" and action_id == &"antimagic" and not bool(simulation.world_object["portal_open"]):
		pending_dialogue_action = &""
		tool_bar.visible = false
		if not repair_hud.show_employee_reaction(selected_employee_id, contextual):
			repair_hud.show_system_message(contextual, true)
			return
	if selected_employee_id == &"felix" and action_id == &"antimagic" and bool(simulation.world_object.get("covered", false)):
		pending_dialogue_action = &""
		tool_bar.visible = false
		if not repair_hud.show_employee_reaction(selected_employee_id, contextual):
			repair_hud.show_system_message(contextual, true)
		return
	var reaction: String = EmployeeReactionResolverScript.reaction_for(employee, action_id, simulation.world_object, &"", contextual)
	if not reaction.is_empty() and repair_hud.show_employee_reaction(selected_employee_id, reaction):
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
	# Повторно проверяем состояние после реплики: сохранённый или запоздавший
	# сигнал диалога не должен запускать уже недопустимое заклинание.
	if action_id == &"antimagic" and (not bool(simulation.world_object.get("portal_open", true)) or bool(simulation.world_object.get("covered", false))):
		pending_dialogue_action = &""
		action_had_intro = false
		return
	action_in_progress = true
	portal_mirror.set_interaction_enabled(false)
	tool_bar.visible = false
	var is_physical: bool = game_state.employees[selected_employee_id].get("actor_action_style", &"magic") == &"physical"
	var approach := physical_approach.position if is_physical else Vector2.INF
	if is_physical:
		pending_physical_action = action_id
		# Один удар по зеркалу выполняется сразу в момент попадания анимации
		# и не расходует две игровые минуты на условную долгую работу.
		physical_timer_finished = _is_instant_physical_action(action_id)
		physical_impact_reached = false
		if not physical_timer_finished:
			repair_hud.start_timed_action(selected_employee_id, action_id, _on_physical_timer_finished.bind(action_id))
	employee_actor.play_action(action_id, portal_mirror.target_global_position(), approach)


func _is_instant_physical_action(action_id: StringName) -> bool:
	return action_id == &"physical_move"


func _on_action_impact(action_id: StringName) -> void:
	if game_state.employees[selected_employee_id].get("actor_action_style", &"magic") == &"magic":
		_resolve_timed_action(action_id)
	else:
		physical_impact_reached = true
		_try_resolve_physical_action(action_id)


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


func _resolve_timed_action(action_id: StringName) -> void:
	var portal_was_open := bool(simulation.world_object.get("portal_open", true))
	var previous_damage := int(simulation.world_object.get("damage", 0))
	var result: Dictionary = simulation.apply_action(selected_employee_id, action_id, game_state.has_supply_item(&"protective_cloth"))
	if bool(result.get("applied", false)) and action_id == &"cover":
		game_state.consume_supply_item(&"protective_cloth")
	elif bool(result.get("applied", false)) and action_id == &"uncover":
		game_state.return_supply_item(&"protective_cloth")
	if bool(result.get("applied", false)):
		if action_id == &"physical_move":
			_play_audio_cue(&"play_heavy_impact")
			_play_audio_cue(&"play_mirror_shatter")
		elif action_id == &"antimagic" and portal_was_open and not bool(simulation.world_object.get("portal_open", true)):
			_play_audio_cue(&"play_portal_close")
	game_state.set_job_repair_state(game_state.active_job_id, simulation.get_state())
	if action_id in [&"cover", &"uncover"] and bool(result.get("applied", false)):
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
		if not freeze_resident_reaction_shown and not resident_reaction.is_empty():
			freeze_resident_reaction_shown = true
			repair_hud.show_resident_dialogue(resident_reaction)
		else:
			repair_hud.clear_all_dialogues()
	elif action_id == &"cover" and bool(result.get("applied", false)) and not resident_reaction.is_empty():
		repair_hud.show_resident_dialogue(resident_reaction)
	elif action_id == &"antimagic" and bool(result.get("applied", false)) and not resident_reaction.is_empty():
		repair_hud.show_resident_dialogue(resident_reaction)
	elif not action_had_intro:
		repair_hud.show_system_message(str(result["message"]), bool(result["warning"]))
	else:
		repair_hud.clear_all_dialogues()
	action_had_intro = false


func _should_show_resident_damage_reaction(action_id: StringName, result: Dictionary, previous_damage: int, current_damage: int, resident_reaction: String) -> bool:
	return (
		action_id == &"physical_move"
		and bool(result.get("applied", false))
		and current_damage > previous_damage
		and not resident_reaction.is_empty()
	)


func _show_failed_action(result: Dictionary) -> void:
	var message := str(result.get("message", ""))
	if message.begins_with("Действие не изменило"):
		repair_hud.show_employee_reaction(selected_employee_id, EmployeeReactionResolverScript.no_effect_for(selected_employee_id))
	else:
		repair_hud.show_system_message(message, true)


func _play_audio_cue(method: StringName) -> void:
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager != null and audio_manager.has_method(method):
		audio_manager.call(method)


func _resume_pending_action() -> void:
	var pending: Dictionary = game_state.get_pending_job_action(game_state.active_job_id)
	if pending.is_empty():
		return
	selected_employee_id = StringName(str(pending.get("employee_id", "")))
	_configure_employee_actor()
	var action_id := StringName(str(pending.get("action_id", "")))
	pending_physical_action = action_id
	physical_timer_finished = false
	# После загрузки уже начатого действия не повторяем путь сотрудника с начала.
	physical_impact_reached = true
	repair_hud.resume_timed_action(_on_physical_timer_finished.bind(action_id))


func _on_action_finished() -> void:
	action_in_progress = false
	portal_mirror.set_interaction_enabled(true)


func _apply_visual_state() -> void:
	portal_mirror.show_state(simulation.visual_state(), bool(simulation.world_object["cold_aura"]))
	if repair_hud.has_method("set_completion_ready"):
		repair_hud.call("set_completion_ready", simulation.is_resolved())


func _attempt_complete_job() -> void:
	if not simulation.is_resolved():
		repair_hud.show_system_message("Работу нельзя завершить: портал всё ещё открыт.", true)
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
