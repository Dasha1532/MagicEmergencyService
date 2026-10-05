extends SceneTree
const Ghost := preload("res://scripts/ghost_followup_simulation.gd")
const Mirror := preload("res://scripts/portal_mirror_simulation.gd")
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func check(value: bool, message: String) -> void:
	if value:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error(message)
func _run() -> void:
	if not "MirrorTests" in OS.get_user_data_dir():
		quit(1)
		return
	var sim := Ghost.new()
	sim.apply_source_follow_up({"cold_aura": true})
	check(sim.uncover_mirror(&"nika", false)["applied"], "Снятие полотна не требует антимагии")
	var common := Mirror.new()
	common.world_object.merge({"cold_aura": true, "portal_open": true, "covered": false}, true)
	for action: StringName in [&"freeze", &"heat", &"heat", &"heat"]:
		var expected: Dictionary = common.apply_action(&"liliya", action)
		var actual: Dictionary = sim.perform(&"mirror", &"liliya", action)
		check(actual["applied"] == expected["applied"] and actual["message"] == expected["message"] and actual["caused_damage"] == expected["caused_damage"], "Действие совпадает с общим зеркалом: " + String(action))
		check(sim.world_object["frame_damage"] == common.world_object["damage"] and sim.world_object["temperature"] == common.world_object["temperature"], "Свойства совпадают с общим зеркалом: " + String(action))
	check(sim.world_object["ghost_state"] == "calm" and sim.mirror_visual_state() == &"heat_damaged", "Нагрев зеркала не выдаётся за воздействие на призрака")
	check(not sim.perform(&"mirror", &"nika", &"telekinesis")["applied"], "Активное зеркало сохраняет отказ телекинеза")
	check(not sim.perform(&"mirror", &"boris", &"cover", {"protective_cloth_available": false})["applied"] and sim.world_object["mirror_state"] == "open", "Без полотна повторная изоляция не происходит")
	check(sim.perform(&"mirror", &"grog", &"cover", {"protective_cloth_available": true})["applied"] and not sim.is_resolved(), "Можно снова завесить зеркало; свободного призрака ещё нужно поймать")
	sim.install_trap(&"boris", true)
	sim.apply_ghost_action(&"boris", &"trap")
	check(sim.is_resolved() and sim.get_completion_result()["successful_employee_ids"].has("liliya"), "Поимка с полотном завершает работу и учитывает устранение холода")
	var restored := Ghost.new()
	restored.load_state(JSON.parse_string(JSON.stringify(sim.get_state())))
	check(restored.world_object["temperature"] == sim.world_object["temperature"] and restored.world_object["frame_damage"] == 1 and restored.world_object["mirror_state"] == "covered", "Сохранение восстанавливает повторное полотно и свойства зеркала")
	var state := root.get_node("GameState")
	state.start_new_game()
	state.skip_tutorial()
	state.active_job_id = &"escaped_ghost"
	state.jobs[&"escaped_ghost"].merge({"unlocked": true, "dispatched": true, "assigned": PackedStringArray(["boris", "grog", "nika", "liliya"])}, true)
	for employee: StringName in [&"boris", &"grog", &"nika", &"liliya"]:
		state.employees[employee]["available"] = true
		state.employees[employee]["arrival_until"] = 0
	var seed := Ghost.new()
	seed.world_object.merge({"resident_intro_seen": true, "ghost_inspected": true, "mirror_inspected": true}, true)
	state.set_job_repair_state(&"escaped_ghost", seed.get_state())
	var room := (load("res://scenes/GhostMirrorRoom.tscn") as PackedScene).instantiate()
	root.add_child(room)
	await process_frame
	room.selected_target = &"mirror"
	for employee: StringName in [&"boris", &"grog", &"nika"]:
		room.selected_employee_id = employee
		room._resolve_action(&"uncover")
		check(state.has_supply_item(&"protective_cloth") and room.simulation.world_object["mirror_state"] == "open", "Снятое полотно возвращается на склад: " + String(employee))
		if employee == &"nika":
			room._on_mirror_selected()
			check(room.tool_bar.get_node("%MoveButton").visible, "У Ники снова есть телекинез зеркала")
		room.selected_employee_id = &"liliya"
		room._on_mirror_selected()
		check(room.tool_bar.get_node("%FreezeButton").visible and room.tool_bar.get_node("%HeatButton").visible, "У Лилии снова есть заморозка и нагрев зеркала")
		room.selected_employee_id = employee
		room._resolve_action(&"cover")
		check(not state.has_supply_item(&"protective_cloth") and room.simulation.world_object["mirror_state"] == "covered", "Повторное навешивание забирает полотно со склада: " + String(employee))
		var log_count: int = room.simulation.action_log.size()
		room._resolve_action(&"cover")
		check(not state.has_supply_item(&"protective_cloth") and not room.simulation.action_log.back()["result"]["applied"] and room.simulation.action_log.size() == log_count + 1, "Повторный отказ не списывает полотно второй раз")
	room.simulation.install_trap(&"boris", true)
	room.simulation.apply_ghost_action(&"boris", &"trap")
	check(room.simulation.get_completion_result()["expense_reimbursement"] == 250, "Полотно из первой заявки не возмещается повторно")
	room.queue_free()
	await process_frame
	print("GHOST REOPEN TEST: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
