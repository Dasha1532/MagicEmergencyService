extends SceneTree

const Generator := preload("res://scripts/generated_job_generator.gd")
const Mirror := preload("res://scripts/portal_mirror_simulation.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
	else:
		print("PASS: ", label)

func context(abilities: PackedStringArray, staff: PackedStringArray, money: int, owned: PackedStringArray = PackedStringArray()) -> Dictionary:
	return {"client_capabilities": {"Госпожа Селеста": abilities}, "admitted_employees": {"Госпожа Селеста": staff}, "money": money, "owned_items": owned, "item_prices": {"protective_cloth": 50, "lunnopuh_cage": 250}}

func run() -> void:
	if not "MirrorTests" in OS.get_user_data_dir():
		quit(1)
		return
	var boris := PackedStringArray(["diagnose", "repair"])
	check(not Generator.generate_mirror(1, boris, context(boris, PackedStringArray(["boris"]), 50)).is_empty(), "Борис и деньги на полотно дают безопасное решение")
	check(Generator.generate_mirror(1, boris, context(boris, PackedStringArray(), 300)).is_empty(), "Запрещённый Борис не даёт безопасный план")
	check(Generator.generate_mirror(1, boris, context(boris, PackedStringArray(["boris"]), 49)).is_empty(), "Без денег на нужное снаряжение заявка не публикуется")
	check(not Generator.generate_mirror(1, boris, context(boris, PackedStringArray(["boris"]), 0, PackedStringArray(["protective_cloth"]))).is_empty(), "Купленное полотно не требует повторной оплаты")
	check(Generator.generate_mirror(1, PackedStringArray(["antimagic"]), context(PackedStringArray(), PackedStringArray(), 600)).is_empty(), "Глобальные умения не обходят запрет Селесты")
	var all_abilities := PackedStringArray(["diagnose", "repair", "telekinesis", "antimagic"])
	var all_context := context(all_abilities, PackedStringArray(["boris", "nika", "felix"]), 600)
	var seen := PackedStringArray()
	for seed_value: int in range(80):
		var generated := Generator.generate_mirror(seed_value, all_abilities, all_context)
		var anomaly_id := str(generated.get("anomaly_id", ""))
		if not seen.has(anomaly_id):
			seen.append(anomaly_id)
	check(seen.size() == 3, "Случайная генерация достигает всех трёх вариантов")
	for previous: String in seen:
		var generated := Generator.generate_mirror(17, all_abilities, all_context, PackedStringArray([previous]))
		check(str(generated["anomaly_id"]) != previous, "Предыдущий вариант исключается при наличии альтернатив: " + previous)
	var no_nika := context(all_abilities, PackedStringArray(["boris", "felix"]), 600)
	for seed_value: int in range(12):
		check(str(Generator.generate_mirror(seed_value, all_abilities, no_nika)["anomaly_id"]) != "escaped_lunnopuh", "Заявка со зверьком не генерируется без допущенной Ники")
	var beast := preload("res://data/anomalies/escaped_lunnopuh.tres")
	for creature_outcome: String in ["caged", "returned"]:
		var report_sim := Mirror.new()
		report_sim.world_object["portal_open"] = false
		report_sim.world_object["cold_aura"] = false
		report_sim.world_object["lunnopuh_state"] = creature_outcome
		var report: Dictionary = report_sim.get_completion_result()
		check(not "до следующего обращения" in str(report["summary"]), "Акт не обещает новую заявку")
		check(("новому питомцу" if creature_outcome == "caged" else "теперь он дома") in str(report["review"]), "Отзыв учитывает судьбу зверька: " + creature_outcome)

	var chase := Mirror.new()
	chase.world_object["lunnopuh_state"] = "free"
	chase.world_object["lunnopuh_inspected"] = true
	chase.world_object["cage_state"] = "installed"
	check(chase.lunnopuh_actions(&"grog").has("catch_into_cage"), "Грог может попытаться загнать зверька в клетку")
	chase.escape_lunnopuh()
	var escaped_position := float(chase.world_object["lunnopuh_offset_x"])
	var restored_chase := Mirror.new()
	restored_chase.load_state(JSON.parse_string(JSON.stringify(chase.get_state())))
	check(not restored_chase.apply_lunnopuh_action(&"grog", &"catch_into_cage")["applied"], "Грог не ловит зверька в клетку")
	check(float(restored_chase.world_object["lunnopuh_offset_x"]) == escaped_position, "Загрузка во время побега не перемещает зверька повторно")
	check(restored_chase.world_object["lunnopuh_state"] == "free", "После попытки зверёк остаётся свободным")
	check("Опять убежал" in restored_chase.lunnopuh_reaction(&"catch_into_cage", true, &"grog"), "Неудача Грога использует его утверждённую реплику")
	for ability: StringName in [&"animate", &"antimagic"]:
		check(not restored_chase.lunnopuh_refusal(ability).is_empty(), "Отказ зверька по умению: " + String(ability))

	var creature_sim := Mirror.new()
	var creature_initial := beast.initial_state.duplicate(true)
	creature_initial["generated_resolution"] = beast.resolution.duplicate(true)
	creature_sim.initialize_from_job({"generated_instance": {"initial_state": creature_initial}})
	check(not creature_sim.is_resolved(), "Свободный лунопух и открытый портал не завершают заявку")
	creature_sim.apply_lunnopuh_action(&"boris", &"diagnose")
	check(not creature_sim.apply_lunnopuh_action(&"boris", &"catch_hand")["applied"], "Борис не ловит свободного зверька")
	check(not creature_sim.lunnopuh_actions(&"boris").has("catch_lunnopuh"), "Телекинетическая поимка недоступна Борису")
	check(not creature_sim.apply_lunnopuh_action(&"nika", &"catch_lunnopuh")["applied"], "Без установленной клетки поимка невозможна")
	creature_sim.install_cage(&"boris", true)
	creature_sim.apply_action(&"felix", &"antimagic")
	check(not creature_sim.is_resolved(), "Закрытый портал не завершает заявку со свободным зверьком")
	check(not creature_sim.apply_lunnopuh_action(&"nika", &"return_lunnopuh")["applied"], "Зверька нельзя вернуть в закрытый портал")
	check(creature_sim.apply_lunnopuh_action(&"nika", &"catch_lunnopuh")["applied"], "Ника ловит зверька после закрытия портала")
	check(creature_sim.is_resolved(), "Закрытый портал и зверёк в клетке завершают заявку")
	check(creature_sim.get_completion_result()["successful_employee_ids"].has("nika"), "Полезная поимка Ники учитывается в акте")
	var saved_creature := Mirror.new()
	saved_creature.load_state(JSON.parse_string(JSON.stringify(creature_sim.get_state())))
	check(saved_creature.world_object["lunnopuh_state"] == "caged" and saved_creature.is_resolved(), "Поимка и завершение сохраняются при загрузке")
	var returned := Mirror.new()
	returned.initialize_from_job({"generated_instance": {"initial_state": creature_initial}})
	check(returned.apply_lunnopuh_action(&"nika", &"return_lunnopuh")["applied"], "Ника направляет свободного лунопуха в портал")
	check(not returned.is_resolved(), "После возвращения зверька портал ещё нужно закрыть")
	returned.apply_action(&"felix", &"antimagic")
	check(returned.is_resolved(), "Возвращение и закрытие завершают заявку")
	check(not returned.get_completion_result().has("follow_up"), "Возвращённый зверёк не создаёт повторного обращения")
	var isolated := Mirror.new()
	isolated.initialize_from_job({"generated_instance": {"initial_state": creature_initial}})
	isolated.apply_lunnopuh_action(&"boris", &"diagnose")
	isolated.install_cage(&"boris", true)
	isolated.apply_lunnopuh_action(&"nika", &"catch_lunnopuh")
	isolated.apply_action(&"boris", &"diagnose")
	isolated.apply_action(&"boris", &"cover", true)
	check(isolated.is_resolved() and isolated.get_completion_result()["follow_up"]["type"] == "escaped_ghost", "Клетка и полотно сохраняют существующее последствие с призраком")
	check(not "Холод устранён" in str(isolated.get_completion_result()["summary"]), "Акт тёплой заявки не приписывает несуществующее устранение холода")
	check(isolated.get_completion_result()["follow_up"]["lunnopuh_state"] == "caged", "Пойманный зверёк переносится в последствие")
	var ghost := preload("res://scripts/ghost_followup_simulation.gd").new()
	ghost.apply_source_follow_up(isolated.get_completion_result()["follow_up"])
	check(ghost.world_object["lunnopuh_state"] == "caged", "Призрак не удаляет пойманного зверька")
	var ghost_copy := preload("res://scripts/ghost_followup_simulation.gd").new()
	ghost_copy.load_state(JSON.parse_string(JSON.stringify(ghost.get_state())))
	check(ghost_copy.world_object["lunnopuh_state"] == "caged", "Клетка в последствии восстанавливается")
	var destroyed := Mirror.new()
	destroyed.initialize_from_job({"generated_instance": {"initial_state": creature_initial}})
	destroyed.install_cage(&"boris", true)
	destroyed.apply_lunnopuh_action(&"nika", &"catch_lunnopuh")
	destroyed.apply_action(&"grog", &"physical_move")
	var damage_result := destroyed.get_completion_result()
	check(damage_result.get("forfeit_payment", false) and damage_result["compensation_cost"] == 300, "Поимка не отменяет ущерб и компенсацию за зеркало")
	check(damage_result["successful_employee_ids"].has("nika") and not damage_result["successful_employee_ids"].has("grog"), "Полезная работа и виновник ущерба учитываются раздельно")
	var memory := preload("res://scripts/world_memory.gd").new()
	memory.evaluate_crew_relations({"resident_id": "Госпожа Селеста", "job_id": "portal_mirror", "crew_ids": ["nika", "grog"], "rating": 1, "payment_forfeited": true, "claim_amount": 300, "object_destroyed": true, "damage_employee_ids": ["grog"], "successful_employee_ids": damage_result["successful_employee_ids"], "credit_helpful_work_on_damage": damage_result["credit_helpful_work_on_damage"]})
	check(memory.get_relation("Госпожа Селеста", "nika").get("professional_trust", 0) > 0 and memory.get_relation("Госпожа Селеста", "grog")["access_status"] == "banned", "Полезная работа Ники улучшает отношения даже при ущербе другого сотрудника")
	var required_crew := PackedStringArray(["telekinesis", "diagnose", "repair"])
	var plans := Generator.find_safe_plans({"anomaly_id": "escaped_lunnopuh", "resident_id": "Госпожа Селеста"}, required_crew, context(required_crew, PackedStringArray(["boris", "nika"]), 299))
	check(plans.filter(func(plan: Dictionary) -> bool: return plan["family"] == &"capture_and_cover").is_empty(), "План клетки и полотна проверяет общую стоимость 300 монет")
	plans = Generator.find_safe_plans({"anomaly_id": "escaped_lunnopuh", "resident_id": "Госпожа Селеста"}, required_crew, context(required_crew, PackedStringArray(["boris", "nika"]), 300))
	check(not plans.filter(func(plan: Dictionary) -> bool: return plan["family"] == &"capture_and_cover").is_empty(), "Оба предмета доступны при достаточной общей сумме")
	var state := root.get_node("GameState")
	state.start_new_game()
	state.debug_tutorial_bypass_day = 1
	state.advance_day()
	check(state.jobs[&"portal_mirror"].get("generated", false) and state.jobs[&"portal_mirror"]["unlocked"], "Игровое расписание публикует сгенерированное зеркало")
	var instance: Dictionary = state.generated_jobs["portal_mirror"].duplicate(true)
	state.save_game(1)
	check(state.load_game(1) == OK, "Загрузка сгенерированной заявки успешна")
	check(JSON.parse_string(JSON.stringify(state.generated_jobs["portal_mirror"])) == JSON.parse_string(JSON.stringify(instance)), "Загрузка не перебрасывает вариант заявки")
	var sim := Mirror.new()
	sim.initialize_from_job(state.jobs[&"portal_mirror"])
	sim.apply_action(&"boris", &"diagnose")
	sim.apply_action(&"boris", &"cover", true)
	check(sim.is_resolved(), "Сгенерированное зеркало решается согласованным способом")
	var legacy: Dictionary = state.legacy_mirror_job.duplicate(true)
	state._remove_generated_job_entries()
	state.generated_jobs.erase("portal_mirror")
	state.jobs[&"portal_mirror"] = legacy
	state.jobs[&"portal_mirror"]["unlocked"] = true
	state.set_job_repair_state(&"portal_mirror", sim.get_state())
	state.save_game(2)
	check(state.load_game(2) == OK and not state.jobs[&"portal_mirror"].get("generated", false), "Опубликованная старая заявка не заменяется случайным вариантом")
	check(state.get_job_repair_state(&"portal_mirror")["world_object"]["covered"], "Старая заявка сохраняет выполненную работу")
	state.start_new_game()
	state.debug_next_mirror_anomaly = &"escaped_lunnopuh"
	state.debug_tutorial_bypass_day = 1
	state.advance_day()
	check(not state.jobs[&"portal_mirror"]["unlocked"], "Тестовый выбор зверька не обходит отсутствие Ники")
	state.money = 1000
	state.hire_employee(&"nika")
	state.advance_day()
	check(state.jobs[&"portal_mirror"]["unlocked"] and state.generated_jobs["portal_mirror"]["anomaly_id"] == "escaped_lunnopuh", "После найма Ники публикуется выбранная заявка со зверьком")
	var pet_instance: Dictionary = state.generated_jobs["portal_mirror"].duplicate(true)
	state.save_game(3)
	check(state.load_game(3) == OK and state.generated_jobs["portal_mirror"]["anomaly_id"] == pet_instance["anomaly_id"], "Загрузка сохраняет вариант со зверьком")
	state.start_new_game()
	state.employees[&"nika"]["available"] = true
	state.debug_next_mirror_anomaly = &"escaped_lunnopuh"
	state.debug_tutorial_bypass_day = 1
	state.world_memory.get_or_create_relation("Госпожа Селеста", "nika")["access_status"] = "banned"
	state.advance_day()
	check(not state.jobs[&"portal_mirror"]["unlocked"], "Старый запрет Селесты не теряется при генерации")
	check(not Generator.generate(1, PackedStringArray(["freeze", "heat", "physical_move", "diagnose", "repair"]), PackedStringArray(), {"money": -20}).is_empty(), "Новый учёт снаряжения не блокирует бесплатные планы шкафа")
	var snapshot := sim.get_state()
	check(snapshot["related_objects"].has("portal_mirror_room.lunnopuh"), "Сохранение содержит самостоятельное состояние зверька")
	var title := (load("res://scenes/TitleScreen.tscn") as PackedScene).instantiate()
	root.add_child(title)
	await process_frame
	title.get_node("DebugMirrorButton").pressed.emit()
	check(title.debug_mirror_picker != null and title.debug_wardrobe_picker == null, "Кнопка проверки зеркала открывает собственный выбор")
	title.debug_mirror_picker.item_selected.emit(3)
	check(state.debug_next_mirror_anomaly == &"escaped_lunnopuh", "Выбор лунопуха передаётся генератору новой игры")
	for pet_outcome: String in ["caged", "returned"]:
		state.start_new_game()
		state.active_job_id = &"portal_mirror"
		state.jobs[&"portal_mirror"]["assigned"] = PackedStringArray()
		state.owned_supply_items.append("lunnopuh_cage")
		var settlement := Mirror.new()
		settlement.world_object["portal_open"] = false
		settlement.world_object["cold_aura"] = false
		settlement.world_object["lunnopuh_state"] = pet_outcome
		settlement.world_object["cage_state"] = "occupied" if pet_outcome == "caged" else "installed"
		state.set_job_repair_state(&"portal_mirror", settlement.get_state())
		var settlement_result := settlement.get_completion_result()
		check(int(settlement_result.get("expense_reimbursement", 0)) == (250 if pet_outcome == "caged" else 0), "Стоимость клетки возмещается только с оставленным зверьком: " + pet_outcome)
		check(state.complete_active_job(settlement_result), "Заявка завершается с исходом: " + pet_outcome)
		check(state.has_supply_item(&"lunnopuh_cage") == (pet_outcome == "returned"), "Склад учитывает передачу или возврат клетки: " + pet_outcome)
		check(state.world_memory.objects["portal_mirror_room.lunnopuh_cage"]["properties"]["state"] == ("occupied" if pet_outcome == "caged" else "packed"), "Завершение сохраняет конечное расположение клетки")
		state.save_game(3)
		check(state.load_game(3) == OK and state.has_supply_item(&"lunnopuh_cage") == (pet_outcome == "returned"), "Склад восстанавливается после загрузки: " + pet_outcome)
	title.queue_free()
	await process_frame
	print("GENERATED MIRROR: ", "PASS" if failures == 0 else "FAIL", " (", failures, ")")
	quit(0 if failures == 0 else 1)
