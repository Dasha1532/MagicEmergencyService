extends SceneTree
const Ghost := preload("res://scripts/ghost_followup_simulation.gd")
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
	var catalog_errors: PackedStringArray = preload("res://scripts/generative_job_catalog.gd").validate_catalog()
	check(catalog_errors.is_empty(), "Каталог объектов: " + str(catalog_errors))
	var sim := Ghost.new()
	check(not sim.is_resolved() and sim.get_completion_result().is_empty(), "Свободный призрак не допускает завершения")
	check(not sim.can_begin_action(&"trap"), "Борис сначала осматривает призрака")
	sim.apply_ghost_action(&"boris", &"diagnose")
	check(sim.can_begin_action(&"trap"), "Осмотр открывает действия")
	sim.interaction_target = &"mirror"
	check(not sim.can_begin_action(&"uncover"), "Зеркало требует собственного осмотра")
	sim.perform(&"mirror", &"boris", &"diagnose")
	check(sim.can_begin_action(&"uncover"), "Осмотр зеркала сохранён")
	check(not sim.install_trap(&"boris", false)["applied"] and str(sim.world_object["trap_state"]) == "packed", "Отсутствующая ловушка не устанавливается")
	sim.install_trap(&"boris", true)
	sim.apply_ghost_action(&"nika", &"trap")
	check(sim.is_resolved() and sim.action_log.back()["object_changes"].size() == 2, "Поимка меняет призрака и ловушку")
	check(sim.get_completion_result()["retained_supply_items"] == ["ghost_trap"], "Оплаченная занятая ловушка остаётся у клиента")
	sim.pending_actor_action = {"employee_id": "boris", "action_id": "uncover", "target_id": "mirror"}
	var restored := Ghost.new()
	restored.load_state(JSON.parse_string(JSON.stringify(sim.get_state())))
	check(restored.pending_actor_action["target_id"] == "mirror" and restored.can_begin_action(&"uncover"), "Загрузка восстанавливает цель и осмотр")
	check(restored.world_object["mirror_state"] == "covered", "Сохранённое незавершённое действие не меняет объект")
	restored.uncover_mirror(&"boris", true)
	check(not restored.is_resolved(), "Открытие портала отменяет готовность завершения")
	restored.close_portal(&"felix", true)
	check(restored.is_resolved(), "Закрытие портала завершает поимку")
	var inherited := Ghost.new()
	inherited.apply_source_follow_up({"frame_damage": 1})
	inherited.uncover_mirror(&"boris", true)
	check(not inherited.action_log.back()["result"]["caused_damage"], "Прежний ущерб не приписывается Борису")
	var damage: Dictionary = inherited.break_mirror(&"grog")
	check(damage["caused_damage"] and damage["destroyed_target_ids"] == ["portal_mirror_room.portal_mirror"], "Разрушение хранит цель ущерба")
	var result := inherited.get_completion_result()
	check(result["compensation_cost"] == 300 and result["reward_adjustment"] == -200, "Согласованные суммы сохранены")
	check(result["successful_employee_ids"].has("boris"), "Полезная работа учитывается отдельно от виновника")
	var legacy := Ghost.new()
	legacy.load_state({"world_object": {"definition_id": "escaped_ghost", "mirror_state": "destroyed", "ghost_state": "expelled"}, "action_log": [{"employee_id": "grog", "action_id": "physical_move", "result": {"applied": true}}]})
	check(legacy.action_log[0]["result"]["caused_damage"] and legacy.action_log[0]["employee_id"] == "grog", "Старый журнал восстанавливает виновника разрушения")
	var memory: RefCounted = preload("res://scripts/world_memory.gd").new()
	memory.record_job_state(&"escaped_ghost", inherited.get_state(), 2, 560)
	check(memory.objects["portal_mirror_room.portal_mirror"]["properties"]["destroyed"], "Продолжение обновляет то же зеркало в памяти")
	check(memory.objects["portal_mirror_room.escaped_ghost"]["properties"]["state"] == "expelled", "Память хранит фактическое состояние призрака")
	var state := root.get_node("GameState")
	state.start_new_game()
	state.skip_tutorial()
	state.active_job_id = &"escaped_ghost"
	state.jobs[&"escaped_ghost"]["assigned"] = PackedStringArray(["boris", "grog", "felix"])
	state.jobs[&"escaped_ghost"]["unlocked"] = true
	state.jobs[&"escaped_ghost"]["dispatched"] = true
	state.owned_supply_items.append("ghost_trap")
	for employee: StringName in [&"boris", &"grog", &"felix"]:
		state.employees[employee]["available"] = true
		state.employees[employee]["arrival_until"] = 0
	var seed := Ghost.new()
	seed.world_object["resident_intro_seen"] = true
	seed.world_object["ghost_inspected"] = true
	state.set_job_repair_state(&"escaped_ghost", seed.get_state())
	var room_scene := load("res://scenes/GhostMirrorRoom.tscn") as PackedScene
	var room := room_scene.instantiate()
	root.add_child(room)
	await process_frame
	room.selected_employee_id = &"boris"
	room.selected_target = &"ghost"
	room._configure_employee_actor()
	room._begin_action(&"install_trap")
	check(room.simulation.world_object["trap_state"] == "packed" and state.get_pending_job_action(&"escaped_ghost").is_empty(), "Подход не устанавливает ловушку и не запускает время работы")
	check(state.get_job_repair_state(&"escaped_ghost")["pending_actor_action"]["target_id"] == "ghost", "Подход сохраняет цель")
	room._on_employee_selected(&"grog")
	check(room.selected_employee_id == &"boris", "Смена выбора не подменяет исполнителя")
	room._on_action_impact(&"install_trap")
	state.set_clock_paused(true)
	room._on_action_finished()
	check(room.simulation.world_object["trap_state"] == "packed" and room.action_in_progress, "Рабочая анимация не обгоняет время установки")
	check(state._save_to_path("user://ghost_pending_test.json") == OK, "Незавершённая работа сохранена отдельно")
	room.queue_free()
	await process_frame
	check(state._load_from_path("user://ghost_pending_test.json") == OK, "Сохранение работы загружается")
	room = room_scene.instantiate()
	root.add_child(room)
	await process_frame
	check(room.action_in_progress and room.selected_employee_id == &"boris" and room.selected_target == &"ghost", "Комната восстанавливает сотрудника и цель установки")
	state.clear_pending_job_action(&"escaped_ghost")
	room._resolve_action(&"install_trap")
	check(room.simulation.world_object["trap_state"] == "installed" and not room.action_in_progress, "Ловушка установлена после окончания работы")
	room.simulation.apply_ghost_action(&"boris", &"trap")
	room.simulation.break_mirror(&"grog")
	room._save_state()
	check(state.complete_active_job(room.simulation.get_completion_result()), "Общий акт принимает результат продолжения")
	var report: Dictionary = state.job_reports.back()
	check(report["damage_employee_ids"].has("grog") and not report["damage_employee_ids"].has("boris"), "Акт продолжения отличает виновника ущерба от помощника")
	check(report["successful_employee_ids"].has("boris") and not state.has_supply_item(&"ghost_trap"), "Полезная поимка учтена, занятая ловушка остаётся у клиента")
	room.queue_free()
	await process_frame
	print("GHOST PROPERTIES TEST: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
