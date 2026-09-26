extends SceneTree

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.start_new_game()
	_check(game_state.is_tutorial_active(), "В новой игре обучение активно")
	_check(str(game_state.tutorial_state.get("step", "")) == "office_welcome", "Обучение начинается со знакомства с офисом")
	_check(game_state.has_autosave(), "Новая игра создаёт отдельное автосохранение")

	game_state.set_tutorial_step(&"crew_choice")
	game_state.tutorial_state["step"] = "broken_test_value"
	_check(game_state.load_autosave() == OK, "Автосохранение загружается")
	_check(str(game_state.tutorial_state.get("step", "")) == "crew_choice", "Шаг обучения восстанавливается")

	var panel = load("res://scripts/save_slots_panel.gd").new()
	root.add_child(panel)
	await process_frame
	panel.configure(&"load")
	_check(panel.autosave_button != null, "Автосохранение показано отдельной верхней карточкой")
	_check("АВТОСОХРАНЕНИЕ" in panel.autosave_button.text, "Карточка автосохранения подписана")
	_check(panel.slot_buttons.size() == game_state.SAVE_SLOT_COUNT, "Пять ручных слотов сохранены отдельно")
	panel.configure(&"save")
	_check(panel.autosave_button.disabled, "Автосохранение нельзя перезаписать вручную")
	panel.queue_free()

	_check(load("res://scripts/tutorial_overlay.gd") != null, "Общий интерфейс обучения загружается")
	_check(load("res://scenes/RepairHouse.tscn") != null, "Сцена первой заявки загружается с обучением")
	var repair_simulation = load("res://scripts/repair_simulation.gd").new()
	repair_simulation.apply_action(&"liliya", &"heat")
	var melt_result: Dictionary = repair_simulation.apply_action(&"liliya", &"heat")
	_check(bool(melt_result.get("resolved", false)), "Расплавление остаётся конечным исходом заявки")
	_check(not (repair_simulation.world_object["tags"] as PackedStringArray).has("lava_flowing"), "Расплавленный кран останавливает поток лавы")
	_check(int(repair_simulation.world_object["pressure"]) == 0, "После расплавления давление сброшено")
	_check("перекрыл" in str(repair_simulation.get_completion_result().get("summary", "")), "Итог объясняет, почему поток остановился")
	var migrated_simulation = load("res://scripts/repair_simulation.gd").new()
	migrated_simulation.load_state({"world_object": {"visual_state": "melted", "tags": ["faucet", "melted", "lava_flowing", "pressurized"], "pressure": 10}})
	_check(not (migrated_simulation.world_object["tags"] as PackedStringArray).has("lava_flowing") and int(migrated_simulation.world_object["pressure"]) == 0, "Старое сохранение с расплавленным краном безопасно исправляется")

	game_state.set_tutorial_step(&"open_board")
	var office = (load("res://scenes/ui/OfficeDashboard.tscn") as PackedScene).instantiate()
	root.add_child(office)
	await process_frame
	await process_frame
	_check(office.hub_layer.visible and not office.dashboard_layer.visible, "Новая игра действительно начинается в общем офисе")
	_check(str(game_state.tutorial_state.get("step", "")) == "open_board", "Скрытая доска не считается открытой")
	_check(office.tutorial_overlay.skip_button.flat and office.tutorial_overlay.skip_button.position.x < office.tutorial_overlay.continue_button.position.x, "Пропуск обучения выглядит как вторичная ссылка слева")
	office.tutorial_overlay._layout_panel("report")
	_check(office.tutorial_overlay.panel.position.y == 10.0, "Подсказка к акту располагается над отчётом")
	office._open_jobs()
	await process_frame
	_check(str(game_state.tutorial_state.get("step", "")) == "open_first_job", "После открытия доски обучение переходит к первой заявке")
	office._show_hub()
	game_state.set_tutorial_step(&"return_board")
	await process_frame
	_check(office.dashboard_layer.visible and str(game_state.tutorial_state.get("step", "")) == "finish_day", "Перед завершением дня доска открывается автоматически")
	game_state.day = 2
	await process_frame
	_check(office.hub_layer.visible and str(game_state.tutorial_state.get("step", "")) == "personnel_overview", "На второй день начинается обзор разделов офиса")
	for frame in 5:
		await process_frame
	_check(str(game_state.tutorial_state.get("step", "")) == "personnel_overview", "Обзор сотрудников не переключается обратно на доску заявок")
	office.tutorial_overlay._advance_information_step()
	_check(str(game_state.tutorial_state.get("step", "")) == "supply_overview", "После сотрудников показывается лавка снабжения")
	office.tutorial_overlay._advance_information_step()
	_check(str(game_state.tutorial_state.get("step", "")) == "storage_overview", "После лавки показывается склад снаряжения")
	office.tutorial_overlay._advance_information_step()
	_check(str(game_state.tutorial_state.get("step", "")) == "final", "Обзор офиса завершается финальной подсказкой")
	office.queue_free()
	await process_frame

	game_state.skip_tutorial()
	_check(not game_state.is_tutorial_active(), "Пропущенное обучение отключается")
	_check(str(game_state.tutorial_state.get("status", "")) == "skipped", "Пропуск сохраняет окончательный статус")
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("TUTORIAL AUTOSAVE SMOKE TEST: PASS")
		quit(0)
	else:
		print("TUTORIAL AUTOSAVE SMOKE TEST: FAIL (%d)" % failures.size())
		quit(1)
