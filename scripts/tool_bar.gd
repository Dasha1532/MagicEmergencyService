extends MarginContainer

signal tool_selected(tool_id: StringName)
signal intent_selected(intent_id: StringName)

const TOOL_NAMES: Dictionary = {
	"FreezeButton": [&"freeze", "Заморозка"],
	"HeatButton": [&"heat", "Нагрев"],
	"MoveButton": [&"telekinesis", "Телекинез"],
	"PhysicalMoveButton": [&"physical_move", "Силовая работа"],
	"AnimateButton": [&"animate", "Оживление"],
	"AntimagicButton": [&"antimagic", "Антимагия"],
	"DiagnoseButton": [&"diagnose", "Осмотр"],
	"RepairButton": [&"repair", "Ремонт"],
}

@onready var title_label: Label = %TitleLabel
@onready var buttons_container: VBoxContainer = $Panel/ContentMargin/Content/Buttons
@onready var buttons: Array[Button] = [
	%FreezeButton,
	%HeatButton,
	%MoveButton,
	%PhysicalMoveButton,
	%AnimateButton,
	%AntimagicButton,
	%DiagnoseButton,
	%RepairButton,
]
var current_tool_id: StringName = &"freeze"
var available_buttons: Array[Button] = []
var temporary_buttons: Array[Button] = []
var current_object_name: String = "Объект"
var menu_height: float = 117.0
var current_action_labels: Dictionary = {}


func _ready() -> void:
	buttons_container.move_child(%DiagnoseButton, 0)
	buttons_container.move_child(%RepairButton, 1)
	for button in buttons:
		button.pressed.connect(_on_button_pressed.bind(button))
		button.toggle_mode = false
		button.custom_minimum_size = Vector2(220, 44)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var tool_data: Array = TOOL_NAMES[button.name]
		button.text = "   %s" % str(tool_data[1])
		for child: Node in button.get_children():
			if child is TextureRect:
				button.icon = child.texture
				button.expand_icon = true
				button.add_theme_constant_override("icon_max_width", 30)
				child.visible = false
	visible = false


func configure_for_employee(employee_name: String, ability_ids: PackedStringArray, core_actions: String) -> void:
	_clear_temporary_buttons()
	available_buttons.clear()
	var available_count: int = 0
	for button in buttons:
		var tool_data: Array = TOOL_NAMES[button.name]
		var is_available := ability_ids.has(String(tool_data[0]))
		button.visible = is_available
		button.disabled = not is_available
		button.button_pressed = false
		if is_available:
			available_buttons.append(button)
			available_count += 1

	_resize_for_action_count(available_count)
	current_tool_id = &""
	title_label.text = "%s  •  %s" % [employee_name, core_actions]
	visible = false


func get_selected_tool_id() -> StringName:
	return current_tool_id


func show_for_object(object_name: String, anchor_position: Vector2, action_labels: Dictionary = {}, contextual_actions: Array = []) -> void:
	current_object_name = object_name
	current_action_labels = action_labels.duplicate()
	_show_ability_buttons()
	_add_contextual_actions(contextual_actions)
	title_label.text = object_name.to_upper()
	visible = true
	position = Vector2(
		clampf(anchor_position.x + 42.0, 20.0, 1330.0),
		clampf(anchor_position.y - menu_height * 0.45, 90.0, 690.0 - menu_height)
	)
	move_to_front()


func show_intents(title: String, choices: Array) -> void:
	for button in buttons:
		button.visible = false
	_clear_temporary_buttons()
	title_label.text = title.to_upper()
	for choice: Dictionary in choices:
		var button := Button.new()
		button.text = "   %s" % str(choice.get("label", "Действие"))
		button.custom_minimum_size = Vector2(220, 44)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_copy_button_style(button)
		button.pressed.connect(_on_intent_pressed.bind(StringName(str(choice.get("id", "")))))
		buttons_container.add_child(button)
		temporary_buttons.append(button)
	var back_button := Button.new()
	back_button.text = "← Назад"
	back_button.custom_minimum_size = Vector2(220, 40)
	_copy_button_style(back_button)
	back_button.pressed.connect(_show_ability_buttons)
	buttons_container.add_child(back_button)
	temporary_buttons.append(back_button)
	_resize_for_action_count(choices.size() + 1)


func _resize_for_action_count(action_count: int) -> void:
	var visible_count: int = maxi(1, action_count)
	menu_height = 66.0 + visible_count * 51.0
	var desired_size := Vector2(248.0, menu_height)
	buttons_container.custom_minimum_size = Vector2(220.0, visible_count * 44.0 + maxi(0, visible_count - 1) * 10.0)
	custom_minimum_size = desired_size
	size = desired_size


func _on_button_pressed(button: Button) -> void:
	var tool_data: Array = TOOL_NAMES[button.name]
	current_tool_id = tool_data[0]
	tool_selected.emit(current_tool_id)


func _on_intent_pressed(intent_id: StringName) -> void:
	visible = false
	intent_selected.emit(intent_id)


func _on_context_action_pressed(action_id: StringName) -> void:
	current_tool_id = action_id
	tool_selected.emit(current_tool_id)


func _show_ability_buttons() -> void:
	_clear_temporary_buttons()
	for button in buttons:
		var tool_data: Array = TOOL_NAMES[button.name]
		button.text = "   %s" % str(current_action_labels.get(tool_data[0], tool_data[1]))
		button.visible = available_buttons.has(button)
	title_label.text = current_object_name.to_upper()
	_resize_for_action_count(available_buttons.size())


func _clear_temporary_buttons() -> void:
	for button in temporary_buttons:
		if is_instance_valid(button):
			button.queue_free()
	temporary_buttons.clear()


func _add_contextual_actions(actions: Array) -> void:
	for action: Dictionary in actions:
		var button := Button.new()
		button.text = "   %s" % str(action.get("label", "Действие"))
		button.custom_minimum_size = Vector2(220, 44)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_copy_button_style(button)
		button.pressed.connect(_on_context_action_pressed.bind(StringName(str(action.get("id", "")))))
		buttons_container.add_child(button)
		temporary_buttons.append(button)
	_resize_for_action_count(available_buttons.size() + actions.size())


func _copy_button_style(target: Button) -> void:
	var source: Button = %DiagnoseButton
	for style_name: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus"]:
		var style: StyleBox = source.get_theme_stylebox(style_name)
		if style != null:
			target.add_theme_stylebox_override(style_name, style)
	target.add_theme_color_override("font_color", Color(0.941176, 0.827451, 0.623529, 1))
	target.add_theme_font_size_override("font_size", 15)
