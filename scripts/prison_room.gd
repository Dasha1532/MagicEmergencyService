extends Control

const Simulation := preload("res://scripts/prison_simulation.gd")
const Definition := preload("res://data/prison/prison.tres")
var simulation := Simulation.new()
var current_room := "office"
var control_panel_clock_was_paused := true
var dialogue_open := false
var dialogue_clock_was_paused := true
@onready var game_state: Node = get_node("/root/GameState")
var finish_button: Button
var repair_hud: Control
var tool_bar: MarginContainer
var dialogue_portrait_frame: Panel
var dialogue_portrait: TextureRect
var employee_actor: Control
var actor_placement: Control
var action_in_progress := false
const Dialogue := preload("res://scripts/prison_dialogue.gd")
var selected_employee_id := "boris"
var dialogue_employee_id := ""
var dialogue_crew := PackedStringArray()
var lines: Array[Dictionary] = []
var line_index := 0
var dialogue_section := ""
var dialogue_panel: Panel
var speaker_label: Label
var speech_label: Label
var next_button: Button
var question_button: Button
var conversation_choice: PanelContainer
@onready var office: Control = $Office
@onready var cells: Control = $Cells
@onready var mysterious_girl: TextureRect = $Cells/MysteriousGirl
@onready var pain: TextureRect = $Cells/MysteriousGirlPain
@onready var talk: Control = $Cells/Talk
@onready var portrait: Control = $Portrait
@onready var record: Panel = $Record

signal state_changed(properties: Dictionary)
signal conversation_requested(character_id: StringName)
signal repair_finished(properties: Dictionary)

func _ready() -> void:
	simulation.initialize(Definition)
	if game_state.active_job_id != &"prison_lock":
		get_tree().change_scene_to_file("res://scenes/main.tscn")
		return
	var saved: Dictionary = game_state.get_job_repair_state(&"prison_lock")
	if not saved.is_empty():
		simulation.load_state(saved)
	_build_employee_actor()
	_build_work_interface()
	$Office/ToCells.pressed.connect(show_room.bind("cells"))
	$Cells/ToOffice.pressed.connect(show_room.bind("office"))
	$Office/Book.pressed.connect(_read_record)
	$Office/Archive.pressed.connect(_read_record)
	$Cells/Circuit.pressed.connect(_open_circuit_view)
	$CircuitView/Close.pressed.connect(_close_circuit_view)
	$Record/Close.pressed.connect(func() -> void:
		record.hide()
		_refresh()
	)
	talk.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_show_actions("girl")
	)
	_build_dialogue_interface()
	_setup_modal_windows()
	$Office/ProtectionBox.pressed.connect(_open_control_panel)
	$ProtectionPanel.closed.connect(_close_control_panel)
	show_room("office")
	if repair_hud.is_timed_action_active():
		var pending: Dictionary = game_state.get_pending_job_action(&"prison_lock")
		selected_employee_id = str(pending.get("employee_id", "boris"))
		repair_hud.selected_employee_id = StringName(selected_employee_id)
		show_room("cells")
		var step := "inspect" if str(pending.get("action_id", "")) == "diagnose" else ("finish_repair" if bool(simulation.state["escaped"]) else "repair_mechanism")
		action_in_progress = true
		_configure_employee_actor()
		employee_actor.set_persistent_work_pose(true)
		repair_hud.resume_timed_action(perform_action.bind(step))
	if not action_in_progress:
		_configure_employee_actor()
	if not bool(simulation.state.get("arrival_seen", false)):
		simulation.state["arrival_seen"] = true
		_save_campaign()
		_begin_dialogue("arrival", false)
	elif not repair_hud.is_timed_action_active() and simulation.state.get("pending_prison_action") is Dictionary:
		var interrupted: Dictionary = simulation.state["pending_prison_action"]
		selected_employee_id = str(interrupted.get("employee_id", selected_employee_id))
		_configure_employee_actor()
		show_room("cells")
		_request_action.call_deferred(str(interrupted.get("action_id", "")))

func show_room(room_id: String) -> void:
	if dialogue_open or (action_in_progress and is_node_ready()) or room_id not in ["office", "cells"]:
		return
	tool_bar.hide()
	current_room = room_id
	actor_placement.scale = Vector2(0.85, 0.85) if room_id == "office" else Vector2(0.65, 0.65)
	actor_placement.position = Vector2(300, 160) if room_id == "office" else Vector2(220, 260)
	employee_actor.position = Vector2.ZERO
	employee_actor.home_position = Vector2.ZERO
	employee_actor.employee_positions.clear()
	office.visible = room_id == "office"
	cells.visible = room_id == "cells"
	record.hide()
	_close_conversation()

func perform_action(action_id: String) -> bool:
	if dialogue_open or record.visible or not _actor_allowed(action_id):
		return false
	action_in_progress = false
	employee_actor.set_persistent_work_pose(false)
	simulation.state.erase("pending_prison_action")
	if not simulation.apply(action_id):
		return false
	_refresh()
	_save_campaign()
	state_changed.emit(simulation.state.duplicate(true))
	if bool(simulation.state["repair_completed"]):
		repair_finished.emit(simulation.state.duplicate(true))
	if action_id == "antimagic":
		_play_escape_cutscene(selected_employee_id)
	elif action_id in ["test_protection", "stop_test"]:
		_begin_dialogue(action_id, false)
	elif not str(Definition.actions[action_id].get("result", "")).is_empty():
		_begin_dialogue("result", false)
		var result_speaker := str(Definition.actions[action_id].get("speaker", ""))
		if result_speaker == "selected":
			result_speaker = selected_employee_id
		lines = [{"speaker": result_speaker, "text": str(Definition.actions[action_id]["result"])}]
		line_index = 0
		_show_line()
	return true

func _read_record() -> void:
	if dialogue_open or action_in_progress:
		return
	simulation.apply("read_record")
	_save_campaign()
	var entry: Dictionary = Definition.prisoner_record
	$Record/Text.text = "ДЕЛО ЗАКЛЮЧЁННОЙ\n\nИмя: %s.\n\nОснование содержания под стражей: %s\n\nПриметы: %s\n\nИзвестная способность: %s\n\nМеры предосторожности: %s" % [entry["name"], entry["accusation"], entry["appearance"], entry["ability"], entry["precautions"]]
	record.show()
	_refresh()

func _open_conversation() -> void:
	if dialogue_open or action_in_progress or not bool(simulation.state["conversation_unlocked"]) or bool(simulation.state["escaped"]) or bool(simulation.state["reverse_feedback"]):
		return
	if _available_crew().is_empty():
		repair_hud.show_system_message("Для разговора нужен сотрудник, прибывший на заявку.")
		return
	_begin_dialogue("conversation", true)
	if bool(simulation.state.get("conversation_seen", false)):
		_show_conversation_choice()
	conversation_requested.emit(&"mysterious_girl")

func _close_conversation() -> void:
	if dialogue_open:
		game_state.clock_paused = dialogue_clock_was_paused
	dialogue_open = false
	if conversation_choice != null:
		conversation_choice.hide()
	portrait.hide()
	if dialogue_panel != null:
		dialogue_panel.hide()
	if repair_hud != null:
		repair_hud.employee_panel.visible = not record.visible
	_refresh()

func _refresh() -> void:
	var state: Dictionary = simulation.state
	if finish_button != null:
		finish_button.visible = not dialogue_open and not record.visible
		finish_button.disabled = not bool(state.get("repair_completed", false))
	if repair_hud != null:
		repair_hud.employee_panel.visible = not dialogue_open and not record.visible
		repair_hud._refresh_employee_states()
		for button: Button in repair_hud.employee_buttons.values():
			button.disabled = button.disabled or action_in_progress
	var escaped := bool(state.get("escaped", false))
	var hurting := bool(state.get("reverse_feedback", false))
	mysterious_girl.texture = load("res://assets/prison/mysterious_girl_open_pose.png" if bool(state.get("conversation_seen", false)) else "res://assets/prison/mysterious_girl_idle.png")
	mysterious_girl.visible = not escaped and not hurting
	pain.visible = not escaped and hurting
	talk.visible = not escaped and not hurting and bool(state.get("conversation_unlocked", false))

func get_state() -> Dictionary:
	return simulation.get_state()

func load_state(saved: Dictionary) -> bool:
	var loaded := simulation.load_state(saved)
	if loaded:
		_refresh()
	return loaded

func _save_campaign() -> void:
	game_state.set_job_repair_state(&"prison_lock", simulation.get_state())
	game_state.save_autosave()

func _leave() -> void:
	_save_campaign()
	game_state.leave_active_job()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _complete() -> void:
	if dialogue_open or record.visible or not bool(simulation.state["repair_completed"]):
		return
	var escaped := bool(simulation.state["escaped"])
	var summary := "Замок и магическая защита восстановлены. "
	summary += "Заключённая прошла сквозь закрытую решётку и сбежала. Охранник подтвердил согласованное отключение защиты. На руке сотрудника осталась неизвестная печать." if escaped else "Заключённая осталась в клетке. Защита исправлена с помощью тюремного специалиста."
	_save_campaign()
	if game_state.complete_active_job({"summary": summary, "compensation_cost": 0, "reputation_change": 0, "consequences": ["Неизвестная печать на руке"] if escaped else []}):
		get_tree().change_scene_to_file("res://scenes/main.tscn")

func _available_crew() -> PackedStringArray:
	var crew := PackedStringArray()
	for employee_id: String in game_state.get_active_job().get("assigned", PackedStringArray()):
		if game_state.can_employee_work_on_job(StringName(employee_id), &"prison_lock"):
			crew.append(employee_id)
	return crew

func _employee_name(id: String) -> String:
	if id == "guard":
		return "Охранник"
	if id == "girl":
		return "Заключённая"
	return str(game_state.employees.get(StringName(id), {}).get("name", id))

func _build_dialogue_interface() -> void:
	dialogue_panel = repair_hud.employee_reaction_panel
	speaker_label = repair_hud.employee_reaction_heading
	speech_label = repair_hud.employee_reaction_label
	dialogue_portrait_frame = repair_hud.dialogue_portrait_frame
	dialogue_portrait = repair_hud.dialogue_portrait
	next_button = dialogue_panel.get_node("CloseButton")
	next_button.tooltip_text = ""
	next_button.pressed.disconnect(repair_hud.clear_employee_reaction)
	next_button.pressed.connect(_next_line)
	conversation_choice = PanelContainer.new()
	conversation_choice.name = "ConversationChoice"
	conversation_choice.position = Vector2(230, 800)
	conversation_choice.size = Vector2(1140, 70)
	conversation_choice.add_theme_stylebox_override("panel", repair_hud._style(Color(0.035, 0.035, 0.04, 0.96), Color(0.26, 0.23, 0.18, 1), 2, 14))
	repair_hud.add_child(conversation_choice)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	conversation_choice.add_child(row)
	var prompt := Label.new()
	prompt.text = "Продолжить разговор?"
	prompt.custom_minimum_size.x = 360
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prompt.add_theme_font_size_override("font_size", 22)
	prompt.add_theme_color_override("font_color", repair_hud.COLOR_PARCHMENT)
	row.add_child(prompt)
	question_button = Button.new()
	question_button.text = "Спросить об обвинении"
	question_button.custom_minimum_size = Vector2(340, 64)
	question_button.add_theme_font_size_override("font_size", 20)
	question_button.add_theme_stylebox_override("normal", repair_hud._style(Color(0.08, 0.08, 0.09, 1), Color(0.24, 0.22, 0.19, 1), 2, 12))
	question_button.add_theme_stylebox_override("hover", next_button.get_theme_stylebox("hover"))
	question_button.pressed.connect(func() -> void: _set_dialogue_lines("accusation"))
	row.add_child(question_button)
	var finish_conversation := Button.new()
	finish_conversation.name = "FinishConversation"
	finish_conversation.text = "Завершить разговор"
	finish_conversation.custom_minimum_size = Vector2(310, 64)
	finish_conversation.add_theme_font_size_override("font_size", 20)
	finish_conversation.add_theme_color_override("font_color", Color(0.15, 0.105, 0.045, 1))
	finish_conversation.add_theme_stylebox_override("normal", repair_hud._style(repair_hud.COLOR_GOLD, repair_hud.COLOR_BRASS, 2, 12))
	finish_conversation.add_theme_stylebox_override("hover", repair_hud._style(repair_hud.COLOR_PARCHMENT, repair_hud.COLOR_GOLD, 2, 12))
	finish_conversation.pressed.connect(func() -> void: _set_dialogue_lines("ending"))
	row.add_child(finish_conversation)
	conversation_choice.hide()
	$Record/Text.add_theme_font_size_override("font_size", 18)
	$Record/Text.position.x = 420
	$Record/Text.size.x = 570

func _begin_dialogue(section: String, close_up: bool) -> void:
	dialogue_employee_id = selected_employee_id
	dialogue_crew = _available_crew()
	if not dialogue_open:
		dialogue_clock_was_paused = game_state.clock_paused
	game_state.clock_paused = true
	dialogue_open = true
	portrait.visible = close_up
	$Portrait/Background.texture = load("res://assets/prison/mysterious_girl_hidden_eye.png" if simulation.state.get("eye_hidden", false) else "res://assets/prison/mysterious_girl_conversation.png")
	repair_hud.employee_panel.hide()
	tool_bar.hide()
	finish_button.hide()
	dialogue_panel.show()
	if section == "result":
		dialogue_section = section
	else:
		_set_dialogue_lines(section)

func _set_dialogue_lines(section: String) -> void:
	dialogue_section = section
	lines = Dialogue.build(section, dialogue_crew, dialogue_employee_id)
	line_index = 0
	_show_line()

func _show_line() -> void:
	conversation_choice.hide()
	dialogue_panel.show()
	if lines.is_empty():
		_close_conversation()
		return
	var line: Dictionary = lines[line_index]
	if line.get("visual", "") == "hide_eye":
		$Portrait/Background.texture = load("res://assets/prison/mysterious_girl_hidden_eye.png")
		simulation.state["eye_hidden"] = true
		_save_campaign()
	var speaker := str(line.get("speaker", ""))
	_set_speaker_portrait(speaker)
	var message := str(line.get("text", ""))
	var description := str(line.get("description", ""))
	if not description.is_empty():
		message = description + "\n\n" + message
	repair_hud._display_dialogue(_employee_name(speaker) if not speaker.is_empty() else "", message, false, dialogue_portrait.texture)
	question_button.hide()
	next_button.text = "Далее"

func _next_line() -> void:
	line_index += 1
	if line_index < lines.size():
		_show_line()
	elif dialogue_section == "conversation":
		simulation.state["conversation_seen"] = true
		_save_campaign()
		_show_conversation_choice()
	elif dialogue_section in ["choice", "accusation"]:
		if dialogue_section == "accusation":
			simulation.state["accusation_seen"] = true
			_save_campaign()
		_set_dialogue_lines("ending")
	else:
		_close_conversation()

func _build_work_interface() -> void:
	var layer := Control.new()
	layer.name = "WorkInterface"
	layer.z_index = 50
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(layer)
	tool_bar = preload("res://scenes/ui/ToolBar.tscn").instantiate()
	tool_bar.name = "ToolBar"
	layer.add_child(tool_bar)
	repair_hud = preload("res://scripts/repair_hud.gd").new()
	repair_hud.name = "RepairHUD"
	repair_hud.employee_selected.connect(func(id: StringName) -> void:
		selected_employee_id = str(id)
		tool_bar.hide()
		_configure_employee_actor()
	)
	layer.add_child(repair_hud)
	finish_button = repair_hud.complete_button
	selected_employee_id = str(repair_hud.get_selected_employee_id())
	repair_hud.completion_requested.connect(_complete)
	tool_bar.intent_selected.connect(func(id: StringName) -> void:
		tool_bar.hide()
		if id == &"talk_guard":
			_begin_dialogue("arrival", false)
		elif id == &"talk_girl":
			_open_conversation()
		else:
			_request_action(str(id))
	)
	var pause := preload("res://scenes/ui/PauseMenu.tscn").instantiate()
	pause.show_default_menu_button = false
	add_child(pause)
	$Office/Guard.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_show_actions("guard")
	)
	var hotspot := Control.new()
	hotspot.position = Vector2(435, 355)
	hotspot.size = Vector2(165, 140)
	hotspot.tooltip_text = "Замок пустой клетки"
	hotspot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hotspot.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_show_actions("lock")
	)
	cells.add_child(hotspot)
	$Cells/Gate.mouse_filter = Control.MOUSE_FILTER_STOP
	$Cells/Gate.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_show_actions("girl")
	)

func _show_actions(target: String) -> void:
	if dialogue_open or record.visible or (action_in_progress or repair_hud.is_timed_action_active()):
		return
	var choices: Array = []
	if target == "guard":
		choices.append({"id": "talk_guard", "label": "Поговорить с охранником"})
	if target == "girl" and bool(simulation.state["conversation_unlocked"]) and not bool(simulation.state["reverse_feedback"]) and not bool(simulation.state["escaped"]):
		choices.append({"id": "talk_girl", "label": "Поговорить"})
	for id: String in Definition.actions:
		var action: Dictionary = Definition.actions[id]
		if str(action.get("target", "lock")) == target and simulation.available(id) and _actor_allowed(id):
			choices.append({"id": id, "label": action["label"]})
	if choices.is_empty():
		return
	tool_bar.position = get_global_mouse_position() + Vector2(30, -50)
	tool_bar.show_intents({"guard": "Охранник", "lock": "Замок пустой клетки", "girl": "Заключённая"}[target], choices)
	tool_bar.position.x = clampf(tool_bar.position.x, 20, 1250)
	tool_bar.show()
	tool_bar.get_node("Panel/ContentMargin/Content/Buttons").get_child(-1).hide()
	tool_bar._resize_for_action_count(choices.size())
	tool_bar.position.y = maxf(155, tool_bar.position.y)

func _actor_allowed(action_id: String) -> bool:
	if not Definition.actions.has(action_id):
		return false
	if not _available_crew().has(selected_employee_id):
		return false
	var needed := str(Definition.actions[action_id].get("ability", ""))
	var abilities: PackedStringArray = game_state.employees.get(StringName(selected_employee_id), {}).get("abilities", PackedStringArray())
	return needed.is_empty() or abilities.has(needed)

func _set_speaker_portrait(speaker: String) -> void:
	var texture: Texture2D
	if speaker == "guard":
		var atlas := AtlasTexture.new()
		atlas.atlas = load("res://assets/prison/guard.png")
		atlas.region = Rect2(190, 0, 650, 620)
		texture = atlas
	elif speaker == "girl":
		texture = load("res://assets/prison/mysterious_girl_portrait.png")
	elif game_state.employees.has(StringName(speaker)):
		texture = repair_hud._cropped_portrait(game_state.employees[StringName(speaker)])
	dialogue_portrait_frame.visible = texture != null
	dialogue_portrait.texture = texture

func _build_employee_actor() -> void:
	actor_placement = Control.new()
	actor_placement.name = "EmployeePlacement"
	actor_placement.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actor_placement.scale = Vector2(0.65, 0.65)
	add_child(actor_placement)
	employee_actor = preload("res://scenes/EmployeeActor.tscn").instantiate()
	actor_placement.add_child(employee_actor)

func _configure_employee_actor() -> void:
	if employee_actor == null:
		return
	var employee: Dictionary = game_state.employees.get(StringName(selected_employee_id), {})
	employee_actor.visible = not employee.is_empty() and employee_actor.configure_employee(StringName(selected_employee_id), employee)
	employee_actor.set_horizontal_flip(true)

func _request_action(action_id: String) -> void:
	if action_in_progress or dialogue_open or record.visible or not simulation.available(action_id) or not _actor_allowed(action_id):
		return
	action_in_progress = true
	simulation.state["pending_prison_action"] = {"action_id": action_id, "employee_id": selected_employee_id}
	_save_campaign()
	tool_bar.hide()
	_refresh()
	var ability := str(Definition.actions[action_id].get("ability", ""))
	if not ability.is_empty():
		var target := Vector2(525, 425) if current_room == "cells" and action_id != "antimagic" else Vector2(1130, 440)
		var approach: Vector2 = actor_placement.get_global_transform().affine_inverse() * Vector2(315, 225)
		employee_actor.play_action(StringName(ability), target, approach, &"work", true)
		await employee_actor.action_finished
	if action_id in ["inspect", "repair_mechanism", "finish_repair"]:
		employee_actor.set_persistent_work_pose(true)
		repair_hud.start_timed_action(StringName(selected_employee_id), &"diagnose" if action_id == "inspect" else &"repair", perform_action.bind(action_id))
		if not repair_hud.is_timed_action_active():
			action_in_progress = false
			employee_actor.set_persistent_work_pose(false)
			_refresh()
	else:
		perform_action(action_id)

func _open_control_panel() -> void:
	if dialogue_open or action_in_progress or record.visible:
		return
	control_panel_clock_was_paused = game_state.clock_paused
	game_state.clock_paused = true
	tool_bar.hide()
	$ProtectionPanel.refresh(bool(simulation.state.get("protection_active", true)))
	repair_hud.hide()
	$ProtectionPanel.show()

func _close_control_panel() -> void:
	$ProtectionPanel.hide()
	repair_hud.show()
	game_state.clock_paused = control_panel_clock_was_paused
	_refresh()

func _open_circuit_view() -> void:
	if dialogue_open or action_in_progress or record.visible:
		return
	control_panel_clock_was_paused = game_state.clock_paused
	game_state.clock_paused = true
	tool_bar.hide()
	repair_hud.hide()
	$CircuitView.show()

func _close_circuit_view() -> void:
	$CircuitView.hide()
	repair_hud.show()
	game_state.clock_paused = control_panel_clock_was_paused
	_refresh()

func _setup_modal_windows() -> void:
	for window: Control in [$Record, $ProtectionPanel, $CircuitView]:
		move_child(window, get_child_count() - 1)
		var close: Button = window.get_node("Close")
		close.add_theme_font_size_override("font_size", 17)
		close.add_theme_color_override("font_color", repair_hud.COLOR_PARCHMENT)
		close.add_theme_stylebox_override("normal", repair_hud._style(repair_hud.COLOR_PANEL, repair_hud.COLOR_BRASS, 2, 8))
		close.add_theme_stylebox_override("hover", repair_hud._style(Color(0.21, 0.14, 0.075, 0.98), repair_hud.COLOR_GOLD, 2, 8))

func _show_conversation_choice() -> void:
	dialogue_panel.hide()
	question_button.visible = bool(simulation.state["record_read"]) and dialogue_employee_id != "felix" and not bool(simulation.state.get("accusation_seen", false))
	conversation_choice.show()
	dialogue_section = "choice"

func _play_escape_cutscene(employee_id: String) -> void:
	action_in_progress = true
	var clock_was_paused: bool = game_state.clock_paused
	game_state.clock_paused = true
	repair_hud.hide()
	tool_bar.hide()
	var layer := CanvasLayer.new()
	layer.name = "EscapeCutscene"
	layer.layer = 100
	add_child(layer)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color.BLACK
	layer.add_child(shade)
	var player := VideoStreamPlayer.new()
	player.name = "Video"
	player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	player.expand = true
	player.stream = load("res://assets/prison/prisoner_escape.ogv")
	layer.add_child(player)
	player.play()
	await player.finished
	layer.queue_free()
	action_in_progress = false
	game_state.clock_paused = clock_was_paused
	repair_hud.show()
	_begin_dialogue("result", false)
	lines = [{"speaker": employee_id, "text": "Что она со мной сделала?"}]
	line_index = 0
	_show_line()
