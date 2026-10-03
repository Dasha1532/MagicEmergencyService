extends Control

signal selected

@onready var walking_pose: TextureRect = $Walking
@onready var idle_pose: TextureRect = $Idle
@onready var frozen_pose: TextureRect = $Frozen
@onready var broken_pose: TextureRect = $Broken
@onready var ash_pile: Sprite2D = $AshPile
@onready var hit_area: Button = $HitArea

var motion_tween: Tween


func _ready() -> void:
	_update_pivot()
	resized.connect(_update_pivot)
	hit_area.pressed.connect(_on_hit_area_pressed)
	show_state(&"walking")


func _update_pivot() -> void:
	# Качаем шкаф вокруг точки между ножками, а не вокруг левого верхнего угла.
	pivot_offset = Vector2(size.x * 0.5, size.y * 0.94)


func _on_hit_area_pressed() -> void:
	selected.emit()


func show_state(state: StringName) -> void:
	walking_pose.visible = state == &"walking"
	idle_pose.visible = state == &"idle"
	frozen_pose.visible = state == &"frozen"
	broken_pose.visible = state == &"broken"
	ash_pile.visible = state == &"destroyed"
	if motion_tween != null:
		motion_tween.kill()
	rotation = 0.0
	if state == &"walking":
		motion_tween = create_tween().set_loops()
		motion_tween.tween_property(self, "rotation", 0.014, 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		motion_tween.tween_property(self, "rotation", -0.014, 0.48).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		motion_tween.tween_property(self, "rotation", 0.0, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func set_interaction_enabled(enabled: bool) -> void:
	hit_area.disabled = not enabled
