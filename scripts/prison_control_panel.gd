extends Control
signal closed
signal action_requested(action_id: String)
var configuration: Dictionary = {}
var current_action := "test_protection"
var switch_button: Button

func _ready() -> void:
 configuration = JSON.parse_string(FileAccess.get_file_as_string("res://data/prison/control_panel.json"))
 $Close.pressed.connect(func() -> void: closed.emit())
 switch_button = Button.new()
 switch_button.name = "Switch1"
 switch_button.position = $Panel/On1.position
 switch_button.size = $Panel/On1.size
 switch_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
 switch_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
 switch_button.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
 var hover := StyleBoxFlat.new()
 hover.bg_color = Color(1, 0.8, 0.4, 0.12)
 hover.set_border_width_all(2)
 hover.border_color = Color(1, 0.8, 0.4, 1)
 switch_button.add_theme_stylebox_override("hover", hover)
 switch_button.pressed.connect(func() -> void: action_requested.emit(current_action))
 $Panel.add_child(switch_button)

func refresh(prisoner_protection: bool, empty_protection: bool = false) -> void:
 for cell in range(1, 11):
  var enabled := false
  for active_cell in configuration.get("active_cells", []):
   if cell == int(active_cell):
    enabled = true
  if cell == int(configuration.get("prisoner_cell", 2)):
   enabled = prisoner_protection
  if cell == int(configuration.get("empty_cell", 1)):
   enabled = empty_protection
  get_node("Panel/On%d" % cell).visible = enabled

func set_action(action_id: String, available: bool) -> void:
 current_action = action_id
 switch_button.disabled = not available
 switch_button.tooltip_text = "Выключить защиту камеры № 1" if action_id == "stop_test" else ("Включить защиту камеры № 1" if available else "Сначала нужно починить замок. Повторная проверка после неисправности запрещена.")
