extends Control

signal selected

@onready var covered_pose: TextureRect = $Covered
@onready var open_pose: TextureRect = $Open
@onready var closed_pose: TextureRect = $Closed
@onready var destroyed_pose: TextureRect = $Destroyed
@onready var interaction_button: Button = $InteractionButton
@onready var target_marker: Marker2D = $Target


func _ready() -> void:
	interaction_button.pressed.connect(func() -> void: selected.emit())
	var empty_style := StyleBoxEmpty.new()
	for state: StringName in [&"normal", &"pressed", &"focus", &"hover", &"hover_pressed", &"disabled"]:
		interaction_button.add_theme_stylebox_override(state, empty_style)


func show_state(state: StringName) -> void:
	covered_pose.visible = state == &"covered"
	open_pose.visible = state == &"open"
	closed_pose.visible = state == &"closed"
	destroyed_pose.visible = state == &"destroyed"


func set_interaction_enabled(enabled: bool) -> void:
	interaction_button.disabled = not enabled


func target_global_position() -> Vector2:
	return target_marker.global_position
