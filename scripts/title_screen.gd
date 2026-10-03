extends Control

const SaveSlotsPanelScript := preload("res://scripts/save_slots_panel.gd")
var debug_wardrobe_picker: OptionButton
const DEBUG_WARDROBE_VARIANTS := [&"", &"restless_animation", &"active_fire", &"deep_freeze"]


func _toggle_debug_wardrobe_picker() -> void:
	if not OS.is_debug_build():
		return
	if debug_wardrobe_picker == null:
		debug_wardrobe_picker = OptionButton.new()
		debug_wardrobe_picker.position = Vector2(72, 710)
		debug_wardrobe_picker.custom_minimum_size = Vector2(390, 48)
		debug_wardrobe_picker.add_theme_font_size_override("font_size", 20)
		debug_wardrobe_picker.add_item("Проверка шкафа: случайный вариант")
		debug_wardrobe_picker.add_item("Проверка шкафа: ходячий")
		debug_wardrobe_picker.add_item("Проверка шкафа: горящий")
		debug_wardrobe_picker.add_item("Проверка шкафа: замёрзший")
		debug_wardrobe_picker.tooltip_text = "Выбор для следующей новой игры. Загрузка сохранений не меняется."
		debug_wardrobe_picker.item_selected.connect(func(index: int) -> void: game_state.debug_next_wardrobe_anomaly = DEBUG_WARDROBE_VARIANTS[index])
		add_child(debug_wardrobe_picker)
	else:
		debug_wardrobe_picker.visible = not debug_wardrobe_picker.visible

const TAGLINES: PackedStringArray = [
	"Спасаем дома, нервы и иногда реальность",
	"Любая авария поправима. Последствия обсуждаются отдельно",
	"Работаем быстро. Думаем по обстоятельствам",
	"Даже у магии бывают технические неполадки",
]
const PREFS_PATH := "user://menu_prefs.cfg"
const COLOR_NAV := Color(0.018, 0.026, 0.035, 0.965)
const COLOR_BUTTON := Color(0.024, 0.031, 0.041, 0.98)
const COLOR_ACTIVE := Color(0.88, 0.59, 0.28, 0.98)
const COLOR_BRASS := Color(0.81, 0.59, 0.29)
const COLOR_GOLD := Color(0.96, 0.78, 0.47)
const COLOR_SHINE := Color(1.0, 0.96, 0.79)
const COLOR_PARCHMENT := Color(0.95, 0.88, 0.76)
const WINDOW_RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]

@onready var game_state: Node = get_node("/root/GameState")

var logo_material: ShaderMaterial
var navigation: Panel
var settings_panel: Panel
var continue_button: Button
var status_label: Label
var volume_slider: HSlider
var fullscreen_check: CheckButton
var resolution_option: OptionButton
var language_option: OptionButton
var title_font: SystemFont
var slots_panel


func _ready() -> void:
	# Главное меню всегда должно принимать ввод, даже если предыдущая сцена
	# была закрыта или перезагружена во время паузы.
	get_tree().paused = false
	_call_audio_manager(&"play_main_menu_music")
	_build_interface()
	_build_slots_panel()
	_logo_shine_loop()


func _exit_tree() -> void:
	_call_audio_manager(&"stop_main_menu_music")


func _call_audio_manager(method: StringName) -> void:
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager != null and audio_manager.has_method(method):
		audio_manager.call(method)


func _build_interface() -> void:
	var background := TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.texture = load("res://assets/backgrounds/title_screen.png") as Texture2D
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.0, 0.018, 0.08)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	_build_title()
	_build_navigation()
	_build_settings()
	if OS.is_debug_build():
		var debug_button := Button.new()
		debug_button.name = "DebugWardrobeButton"
		debug_button.text = "Проверка шкафа"
		debug_button.position = Vector2(72, 650)
		debug_button.custom_minimum_size = Vector2(250, 48)
		debug_button.add_theme_font_size_override("font_size", 20)
		debug_button.add_theme_color_override("font_color", COLOR_PARCHMENT)
		debug_button.add_theme_stylebox_override("normal", _style(COLOR_BUTTON, COLOR_BRASS, 2, 8))
		debug_button.pressed.connect(_toggle_debug_wardrobe_picker)
		add_child(debug_button)


func _build_title() -> void:
	title_font = SystemFont.new()
	title_font.font_names = PackedStringArray(["Georgia", "Times New Roman"])
	title_font.font_weight = 600

	var logo := TextureRect.new()
	logo.position = Vector2(72, 18)
	logo.size = Vector2(820, 462)
	logo.texture = load("res://assets/ui/title_logo.png") as Texture2D
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo_material = ShaderMaterial.new()
	logo_material.shader = load("res://shaders/title_logo_shine.gdshader") as Shader
	logo_material.set_shader_parameter("shine_position", -0.35)
	logo.material = logo_material
	add_child(logo)

	var tagline := _label("✦  %s  ✦" % tr(_choose_tagline()).to_upper(), 18, COLOR_PARCHMENT)
	tagline.add_theme_font_override("font", title_font)
	tagline.position = Vector2(92, 445)
	tagline.size = Vector2(780, 42)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(tagline)

	var rule := ColorRect.new()
	rule.color = Color(COLOR_BRASS, 0.82)
	rule.position = Vector2(226, 498)
	rule.size = Vector2(510, 2)
	add_child(rule)

	var diamond := _label("◇", 24, COLOR_GOLD)
	diamond.position = Vector2(470, 483)
	diamond.size = Vector2(24, 30)
	diamond.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(diamond)


func _build_navigation() -> void:
	navigation = $Navigation
	navigation.add_theme_stylebox_override("panel", _style(COLOR_NAV, COLOR_BRASS, 2, 3))
	navigation.move_to_front()

	continue_button = $Navigation/ContinueButton
	_configure_nav_button(continue_button)
	continue_button.disabled = not game_state.has_save()
	_set_nav_button_visual(continue_button, &"disabled" if continue_button.disabled else &"normal")
	continue_button.tooltip_text = "Нет сохранённой игры" if continue_button.disabled else "Продолжить последнее сохранение"
	continue_button.pressed.connect(_continue_game)

	var new_button := $Navigation/NewGameButton as Button
	_configure_nav_button(new_button)
	new_button.pressed.connect(_new_game)

	var load_button := $Navigation/LoadButton as Button
	_configure_nav_button(load_button)
	load_button.disabled = not game_state.has_save()
	_set_nav_button_visual(load_button, &"disabled" if load_button.disabled else &"normal")
	load_button.tooltip_text = "Нет сохранённой игры" if load_button.disabled else "Открыть сохранённую игру"
	load_button.pressed.connect(_show_load_slots)

	var settings_button := $Navigation/SettingsButton as Button
	_configure_nav_button(settings_button)
	settings_button.pressed.connect(_show_settings)

	var exit_button := $Navigation/ExitButton as Button
	_configure_nav_button(exit_button)
	exit_button.pressed.connect(_exit_game)

	status_label = _label("", 15, COLOR_GOLD)
	status_label.position = Vector2(470, 636)
	status_label.size = Vector2(660, 34)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(status_label)


func _build_settings() -> void:
	settings_panel = Panel.new()
	settings_panel.position = Vector2(500, 195)
	settings_panel.size = Vector2(600, 590)
	settings_panel.visible = false
	settings_panel.add_theme_stylebox_override("panel", _style(Color(0.025, 0.026, 0.032, 0.985), COLOR_BRASS, 2, 12))
	add_child(settings_panel)

	var heading := _label("НАСТРОЙКИ", 30, COLOR_GOLD)
	heading.position = Vector2(40, 28)
	heading.size = Vector2(520, 45)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_panel.add_child(heading)

	var audio_label := _label("Общая громкость", 18, COLOR_PARCHMENT)
	audio_label.position = Vector2(55, 105)
	audio_label.size = Vector2(490, 30)
	settings_panel.add_child(audio_label)

	volume_slider = HSlider.new()
	volume_slider.position = Vector2(55, 145)
	volume_slider.size = Vector2(490, 34)
	volume_slider.min_value = 0.0
	volume_slider.max_value = 100.0
	volume_slider.step = 1.0
	volume_slider.value = _current_volume_percent()
	volume_slider.value_changed.connect(_set_volume)
	settings_panel.add_child(volume_slider)

	var resolution_label := _label("Разрешение окна", 18, COLOR_PARCHMENT)
	resolution_label.position = Vector2(55, 195)
	resolution_label.size = Vector2(490, 30)
	settings_panel.add_child(resolution_label)

	resolution_option = OptionButton.new()
	resolution_option.position = Vector2(55, 230)
	resolution_option.size = Vector2(490, 48)
	resolution_option.add_theme_font_size_override("font_size", 18)
	for resolution: Vector2i in WINDOW_RESOLUTIONS:
		resolution_option.add_item("%d × %d" % [resolution.x, resolution.y])
	resolution_option.select(_current_resolution_index())
	resolution_option.item_selected.connect(_set_resolution)
	settings_panel.add_child(resolution_option)

	fullscreen_check = CheckButton.new()
	fullscreen_check.text = "Полноэкранный режим"
	fullscreen_check.position = Vector2(55, 300)
	fullscreen_check.size = Vector2(490, 48)
	fullscreen_check.button_pressed = _is_fullscreen()
	fullscreen_check.add_theme_font_size_override("font_size", 18)
	fullscreen_check.add_theme_color_override("font_color", COLOR_PARCHMENT)
	fullscreen_check.toggled.connect(_set_fullscreen)
	settings_panel.add_child(fullscreen_check)
	resolution_option.disabled = fullscreen_check.button_pressed
	resolution_option.tooltip_text = "В полноэкранном режиме используется разрешение экрана." if resolution_option.disabled else "Размер игрового окна."

	var language_label := _label("Язык", 18, COLOR_PARCHMENT)
	language_label.position = Vector2(55, 365)
	language_label.size = Vector2(160, 30)
	settings_panel.add_child(language_label)

	language_option = OptionButton.new()
	language_option.position = Vector2(220, 355)
	language_option.size = Vector2(325, 48)
	language_option.add_theme_font_size_override("font_size", 18)
	language_option.add_item("Русский")
	language_option.set_item_metadata(0, "ru")
	language_option.add_item("English")
	language_option.set_item_metadata(1, "en")
	language_option.select(1 if _current_language() == "en" else 0)
	language_option.item_selected.connect(_set_language)
	settings_panel.add_child(language_option)

	var back_button := Button.new()
	back_button.text = "НАЗАД"
	back_button.position = Vector2(55, 465)
	back_button.size = Vector2(490, 62)
	_apply_button_theme(back_button)
	back_button.pressed.connect(_show_main)
	settings_panel.add_child(back_button)


func _logo_shine_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(5.5).timeout
		if not is_instance_valid(logo_material):
			return
		logo_material.set_shader_parameter("shine_position", -0.35)
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.tween_method(_set_logo_shine, -0.35, 1.42, 1.65)
		await tween.finished


func _set_logo_shine(shine_position: float) -> void:
	logo_material.set_shader_parameter("shine_position", shine_position)


func _choose_tagline() -> String:
	var config := ConfigFile.new()
	config.load(PREFS_PATH)
	var previous := int(config.get_value("title", "last_tagline", -1))
	var choices: Array[int] = []
	for index in TAGLINES.size():
		if index != previous:
			choices.append(index)
	var selected: int = choices.pick_random()
	config.set_value("title", "last_tagline", selected)
	config.save(PREFS_PATH)
	return TAGLINES[selected]


func _new_game() -> void:
	game_state.start_new_game()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _continue_game() -> void:
	var error: Error = game_state.load_latest_game()
	if error != OK:
		status_label.text = tr("Не удалось загрузить сохранение. Код ошибки: %d") % error
		return
	_open_loaded_game()


func _load_slot(slot: int) -> void:
	var error: Error = game_state.load_autosave() if slot == 0 else game_state.load_game(slot)
	if error != OK:
		status_label.text = tr("Не удалось загрузить сохранение. Код ошибки: %d") % error
		return
	_open_loaded_game()


func _open_loaded_game() -> void:
	var target_scene := "res://scenes/main.tscn"
	var repair_scene: String = game_state.get_active_job_repair_scene()
	if not repair_scene.is_empty():
		target_scene = repair_scene
	get_tree().change_scene_to_file(target_scene)


func _build_slots_panel() -> void:
	slots_panel = SaveSlotsPanelScript.new()
	slots_panel.configure(&"load")
	slots_panel.visible = false
	slots_panel.slot_selected.connect(_load_slot)
	slots_panel.cancelled.connect(_hide_load_slots)
	add_child(slots_panel)


func _show_load_slots() -> void:
	navigation.visible = false
	settings_panel.visible = false
	slots_panel.refresh()
	slots_panel.visible = true


func _hide_load_slots() -> void:
	slots_panel.visible = false
	navigation.visible = true


func _show_settings() -> void:
	navigation.visible = false
	settings_panel.visible = true


func _show_main() -> void:
	settings_panel.visible = false
	navigation.visible = true


func _exit_game() -> void:
	get_tree().quit()


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
	if resolution_option != null:
		resolution_option.disabled = enabled
		resolution_option.tooltip_text = "В полноэкранном режиме используется разрешение экрана." if enabled else "Размер игрового окна."


func _is_fullscreen() -> bool:
	var settings_manager := get_node_or_null("/root/SettingsManager")
	return bool(settings_manager.call(&"is_fullscreen")) if settings_manager != null else false


func _set_resolution(index: int) -> void:
	if index < 0 or index >= WINDOW_RESOLUTIONS.size():
		return
	var settings_manager := get_node_or_null("/root/SettingsManager")
	if settings_manager != null:
		settings_manager.call(&"set_window_resolution", WINDOW_RESOLUTIONS[index])


func _current_resolution_index() -> int:
	var settings_manager := get_node_or_null("/root/SettingsManager")
	if settings_manager == null:
		return 1
	var current: Vector2i = settings_manager.call(&"get_window_resolution")
	var index := WINDOW_RESOLUTIONS.find(current)
	return index if index >= 0 else 1


func _set_language(index: int) -> void:
	if language_option == null or index < 0 or index >= language_option.item_count:
		return
	var settings_manager := get_node_or_null("/root/SettingsManager")
	if settings_manager != null:
		settings_manager.call(&"set_language", str(language_option.get_item_metadata(index)))
	# Rebuild the screen so dynamically composed captions and tooltips also update.
	get_tree().reload_current_scene()


func _current_language() -> String:
	var settings_manager := get_node_or_null("/root/SettingsManager")
	return str(settings_manager.call(&"get_language")) if settings_manager != null else "ru"


func _configure_nav_button(button: Button) -> void:
	var empty_style := StyleBoxEmpty.new()
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		button.add_theme_stylebox_override(state, empty_style)
	button.mouse_entered.connect(_set_nav_button_visual.bind(button, &"hover"))
	button.mouse_exited.connect(_set_nav_button_visual.bind(button, &"normal"))
	button.button_down.connect(_set_nav_button_visual.bind(button, &"pressed"))
	button.button_up.connect(_set_nav_button_visual.bind(button, &"hover"))
	_set_nav_button_visual(button, &"normal")


func _set_nav_button_visual(button: Button, state: StringName) -> void:
	if button.disabled:
		state = &"disabled"
	var plaque := button.get_node("Plaque") as TextureRect
	var medallion := button.get_node("Medallion") as TextureRect
	var caption := button.get_node("Caption") as Label
	match state:
		&"hover":
			plaque.modulate = Color(1.0, 0.92, 0.76)
			medallion.modulate = Color(0.88, 0.86, 0.82)
			caption.add_theme_color_override("font_color", COLOR_SHINE)
		&"pressed":
			plaque.modulate = Color(0.70, 0.66, 0.58)
			medallion.modulate = Color(0.66, 0.64, 0.60)
			caption.add_theme_color_override("font_color", COLOR_GOLD)
		&"disabled":
			plaque.modulate = Color(0.34, 0.33, 0.31, 0.76)
			medallion.modulate = Color(0.34, 0.32, 0.30, 0.72)
			caption.add_theme_color_override("font_color", Color(0.48, 0.45, 0.40))
		_:
			plaque.modulate = Color(0.82, 0.82, 0.82)
			medallion.modulate = Color(0.78, 0.78, 0.78)
			caption.add_theme_color_override("font_color", COLOR_PARCHMENT)


func _apply_button_theme(button: Button) -> void:
	button.add_theme_color_override("font_color", COLOR_PARCHMENT)
	button.add_theme_color_override("font_hover_color", Color(0.13, 0.075, 0.025))
	button.add_theme_color_override("font_pressed_color", Color(0.13, 0.075, 0.025))
	button.add_theme_color_override("font_disabled_color", Color(0.39, 0.38, 0.37))
	button.add_theme_stylebox_override("normal", _style(COLOR_BUTTON, Color(COLOR_BRASS, 0.54), 1, 0))
	button.add_theme_stylebox_override("hover", _style(COLOR_ACTIVE, COLOR_GOLD, 2, 0))
	button.add_theme_stylebox_override("pressed", _style(Color(0.98, 0.73, 0.41), COLOR_SHINE, 2, 0))
	button.add_theme_stylebox_override("focus", _style(Color(0.22, 0.135, 0.055), COLOR_GOLD, 2, 0))
	button.add_theme_stylebox_override("disabled", _style(Color(0.018, 0.021, 0.026), Color(0.26, 0.23, 0.18), 1, 0))


func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.96))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 3)
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
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_color = Color(0, 0, 0, 0.72)
	style.shadow_size = 12
	return style
