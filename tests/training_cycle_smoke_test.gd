extends SceneTree

const WARDROBE_SIMULATION_SCRIPT = preload("res://scripts/wardrobe_simulation.gd")
const WARDROBE_ROOM_SCRIPT = preload("res://scripts/wardrobe_room.gd")
const EMPLOYEE_ACTOR_SCENE = preload("res://scenes/EmployeeActor.tscn")
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
	_check(WARDROBE_ROOM_SCRIPT.WARDROBE_STEPS != null, "Звук шагов шкафа подключён к комнате заявки")
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
	_check(game_state.buy_supply_item(&"protective_cloth"), "Защитное полотно покупается для проверки склада")
	await process_frame
	_check(office.equipment_cards.get_child_count() == 4, "Купленное полевое снаряжение и защитное полотно появляются на складе")
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
	_check(is_equal_approx(office.personnel_training_button.position.x + office.personnel_training_button.size.x * 0.5, course_guide.get_center().x), "Кнопка доступного курса расположена по центру области")
	_check(is_equal_approx(office.personnel_hire_button.position.x + office.personnel_hire_button.size.x * 0.5, course_guide.get_center().x), "Кнопка найма независимо выровнена по центру")
	_check(is_equal_approx(office.personnel_specializations_button.position.x + office.personnel_specializations_button.size.x * 0.5, course_guide.get_center().x), "Кнопка специализаций независимо выровнена по центру")
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
	wardrobe_simulation.apply_action(&"liliya", &"heat")
	wardrobe_simulation.apply_action(&"liliya", &"heat")
	wardrobe_simulation.start_burning_clock(540, 5)
	var early_fire_results: Array[Dictionary] = wardrobe_simulation.advance_burning_until(550, 5)
	_check(early_fire_results.size() == 2 and int(wardrobe_simulation.world_object["fire_spots"]) == 3 and not wardrobe_simulation.is_resolved(), "За 10 минут на шкафу последовательно появляются три очага")
	var elapsed_fire_results: Array[Dictionary] = wardrobe_simulation.advance_burning_until(555, 5)
	_check(elapsed_fire_results.size() == 1 and wardrobe_simulation.is_resolved(), "После трёх очагов шкаф сгорает на 15-й минуте")
	var fire_result: Dictionary = elapsed_fire_results[-1]
	_check((fire_result.get("audio_cues", PackedStringArray()) as PackedStringArray).size() == 2, "Полное сгорание шкафа сопровождается звуком удара и разрушения дерева")
	_check(bool(wardrobe_simulation.get_completion_result().get("forfeit_payment", false)), "За уничтоженный шкаф служба не получает оплату")
	wardrobe_simulation = WARDROBE_SIMULATION_SCRIPT.new()
	var wardrobe_room = WARDROBE_ROOM_SCRIPT.new()
	wardrobe_room.fire_progression_revision = 1
	_check(not wardrobe_room._can_continue_fire_progression(1), "Распространение огня прекращается после выхода из комнаты")
	wardrobe_room._schedule_fire_step(1)
	_check(wardrobe_room._persistent_pose_for_action(&"physical_move", &"break_legs") == &"work", "Грог сохраняет рабочую позу до завершения ломания ножек")
	for push_intent: StringName in [&"hold", &"move_left", &"move_kitchen", &"release"]:
		_check(wardrobe_room._persistent_pose_for_action(&"physical_move", push_intent) == &"hold", "Поза удерживания сохраняется для действия %s" % push_intent)
	wardrobe_room.free()
	var pose_actor = EMPLOYEE_ACTOR_SCENE.instantiate()
	root.add_child(pose_actor)
	_check(pose_actor.configure_employee(&"grog", game_state.employees[&"grog"]), "Актёр Грога загружается для проверки поз")
	pose_actor.set_persistent_action_pose(&"hold")
	_check(pose_actor.get_node("HoldPose").visible and not pose_actor.get_node("WorkPose").visible, "Режим толкания показывает позу удерживания")
	pose_actor.set_persistent_action_pose(&"work")
	_check(pose_actor.get_node("WorkPose").visible and not pose_actor.get_node("HoldPose").visible, "Режим ломания ножек показывает рабочую позу")
	pose_actor.set_persistent_action_pose(&"")
	_check(pose_actor.get_node("NeutralPose").visible, "После завершения долгой работы возвращается поза ожидания")
	pose_actor.queue_free()
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
	_check(office.supply_catalog_list.get_child(0).text == "СНАРЯЖЕНИЕ" and office.supply_catalog_list.get_child(4).text == "МАГИЧЕСКИЕ КУРСЫ", "Снаряжение и магические курсы разделены в каталоге")
	office._select_supply_item(&"antimagic_grimoire")
	_check("антимаг" in office.supply_detail_heading.text.to_lower(), "Выбранная книга показывается без обрезанного названия")
	office._open_personnel()
	office._select_personnel_employee(&"nika")
	_check("АНТИМАГ" in office.personnel_training_button.text, "Из выбранной книги курс антимагии предлагается Нике")
	office.personnel_training_button.pressed.emit()
	_check(StringName(str(game_state.employees[&"nika"].get("training_id", ""))) == &"antimagic", "Ника начинает обучение антимагии")

	game_state.start_new_game()
	game_state.jobs[&"walking_wardrobe"]["unlocked"] = true
	game_state.assign_employee(&"liliya", &"walking_wardrobe")
	_check(game_state.begin_job(&"walking_wardrobe"), "Лилия отправляется к шкафу для проверки пожара вне объекта")
	game_state.advance_time(game_state.TRAVEL_TIME_MINUTES)
	var remote_fire := WARDROBE_SIMULATION_SCRIPT.new()
	remote_fire.apply_action(&"liliya", &"heat")
	remote_fire.apply_action(&"liliya", &"heat")
	remote_fire.start_burning_clock(game_state.time_minutes, game_state.WARDROBE_FIRE_SPREAD_MINUTES)
	game_state.set_job_repair_state(&"walking_wardrobe", remote_fire.get_state())
	game_state._process_timed_job_consequences()
	_check(not game_state.completed_job_ids.has("walking_wardrobe") and game_state.active_job_id == &"walking_wardrobe", "На объекте глобальный пожар не закрывает заявку раньше комнаты")
	_check(load(str(game_state.jobs[&"walking_wardrobe"].get("resident_portrait", ""))) != null, "Для реакции хозяйки шкафа подключён портрет")
	game_state.leave_active_job()
	_check(game_state.recall_job(&"walking_wardrobe"), "Лилию можно отозвать с горящего объекта")
	game_state.advance_time(14)
	_check(not game_state.completed_job_ids.has("walking_wardrobe"), "До истечения 15 минут горящая заявка остаётся открытой")
	game_state.advance_time(1)
	_check(game_state.completed_job_ids.has("walking_wardrobe"), "Шкаф сгорает и заявка автоматически закрывается без присутствия игрока")
	_check(int(game_state.pending_job_report.get("reward", -1)) == 0 and int(game_state.pending_job_report.get("claim_amount", 0)) > 0, "Автоматический исход отменяет оплату и создаёт претензию")
	_check("Срочное сообщение" in str(game_state.pending_job_report.get("incident_message", "")), "В офис приходит сообщение о сгоревшем шкафе")
	_check(game_state.complete_job(&"lava_leak", {"summary": "Параллельная заявка завершена.", "reputation_change": 1}), "После пожара можно завершить другую заявку до возвращения в офис")
	_check(str(game_state.pending_job_report.get("job_id", "")) == "walking_wardrobe", "Следующая заявка не перезаписывает срочное сообщение о шкафе")
	office._refresh_job_report()
	_check(office.job_report_title.text == "СРОЧНОЕ СООБЩЕНИЕ" and "бригада отсутствовала" in office.job_report_body.text, "Офис показывает происшествие отдельным срочным сообщением")
	var incident_books := (load("res://scenes/ui/OfficeBooks.tscn") as PackedScene).instantiate()
	root.add_child(incident_books)
	await process_frame
	incident_books._show_archive_report(game_state.job_reports[0])
	_check("Претензия: 700 монет" in incident_books.detail_body.text and "решение не принято" in incident_books.detail_body.text and "Компенсация: 0" not in incident_books.detail_body.text, "Архив отличает предъявленную претензию от выплаченной компенсации")
	var wardrobe_ledger_event: Dictionary = game_state.financial_ledger[-2]
	incident_books._show_financial_event(wardrobe_ledger_event)
	_check("Предъявлена претензия: 700 монет" in incident_books.detail_body.text and "решение не принято" in incident_books.detail_body.text, "Книга учёта показывает ожидающую решения претензию вместо нулевой компенсации")
	incident_books.queue_free()
	_check(game_state.resolve_pending_claim(false), "По претензии за шкаф можно принять решение")
	game_state.dismiss_pending_job_report()
	_check(str(game_state.pending_job_report.get("job_id", "")) == "lava_leak", "После срочного сообщения показывается следующий непросмотренный акт")
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
