extends SceneTree

const WARDROBE_SIMULATION_SCRIPT = preload("res://scripts/wardrobe_simulation.gd")
const EMPLOYEE_REACTION_RESOLVER_SCRIPT = preload("res://scripts/employee_reaction_resolver.gd")

var failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	var audio_manager := root.get_node("AudioManager")
	_check(audio_manager.coin_player.stream != null, "Звук монет подключён")
	_check(audio_manager.cat_meow_player.stream != null, "Обычное мяуканье кота подключено")
	_check(audio_manager.cat_angry_meow_player.stream != null, "Сердитое мяуканье кота подключено")
	audio_manager.set_wardrobe_steps_playing(true)
	_check(audio_manager.wardrobe_steps_player.playing, "Шаги ходячего шкафа запускаются зацикленно")
	audio_manager.set_wardrobe_steps_playing(false)
	_check(not audio_manager.wardrobe_steps_player.playing, "Шаги шкафа можно остановить после обездвиживания")
	game_state.start_new_game()
	_check(game_state.get_training_availability(&"liliya", &"animate") == &"no_slots", "Две специализации Лилии занимают обе учебные ячейки")
	_check(game_state.get_training_availability(&"grog", &"animate") == &"incompatible", "Несовместимый сотрудник отклоняется")
	_check(game_state.get_training_availability(&"boris", &"freeze") == &"incompatible", "Бориса нельзя обучить магии")
	_check("замороз" in EMPLOYEE_REACTION_RESOLVER_SCRIPT.reaction_for(game_state.employees[&"nika"], &"freeze", {}, &"", "", true).to_lower(), "Обучаемый маг получает личную реплику заморозки")
	_check(not EMPLOYEE_REACTION_RESOLVER_SCRIPT.reaction_for(game_state.employees[&"grog"], &"antimagic", {}, &"", "", true).is_empty(), "Для способности предусмотрена общая запасная реплика")
	_check(game_state.get_training_availability(&"nika", &"animate") == &"not_hired", "Ненанятый сотрудник не может учиться")
	var actor := (load("res://scenes/EmployeeActor.tscn") as PackedScene).instantiate()
	root.add_child(actor)
	await process_frame
	_check(actor.configure_employee(&"boris", game_state.employees[&"boris"]), "Две новые шагающие позы Бориса загружаются")
	_check(actor._walk_scale_x(actor.position.x + 100.0) < 0.0, "Борис разворачивается вправо из исходной позы лицом влево")
	actor._set_walk_frame(true)
	_check(actor.walk_pose_alt.visible and not actor.walk_pose.visible, "Кадры ходьбы Бориса переключаются попеременно")
	_check(actor.configure_employee(&"grog", game_state.employees[&"grog"]), "Две новые шагающие позы Грога загружаются")
	_check(actor._walk_scale_x(actor.position.x + 100.0) > 0.0, "Грог идёт лицом вправо без лишнего отражения позы")
	actor._set_walk_frame(true)
	_check(actor.walk_pose_alt.visible and not actor.walk_pose.visible, "Кадры ходьбы Грога переключаются попеременно")
	actor.queue_free()

	game_state.grant_debug_money(500)
	_check(game_state.buy_supply_item(&"animation_kit"), "Учебный комплект покупается")
	_check(game_state.hire_employee(&"nika"), "Ника нанимается для обучения")
	_check(game_state.get_training_availability(&"nika", &"animate") == &"available", "После покупки курс доступен Нике со свободной ячейкой")

	var office_scene := load("res://scenes/ui/OfficeDashboard.tscn") as PackedScene
	var office := office_scene.instantiate()
	root.add_child(office)
	await process_frame
	var steam := office.find_child("CupSteam", true, false)
	_check(steam != null and steam.is_processing(), "Над кружкой работает анимированный пар")
	_check(steam.position.x < 700.0 and steam.position.y < 500.0, "Пар привязан к области кружки, а не книги")
	var office_menu := office.find_child("OfficeMenuButton", true, false) as TextureButton
	_check(office_menu != null and office_menu.self_modulate.r < 0.75, "Главный рубильник приглушён относительно исходного ассета")
	_check(office.cat_sprite.texture.resource_path.ends_with("sleeping.png"), "Поверх фонового кота показан новый спящий ассет")
	office._on_cat_pressed()
	_check(office.cat_phrase_panel.visible and not office.cat_phrase_label.text.is_empty(), "Невидимая зона кота показывает шуточную реплику")
	for click_index in range(3):
		office._on_cat_pressed()
	_check(office.cat_sprite.texture.resource_path.ends_with("alert.png"), "На четвёртом нажатии кот поднимает мордочку")
	for click_index in range(4):
		office._on_cat_pressed()
	_check(office.cat_sprite.texture.resource_path.ends_with("warning.png"), "На восьмом нажатии кот поднимает лапу")
	for click_index in range(2):
		office._on_cat_pressed()
	_check("Инспектором кошачьего отдела" in office.cat_phrase_label.text, "Десятое нажатие выдаёт скрытое кошачье прозвище")
	office._on_cat_pressed()
	_check(office.cat_sprite.texture.resource_path.ends_with("offended.png"), "После последнего предупреждения кот отворачивается")
	_check(office.cat_button.disabled, "После отворачивания дальнейшие клики по коту заблокированы")
	var offended_click_count: int = office.cat_click_count
	office._on_cat_pressed()
	_check(office.cat_click_count == offended_click_count, "Заблокированный кот больше не меняет состояние")
	office._open_equipment_storage()
	await process_frame
	_check(office.equipment_cards.get_child_count() == 1, "На складе изначально есть служебный ремонтный набор Бориса")
	game_state.grant_debug_money(500)
	_check(game_state.buy_supply_item(&"ghost_trap"), "Ловушка покупается для проверки склада")
	_check(game_state.buy_supply_item(&"thermal_regulator"), "Терморегулятор покупается для проверки склада")
	await process_frame
	_check(office.equipment_cards.get_child_count() == 3, "Купленное полевое снаряжение появляется на складе")
	_check(not office.warning_label.visible, "Служебные подтверждения не выводятся поверх карточки заявки")
	office._open_personnel()
	var status_guide: Rect2 = office._personnel_guide_rect("StatusArea")
	_check(office.personnel_specializations_button.visible and not office.personnel_training_button.visible, "При заполненных ячейках управление заменяет бесполезную кнопку курса")
	_check(is_equal_approx(office.personnel_specializations_button.position.x + office.personnel_specializations_button.size.x * 0.5, status_guide.get_center().x), "Управление специализациями расположено по центру области")
	office._select_personnel_employee(&"grog")
	_check("КУРС НЕ ПОДХОДИТ" in office.personnel_training_button.text, "Грог показывает состояние несовместимого курса")
	_check(is_equal_approx(office.personnel_training_button.position.x + office.personnel_training_button.size.x * 0.5, status_guide.get_center().x), "Неактивное состояние курса расположено по центру")
	office._select_personnel_employee(&"nika")
	_check("НАЧАТЬ КУРС" in office.personnel_training_button.text, "Кадровый экран предлагает начать доступный курс")
	office._open_specializations()
	_check(office.specialization_slots.get_child_count() == 2, "Окно специализаций показывает две ячейки")
	_check("ТЕЛЕКИНЕЗ" in office.specialization_slots.get_child(0).text and "СВОБОДНА" in office.specialization_slots.get_child(1).text, "Занятая и свободная ячейки подписаны")
	office.specialization_slots.get_child(0).pressed.emit()
	_check(office.specialization_confirm_layer.visible, "Забывание требует отдельного подтверждения")
	office._cancel_forget_specialization()
	office._close_specializations()
	var course_guide: Rect2 = office._personnel_guide_rect("StatusArea")
	_check(office.personnel_training_button.position.x < course_guide.position.x, "Кнопка курса сдвинута левее")
	_check(office.personnel_training_button.position.x + office.personnel_training_button.size.x < course_guide.end.x, "Кнопка курса не выходит за правый край рамки")
	_check(is_equal_approx(office.personnel_hire_button.position.x + office.personnel_hire_button.size.x * 0.5, course_guide.get_center().x), "Кнопка найма независимо выровнена по центру")
	_check(office.finish_day_button.get_parent() == office.dashboard_layer, "Кнопка завершения дня находится на доске заявок")
	var returning_status: String = office._employee_card_status(
		{"status": "Возвращается, прибудет в 09:36"}, false, false, false, false, true
	)
	_check(returning_status == "Возвращается\nПрибудет в 09:36", "Статус возвращения разбит на две строки карточки")
	office.personnel_training_button.pressed.emit()
	_check(game_state.is_employee_training(&"nika"), "Обучение начинается из кадрового экрана")
	_check(not game_state.forget_employee_ability(&"nika", &"telekinesis"), "Во время обучения специализацию забыть нельзя")
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
	_check(game_state.forget_employee_ability(&"nika", &"animate"), "Изученную специализацию можно забыть после обучения")
	_check(not (game_state.employees[&"nika"]["abilities"] as PackedStringArray).has("animate"), "Забытая специализация исчезает из действий")
	_check(not (game_state.employees[&"nika"]["learned_abilities"] as PackedStringArray).has("animate"), "Забытая специализация удаляется из прогресса")
	_check(game_state.get_training_availability(&"nika", &"animate") == &"available", "Забытую специализацию можно изучить заново")
	_check(game_state.TRAINING_DEFINITIONS.has(&"freeze") and game_state.TRAINING_DEFINITIONS.has(&"heat") and game_state.TRAINING_DEFINITIONS.has(&"telekinesis") and game_state.TRAINING_DEFINITIONS.has(&"antimagic"), "В лавку добавлены четыре базовых магических курса")
	game_state.grant_debug_money(600)
	_check(game_state.buy_supply_item(&"antimagic_grimoire"), "Книгу антимагии можно купить отдельно от найма Феликса")
	office._open_supply_shop()
	var debug_money_found := false
	for button_node: Node in office.find_children("*", "Button", true, false):
		if (button_node as Button).text == "ТЕСТ: +500 МОНЕТ":
			debug_money_found = true
			break
	_check(debug_money_found, "В лавке доступна тестовая кнопка +500 монет")
	_check(office.supply_catalog_cards.size() == game_state.SUPPLY_ITEMS.size(), "Каталог показывает всё снаряжение и учебные книги")
	_check(office.supply_catalog_list.get_child(0).text == "СНАРЯЖЕНИЕ" and office.supply_catalog_list.get_child(3).text == "МАГИЧЕСКИЕ КУРСЫ", "Снаряжение и магические курсы разделены в каталоге")
	office._select_supply_item(&"antimagic_grimoire")
	_check("антимаг" in office.supply_detail_heading.text.to_lower(), "Выбранная книга показывается без обрезанного названия")
	office._open_personnel()
	office._select_personnel_employee(&"nika")
	_check("АНТИМАГ" in office.personnel_training_button.text, "Из выбранной книги курс антимагии предлагается Нике")
	office.personnel_training_button.pressed.emit()
	_check(StringName(str(game_state.employees[&"nika"].get("training_id", ""))) == &"antimagic", "Ника начинает обучение антимагии")
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
