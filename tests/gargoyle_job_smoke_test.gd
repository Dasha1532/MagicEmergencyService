extends SceneTree

const GargoyleSimulationScript := preload("res://scripts/gargoyle_simulation.gd")

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.start_new_game()
	_check(not game_state.jobs[&"sleeping_gargoyle"]["unlocked"], "Заявка с горгульей скрыта в первый день")
	game_state.day = 2
	game_state.completed_job_ids = PackedStringArray(["lava_leak", "walking_wardrobe", "portal_mirror"])
	game_state.job_reports = [
		{"job_id": "lava_leak", "completed_day": 1},
		{"job_id": "walking_wardrobe", "completed_day": 2},
		{"job_id": "portal_mirror", "completed_day": 2},
	]
	game_state.advance_day()
	_check(game_state.day == 3, "После заявок второго дня наступает третий день")
	_check(game_state.is_job_available(&"sleeping_gargoyle"), "На третий день открывается заявка с горгульей")
	_check(game_state.jobs[&"sleeping_gargoyle"]["repair_scene"] == "res://scenes/GargoyleAttic.tscn", "Заявка ведёт прямо на чердак")

	var attic_scene := load("res://scenes/GargoyleAttic.tscn") as PackedScene
	_check(attic_scene != null, "Сцена чердака загружается")
	_check(load("res://assets/backgrounds/gargoyle_attic.png") != null, "Фон чердака загружается")
	_check(load("res://assets/objects/drain_gargoyle/dormant.png") != null, "Спящая горгулья загружается")
	_check(load("res://assets/objects/drain_gargoyle/awakened.png") != null, "Пробуждённая горгулья загружается")
	_check(load("res://assets/objects/drain_gargoyle/damaged.png") != null, "Повреждённая горгулья загружается")
	_check(load("res://assets/objects/drain_gargoyle/dormant_clean.png") != null, "Очищенная спящая горгулья загружается")
	_check(load("res://assets/objects/drain_gargoyle/frozen.png") != null, "Замёрзшая горгулья загружается")
	_check(load("res://assets/effects/gargoyle_attic/flooding.png") != null, "Слой протечек загружается")
	_check(load("res://assets/effects/gargoyle_attic/frozen_flooding.png") != null, "Слой замёрзших протечек загружается")

	var ideal: RefCounted = GargoyleSimulationScript.new()
	var ideal_result: Dictionary = ideal.apply_action(&"liliya", &"animate")
	_check(bool(ideal_result["resolved"]) and ideal.visual_state() == &"awakened", "Оживление даёт идеальный исход")
	_check(int(ideal.get_completion_result()["reputation_change"]) == 1, "Идеальный исход повышает репутацию")
	ideal.apply_action(&"felix", &"antimagic")
	_check(not ideal.is_resolved() and ideal.visual_state() == &"dormant_clean", "Антимагия снова усыпляет пробуждённую горгулью")
	_check(ideal.flooding_state() == &"water", "После антимагии протечки возвращаются")

	var cleared: RefCounted = GargoyleSimulationScript.new()
	cleared.apply_action(&"nika", &"telekinesis")
	_check(cleared.visual_state() == &"dormant_clean", "Телекинез показывает очищенную пасть")
	cleared.apply_action(&"liliya", &"freeze")
	_check(cleared.visual_state() == &"frozen" and cleared.flooding_state() == &"frozen", "Заморозка включает оба ледяных ассета")
	cleared.apply_action(&"liliya", &"heat")
	_check(cleared.visual_state() == &"dormant_clean" and cleared.flooding_state() == &"water", "Нагрев возвращает обычные протечки")

	var technical: RefCounted = GargoyleSimulationScript.new()
	technical.apply_action(&"boris", &"repair")
	var technical_result: Dictionary = technical.get_completion_result()
	_check(technical.is_resolved() and int(technical_result["reward_adjustment"]) < 0, "Механический обход завершает заявку с меньшей оплатой")
	technical.apply_action(&"nika", &"animate")
	var improved_result: Dictionary = technical.get_completion_result()
	_check(int(improved_result["reward_adjustment"]) == 0 and int(improved_result["reputation_change"]) == 1, "Оживление после обходного канала оплачивается как лучший исход")
	_check("пробуждена" in str(improved_result["summary"]), "Итог после улучшения описывает работающую горгулью")

	var damaged: RefCounted = GargoyleSimulationScript.new()
	damaged.apply_action(&"grog", &"physical_move")
	var damaged_result: Dictionary = damaged.get_completion_result()
	_check(damaged.visual_state() == &"damaged", "Силовое воздействие включает повреждённый вид")
	_check(int(damaged_result["compensation_cost"]) > 0 and int(damaged_result["reputation_change"]) < 0, "Повреждение приводит к компенсации и потере репутации")
	var repeated_force: Dictionary = damaged.apply_action(&"grog", &"physical_move")
	_check(not bool(repeated_force["applied"]) and int(damaged.world_object["damage"]) == 8, "Повторный силовой удар по повреждённой горгулье запрещён")
	var failed_animation: Dictionary = damaged.apply_action(&"liliya", &"animate")
	_check(not bool(failed_animation["applied"]), "Повреждённую горгулью нельзя оживить")
	var failed_repair: Dictionary = damaged.apply_action(&"boris", &"repair")
	_check(not bool(failed_repair["applied"]) and "пролом" in str(failed_repair["message"]), "Борис сообщает, что вода уже уходит через пролом")
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("GARGOYLE JOB SMOKE TEST: PASS")
		quit(0)
	else:
		print("GARGOYLE JOB SMOKE TEST: FAIL (%d)" % failures.size())
		quit(1)
