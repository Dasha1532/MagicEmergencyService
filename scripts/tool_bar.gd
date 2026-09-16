extends MarginContainer

signal tool_selected(tool_id: StringName)

const TOOL_NAMES: Dictionary = {
	"FreezeButton": [&"freeze", "Заморозка"],
	"HeatButton": [&"heat", "Нагрев"],
	"MoveButton": [&"move", "Перемещение"],
	"AnimateButton": [&"animate", "Оживление"],
	"AntimagicButton": [&"antimagic", "Антимагия"],
}

@onready var title_label: Label = %TitleLabel
@onready var buttons: Array[Button] = [
	%FreezeButton,
	%HeatButton,
	%MoveButton,
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
	for button in buttons:
		var tool_data: Array = TOOL_NAMES[button.name]
		var is_available := ability_ids.has(String(tool_data[0]))
		button.disabled = not is_available
		button.button_pressed = false
		if is_available and first_available == null:
			first_available = button

	if first_available != null:
		first_available.button_pressed = true
	else:
		current_tool_id = &""
		title_label.text = "%s  •  %s" % [employee_name, core_actions]
		tool_selected.emit(current_tool_id)


func get_selected_tool_id() -> StringName:
	return current_tool_id


func _on_button_toggled(is_pressed: bool, button: Button) -> void:
	if not is_pressed:
		return

	var tool_data: Array = TOOL_NAMES[button.name]
	current_tool_id = tool_data[0]
	title_label.text = "Набор инструментов  •  выбран: %s" % tool_data[1]
	tool_selected.emit(current_tool_id)
