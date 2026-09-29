extends SceneTree

var failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	TranslationServer.set_locale("ru")
	var game_state := root.get_node("GameState")
	game_state.start_new_game()
	var map_scene := load("res://scenes/ui/CityMap.tscn") as PackedScene
	_check(map_scene != null, "Сцена карты загружается")
	if map_scene == null:
		_finish()
		return
	var city_map := map_scene.instantiate()
	root.add_child(city_map)
	await process_frame
	var marker := city_map.get_node("MapArea/HouseMarkers/RagnarAndEleonora") as Button
	var selesta_marker := city_map.get_node("MapArea/HouseMarkers/Selesta") as Button
	var gargoyle_marker := city_map.get_node("MapArea/HouseMarkers/GargoyleAttic") as Button
	_check("Активных заявок: 1" in marker.text, "Стартовая заявка показана по адресу")
	_check("Старый квартал, 5" in marker.text, "Маркер подписан адресом")
	_check("Рагнар" not in marker.text and "Элеонор" not in marker.text, "Маркер не присваивает дом жильцам")
	_check(not selesta_marker.visible, "Адрес без доступных заявок скрыт")
	_check(not gargoyle_marker.visible, "Адрес третьего дня пока скрыт")
	_check("Бригада не назначена" in marker.text, "Показан статус без бригады")

	var selection := {"job_id": &""}
	city_map.job_selected.connect(func(job_id: StringName) -> void: selection["job_id"] = job_id)
	marker.pressed.emit()
	await process_frame
	var first_job_button := city_map.get_node("HousePanel/JobScroll/JobList").get_child(0) as Button
	first_job_button.pressed.emit()
	_check(selection["job_id"] == &"lava_leak", "Заявка выбирается из списка дома")

	game_state.assign_employee(&"liliya", &"lava_leak")
	game_state.begin_job(&"lava_leak")
	_check("Сотрудники в пути" in marker.text, "Маркер обновлён при отправке")
	game_state.advance_time(game_state.TRAVEL_TIME_MINUTES)
	_check("Сотрудники на объекте" in marker.text, "Маркер обновлён при прибытии")
	game_state.start_job_action(&"lava_leak", &"liliya", &"freeze", &"", 2)
	_check("Работа выполняется" in marker.text, "Маркер обновлён при начале работы")
	game_state.advance_time(2)
	_check("Сотрудники на объекте" in marker.text, "Маркер обновлён после окончания работы")
	game_state.clear_pending_job_action(&"lava_leak")
	game_state.advance_time(100)
	_check("Срок истёк" in marker.text, "Маркер обновлён при просрочке")
	game_state.complete_active_job()
	_check(not marker.visible and not selesta_marker.visible, "После вводной заявки день остаётся без новых вызовов")
	_check(game_state.can_finish_day(), "После крана рабочий день можно завершить")
	_check(game_state.try_finish_day(), "Завершение дня открывает следующее утро")
	_check("Активных заявок: 2" in marker.text, "На следующий день открыты ручная и генеративная заявки со шкафом")
	marker.pressed.emit()
	await process_frame
	var current_job_list := city_map.get_node("HousePanel/JobScroll/JobList")
	_check(current_job_list.get_child_count() == 2 and "Шкаф" in current_job_list.get_child(0).text and "шкаф" in current_job_list.get_child(1).text.to_lower(), "Список содержит обе доступные заявки со шкафом")
	_check("Активных заявок: 1" in selesta_marker.text, "Адрес показывает заявку с порталом")
	_check(selesta_marker.visible, "Адрес появляется после открытия заявки")
	_check("Селест" not in selesta_marker.text, "Второй маркер также подписан только адресом")
	game_state.assign_employee(&"boris", &"portal_mirror")
	game_state.begin_job(&"portal_mirror")
	_check("Сотрудники в пути" in selesta_marker.text, "Второй дом обновлён при отправке")
	game_state.cancel_job_arrivals(&"portal_mirror")
	_check("Бригада не назначена" in selesta_marker.text, "Второй дом обновлён при отмене отправки")
	game_state.completed_job_ids.append("walking_wardrobe")
	game_state.completed_job_ids.append("portal_mirror")
	game_state.advance_day()
	_check(gargoyle_marker.visible and "Горгуль" not in gargoyle_marker.text, "На третий день карта показывает новый адрес без имени объекта")
	_check("Активных заявок: 1" in gargoyle_marker.text, "Новый маркер использует общие данные заявок")
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("CITY MAP SMOKE TEST: PASS")
		quit(0)
	else:
		print("CITY MAP SMOKE TEST: FAIL (%d)" % failures.size())
		quit(1)
