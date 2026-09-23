extends Control

const TAGLINES: PackedStringArray = [
	"Спасаем дома, нервы и иногда реальность.",
	"Любая авария поправима. Последствия обсуждаются отдельно.",
	"Работаем быстро. Думаем по обстоятельствам.",
	"Даже у магии бывают технические неполадки.",
]
const PREFS_PATH := "user://menu_prefs.cfg"
const COLOR_NAV := Color(0.018, 0.026, 0.035, 0.965)
const COLOR_BUTTON := Color(0.024, 0.031, 0.041, 0.98)
const COLOR_ACTIVE := Color(0.88, 0.59, 0.28, 0.98)
const COLOR_BRASS := Color(0.81, 0.59, 0.29)
const COLOR_GOLD := Color(0.96, 0.78, 0.47)
const COLOR_SHINE := Color(1.0, 0.96, 0.79)
const COLOR_PARCHMENT := Color(0.95, 0.88, 0.76)

@onready var game_state: Node = get_node("/root/GameState")

var logo_material: ShaderMaterial
var navigation: Panel
var settings_panel: Panel
var continue_button: Button
var status_label: Label
var volume_slider: HSlider
var fullscreen_check: CheckButton
var title_font: SystemFont


func _ready() -> void:
	# Главное меню всегда должно принимать ввод, даже если предыдущая сцена
	# была закрыта или перезагружена во время паузы.
	get_tree().paused = false
	_build_interface()
	_logo_shine_loop()


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

	var tagline := _label("✦  %s  ✦" % _choose_tagline().to_upper(), 18, COLOR_PARCHMENT)
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
	navigation = Panel.new()
	navigation.position = Vector2(150, 742)
	navigation.size = Vector2(1300, 126)
	navigation.add_theme_stylebox_override("panel", _style(COLOR_NAV, COLOR_BRASS, 2, 3))
	add_child(navigation)

	continue_button = _nav_button("▶\nПРОДОЛЖИТЬ", 0)
	continue_button.disabled = not game_state.has_save()
	continue_button.tooltip_text = "Нет сохранённой игры" if continue_button.disabled else "Продолжить последнее сохранение"
	continue_button.pressed.connect(_continue_game)
	navigation.add_child(continue_button)

	var new_button := _nav_button("＋\nНОВАЯ ИГРА", 1)
	new_button.pressed.connect(_new_game)
	navigation.add_child(new_button)

	var load_button := _nav_button("▱\nЗАГРУЗИТЬ ИГРУ", 2)
	load_button.disabled = not game_state.has_save()
	load_button.tooltip_text = "Нет сохранённой игры" if load_button.disabled else "Открыть сохранённую игру"
	load_button.pressed.connect(_continue_game)
	navigation.add_child(load_button)

	var settings_button := _nav_button("⚙\nНАСТРОЙКИ", 3)
	settings_button.pressed.connect(_show_settings)
	navigation.add_child(settings_button)

	var exit_button := _nav_button("⏻\nВЫЙТИ", 4)
	exit_button.pressed.connect(_exit_game)
	navigation.add_child(exit_button)

	status_label = _label("", 15, COLOR_GOLD)
	status_label.position = Vector2(470, 696)
	status_label.size = Vector2(660, 34)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(status_label)

	var initially_active := continue_button if not continue_button.disabled else new_button
	initially_active.add_theme_stylebox_override("normal", _style(COLOR_ACTIVE, COLOR_GOLD, 2, 0))
	initially_active.add_theme_color_override("font_color", Color(0.13, 0.075, 0.025))


func _build_settings() -> void:
	settings_panel = Panel.new()
	settings_panel.position = Vector2(500, 235)
	settings_panel.size = Vector2(600, 430)
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

	fullscreen_check = CheckButton.new()
	fullscreen_check.text = "Полноэкранный режим"
	fullscreen_check.position = Vector2(55, 214)
	fullscreen_check.size = Vector2(490, 48)
	fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen_check.add_theme_font_size_override("font_size", 18)
	fullscreen_check.add_theme_color_override("font_color", COLOR_PARCHMENT)
	fullscreen_check.toggled.connect(_set_fullscreen)
	settings_panel.add_child(fullscreen_check)

	var back_button := Button.new()
	back_button.text = "НАЗАД"
	back_button.position = Vector2(55, 320)
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
	var error: Error = game_state.load_game()
	if error != OK:
		status_label.text = "Не удалось загрузить сохранение. Код ошибки: %d" % error
		return
	var target_scene := "res://scenes/main.tscn"
	var repair_scene: String = game_state.get_active_job_repair_scene()
	if not repair_scene.is_empty():
		target_scene = repair_scene
	get_tree().change_scene_to_file(target_scene)


func _show_settings() -> void:
	navigation.visible = false
	settings_panel.visible = true


func _show_main() -> void:
	settings_panel.visible = false
	navigation.visible = true


func _exit_game() -> void:
	get_tree().quit()


func _set_volume(value: float) -> void:
	var bus_index := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus_index, value <= 0.0)
	if value > 0.0:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(value / 100.0))


func _current_volume_percent() -> float:
	var bus_index := AudioServer.get_bus_index("Master")
	if AudioServer.is_bus_mute(bus_index):
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(bus_index)) * 100.0


func _set_fullscreen(enabled: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)


func _nav_button(text_value: String, index: int) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = Vector2(index * 260 + 2, 2)
	button.size = Vector2(260, 122)
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_constant_override("line_spacing", 9)
	_apply_button_theme(button)
	return button


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
