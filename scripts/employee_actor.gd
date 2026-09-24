extends Control

signal action_impact(action_id: StringName)
signal action_finished

@onready var neutral_pose: TextureRect = $NeutralPose
@onready var work_pose: TextureRect = $WorkPose
@onready var walk_pose: TextureRect = $WalkPose
@onready var walk_pose_alt: TextureRect = $WalkPoseAlt
@onready var hold_pose: TextureRect = $HoldPose
@onready var action_origin_marker: Marker2D = get_node_or_null("ActionOrigin") as Marker2D

var idle_tween: Tween
var action_in_progress: bool = false
var employee_id: StringName = &""
var action_style: StringName = &"magic"
var action_origin: Vector2 = Vector2(45, 70)
var action_origin_from_data: bool = false
var home_position: Vector2
var walk_pose_base_position: Vector2
var walk_pose_alt_base_position: Vector2
var walk_pose_faces_right: bool = false
var persistent_work_pose: bool = false
var employee_positions: Dictionary = {}
var walking_z_index: int
var horizontal_flip: bool = false


func _ready() -> void:
	home_position = position
	walking_z_index = z_index
	pivot_offset = Vector2(size.x * 0.5, size.y)
	walk_pose_base_position = walk_pose.position
	walk_pose_alt_base_position = walk_pose_alt.position
	walk_pose.pivot_offset = walk_pose.size * 0.5
	walk_pose_alt.pivot_offset = walk_pose_alt.size * 0.5
	_reset_pose_visibility()
	if not Engine.is_editor_hint():
		_start_idle_motion()


func configure_employee(new_employee_id: StringName, employee_data: Dictionary) -> bool:
	var neutral_path := str(employee_data.get("actor_neutral_pose", ""))
	var work_path := str(employee_data.get("actor_work_pose", ""))
	if neutral_path.is_empty() or work_path.is_empty():
		employee_id = &""
		return false
	if not employee_id.is_empty():
		employee_positions[employee_id] = position
	employee_id = new_employee_id
	action_style = StringName(str(employee_data.get("actor_action_style", "magic")))
	position = employee_positions.get(employee_id, home_position) as Vector2
	z_index = walking_z_index
	var configured_action_origin: Variant = employee_data.get("actor_action_origin", Vector2(45, 70))
	if configured_action_origin is Vector2:
		action_origin = configured_action_origin
	action_origin_from_data = bool(employee_data.get("actor_action_origin_from_data", false))
	neutral_pose.texture = load(neutral_path)
	work_pose.texture = load(work_path)
	var walk_path := str(employee_data.get("actor_walk_pose", ""))
	var walk_alt_path := str(employee_data.get("actor_walk_pose_alt", ""))
	walk_pose_faces_right = bool(employee_data.get("actor_walk_pose_faces_right", false))
	var hold_path := str(employee_data.get("actor_hold_pose", ""))
	walk_pose.texture = load(walk_path) as Texture2D if not walk_path.is_empty() else null
	walk_pose_alt.texture = load(walk_alt_path) as Texture2D if not walk_alt_path.is_empty() else null
	hold_pose.texture = load(hold_path) as Texture2D if not hold_path.is_empty() else null
	# Обе цельные позы используют одну область, масштаб и точку опоры.
	work_pose.offset_left = neutral_pose.offset_left
	work_pose.offset_top = neutral_pose.offset_top
	work_pose.offset_right = neutral_pose.offset_right
	work_pose.offset_bottom = neutral_pose.offset_bottom
	_copy_pose_layout(neutral_pose, walk_pose)
	_copy_pose_layout(neutral_pose, walk_pose_alt)
	_copy_pose_layout(neutral_pose, hold_pose)
	walk_pose_base_position = walk_pose.position
	walk_pose_alt_base_position = walk_pose_alt.position
	_reset_pose_visibility()
	if idle_tween != null:
		idle_tween.play()
	return neutral_pose.texture != null and work_pose.texture != null


func set_horizontal_flip(should_flip: bool) -> void:
	horizontal_flip = should_flip
	rotation = 0.0
	scale = Vector2(-1.0 if horizontal_flip else 1.0, 1.0)
	if idle_tween != null:
		idle_tween.kill()
		_start_idle_motion()


func _reset_pose_visibility() -> void:
	neutral_pose.visible = true
	neutral_pose.modulate = Color.WHITE
	work_pose.visible = false
	work_pose.modulate = Color(1, 1, 1, 0)
	walk_pose.visible = false
	walk_pose.modulate = Color.WHITE
	walk_pose.position = walk_pose_base_position
	walk_pose.rotation = 0.0
	walk_pose.scale = Vector2.ONE
	walk_pose_alt.visible = false
	walk_pose_alt.modulate = Color.WHITE
	walk_pose_alt.position = walk_pose_alt_base_position
	walk_pose_alt.rotation = 0.0
	walk_pose_alt.scale = Vector2.ONE
	hold_pose.visible = false
	hold_pose.modulate = Color(1, 1, 1, 0)


func _copy_pose_layout(source: TextureRect, target: TextureRect) -> void:
	target.offset_left = source.offset_left
	target.offset_top = source.offset_top
	target.offset_right = source.offset_right
	target.offset_bottom = source.offset_bottom


func _start_idle_motion() -> void:
	if idle_tween != null:
		idle_tween.kill()
	idle_tween = create_tween().set_loops()
	var direction: float = -1.0 if horizontal_flip else 1.0
	idle_tween.tween_property(self, "scale", Vector2(direction * 1.004, 0.997), 1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	idle_tween.parallel().tween_property(self, "rotation", 0.0035, 1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	idle_tween.tween_property(self, "scale", Vector2(direction * 0.998, 1.003), 1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	idle_tween.parallel().tween_property(self, "rotation", -0.0025, 1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func play_action(
	action_id: StringName,
	target_global_position: Vector2,
	physical_approach_position: Vector2 = Vector2.INF,
	physical_pose: StringName = &"work",
	stay_near_target: bool = false,
	physical_action_z_index: int = 20
) -> void:
	if action_in_progress:
		return
	action_in_progress = true
	z_index = walking_z_index
	if idle_tween != null:
		idle_tween.pause()
	rotation = 0.0
	scale = Vector2(-1.0 if horizontal_flip else 1.0, 1.0)
	if action_style == &"magic":
		await _show_action_pose(work_pose)
		await _play_magic_impact(action_id, target_global_position)
	else:
		if physical_approach_position.is_finite() and walk_pose.texture != null:
			await _walk_to(physical_approach_position)
		z_index = physical_action_z_index
		var selected_pose: TextureRect = work_pose
		if physical_pose == &"hold" and hold_pose.texture != null:
			selected_pose = hold_pose
		elif physical_pose == &"neutral":
			selected_pose = neutral_pose
		if employee_id == &"boris" and action_id == &"repair":
			_play_audio_cue(&"play_boris_repair")
		await _show_action_pose(selected_pose)
		await get_tree().create_timer(0.38).timeout
		action_impact.emit(action_id)
		await get_tree().create_timer(0.16).timeout
		if stay_near_target:
			action_in_progress = false
			action_finished.emit()
			return

	if persistent_work_pose:
		_show_work_pose_now()
		action_in_progress = false
		action_finished.emit()
		return
	_reset_pose_visibility()
	if action_style == &"physical":
		employee_positions[employee_id] = position
	action_in_progress = false
	if idle_tween != null:
		idle_tween.play()
	action_finished.emit()


func _show_action_pose(pose: TextureRect) -> void:
	for item: TextureRect in [neutral_pose, work_pose, walk_pose, walk_pose_alt, hold_pose]:
		if item != pose:
			item.visible = false
	pose.visible = true
	pose.modulate = Color(1, 1, 1, 0)
	var pose_tween: Tween = create_tween()
	pose_tween.tween_property(pose, "modulate", Color.WHITE, 0.18)
	await pose_tween.finished


func set_persistent_work_pose(enabled: bool) -> void:
	persistent_work_pose = enabled
	if enabled:
		_show_work_pose_now()
	elif not action_in_progress:
		_reset_pose_visibility()
		if idle_tween != null:
			idle_tween.play()


func _show_work_pose_now() -> void:
	if idle_tween != null:
		idle_tween.pause()
	for item: TextureRect in [neutral_pose, walk_pose, walk_pose_alt, hold_pose]:
		item.visible = false
	work_pose.visible = true
	work_pose.modulate = Color.WHITE


func _walk_to(target_position: Vector2) -> void:
	var distance: float = position.distance_to(target_position)
	if distance < 2.0:
		return
	neutral_pose.visible = false
	work_pose.visible = false
	hold_pose.visible = false
	walk_pose.visible = true
	walk_pose_alt.visible = false
	walk_pose.modulate = Color.WHITE
	walk_pose_alt.modulate = Color(1, 1, 1, 0)
	walk_pose.pivot_offset = walk_pose.size * 0.5
	walk_pose_alt.pivot_offset = walk_pose_alt.size * 0.5
	walk_pose.scale = Vector2(_walk_scale_x(target_position.x), 1.0)
	walk_pose_alt.scale = walk_pose.scale
	var duration: float = clampf(distance / 260.0, 0.45, 1.45)
	var movement: Tween = create_tween()
	movement.tween_property(self, "position", target_position, duration).set_trans(Tween.TRANS_LINEAR)
	var frame_cycle: Tween = null
	var has_alternate_walk_pose := walk_pose_alt.texture != null
	if has_alternate_walk_pose:
		# Пауза между шагами делает походку спокойнее, а короткое перекрытие
		# сглаживает разницу между двумя нарисованными силуэтами.
		walk_pose_alt.visible = true
		frame_cycle = create_tween().set_loops()
		frame_cycle.tween_interval(0.30)
		frame_cycle.tween_property(walk_pose, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		frame_cycle.parallel().tween_property(walk_pose_alt, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		frame_cycle.tween_interval(0.30)
		frame_cycle.tween_property(walk_pose_alt, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		frame_cycle.parallel().tween_property(walk_pose, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var step_lift := 4.0 if has_alternate_walk_pose else 7.0
	var step_duration := 0.24 if has_alternate_walk_pose else 0.16
	var step_rotation_forward := 0.006 if has_alternate_walk_pose else 0.009
	var step_rotation_back := -0.004 if has_alternate_walk_pose else -0.007
	var steps: Tween = create_tween().set_loops()
	steps.tween_property(walk_pose, "position:y", walk_pose_base_position.y - step_lift, step_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	steps.parallel().tween_property(walk_pose, "rotation", step_rotation_forward, step_duration).set_trans(Tween.TRANS_SINE)
	steps.parallel().tween_property(walk_pose_alt, "position:y", walk_pose_alt_base_position.y - step_lift, step_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	steps.parallel().tween_property(walk_pose_alt, "rotation", step_rotation_forward, step_duration).set_trans(Tween.TRANS_SINE)
	steps.tween_property(walk_pose, "position:y", walk_pose_base_position.y, step_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	steps.parallel().tween_property(walk_pose, "rotation", step_rotation_back, step_duration).set_trans(Tween.TRANS_SINE)
	steps.parallel().tween_property(walk_pose_alt, "position:y", walk_pose_alt_base_position.y, step_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	steps.parallel().tween_property(walk_pose_alt, "rotation", step_rotation_back, step_duration).set_trans(Tween.TRANS_SINE)
	await movement.finished
	if frame_cycle != null:
		frame_cycle.kill()
	steps.kill()
	walk_pose_alt.visible = false
	walk_pose.modulate = Color.WHITE
	walk_pose_alt.modulate = Color.WHITE
	walk_pose.position = walk_pose_base_position
	walk_pose.rotation = 0.0
	walk_pose.scale = Vector2.ONE
	walk_pose_alt.position = walk_pose_alt_base_position
	walk_pose_alt.rotation = 0.0
	walk_pose_alt.scale = Vector2.ONE


func _set_walk_frame(show_alternate: bool) -> void:
	walk_pose.visible = not show_alternate
	walk_pose_alt.visible = show_alternate and walk_pose_alt.texture != null


func _walk_scale_x(target_x: float) -> float:
	var desired_direction := -1.0 if target_x > position.x else 1.0
	var source_direction := -1.0 if walk_pose_faces_right else 1.0
	var parent_direction := -1.0 if horizontal_flip else 1.0
	return desired_direction * source_direction / parent_direction


func restore_hold_pose(target_position: Vector2, action_z_index: int = 20) -> void:
	if action_style != &"physical" or hold_pose.texture == null:
		return
	if idle_tween != null:
		idle_tween.pause()
	position = target_position
	employee_positions[employee_id] = position
	rotation = 0.0
	scale = Vector2(-1.0 if horizontal_flip else 1.0, 1.0)
	z_index = action_z_index
	_reset_pose_visibility()
	neutral_pose.visible = false
	hold_pose.visible = true
	hold_pose.modulate = Color.WHITE
	action_in_progress = false


func _play_magic_impact(action_id: StringName, target_global_position: Vector2) -> void:
	_play_audio_cue(&"play_spell")
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


func _play_audio_cue(method: StringName) -> void:
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager != null and audio_manager.has_method(method):
		audio_manager.call(method)


func _create_projectile(action_id: StringName, target_global_position: Vector2) -> Node2D:
	var projectile := Node2D.new()
	projectile.z_index = 100
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
	core.color = _magic_core_color(action_id)
	projectile.add_child(core)
	return projectile


func _create_charge_effect(action_id: StringName) -> Node2D:
	var charge := Node2D.new()
	charge.z_index = 100
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
	core.color = _magic_core_color(action_id)
	charge.add_child(core)

	for index in 4:
		var spark := Polygon2D.new()
		spark.polygon = _circle_points(3.5, 10)
		spark.color = Color(color.r, color.g, color.b, 0.92)
		spark.position = Vector2.RIGHT.rotated(TAU * float(index) / 4.0) * (34.0 + float(index % 2) * 7.0)
		charge.add_child(spark)
	return charge


func _magic_color(action_id: StringName) -> Color:
	match action_id:
		&"freeze":
			return Color(0.34, 0.86, 1.0, 1.0)
		&"antimagic":
			return Color(0.68, 0.48, 1.0, 1.0)
		_:
			return Color(1.0, 0.34, 0.08, 1.0)


func _magic_core_color(action_id: StringName) -> Color:
	return Color(0.94, 0.90, 1.0, 0.98) if action_id == &"antimagic" else (Color(0.92, 0.98, 1.0, 0.96) if action_id == &"freeze" else Color(1.0, 0.86, 0.48, 0.98))


func _spell_origin_global() -> Vector2:
	if action_origin_marker != null and not action_origin_from_data:
		return action_origin_marker.global_position
	return get_global_transform() * action_origin


func _circle_points(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in segments:
		var angle := TAU * float(index) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
