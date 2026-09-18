class_name ObjectStatusEffects
extends Node2D

@export_range(24.0, 400.0, 1.0) var visual_size: float = 160.0
@export var frost_offset: Vector2 = Vector2.ZERO
@export var fire_offset: Vector2 = Vector2.ZERO

@onready var frost_sprite: Sprite2D = $Frost
@onready var fire_sprite: Sprite2D = $Fire
var fire_tween: Tween
var fire_base_scale: Vector2


func _ready() -> void:
	frost_sprite.position = frost_offset
	fire_sprite.position = fire_offset
	frost_sprite.scale = _fitted_scale(frost_sprite.texture)
	fire_sprite.scale = _fitted_scale(fire_sprite.texture)
	fire_base_scale = fire_sprite.scale
	frost_sprite.visible = false
	fire_sprite.visible = false


func sync_from_state(object_state: Dictionary) -> void:
	var frost_active: bool = bool(object_state.get("frozen", false))
	var fire_active: bool = bool(object_state.get("burning", false))
	_set_frost_visible(frost_active)
	_set_fire_visible(fire_active)


func _fitted_scale(texture: Texture2D) -> Vector2:
	var longest_side: float = float(maxi(texture.get_width(), texture.get_height()))
	var fitted_scale: float = visual_size / longest_side
	return Vector2(fitted_scale, fitted_scale)


func _set_frost_visible(value: bool) -> void:
	if frost_sprite.visible == value:
		return
	frost_sprite.visible = value
	if value:
		frost_sprite.modulate = Color(1, 1, 1, 0)
		create_tween().tween_property(frost_sprite, "modulate", Color.WHITE, 0.2)


func _set_fire_visible(value: bool) -> void:
	if fire_sprite.visible == value:
		return
	if fire_tween != null:
		fire_tween.kill()
		fire_tween = null
	fire_sprite.scale = fire_base_scale
	fire_sprite.visible = value
	if not value:
		return
	fire_sprite.modulate = Color.WHITE
	fire_tween = create_tween().set_loops()
	fire_tween.tween_property(fire_sprite, "scale", fire_base_scale * Vector2(1.025, 0.965), 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fire_tween.parallel().tween_property(fire_sprite, "modulate", Color(1, 0.91, 0.76, 0.9), 0.24)
	fire_tween.tween_property(fire_sprite, "scale", fire_base_scale * Vector2(0.98, 1.035), 0.31).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fire_tween.parallel().tween_property(fire_sprite, "modulate", Color.WHITE, 0.31)
