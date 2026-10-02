extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state = root.get_node("GameState")
	state.start_new_game()
	state.skip_tutorial()
	var job_id: StringName = state.get_tutorial_job_id()
	state.assign_employee(&"boris", job_id)
	assert(state.begin_job(job_id))
	state.advance_time(state.TRAVEL_TIME_MINUTES)
	assert(state.get_resident_greeting(job_id) == "Здравствуйте. Вот такая у меня неприятность.")
	var relation: Dictionary = state.world_memory.get_or_create_relation("ragnar", "boris")
	relation["professional_trust"] = 10
	var pools: Dictionary = state.CLIENT_GREETING_PROFILE.POOLS
	var previous := ""
	var seen := {}
	for index in 30:
		var phrase: String = state.get_resident_greeting(job_id)
		assert(phrase != previous)
		assert(pools.trusted.phrases.has(phrase.replace("Борис", "{Имя}")))
		assert(not "прошлый" in phrase)
		seen[phrase] = true
		previous = phrase
	assert(seen.size() > 1)
	assert(state._save_to_path("res://tests/.relationship_greeting_roundtrip.json") == OK)
	assert(state._load_from_path("res://tests/.relationship_greeting_roundtrip.json") == OK)
	assert(state.get_resident_greeting(job_id) != previous)
	state.assign_employee(&"liliya", job_id)
	state.advance_time(state.TRAVEL_TIME_MINUTES)
	var cautious: Dictionary = state.world_memory.get_or_create_relation("ragnar", "liliya")
	cautious["access_status"] = "warned"
	cautious["apology_probation"] = true
	var greeting: String = state.get_resident_greeting(job_id)
	assert(pools.cautious.phrases.has(greeting.replace("Лилия", "{Имя}")))
	# Banned and still travelling employees cannot receive a warm greeting.
	cautious["access_status"] = "banned"
	assert(state.get_resident_greeting(job_id).begins_with("Борис,"))
	state.employees[&"boris"]["arrival_until"] = state.time_minutes + 15
	assert(state.get_resident_greeting(job_id, "Обычная просьба") == "Обычная просьба")
	state.employees[&"boris"]["arrival_until"] = 0
	state.world_memory.get_or_create_relation("ragnar", "boris")["professional_trust"] = 30
	state.jobs[job_id]["generated_instance"]["preferred_employee_id"] = "boris"
	assert(pools.trusted.phrases.has(state.get_resident_greeting(job_id).replace("Борис", "{Имя}")))
	# Another client's memories must not leak into this greeting.
	state.jobs[job_id]["generated_instance"]["resident_id"] = "another_client"
	assert(state.get_resident_greeting(job_id, "Обычная просьба") == "Обычная просьба")
	state.jobs[job_id]["generated_instance"]["resident_id"] = "ragnar"
	state.world_memory.get_or_create_relation("ragnar", "boris").erase("last_greeting_template")
	var room = load("res://scenes/RepairHouse.tscn").instantiate()
	root.add_child(room)
	await create_timer(0.5).timeout
	assert(pools.trusted.phrases.has(room.repair_hud.employee_reaction_label.text.replace("Борис", "{Имя}")))
	assert(room.repair_hud.queued_dialogues.is_empty())
	room.queue_free()
	await process_frame
	room = load("res://scenes/RepairHouse.tscn").instantiate()
	root.add_child(room)
	await create_timer(0.5).timeout
	assert(room.repair_hud.employee_reaction_label.text.is_empty())
	room.queue_free()
	await process_frame
	print("RELATIONSHIP GREETING SMOKE TEST: PASS")
	quit()
