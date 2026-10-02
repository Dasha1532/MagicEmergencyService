extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _good(state: Node, employee: String, count: int) -> void:
	for index in count:
		state.world_memory.evaluate_crew_relations({"resident_id": "ragnar", "rating": 5, "crew_ids": [employee], "job_id": "%s_%d" % [employee, index]})

func _run() -> void:
	var state = root.get_node("GameState")
	state.start_new_game()
	state.skip_tutorial()
	state.world_memory.reset()
	var original_id: StringName = state.get_tutorial_job_id()
	_good(state, "boris", 1)
	assert(state._preferred_employee_for_resident("ragnar").is_empty())
	_good(state, "boris", 1)
	assert(state._preferred_employee_for_resident("ragnar") == &"boris")
	assert(state.get_preferred_employee_for_job(original_id).is_empty())
	var instance: Dictionary = state.jobs[original_id]["generated_instance"].duplicate(true)
	instance["instance_id"] = "preference_test"
	instance.erase("preferred_employee_id")
	state._register_generated_job(instance)
	state._set_job_unlocked(&"preference_test", true)
	assert(state.get_preferred_employee_request(&"preference_test") == "Господин Рагнар просит прислать Бориса")
	state.employees[&"boris"]["return_until"] = state.time_minutes + 30
	assert(state.get_preferred_employee_for_job(&"preference_test") == &"boris")
	_good(state, "grog", 3)
	assert(state.get_preferred_employee_for_job(&"preference_test") == &"boris")
	assert(state._save_to_path("res://tests/.client_preference_roundtrip.json") == OK)
	assert(state._load_from_path("res://tests/.client_preference_roundtrip.json") == OK)
	assert(state.get_preferred_employee_for_job(&"preference_test") == &"boris")
	state.selected_job_id = &"preference_test"
	var office = load("res://scenes/ui/OfficeDashboard.tscn").instantiate()
	root.add_child(office)
	await process_frame
	assert(office.preference_request_label.visible)
	assert("Господин Рагнар просит прислать Бориса" in office.preference_request_label.text)
	assert(office.preference_request_label.position.y + office.preference_request_label.size.y <= office.assignment_label.position.y)
	office._show_expanded_job_details()
	assert(office.detail_resident_button.text == "Клиент: Господин Рагнар")
	assert("просит прислать Бориса" in office.detail_expanded_body.text)
	var badge_found := false
	for card in office.employee_list.get_children():
		for child in card.get_children():
			if child is Label and child.text == "Предпочтение клиента":
				badge_found = true
	assert(badge_found)
	var money_before: int = state.money
	var reputation_before: int = state.reputation
	state.assign_employee(&"liliya", &"preference_test")
	assert(state.jobs[&"preference_test"]["assigned"].has("liliya"))
	assert(state.money == money_before and state.reputation == reputation_before)
	state.jobs[&"preference_test"]["consequence"] = true
	state.jobs[&"preference_test"]["title"] = "Кран покрылся магическим льдом"
	office._refresh_details()
	await process_frame
	assert(office.detail_badge.position.y >= office.detail_title.position.y + office.detail_title.size.y + 8)
	assert(office.detail_body.position.y >= office.detail_badge.position.y + office.detail_badge.size.y)
	assert(office.detail_body.position.y + office.detail_body.size.y <= office.detail_more_button.position.y)
	state.jobs[&"preference_test"]["restoration"] = true
	office._refresh_details()
	assert(office.detail_body.position.y + office.detail_body.size.y <= office.detail_more_button.position.y)
	assert(office.restoration_payment_label.position.y + office.restoration_payment_label.size.y <= office.preference_request_label.position.y)
	assert(office.preference_request_label.position.y + office.preference_request_label.size.y <= office.assignment_label.position.y)
	assert(office.assignment_label.position.y + office.assignment_label.size.y <= office.depart_button.position.y)
	state.world_memory.get_or_create_relation("ragnar", "boris")["access_status"] = "banned"
	assert(state.get_preferred_employee_request(&"preference_test").is_empty())
	office._refresh_details()
	assert(not office.preference_request_label.visible)
	# Legacy requests gain a snapshot once, not a new choice after each load.
	state.jobs[&"preference_test"]["generated_instance"].erase("preferred_employee_id")
	state.generated_jobs["preference_test"].erase("preferred_employee_id")
	state._migrate_job_preferences()
	assert(state.get_preferred_employee_for_job(&"preference_test") == &"grog")
	state.employees[&"nika"]["available"] = false
	_good(state, "nika", 10)
	assert(state._preferred_employee_for_resident("ragnar") == &"grog")
	assert(LocalizationHelper.client_terms("Жилец, претензия жильца, отношения с жильцами") == "Клиент, претензия клиента, отношения с клиентами")
	var books = office.books_layer
	books.open_section(&"reviews")
	assert(books.detail_title.text == "ОТЗЫВЫ КЛИЕНТОВ")
	books._render_archive_report({"resident": "Господин Рагнар", "crew": ["Борис Медяк"], "summary": "Жилец доволен.", "claim_amount": 0, "rating": 5})
	assert("Клиент: Господин Рагнар" in books.detail_body.text)
	assert("Клиент доволен" in books.detail_body.text)
	assert(not "Жилец" in books.detail_body.text)
	books._render_financial_event({"title": "Компенсация жильцу", "kind": "compensation", "amount": -350})
	assert(books.detail_title.text == "Компенсация клиенту")
	office.queue_free()
	await process_frame
	print("CLIENT PREFERENCE SMOKE TEST: PASS")
	quit()
