extends SceneTree
func _initialize() -> void:
	call_deferred("_capture")
func _capture() -> void:
	var gs = preload("res://tests/prison_test_state.gd").install(root)
	gs.prepare_prison(PackedStringArray(["boris", "grog", "felix"]))
	var room = load("res://scenes/PrisonRoom.tscn").instantiate()
	root.add_child(room)
	await process_frame
	while room.dialogue_open:
		room._next_line()
	room.show_room("cells")
	await process_frame
	var original_position: Vector2 = room.employee_actor.position
	room._request_action("inspect")
	await room.employee_actor.action_finished
	await process_frame
	assert(not gs.get_pending_job_action(&"prison_lock").is_empty())
	assert(room.employee_actor.position != original_position)
	assert(absf(room.employee_actor.position.y - original_position.y) < 0.01)
	assert(room.employee_actor.persistent_action_pose == &"work")
	room.queue_free()
	await process_frame
	room = load("res://scenes/PrisonRoom.tscn").instantiate()
	root.add_child(room)
	await process_frame
	assert(room.current_room == "cells")
	assert(room.action_in_progress)
	assert(room.employee_actor.persistent_action_pose == &"work")
	gs.advance_time(30)
	await process_frame
	await process_frame
	assert(room.simulation.state["lock_inspected"])
	assert(room.dialogue_open)
	room._next_line()
	room._request_action("repair_mechanism")
	await room.employee_actor.action_finished
	await process_frame
	gs.advance_time(30)
	await process_frame
	await process_frame
	assert(room.simulation.state["mechanism_repaired"])
	while room.dialogue_open:
		room._next_line()
	assert(room.simulation.state["guard_away"])
	room.perform_action("test_protection")
	await process_frame
	room.queue_free()
	await process_frame
	print("PRISON ACTOR: PASS")
	quit()
