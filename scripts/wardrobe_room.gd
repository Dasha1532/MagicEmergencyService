extends Node2D

const WardrobeSimulationScript := preload("res://scripts/wardrobe_simulation.gd")
const EmployeeReactionResolverScript := preload("res://scripts/employee_reaction_resolver.gd")
const WARDROBE_STEPS := preload("res://assets/audio/skafhodit.wav")

const COLOR_PANEL := Color(0.07, 0.045, 0.03, 0.94)
const COLOR_GOLD := Color(0.96, 0.78, 0.46)
const COLOR_PARCHMENT := Color(0.92, 0.84, 0.69)

@export_group("Положение и размер шкафа")
@export var entrance_scale: Vector2 = Vector2.ONE
@export var left_wall_scale: Vector2 = Vector2(0.86, 0.86)
@export var kitchen_passage_scale: Vector2 = Vector2(0.68, 0.68)

@onready var overview_background: TextureRect = $Background
@onready var room_preview_backdrop: ColorRect = $RoomPreviewBackdrop
@onready var room_preview: TextureRect = $RoomPreview
@onready var room_hotspot: Button = $RoomHotspot
@onready var problem_room_marker: Panel = $ProblemRoomMarker
@onready var closeup_background: TextureRect = $RoomCloseup
@onready var wardrobe: Control = $Wardrobe
@onready var wardrobe_status_effects: Node2D = $Wardrobe/StatusEffects
@onready var left_wall_marker: Marker2D = $WardrobePositions/LeftWall
@onready var kitchen_passage_marker: Marker2D = _find_kitchen_passage_marker()
@onready var employee_actor: Control = $EmployeeActor
@onready var physical_approach: Marker2D = $PhysicalApproach
@onready var back_to_house_button: Button = $Interface/BackToHouseButton
@onready var tool_bar: Control = $Interface/ToolBar
@onready var repair_hud: Control = $Interface/RepairHUD
@onready var feedback_panel: Panel = $Interface/ActionFeedback
@onready var request_panel: Panel = $Interface/ResidentRequest
@onready var request_label: Label = $Interface/ResidentRequest/Message
@onready var crew_placement_guide: Control = get_node_or_null("CrewPlacementGuide") as Control
@onready var left_wall_guide: Control = get_node_or_null("WardrobePositions/LeftWall/PlacementGuide") as Control
@onready var center_wall_guide: Control = get_node_or_null("WardrobePositions/CenterWall/PlacementGuide") as Control
@onready var game_state: Node = get_node("/root/GameState")

var simulation: WardrobeSimulation
var selected_tool_id: StringName = &""
var selected_employee_id: StringName = &""
var pending_intent: StringName = &""
var action_in_progress: bool = false
var pending_dialogue_action: StringName = &""
var pending_dialogue_intent: StringName = &""
var action_had_intro: bool = false
var entrance_position: Vector2
var fire_progression_revision: int = 0
var wardrobe_steps_player: AudioStreamPlayer
var wardrobe_steps_enabled: bool = false
var long_action_pose: StringName = &""


func _ready() -> void:
	var active_job: Dictionary = game_state.get_active_job()
	var is_manual_wardrobe: bool = game_state.active_job_id == &"walking_wardrobe"
	var is_generated_wardrobe: bool = StringName(str(active_job.get("simulation_type", ""))) == &"generated_wardrobe"
	if not is_manual_wardrobe and not is_generated_wardrobe:
		get_tree().change_scene_to_file("res://scenes/main.tscn")
		return
	simulation = WardrobeSimulationScript.new()
	wardrobe_steps_player = AudioStreamPlayer.new()
	wardrobe_steps_player.stream = WARDROBE_STEPS
	wardrobe_steps_player.volume_db = linear_to_db(1.5)
	wardrobe_steps_player.finished.connect(_on_wardrobe_steps_finished)
	add_child(wardrobe_steps_player)
	var saved_state: Dictionary = game_state.get_job_repair_state(game_state.active_job_id)
	if saved_state.is_empty():
		if is_generated_wardrobe:
			simulation.initialize_generated(active_job.get("generated_instance", {}))
		else:
			simulation.initialize_variant(hash("%s:%s" % [game_state.day, game_state.active_job_id]))
	else:
		simulation.load_state(saved_state)
	# Начальное положение берётся непосредственно из сохранённого узла Wardrobe.
	entrance_position = wardrobe.position
	if crew_placement_guide != null:
		crew_placement_guide.visible = false
	if left_wall_guide != null:
		left_wall_guide.visible = false
	if center_wall_guide != null:
		center_wall_guide.visible = false
	$Interface/PhysicalIntentPanel.visible = false
	_configure_room_button()
	room_hotspot.pressed.connect(_open_room)
	back_to_house_button.pressed.connect(_show_house_overview)
	wardrobe.selected.connect(_on_wardrobe_selected)
	tool_bar.tool_selected.connect(_on_tool_selected)
	tool_bar.intent_selected.connect(_on_context_intent_selected)
	repair_hud.employee_selected.connect(_on_employee_selected)
	repair_hud.completion_requested.connect(_attempt_complete_job)
	repair_hud.long_action_started.connect(_on_long_action_started)
	repair_hud.long_action_finished.connect(_on_long_action_finished)
	repair_hud.dialogue_finished.connect(_on_pre_action_dialogue_finished)
	employee_actor.action_impact.connect(_on_employee_action_impact)
	employee_actor.action_finished.connect(_on_employee_action_finished)
	selected_tool_id = tool_bar.get_selected_tool_id()
	selected_employee_id = repair_hud.get_selected_employee_id()
	_configure_employee_actor()
	_restore_visual_state()
	_resume_pending_action()
	if bool(simulation.world_object["burning"]):
		_start_fire_progression()
	call_deferred("_open_room")


func _exit_tree() -> void:
	# Отменяем отложенное распространение огня до удаления комнаты.
	fire_progression_revision += 1
	_set_wardrobe_steps_playing(false)


func _find_kitchen_passage_marker() -> Marker2D:
	var marker: Marker2D = get_node_or_null("WardrobePositions/KitchenPassage") as Marker2D
	if marker == null:
		marker = get_node("WardrobePositions/CenterWall") as Marker2D
	return marker


func _on_long_action_started(employee_id: StringName) -> void:
	long_action_pose = _persistent_pose_for_action(selected_tool_id, pending_intent)
	if employee_id == selected_employee_id and employee_actor.visible and not long_action_pose.is_empty():
		employee_actor.call("set_persistent_action_pose", long_action_pose)


func _on_long_action_finished(employee_id: StringName) -> void:
	if employee_id == selected_employee_id and not long_action_pose.is_empty():
		employee_actor.call("set_persistent_action_pose", &"")
	long_action_pose = &""


func _persistent_pose_for_action(action_id: StringName, intent: StringName) -> StringName:
	if action_id != &"physical_move":
		return &"work"
	if intent == &"break_legs":
		return &"work"
	if intent in [&"hold", &"move_left", &"move_kitchen", &"release"]:
		return &"hold"
	return &""


func _open_room() -> void:
	room_hotspot.disabled = true
	room_hotspot.visible = false
	problem_room_marker.visible = false
	closeup_background.visible = true
	closeup_background.modulate = Color(1, 1, 1, 0)
	wardrobe.visible = true
	wardrobe.self_modulate = Color(1, 1, 1, 0)
	employee_actor.visible = _configure_employee_actor()
	employee_actor.self_modulate = Color(1, 1, 1, 0)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(closeup_background, "modulate", Color.WHITE, 0.24)
	tween.tween_property(wardrobe, "self_modulate", Color.WHITE, 0.24)
	if employee_actor.visible:
		tween.tween_property(employee_actor, "self_modulate", Color.WHITE, 0.24)
	await tween.finished
	overview_background.visible = false
	room_preview_backdrop.visible = false
	room_preview.visible = false
	back_to_house_button.visible = false
	tool_bar.visible = false
	$Interface/PhysicalIntentPanel.visible = false
	if repair_hud.has_method("set_work_ui_visible"):
		repair_hud.call("set_work_ui_visible", true)
	repair_hud.clear_all_dialogues()
	request_panel.visible = false
	if not bool(simulation.world_object.get("resident_intro_seen", false)):
		simulation.world_object["resident_intro_seen"] = true
		game_state.set_job_repair_state(game_state.active_job_id, simulation.get_state())
		repair_hud.show_resident_dialogue(game_state.get_resident_greeting(game_state.active_job_id, simulation.get_resident_request()))
	feedback_panel.visible = false
	_sync_wardrobe_steps()


func _show_house_overview(animated: bool = true) -> void:
	_set_wardrobe_steps_playing(false)
	overview_background.visible = true
	room_preview_backdrop.visible = true
	room_preview.visible = true
	room_hotspot.visible = true
	room_hotspot.disabled = false
	problem_room_marker.visible = not simulation.is_resolved()
	wardrobe.visible = false
	employee_actor.visible = false
	back_to_house_button.visible = false
	tool_bar.visible = false
	if repair_hud.has_method("set_work_ui_visible"):
		repair_hud.call("set_work_ui_visible", false)
	request_panel.visible = false
	feedback_panel.visible = false
	$Interface/PhysicalIntentPanel.visible = false
	if not animated:
		closeup_background.visible = false
		return
	var tween: Tween = create_tween()
	tween.tween_property(closeup_background, "modulate", Color(1, 1, 1, 0), 0.24)
	await tween.finished
	closeup_background.visible = false
	closeup_background.modulate = Color.WHITE


func _configure_room_button() -> void:
	var empty_style: StyleBoxEmpty = StyleBoxEmpty.new()
	room_hotspot.add_theme_stylebox_override("normal", empty_style)
	room_hotspot.add_theme_stylebox_override("pressed", empty_style)
	room_hotspot.add_theme_stylebox_override("focus", empty_style)
	var room_hover: StyleBoxFlat = StyleBoxFlat.new()
	room_hover.bg_color = Color(1.0, 0.42, 0.08, 0.08)
	room_hover.border_color = Color(1.0, 0.68, 0.24, 0.88)
	room_hover.set_border_width_all(3)
	room_hover.set_corner_radius_all(12)
	room_hotspot.add_theme_stylebox_override("hover", room_hover)
	back_to_house_button.add_theme_font_size_override("font_size", 17)
	back_to_house_button.add_theme_color_override("font_color", COLOR_PARCHMENT)
	back_to_house_button.add_theme_stylebox_override("normal", _panel_style(COLOR_PANEL, Color(0.76, 0.54, 0.27), 2))
	back_to_house_button.add_theme_stylebox_override("hover", _panel_style(Color(0.21, 0.14, 0.075, 0.98), COLOR_GOLD, 3))
	var problem_style: StyleBoxFlat = _panel_style(Color(0.15, 0.08, 0.025, 0.08), COLOR_GOLD, 3)
	problem_style.shadow_color = Color(1.0, 0.58, 0.12, 0.24)
	problem_style.shadow_size = 10
	problem_room_marker.add_theme_stylebox_override("panel", problem_style)


func _panel_style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(12)
	return style


func _on_tool_selected(tool_id: StringName) -> void:
	if repair_hud.is_timed_action_active():
		_show_feedback("Сначала дождитесь завершения текущей работы.", true)
		return
	if not game_state.can_employee_work_on_job(selected_employee_id, game_state.active_job_id):
		_show_feedback(tr("Сотрудник ещё едет на объект. %s.") % tr(str(game_state.employees[selected_employee_id]["status"])), true)
		return
	selected_tool_id = tool_id
	if tool_id == &"physical_move":
		tool_bar.show_intents("Силовая работа", [
			{"id": &"hold", "label": "Отпустить" if bool(simulation.world_object.get("held", false)) else "Удерживать"},
			{"id": &"move_left", "label": _move_label(&"left_wall")},
			{"id": &"move_kitchen", "label": _move_label(&"kitchen_passage")},
			{"id": &"break_legs", "label": "Сломать ножки"},
		])
		return
	if tool_id == &"telekinesis":
		tool_bar.show_intents("Куда переместить?", [
			{"id": &"move_left", "label": _move_label(&"left_wall")},
			{"id": &"move_kitchen", "label": _move_label(&"kitchen_passage")},
		])
		return
	tool_bar.visible = false
	pending_intent = &""
	_request_action()


func _move_label(zone_id: StringName) -> String:
	var requested: bool = zone_id == simulation.world_object["requested_zone"]
	var label := "К левой стене" if zone_id == &"left_wall" else "В проход на кухню"
	return "%s %s" % [tr(label), tr("(просьба хозяйки)")] if requested else tr(label)


func _on_employee_selected(employee_id: StringName) -> void:
	selected_employee_id = employee_id
	tool_bar.visible = false
	_configure_employee_actor()


func _configure_employee_actor() -> bool:
	if selected_employee_id.is_empty() or not game_state.employees.has(selected_employee_id):
		employee_actor.visible = false
		return false
	employee_actor.visible = employee_actor.configure_employee(selected_employee_id, game_state.employees[selected_employee_id])
	if employee_actor.visible and selected_employee_id == &"grog" and bool(simulation.world_object.get("held", false)):
		employee_actor.call("restore_hold_pose", _wardrobe_approach_position(&"hold"), 20)
	return employee_actor.visible


func _on_wardrobe_selected() -> void:
	if action_in_progress:
		return
	if selected_employee_id.is_empty():
		_show_feedback("Сначала выберите сотрудника из бригады.", true)
		return
	var contextual_actions: Array[Dictionary] = []
	var employee: Dictionary = game_state.employees.get(selected_employee_id, {})
	var abilities: PackedStringArray = employee.get("abilities", PackedStringArray())
	if abilities.has("repair"):
		contextual_actions.append({"id": &"anchor", "label": "Закрепить у стены"})
	tool_bar.show_for_object("Шкаф", _wardrobe_target_global(), {}, contextual_actions)


func _on_context_intent_selected(intent: StringName) -> void:
	pending_intent = &"release" if selected_tool_id == &"physical_move" and intent == &"hold" and bool(simulation.world_object.get("held", false)) else intent
	_request_action()


func _request_action() -> void:
	var employee: Dictionary = game_state.employees.get(selected_employee_id, {})
	var contextual: String = simulation.get_employee_reaction(selected_employee_id, selected_tool_id, pending_intent)
	if selected_employee_id == &"liliya" and selected_tool_id in [&"freeze", &"heat"] and bool(simulation.world_object["destroyed"]):
		if not repair_hud.show_employee_reaction(selected_employee_id, contextual):
			_show_feedback(contextual, true)
		return
	if selected_employee_id == &"boris" and selected_tool_id == &"anchor" and simulation.world_object["position_zone"] != simulation.world_object["requested_zone"]:
		if not repair_hud.show_employee_reaction(selected_employee_id, contextual):
			_show_feedback(contextual, true)
		return
	if selected_employee_id == &"boris" and selected_tool_id == &"repair" and int(simulation.world_object["mobility"]) > 0 and not bool(simulation.world_object["destroyed"]):
		if not repair_hud.show_employee_reaction(selected_employee_id, contextual):
			_show_feedback(contextual, true)
		return
	var reaction: String = EmployeeReactionResolverScript.reaction_for(employee, selected_tool_id, simulation.world_object, pending_intent, contextual)
	if not reaction.is_empty() and repair_hud.show_employee_reaction(selected_employee_id, reaction):
		pending_dialogue_action = selected_tool_id
		pending_dialogue_intent = pending_intent
		return
	action_had_intro = false
	_start_action()


func _on_pre_action_dialogue_finished() -> void:
	if pending_dialogue_action.is_empty():
		return
	selected_tool_id = pending_dialogue_action
	pending_intent = pending_dialogue_intent
	pending_dialogue_action = &""
	pending_dialogue_intent = &""
	action_had_intro = true
	_start_action()


func _start_action() -> void:
	action_in_progress = true
	wardrobe.set_interaction_enabled(false)
	if not simulation.can_begin_action(selected_tool_id):
		_resolve_action(selected_tool_id, pending_intent)
		_on_employee_action_finished()
		return
	if employee_actor.visible:
		var is_physical: bool = game_state.employees[selected_employee_id].get("actor_action_style", &"magic") == &"physical"
		var uses_hold_pose: bool = pending_intent in [&"hold", &"move_left", &"move_kitchen", &"release"]
		var pushes_from_behind: bool = pending_intent in [&"move_left", &"move_kitchen"]
		var action_pose: StringName = &"hold" if uses_hold_pose else (&"neutral" if selected_tool_id == &"diagnose" else &"work")
		if is_physical:
			var duration: int = game_state.get_action_duration(selected_tool_id, pending_intent)
			if game_state.start_job_action(game_state.active_job_id, selected_employee_id, selected_tool_id, pending_intent, duration):
				repair_hud.resume_timed_action(_resolve_action.bind(selected_tool_id, pending_intent))
				game_state.set_clock_paused(false)
		employee_actor.play_action(
			selected_tool_id,
			_wardrobe_target_global(),
			_wardrobe_approach_position(pending_intent),
			action_pose,
			pending_intent == &"hold",
			5 if pushes_from_behind else 20
		)
	else:
		_resolve_action(selected_tool_id, pending_intent)
		_on_employee_action_finished()


func _on_employee_action_impact(action_id: StringName) -> void:
	if game_state.employees[selected_employee_id].get("actor_action_style", &"magic") == &"magic":
		_resolve_action(action_id, pending_intent)


func _resume_pending_action() -> void:
	var pending: Dictionary = game_state.get_pending_job_action(game_state.active_job_id)
	if pending.is_empty():
		return
	selected_employee_id = StringName(str(pending.get("employee_id", "")))
	selected_tool_id = StringName(str(pending.get("action_id", "")))
	pending_intent = StringName(str(pending.get("intent", "")))
	_configure_employee_actor()
	repair_hud.resume_timed_action(_resolve_action.bind(
		selected_tool_id,
		pending_intent
	))


func _on_employee_action_finished() -> void:
	action_in_progress = false
	pending_intent = &""
	wardrobe.set_interaction_enabled(true)


func _restore_grog_hold_pose_if_needed() -> void:
	if employee_actor.visible and selected_employee_id == &"grog" and bool(simulation.world_object.get("held", false)):
		employee_actor.call("restore_hold_pose", _wardrobe_approach_position(&"hold"), 20)


func _resolve_action(action_id: StringName, intent: StringName = &"") -> void:
	var was_burning: bool = bool(simulation.world_object["burning"])
	var previous_damage: int = int(simulation.world_object.get("damage", 0)) + int(simulation.world_object.get("contents_damage", 0))
	var result: Dictionary = simulation.apply_action(selected_employee_id, action_id, intent)
	if bool(result.get("applied", false)) and action_id == &"physical_move":
		if intent in [&"move_left", &"move_kitchen"]:
			_play_audio_cue(&"play_wardrobe_move")
		elif intent == &"break_legs":
			_play_audio_cue(&"play_heavy_impact")
			_play_audio_cue(&"play_breaking_wood")
	_apply_visual_state()
	_restore_grog_hold_pose_if_needed()
	var resident_message: String = simulation.get_resident_reaction()
	var damage_now: int = int(simulation.world_object.get("damage", 0)) + int(simulation.world_object.get("contents_damage", 0))
	if action_id == &"diagnose":
		repair_hud.show_dialogue("РЕЗУЛЬТАТ ОСМОТРА", str(result["message"]))
	elif damage_now > previous_damage and not resident_message.is_empty():
		repair_hud.show_resident_dialogue(resident_message)
	elif not bool(result["applied"]):
		_show_failed_action(result)
	elif not action_had_intro:
		_show_feedback(str(result["message"]), bool(result.get("warning", false)))
	else:
		repair_hud.clear_all_dialogues()
	action_had_intro = false
	repair_hud.set_completion_ready(bool(result["resolved"]))
	game_state.set_job_repair_state(game_state.active_job_id, simulation.get_state())
	var is_burning: bool = bool(simulation.world_object["burning"])
	if is_burning and not was_burning:
		_start_fire_progression()
	elif not is_burning and was_burning:
		fire_progression_revision += 1
		simulation.world_object["next_fire_spread_at"] = -1
		game_state.set_job_repair_state(game_state.active_job_id, simulation.get_state())


func _show_failed_action(result: Dictionary) -> void:
	var message := str(result.get("message", ""))
	if message.begins_with("Это действие не изменило"):
		repair_hud.show_employee_reaction(selected_employee_id, EmployeeReactionResolverScript.no_effect_for(selected_employee_id))
	else:
		_show_feedback(message, true)


func _play_audio_cue(method: StringName) -> void:
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager != null and audio_manager.has_method(method):
		audio_manager.call(method)


func _start_fire_progression() -> void:
	fire_progression_revision += 1
	simulation.start_burning_clock(game_state.time_minutes, game_state.WARDROBE_FIRE_SPREAD_MINUTES)
	game_state.set_job_repair_state(game_state.active_job_id, simulation.get_state())
	_schedule_fire_step(fire_progression_revision)


func _schedule_fire_step(revision: int) -> void:
	if not _can_continue_fire_progression(revision):
		return
	while _can_continue_fire_progression(revision):
		var previous_resident_message: String = simulation.get_resident_reaction()
		var results: Array[Dictionary] = simulation.advance_burning_until(game_state.time_minutes, game_state.WARDROBE_FIRE_SPREAD_MINUTES)
		if not results.is_empty():
			for result: Dictionary in results:
				for audio_cue: String in result.get("audio_cues", PackedStringArray()):
					_play_audio_cue(StringName(audio_cue))
			_apply_visual_state()
			var latest_result: Dictionary = results[-1]
			if bool(simulation.world_object["destroyed"]):
				_show_feedback(str(latest_result["message"]), true)
				var resident_message: String = simulation.get_resident_reaction()
				if resident_message != previous_resident_message:
					repair_hud.queue_resident_dialogue(resident_message)
			repair_hud.set_completion_ready(bool(latest_result["resolved"]))
			game_state.set_job_repair_state(game_state.active_job_id, simulation.get_state())
			if not _can_continue_fire_progression(revision):
				return
		if not _can_continue_fire_progression(revision):
			return
		var scene_tree := get_tree()
		if scene_tree == null:
			return
		await scene_tree.process_frame


func _can_continue_fire_progression(revision: int) -> bool:
	return (
		is_inside_tree()
		and revision == fire_progression_revision
		and simulation != null
		and bool(simulation.world_object.get("burning", false))
	)


func _restore_visual_state() -> void:
	_apply_visual_state()
	repair_hud.set_completion_ready(simulation.is_resolved())


func _apply_visual_state() -> void:
	wardrobe.show_state(StringName(str(simulation.world_object["visual_state"])))
	wardrobe_status_effects.call("sync_from_state", simulation.world_object)
	request_label.text = simulation.get_resident_message()
	var zone: StringName = StringName(str(simulation.world_object["position_zone"]))
	var target_position: Vector2 = {
		&"entrance": entrance_position,
		&"left_wall": left_wall_marker.position,
		&"kitchen_passage": kitchen_passage_marker.position,
	}.get(zone, entrance_position)
	var target_scale: Vector2 = {
		&"entrance": entrance_scale,
		&"left_wall": left_wall_scale,
		&"kitchen_passage": kitchen_passage_scale,
	}.get(zone, entrance_scale)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(wardrobe, "position", target_position, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(wardrobe, "scale", target_scale, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_sync_wardrobe_steps()


func _sync_wardrobe_steps() -> void:
	var should_play := closeup_background.visible and wardrobe.visible and bool(simulation.world_object.get("moving", false))
	_set_wardrobe_steps_playing(should_play)


func _set_wardrobe_steps_playing(enabled: bool) -> void:
	if wardrobe_steps_player == null:
		return
	wardrobe_steps_enabled = enabled
	if enabled and not wardrobe_steps_player.playing:
		wardrobe_steps_player.play()
	elif not enabled and wardrobe_steps_player.playing:
		wardrobe_steps_player.stop()


func _on_wardrobe_steps_finished() -> void:
	if wardrobe_steps_enabled and wardrobe_steps_player != null:
		wardrobe_steps_player.play()


func _wardrobe_target_global() -> Vector2:
	return wardrobe_status_effects.global_position


func _wardrobe_approach_position(intent: StringName) -> Vector2:
	# Горизонтальная точка следует за текущим положением и масштабом шкафа.
	# Для удержания и толкания ладони совмещаются с правой боковой стенкой.
	# Для поломки Грог остаётся ближе к передней части и ножкам.
	var wardrobe_width: float = wardrobe.size.x * wardrobe.scale.x
	var contact_ratio: float = 0.53 if intent in [&"hold", &"release", &"move_left", &"move_kitchen"] else 0.25
	return Vector2(wardrobe.position.x + wardrobe_width * contact_ratio, physical_approach.position.y)


func _attempt_complete_job() -> void:
	if not simulation.is_resolved():
		_show_feedback("Работу нельзя завершить: шкаф всё ещё ходит или перекрывает вход.", true)
		return
	if game_state.complete_active_job(simulation.get_completion_result()):
		get_tree().change_scene_to_file("res://scenes/main.tscn")


func _show_feedback(message: String, is_warning: bool = false) -> void:
	feedback_panel.visible = false
	repair_hud.show_system_message(message, is_warning)
