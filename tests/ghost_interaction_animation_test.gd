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
func reset_room(room: Node, employee: StringName, trap_state: String = "installed", mirror_state: String = "covered") -> void:
	room.simulation = Ghost.new()
	room.simulation.world_object.merge({"resident_intro_seen": true, "ghost_inspected": true, "mirror_inspected": true, "trap_state": trap_state, "mirror_state": mirror_state}, true)
	room.selected_employee_id = employee
	room.selected_target = &"ghost"
	room._configure_employee_actor()
	room._apply_visual_state()
	room._save_state()
func _run() -> void:
	if not "MirrorTests" in OS.get_user_data_dir():
		quit(1)
		return
	var sim := Ghost.new()
	for employee: StringName in [&"grog", &"nika", &"liliya", &"felix"]:
		check(not sim.install_trap(employee, true)["applied"] and sim.world_object["trap_state"] == "packed", "Ловушку не устанавливает " + String(employee))
	for employee: StringName in [&"liliya", &"felix"]:
		check(not sim.uncover_mirror(employee, true)["applied"] and sim.world_object["mirror_state"] == "covered", "Полотно не снимает " + String(employee))
	for employee: StringName in [&"boris", &"grog", &"nika"]:
		var allowed := Ghost.new()
		check(allowed.uncover_mirror(employee, true)["applied"], "Полотно снимает " + String(employee))
	var state := root.get_node("GameState")
	state.start_new_game()
	state.skip_tutorial()
	state.active_job_id = &"escaped_ghost"
	state.jobs[&"escaped_ghost"].merge({"unlocked": true, "dispatched": true, "assigned": PackedStringArray(["boris", "grog", "nika", "liliya", "felix"])}, true)
	state.owned_supply_items.append("ghost_trap")
	for employee: StringName in [&"boris", &"grog", &"nika", &"liliya", &"felix"]:
		state.employees[employee]["available"] = true
		state.employees[employee]["arrival_until"] = 0
	sim.world_object["resident_intro_seen"] = true
	sim.world_object["ghost_inspected"] = true
	sim.world_object["mirror_inspected"] = true
	state.set_job_repair_state(&"escaped_ghost", sim.get_state())
	var room := (load("res://scenes/GhostMirrorRoom.tscn") as PackedScene).instantiate()
	root.add_child(room)
	await process_frame
	var floor_y: float = room.employee_actor.home_position.y
	check(is_equal_approx(room.physical_approach.position.y, floor_y) and is_equal_approx(room.mirror_physical_approach.position.y, floor_y), "Подходы к призраку и зеркалу стоят на высоте исходной позиции сотрудника")
	for caged: bool in [false, true]:
		room.simulation.world_object["lunnopuh_state"] = "caged" if caged else "absent"
		room._apply_visual_state()
		check(is_equal_approx(room.to_local(room.get_node("TrapPlacement/PhysicalApproach").global_position).y, floor_y), "Ловушка сохраняет высоту подхода рядом с клеткой и без неё")
	var pet_group: Node2D = room.get_node("LunnopuhTablePlacement")
	var pet_button: Button = room.lunnopuh_cage.get_node("InteractionButton")
	room.simulation.world_object["lunnopuh_state"] = "caged"
	pet_group.position += Vector2(-12, 18)
	pet_group.scale = Vector2(0.9, 0.9)
	var edited_position: Vector2 = pet_group.position
	room._apply_visual_state()
	check(pet_group.visible and room.lunnopuh_cage.visible and not pet_button.visible and pet_button.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Лунопух на столике декоративный и не перехватывает курсор")
	check(pet_group.position == edited_position and pet_group.scale == Vector2(0.9, 0.9), "Настройки положения и масштаба столика сохраняются при обновлении состояния")
	room.simulation.world_object["lunnopuh_state"] = "absent"
	room._apply_visual_state()
	check(not pet_group.visible, "Столик с клеткой скрыт, если Лунопух не остался у Селесты")
	for employee: StringName in [&"boris", &"grog"]:
		reset_room(room, employee)
		room.employee_actor.position = room.employee_actor.home_position
		var start_x: float = room.employee_actor.position.x
		var action: StringName = &"diagnose" if employee == &"boris" else &"physical_move"
		room._begin_action(action)
		await create_timer(0.65).timeout
		check(is_equal_approx(room.employee_actor.position.y, floor_y) and room.employee_actor.position.x > start_x and room.employee_actor.position.x < room.physical_approach.position.x, "Маршрут к призраку идёт вдоль пола без спуска: " + String(employee))
		await create_timer(1.8).timeout
		check(room.employee_actor.position.distance_to(room.physical_approach.position) < 1.0, "Сотрудник доходит к точке призрака: " + String(employee))
		if not state.get_pending_job_action(&"escaped_ghost").is_empty():
			state.clear_pending_job_action(&"escaped_ghost")
			room._resolve_action(action)
		await create_timer(0.9).timeout
	room.queue_free()
	await process_frame
	state.clear_pending_job_action(&"escaped_ghost")
	state.set_job_repair_state(&"escaped_ghost", sim.get_state())
	room = (load("res://scenes/GhostMirrorRoom.tscn") as PackedScene).instantiate()
	root.add_child(room)
	await process_frame
	for employee: StringName in [&"boris", &"grog", &"nika", &"liliya", &"felix"]:
		reset_room(room, employee, "packed")
		room._on_ghost_selected()
		var labels: Array[String] = []
		for button: Button in room.tool_bar.temporary_buttons:
			labels.append(button.text)
		check(labels.has("Установить ловушку") == (employee == &"boris"), "Кнопка установки соответствует сотруднику " + String(employee))
		room._on_mirror_selected()
		labels.clear()
		for button: Button in room.tool_bar.temporary_buttons:
			labels.append(button.text)
		check(labels.has("Снять полотно") == (employee in [&"boris", &"grog", &"nika"]), "Кнопка снятия соответствует сотруднику " + String(employee))
	reset_room(room, &"grog")
	await create_timer(0.8).timeout
	check(room.ghost.position.distance_to(room.ghost_home_position) > 0.5 and room.ghost.position.distance_to(room.ghost_home_position) < 15.0, "Спокойный призрак слегка парит вокруг точки сцены")
	room.employee_actor.position = room.physical_approach.position
	room._begin_action(&"physical_move")
	await create_timer(0.3).timeout
	check(room.employee_actor.specific_pose.visible and room.employee_actor.specific_pose.texture == room.employee_actor.catch_texture and not room.employee_actor.work_pose.visible, "Грог ловит призрака руками без ключа")
	await create_timer(0.9).timeout
	check(room.simulation.world_object["ghost_state"] == "angry" and not room.action_in_progress and state.get_pending_job_action(&"escaped_ghost").is_empty(), "Неудачная попытка не оставляет Грога работать")
	for employee: StringName in [&"boris", &"grog", &"liliya"]:
		reset_room(room, employee)
		var approach: Vector2 = room.to_local(room.get_node("TrapPlacement/PhysicalApproach").global_position)
		if employee in [&"boris", &"grog"]:
			room.employee_actor.position = approach + Vector2(-45, 0)
		room._begin_action(&"trap")
		await create_timer(1.25).timeout
		check(room.transfer_in_progress and room.simulation.world_object["ghost_state"] == "calm" and room.simulation.world_object["trap_state"] == "installed", "Призрак летит до поимки: " + String(employee))
		check(not room.employee_actor.work_pose.visible and state.get_pending_job_action(&"escaped_ghost").is_empty(), "Активация ловушки короткая и без заклинания: " + String(employee))
		if employee in [&"boris", &"grog"]:
			check(room.employee_actor.position.distance_to(approach) < 1.0, "Сотрудник подошёл к ловушке: " + String(employee))
		await create_timer(1.7).timeout
		check(room.simulation.world_object["ghost_state"] == "captured" and room.occupied_trap.visible and not room.ghost.visible and not room.action_in_progress, "После полёта ловушка заполнена: " + String(employee))
		check(not room.angry_tween.is_valid(), "Парение прекращается после поимки: " + String(employee))
	reset_room(room, &"felix", "packed", "open")
	room._begin_action(&"antimagic")
	await create_timer(1.1).timeout
	check(room.transfer_in_progress and room.simulation.world_object["ghost_state"] == "calm" and room.employee_actor.work_pose.visible, "Феликс держит рабочую позу во время возвращения")
	check(state.get_job_repair_state(&"escaped_ghost")["pending_actor_action"].get("phase", "") == "transfer", "Незавершённый полёт сохраняется")
	check(state._save_to_path("user://ghost_transfer_test.json") == OK, "Полёт записан в отдельное сохранение")
	await create_timer(1.8).timeout
	check(room.simulation.world_object["ghost_state"] == "expelled" and room.simulation.world_object["mirror_state"] == "open" and not room.employee_actor.work_pose.visible and not room.action_in_progress, "Феликс ждёт после исчезновения призрака; портал ещё открыт")
	room.queue_free()
	await process_frame
	check(state._load_from_path("user://ghost_transfer_test.json") == OK, "Сохранение полёта загружается")
	room = (load("res://scenes/GhostMirrorRoom.tscn") as PackedScene).instantiate()
	root.add_child(room)
	await process_frame
	check(room.action_in_progress and room.simulation.world_object["ghost_state"] == "calm" and room.selected_employee_id == &"felix", "Загрузка возобновляет полёт без раннего изгнания")
	await create_timer(1.1).timeout
	check(room.transfer_in_progress and room.employee_actor.work_pose.visible, "При загрузке Феликс снова сопровождает призрака")
	await create_timer(1.8).timeout
	check(room.simulation.world_object["ghost_state"] == "expelled" and room.simulation.action_log.size() == 1 and not room.action_in_progress, "Загруженный полёт применяется один раз")
	room.queue_free()
	await process_frame
	print("GHOST ANIMATION TEST: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
