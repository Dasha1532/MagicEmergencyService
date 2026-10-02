extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _damage(id: String) -> Dictionary:
	return {"job_id": id, "resident_id": "ragnar", "resident": "Господин Рагнар", "completed_day": 1, "completed_time": 600, "rating": 1, "object_destroyed": true, "claim_amount": 350, "claim_status": "denied", "damage_employee_ids": ["liliya"], "crew_ids": ["liliya"]}

func _good(id: String, resident: String, crew: Array) -> Dictionary:
	return {"job_id": id, "resident_id": resident, "rating": 5, "crew_ids": crew, "claim_amount": 0, "overdue": false}

func _run() -> void:
	var state = root.get_node("GameState")
	state.start_new_game()
	state.world_memory.reset()
	state.job_reports.clear()
	var damage := _damage("first_damage")
	state.job_reports.append(damage)
	state.world_memory.evaluate_crew_relations(damage)
	assert(state.get_apology_availability("ragnar", &"liliya") == &"unsettled_damage")
	assert(not state.apologize_to_resident("ragnar", &"liliya"))
	assert(state.pay_denied_claim("first_damage", 1, 600))
	assert(state.get_apology_availability("ragnar", &"liliya") == &"available")
	var office = load("res://scenes/ui/OfficeDashboard.tscn").instantiate()
	root.add_child(office)
	await process_frame
	office.selected_employee_id = &"liliya"
	office._open_resident_memory()
	assert("Извиниться" in office.resident_memory_body.text)
	assert(office.apology_targets.size() == 1)
	await process_frame
	await process_frame
	assert(office.resident_memory_panel.size.x == 580)
	assert(not office.resident_memory_body.scroll_active)
	assert(office.resident_memory_body.get_content_height() <= office.resident_memory_body.size.y)
	assert(office.resident_memory_body.position.y + office.resident_memory_body.size.y < office.resident_memory_close.position.y)
	var cursors = root.get_node("CursorManager")
	office.resident_memory_body.meta_hover_started.emit("0")
	assert(cursors.plain_link_owner == office.resident_memory_body)
	office.resident_memory_body.meta_clicked.emit("0")
	assert(cursors.plain_link_owner == null)
	await process_frame
	await process_frame
	assert(office.apology_reply_panel.size.x == 580)
	assert(office.apology_reply_panel.size.y < 380)
	assert(office.apology_reply_body.get_minimum_size().y <= office.apology_reply_body.size.y)
	assert(office.apology_reply_body.position.y + office.apology_reply_body.size.y < office.apology_reply_close.position.y)
	assert(office.apology_reply_close.size.x == 200)
	var long_text := PackedStringArray()
	for index in 30:
		long_text.append("Жилец %d: отношение к сотруднику." % index)
	office._show_resident_memory(long_text)
	await process_frame
	await process_frame
	assert(office.resident_memory_body.scroll_active)
	assert(office.resident_memory_panel.size.y <= 574)
	office._open_resident_memory()
	await process_frame
	await process_frame
	assert(not office.resident_memory_body.scroll_active)
	assert(office.apology_reply_dialog.visible)
	assert("вашей магичке" in office.apology_reply_body.text)
	assert(state.world_memory.get_relation("ragnar", "liliya")["access_status"] == "warned")
	assert(state.world_memory.get_relation("ragnar", "liliya")["professional_trust"] == -30)
	assert(not state.apologize_to_resident("ragnar", &"liliya"))
	assert(state._save_to_path("res://tests/.apology_roundtrip.json") == OK)
	assert(state._load_from_path("res://tests/.apology_roundtrip.json") == OK)
	assert(state.world_memory.get_relation("ragnar", "liliya")["apology_probation"])
	var good := _good("probation_success", "ragnar", ["liliya", "boris"])
	state.job_reports.append(good)
	state.world_memory.evaluate_crew_relations(good)
	assert(state.world_memory.get_relation("ragnar", "liliya")["access_status"] == "allowed")
	damage = _damage("second_damage")
	damage["object_destroyed"] = false
	state.job_reports.append(damage)
	state.world_memory.evaluate_crew_relations(damage)
	assert(state.world_memory.get_relation("ragnar", "liliya")["access_status"] == "banned")
	# Good work before compensation must not count.
	state.job_reports.append(_good("too_early", "ragnar", ["boris"]))
	assert(state.pay_denied_claim("second_damage", 1, 600))
	assert(state.get_apology_availability("ragnar", &"liliya") == &"needs_other_crew_work")
	state.job_reports.append(_good("other_resident", "eleonora", ["boris"]))
	state.job_reports.append(_good("wrong_crew", "ragnar", ["liliya", "boris"]))
	var late := _good("late_work", "ragnar", ["boris"])
	late["overdue"] = true
	state.job_reports.append(late)
	assert(state.get_apology_availability("ragnar", &"liliya") == &"needs_other_crew_work")
	state.job_reports.append(_good("right_crew", "ragnar", ["boris", "grog"]))
	assert(state.get_apology_availability("ragnar", &"liliya") == &"available")
	assert(state.apologize_to_resident("ragnar", &"liliya"))
	assert(state.world_memory.get_relation("ragnar", "liliya")["apology_count"] == 2)
	assert(state._save_to_path("res://tests/.apology_roundtrip.json") == OK)
	assert(state._load_from_path("res://tests/.apology_roundtrip.json") == OK)
	assert(state.world_memory.get_relation("ragnar", "liliya")["access_status"] == "warned")
	# Restoration settles damage, but does not remove a ban without apology.
	state.world_memory.reset()
	damage = _damage("restored_damage")
	damage["property_restored"] = true
	damage["claim_status"] = "settled_by_restoration"
	state.job_reports = [damage]
	state.world_memory.evaluate_crew_relations(damage)
	assert(state.get_apology_availability("ragnar", &"liliya") == &"available")
	assert("Кран заменили" in state.get_apology_reply("ragnar", &"liliya"))
	assert(state.world_memory.get_relation("ragnar", "liliya")["access_status"] == "banned")
	# The restoration closing a repeated claim is not the later trust-building job.
	state.world_memory.get_or_create_relation("ragnar", "liliya")["apology_count"] = 1
	state.job_reports[0]["claim_settled_report_count"] = 2
	var restoration := _good("recovery", "ragnar", ["boris"])
	restoration["restoration"] = true
	restoration["payment_forfeited"] = true
	state.job_reports.append(restoration)
	assert(state.get_apology_availability("ragnar", &"liliya") == &"needs_other_crew_work")
	state.job_reports.append(_good("later_safe_work", "ragnar", ["boris"]))
	assert(state.get_apology_availability("ragnar", &"liliya") == &"available")
	assert(state.apologize_to_resident("ragnar", &"liliya"))
	restoration["crew_ids"] = ["liliya"]
	state.world_memory.evaluate_crew_relations(restoration)
	assert(state.world_memory.get_relation("ragnar", "liliya")["access_status"] == "allowed")
	office.queue_free()
	await process_frame
	print("RESIDENT APOLOGY SMOKE TEST: PASS")
	quit()
