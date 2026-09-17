extends Control

var idle_tween: Tween


func _ready() -> void:
	pivot_offset = Vector2(size.x * 0.5, size.y)
	if not Engine.is_editor_hint():
		_start_idle_motion()


func _start_idle_motion() -> void:
	if idle_tween != null:
		idle_tween.kill()
	idle_tween = create_tween().set_loops()
	idle_tween.tween_property(self, "scale", Vector2(1.004, 0.997), 1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	idle_tween.parallel().tween_property(self, "rotation", 0.0035, 1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	idle_tween.tween_property(self, "scale", Vector2(0.998, 1.003), 1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	idle_tween.parallel().tween_property(self, "rotation", -0.0025, 1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
