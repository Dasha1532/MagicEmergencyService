extends Node2D

## Initial presentation scene for the Magic Emergency Service prototype.
## The background is intentionally separate from the future simulation layer.

@onready var background: TextureRect = $Background


func _ready() -> void:
	_call_audio_manager(&"play_office_music")
	var image_texture := load("res://assets/backgrounds/office_hub.png") as Texture2D
	if image_texture != null:
		background.texture = image_texture


func _exit_tree() -> void:
	_call_audio_manager(&"stop_office_music")


func _call_audio_manager(method: StringName) -> void:
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager != null and audio_manager.has_method(method):
		audio_manager.call(method)
