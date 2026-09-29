class_name SaveSlotsPanel
extends Control

signal slot_selected(slot: int)
signal cancelled

const COLOR_PANEL := Color(0.07, 0.045, 0.03, 0.99)
const COLOR_BUTTON := Color(0.13, 0.09, 0.055, 0.98)
const COLOR_HOVER := Color(0.22, 0.145, 0.075, 1.0)
const COLOR_BRASS := Color(0.76, 0.54, 0.27)
const COLOR_GOLD := Color(0.96, 0.78, 0.46)
const COLOR_TEXT := Color(0.92, 0.84, 0.69)
const COLOR_MUTED := Color(0.69, 0.62, 0.52)

@onready var game_state: Node = get_node("/root/GameState")

var mode: StringName = &"load"
var heading: Label
var slot_buttons: Array[Button] = []
var autosave_button: Button
var pending_overwrite_slot: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	refresh()


func configure(new_mode: StringName) -> void:
	mode = new_mode if new_mode in [&"save", &"load"] else &"load"
	pending_overwrite_slot = 0
	if is_node_ready():
		refresh()


func refresh() -> void:
	if heading == null:
		return
	heading.text = tr("ВЫБЕРИТЕ СЛОТ СОХРАНЕНИЯ") if mode == &"save" else tr("ВЫБЕРИТЕ СОХРАНЕНИЕ")
	var autosave_summary: Dictionary = game_state.get_autosave_summary()
	if bool(autosave_summary.get("exists", false)):
		var tutorial_line := str(autosave_summary.get("tutorial_label", ""))
		autosave_button.text = tr("АВТОСОХРАНЕНИЕ\nДень %d, %s, %d монет, репутация %d%s") % [
			int(autosave_summary["day"]), str(autosave_summary["time"]), int(autosave_summary["money"]),
			int(autosave_summary["reputation"]), "\n%s" % tr(tutorial_line) if not tutorial_line.is_empty() else "",
		]
		autosave_button.disabled = mode == &"save"
	else:
		autosave_button.text = tr("АВТОСОХРАНЕНИЕ\nПУСТО")
		autosave_button.disabled = true
	for index in slot_buttons.size():
		var slot := index + 1
		var summary: Dictionary = game_state.get_save_slot_summary(slot)
		var button := slot_buttons[index]
		if bool(summary.get("exists", false)):
			var overwrite_hint := ""
			if mode == &"save":
				overwrite_hint = "\n%s" % (tr("Нажмите ещё раз, чтобы перезаписать") if pending_overwrite_slot == slot else tr("Нажмите, чобы выбрать"))
			button.text = tr("СЛОТ %d\nДень %d, %s, %d монет, репутация %d%s") % [
				slot, int(summary["day"]), str(summary["time"]), int(summary["money"]), int(summary["reputation"]),
				overwrite_hint,
			]
			button.disabled = false
		else:
			button.text = tr("СЛОТ %d\nПУСТО") % slot
			button.disabled = mode == &"load"


func _build() -> void:
	var dimmer := ColorRect.new()
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.01, 0.008, 0.006, 0.82)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dimmer)

	var panel := Panel.new()
	panel.position = Vector2(500, 32)
	panel.size = Vector2(600, 836)
	panel.add_theme_stylebox_override("panel", _style(COLOR_PANEL, COLOR_BRASS, 3, 14))
	add_child(panel)

	heading = _label("", 28, COLOR_GOLD)
	heading.position = Vector2(35, 24)
	heading.size = Vector2(530, 45)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(heading)

	autosave_button = _slot_button(Vector2(55, 82), Vector2(490, 82))
	autosave_button.pressed.connect(_select_slot.bind(0))
	panel.add_child(autosave_button)

	for index: int in range(game_state.SAVE_SLOT_COUNT):
		var slot: int = index + 1
		var button := _slot_button(Vector2(55, 174 + index * 101), Vector2(490, 86))
		button.pressed.connect(_select_slot.bind(slot))
		panel.add_child(button)
		slot_buttons.append(button)

	var back := Button.new()
	back.text = tr("НАЗАД")
	back.position = Vector2(150, 758)
	back.size = Vector2(300, 56)
	back.add_theme_font_size_override("font_size", 18)
	back.add_theme_color_override("font_color", COLOR_TEXT)
	back.add_theme_stylebox_override("normal", _style(COLOR_BUTTON, COLOR_BRASS, 2, 9))
	back.add_theme_stylebox_override("hover", _style(COLOR_HOVER, COLOR_GOLD, 2, 9))
	back.pressed.connect(func() -> void: cancelled.emit())
	panel.add_child(back)


func _select_slot(slot: int) -> void:
	if slot == 0:
		if mode == &"load" and game_state.has_autosave():
			slot_selected.emit(0)
		return
	if mode == &"save" and game_state.has_save(slot) and pending_overwrite_slot != slot:
		pending_overwrite_slot = slot
		refresh()
		return
	pending_overwrite_slot = 0
	slot_selected.emit(slot)


func _slot_button(button_position: Vector2, button_size: Vector2) -> Button:
	var button := Button.new()
	button.position = button_position
	button.size = button_size
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_disabled_color", COLOR_MUTED)
	button.add_theme_stylebox_override("normal", _style(COLOR_BUTTON, COLOR_BRASS, 2, 9))
	button.add_theme_stylebox_override("hover", _style(COLOR_HOVER, COLOR_GOLD, 2, 9))
	button.add_theme_stylebox_override("pressed", _style(Color(0.09, 0.15, 0.17), COLOR_GOLD, 3, 9))
	button.add_theme_stylebox_override("disabled", _style(Color(0.07, 0.055, 0.045), Color(0.3, 0.25, 0.19), 1, 9))
	return button


func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _style(background: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0, 0, 0, 0.65)
	style.shadow_size = 10
	return style
