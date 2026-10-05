extends SceneTree
const Care := preload("res://scripts/lunnopuh_care_simulation.gd")
const Mirror := preload("res://scripts/portal_mirror_simulation.gd")
const Ghost := preload("res://scripts/ghost_followup_simulation.gd")
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: ", label)
	else:
		failures.append(label)
		push_error(label)
func care(portal_open: bool = true, covered: bool = false, destroyed: bool = false) -> LunnopuhCareSimulation:
	var sim := Care.new()
	sim.initialize_from_job({"object_initial_state": {"portal_open": portal_open, "covered": covered, "destroyed": destroyed, "damage": 10 if destroyed else 0, "cold_aura": false, "magic_level": 9 if portal_open else 0}})
	return sim
func set_visit(state: Node, sim: RefCounted, employee: StringName) -> void:
	state.jobs[&"lunnopuh_care"].merge({"unlocked": true, "dispatched": true, "assigned": PackedStringArray([employee]), "object_initial_state": sim.world_object.duplicate(true)}, true)
	state.employees[employee]["available"] = true
	state.employees[employee]["arrival_until"] = 0
	state.active_job_id = &"lunnopuh_care"
	state.set_job_repair_state(&"lunnopuh_care", sim.get_state())
func _run() -> void:
	if not "MirrorTests" in OS.get_user_data_dir():
		quit(1)
		return
	var sim := care()
	check(not sim.is_resolved() and sim.get_completion_result().is_empty(), "Судьба пойманного Лунопуха ещё не решена")
	check(sim.lunnopuh_actions(&"boris") == PackedStringArray(["diagnose"]), "Борис сначала осматривает Лунопуха")
	check(not sim.apply_lunnopuh_action(&"boris", &"transport_lunnopuh")["applied"], "Перевозка Бориса до осмотра не применяется")
	check(sim.apply_lunnopuh_action(&"boris", &"diagnose")["message"] == Care.CARE.base_properties["diagnosis_open"], "Осмотр предлагает два исхода при сохранившемся портале")
	check(not sim.apply_lunnopuh_action(&"grog", &"return_lunnopuh")["applied"], "Грог не возвращает зверька телекинезом")
	check(sim.apply_lunnopuh_action(&"nika", &"return_lunnopuh")["applied"] and not sim.is_resolved(), "Возвращение оставляет отдельную задачу закрыть портал")
	sim.apply_action(&"felix", &"antimagic")
	check(sim.is_resolved(), "Возвращение и закрытие позволяют завершить заявку")
	var result := sim.get_completion_result()
	check(result["expense_reimbursement"] == 0 and result["returned_supply_items"] == ["lunnopuh_cage"] and "теперь он дома" in result["review"], "Нет повторной оплаты клетки, отзыв соответствует возвращению")
	for broken: bool in [false, true]:
		var closed := care(false, false, broken)
		check(not closed.lunnopuh_actions(&"nika").has("return_lunnopuh") and closed.get_resident_request() == Care.CARE.base_properties["request_closed"], "Закрытое/разбитое зеркало не предлагает возвращение")
		check(closed.lunnopuh_refusal(&"antimagic") == Care.CARE.base_properties["closed_antimagic_refusal"], "Отказ антимагии учитывает отсутствие портала")
		closed.apply_lunnopuh_action(&"grog", &"transport_lunnopuh")
		var completed := closed.get_completion_result()
		check(closed.is_resolved() and completed["compensation_cost"] == 0 and not completed["forfeit_payment"] and "смогут позаботиться" in completed["review"], "Приют завершает заявку и не приписывает старый ущерб новому сотруднику")
	var covered := care(true, true)
	check(not covered.lunnopuh_actions(&"nika").has("return_lunnopuh") and covered.get_resident_request() == Care.CARE.base_properties["request_open"], "Полотно скрывает возвращение, но сохраняет возможность родного мира")
	check(not covered.available_actions(&"liliya").has("uncover") and not covered.available_actions(&"felix").has("uncover"), "Лилия и Феликс не снимают полотно")
	covered.apply_action(&"nika", &"uncover")
	check(covered.lunnopuh_actions(&"nika").has("return_lunnopuh"), "Снятие полотна открывает возвращение")
	covered.apply_lunnopuh_action(&"nika", &"return_lunnopuh")
	covered.apply_action(&"nika", &"cover")
	check(covered.is_resolved() and covered.get_completion_result()["expense_reimbursement"] == 0, "Повторная изоляция завершает заявку без повторного возмещения полотна")
	var damaged := care()
	damaged.apply_action(&"liliya", &"heat")
	damaged.apply_lunnopuh_action(&"grog", &"transport_lunnopuh")
	damaged.apply_action(&"grog", &"physical_move")
	var damage_result := damaged.get_completion_result()
	check(damage_result["compensation_cost"] == 300 and damage_result["successful_employee_ids"].has("grog"), "Новый ущерб оплачивается, полезная перевозка тоже учитывается")
	check(damaged.action_log.back()["result"]["caused_damage"] and damaged.action_log.back()["employee_id"] == "grog", "Ущерб хранится с виновником")
	var restored := care()
	restored.load_state(damaged.get_state())
	check(restored.world_object == damaged.world_object and restored.action_log == damaged.action_log, "Свойства и журнал точно восстанавливаются")
	var state := root.get_node("GameState")
	state.start_new_game()
	state.skip_tutorial()
	var original := Mirror.new()
	original.world_object.merge({"lunnopuh_state": "caged", "cage_state": "occupied", "cold_aura": false, "portal_open": false}, true)
	state.set_job_repair_state(&"portal_mirror", original.get_state())
	state.world_memory.finalize_job(&"portal_mirror", {}, 1, 540)
	check(state.world_memory.has_consequence(&"lunnopuh_care"), "Свойства пойманного зверька создают последствие")
	state.day = 1
	state._unlock_lunnopuh_care_job_if_due()
	check(not state.is_job_available(&"lunnopuh_care"), "Повторная заявка не возникает в тот же день")
	state.day = 2
	state._unlock_lunnopuh_care_job_if_due()
	check(state.is_job_available(&"lunnopuh_care"), "На следующий день доступна заявка о судьбе")
	state.world_memory.queue_consequence(&"legacy_follow_up", &"escaped_ghost", "portal_mirror_room.portal_mirror", &"portal_mirror", 2, 540, 50, {}, "chain.portal_mirror", "", 1)
	state._unlock_lunnopuh_care_job_if_due()
	check(not state.is_job_available(&"lunnopuh_care"), "Привидение блокирует одновременное обращение в комнате")
	state.completed_job_ids.append("escaped_ghost")
	state.job_reports.append({"job_id": "escaped_ghost", "completed_day": 2})
	state.world_memory.set_consequence_status(&"escaped_ghost", "resolved")
	state._unlock_lunnopuh_care_job_if_due()
	check(not state.is_job_available(&"lunnopuh_care"), "После призрака Селеста обращается на следующий день")
	state.day = 3
	for id: StringName in [&"boris", &"grog", &"nika"]:
		state.employees[id]["available"] = false
	state._unlock_lunnopuh_care_job_if_due()
	check(not state.is_job_available(&"lunnopuh_care"), "Без решающего сотрудника заявка ожидает")
	state.employees[&"grog"]["available"] = true
	state.world_memory.get_or_create_relation("Госпожа Селеста", "grog")["access_status"] = "banned"
	state._unlock_lunnopuh_care_job_if_due()
	check(not state.is_job_available(&"lunnopuh_care"), "Запрет на вход учитывается при решаемости")
	state.world_memory.get_or_create_relation("Госпожа Селеста", "grog")["access_status"] = "allowed"
	state._unlock_lunnopuh_care_job_if_due()
	check(state.is_job_available(&"lunnopuh_care"), "Доступный Грог обеспечивает исход в приют")
	state.world_memory.reset()
	var returned := Mirror.new()
	returned.world_object.merge({"lunnopuh_state": "returned", "cage_state": "packed"}, true)
	state.world_memory.record_job_state(&"portal_mirror", returned.get_state(), 1, 540)
	state.world_memory.finalize_job(&"portal_mirror", {}, 1, 540)
	check(not state.world_memory.has_consequence(&"lunnopuh_care"), "Вернувшийся домой зверёк не создаёт обращение")
	state.start_new_game()
	state.skip_tutorial()
	original = Mirror.new()
	original.world_object.merge({"lunnopuh_state": "caged", "cage_state": "occupied", "cold_aura": false, "portal_open": false}, true)
	state.world_memory.record_job_state(&"portal_mirror", original.get_state(), 1, 540)
	state.completed_job_ids.append("portal_mirror")
	state.job_reports.append({"job_id": "portal_mirror", "completed_day": 1, "actions": [], "summary": "Лунопух остался в клетке."})
	state.day = 2
	state._save_to_path("user://care_legacy.json")
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://care_legacy.json"))
	legacy["version"] = 32
	legacy["world_memory"]["deferred_events"] = []
	legacy["job_progress"].erase("lunnopuh_care")
	var legacy_file := FileAccess.open("user://care_legacy.json", FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(legacy))
	legacy_file.close()
	check(state._load_from_path("user://care_legacy.json") == OK and state.is_job_available(&"lunnopuh_care"), "Сохранение версии 32 получает обращение о реально оставшемся зверьке")
	var care_events := 0
	for event: Dictionary in state.world_memory.deferred_events:
		if event["event_type"] == "lunnopuh_care":
			care_events += 1
	state._unlock_lunnopuh_care_job_if_due()
	check(care_events == 1 and state.world_memory.deferred_events.size() == care_events, "Повторная миграция не дублирует обращение")
	state.start_new_game()
	state.skip_tutorial()
	sim = care(false)
	sim.world_object["resident_intro_seen"] = true
	set_visit(state, sim, &"boris")
	var room := (load("res://scenes/LunnopuhCareRoom.tscn") as PackedScene).instantiate()
	root.add_child(room)
	await process_frame
	check(room.cage.visible and not room.cage.get_node("InteractionButton").disabled, "Клетка на столике стала действующей целью")
	room._select_pet()
	var labels: Array[String] = []
	for button: Button in room.tool_bar.temporary_buttons:
		labels.append(button.text)
	check(not labels.has("Отвезти в приют"), "Меню Бориса сначала даёт осмотр")
	room.simulation.apply_lunnopuh_action(&"boris", &"diagnose")
	state.set_job_repair_state(&"lunnopuh_care", room.simulation.get_state())
	room._select_pet()
	labels.clear()
	for button: Button in room.tool_bar.temporary_buttons:
		labels.append(button.text)
	check(labels.has("Отвезти в приют"), "После осмотра появляется перевозка")
	var original_abilities: PackedStringArray = state.employees[&"boris"]["abilities"].duplicate()
	state.employees[&"boris"]["abilities"].append("antimagic")
	room._select_pet()
	check(room.tool_bar.get_node("%AntimagicButton").visible and room.tool_bar.get_node("%AntimagicButton").text == "Применить антимагию", "Изученная антимагия на зверьке имеет общее название")
	room._on_tool_selected(&"antimagic")
	check(room.repair_hud.employee_reaction_label.text == Care.CARE.base_properties["closed_antimagic_refusal"] and not room.action_in_progress, "Борис с антимагией произносит согласованный отказ без действия")
	state.employees[&"boris"]["abilities"] = original_abilities

	room._begin_action(&"transport_lunnopuh")
	await create_timer(0.6).timeout
	check(room.simulation.world_object["lunnopuh_state"] == "caged", "Подход не меняет судьбу зверька раньше времени")
	await create_timer(3.2).timeout
	check(room.simulation.world_object["lunnopuh_state"] == "transferred" and not room.cage.visible and room.simulation.is_resolved(), "Борис исчезает с клеткой после подхвата")
	check(not room.employee_actor.visible and not state.can_employee_work_on_job(&"boris", &"lunnopuh_care") and room.repair_hud.employee_buttons[&"boris"].disabled, "Уехавший Борис скрыт, карточка заблокирована")
	check(int(state.employees[&"boris"]["return_until"]) == state.time_minutes + 2 * state.TRAVEL_TIME_MINUTES, "Возвращение в офис назначено после доставки")
	room.queue_free()
	await process_frame
	sim = care(false)
	sim.world_object["resident_intro_seen"] = true
	set_visit(state, sim, &"grog")
	room = (load("res://scenes/LunnopuhCareRoom.tscn") as PackedScene).instantiate()
	root.add_child(room)
	await process_frame
	room._select_pet()
	room._begin_action(&"transport_lunnopuh")
	await create_timer(0.6).timeout
	check(room.action_in_progress and room.simulation.world_object["lunnopuh_state"] == "caged", "До подхвата клетка ещё не считается переданной")
	check(state._save_to_path("user://care_transport.json") == OK, "Незавершённый вынос сохраняется")
	room.queue_free()
	await process_frame
	check(state._load_from_path("user://care_transport.json") == OK, "Загрузка незавершённого выноса")
	room = (load("res://scenes/LunnopuhCareRoom.tscn") as PackedScene).instantiate()
	root.add_child(room)
	await create_timer(4.0).timeout
	check(room.simulation.world_object["lunnopuh_state"] == "transferred" and room.simulation.action_log.size() == 1 and not room.action_in_progress, "Грог после загрузки завершает перевозку один раз")
	check(not room.employee_actor.visible and not state.can_employee_work_on_job(&"grog", &"lunnopuh_care"), "Уехавший Грог не появляется после загрузки")
	var delivery_return: int = state.employees[&"grog"]["return_until"]
	check(state.complete_active_job(room.simulation.get_completion_result()) and int(state.employees[&"grog"]["return_until"]) == delivery_return, "Завершение заявки сохраняет время возвращения перевозчика")
	state.start_new_game()
	state.skip_tutorial()
	room.queue_free()
	await process_frame
	sim = care()
	sim.world_object["resident_intro_seen"] = true
	set_visit(state, sim, &"nika")
	room = (load("res://scenes/LunnopuhCareRoom.tscn") as PackedScene).instantiate()
	root.add_child(room)
	await process_frame
	room._select_pet()
	room._begin_action(&"return_lunnopuh")
	await create_timer(1.0).timeout
	check(room.transfer_in_progress and room.employee_actor.work_pose.visible and room.simulation.world_object["lunnopuh_state"] == "caged", "Ника сопровождает полёт, состояние меняется после исчезновения")
	check(state._save_to_path("user://care_flight.json") == OK, "Полёт сохранён в отдельном тестовом профиле")
	room.queue_free()
	await process_frame
	check(state._load_from_path("user://care_flight.json") == OK, "Сохранение новой заявки загружается")
	room = (load("res://scenes/LunnopuhCareRoom.tscn") as PackedScene).instantiate()
	root.add_child(room)
	await create_timer(3.4).timeout
	check(room.simulation.world_object["lunnopuh_state"] == "returned" and room.simulation.action_log.size() == 1 and not room.action_in_progress, "Загрузка возобновляет полёт и применяет его один раз")
	room.simulation.apply_action(&"felix", &"antimagic")
	state.set_job_repair_state(&"lunnopuh_care", room.simulation.get_state())
	check(state.complete_active_job(room.simulation.get_completion_result()), "Заявка завершается через общий акт")
	check(state.owned_supply_items.has("lunnopuh_cage") and state.job_reports.back()["expense_reimbursement"] == 0 and state.completed_job_ids.has("lunnopuh_care"), "Клетка возвращается на склад без повторной оплаты")
	room.queue_free()
	await process_frame
	print("LUNNOPUH CARE: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
