extends SceneTree

const Generator := preload("res://scripts/generated_job_generator.gd")
const RepairSimulationScript := preload("res://scripts/repair_simulation.gd")

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	_check(game_state.SUPPLY_ITEMS.has(&"heat_gloves"), "Рукавицы добавлены в лавку")
	_check(int(game_state.SUPPLY_ITEMS[&"heat_gloves"]["price"]) == 120, "Цена рукавиц — 120 монет")
	_check(game_state.SUPPLY_ITEMS.has(&"replacement_faucet"), "Запасной кран добавлен в лавку")
	_check(int(game_state.SUPPLY_ITEMS[&"replacement_faucet"]["price"]) == 250, "Цена запасного крана — 250 монет")
	_check(str(game_state.SUPPLY_ITEMS[&"thermal_regulator"].get("solution_capability", "")) == "thermal_regulator", "Терморегулятор объявляет генератору свою способность")
	var regulator_profile: Dictionary = load("res://data/objects/thermal_regulator.tres").base_properties
	_check(PackedStringArray(regulator_profile.get("neutralizes_source_properties", PackedStringArray())).has("lava_source_active"), "Профиль терморегулятора задаёт нейтрализуемые свойства")
	_check(PackedStringArray(regulator_profile.get("forbidden_target_tags", PackedStringArray())).has("melted"), "Свойства терморегулятора запрещают установку на уничтоженный объект")
	var regulated_lava := RepairSimulationScript.new()
	regulated_lava.world_object["thermal_regulator_available"] = true
	_check(not regulated_lava.can_employee_start_action(&"install_thermal_regulator", game_state.employees[&"boris"]), "Без защиты действие Бориса скрывается до запуска рабочей позы")
	_check(not regulated_lava.can_begin_action(&"install_thermal_regulator", game_state.employees[&"boris"]), "Отказ Бориса блокирует движение и анимацию действия")
	var unprotected_regulator_result: Dictionary = regulated_lava.apply_action(&"boris", &"install_thermal_regulator")
	_check(not bool(unprotected_regulator_result["applied"]) and bool(regulated_lava.world_object["lava_source_active"]), "Борис не устанавливает регулятор на раскалённый кран без рукавиц")
	var regulator_refusal := regulated_lava.get_employee_reaction(&"boris", &"install_thermal_regulator")
	_check(not regulator_refusal.is_empty() and not regulator_refusal.contains("установлен") and not regulator_refusal.contains("Готово"), "До действия Борис говорит о намерении или условии, а не о выполненной работе")
	var regulated_lava_result: Dictionary = regulated_lava.apply_action(&"boris", &"install_thermal_regulator", {"protections": PackedStringArray(["contact_heat"])})
	_check(bool(regulated_lava_result["applied"]) and not bool(regulated_lava.world_object["lava_source_active"]), "Терморегулятор отключает лавовый источник по свойству")
	_check(StringName(str(regulated_lava_result.get("consume_item_id", ""))) == &"thermal_regulator" and bool(regulated_lava.world_object["regulator_installed"]), "Установленный прибор покидает склад и остаётся на объекте")
	_check(not str(regulated_lava_result.get("employee_result", "")).is_empty(), "После установки выбирается отдельная реплика результата")
	_check(StringName(str(regulated_lava.world_object["flow_content"])) == &"water" and not PackedStringArray(regulated_lava.world_object["tags"]).has("lava_flowing"), "После стабилизации лавовый поток становится обычной водой")
	_check(bool(regulated_lava.world_object["function_test_passed"]) and regulated_lava.is_resolved(), "Игра автоматически проверяет исправность и только после этого разрешает завершение")
	_check(int(regulated_lava.get_completion_result()["expense_reimbursement"]) == 280, "Стоимость оставленного на объекте терморегулятора возмещается")
	var faucet_scene := load("res://scenes/RepairHouse.tscn") as PackedScene
	var faucet_scene_instance := faucet_scene.instantiate()
	_check(faucet_scene_instance.get_node_or_null("InteractiveObjects/LavaFaucet/RegulatedFaucet") != null, "Ассет крана с установленным терморегулятором подключён отдельным редактируемым узлом")
	faucet_scene_instance.free()
	var regulated_cold := RepairSimulationScript.new()
	regulated_cold.world_object.merge({"thermal_regulator_available": true, "cold_source_active": true, "lava_source_active": false, "frozen": true, "valve_frozen": true, "flow_blocked": true, "temperature": -3, "tags": PackedStringArray(["faucet", "frozen"])}, true)
	var regulated_cold_result: Dictionary = regulated_cold.apply_action(&"boris", &"install_thermal_regulator")
	_check(bool(regulated_cold_result["applied"]) and not bool(regulated_cold.world_object["cold_source_active"]) and not bool(regulated_cold.world_object["frozen"]), "Тот же профиль стабилизирует холодный источник по свойствам")
	var residual_frost := RepairSimulationScript.new()
	residual_frost.world_object.merge({"thermal_regulator_available": true, "cold_source_active": false, "lava_source_active": false, "frozen": true, "valve_frozen": true, "flow_blocked": true, "temperature": -5, "tags": PackedStringArray(["faucet", "frozen"])}, true)
	_check(residual_frost.can_install_temperature_regulator(), "Терморегулятор доступен для замороженного крана даже после исчезновения источника холода")
	var residual_frost_result: Dictionary = residual_frost.apply_action(&"boris", &"install_thermal_regulator")
	_check(bool(residual_frost_result["applied"]) and not bool(residual_frost.world_object["frozen"]) and int(residual_frost.world_object["temperature"]) == 2, "Прибор оттаивает остаточно замороженный кран по его свойствам")

	var examples: Dictionary = {}
	for seed_value: int in range(200):
		var instance := Generator.generate_tutorial_faucet(seed_value, PackedStringArray(["freeze", "heat", "diagnose", "repair", "thermal_regulator", "contact_heat"]))
		if not instance.is_empty():
			examples[str(instance["anomaly_id"])] = instance
		if examples.size() == 3:
			break

	var lava := RepairSimulationScript.new()
	lava.initialize_from_job(Generator.materialize_job(examples["lava_leak"]))
	var lava_tags := PackedStringArray(lava.world_object["tags"])
	_check(int(lava.world_object["temperature"]) >= 10 and lava_tags.has("overheated"), "Кран с лавой сразу имеет раскалённое состояние")
	var boris_lava_valve := lava.apply_action(&"boris", &"turn_valve", game_state.employees[&"boris"])
	_check(not bool(boris_lava_valve["applied"]) and (lava.world_object["tags"] as PackedStringArray).has("lava_flowing"), "Борис без экипированных рукавиц не касается раскалённого лавового крана")
	var grog_data: Dictionary = game_state.employees[&"grog"]
	var grog_closes_lava := lava.apply_action(&"grog", &"turn_valve", grog_data)
	_check(bool(grog_closes_lava["applied"]) and not (lava.world_object["tags"] as PackedStringArray).has("lava_flowing"), "Грог с собственной защитой закрывает лавовый вентиль")
	_check(not lava.is_resolved(), "Закрытый вентиль не устраняет активный лавовый источник")
	var grog_reopens_lava := lava.apply_action(&"grog", &"turn_valve", grog_data)
	_check(bool(grog_reopens_lava["applied"]) and (lava.world_object["tags"] as PackedStringArray).has("lava_flowing"), "При повторном открытии лавовый поток возобновляется")
	lava.apply_action(&"liliya", &"freeze")
	_check(not lava.is_resolved() and bool(lava.world_object["frozen_lava_flow"]) and bool(lava.world_object["lava_source_active"]), "Заморозка создаёт пробку, но не устраняет лавовый источник")

	var frozen := RepairSimulationScript.new()
	frozen.initialize_from_job(Generator.materialize_job(examples["faucet_freeze"]))
	var initial_frozen_diagnosis := str(frozen.apply_action(&"boris", &"diagnose")["message"]).to_lower()
	_check("опасность не устранена" in initial_frozen_diagnosis and "источник магического холода" in initial_frozen_diagnosis, "Осмотр целого замороженного крана видит активную магическую опасность")
	var frozen_valve := frozen.apply_action(&"nika", &"telekinesis")
	_check(not bool(frozen_valve["applied"]) and bool(frozen.world_object["frozen"]), "Телекинез не поворачивает промёрзший вентиль")
	frozen.apply_action(&"liliya", &"heat")
	var opened_water := frozen.apply_action(&"nika", &"telekinesis")
	_check(bool(opened_water["applied"]) and StringName(str(frozen.world_object["valve_position"])) == &"open" and StringName(str(frozen.world_object["flow_content"])) == &"water", "После оттаивания Ника открывает воду")
	var closed_by_boris := frozen.apply_action(&"boris", &"turn_valve")
	_check(bool(closed_by_boris["applied"]) and StringName(str(frozen.world_object["valve_position"])) == &"closed", "Борис закрывает открытый вентиль")
	var not_reopened_by_boris := frozen.apply_action(&"boris", &"turn_valve")
	_check(bool(not_reopened_by_boris["applied"]) and StringName(str(frozen.world_object["valve_position"])) == &"open", "После устранения аномалии Борис открывает исправный кран для проверки воды")

	var broken_frozen := RepairSimulationScript.new()
	broken_frozen.initialize_from_job(Generator.materialize_job(examples["faucet_freeze"]))
	broken_frozen.apply_action(&"grog", &"brute_force", game_state.employees[&"grog"])
	_check(bool(broken_frozen.world_object["broken"]) and bool(broken_frozen.world_object["frozen"]) and bool(broken_frozen.world_object["cold_leak"]), "Сломанный замороженный кран сохраняет холод и получает утечку холода")
	_check(not broken_frozen.is_resolved(), "Сломанный кран нельзя сдать как выполненную заявку")
	var status_scene := load("res://scenes/ObjectStatusEffects.tscn") as PackedScene
	var status_effects := status_scene.instantiate()
	root.add_child(status_effects)
	status_effects.sync_from_state(broken_frozen.world_object)
	_check((status_effects.get_node("Frost") as Sprite2D).visible, "Поверх сломанного крана виден иней, пока холод не устранён")
	status_effects.queue_free()
	var broken_diagnosis := str(broken_frozen.apply_action(&"boris", &"diagnose")["message"]).to_lower()
	_check("сломан" in broken_diagnosis and "холод" in broken_diagnosis and "перегрев" not in broken_diagnosis, "Осмотр описывает поломку и холод, а не перегрев")
	broken_frozen.world_object["replacement_faucet_available"] = true
	var cold_replacement := broken_frozen.apply_action(&"boris", &"replace_faucet")
	_check(not broken_frozen.can_begin_action(&"replace_faucet", game_state.employees[&"boris"]) and not bool(cold_replacement["applied"]) and "Сначала устраните источник холода" in str(cold_replacement["message"]), "Активный холод блокирует подход Бориса и сразу объясняет условие замены")
	broken_frozen.apply_action(&"liliya", &"heat")
	_check(not bool(broken_frozen.world_object["frozen"]) and not bool(broken_frozen.world_object["cold_source_active"]) and not bool(broken_frozen.world_object["cold_leak"]), "Устранение холода сохраняет поломку, но убирает холодный источник и иней")
	cold_replacement = broken_frozen.apply_action(&"boris", &"replace_faucet")
	_check(bool(cold_replacement["applied"]) and StringName(str(broken_frozen.world_object["flow_content"])) == &"water" and int(broken_frozen.world_object["magic_level"]) == 0, "После устранения холода замена создаёт новый безопасный кран с обычной водой")
	var tested_water := broken_frozen.apply_action(&"boris", &"turn_valve")
	_check(bool(tested_water["applied"]) and StringName(str(broken_frozen.world_object["valve_position"])) == &"open", "Борис открывает новый кран и проверяет воду")

	var hot := RepairSimulationScript.new()
	hot.initialize_from_job(Generator.materialize_job(examples["faucet_overheat"]))
	_check((grog_data["protections"] as PackedStringArray).has("contact_heat"), "У Грога есть штатная защита от контактного жара")
	var protected_touch := hot.apply_action(&"grog", &"normal_force", grog_data)
	_check(not bool(protected_touch.get("injured", false)), "Грог не обжигается благодаря собственной защите")
	var broken := hot.apply_action(&"grog", &"brute_force", grog_data)
	_check(bool(broken["applied"]) and bool(hot.world_object["broken"]) and not bool(broken.get("injured", false)), "Грог ломает раскалённый кран без ожога")
	hot.apply_action(&"liliya", &"freeze")
	hot.world_object["replacement_faucet_available"] = true
	var replaced := hot.apply_action(&"boris", &"replace_faucet")
	_check(bool(replaced["applied"]) and StringName(str(replaced.get("consume_item_id", ""))) == &"replacement_faucet" and not bool(hot.world_object["broken"]), "Борис устанавливает и расходует запасной кран")

	var boris_hot := RepairSimulationScript.new()
	boris_hot.initialize_from_job(Generator.materialize_job(examples["faucet_overheat"]))
	boris_hot.world_object["valve_position"] = &"open"
	game_state.return_supply_item(&"heat_gloves")
	_check(game_state.has_supply_item(&"heat_gloves") and game_state.get_equipped_employee(&"heat_gloves").is_empty(), "После покупки рукавицы лежат на складе и ещё никого не защищают")
	var unprotected_boris := boris_hot.apply_action(&"boris", &"turn_valve", game_state.get_employee_with_equipment(&"boris"))
	_check(not bool(unprotected_boris["applied"]), "Без экипированных рукавиц Борис не касается раскалённого вентиля")
	_check(game_state.equip_supply_item(&"heat_gloves", &"boris"), "Рукавицы можно экипировать на Бориса")
	boris_hot.world_object["heat_gloves_available"] = game_state.is_supply_equipped_by(&"heat_gloves", &"boris")
	var protected_boris := boris_hot.apply_action(&"boris", &"turn_valve", game_state.get_employee_with_equipment(&"boris"))
	_check(bool(protected_boris["applied"]) and StringName(str(boris_hot.world_object["valve_position"])) == &"closed", "С купленными рукавицами Борис закрывает раскалённый вентиль")
	_check((game_state.get_employee_with_equipment(&"boris")["protections"] as PackedStringArray).has("contact_heat"), "Экипировка добавляет Борису защиту от контактного жара")
	_check(ResourceLoader.exists("res://assets/characters/employees/boris/heat_gloves_work_pose.png"), "Поза Бориса в рукавицах подключена к проекту")
	var actor_scene := load("res://scenes/EmployeeActor.tscn") as PackedScene
	var actor := actor_scene.instantiate()
	root.add_child(actor)
	_check(actor.configure_employee(&"boris", game_state.get_employee_with_equipment(&"boris")), "Актёр Бориса загружает защищённую рабочую позу")
	_check((actor.get_node("HeatProtectedWorkPose") as TextureRect).texture != null, "Для горячего контакта доступен отдельный ассет Бориса")
	actor.queue_free()
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("FAUCET EQUIPMENT AND ACTIONS SMOKE TEST: PASS")
		quit(0)
	else:
		print("FAUCET EQUIPMENT AND ACTIONS SMOKE TEST: FAIL (%d)" % failures.size())
		quit(1)
