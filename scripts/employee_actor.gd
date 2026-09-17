extends Control

signal action_impact(action_id: StringName)
signal action_finished

@onready var neutral_pose: TextureRect = $NeutralPose
@onready var cast_pose: TextureRect = $CastPose

var idle_tween: Tween
var action_in_progress: bool = false


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


func play_action(action_id: StringName, target_global_position: Vector2) -> void:
	if action_in_progress:
		return
	action_in_progress = true
	if idle_tween != null:
		idle_tween.pause()
	rotation = 0.0
	scale = Vector2.ONE
	cast_pose.visible = true
	cast_pose.modulate = Color(1, 1, 1, 0)
	var pose_tween := create_tween().set_parallel(true)
	pose_tween.tween_property(neutral_pose, "modulate", Color(1, 1, 1, 0), 0.18)
	pose_tween.tween_property(cast_pose, "modulate", Color.WHITE, 0.18)
	await pose_tween.finished

	var charge := _create_charge_effect(action_id)
	var charge_tween := create_tween().set_parallel(true)
	charge_tween.tween_property(charge, "scale", Vector2(1.15, 1.15), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	charge_tween.tween_property(charge, "rotation", TAU * 0.35, 0.3).set_trans(Tween.TRANS_SINE)
	charge_tween.tween_property(charge, "modulate", Color.WHITE, 0.16)
	await charge_tween.finished

	var projectile := _create_projectile(action_id, target_global_position)
	charge.queue_free()
	var flight := create_tween().set_parallel(true)
	flight.tween_property(projectile, "global_position", target_global_position, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	flight.tween_property(projectile, "scale", Vector2(1.28, 1.28), 0.42).set_trans(Tween.TRANS_SINE)
	await flight.finished
	action_impact.emit(action_id)

	var flash := create_tween().set_parallel(true)
	flash.tween_property(projectile, "scale", Vector2(2.2, 2.2), 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	flash.tween_property(projectile, "modulate", Color(1, 1, 1, 0), 0.13)
	await flash.finished
	projectile.queue_free()

	var return_tween := create_tween().set_parallel(true)
	return_tween.tween_property(cast_pose, "modulate", Color(1, 1, 1, 0), 0.22)
	return_tween.tween_property(neutral_pose, "modulate", Color.WHITE, 0.22)
	await return_tween.finished
	cast_pose.visible = false
	neutral_pose.modulate = Color.WHITE
	action_in_progress = false
	if idle_tween != null:
		idle_tween.play()
	action_finished.emit()


func _create_projectile(action_id: StringName, target_global_position: Vector2) -> Node2D:
	var projectile := Node2D.new()
	get_parent().add_child(projectile)
	projectile.global_position = _spell_origin_global()
	projectile.rotation = (target_global_position - projectile.global_position).angle()
	var color := _magic_color(action_id)

	var trail := Line2D.new()
	trail.points = PackedVector2Array([Vector2(-38, 0), Vector2.ZERO])
	trail.width = 7.0
	trail.default_color = Color(color.r, color.g, color.b, 0.42)
	trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	projectile.add_child(trail)

	var glow := Polygon2D.new()
	glow.polygon = _circle_points(18.0, 24)
	glow.color = Color(color.r, color.g, color.b, 0.34)
	projectile.add_child(glow)
	var core := Polygon2D.new()
	core.polygon = _circle_points(8.0, 20)
	core.color = Color(0.92, 0.98, 1.0, 0.96) if action_id == &"freeze" else Color(1.0, 0.86, 0.48, 0.98)
	projectile.add_child(core)
	return projectile


func _create_charge_effect(action_id: StringName) -> Node2D:
	var charge := Node2D.new()
	get_parent().add_child(charge)
	charge.global_position = _spell_origin_global()
	charge.scale = Vector2(0.18, 0.18)
	charge.modulate = Color(1, 1, 1, 0.35)
	var color := _magic_color(action_id)

	var glow := Polygon2D.new()
	glow.polygon = _circle_points(25.0, 28)
	glow.color = Color(color.r, color.g, color.b, 0.24)
	charge.add_child(glow)

	var ring := Line2D.new()
	ring.points = _circle_points(29.0, 32)
	ring.closed = true
	ring.width = 3.0
	ring.default_color = Color(color.r, color.g, color.b, 0.88)
	ring.begin_cap_mode = Line2D.LINE_CAP_ROUND
	ring.end_cap_mode = Line2D.LINE_CAP_ROUND
	charge.add_child(ring)

	var core := Polygon2D.new()
	core.polygon = _circle_points(9.0, 20)
	core.color = Color(0.92, 0.98, 1.0, 0.96) if action_id == &"freeze" else Color(1.0, 0.86, 0.48, 0.98)
	charge.add_child(core)

	for index in 4:
		var spark := Polygon2D.new()
		spark.polygon = _circle_points(3.5, 10)
		spark.color = Color(color.r, color.g, color.b, 0.92)
		spark.position = Vector2.RIGHT.rotated(TAU * float(index) / 4.0) * (34.0 + float(index % 2) * 7.0)
		charge.add_child(spark)
	return charge


func _magic_color(action_id: StringName) -> Color:
	return Color(0.34, 0.86, 1.0, 1.0) if action_id == &"freeze" else Color(1.0, 0.34, 0.08, 1.0)


func _spell_origin_global() -> Vector2:
	return global_position + Vector2(45, 70)


func _circle_points(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in segments:
		var angle := TAU * float(index) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
