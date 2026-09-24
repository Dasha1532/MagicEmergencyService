extends CanvasLayer

const SaveSlotsPanelScript := preload("res://scripts/save_slots_panel.gd")

@export var show_default_menu_button := true

const COLOR_OVERLAY := Color(0.015, 0.012, 0.012, 0.76)
const COLOR_PANEL := Color(0.07, 0.045, 0.03, 0.985)
const COLOR_BUTTON := Color(0.13, 0.09, 0.055, 0.98)
const COLOR_HOVER := Color(0.22, 0.145, 0.075, 1.0)
const COLOR_BRASS := Color(0.76, 0.54, 0.27)
const COLOR_GOLD := Color(0.96, 0.78, 0.46)
const COLOR_PARCHMENT := Color(0.92, 0.84, 0.69)
const COLOR_MUTED := Color(0.69, 0.62, 0.52)

@onready var game_state: Node = get_node("/root/GameState")

var overlay: Control
var main_panel: Panel
var settings_panel: Panel
var load_button: Button
var status_label: Label
var volume_slider: HSlider
var fullscreen_check: CheckButton
var menu_button: Button
var slots_panel
var slots_mode: StringName = &"load"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_build_interface()
	_build_slots_panel()
	overlay.visible = false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if slots_panel.visible:
			_close_slots_panel()
		elif overlay.visible and settings_panel.visible:
			_show_main_panel()
		else:
			_toggle_menu()
		get_viewport().set_input_as_handled()


func _build_interface() -> void:
	menu_button = Button.new()
	menu_button.text = "☰"
	menu_button.tooltip_text = "Меню (Esc)"
	menu_button.position = Vector2(1522, 31)
	menu_button.size = Vector2(48, 48)
	menu_button.add_theme_font_size_override("font_size", 25)
	menu_button.add_theme_color_override("font_color", COLOR_GOLD)
	menu_button.add_theme_stylebox_override("normal", _style(COLOR_PANEL, COLOR_BRASS, 2, 9))
	menu_button.add_theme_stylebox_override("hover", _style(COLOR_HOVER, COLOR_GOLD, 2, 9))
	menu_button.add_theme_stylebox_override("pressed", _style(Color(0.09, 0.15, 0.17), COLOR_GOLD, 3, 9))
	menu_button.pressed.connect(_open_menu)
	menu_button.visible = show_default_menu_button
	add_child(menu_button)

	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var dimmer := ColorRect.new()
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = COLOR_OVERLAY
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dimmer)

	main_panel = _make_panel(Vector2(535, 76), Vector2(530, 748))
	overlay.add_child(main_panel)
	_build_main_panel()

	settings_panel = _make_panel(Vector2(535, 126), Vector2(530, 648))
	settings_panel.visible = false
	overlay.add_child(settings_panel)
	_build_settings_panel()


func _build_main_panel() -> void:
	var title := _label("МЕНЮ", 34, COLOR_GOLD)
	title.position = Vector2(30, 28)
	title.size = Vector2(470, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_panel.add_child(title)

	var subtitle := _label("Магическая аварийная служба", 16, COLOR_MUTED)
	subtitle.position = Vector2(30, 77)
	subtitle.size = Vector2(470, 28)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_panel.add_child(subtitle)

	var continue_button := _button("ПРОДОЛЖИТЬ", 132)
	continue_button.pressed.connect(_close_menu)
	main_panel.add_child(continue_button)

	var save_button := _button("СОХРАНИТЬ ИГРУ", 210)
	save_button.pressed.connect(_save_game)
	main_panel.add_child(save_button)

	load_button = _button("ЗАГРУЗИТЬ ИГРУ", 288)
	load_button.pressed.connect(_show_load_slots)
	main_panel.add_child(load_button)

	var settings_button := _button("НАСТРОЙКИ", 366)
	settings_button.pressed.connect(_show_settings)
	main_panel.add_child(settings_button)

	var title_button := _button("В ГЛАВНОЕ МЕНЮ", 444)
	title_button.pressed.connect(_return_to_title)
	main_panel.add_child(title_button)

	var exit_button := _button("ВЫЙТИ ИЗ ИГРЫ", 522)
	exit_button.pressed.connect(_exit_game)
	main_panel.add_child(exit_button)

	status_label = _label("", 15, COLOR_GOLD)
	status_label.position = Vector2(50, 598)
	status_label.size = Vector2(430, 50)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_panel.add_child(status_label)

	var hint := _label("Esc — закрыть меню", 14, COLOR_MUTED)
	hint.position = Vector2(50, 680)
	hint.size = Vector2(430, 28)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_panel.add_child(hint)


func _build_settings_panel() -> void:
	var title := _label("НАСТРОЙКИ", 30, COLOR_GOLD)
	title.position = Vector2(30, 28)
	title.size = Vector2(470, 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_panel.add_child(title)

	var audio_label := _label("Общая громкость", 19, COLOR_PARCHMENT)
	audio_label.position = Vector2(55, 126)
	audio_label.size = Vector2(420, 30)
	settings_panel.add_child(audio_label)

	volume_slider = HSlider.new()
	volume_slider.position = Vector2(55, 168)
	volume_slider.size = Vector2(420, 36)
	volume_slider.min_value = 0.0
	volume_slider.max_value = 100.0
	volume_slider.step = 1.0
	volume_slider.value = _current_volume_percent()
	volume_slider.value_changed.connect(_set_volume)
	settings_panel.add_child(volume_slider)

	fullscreen_check = CheckButton.new()
	fullscreen_check.text = "Полноэкранный режим"
	fullscreen_check.position = Vector2(55, 246)
	fullscreen_check.size = Vector2(420, 48)
	fullscreen_check.button_pressed = _is_fullscreen()
	fullscreen_check.add_theme_font_size_override("font_size", 18)
	fullscreen_check.add_theme_color_override("font_color", COLOR_PARCHMENT)
	fullscreen_check.toggled.connect(_set_fullscreen)
	settings_panel.add_child(fullscreen_check)

	var note := _label("Изменения применяются сразу.", 15, COLOR_MUTED)
	note.position = Vector2(55, 318)
	note.size = Vector2(420, 30)
	settings_panel.add_child(note)

	var back_button := _button("НАЗАД", 510)
	back_button.pressed.connect(_show_main_panel)
	settings_panel.add_child(back_button)


func _toggle_menu() -> void:
	if overlay.visible:
		_close_menu()
	else:
		_open_menu()


func open_menu() -> void:
	_open_menu()


func _open_menu() -> void:
	status_label.text = ""
	load_button.disabled = not game_state.has_save()
	main_panel.visible = true
	settings_panel.visible = false
	overlay.visible = true
	slots_panel.visible = false
	menu_button.visible = false
	get_tree().paused = true


func _close_menu() -> void:
	overlay.visible = false
	menu_button.visible = show_default_menu_button
	get_tree().paused = false


func _save_game() -> void:
	_show_save_slots()


func _save_to_slot(slot: int) -> void:
	var error: Error = game_state.save_game(slot)
	if error == OK:
		status_label.text = "Слот %d сохранён: день %d, %s" % [slot, game_state.day, game_state.format_time()]
		load_button.disabled = false
	else:
		status_label.text = "Не удалось сохранить игру. Код ошибки: %d" % error
	_close_slots_panel()


func _load_from_slot(slot: int) -> void:
	var error: Error = game_state.load_game(slot)
	if error != OK:
		status_label.text = "Не удалось загрузить сохранение. Код ошибки: %d" % error
		return

	overlay.visible = false
	get_tree().paused = false
	var target_scene := "res://scenes/main.tscn"
	var repair_scene: String = game_state.get_active_job_repair_scene()
	if not repair_scene.is_empty():
		target_scene = repair_scene
	get_tree().change_scene_to_file(target_scene)


func _build_slots_panel() -> void:
	slots_panel = SaveSlotsPanelScript.new()
	slots_panel.visible = false
	slots_panel.slot_selected.connect(_on_slot_selected)
	slots_panel.cancelled.connect(_close_slots_panel)
	add_child(slots_panel)


func _show_save_slots() -> void:
	slots_mode = &"save"
	slots_panel.configure(slots_mode)
	slots_panel.visible = true


func _show_load_slots() -> void:
	slots_mode = &"load"
	slots_panel.configure(slots_mode)
	slots_panel.visible = true


func _close_slots_panel() -> void:
	slots_panel.visible = false
	main_panel.visible = true


func _on_slot_selected(slot: int) -> void:
	if slots_mode == &"save":
		_save_to_slot(slot)
	else:
		_load_from_slot(slot)


func _show_settings() -> void:
	main_panel.visible = false
	settings_panel.visible = true


func _show_main_panel() -> void:
	settings_panel.visible = false
	main_panel.visible = true


func _return_to_title() -> void:
	overlay.visible = false
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/TitleScreen.tscn")


func _set_volume(value: float) -> void:
	var settings_manager := get_node_or_null("/root/SettingsManager")
	if settings_manager != null:
		settings_manager.call(&"set_master_volume", value)


func _current_volume_percent() -> float:
	var settings_manager := get_node_or_null("/root/SettingsManager")
	return float(settings_manager.call(&"get_master_volume")) if settings_manager != null else 100.0


func _set_fullscreen(enabled: bool) -> void:
	var settings_manager := get_node_or_null("/root/SettingsManager")
	if settings_manager != null:
		settings_manager.call(&"set_fullscreen", enabled)


func _is_fullscreen() -> bool:
	var settings_manager := get_node_or_null("/root/SettingsManager")
	return bool(settings_manager.call(&"is_fullscreen")) if settings_manager != null else false


func _exit_game() -> void:
	get_tree().paused = false
	get_tree().quit()


func _make_panel(panel_position: Vector2, panel_size: Vector2) -> Panel:
	var panel := Panel.new()
	panel.position = panel_position
	panel.size = panel_size
	panel.add_theme_stylebox_override("panel", _style(COLOR_PANEL, COLOR_BRASS, 3, 14))
	return panel


func _button(text_value: String, y: float) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = Vector2(55, y)
	button.size = Vector2(420, 60)
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_color_override("font_color", COLOR_PARCHMENT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.42, 0.38, 0.33))
	button.add_theme_stylebox_override("normal", _style(COLOR_BUTTON, COLOR_BRASS, 2, 9))
	button.add_theme_stylebox_override("hover", _style(COLOR_HOVER, COLOR_GOLD, 2, 9))
	button.add_theme_stylebox_override("pressed", _style(Color(0.09, 0.15, 0.17), COLOR_GOLD, 3, 9))
	button.add_theme_stylebox_override("focus", _style(COLOR_HOVER, COLOR_GOLD, 2, 9))
	button.add_theme_stylebox_override("disabled", _style(Color(0.07, 0.055, 0.045), Color(0.30, 0.25, 0.19), 1, 9))
	return button


func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
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
	style.shadow_color = Color(0, 0, 0, 0.65)
	style.shadow_size = 10
	return style
