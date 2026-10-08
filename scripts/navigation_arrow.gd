extends TextureButton

@export var motion_distance := 10.0
@export var motion_duration := 0.65

func _ready() -> void:
	# Animate only the image; the click area stays in its editor position.
	var image := TextureRect.new()
	image.texture = texture_normal
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.flip_h = flip_h
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(image)
	texture_normal = null
	var direction := -1.0 if flip_h else 1.0
	var motion := create_tween().set_loops()
	motion.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	motion.tween_property(image, "position:x", direction * motion_distance, motion_duration)
	motion.tween_property(image, "position:x", 0.0, motion_duration)
