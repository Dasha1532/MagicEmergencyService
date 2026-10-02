extends SceneTree

const Rules := preload("res://scripts/object_interaction_rules.gd")
const Repair := preload("res://scripts/repair_simulation.gd")
const Bath := preload("res://scripts/frozen_bath_simulation.gd")
const Memory := preload("res://scripts/world_memory.gd")
const Generator := preload("res://scripts/generated_job_generator.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var boris := {"abilities": PackedStringArray(["diagnose", "repair"])}
	var gloves := boris.duplicate(true)
	gloves["protections"] = PackedStringArray(["contact_heat"])
	var hot := Repair.new()
	var soot_test := Repair.new()
	soot_test.initialize_from_job({"generated_instance": {"initial_state": {"scorched": true, "damage": 0, "temperature": 12, "heat_source_active": true}}})
	_check(not bool(soot_test.world_object["scorched"]), "Spontaneous overheating does not produce soot, including old initial states")
	soot_test.apply_action(&"liliya", &"heat")
	_check(bool(soot_test.world_object["scorched"]), "Fire heating retains soot")
	hot.world_object["temperature"] = 12
	hot.world_object["valve_position"] = &"open"
	var actions := Rules.contextual_actions(hot.world_object, boris)
	_check(actions.size() == 1 and str(actions[0]["label"]) == "Повернуть вентиль", "Hot valve remains visible without gloves")
	_check(not hot.can_begin_action(&"turn_valve", boris), "Unsafe valve refuses before walking")
	_check(not hot.get_employee_reaction(&"boris", &"turn_valve", boris).is_empty(), "Approved glove refusal remains reachable")
	_check(not bool(hot.apply_action(&"boris", &"turn_valve", boris)["applied"]), "No unsafe contact")
	_check(hot.can_begin_action(&"turn_valve", gloves), "Gloves permit contact")
	_check(bool(hot.apply_action(&"boris", &"turn_valve", gloves)["applied"]) and str(hot.world_object["valve_position"]) == "closed", "Protected valve stops flow")
	var frozen := {"frozen": true, "valve_frozen": true}
	_check(Rules.valve_preflight_reason(frozen, boris).is_empty(), "Frozen valve permits walking and attempting before refusal")
	_check(Rules.valve_preflight_reason({"valve_operable": false}, boris).is_empty(), "Jammed valve requires an attempt")
	_check(bool(hot.apply_action(&"boris", &"turn_valve", gloves)["applied"]) and str(hot.world_object["valve_position"]) == "open", "Boris can reopen a protected hot valve like Grog")
	_check(Rules.contextual_actions(frozen, boris).size() == 1 and "примёрз" in Rules.valve_block_reason(frozen, boris), "Frozen valve remains visible and explains refusal")
	_check(Rules.valve_block_reason({"frozen": true, "valve_frozen": false}, boris).is_empty(), "Frozen body does not imply blocked valve")
	_check(not Rules.is_applicable(&"repair", {"broken": true}) and Rules.contextual_actions({"broken": true}, boris).is_empty(), "Destroyed object offers neither repair nor valve")
	_check(not Rules.is_applicable(&"install_thermal_regulator", {"tags": ["melted"]}), "No regulator on destroyed target")
	_check(Rules.resolves_on_impact(&"turn_valve") and not Rules.resolves_on_impact(&"repair"), "Valve uses impact, repair retains work timer")

	var memory := Memory.new()
	memory.reset()
	var event := {"event_id": "contract.test", "event_type": "cold_trace", "payload": {"anomaly_id": "cold_trace"}}
	var instance: Dictionary = Generator.generate_faucet_consequence(event, ["heat"], memory.generator_context())
	var job: Dictionary = Generator.materialize_job(instance)
	var client := str(instance["resident_id"])
	var sim := Bath.new()
	sim.initialize_from_job(job)
	_check(Rules.contextual_actions(sim.world_object, boris)[0]["label"] == actions[0]["label"], "Both adapters share action label")
	var damage: Dictionary = sim.apply_action(&"grog", &"physical_move", false, &"bath")
	_check("Ванна цела" not in sim.get_employee_reaction(&"boris", &"diagnose", &"bath"), "Boris observes actual bath damage")
	var bath_diagnosis := sim.apply_action(&"boris", &"diagnose", false, &"bath")
	_check("трещина" in str(bath_diagnosis["message"]) and "цела" not in str(bath_diagnosis["message"]), "Diagnosis result also describes damaged bath")
	var saved_bath: Dictionary = JSON.parse_string(JSON.stringify(sim.get_state()))
	var loaded_bath := Bath.new()
	loaded_bath.initialize_from_job(job)
	loaded_bath.load_state(saved_bath)
	_check(bool(loaded_bath.world_object["bath_damaged"]), "Bath damage survives JSON save/load")
	_check("трещина" in loaded_bath.get_employee_reaction(&"boris", &"diagnose", &"bath"), "Loaded bath diagnosis reflects damage")
	_check("трещина" in str(loaded_bath.apply_action(&"boris", &"diagnose", false, &"bath")["message"]), "Loaded bath result reflects damage")
	_check(bool(damage["caused_damage"]) and damage["damage_target_ids"] == [Bath.BATH_INSTANCE_ID], "Damage event identifies bathtub, not faucet")
	_check((damage["destroyed_target_ids"] as Array).is_empty(), "Crack is not destruction")
	var relation: Dictionary = memory.get_or_create_relation(client, "grog")
	relation["professional_trust"] = 30
	memory.ensure_job_context(&"generated_faucet_contract", {}, "", {"resident_id": client})
	memory.record_job_state(&"generated_faucet_contract", sim.get_state(), 2, 540)
	relation = memory.get_relation(client, "grog")
	_check(int(relation["professional_trust"]) == 15 and str(relation["access_status"]) == "warned", "New damage immediately overrides past trust without banning")
	var dashboard = load("res://scripts/office_dashboard.gd").new()
	_check(dashboard._relation_description(relation) == "не доверяет", "Positive old score cannot hide current warning")
	dashboard.free()
	_check(int(memory.get_relation(client, "boris").get("professional_trust", 0)) == 0 and not memory.get_relation(client, "boris").has("damage_jobs"), "Innocent crew not penalized")
	var bath_event_found := false
	for recorded: Dictionary in memory.significant_events:
		if str(recorded["target_instance_id"]) == Bath.BATH_INSTANCE_ID and str(recorded["actor_id"]) == "grog":
			bath_event_found = true
	_check(bath_event_found, "World event retains target and culprit")
	memory.record_job_state(&"generated_faucet_contract", sim.get_state(), 2, 541)
	var reloaded := Memory.new()
	reloaded.load_data(memory.to_data())
	reloaded.record_job_state(&"generated_faucet_contract", sim.get_state(), 2, 542)
	reloaded.evaluate_crew_relations({"resident_id": client, "job_id": "generated_faucet_contract", "damage_employee_ids": ["grog"], "claim_amount": 180})
	_check(int(reloaded.get_relation(client, "grog")["professional_trust"]) == 15, "Save reload and completion never apply damage twice")
	reloaded.evaluate_crew_relations({"resident_id": client, "job_id": "generated_faucet_contract", "damage_employee_ids": ["grog", "liliya"], "object_destroyed": true, "claim_amount": 530, "damage_severity_by_employee": {"grog": 1, "liliya": 2}})
	_check(str(reloaded.get_relation(client, "grog")["access_status"]) == "warned" and str(reloaded.get_relation(client, "liliya")["access_status"]) == "banned", "One actor's destruction does not ban another for a crack")
	var unchanged: Dictionary = sim.apply_action(&"grog", &"physical_move", false, &"bath")
	_check(not bool(unchanged["caused_damage"]), "Unchanged old crack does not create new damage")

	# Same actor's later destruction escalates severity within the same job.
	var broken := Rules.action_event(&"grog", &"brute_force", {Bath.FAUCET_INSTANCE_ID: {"broken": false}}, {Bath.FAUCET_INSTANCE_ID: {"broken": true}}, {"applied": true})
	var escalation := sim.get_state()
	escalation["action_log"].append(broken)
	reloaded.record_job_state(&"generated_faucet_contract", escalation, 2, 543)
	_check(str(reloaded.get_relation(client, "grog")["access_status"]) == "banned", "Destruction escalates an existing warning")
	_check(str(reloaded.get_relation(client, "grog")["last_damage_job_id"]) == "generated_faucet_contract", "Damage source survives escalation")

	var state = root.get_node("GameState")
	state.start_new_game()
	instance["instance_id"] = "generated_faucet_contract_room"
	state._register_generated_job(instance)
	state.active_job_id = &"generated_faucet_contract_room"
	state.jobs[state.active_job_id]["unlocked"] = true
	state.assign_employee(&"grog", state.active_job_id)
	state.assign_employee(&"boris", state.active_job_id)
	state.begin_job(state.active_job_id)
	state.advance_time(state.TRAVEL_TIME_MINUTES)
	var room = load("res://scenes/FrozenBathRoom.tscn").instantiate()
	root.add_child(room)
	await process_frame
	room.selected_employee_id = &"boris"
	room.selected_target = &"faucet"
	room._on_action_impact(&"turn_valve")
	_check(not room.ice_stream.visible, "Closing hides ice in the same impact callback")
	room._on_action_impact(&"turn_valve")
	_check(room.ice_stream.visible and not room.repair_hud.is_timed_action_active(), "Opening shows ice immediately without repair timer")
	room.simulation.apply_action(&"boris", &"repair", true, &"faucet")
	room._apply_visual_state()
	_check(room.water_stream.visible and not room.ice_stream.visible and room.regulated_faucet.visible, "Regulator changes visible ice flow into water with open valve")
	room._on_action_impact(&"turn_valve")
	_check(not room.water_stream.visible, "Closing regulated faucet stops water immediately")
	room._on_action_impact(&"turn_valve")
	_check(room.water_stream.visible, "Opening regulated faucet restores water immediately")
	room.selected_employee_id = &"grog"
	room.selected_target = &"bath"
	room.simulation.world_object["ice_removed"] = false
	room.simulation.world_object["bath_damaged"] = false
	room.waiting_work_action = &"physical_move"
	room.work_timer_finished = false
	room.work_actor_finished = false
	room._on_work_timer_finished()
	_check(not bool(room.simulation.world_object["bath_damaged"]), "Timer alone cannot crack ice before actor finishes")
	room._on_action_finished()
	_check("трещина" in room._instant_target_result(&"boris", &"bath"), "Clicking damaged bath uses current diagnosis rather than old constant")
	_check(bool(room.simulation.world_object["bath_damaged"]) and room.waiting_work_action.is_empty(), "Ice cracks only once both work and actor finish")
	room.simulation.apply_action(&"grog", &"physical_move", false, &"bath")
	room._save_state()
	var save_path := "res://tests/.bath_damage_roundtrip.json"
	_check(state._save_to_path(save_path) == OK, "Campaign saves damaged bath to disk")
	_check(state._load_from_path(save_path) == OK, "Campaign reloads damaged bath from disk")
	var campaign_bath := Bath.new()
	campaign_bath.initialize_from_job(state.jobs[state.active_job_id])
	campaign_bath.load_state(state.get_job_repair_state(state.active_job_id))
	_check(bool(campaign_bath.world_object["bath_damaged"]) and "трещина" in campaign_bath.get_employee_reaction(&"boris", &"diagnose", &"bath"), "Full campaign reload preserves damage and Boris diagnosis")
	_check(str(state.get_employee_access_status_for_job(&"grog", state.active_job_id)) == "warned" and state.can_employee_work_on_job(&"grog", state.active_job_id), "Actual campaign remembers crack before job completion and still admits Grog")
	var visit_state: Dictionary = room.simulation.get_state()
	visit_state["action_log"].append(broken)
	state.set_job_repair_state(state.active_job_id, visit_state)
	state.advance_time(1)
	_check(state.can_employee_work_on_job(&"grog", state.active_job_id) and state.take_access_messages(state.active_job_id).is_empty(), "New ban does not eject crew midway through the current visit")
	var visit_job: StringName = state.active_job_id
	_check(state.recall_job(visit_job), "Current crew can be recalled")
	state.advance_time(state.TRAVEL_TIME_MINUTES)
	state.assign_employee(&"grog", visit_job)
	state.begin_job(visit_job)
	state.advance_time(state.TRAVEL_TIME_MINUTES)
	_check(not state.can_employee_work_on_job(&"grog", visit_job) and state.is_employee_returning(&"grog"), "Ban applies on next entry even to the same unfinished job")
	room.queue_free()
	await process_frame
	var hot_instance: Dictionary = Generator.generate_faucet_consequence({"event_id": "contract.hot", "event_type": "faucet_overheat", "payload": {"anomaly_id": "faucet_overheat"}}, ["freeze"], {})
	hot_instance["instance_id"] = "generated_faucet_contract_hot"
	state._register_generated_job(hot_instance)
	state.active_job_id = &"generated_faucet_contract_hot"
	var house = load("res://scenes/RepairHouse.tscn").instantiate()
	root.add_child(house)
	await process_frame
	house.selected_employee_id = &"boris"
	house.tool_bar.configure_for_employee("Борис Медяк", boris["abilities"], "Ремонт")
	house._apply_selected_action()
	_check(house.tool_bar.temporary_buttons.size() == 1 and house.tool_bar.temporary_buttons[0].text == "Повернуть вентиль", "Actual hot faucet menu keeps valve")
	house.selected_tool_id = &"turn_valve"
	house._begin_selected_action()
	_check(not house.action_in_progress and not house.repair_hud.is_timed_action_active(), "Refusal does not start movement or work")
	house.simulation.world_object["broken"] = true
	house.simulation.world_object["tags"] = PackedStringArray(["melted", "sealed_by_melt"])
	house.simulation.world_object["visual_state"] = &"melted"
	house.simulation.world_object["valve_position"] = &"open"
	house.simulation.world_object["flow_content"] = &"water"
	var faucet_visual = house.get_node("InteractiveObjects/LavaFaucet")
	faucet_visual.sync_from_state(house.simulation.world_object)
	_check(not faucet_visual.water_stream.visible and not faucet_visual.lava_stream.visible, "Melted sealed faucet shows no stream even with open valve")
	house._apply_selected_action()
	_check(house.tool_bar.temporary_buttons.is_empty() and not house.tool_bar.get_node("%RepairButton").visible, "Actual destroyed faucet menu removes repair and valve")
	house.queue_free()
	await process_frame
	if failures.is_empty():
		print("Object action contract smoke test: PASS")
	quit(0 if failures.is_empty() else 1)
