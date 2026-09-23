extends Control

signal selected

@onready var calm_pose: TextureRect = $Calm
@onready var angry_pose: TextureRect = $Angry
@onready var interaction_button: Button = $InteractionButton
@onready var target_marker: Marker2D = $Target


func _ready() -> void:
	interaction_button.pressed.connect(func() -> void: selected.emit())
	var empty_style := StyleBoxEmpty.new()
	for state: StringName in [&"normal", &"pressed", &"focus", &"hover", &"hover_pressed", &"disabled"]:
		interaction_button.add_theme_stylebox_override(state, empty_style)


func show_state(state: StringName) -> void:
	calm_pose.visible = state == &"calm"
	angry_pose.visible = state == &"angry"
	visible = state not in [&"expelled", &"captured"]


func set_interaction_enabled(enabled: bool) -> void:
	interaction_button.disabled = not enabled


func target_global_position() -> Vector2:
	return target_marker.global_position
