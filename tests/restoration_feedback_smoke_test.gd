extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _prepare(state: Node) -> void:
	state.jobs = {}
	state.generated_jobs = {}
	state.job_reports = [{"job_id": "destroyed", "resident_id": "ragnar", "resident": "Господин Рагнар", "object_definition_id": "lava_faucet", "object_instance_id": "old_quarter_5.bathroom.lava_faucet", "object_destroyed": true, "completed_day": 1, "reputation_change": -8, "claim_status": "denied", "claim_amount": 350}]
	state.completed_job_ids = PackedStringArray(["destroyed"])
	state.pending_job_report = {}
	state.job_repair_states = {}
	state.active_job_id = &""
	state.selected_job_id = &"destroyed_restoration"
	state.money = 600
	state.reputation = 29
	state.day = 2
	state.time_minutes = 540
	state.tutorial_state = {"status": "completed"}
	state.world_memory.reset()
	state.world_memory.get_or_create_relation("ragnar", "liliya")["access_status"] = "banned"
	for employee_id: StringName in state.employees:
		state.employees[employee_id]["return_until"] = 0
		state.employees[employee_id]["arrival_until"] = 0
	state._publish_due_restoration_jobs()
	state.set_clock_paused(true)

func _run() -> void:
	var state: Node = root.get_node("GameState")
	_prepare(state)
	var job_id := &"destroyed_restoration"
	var office = load("res://scenes/ui/OfficeDashboard.tscn").instantiate()
	root.add_child(office)
	office.auto_wait_running = true
	for employee_id: StringName in [&"liliya", &"boris", &"grog"]:
		state.assign_employee(employee_id, job_id)
	assert(state.begin_job(job_id))
	state.leave_active_job()
	state.advance_time(state.TRAVEL_TIME_MINUTES)
	assert(state.jobs[job_id]["access_messages"].size() == 1)
	assert(state.begin_job(job_id))
	assert(state.jobs[job_id]["access_messages"].size() == 1)
	office.queue_free()
	await process_frame
	var room = load("res://scenes/RepairHouse.tscn").instantiate()
	root.add_child(room)
	await create_timer(0.5).timeout
	assert(room.repair_hud.employee_reaction_label.text == "Я просил больше не присылать эту магичку")
	assert(not "Рагнар" in room.repair_hud.employee_reaction_label.text)
	assert(not room.repair_hud.access_notice.visible)
	room.repair_hud.clear_employee_reaction()
	assert(room.repair_hud.access_notice.is_visible_in_tree())
	assert("Хозяин не впустил сотрудника: Лилия Морозова" in room.repair_hud.access_notice_text.text)
	assert("возвращается в офис" in room.repair_hud.access_notice_text.text)
	room.repair_hud._advance_access_sequence()
	assert(not room.repair_hud.access_notice.visible)
	assert(room.repair_hud.employee_reaction_label.text == "Здравствуйте. Надеюсь, в этот раз обойдётся без повреждений.")
	room.repair_hud.clear_employee_reaction()
	assert(not room.repair_hud.access_sequence_active)
	assert(room.repair_hud.employee_buttons.size() == 2)
	assert(not room.simulation.can_employee_start_action(&"repair", state.employees[&"boris"]))
	assert(not room.simulation.apply_action(&"boris", &"repair").get("applied"))
	assert(room.simulation.can_replace_faucet())
	state.owned_supply_items.append("replacement_faucet")
	room.repair_hud._select_employee(&"boris")
	room._apply_selected_action()
	assert(not room.tool_bar.get_node("%RepairButton").visible)
	var replacement_found := false
	for action_button: Button in room.tool_bar.temporary_buttons:
		if action_button.text == "Заменить кран":
			replacement_found = true
	assert(replacement_found)
	room.queue_free()
	await process_frame
	_prepare(state)
	state.assign_employee(&"liliya", job_id)
	assert(state.begin_job(job_id))
	state.leave_active_job()
	office = load("res://scenes/ui/OfficeDashboard.tscn").instantiate()
	root.add_child(office)
	office._open_jobs()
	state.advance_time(state.TRAVEL_TIME_MINUTES)
	assert(office.access_notice_dialog.is_visible_in_tree())
	assert("Лилия Морозова" in office.access_notice_body.text)
	assert("возвращается в офис" in office.access_notice_body.text)
	assert(not "Я просил" in office.access_notice_body.text)
	assert(not "Господин Рагнар:" in office.access_notice_body.text)
	assert(state.jobs[job_id]["assigned"].is_empty())
	assert(state.is_employee_returning(&"liliya"))
	assert(office.restoration_refuse_dialog is Control and not office.restoration_refuse_dialog is Window)
	office._confirm_restoration_refusal()
	assert(office.restoration_refuse_dialog.is_visible_in_tree())
	assert(office.detail_badge.text == "ПОВТОРНЫЙ ВЫЗОВ")
	var repeat_badge_found := false
	for card: Node in office.job_list.get_children():
		for child: Node in card.get_children():
			if child is Label and "ПОВТОРНАЯ" in child.text:
				repeat_badge_found = true
	assert(repeat_badge_found)
	office.queue_free()
	await process_frame
	print("RESTORATION FEEDBACK SMOKE TEST: PASS")
	quit()
