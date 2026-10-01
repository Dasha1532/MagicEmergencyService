extends Control

signal employee_selected(employee_id: StringName)
signal completion_requested
signal long_action_started(employee_id: StringName)
signal long_action_finished(employee_id: StringName)
signal dialogue_finished

const COLOR_PANEL := Color(0.07, 0.045, 0.03, 0.94)
const COLOR_CARD := Color(0.13, 0.09, 0.055, 0.96)
const COLOR_SELECTED := Color(0.10, 0.16, 0.18, 0.98)
const COLOR_BRASS := Color(0.76, 0.54, 0.27)
const COLOR_GOLD := Color(0.96, 0.78, 0.46)
const COLOR_PARCHMENT := Color(0.92, 0.84, 0.69)
const COLOR_MUTED := Color(0.66, 0.60, 0.50)
const RESIDENT_DIALOGUE_PANEL_SCENE := preload("res://scenes/ui/ResidentDialoguePanel.tscn")
const CLOCK_CONTROLS_SCRIPT = preload("res://scripts/game_clock_controls.gd")

var selected_employee_id: StringName = &""
var employee_box: HBoxContainer
var employee_panel: Panel
var complete_button: Button
var tool_bar: MarginContainer
var job_title_label: Label
var job_time_label: Label
var employee_reaction_panel: Panel
var employee_reaction_label: Label
var employee_reaction_heading: Label
var dialogue_portrait_frame: Panel
var dialogue_portrait: TextureRect
var portrait_heading_position: Vector2
var portrait_heading_size: Vector2
var portrait_label_position: Vector2
var portrait_label_size: Vector2
var work_ui_visible: bool = true
var queued_dialogues: Array[Dictionary] = []
var task_panel: Panel
var task_label: Label
var task_progress: ProgressBar
var task_started_at: int = 0
var task_ends_at: int = 0
var task_callback: Callable
var employee_buttons: Dictionary = {}
var access_dialogues_ready: bool = false
var access_sequence: Array[Dictionary] = []
var access_sequence_active: bool = false
var access_notice: Control
var access_notice_text: Label
var employee_detail_labels: Dictionary = {}
var shown_employee_reactions: Dictionary = {}
@onready var game_state: Node = get_node("/root/GameState")


func _ready() -> void:
	_call_audio_manager(&"play_job_music")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tool_bar = get_node("../ToolBar")
	if game_state.active_job_id.is_empty():
		game_state.active_job_id = game_state.selected_job_id
	_build_job_header()
	_build_clock_controls()
	_build_employee_selector()
	_build_return_button()
	_build_complete_button()
	_build_employee_reaction_panel()
	_build_access_notice()
	_build_task_progress()
	game_state.state_changed.connect(_refresh_job_time)
	game_state.state_changed.connect(_refresh_employee_states)
	_refresh_job_time()
	_select_first_employee()
	set_process(true)


func _exit_tree() -> void:
	_call_audio_manager(&"stop_job_music")


func _call_audio_manager(method: StringName) -> void:
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager != null and audio_manager.has_method(method):
		audio_manager.call(method)


func _process(_delta: float) -> void:
	var pending: Dictionary = game_state.get_pending_job_action(game_state.active_job_id)
	if pending.is_empty():
		if task_panel != null:
			task_panel.visible = false
		return
	task_started_at = int(pending.get("started_at", game_state.time_minutes))
	task_ends_at = int(pending.get("ends_at", game_state.time_minutes))
	var duration: int = maxi(1, task_ends_at - task_started_at)
	var elapsed: int = clampi(game_state.time_minutes - task_started_at, 0, duration)
	task_panel.visible = duration > 1
	if task_panel.visible:
		task_progress.value = float(elapsed) / float(duration) * 100.0
		task_label.text = tr("Работа выполняется, осталось %d мин.") % maxi(0, task_ends_at - game_state.time_minutes)
	if game_state.time_minutes < task_ends_at:
		return
	if not task_callback.is_valid():
		return
	var callback := task_callback
	var employee_id := StringName(str(pending.get("employee_id", "")))
	task_callback = Callable()
	game_state.clear_pending_job_action(game_state.active_job_id)
	task_panel.visible = false
	if duration > 1:
		long_action_finished.emit(employee_id)
	if callback.is_valid():
		callback.call()


func _build_job_header() -> void:
	var job: Dictionary = game_state.get_active_job()
	var panel := Panel.new()
	panel.position = Vector2(20, 18)
	panel.size = Vector2(650, 64)
	panel.add_theme_stylebox_override("panel", _style(COLOR_PANEL, COLOR_BRASS, 2, 10))
	add_child(panel)

	job_title_label = _label(job.get("objective", job.get("title", "Ремонт")), 20, COLOR_GOLD)
	job_title_label.position = Vector2(18, 4)
	job_title_label.size = Vector2(614, 32)
	job_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(job_title_label)

	job_time_label = _label("", 14, COLOR_PARCHMENT)
	job_time_label.position = Vector2(18, 34)
	job_time_label.size = Vector2(614, 24)
	job_time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(job_time_label)


func _build_clock_controls() -> void:
	var controls := CLOCK_CONTROLS_SCRIPT.new()
	controls.position = Vector2(680, 18)
	add_child(controls)


func _build_task_progress() -> void:
	task_panel = Panel.new()
	task_panel.position = Vector2(1048, 88)
	task_panel.size = Vector2(530, 72)
	task_panel.visible = false
	task_panel.add_theme_stylebox_override("panel", _style(COLOR_PANEL, COLOR_BRASS, 2, 8))
	add_child(task_panel)
	task_label = _label("", 15, COLOR_PARCHMENT)
	task_label.position = Vector2(14, 7)
	task_label.size = Vector2(502, 25)
	task_panel.add_child(task_label)
	task_progress = ProgressBar.new()
	task_progress.position = Vector2(14, 38)
	task_progress.size = Vector2(502, 22)
	task_progress.show_percentage = false
	task_panel.add_child(task_progress)


func start_timed_action(employee_id: StringName, action_id: StringName, completion: Callable, duration: int = -1) -> void:
	if is_timed_action_active():
		return
	var actual_duration: int = duration if duration > 0 else game_state.get_action_duration(action_id)
	if not game_state.start_job_action(game_state.active_job_id, employee_id, action_id, &"", actual_duration):
		return
	task_started_at = game_state.time_minutes
	task_ends_at = task_started_at + maxi(1, actual_duration)
	task_callback = completion
	task_panel.visible = actual_duration > 1
	if task_panel.visible:
		task_label.text = tr("%s работает, осталось %d мин.") % [tr(str(game_state.employees[employee_id]["name"])), actual_duration]
		task_progress.value = 0.0
		long_action_started.emit(employee_id)
	game_state.set_clock_paused(false)


func is_timed_action_active() -> bool:
	return not game_state.get_pending_job_action(game_state.active_job_id).is_empty()


func resume_timed_action(completion: Callable) -> void:
	if is_timed_action_active():
		task_callback = completion
		var pending: Dictionary = game_state.get_pending_job_action(game_state.active_job_id)
		if int(pending.get("ends_at", 0)) - int(pending.get("started_at", 0)) > 1:
			long_action_started.emit(StringName(str(pending.get("employee_id", ""))))


func set_job_title(title: String) -> void:
	if job_title_label != null:
		job_title_label.text = title


func _refresh_job_time() -> void:
	if job_time_label == null:
		return
	var job: Dictionary = game_state.get_active_job()
	if job.is_empty():
		job_time_label.text = game_state.format_time()
		return
	if bool(job.get("overdue", false)):
		job_time_label.text = tr("%s — СРОК ИСТЁК") % game_state.format_time()
		job_time_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.28))
	else:
		job_time_label.text = tr("%s, осталось %d мин.") % [game_state.format_time(), int(job.get("time_left", 0))]
		job_time_label.add_theme_color_override("font_color", COLOR_PARCHMENT)


func _build_employee_selector() -> void:
	var job: Dictionary = game_state.get_active_job()
	var assigned: PackedStringArray = job.get("assigned", PackedStringArray())
	employee_buttons.clear()
	employee_detail_labels.clear()
	var employee_count: int = assigned.size()
	var visible_count: int = clampi(employee_count, 1, 3)
	var card_width: int = 297
	var card_gap: int = 7
	var viewport_width: int = visible_count * card_width + maxi(visible_count - 1, 0) * card_gap
	var content_width: int = employee_count * card_width + maxi(employee_count - 1, 0) * card_gap

	employee_panel = Panel.new()
	employee_panel.position = Vector2(20, 730)
	employee_panel.size = Vector2(viewport_width + 24, 150)
	employee_panel.add_theme_stylebox_override("panel", _style(COLOR_PANEL, COLOR_BRASS, 2, 10))
	add_child(employee_panel)

	var heading := _label("БРИГАДА", 19, COLOR_GOLD)
	heading.position = Vector2(16, 6)
	heading.size = Vector2(viewport_width - 8, 28)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	employee_panel.add_child(heading)

	var employee_scroll := ScrollContainer.new()
	employee_scroll.position = Vector2(12, 38)
	employee_scroll.size = Vector2(viewport_width, 102)
	employee_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	employee_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	employee_panel.add_child(employee_scroll)

	employee_box = HBoxContainer.new()
	employee_box.custom_minimum_size = Vector2(maxi(content_width, viewport_width), 91)
	employee_box.add_theme_constant_override("separation", 7)
	employee_scroll.add_child(employee_box)

	for employee_id: String in assigned:
		_add_employee_button(StringName(employee_id))


func _add_employee_button(employee_id: StringName) -> void:
	var employee: Dictionary = game_state.employees[employee_id]
	var button := Button.new()
	button.custom_minimum_size = Vector2(297, 91)
	button.add_theme_stylebox_override("normal", _style(COLOR_CARD, COLOR_BRASS, 2, 7))
	button.add_theme_stylebox_override("hover", _style(Color(0.21, 0.14, 0.075, 0.98), COLOR_GOLD, 2, 7))
	button.add_theme_stylebox_override("pressed", _style(COLOR_SELECTED, COLOR_GOLD, 3, 7))
	button.pressed.connect(_select_employee.bind(employee_id))
	employee_box.add_child(button)
	button.set_meta("employee_id", employee_id)
	employee_buttons[employee_id] = button

	var portrait_frame := Panel.new()
	portrait_frame.position = Vector2(7, 5)
	portrait_frame.size = Vector2(82, 81)
	portrait_frame.clip_contents = true
	portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_theme_stylebox_override("panel", _style(Color(0.035, 0.03, 0.028, 1), COLOR_BRASS, 1, 5))
	button.add_child(portrait_frame)

	var portrait := TextureRect.new()
	portrait.position = Vector2(1, 1)
	portrait.size = Vector2(80, 79)
	portrait.texture = _cropped_portrait(employee)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_child(portrait)

	var name_label := _label(tr(str(employee["name"])), 15, COLOR_GOLD)
	name_label.position = Vector2(96, 9)
	name_label.size = Vector2(189, 28)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_child(name_label)

	var role_label := _label(tr(str(employee["core_actions"])), 13, COLOR_PARCHMENT)
	role_label.position = Vector2(96, 38)
	role_label.size = Vector2(189, 45)
	role_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	role_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	role_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_child(role_label)
	employee_detail_labels[employee_id] = role_label
	_update_employee_card(employee_id)


func _refresh_employee_states() -> void:
	for employee_key: Variant in employee_buttons.keys():
		var assigned: PackedStringArray = game_state.jobs.get(game_state.active_job_id, {}).get("assigned", PackedStringArray())
		employee_buttons[employee_key].visible = assigned.has(String(employee_key))
		_update_employee_card(StringName(employee_key))
	if access_dialogues_ready:
		_show_access_messages()
	if selected_employee_id.is_empty() or not game_state.can_employee_work_on_job(selected_employee_id, game_state.active_job_id):
		_select_first_employee()


func enable_access_dialogues() -> bool:
	access_dialogues_ready = true
	return _show_access_messages()


func _show_access_messages() -> bool:
	var events: Array[Dictionary] = game_state.take_access_events(game_state.active_job_id)
	if events.is_empty():
		return false
	for event: Dictionary in events:
		access_sequence.append({"kind": "resident", "text": str(event["phrase"])})
		access_sequence.append({"kind": "notice", "text": str(event["message"])})
	access_sequence.append({"kind": "resident", "text": game_state.get_resident_greeting(game_state.active_job_id)})
	if not access_sequence_active:
		access_sequence_active = true
		_advance_access_sequence()
	return true


func _advance_access_sequence() -> void:
	access_notice.visible = false
	if access_sequence.is_empty():
		access_sequence_active = false
		employee_panel.visible = work_ui_visible
		dialogue_finished.emit()
		return
	var step: Dictionary = access_sequence.pop_front()
	if str(step["kind"]) == "resident":
		show_resident_dialogue(str(step["text"]))
	else:
		employee_reaction_panel.visible = false
		employee_panel.visible = false
		access_notice_text.text = str(step["text"])
		access_notice.visible = true
		access_notice.move_to_front()
		game_state.set_clock_paused(true)


func _build_access_notice() -> void:
	access_notice = Control.new()
	access_notice.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	access_notice.visible = false
	access_notice.z_index = 220
	add_child(access_notice)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.01, 0.008, 0.76)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	access_notice.add_child(shade)
	var panel := Panel.new()
	panel.position = Vector2(410, 260)
	panel.size = Vector2(780, 380)
	panel.add_theme_stylebox_override("panel", _style(COLOR_PANEL, COLOR_BRASS, 2, 14))
	access_notice.add_child(panel)
	var title := _label("ЖИЛЕЦ НЕ ВПУСТИЛ СОТРУДНИКА", 24, COLOR_GOLD)
	title.position = Vector2(38, 34)
	title.size = Vector2(704, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)
	access_notice_text = _label("", 18, COLOR_PARCHMENT)
	access_notice_text.position = Vector2(60, 100)
	access_notice_text.size = Vector2(660, 150)
	access_notice_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	access_notice_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	access_notice_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(access_notice_text)
	var button := Button.new()
	button.text = "ПОНЯТНО"
	button.position = Vector2(235, 278)
	button.size = Vector2(310, 62)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", COLOR_GOLD)
	button.add_theme_stylebox_override("normal", _style(COLOR_PANEL, COLOR_BRASS, 2, 9))
	button.add_theme_stylebox_override("hover", _style(COLOR_SELECTED, COLOR_GOLD, 2, 9))
	button.pressed.connect(_advance_access_sequence)
	panel.add_child(button)


func _update_employee_card(employee_id: StringName) -> void:
	if not employee_buttons.has(employee_id) or not employee_detail_labels.has(employee_id):
		return
	var employee: Dictionary = game_state.employees[employee_id]
	var on_site: bool = game_state.can_employee_work_on_job(employee_id, game_state.active_job_id)
	var button: Button = employee_buttons[employee_id]
	var detail_label: Label = employee_detail_labels[employee_id]
	button.disabled = not on_site
	button.tooltip_text = "" if on_site else tr(str(employee["status"]))
	detail_label.text = tr(str(employee["core_actions"])) if on_site else tr(str(employee["status"]))
	detail_label.add_theme_color_override("font_color", COLOR_PARCHMENT if on_site else COLOR_MUTED)


func _build_return_button() -> void:
	var button := Button.new()
	button.text = "←  ОТКРЫТЬ ОФИС"
	button.position = Vector2(1325, 24)
	button.size = Vector2(253, 54)
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", COLOR_PARCHMENT)
	button.add_theme_stylebox_override("normal", _style(COLOR_PANEL, COLOR_BRASS, 2, 8))
	button.add_theme_stylebox_override("hover", _style(Color(0.21, 0.14, 0.075, 0.98), COLOR_GOLD, 2, 8))
	button.pressed.connect(_return_to_office)
	add_child(button)


func _build_complete_button() -> void:
	complete_button = Button.new()
	complete_button.text = "ЗАВЕРШИТЬ РАБОТУ"
	complete_button.position = Vector2(1048, 24)
	complete_button.size = Vector2(255, 54)
	complete_button.add_theme_font_size_override("font_size", 17)
	complete_button.add_theme_color_override("font_color", COLOR_GOLD)
	complete_button.add_theme_stylebox_override("normal", _style(COLOR_SELECTED, COLOR_GOLD, 2, 8))
	complete_button.add_theme_stylebox_override("hover", _style(Color(0.18, 0.25, 0.20, 0.98), COLOR_GOLD, 3, 8))
	complete_button.pressed.connect(_complete_job)
	add_child(complete_button)


func _build_employee_reaction_panel() -> void:
	employee_reaction_panel = RESIDENT_DIALOGUE_PANEL_SCENE.instantiate() as Panel
	employee_reaction_panel.visible = false
	add_child(employee_reaction_panel)

	dialogue_portrait_frame = employee_reaction_panel.get_node("PortraitFrame") as Panel
	dialogue_portrait_frame.visible = false
	dialogue_portrait = dialogue_portrait_frame.get_node("Portrait") as TextureRect
	employee_reaction_heading = employee_reaction_panel.get_node("SpeakerName") as Label
	employee_reaction_label = employee_reaction_panel.get_node("Message") as Label
	portrait_heading_position = employee_reaction_heading.position
	portrait_heading_size = employee_reaction_heading.size
	portrait_label_position = employee_reaction_label.position
	portrait_label_size = employee_reaction_label.size

	var close_button := employee_reaction_panel.get_node("CloseButton") as Button
	close_button.pressed.connect(clear_employee_reaction)


func show_employee_reaction(employee_id: StringName, message: String) -> bool:
	var normalized_message := message.strip_edges()
	if not should_show_employee_reaction(employee_id, normalized_message):
		return false
	var employee: Dictionary = game_state.employees.get(employee_id, {})
	queued_dialogues.clear()
	_display_dialogue(str(employee.get("name", "Сотрудник")), normalized_message, false, _cropped_portrait(employee))
	return true


func should_show_employee_reaction(employee_id: StringName, message: String) -> bool:
	var normalized_message := message.strip_edges()
	if normalized_message.is_empty():
		return false
	var reaction_key := "%s\n%s" % [String(employee_id), normalized_message]
	if shown_employee_reactions.has(reaction_key):
		return false
	shown_employee_reactions[reaction_key] = true
	return true


func show_dialogue(speaker: String, message: String) -> void:
	if employee_reaction_panel == null or employee_reaction_label == null or message.is_empty():
		return
	queued_dialogues.clear()
	_display_dialogue(speaker, message, false)


func show_resident_dialogue(message: String) -> void:
	if message.is_empty():
		return
	var job: Dictionary = game_state.get_active_job()
	queued_dialogues.clear()
	_display_dialogue(str(job.get("resident", "Жилец")), message, false, _resident_portrait(job))


func queue_dialogue(speaker: String, message: String, is_warning: bool = false) -> void:
	if message.is_empty():
		return
	if employee_reaction_panel.visible and not employee_reaction_label.text.is_empty():
		_push_queued_dialogue({"speaker": speaker, "message": message, "warning": is_warning})
		return
	_display_dialogue(speaker, message, is_warning)


func queue_resident_dialogue(message: String) -> void:
	if message.is_empty():
		return
	var job: Dictionary = game_state.get_active_job()
	var dialogue: Dictionary = {
		"speaker": str(job.get("resident", "Жилец")),
		"message": message,
		"warning": false,
		"portrait": _resident_portrait(job),
	}
	if employee_reaction_panel.visible and not employee_reaction_label.text.is_empty():
		_push_queued_dialogue(dialogue)
		return
	_display_dialogue(str(dialogue["speaker"]), message, false, dialogue["portrait"])


func queue_employee_reaction(employee_id: StringName, message: String) -> void:
	if message.is_empty():
		return
	var employee: Dictionary = game_state.employees.get(employee_id, {})
	var dialogue: Dictionary = {
		"speaker": str(employee.get("name", "Сотрудник")),
		"message": message,
		"warning": false,
		"portrait": _cropped_portrait(employee),
	}
	if employee_reaction_panel.visible and not employee_reaction_label.text.is_empty():
		_push_queued_dialogue(dialogue)
		return
	_display_dialogue(str(dialogue["speaker"]), message, false, dialogue["portrait"])


func _push_queued_dialogue(dialogue: Dictionary) -> void:
	# На экране может быть одно сообщение и только одно следующее за ним.
	# Новое актуальное последствие заменяет устаревший хвост очереди.
	if queued_dialogues.is_empty():
		queued_dialogues.append(dialogue)
	else:
		queued_dialogues[0] = dialogue


func _load_portrait(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _resident_portrait(job: Dictionary) -> Texture2D:
	var texture: Texture2D = _load_portrait(str(job.get("resident_portrait", "")))
	if texture == null:
		return null
	var configured_region: Variant = job.get("resident_portrait_region", Rect2())
	if not configured_region is Rect2:
		return texture
	var region: Rect2 = configured_region
	if region.size == Vector2.ZERO:
		return texture
	var portrait := AtlasTexture.new()
	portrait.atlas = texture
	portrait.region = region
	portrait.filter_clip = true
	return portrait


func _display_dialogue(speaker: String, message: String, is_warning: bool, portrait_texture: Texture2D = null) -> void:
	game_state.set_clock_paused(true)
	var has_portrait: bool = portrait_texture != null
	dialogue_portrait_frame.visible = has_portrait
	dialogue_portrait.texture = portrait_texture
	employee_reaction_heading.position = portrait_heading_position if has_portrait else Vector2(24, portrait_heading_position.y)
	employee_reaction_heading.size = portrait_heading_size if has_portrait else Vector2(1260, portrait_heading_size.y)
	employee_reaction_label.position = portrait_label_position if has_portrait else Vector2(24, portrait_label_position.y)
	employee_reaction_label.size = portrait_label_size if has_portrait else Vector2(1260, portrait_label_size.y)
	employee_reaction_heading.text = tr(speaker)
	employee_reaction_label.text = tr(message)
	employee_reaction_label.add_theme_color_override("font_color", Color(1.0, 0.58, 0.35) if is_warning else COLOR_PARCHMENT)
	if employee_panel != null:
		employee_panel.visible = false
	employee_reaction_panel.visible = true
	employee_reaction_panel.move_to_front()


func show_system_message(message: String, is_warning: bool = false) -> void:
	queue_dialogue("ВНИМАНИЕ" if is_warning else "РЕЗУЛЬТАТ", message, is_warning)


func clear_employee_reaction() -> void:
	if access_sequence_active:
		employee_reaction_label.text = ""
		employee_reaction_panel.visible = false
		_advance_access_sequence()
		return
	if not queued_dialogues.is_empty():
		var next_dialogue: Dictionary = queued_dialogues.pop_front()
		_display_dialogue(str(next_dialogue["speaker"]), str(next_dialogue["message"]), bool(next_dialogue["warning"]), next_dialogue.get("portrait") as Texture2D)
		return
	if employee_reaction_label != null:
		employee_reaction_label.text = ""
	if employee_reaction_panel != null:
		employee_reaction_panel.visible = false
	if employee_panel != null:
		employee_panel.visible = work_ui_visible
	dialogue_finished.emit()


func clear_all_dialogues() -> void:
	queued_dialogues.clear()
	if employee_reaction_label != null:
		employee_reaction_label.text = ""
	if employee_reaction_panel != null:
		employee_reaction_panel.visible = false
	if employee_panel != null:
		employee_panel.visible = work_ui_visible


func set_work_ui_visible(should_be_visible: bool) -> void:
	work_ui_visible = should_be_visible
	var has_dialogue: bool = employee_reaction_label != null and not employee_reaction_label.text.is_empty()
	if employee_reaction_panel != null:
		employee_reaction_panel.visible = should_be_visible and has_dialogue
	if employee_panel != null:
		employee_panel.visible = should_be_visible and not has_dialogue
	if complete_button != null:
		complete_button.visible = should_be_visible


func set_completion_ready(is_ready: bool) -> void:
	if complete_button == null:
		return
	complete_button.disabled = not is_ready
	complete_button.tooltip_text = "" if is_ready else "Сначала устраните причину аварии"


func get_selected_employee_id() -> StringName:
	return selected_employee_id


func _select_first_employee() -> void:
	var job: Dictionary = game_state.get_active_job()
	var assigned: PackedStringArray = job.get("assigned", PackedStringArray())
	for employee_id: String in assigned:
		if game_state.can_employee_work_on_job(StringName(employee_id), game_state.active_job_id):
			_select_employee(StringName(employee_id))
			return
	selected_employee_id = &""
	tool_bar.visible = false


func _select_employee(employee_id: StringName) -> void:
	if not game_state.can_employee_work_on_job(employee_id, game_state.active_job_id):
		return
	if is_timed_action_active() and not selected_employee_id.is_empty() and employee_id != selected_employee_id:
		return
	if employee_id != selected_employee_id:
		clear_employee_reaction()
	selected_employee_id = employee_id
	for child in employee_box.get_children():
		if child is Button:
			var selected: bool = child.get_meta("employee_id") == employee_id
			child.add_theme_stylebox_override("normal", _style(COLOR_SELECTED if selected else COLOR_CARD, COLOR_GOLD if selected else COLOR_BRASS, 3 if selected else 2, 7))

	var employee: Dictionary = game_state.employees[employee_id]
	tool_bar.configure_for_employee(employee["name"], employee["abilities"], employee["core_actions"])
	employee_selected.emit(employee_id)


func _return_to_office() -> void:
	game_state.leave_active_job()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _complete_job() -> void:
	completion_requested.emit()


func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label


func _style(background: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _cropped_portrait(employee: Dictionary) -> AtlasTexture:
	var portrait := AtlasTexture.new()
	portrait.atlas = load(str(employee["portrait"]))
	var configured_region: Variant = employee.get("portrait_region", Rect2(177, 0, 900, 932))
	portrait.region = configured_region if configured_region is Rect2 else Rect2(177, 0, 900, 932)
	portrait.filter_clip = true
	return portrait
