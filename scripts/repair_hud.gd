extends Control

signal employee_selected(employee_id: StringName)
signal completion_requested

const COLOR_PANEL := Color(0.07, 0.045, 0.03, 0.94)
const COLOR_CARD := Color(0.13, 0.09, 0.055, 0.96)
const COLOR_SELECTED := Color(0.10, 0.16, 0.18, 0.98)
const COLOR_BRASS := Color(0.76, 0.54, 0.27)
const COLOR_GOLD := Color(0.96, 0.78, 0.46)
const COLOR_PARCHMENT := Color(0.92, 0.84, 0.69)

var selected_employee_id: StringName = &""
var employee_box: HBoxContainer
var employee_panel: Panel
var complete_button: Button
var tool_bar: MarginContainer
@onready var game_state: Node = get_node("/root/GameState")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tool_bar = get_node("../ToolBar")
	if game_state.active_job_id.is_empty():
		game_state.active_job_id = game_state.selected_job_id
	_build_job_header()
	_build_employee_selector()
	_build_return_button()
	_build_complete_button()
	_select_first_employee()


func _build_job_header() -> void:
	var job: Dictionary = game_state.get_active_job()
	var panel := Panel.new()
	panel.position = Vector2(20, 18)
	panel.size = Vector2(500, 92)
	panel.add_theme_stylebox_override("panel", _style(COLOR_PANEL, COLOR_BRASS, 2, 10))
	add_child(panel)

	var title := _label(job.get("title", "Ремонт"), 23, COLOR_GOLD)
	title.position = Vector2(18, 12)
	title.size = Vector2(464, 32)
	panel.add_child(title)

	var address := _label("%s  •  %s" % [job.get("address", ""), job.get("danger", "")], 16, COLOR_PARCHMENT)
	address.position = Vector2(18, 50)
	address.size = Vector2(464, 28)
	panel.add_child(address)


func _build_employee_selector() -> void:
	employee_panel = Panel.new()
	employee_panel.position = Vector2(20, 745)
	employee_panel.size = Vector2(930, 135)
	employee_panel.add_theme_stylebox_override("panel", _style(COLOR_PANEL, COLOR_BRASS, 2, 10))
	add_child(employee_panel)

	var heading := _label("БРИГАДА", 19, COLOR_GOLD)
	heading.position = Vector2(16, 6)
	heading.size = Vector2(898, 28)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	employee_panel.add_child(heading)

	var employee_scroll := ScrollContainer.new()
	employee_scroll.position = Vector2(12, 38)
	employee_scroll.size = Vector2(906, 87)
	employee_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	employee_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	employee_panel.add_child(employee_scroll)

	employee_box = HBoxContainer.new()
	employee_box.custom_minimum_size = Vector2(906, 76)
	employee_box.add_theme_constant_override("separation", 7)
	employee_scroll.add_child(employee_box)

	var job: Dictionary = game_state.get_active_job()
	var assigned: PackedStringArray = job.get("assigned", PackedStringArray())
	for employee_id: String in assigned:
		_add_employee_button(StringName(employee_id))


func _add_employee_button(employee_id: StringName) -> void:
	var employee: Dictionary = game_state.employees[employee_id]
	var button := Button.new()
	button.custom_minimum_size = Vector2(297, 76)
	button.add_theme_stylebox_override("normal", _style(COLOR_CARD, COLOR_BRASS, 2, 7))
	button.add_theme_stylebox_override("hover", _style(Color(0.21, 0.14, 0.075, 0.98), COLOR_GOLD, 2, 7))
	button.add_theme_stylebox_override("pressed", _style(COLOR_SELECTED, COLOR_GOLD, 3, 7))
	button.pressed.connect(_select_employee.bind(employee_id))
	employee_box.add_child(button)
	button.set_meta("employee_id", employee_id)

	var portrait_frame := Panel.new()
	portrait_frame.position = Vector2(7, 5)
	portrait_frame.size = Vector2(68, 66)
	portrait_frame.clip_contents = true
	portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_theme_stylebox_override("panel", _style(Color(0.035, 0.03, 0.028, 1), COLOR_BRASS, 1, 5))
	button.add_child(portrait_frame)

	var portrait := TextureRect.new()
	portrait.position = Vector2(1, 1)
	portrait.size = Vector2(66, 64)
	portrait.texture = _cropped_portrait(employee["portrait"])
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_child(portrait)

	var name_label := _label(str(employee["name"]), 15, COLOR_GOLD)
	name_label.position = Vector2(82, 6)
	name_label.size = Vector2(203, 26)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_child(name_label)

	var role_label := _label(str(employee["core_actions"]), 13, COLOR_PARCHMENT)
	role_label.position = Vector2(82, 30)
	role_label.size = Vector2(203, 40)
	role_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	role_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	role_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_child(role_label)


func _build_return_button() -> void:
	var button := Button.new()
	button.text = "←  ВЕРНУТЬСЯ В ОФИС"
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


func set_work_ui_visible(is_visible: bool) -> void:
	if employee_panel != null:
		employee_panel.visible = is_visible
	if complete_button != null:
		complete_button.visible = is_visible


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
	if not assigned.is_empty():
		_select_employee(StringName(assigned[0]))
	else:
		tool_bar.visible = false


func _select_employee(employee_id: StringName) -> void:
	selected_employee_id = employee_id
	for child in employee_box.get_children():
		if child is Button:
			var selected: bool = child.get_meta("employee_id") == employee_id
			child.add_theme_stylebox_override("normal", _style(COLOR_SELECTED if selected else COLOR_CARD, COLOR_GOLD if selected else COLOR_BRASS, 3 if selected else 2, 7))

	var employee: Dictionary = game_state.employees[employee_id]
	tool_bar.visible = true
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


func _cropped_portrait(path: String) -> AtlasTexture:
	var portrait := AtlasTexture.new()
	portrait.atlas = load(path)
	portrait.region = Rect2(177, 0, 900, 932)
	portrait.filter_clip = true
	return portrait
