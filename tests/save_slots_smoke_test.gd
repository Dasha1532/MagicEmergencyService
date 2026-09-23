extends SceneTree

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.start_new_game()
	_check(game_state.SAVE_SLOT_COUNT == 5, "Доступно пять слотов")
	_check(game_state.save_slot_path(1).ends_with("save_slot_1.json"), "У каждого слота отдельный файл")
	_check(game_state.save_game(0) == ERR_INVALID_PARAMETER, "Нельзя сохранить игру вне диапазона слотов")
	_check(game_state.load_game(6) == ERR_INVALID_PARAMETER, "Нельзя загрузить игру вне диапазона слотов")
	game_state.day = 2
	game_state.money = 725
	_check(game_state.save_game(1) == OK, "Первый слот сохраняется")
	game_state.day = 4
	game_state.money = 1180
	_check(game_state.save_game(2) == OK, "Второй слот сохраняется независимо")
	var first: Dictionary = game_state.get_save_slot_summary(1)
	var second: Dictionary = game_state.get_save_slot_summary(2)
	_check(int(first.get("day", 0)) == 2 and int(first.get("money", 0)) == 725, "Карточка первого слота показывает его состояние")
	_check(int(second.get("day", 0)) == 4 and int(second.get("money", 0)) == 1180, "Карточка второго слота показывает его состояние")
	_check(game_state.load_game(1) == OK and game_state.day == 2 and game_state.money == 725, "Загружается выбранный слот")
	_check(game_state.load_game(2) == OK and game_state.day == 4 and game_state.money == 1180, "Слоты не перезаписывают друг друга")
	var panel = load("res://scripts/save_slots_panel.gd").new()
	root.add_child(panel)
	await process_frame
	_check(panel.slot_buttons.size() == 5, "Панель создаёт пять кнопок слотов")
	panel.configure(&"load")
	_check(panel.slot_buttons[0].disabled == false and panel.slot_buttons[4].disabled == true, "При загрузке занятые слоты доступны, а пустые заблокированы")
	panel.configure(&"save")
	_check(panel.slot_buttons[4].disabled == false, "При сохранении можно выбрать пустой слот")
	panel._select_slot(1)
	_check(panel.pending_overwrite_slot == 1, "Перезапись занятого слота требует подтверждения")
	panel.queue_free()
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("SAVE SLOTS SMOKE TEST: PASS")
		quit(0)
	else:
		print("SAVE SLOTS SMOKE TEST: FAIL (%d)" % failures.size())
		quit(1)
