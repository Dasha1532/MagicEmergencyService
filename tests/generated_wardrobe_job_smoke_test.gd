extends SceneTree

const Generator := preload("res://scripts/generated_job_generator.gd")
const Catalog := preload("res://scripts/generative_job_catalog.gd")
const WardrobeSimulationScript := preload("res://scripts/wardrobe_simulation.gd")

const TEST_SAVE_PATH := "res://tests/.generated_wardrobe_smoke_test.json"
const LEGACY_TEST_SAVE_PATH := "res://tests/.generated_wardrobe_v14_smoke_test.json"

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var starting_abilities := PackedStringArray(["freeze", "heat", "physical_move", "diagnose", "repair"])
	var catalog_errors: PackedStringArray = Catalog.validate_catalog()
	_check(catalog_errors.is_empty(), "У всех объектов и аномалий заполнены обязательные поля, ссылки и ассеты")
	_check(Catalog.compatible_anomalies(&"eleonora_room", &"wardrobe").size() == 3, "Генератор получает совместимые аномалии из каталога")
	var examples: Dictionary = {}
	for seed_value: int in range(100):
		var candidate: Dictionary = Generator.generate(seed_value, starting_abilities)
		if not candidate.is_empty():
			examples[String(candidate["anomaly_id"])] = candidate
		if examples.size() == 3:
			break
	_check(examples.size() == 3, "Набор seed создаёт три разные аварии со шкафом")
	_check(examples.has("restless_animation"), "Генерируется ходячий шкаф")
	_check(examples.has("active_fire"), "Генерируется горящий шкаф")
	_check(examples.has("deep_freeze"), "Генерируется замёрзший шкаф")
	for anomaly_id: String in examples:
		var instance: Dictionary = examples[anomaly_id]
		var repeated: Dictionary = Generator.generate(int(instance["seed"]), starting_abilities)
		_check(instance == repeated, "Один seed воспроизводит аварийный вариант %s" % anomaly_id)
		_check((instance.get("validated_safe_plans", []) as Array).size() >= 1, "Вариант %s имеет доступный безопасный план" % anomaly_id)
		_check(StringName(str(instance.get("requested_zone", ""))) == &"left_wall", "Вариант %s не просит поставить шкаф в проход" % anomaly_id)
		var simulation := _resolved_simulation(instance)
		_check(simulation.is_resolved(), "Вариант %s проходим стартовой бригадой" % anomaly_id)
		_check(int(simulation.get_completion_result().get("reputation_change", 0)) > 0, "Безопасное решение варианта %s даёт положительный результат" % anomaly_id)
	var first: Dictionary = examples["restless_animation"]
	_check(Catalog.has_compatible_vertical_slice(), "Каталог связывает комнату, объект, аномалию и цели")

	var game_state := root.get_node("GameState")
	game_state.start_new_game()
	var generated_id := Generator.JOB_ID
	_check(game_state.jobs.has(generated_id) and game_state.generated_jobs.has(String(generated_id)), "Новая игра материализует генеративную заявку шкафа независимо от учебной заявки крана")
	_check(not game_state.is_job_available(generated_id), "В первый обучающий день генеративная карточка скрыта")
	_check(not game_state.is_job_available(&"walking_wardrobe"), "Старая ручная заявка про тот же шкаф отключена")
	var first_new_game_anomaly := str(game_state.generated_jobs[String(generated_id)].get("anomaly_id", ""))
	game_state.start_new_game()
	var second_new_game_anomaly := str(game_state.generated_jobs[String(generated_id)].get("anomaly_id", ""))
	_check(first_new_game_anomaly != second_new_game_anomaly, "Две новые игры подряд гарантированно получают разные аномалии")
	game_state.completed_job_ids.append(String(game_state.get_tutorial_job_id()))
	game_state.job_reports.append({"job_id": String(game_state.get_tutorial_job_id()), "completed_day": 1})
	game_state.advance_day()
	_check(game_state.is_job_available(generated_id), "Генеративная карточка открывается утром второго дня")
	var stored_instance: Dictionary = game_state.generated_jobs[String(generated_id)].duplicate(true)
	var simulation := WardrobeSimulationScript.new()
	simulation.initialize_generated(stored_instance)
	game_state.set_job_repair_state(generated_id, simulation.get_state())
	_check(game_state._save_to_path(TEST_SAVE_PATH) == OK, "Материализованный экземпляр и runtime-состояние сохраняются")
	game_state.generated_jobs = {}
	game_state.jobs.erase(generated_id)
	game_state.job_repair_states = {}
	_check(game_state._load_from_path(TEST_SAVE_PATH) == OK, "Сохранение с генеративной заявкой загружается")
	_check(not game_state.is_job_available(&"walking_wardrobe"), "После загрузки старая заявка про шкаф не возвращается")
	var restored_instance: Dictionary = game_state.generated_jobs[String(generated_id)]
	_check(int(restored_instance.get("seed", -1)) == int(stored_instance["seed"]) and str(restored_instance.get("anomaly_id", "")) == str(stored_instance["anomaly_id"]), "После загрузки тип аварии не перегенерируется")
	_check(not game_state.get_job_repair_state(generated_id).is_empty(), "Runtime-состояние шкафа восстанавливается")
	var resolved := _resolved_simulation(restored_instance)
	game_state.jobs[generated_id]["assigned"] = PackedStringArray(["liliya", "grog", "boris"])
	_check(game_state.complete_job(generated_id, resolved.get_completion_result()), "Сгенерированная авария завершается через общий игровой цикл")
	_check(game_state.generated_jobs.has(String(generated_id)) and not game_state.is_job_available(generated_id), "После завершения не создаётся новый вариант шкафа")
	var saved_file := FileAccess.open(TEST_SAVE_PATH, FileAccess.READ)
	var legacy_data: Dictionary = JSON.parse_string(saved_file.get_as_text())
	legacy_data["version"] = 14
	legacy_data.erase("campaign_seed")
	legacy_data.erase("next_generated_job_index")
	legacy_data.erase("generated_jobs")
	var legacy_file := FileAccess.open(LEGACY_TEST_SAVE_PATH, FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(legacy_data, "\t"))
	legacy_file.close()
	_check(game_state._load_from_path(LEGACY_TEST_SAVE_PATH) == OK and game_state.generated_jobs.has(String(generated_id)), "Сохранение версии 14 безопасно получает новый материализованный вариант")
	var absolute_path := ProjectSettings.globalize_path(TEST_SAVE_PATH)
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(absolute_path)
	if FileAccess.file_exists(LEGACY_TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LEGACY_TEST_SAVE_PATH))
	_finish()


func _resolved_simulation(instance: Dictionary) -> RefCounted:
	var simulation: RefCounted = WardrobeSimulationScript.new()
	simulation.initialize_generated(instance)
	var anomaly_id := StringName(str(instance.get("anomaly_id", "")))
	if anomaly_id == &"active_fire":
		simulation.apply_action(&"liliya", &"freeze")
	elif anomaly_id == &"deep_freeze":
		simulation.apply_action(&"liliya", &"heat")
	else:
		var move_intent := &"move_left" if StringName(str(instance["requested_zone"])) == &"left_wall" else &"move_kitchen"
		simulation.apply_action(&"grog", &"physical_move", move_intent)
		simulation.apply_action(&"boris", &"anchor")
	return simulation


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("GENERATED WARDROBE JOB SMOKE TEST: PASS")
		quit(0)
	else:
		print("GENERATED WARDROBE JOB SMOKE TEST: FAIL (%d)" % failures.size())
		quit(1)
