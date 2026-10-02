extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _source(state: Node, status: String) -> void:
	state.jobs = {}
	state.generated_jobs = {}
	state.job_reports = [{"job_id": "destroyed", "resident_id": "ragnar", "resident": "Господин Рагнар", "object_definition_id": "lava_faucet", "object_instance_id": "old_quarter_5.bathroom.lava_faucet", "object_destroyed": true, "completed_day": 1, "reputation_change": -8 if status == "denied" else -6, "claim_status": status, "claim_amount": 350, "claim_reputation_penalty": 2 if status == "denied" else 0}]
	state.completed_job_ids = PackedStringArray(["destroyed"])
	state.pending_job_report = {}
	state.job_repair_states = {}
	state.active_job_id = &""
	state.money = 600
	state.reputation = 29 if status == "denied" else 31
	state.day = 1
	state.time_minutes = 540
	state.world_memory.reset()

func _run() -> void:
	var state: Node = root.get_node("GameState")
	_source(state, "denied")
	state._publish_due_restoration_jobs()
	assert(state.jobs.is_empty())
	state.day = 2
	state._publish_due_restoration_jobs()
	var job_id := &"destroyed_restoration"
	assert(state.is_job_available(job_id))
	assert("Без оплаты" in state.get_restoration_payment_text(job_id))
	state.world_memory.get_or_create_relation("ragnar", "liliya")["access_status"] = "banned"
	state.assign_employee(&"liliya", job_id)
	state.assign_employee(&"boris", job_id)
	state.assign_employee(&"grog", job_id)
	assert(state.jobs[job_id]["assigned"].size() == 3)
	assert(state.begin_job(job_id))
	state.advance_time(state.TRAVEL_TIME_MINUTES)
	assert(state.jobs[job_id]["assigned"].size() == 2)
	assert(not state.jobs[job_id]["assigned"].has("liliya"))
	assert(state.is_employee_returning(&"liliya"))
	var notice: String = state.take_access_messages(job_id)[0]
	assert("Хозяин не впустил сотрудника: Лилия Морозова" in notice)
	assert(not "эту магичку" in notice)
	var simulation = load("res://scripts/repair_simulation.gd").new()
	simulation.initialize_from_job(state.jobs[job_id])
	assert(not simulation.is_resolved())
	simulation.world_object["replacement_faucet_available"] = true
	assert(simulation.apply_action(&"boris", &"replace_faucet").get("applied"))
	assert(simulation.is_resolved())
	state.set_job_repair_state(job_id, simulation.get_state())
	assert(state.complete_job(job_id, simulation.get_completion_result(job_id)))
	assert(state.money == 600)
	assert(state.reputation == 37)
	assert(state.job_reports[0]["claim_status"] == "settled_by_restoration")
	assert(state.world_memory.get_relation("ragnar", "boris").get("professional_trust") == 10)
	var recorded_relation: Dictionary = state.world_memory.get_relation("ragnar", "boris")
	state._migrate_restoration_trust()
	assert(state.world_memory.get_relation("ragnar", "boris") == recorded_relation)
	state.world_memory.resident_relations["ragnar"].erase("boris")
	state.job_reports.back()["relations_recorded"] = false
	state._migrate_restoration_trust()
	assert(state.world_memory.get_relation("ragnar", "boris").get("professional_trust") == 10)
	assert(state.world_memory.get_relation("ragnar", "grog").get("professional_trust") == 10)
	state._migrate_restoration_trust()
	assert(state.world_memory.get_relation("ragnar", "boris").get("professional_trust") == 10)
	assert(state._save_to_path("res://tests/.restoration_trust_roundtrip.json") == OK)
	assert(state._load_from_path("res://tests/.restoration_trust_roundtrip.json") == OK)
	assert(state.world_memory.get_relation("ragnar", "boris").get("professional_trust") == 10)
	assert(not state.pay_denied_claim("destroyed", 1, 0))
	_source(state, "paid")
	state.day = 2
	state._publish_due_restoration_jobs()
	assert("250" in state.get_restoration_payment_text(job_id))
	state.job_repair_states[String(job_id)] = simulation.get_state()
	assert(state.complete_job(job_id, {}))
	assert(state.money == 950)
	assert(state.reputation == 37)
	_source(state, "denied")
	state.day = 2
	state._publish_due_restoration_jobs()
	assert(state.refuse_restoration_job(job_id))
	assert(state.job_reports.back()["review"] == state.RESTORATION_REFUSAL_REVIEW)
	assert(state.reputation == 27)
	assert(state.job_reports[0]["claim_status"] == "denied")
	state.day = 3
	state._publish_due_restoration_jobs()
	assert(not state.is_job_available(job_id))
	assert(not state.refuse_restoration_job(job_id))
	assert(state._save_to_path("res://tests/.restoration_roundtrip.json") == OK)
	assert(state._load_from_path("res://tests/.restoration_roundtrip.json") == OK)
	assert(not state.is_job_available(job_id))
	_source(state, "denied")
	state.day = 2
	state._publish_due_restoration_jobs()
	state.selected_job_id = job_id
	var office = load("res://scenes/ui/OfficeDashboard.tscn").instantiate()
	root.add_child(office)
	await process_frame
	assert(office.restoration_refuse_button.visible)
	assert("Состояние: требуется полная замена" in office.detail_body.text)
	assert(not "Опасность:" in office.detail_body.text)
	office._show_expanded_job_details()
	assert("Состояние: требуется полная замена" in office.detail_expanded_body.text)
	assert("Опасность:" in office._job_condition_text({"danger": "Магический холод"}))
	assert(office.books_layer._review_text({"restoration_refused": true}) == state.RESTORATION_REFUSAL_REVIEW)
	state.world_memory.evaluate_crew_relations({"resident_id": "ragnar", "rating": 5, "crew_ids": ["boris"]})
	assert(office._relation_description(state.world_memory.get_relation("ragnar", "boris")) == "доверяет")
	state.world_memory.evaluate_crew_relations({"resident_id": "ragnar", "rating": 5, "crew_ids": ["boris"]})
	assert(office._relation_description(state.world_memory.get_relation("ragnar", "boris")) == "предпочитает")
	office.selected_employee_id = &"boris"
	office._open_resident_memory()
	assert("Господин Рагнар" in office.resident_memory_body.text)
	assert("предпочитает" in office.resident_memory_body.text)
	assert(office.resident_memory_dialog.is_visible_in_tree())
	office.resident_memory_dialog.visible = false
	state.world_memory.evaluate_crew_relations({"resident_id": "ragnar", "rating": 1, "claim_amount": 350, "object_destroyed": true, "damage_employee_ids": ["liliya"], "crew_ids": ["liliya"]})
	office._show_expanded_job_details()
	assert("Господин Рагнар" in office.detail_resident_button.text)
	office.detail_resident_button.pressed.emit()
	assert(office.resident_memory_dialog.is_visible_in_tree())
	assert("Борис Медяк" in office.resident_memory_body.text)
	assert("Лилия Морозова" in office.resident_memory_body.text)
	assert("Вход запрещён" in office.resident_memory_body.text)
	assert("предпочитает" in office.resident_memory_body.text)
	var relation_button: Button
	for child in office.personnel_layer.get_children():
		if child is Button and child.text == "ОТНОШЕНИЯ С КЛИЕНТАМИ":
			relation_button = child
	assert(relation_button != null)
	assert(relation_button.position.y > 100)
	assert(office.personnel_description.position.y + office.personnel_description.size.y < relation_button.position.y)
	assert(office.restoration_payment_label.get_minimum_size().y <= 86)
	assert(office.restoration_payment_label.position.y + office.restoration_payment_label.size.y <= office.assignment_label.position.y)
	office.queue_free()
	await process_frame
	simulation = null
	print("RESTORATION JOB SMOKE TEST: PASS")
	quit()
