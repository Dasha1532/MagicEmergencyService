extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var gs = preload("res://tests/prison_test_state.gd").install(root)
	gs.start_new_game()
	for step: int in 10:
		if gs.is_job_available(&"prison_lock"):
			break
		var before: int = gs.day
		var current := PackedStringArray()
		for id: StringName in gs.jobs:
			if gs.is_job_available(id):
				current.append(str(id))
		assert(gs.debug_skip_day())
		assert(gs.day == before + 1)
		for id: String in current:
			assert(gs.completed_job_ids.has(id))
		assert(gs.pending_job_report.is_empty())
	assert(gs.is_job_available(&"prison_lock"))
	assert(not gs.completed_job_ids.has("prison_lock"))
	assert(not gs.is_demo_complete())
	print("Prison available on day ", gs.day)
	assert(gs.debug_skip_day())
	assert(gs.is_job_available(&"prison_lock"))
	# Existing follow-ups delay prison and are completed by the same test button.
	gs.world_memory.queue_consequence(&"test_ghost", &"escaped_ghost", "portal_mirror_room.portal_mirror", &"portal_mirror", gs.day + 1, 0, 50, {"lunnopuh_state": "absent"}, "test_chain", "test_event", 1)
	gs.advance_day()
	gs.jobs[&"escaped_ghost"]["unlocked"] = true
	assert(not gs.is_job_available(&"prison_lock"))
	assert(gs.debug_skip_day())
	assert(gs.completed_job_ids.has("escaped_ghost"))
	assert(gs.is_job_available(&"prison_lock"))
	# Enter with the regular assignment and dispatch API.
	gs.assign_employee(&"boris", &"prison_lock")
	gs.assign_employee(&"grog", &"prison_lock")
	assert(gs.begin_job(&"prison_lock"))
	gs.time_minutes += gs.TRAVEL_TIME_MINUTES
	assert(gs.has_employee_on_site(&"prison_lock"))
	assert(gs.get_active_job_repair_scene() == "res://scenes/PrisonRoom.tscn")
	var room = load(gs.get_active_job_repair_scene()).instantiate()
	root.add_child(room)
	await process_frame
	assert(room.employee_actor.visible)
	assert(room.dialogue_panel.size == Vector2(1560, 150))
	assert(room.dialogue_portrait_frame.position.y == -98)
	assert(room.lines.size() > 1)
	while room.dialogue_open:
		room._next_line()
	assert(not room.dialogue_open)
	assert(room.get_node_or_null("Interface") == null)
	assert(room.get_node_or_null("DebugPrisonButton") == null)
	room.queue_free()
	await process_frame
	print("PRISON CAMPAIGN: PASS")
	quit()
