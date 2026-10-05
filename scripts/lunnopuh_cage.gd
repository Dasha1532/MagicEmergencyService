extends Control

signal selected

@export_enum("packed", "installed", "occupied") var preview_state: String = "installed"
@onready var empty_pose: TextureRect = $Empty
@onready var occupied_pose: TextureRect = $Occupied
@onready var interaction_button: Button = $InteractionButton

func _ready() -> void:
	$InteractionButton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	interaction_button.pressed.connect(func() -> void: selected.emit())
	show_state(StringName(preview_state))

func show_state(state: StringName) -> void:
	visible = state in [&"installed", &"occupied"]
	empty_pose.visible = state == &"installed"
	occupied_pose.visible = state == &"occupied"
	interaction_button.visible = state == &"occupied"

func target_global_position() -> Vector2:
	return $Target.global_position