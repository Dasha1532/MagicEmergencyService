extends SceneTree

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var title_scene := load("res://scenes/TitleScreen.tscn") as PackedScene
	_check(title_scene != null, "Главное меню загружается")
	if title_scene == null:
		_finish()
		return
	paused = true
	var title_screen := title_scene.instantiate()
	root.add_child(title_screen)
	current_scene = title_screen
	await process_frame
	await process_frame
	_check(not paused, "Главное меню снимает оставшуюся паузу предыдущей сцены")

	var navigation: Panel = title_screen.navigation
	var buttons: Array[Button] = []
	for child: Node in navigation.get_children():
		if child is Button:
			buttons.append(child as Button)
	_check(buttons.size() == 5, "В главном меню созданы все пять кнопок")
	if buttons.size() < 5:
		_finish()
		return

	_click(buttons[3])
	await process_frame
	_check(title_screen.settings_panel.visible, "Кнопка настроек принимает обычный щелчок мыши")
	_check(title_screen.resolution_option.item_count == 3, "В настройках доступны три разрешения окна")
	_check(title_screen.resolution_option.get_item_text(1) == "1600 × 900", "Базовое разрешение 1600 × 900 отображается в списке")
	title_screen._show_main()
	_click(buttons[1])
	await process_frame
	await process_frame
	_check(current_scene != null and current_scene.scene_file_path == "res://scenes/main.tscn", "Кнопка новой игры открывает офис")
	_finish()


func _click(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = point
	press.global_position = point
	press.pressed = true
	root.push_input(press, true)
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	root.push_input(release, true)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("TITLE SCREEN SMOKE TEST: PASS")
		quit(0)
	else:
		print("TITLE SCREEN SMOKE TEST: FAIL (%d)" % failures.size())
		quit(1)
