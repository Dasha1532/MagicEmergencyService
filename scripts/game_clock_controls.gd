extends Panel

const COLOR_PANEL := Color(0.07, 0.045, 0.03, 0.94)
const COLOR_BRASS := Color(0.76, 0.54, 0.27)
const COLOR_GOLD := Color(0.96, 0.78, 0.46)
const COLOR_PARCHMENT := Color(0.92, 0.84, 0.69)

var time_label: Label
var pause_button: Button
var speed_buttons: Dictionary = {}
@onready var game_state: Node = get_node("/root/GameState")


func _ready() -> void:
	size = Vector2(350, 54)
	add_theme_stylebox_override("panel", _style(COLOR_PANEL, COLOR_BRASS, 2, 8))
	time_label = Label.new()
	time_label.position = Vector2(12, 8)
	time_label.size = Vector2(72, 38)
	time_label.add_theme_font_size_override("font_size", 18)
	time_label.add_theme_color_override("font_color", COLOR_PARCHMENT)
	time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(time_label)
	pause_button = _button("Ⅱ", Vector2(88, 7), Vector2(54, 40))
	pause_button.tooltip_text = "Пауза — время остановлено, можно спокойно отдавать команды"
	pause_button.pressed.connect(func() -> void: game_state.set_clock_paused(not game_state.clock_paused))
	add_child(pause_button)
	for index in 3:
		var speed: int = [1, 2, 4][index]
		var button := _button("×%d" % speed, Vector2(148 + index * 64, 7), Vector2(58, 40))
		button.pressed.connect(_set_speed.bind(speed))
		add_child(button)
		speed_buttons[speed] = button
	game_state.state_changed.connect(_refresh)
	_refresh()


func _set_speed(speed: int) -> void:
	game_state.set_clock_speed(speed)


func _refresh() -> void:
	time_label.text = game_state.format_time()
	pause_button.text = "▶" if game_state.clock_paused else "Ⅱ"
	pause_button.add_theme_color_override("font_color", COLOR_GOLD if game_state.clock_paused else COLOR_PARCHMENT)
	for speed: int in speed_buttons:
		var button: Button = speed_buttons[speed]
		button.add_theme_color_override("font_color", COLOR_GOLD if speed == game_state.clock_speed and not game_state.clock_paused else COLOR_PARCHMENT)


func _button(text_value: String, button_position: Vector2, button_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = button_position
	button.size = button_size
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_stylebox_override("normal", _style(Color(0.13, 0.09, 0.055, 0.96), COLOR_BRASS, 1, 6))
	button.add_theme_stylebox_override("hover", _style(Color(0.21, 0.14, 0.075, 0.98), COLOR_GOLD, 2, 6))
	return button


func _style(background: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style
