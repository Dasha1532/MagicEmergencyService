extends TextureRect
@export var breath_amount := 0.0015
@export var period := 2.8
var idle_tween: Tween
func _ready() -> void:
	resized.connect(_update_pivot)
	_update_pivot.call_deferred()
	idle_tween = create_tween().set_loops()
	# Лёгкая смена опоры без растяжения по высоте и перемещения вверх.
	idle_tween.tween_property(self, "scale:x", 1.0 + breath_amount, period).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	idle_tween.parallel().tween_property(self, "rotation", 0.0012, period).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	idle_tween.tween_property(self, "scale:x", 1.0 - breath_amount, period).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	idle_tween.parallel().tween_property(self, "rotation", -0.0012, period).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
func _update_pivot() -> void:
	pivot_offset = Vector2(size.x * 0.5, size.y)
