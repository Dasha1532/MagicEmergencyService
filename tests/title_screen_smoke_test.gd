extends SceneTree

const LocalizationHelperScript := preload("res://scripts/localization_helper.gd")

const TITLE_SCREEN_SCRIPT := preload("res://scripts/title_screen.gd")

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
	for tagline: String in TITLE_SCREEN_SCRIPT.TAGLINES:
		_check(not tagline.ends_with("."), "Слоган главного меню не заканчивается точкой")

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
	_check(title_screen.language_option.item_count == 2, "В настройках доступны русский и английский языки")
	TranslationServer.set_locale("en")
	_check(tr("НАСТРОЙКИ") == "SETTINGS", "Английский каталог переводит интерфейс")
	_check(tr("Обучение пропущено") == "Training missed", "Статус пропущенного обучения переводится")
	for object_name in ["Кран", "Ванна со льдом", "Водосточная горгулья", "Привидение", "Зеркало", "Шкаф"]:
		_check(tr(object_name) != object_name, "Название объекта переводится: %s" % object_name)
	var course_note := tr("После покупки книга откроет курс «%s». Выберите её в каталоге, затем откройте личное дело совместимого сотрудника.") % tr("Оживление")
	_check("Оживление" not in course_note and "Revival" in course_note, "В подсказку книги подставляется переведённое название курса")
	var saved_summary: String = LocalizationHelperScript.translate_saved_text("Шкаф закреплён у стены и больше не ходит, хотя чары всё ещё действуют. Проход освобождён. Заявка выполнена после истечения срока: из оплаты удержано 100 монет.")
	_check("Шкаф" not in saved_summary and "Проход" not in saved_summary and "Заявка" not in saved_summary, "Составной итог из старого сохранения переводится по предложениям")
	var saved_review: String = LocalizationHelperScript.translate_saved_text("Вода больше не замерзает. Трещину на ванне я назову памятью о вашем особенно убедительном методе. После первоначального отказа служба всё-таки выплатила компенсацию.")
	_check("Вода" not in saved_review and "Трещину" not in saved_review, "Старый составной отзыв полностью переводится")
	TranslationServer.set_locale("ru")
	_check(tr("НАСТРОЙКИ") == "НАСТРОЙКИ", "Русский язык показывает исходный текст без английского fallback")
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
