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
	var first: Dictionary = Generator.generate(424242, starting_abilities)
	var repeated: Dictionary = Generator.generate(424242, starting_abilities)
	_check(not first.is_empty(), "Стартовая бригада получает разрешимую генеративную заявку")
	_check(first == repeated, "Один seed создаёт идентичный материализованный экземпляр")
	_check(str(first.get("contents_type", "")) == "dishes", "Генератор использует только поддерживаемую посуду")
	_check((first.get("validated_safe_plans", []) as Array).size() >= 1, "До публикации найден доступный безопасный план")
	_check(Generator.find_safe_plans(first, PackedStringArray()).is_empty(), "Заявка отклоняется без необходимых навыков")
	var all_plans := Generator.find_safe_plans(first, PackedStringArray(["physical_move", "repair", "telekinesis", "antimagic"]))
	_check(all_plans.size() >= 2, "Поддерживаются минимум два безопасных семейства решения")
	_check(Catalog.has_compatible_vertical_slice(), "Каталог связывает комнату, объект, аномалию и цели")

	var simulation: RefCounted = WardrobeSimulationScript.new()
	simulation.initialize_generated(first)
	var requested_zone := StringName(str(first["requested_zone"]))
	var move_intent := &"move_left" if requested_zone == &"left_wall" else &"move_kitchen"
	simulation.apply_action(&"grog", &"physical_move", move_intent)
	var anchor_result: Dictionary = simulation.apply_action(&"boris", &"anchor")
	_check(bool(anchor_result["resolved"]), "Безопасный маршрут Грог плюс Борис завершает заявку")
	var completion: Dictionary = simulation.get_completion_result()
	_check(int(completion["reputation_change"]) == 1 and int(completion["reward_adjustment"]) == 0, "Безопасный путь даёт максимальный результат")

	var antimagic_route: RefCounted = WardrobeSimulationScript.new()
	antimagic_route.initialize_generated(first)
	antimagic_route.apply_action(&"grog", &"physical_move", move_intent)
	antimagic_route.apply_action(&"felix", &"antimagic")
	_check(antimagic_route.is_resolved(), "Альтернативный безопасный путь с антимагией работает")

	var destructive: RefCounted = WardrobeSimulationScript.new()
	destructive.initialize_generated(first)
	destructive.apply_action(&"grog", &"physical_move", &"break_legs")
	_check(destructive.is_resolved() and int(destructive.get_completion_result()["reputation_change"]) < 0, "Разрушительный исход сохранён и штрафуется")

	var game_state := root.get_node("GameState")
	game_state.start_new_game()
	var generated_id := Generator.JOB_ID
	_check(game_state.jobs.has(generated_id) and game_state.generated_jobs.has(String(generated_id)), "Новая игра материализует отдельную карточку заявки")
	_check(not game_state.is_job_available(generated_id), "Генеративная заявка скрыта до следующего дня после вводной аварии")
	game_state.completed_job_ids = PackedStringArray(["lava_leak"])
	game_state.job_reports = [{"job_id": "lava_leak", "completed_day": 1}]
	game_state.advance_day()
	_check(game_state.is_job_available(generated_id), "Генеративная карточка открывается в существующем цикле заявок")
	var stored_instance: Dictionary = game_state.generated_jobs[String(generated_id)].duplicate(true)
	game_state.set_job_repair_state(generated_id, simulation.get_state())
	_check(game_state._save_to_path(TEST_SAVE_PATH) == OK, "Материализованный экземпляр и runtime-состояние сохраняются")
	game_state.generated_jobs = {}
	game_state.jobs.erase(generated_id)
	game_state.job_repair_states = {}
	_check(game_state._load_from_path(TEST_SAVE_PATH) == OK, "Сохранение с генеративной заявкой загружается")
	var restored_instance: Dictionary = game_state.generated_jobs[String(generated_id)]
	_check(int(restored_instance.get("seed", -1)) == int(stored_instance["seed"]) and str(restored_instance.get("requested_zone", "")) == str(stored_instance["requested_zone"]) and int(restored_instance.get("initial_time", 0)) == int(stored_instance["initial_time"]), "После загрузки материализованные параметры не перегенерируются")
	_check(not game_state.get_job_repair_state(generated_id).is_empty(), "Runtime-состояние шкафа восстанавливается")
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
