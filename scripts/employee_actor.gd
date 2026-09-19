extends Control

signal action_impact(action_id: StringName)
signal action_finished

@onready var neutral_pose: TextureRect = $NeutralPose
@onready var work_pose: TextureRect = $WorkPose
@onready var walk_pose: TextureRect = $WalkPose
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
var employee_positions: Dictionary = {}
var walking_z_index: int


func _ready() -> void:
	home_position = position
	walking_z_index = z_index
	pivot_offset = Vector2(size.x * 0.5, size.y)
	walk_pose_base_position = walk_pose.position
	walk_pose.pivot_offset = walk_pose.size * 0.5
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
	var hold_path := str(employee_data.get("actor_hold_pose", ""))
	walk_pose.texture = load(walk_path) as Texture2D if not walk_path.is_empty() else null
	hold_pose.texture = load(hold_path) as Texture2D if not hold_path.is_empty() else null
	# Обе цельные позы используют одну область, масштаб и точку опоры.
	work_pose.offset_left = neutral_pose.offset_left
	work_pose.offset_top = neutral_pose.offset_top
	work_pose.offset_right = neutral_pose.offset_right
	work_pose.offset_bottom = neutral_pose.offset_bottom
	_copy_pose_layout(neutral_pose, walk_pose)
	_copy_pose_layout(neutral_pose, hold_pose)
	walk_pose_base_position = walk_pose.position
	_reset_pose_visibility()
	if idle_tween != null:
		idle_tween.play()
	return neutral_pose.texture != null and work_pose.texture != null


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
	idle_tween.tween_property(self, "scale", Vector2(1.004, 0.997), 1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	idle_tween.parallel().tween_property(self, "rotation", 0.0035, 1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	idle_tween.tween_property(self, "scale", Vector2(0.998, 1.003), 1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
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
	scale = Vector2.ONE
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
		await _show_action_pose(selected_pose)
		await get_tree().create_timer(0.38).timeout
		action_impact.emit(action_id)
		await get_tree().create_timer(0.16).timeout
		if stay_near_target:
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
	for item: TextureRect in [neutral_pose, work_pose, walk_pose, hold_pose]:
		if item != pose:
			item.visible = false
	pose.visible = true
	pose.modulate = Color(1, 1, 1, 0)
	var pose_tween: Tween = create_tween()
	pose_tween.tween_property(pose, "modulate", Color.WHITE, 0.18)
	await pose_tween.finished


func _walk_to(target_position: Vector2) -> void:
	var distance: float = position.distance_to(target_position)
	if distance < 2.0:
		return
	neutral_pose.visible = false
	work_pose.visible = false
	hold_pose.visible = false
	walk_pose.visible = true
	walk_pose.modulate = Color.WHITE
	walk_pose.pivot_offset = walk_pose.size * 0.5
	walk_pose.scale = Vector2(-1.0, 1.0) if target_position.x > position.x else Vector2.ONE
	var duration: float = clampf(distance / 260.0, 0.45, 1.45)
	var movement: Tween = create_tween()
	movement.tween_property(self, "position", target_position, duration).set_trans(Tween.TRANS_LINEAR)
	var steps: Tween = create_tween().set_loops()
	steps.tween_property(walk_pose, "position:y", walk_pose_base_position.y - 7.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	steps.parallel().tween_property(walk_pose, "rotation", 0.009, 0.16).set_trans(Tween.TRANS_SINE)
	steps.tween_property(walk_pose, "position:y", walk_pose_base_position.y, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	steps.parallel().tween_property(walk_pose, "rotation", -0.007, 0.16).set_trans(Tween.TRANS_SINE)
	await movement.finished
	steps.kill()
	walk_pose.position = walk_pose_base_position
	walk_pose.rotation = 0.0
	walk_pose.scale = Vector2.ONE


func restore_hold_pose(target_position: Vector2, action_z_index: int = 20) -> void:
	if action_style != &"physical" or hold_pose.texture == null:
		return
	if idle_tween != null:
		idle_tween.pause()
	position = target_position
	employee_positions[employee_id] = position
	rotation = 0.0
	scale = Vector2.ONE
	z_index = action_z_index
	_reset_pose_visibility()
	neutral_pose.visible = false
	hold_pose.visible = true
	hold_pose.modulate = Color.WHITE
	action_in_progress = false


func _play_magic_impact(action_id: StringName, target_global_position: Vector2) -> void:
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
