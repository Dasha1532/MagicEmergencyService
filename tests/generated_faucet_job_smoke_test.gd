extends SceneTree

const Generator := preload("res://scripts/generated_job_generator.gd")
const Catalog := preload("res://scripts/generative_job_catalog.gd")
const RepairSimulationScript := preload("res://scripts/repair_simulation.gd")

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var abilities := PackedStringArray(["freeze", "heat", "physical_move", "diagnose", "repair"])
	var compatible := Catalog.compatible_anomalies(&"ragnar_bathroom", &"lava_faucet")
	_check(compatible.size() == 3, "Для учебного крана доступны ровно три подготовленные аномалии")
	var examples: Dictionary = {}
	for seed_value: int in range(200):
		var instance := Generator.generate_tutorial_faucet(seed_value, abilities)
		if not instance.is_empty():
			examples[str(instance["anomaly_id"])] = instance
		if examples.size() == 2:
			break
	_check(not examples.has("lava_leak"), "Лавовая течь не генерируется без полного способа устранить источник")
	_check(examples.has("faucet_overheat"), "Генерируется магический перегрев")
	_check(examples.has("faucet_freeze"), "Генерируется магическое промерзание")
	for initial_instance_value: Variant in examples.values():
		var initial_presentation: Dictionary = (initial_instance_value as Dictionary).get("presentation", {}) as Dictionary
		var initial_text := (str(initial_presentation.get("description", "")) + " " + str(initial_presentation.get("resident_request", ""))).to_lower()
		_check("вчера" not in initial_text and "прошлого обращения" not in initial_text, "Начальная заявка не упоминает предыдущий визит службы")
	var appreciative_follow_up := Generator.generate_faucet_consequence({"event_id": "deferred.test.thanks", "event_type": "faucet_freeze", "payload": {"anomaly_id": "faucet_freeze", "relationship_tone": "appreciative"}}, abilities, {})
	var neutral_follow_up := Generator.generate_faucet_consequence({"event_id": "deferred.test.neutral", "event_type": "faucet_freeze", "payload": {"anomaly_id": "faucet_freeze", "relationship_tone": "neutral"}}, abilities, {})
	_check("Спасибо, что вчера" in str((appreciative_follow_up.get("presentation", {}) as Dictionary).get("resident_request", "")) and "Спасибо" not in str((appreciative_follow_up.get("presentation", {}) as Dictionary).get("description", "")), "Хороший прошлый результат получает благодарность только в реплике жильца")
	_check("После прошлого обращения" in str((neutral_follow_up.get("presentation", {}) as Dictionary).get("resident_request", "")) and "прошлого обращения" not in str((neutral_follow_up.get("presentation", {}) as Dictionary).get("description", "")).to_lower(), "Остальные результаты получают нейтральную связь только в реплике жильца")
	for anomaly_id: String in examples:
		var instance: Dictionary = examples[anomaly_id]
		_check(not (instance.get("validated_safe_plans", []) as Array).is_empty(), "Вариант %s разрешим стартовыми сотрудниками" % anomaly_id)
		var job := Generator.materialize_job(instance)
		var simulation := RepairSimulationScript.new()
		simulation.initialize_from_job(job)
		if anomaly_id == "faucet_freeze":
			simulation.apply_action(&"liliya", &"heat")
		else:
			simulation.apply_action(&"liliya", &"freeze")
		_check(simulation.is_resolved(), "Безопасный план действительно завершает вариант %s" % anomaly_id)
		_check(int(simulation.get_completion_result(Generator.TUTORIAL_FAUCET_JOB_ID).get("reputation_change", 0)) > 0, "Безопасное решение %s даёт положительный результат" % anomaly_id)
	var equipped_capabilities := PackedStringArray(["freeze", "heat", "physical_move", "diagnose", "repair", "thermal_regulator", "contact_heat"])
	var lava_instance: Dictionary = {}
	for seed_value: int in range(200):
		var candidate := Generator.generate_tutorial_faucet(seed_value, equipped_capabilities)
		if str(candidate.get("anomaly_id", "")) == "lava_leak":
			lava_instance = candidate
			break
	_check(not lava_instance.is_empty(), "Лавовая течь доступна при наличии Бориса, терморегулятора и защиты от жара")
	if not lava_instance.is_empty():
		var lava_simulation := RepairSimulationScript.new()
		lava_simulation.initialize_from_job(Generator.materialize_job(lava_instance))
		lava_simulation.world_object["thermal_regulator_available"] = true
		lava_simulation.apply_action(&"boris", &"install_thermal_regulator", {"protections": PackedStringArray(["contact_heat"])})
		_check(lava_simulation.is_resolved(), "Терморегулятор устраняет источник лавы, а не только останавливает поток")
	var frozen_job := Generator.materialize_job(examples["faucet_freeze"])
	var frozen_simulation := RepairSimulationScript.new()
	frozen_simulation.initialize_from_job(frozen_job)
	var frozen_freeze_reaction := frozen_simulation.get_employee_reaction(&"liliya", &"freeze").to_lower()
	var frozen_diagnosis := frozen_simulation.get_employee_reaction(&"boris", &"diagnose").to_lower()
	_check(frozen_freeze_reaction.contains("холод") or frozen_freeze_reaction.contains("заморож") or frozen_freeze_reaction.contains("иней") or frozen_freeze_reaction.contains("зим"), "Повторная заморозка получает реплику о холодном состоянии")
	_check(not frozen_freeze_reaction.contains("лава") and not frozen_diagnosis.contains("лава"), "Реплики замороженного крана не выдумывают лаву")
	_check(bool(frozen_simulation.world_object.get("frozen", false)), "Замороженный визуал определяется свойством frozen")
	frozen_simulation.apply_action(&"liliya", &"heat")
	_check(not bool(frozen_simulation.world_object.get("frozen", false)) and not (frozen_simulation.world_object.get("tags", PackedStringArray()) as PackedStringArray).has("lava_flowing"), "Отогрев обычного замороженного крана не создаёт лавовый поток")
	var hot_job := Generator.materialize_job(examples["faucet_overheat"])
	var hot_simulation := RepairSimulationScript.new()
	hot_simulation.initialize_from_job(hot_job)
	var hot_diagnosis := str(hot_simulation.apply_action(&"boris", &"diagnose")["message"]).to_lower()
	_check("поток остановлен" not in hot_diagnosis and "лав" not in hot_diagnosis and "раскал" in hot_diagnosis, "Осмотр перегретого крана без потока описывает только фактические свойства")
	var hot_freeze_reaction := hot_simulation.get_employee_reaction(&"liliya", &"freeze").to_lower()
	_check(not hot_freeze_reaction.contains("зачем замораживать холодное") and not hot_freeze_reaction.contains("уже промёрз"), "Раскалённый кран не получает реплику о повторной заморозке")
	hot_simulation.apply_action(&"liliya", &"freeze")
	var hot_completion := hot_simulation.get_completion_result(Generator.TUTORIAL_FAUCET_JOB_ID)
	_check("лав" not in str(hot_completion.get("summary", "")).to_lower() and "лав" not in str(hot_completion.get("review", "")).to_lower(), "Акт перегретого крана без лавы не выдумывает лавовый поток")
	var melted_hot := RepairSimulationScript.new()
	melted_hot.initialize_from_job(hot_job)
	melted_hot.apply_action(&"liliya", &"heat")
	var melted_hot_summary := str(melted_hot.get_completion_result(Generator.TUTORIAL_FAUCET_JOB_ID).get("summary", "")).to_lower()
	_check("лава" not in melted_hot_summary and "лавов" not in melted_hot_summary, "Акт расплавленного перегретого крана без лавы не упоминает лаву")
	melted_hot.world_object["thermal_regulator_available"] = true
	_check(not melted_hot.can_install_temperature_regulator(), "У Бориса нет действия установки терморегулятора на уничтоженный кран")
	var game_state := root.get_node("GameState")
	game_state.start_new_game()
	var first_anomaly := str(game_state.generated_jobs[String(Generator.TUTORIAL_FAUCET_JOB_ID)].get("anomaly_id", ""))
	_check(game_state.get_tutorial_job_id() == Generator.TUTORIAL_FAUCET_JOB_ID, "Новая игра выбирает сгенерированную заявку крана")
	_check(game_state.is_job_available(Generator.TUTORIAL_FAUCET_JOB_ID) and not game_state.is_job_available(&"lava_leak"), "В первый день показана одна сгенерированная заявка крана")
	game_state.start_new_game()
	var second_anomaly := str(game_state.generated_jobs[String(Generator.TUTORIAL_FAUCET_JOB_ID)].get("anomaly_id", ""))
	_check(first_anomaly != second_anomaly, "Две новые игры подряд не повторяют аномалию крана")
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("GENERATED FAUCET JOB SMOKE TEST: PASS")
		quit(0)
	else:
		print("GENERATED FAUCET JOB SMOKE TEST: FAIL (%d)" % failures.size())
		quit(1)
