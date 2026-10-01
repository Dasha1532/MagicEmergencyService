class_name ObjectStatusEffects
extends Node2D

@export_range(24.0, 400.0, 1.0) var visual_size: float = 160.0
@export_range(24.0, 600.0, 1.0) var soot_size: float = 190.0
@export_range(-10, 10, 1) var soot_z_index: int = 0
@export var soot_modulate: Color = Color(1.0, 1.0, 1.0, 0.82)
@export var frost_offset: Vector2 = Vector2.ZERO
@export var fire_offset: Vector2 = Vector2.ZERO
@export var soot_offset: Vector2 = Vector2.ZERO
@export var fire_spot_offsets: PackedVector2Array = PackedVector2Array([Vector2.ZERO])

@onready var soot_sprite: Sprite2D = $Soot
@onready var frost_sprite: Sprite2D = $Frost
@onready var fire_sprite: Sprite2D = $Fire
var fire_sprites: Array[Sprite2D] = []
var fire_tweens: Array[Tween] = []


func _ready() -> void:
	frost_sprite.position = frost_offset
	soot_sprite.position = soot_offset
	soot_sprite.z_index = soot_z_index
	soot_sprite.modulate = soot_modulate
	frost_sprite.scale = _fitted_scale(frost_sprite.texture)
	soot_sprite.scale = _fitted_scale_for_size(soot_sprite.texture, soot_size)
	frost_sprite.visible = false
	soot_sprite.visible = false
	_prepare_fire_sprites()


func sync_from_state(object_state: Dictionary) -> void:
	# У объектов с отдельным замороженным ассетом иней не дублируется поверх него.
	var broken_with_cold := bool(object_state.get("broken", false)) and (bool(object_state.get("frozen", false)) or bool(object_state.get("cold_leak", false)) or bool(object_state.get("cold_source_active", false)))
	var frost_active: bool = broken_with_cold or (bool(object_state.get("frozen", false)) and not bool(object_state.get("uses_frozen_visual", false)))
	var fire_active: bool = bool(object_state.get("burning", false))
	var destroyed: bool = bool(object_state.get("destroyed", false))
	var soot_active: bool = bool(object_state.get("scorched", false)) and not destroyed
	var fire_spots: int = int(object_state.get("fire_spots", 1 if fire_active else 0))
	_set_frost_visible(frost_active)
	_set_soot_visible(soot_active)
	_set_fire_count(fire_spots if fire_active else 0)


func _fitted_scale(texture: Texture2D) -> Vector2:
	return _fitted_scale_for_size(texture, visual_size)


func _fitted_scale_for_size(texture: Texture2D, target_size: float) -> Vector2:
	var longest_side: float = float(maxi(texture.get_width(), texture.get_height()))
	var fitted_scale: float = target_size / longest_side
	return Vector2(fitted_scale, fitted_scale)


func _prepare_fire_sprites() -> void:
	var offsets: PackedVector2Array = fire_spot_offsets
	if offsets.is_empty():
		offsets = PackedVector2Array([Vector2.ZERO])
	for index: int in offsets.size():
		var sprite: Sprite2D
		if index == 0:
			sprite = fire_sprite
		else:
			sprite = fire_sprite.duplicate() as Sprite2D
			add_child(sprite)
		sprite.position = fire_offset + offsets[index]
		sprite.scale = _fitted_scale(sprite.texture) * (1.0 - float(index) * 0.08)
		sprite.visible = false
		fire_sprites.append(sprite)


func _set_frost_visible(value: bool) -> void:
	if frost_sprite.visible == value:
		return
	frost_sprite.visible = value
	if value:
		frost_sprite.modulate = Color(1, 1, 1, 0)
		create_tween().tween_property(frost_sprite, "modulate", Color.WHITE, 0.2)


func _set_soot_visible(value: bool) -> void:
	soot_sprite.visible = value


func _set_fire_count(count: int) -> void:
	for tween: Tween in fire_tweens:
		tween.kill()
	fire_tweens.clear()
	var visible_count: int = clampi(count, 0, fire_sprites.size())
	for index: int in fire_sprites.size():
		var sprite: Sprite2D = fire_sprites[index]
		sprite.visible = index < visible_count
		if not sprite.visible:
			continue
		var base_scale: Vector2 = _fitted_scale(sprite.texture) * (1.0 - float(index) * 0.08)
		sprite.scale = base_scale
		sprite.modulate = Color.WHITE
		var tween: Tween = create_tween().set_loops()
		var phase: float = float(index) * 0.04
		tween.tween_property(sprite, "scale", base_scale * Vector2(1.04, 0.95), 0.22 + phase).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.parallel().tween_property(sprite, "modulate", Color(1, 0.88, 0.68, 0.9), 0.22 + phase)
		tween.tween_property(sprite, "scale", base_scale * Vector2(0.97, 1.06), 0.30 + phase).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.30 + phase)
		fire_tweens.append(tween)
