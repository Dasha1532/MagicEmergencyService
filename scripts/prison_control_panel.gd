extends Control
signal closed
var configuration: Dictionary = {}

func _ready() -> void:
 configuration = JSON.parse_string(FileAccess.get_file_as_string("res://data/prison/control_panel.json"))
 $Close.pressed.connect(func() -> void: closed.emit())

func refresh(prisoner_protection: bool) -> void:
 for cell in range(1, 11):
  var enabled := false
  for active_cell in configuration.get("active_cells", []):
   if cell == int(active_cell):
    enabled = true
  if cell == int(configuration.get("prisoner_cell", 2)):
   enabled = prisoner_protection
  get_node("Panel/On%d" % cell).visible = enabled
