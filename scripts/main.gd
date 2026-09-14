extends Node2D

## Initial presentation scene for the Magic Emergency Service prototype.
## The background is intentionally separate from the future simulation layer.

@onready var background: TextureRect = $Background


func _ready() -> void:
	var image_texture := load("res://assets/backgrounds/office.png") as Texture2D
	if image_texture != null:
		background.texture = image_texture
