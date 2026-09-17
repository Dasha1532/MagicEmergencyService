extends MarginContainer

signal tool_selected(tool_id: StringName)

const TOOL_NAMES: Dictionary = {
	"FreezeButton": [&"freeze", "Заморозка"],
	"HeatButton": [&"heat", "Нагрев"],
	"MoveButton": [&"telekinesis", "Телекинез"],
	"PhysicalMoveButton": [&"physical_move", "Силовая работа"],
	"AnimateButton": [&"animate", "Оживление"],
	"AntimagicButton": [&"antimagic", "Антимагия"],
}

@onready var title_label: Label = %TitleLabel
@onready var buttons: Array[Button] = [
	%FreezeButton,
	%HeatButton,
	%MoveButton,
	%PhysicalMoveButton,
	%AnimateButton,
	%AntimagicButton,
]
var current_tool_id: StringName = &"freeze"


func _ready() -> void:
	for button in buttons:
		button.toggled.connect(_on_button_toggled.bind(button))

	%FreezeButton.button_pressed = true


func configure_for_employee(employee_name: String, ability_ids: PackedStringArray, core_actions: String) -> void:
	var first_available: Button = null
	var available_count: int = 0
	for button in buttons:
		var tool_data: Array = TOOL_NAMES[button.name]
		var is_available := ability_ids.has(String(tool_data[0]))
		button.visible = is_available
		button.disabled = not is_available
		button.button_pressed = false
		if is_available and first_available == null:
			first_available = button
		if is_available:
			available_count += 1

	_resize_for_action_count(available_count)

	if first_available != null:
		first_available.button_pressed = true
	else:
		current_tool_id = &""
		title_label.text = "%s  •  %s" % [employee_name, core_actions]
		tool_selected.emit(current_tool_id)


func get_selected_tool_id() -> StringName:
	return current_tool_id


func _resize_for_action_count(action_count: int) -> void:
	var visible_count := maxi(1, action_count)
	var panel_height: float = 82.0 + visible_count * 84.0 + maxi(0, visible_count - 1) * 10.0
	offset_top = -panel_height * 0.5
	offset_bottom = panel_height * 0.5


func _on_button_toggled(is_pressed: bool, button: Button) -> void:
	if not is_pressed:
		return

	var tool_data: Array = TOOL_NAMES[button.name]
	current_tool_id = tool_data[0]
	title_label.text = str(tool_data[1]).to_upper()
	tool_selected.emit(current_tool_id)
