extends SceneTree

const WARDROBE_SIMULATION_SCRIPT = preload("res://scripts/wardrobe_simulation.gd")
const EMPLOYEE_REACTION_RESOLVER_SCRIPT = preload("res://scripts/employee_reaction_resolver.gd")

var failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.start_new_game()
	_check(game_state.get_training_availability(&"liliya", &"animate") == &"no_slots", "Две специализации Лилии занимают обе учебные ячейки")
	_check(game_state.get_training_availability(&"grog", &"animate") == &"incompatible", "Несовместимый сотрудник отклоняется")
	_check(game_state.get_training_availability(&"nika", &"animate") == &"not_hired", "Ненанятый сотрудник не может учиться")

	game_state.grant_debug_money(500)
	_check(game_state.buy_supply_item(&"animation_kit"), "Учебный комплект покупается")
	_check(game_state.hire_employee(&"nika"), "Ника нанимается для обучения")
	_check(game_state.get_training_availability(&"nika", &"animate") == &"available", "После покупки курс доступен Нике со свободной ячейкой")

	var office_scene := load("res://scenes/ui/OfficeDashboard.tscn") as PackedScene
	var office := office_scene.instantiate()
	root.add_child(office)
	await process_frame
	office._open_personnel()
	office._select_personnel_employee(&"nika")
	_check("НАЧАТЬ КУРС" in office.personnel_training_button.text, "Кадровый экран предлагает начать доступный курс")
	var course_guide: Rect2 = office._personnel_guide_rect("StatusArea")
	_check(office.personnel_training_button.position.x < course_guide.position.x, "Кнопка курса сдвинута левее")
	_check(office.personnel_training_button.position.x + office.personnel_training_button.size.x < course_guide.end.x, "Кнопка курса не выходит за правый край рамки")
	_check(is_equal_approx(office.personnel_hire_button.position.x + office.personnel_hire_button.size.x * 0.5, course_guide.get_center().x), "Кнопка найма независимо выровнена по центру")
	_check(office.finish_day_button.get_parent() == office.dashboard_layer, "Кнопка завершения дня находится на доске заявок")
	var returning_status: String = office._employee_card_status(
		{"status": "Возвращается • прибудет в 09:36"}, false, false, false, false, true
	)
	_check(returning_status == "Возвращается\nПрибудет в 09:36", "Статус возвращения разбит на две строки карточки")
	office.personnel_training_button.pressed.emit()
	_check(game_state.is_employee_training(&"nika"), "Обучение начинается из кадрового экрана")
	_check("ОБУЧЕНИЕ ИДЁТ" in office.personnel_training_button.text, "Кадровый экран показывает срок обучения")

	game_state.assign_employee(&"nika", &"lava_leak")
	_check(game_state.get_employee_job(&"nika").is_empty(), "Обучающегося нельзя назначить на заявку")
	_check(not game_state.try_finish_day(), "Рабочий день нельзя завершить при доступных заявках")
	game_state.completed_job_ids = PackedStringArray(["lava_leak", "walking_wardrobe", "portal_mirror"])
	_check(game_state.try_finish_day(), "После закрытия заявок начинается следующий день")
	_check(game_state.day == 2, "Игровой день увеличивается")
	_check(not game_state.is_employee_training(&"nika"), "Обучение завершается утром следующего дня")
	_check((game_state.employees[&"nika"]["abilities"] as PackedStringArray).has("animate"), "Изученное действие добавлено сотруднику")
	_check((game_state.employees[&"nika"]["learned_abilities"] as PackedStringArray).has("animate"), "Изученная способность сохраняется в прогрессе")
	_check(game_state.get_training_availability(&"nika", &"animate") == &"learned", "Повторное обучение не предлагается")
	var wardrobe_simulation = WARDROBE_SIMULATION_SCRIPT.new()
	var previous_magic_level := int(wardrobe_simulation.world_object["magic_level"])
	var animation_result: Dictionary = wardrobe_simulation.apply_action(&"nika", &"animate")
	_check(bool(animation_result.get("applied", false)), "Изученное оживление применяется к совместимому объекту")
	_check(int(wardrobe_simulation.world_object["magic_level"]) > previous_magic_level, "Оживление системно усиливает чары объекта")
	var felix_reaction: String = EMPLOYEE_REACTION_RESOLVER_SCRIPT.reaction_for(
		game_state.employees[&"felix"], &"antimagic", WARDROBE_SIMULATION_SCRIPT.new().world_object
	)
	_check(felix_reaction != "Подавление чар — не ремонт." and not felix_reaction.is_empty(), "Феликс использует выбранные контекстные реплики")
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("TRAINING CYCLE SMOKE TEST: PASS")
		quit(0)
	else:
		print("TRAINING CYCLE SMOKE TEST: FAIL (%d)" % failures.size())
		quit(1)
