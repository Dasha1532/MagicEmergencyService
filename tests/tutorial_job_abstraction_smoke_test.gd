extends SceneTree

const TutorialOverlayScript := preload("res://scripts/tutorial_overlay.gd")
const RepairSimulationScript := preload("res://scripts/repair_simulation.gd")
const Generator := preload("res://scripts/generated_job_generator.gd")

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	var original_lava_job: Dictionary = game_state.jobs[&"lava_leak"].duplicate(true)
	var probe_id := &"tutorial_faucet_probe"
	var probe: Dictionary = original_lava_job.duplicate(true)
	probe["title"] = "Проверочная аномалия крана"
	probe["resident_request"] = "Проверочная просьба жильца."
	probe["unresolved_message"] = "Проверочная проблема ещё не устранена."
	probe["tutorial_eligible"] = true
	probe["simulation_type"] = &"lava_faucet"
	game_state.jobs[&"lava_leak"]["tutorial_eligible"] = false
	game_state.jobs[probe_id] = probe
	game_state.start_new_game()
	if game_state.jobs.has(Generator.TUTORIAL_FAUCET_JOB_ID):
		game_state.jobs[Generator.TUTORIAL_FAUCET_JOB_ID]["tutorial_eligible"] = false
	game_state.tutorial_job_id = game_state._choose_tutorial_job_id()
	game_state._set_job_unlocked(Generator.TUTORIAL_FAUCET_JOB_ID, false)
	game_state._set_job_unlocked(probe_id, true)
	_check(game_state.get_tutorial_job_id() == probe_id, "Первый день выбирает учебно-допустимую заявку без привязки к lava_leak")
	_check(game_state.is_job_available(probe_id) and not game_state.is_job_available(&"lava_leak"), "На доске доступна только выбранная учебная заявка")
	_check(game_state.is_faucet_job(probe_id), "Ремонтная сцена распознаёт заявку по типу симуляции")
	var overlay := TutorialOverlayScript.new()
	root.add_child(overlay)
	var prompt: Dictionary = overlay._step_data("open_first_job")
	_check("Проверочная аномалия крана" in str(prompt.get("text", "")), "Подсказка обучения берёт название активной заявки из данных")
	var simulation := RepairSimulationScript.new()
	simulation.initialize_from_job(probe)
	_check(simulation.get_resident_request() == "Проверочная просьба жильца.", "Симуляция получает просьбу жильца из заявки")
	_check(simulation.get_unresolved_message() == "Проверочная проблема ещё не устранена.", "Сообщение о незавершённой работе приходит из заявки")
	_check(simulation.get_status_title() == "Проверочная аномалия крана", "Статус объекта использует динамический заголовок")
	game_state.jobs.erase(probe_id)
	game_state.jobs[&"lava_leak"] = original_lava_job
	overlay.queue_free()
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("TUTORIAL JOB ABSTRACTION SMOKE TEST: PASS")
		quit(0)
	else:
		print("TUTORIAL JOB ABSTRACTION SMOKE TEST: FAIL (%d)" % failures.size())
		quit(1)
