extends TextureRect

signal selected

func _ready() -> void:
	$InteractionButton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	$InteractionButton.pressed.connect(func() -> void: selected.emit())

func target_global_position() -> Vector2:
	return $Target.global_position
