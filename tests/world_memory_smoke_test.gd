extends SceneTree

const WorldMemoryScript := preload("res://scripts/world_memory.gd")
const GeneratorScript := preload("res://scripts/generated_job_generator.gd")
const RepairSimulationScript := preload("res://scripts/repair_simulation.gd")
const TEST_SAVE_PATH: String = "user://world_memory_migration_test.json"

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var memory := WorldMemoryScript.new()
	memory.reset()
	var state := {
		"world_object": {
			"instance_id": &"old_quarter_5.bathroom.lava_faucet",
			"definition_id": &"lava_faucet", "temperature": 9, "damage": 0,
			"frozen": false, "broken": false, "visual_state": &"emergency",
		},
		"action_log": [],
	}
	memory.record_job_state(&"lava_leak", state, 1, 540)
	var started := Time.get_ticks_msec()
	for index: int in 5000:
		state["world_object"]["temperature"] = int(state["world_object"]["temperature"]) - 1
		state["world_object"]["frozen"] = true
		if index == 2499:
			state["world_object"]["broken"] = true
			state["world_object"]["damage"] = 4
		state["action_log"].append({
			"employee_id": "liliya", "action_id": "freeze", "intent": "stabilize",
			"result": {"applied": true},
		})
		memory.record_job_state(&"lava_leak", state, 1, 541 + index)
	var elapsed := Time.get_ticks_msec() - started
	_check(memory.recent_events.size() <= 5, "Пять тысяч повторяющихся воздействий сворачиваются в несколько записей")
	_check(memory.significant_events.size() >= 2, "Порог заморозки и поломка остаются отдельными значимыми событиями")
	var last_event: Dictionary = memory.recent_events[-1]
	_check(int(last_event.get("count", 0)) >= 2000, "Компактная запись хранит количество повторений")

	state["world_object"]["temperature"] = int(state["world_object"]["temperature"]) + 5
	state["world_object"]["frozen"] = false
	state["action_log"].append({"employee_id": "boris", "action_id": "heat", "intent": "thaw", "result": {"applied": true}})
	memory.record_job_state(&"lava_leak", state, 1, 6000)
	var faucet: Dictionary = memory.objects["old_quarter_5.bathroom.lava_faucet"]
	var origins: Dictionary = faucet["origins"]
	_check(not bool((origins["frozen"] as Dictionary)["active"]), "Устранённая заморозка сохраняет событие, которым она снята")
	_check(bool((origins["damage"] as Dictionary)["active"]) and str((origins["damage"] as Dictionary)["origin_actor_id"]) == "liliya", "Последующий нагрев не стирает ущерб и ответственность Лилии")

	var serialized := JSON.stringify(memory.to_data())
	var serialized_bytes := serialized.to_utf8_buffer().size()
	print("WORLD_MEMORY_METRICS actions=5000 events=", memory.recent_events.size(), " significant=", memory.significant_events.size(), " bytes=", serialized_bytes, " elapsed_ms=", elapsed)
	_check(serialized_bytes < 120000, "Сериализованная память после 5000 действий меньше 120 КБ")
	_check(elapsed < 15000, "Обработка 5000 действий укладывается в мягкий headless-лимит 15 секунд")
	var restored := WorldMemoryScript.new()
	restored.load_data(JSON.parse_string(serialized))
	var restored_faucet: Dictionary = restored.objects["old_quarter_5.bathroom.lava_faucet"]
	_check(int((restored_faucet["properties"] as Dictionary)["damage"]) == 4 and bool(((restored_faucet["origins"] as Dictionary)["damage"] as Dictionary)["active"]) and restored.recent_events.size() == memory.recent_events.size(), "Состояние, происхождение и компактный журнал восстанавливаются без потерь")
	var generator_context: Dictionary = memory.generator_context()
	_check(not generator_context.has("recent_events") and not generator_context.has("significant_events"), "Генератор получает индекс состояния, а не полный журнал кампании")
	var wardrobe_memory: Dictionary = memory.objects["old_quarter_5.hall.wardrobe"]
	wardrobe_memory["properties"] = {"damage": 3, "scorched": true, "destroyed": false}
	memory.objects["old_quarter_5.hall.wardrobe"] = wardrobe_memory
	generator_context = memory.generator_context()
	var generated: Dictionary = GeneratorScript.generate(424242, PackedStringArray(["freeze", "heat", "physical_move", "diagnose", "repair"]), PackedStringArray(), generator_context)
	_check(not generated.is_empty() and int((generated["initial_state"] as Dictionary).get("damage", 0)) == 3 and bool((generated["initial_state"] as Dictionary).get("scorched", false)), "Генератор сохраняет накопленный ущерб из снимка постоянного объекта")
	wardrobe_memory["properties"] = {"destroyed": true}
	memory.objects["old_quarter_5.hall.wardrobe"] = wardrobe_memory
	_check(GeneratorScript.generate(424242, PackedStringArray(["freeze", "heat", "physical_move", "diagnose", "repair"]), PackedStringArray(), memory.generator_context()).is_empty(), "Генератор не публикует функциональную аномалию для уничтоженного объекта")

	var first_id: String = memory.queue_consequence(&"cold_trace", &"frozen_bath", "old_quarter_5.bathroom.lava_faucet", &"lava_leak", 2, 540, 50, {"reason": "cold_trace"}, "chain.faucet.1", "action.1", 1)
	var duplicate_id: String = memory.queue_consequence(&"cold_trace", &"frozen_bath", "old_quarter_5.bathroom.lava_faucet", &"lava_leak", 2, 540, 50, {"reason": "cold_trace"}, "chain.faucet.1", "action.1", 1)
	var cyclic_id: String = memory.queue_consequence(&"cold_trace", &"frozen_bath", "old_quarter_5.bathroom.lava_faucet", &"lava_leak", 3, 540, 50, {}, "chain.faucet.1", first_id, 5)
	_check(first_id == duplicate_id and cyclic_id.is_empty(), "Очередь подавляет дубли и цепочки глубже четырёх событий")

	var normal_faucet := RepairSimulationScript.new()
	normal_faucet.world_object["thermal_regulator_available"] = true
	normal_faucet.world_object["lava_source_active"] = false
	normal_faucet.world_object["cold_source_active"] = false
	normal_faucet.world_object["heat_source_active"] = false
	normal_faucet.world_object["frozen"] = false
	normal_faucet.world_object["temperature"] = 2
	var unnecessary_regulator: Dictionary = normal_faucet.apply_action(&"boris", &"install_thermal_regulator", {"protections": PackedStringArray(["contact_heat"])})
	_check(not normal_faucet.can_install_temperature_regulator() and not bool(unnecessary_regulator.get("applied", false)), "На исправный кран без активной температурной причины терморегулятор установить нельзя")
	var completed_frozen_faucet := RepairSimulationScript.new()
	completed_frozen_faucet.world_object["generated_anomaly_id"] = &"faucet_freeze"
	completed_frozen_faucet.world_object["generated_completion"] = {"summary": "", "review": "", "consequences": []}
	completed_frozen_faucet.world_object["frozen"] = true
	completed_frozen_faucet.world_object["cold_source_active"] = true
	completed_frozen_faucet.world_object["temperature"] = -5
	completed_frozen_faucet.apply_action(&"liliya", &"heat")
	var completion_text := JSON.stringify(completed_frozen_faucet.get_completion_result()).to_lower()
	_check("автоматичес" not in completion_text and "провер" not in completion_text, "Акт не сообщает игроку о внутренней проверке исправности")

	var rebound_memory := _completed_thaw_memory(false)
	_check(rebound_memory.has_consequence(&"faucet_overheat"), "Заморозка с последующим отогревом создаёт отложенный перегрев из состояния и действий")
	var cooling_memory := _completed_cooling_memory()
	_check(cooling_memory.has_consequence(&"cold_trace") and not cooling_memory.has_consequence(&"faucet_overheat"), "Перегрев с последующим охлаждением создаёт холодный след из свойств памяти мира")
	var replaced_memory := _completed_thaw_memory(true)
	_check(not replaced_memory.has_consequence(&"faucet_overheat"), "Замена крана отменяет тепловое последствие прежней физической инкарнации")
	_check_no_inverse_consequence_loop()
	_check_consequence_materialization(rebound_memory)
	_check_v19_missing_consequence_migration()

	_check_legacy_migration()
	_finish()


func _check_legacy_migration() -> void:
	var game_state := root.get_node("GameState")
	game_state.start_new_game()
	for legacy_job_id: String in game_state.HIDDEN_LEGACY_JOB_IDS:
		game_state.jobs[StringName(legacy_job_id)]["unlocked"] = true
		_check(not game_state.is_job_available(StringName(legacy_job_id)), "Старая заявка %s скрыта от генеративного цикла" % legacy_job_id)
	_check(game_state._save_to_path(TEST_SAVE_PATH) == OK, "Тестовое сохранение памяти создано")
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.READ)
	var legacy: Dictionary = JSON.parse_string(file.get_as_text())
	file.close()
	legacy["version"] = 18
	legacy.erase("world_memory")
	legacy["job_reports"] = [{
		"job_id": "lava_leak", "completed_day": 1, "completed_time": 600,
		"follow_up": {"type": "frozen_bath", "source_job_id": "lava_leak"},
	}]
	file = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	_check(game_state._load_from_path(TEST_SAVE_PATH) == OK, "Сохранение v18 последовательно мигрирует в память мира")
	_check(game_state.world_memory.has_consequence(&"frozen_bath"), "Старый follow_up мигрирует в общую очередь")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))


func _check_no_inverse_consequence_loop() -> void:
	var memory := WorldMemoryScript.new()
	memory.reset()
	var initial := {"definition_id": &"lava_faucet", "incarnation": 1, "temperature": 12, "frozen": false, "broken": false, "thermal_regulator_installed": false, "function_test_passed": false}
	memory.ensure_job_context(&"generated_faucet_consequence_test", initial, "old_quarter_5.bathroom.lava_faucet", {"source_deferred_event_id": "deferred.test"})
	var state := {"world_object": initial.duplicate(true), "action_log": []}
	memory.record_job_state(&"generated_faucet_consequence_test", state, 2, 550)
	state["world_object"]["temperature"] = 2
	state["world_object"]["function_test_passed"] = true
	state["action_log"].append({"employee_id": "liliya", "action_id": "freeze", "result": {"applied": true}})
	memory.record_job_state(&"generated_faucet_consequence_test", state, 2, 555)
	memory.finalize_job(&"generated_faucet_consequence_test", {}, 2, 560)
	_check(memory.due_consequences(99, 0).is_empty(), "Решение системного последствия не создаёт обратную заявку и не запускает цикл")


func _check_v19_missing_consequence_migration() -> void:
	var game_state := root.get_node("GameState")
	game_state.start_new_game()
	var frozen_instance: Dictionary = {}
	for seed_value: int in 200:
		var candidate: Dictionary = GeneratorScript.generate_tutorial_faucet(seed_value, PackedStringArray(["freeze", "heat", "physical_move", "diagnose", "repair"]))
		if str(candidate.get("anomaly_id", "")) == "faucet_freeze":
			frozen_instance = candidate
			break
	_check(not frozen_instance.is_empty(), "Для миграционного fixture найден замороженный вариант крана")
	if frozen_instance.is_empty():
		return
	game_state._register_generated_job(frozen_instance)
	var job_id := StringName(str(frozen_instance["instance_id"]))
	game_state.completed_job_ids.append(String(job_id))
	game_state.job_reports = [{
		"job_id": String(job_id), "completed_day": 1, "completed_time": 570,
		"summary": "Источник магического холода устранён. Кран оттаял и прошёл автоматическую проверку исправности.",
		"consequences": ["Автоматическая проверка исправности пройдена."],
		"actions": [{"employee_id": "liliya", "action_id": "heat", "result": {"applied": true}}],
	}]
	game_state.world_memory.reset()
	_check(game_state._save_to_path(TEST_SAVE_PATH) == OK, "Создано сохранение v19 без ожидающего последствия")
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.READ)
	var old_data: Dictionary = JSON.parse_string(file.get_as_text())
	file.close()
	old_data["version"] = 19
	file = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(old_data))
	file.close()
	_check(game_state._load_from_path(TEST_SAVE_PATH) == OK and game_state.world_memory.has_consequence(&"faucet_overheat"), "Загрузка v19 восстанавливает пропущенное последствие исходно замороженного крана")
	var migrated_report: Dictionary = game_state.job_reports[-1]
	_check("автоматичес" not in str(migrated_report.get("summary", "")).to_lower() and (migrated_report.get("consequences", []) as Array).is_empty(), "Миграция очищает старый акт от внутренней проверки исправности")


func _completed_thaw_memory(replace_afterward: bool) -> RefCounted:
	var memory := WorldMemoryScript.new()
	memory.reset()
	var state := {"world_object": {"definition_id": &"lava_faucet", "incarnation": 1, "temperature": -5, "frozen": true, "cold_source_active": true, "broken": false, "replaced": false, "thermal_regulator_installed": false, "function_test_passed": false, "visual_state": &"frozen", "damage": 0}, "action_log": []}
	memory.record_job_state(&"generated_faucet_tutorial_1", state, 1, 560)
	state["world_object"]["temperature"] = 2
	state["world_object"]["frozen"] = false
	state["world_object"]["cold_source_active"] = false
	state["world_object"]["function_test_passed"] = true
	state["action_log"].append({"employee_id": "liliya", "action_id": "heat", "result": {"applied": true}})
	memory.record_job_state(&"generated_faucet_tutorial_1", state, 1, 564)
	if replace_afterward:
		state["world_object"]["incarnation"] = 2
		state["world_object"]["replaced"] = true
		state["action_log"].append({"employee_id": "boris", "action_id": "replace_faucet", "result": {"applied": true}})
		memory.record_job_state(&"generated_faucet_tutorial_1", state, 1, 570)
	memory.finalize_job(&"generated_faucet_tutorial_1", {}, 1, 570)
	return memory


func _completed_cooling_memory() -> RefCounted:
	var memory := WorldMemoryScript.new()
	memory.reset()
	var state := {"world_object": {"definition_id": &"lava_faucet", "incarnation": 1, "temperature": 12, "frozen": false, "heat_source_active": true, "broken": false, "replaced": false, "thermal_regulator_installed": false, "function_test_passed": false, "visual_state": &"overheated", "tags": PackedStringArray(["faucet", "overheated"]), "damage": 0}, "action_log": []}
	memory.record_job_state(&"generated_faucet_tutorial_hot", state, 1, 560)
	state["world_object"]["temperature"] = 2
	state["world_object"]["heat_source_active"] = false
	state["world_object"]["function_test_passed"] = true
	state["world_object"]["visual_state"] = &"normal"
	state["world_object"]["tags"] = PackedStringArray(["faucet"])
	state["action_log"].append({"employee_id": "liliya", "action_id": "freeze", "result": {"applied": true}})
	memory.record_job_state(&"generated_faucet_tutorial_hot", state, 1, 564)
	memory.finalize_job(&"generated_faucet_tutorial_hot", {}, 1, 570)
	return memory


func _check_consequence_materialization(memory: RefCounted) -> void:
	var game_state := root.get_node("GameState")
	game_state.start_new_game()
	game_state.world_memory.load_data(memory.to_data())
	game_state.day = 1
	_check(game_state._save_to_path(TEST_SAVE_PATH) == OK, "Ожидающее последствие сохраняется до наступления следующего дня")
	game_state.world_memory.reset()
	_check(game_state._load_from_path(TEST_SAVE_PATH) == OK and game_state.world_memory.has_consequence(&"faucet_overheat"), "После загрузки причинное последствие остаётся в очереди")
	game_state.advance_day()
	var consequence_job_id: StringName = &""
	for job_id: StringName in game_state.jobs:
		if String(job_id).begins_with("generated_faucet_consequence_"):
			consequence_job_id = job_id
			break
	_check(not consequence_job_id.is_empty() and game_state.is_job_available(consequence_job_id), "На следующий день последствие публикуется как новая доступная заявка по тому же крану")
	if consequence_job_id.is_empty():
		return
	var job: Dictionary = game_state.jobs[consequence_job_id]
	var description := str(job.get("description", "")).to_lower()
	var resident_request := str(job.get("resident_request", "")).to_lower()
	_check(str((job.get("generated_instance", {}) as Dictionary).get("anomaly_id", "")) == "faucet_overheat" and "прошлого обращения" in resident_request and "прошлого обращения" not in description and "последств" not in description, "Связь заявок перенесена из описания в реплику жильца")
	var stored_instance: Dictionary = (job.get("generated_instance", {}) as Dictionary).duplicate(true)
	_check(game_state._save_to_path(TEST_SAVE_PATH) == OK, "Заявка-последствие сохраняется")
	_check(game_state._load_from_path(TEST_SAVE_PATH) == OK, "Заявка-последствие загружается")
	var restored_instance: Dictionary = game_state.generated_jobs.get(String(consequence_job_id), {}) as Dictionary
	_check(str(restored_instance.get("instance_id", "")) == str(stored_instance.get("instance_id", "")) and str(restored_instance.get("anomaly_id", "")) == str(stored_instance.get("anomaly_id", "")) and str(restored_instance.get("source_deferred_event_id", "")) == str(stored_instance.get("source_deferred_event_id", "")) and game_state.is_job_available(consequence_job_id), "После загрузки заявка-последствие не генерируется заново")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)


func _finish() -> void:
	if failures.is_empty():
		print("WORLD MEMORY SMOKE TEST PASSED")
		quit(0)
	else:
		print("WORLD MEMORY SMOKE TEST FAILED: ", failures)
		quit(1)
