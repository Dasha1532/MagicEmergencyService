extends SceneTree

const Mirror := preload("res://scripts/portal_mirror_simulation.gd")
const Office := preload("res://scripts/office_dashboard.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
	else:
		print("PASS: ", label)

func run() -> void:
	if not "MirrorTests" in OS.get_user_data_dir():
		push_error("Запускайте через tests/run_portal_mirror_checks.ps1: нужен отдельный профиль сохранений.")
		quit(1)
		return
	var state := root.get_node("GameState")
	state.start_new_game()
	for path: String in ["res://assets/objects/lunnopuh_cage/empty.png", "res://assets/objects/lunnopuh_cage/occupied.png", "res://assets/objects/lunnopuh/free.png", "res://assets/objects/portal_mirror/silhouette.png", "res://assets/objects/portal_mirror/silhouette_heat_damaged.png"]:
		var texture := load(path) as Texture2D
		check(texture != null and texture.get_image().detect_alpha() != Image.ALPHA_NONE, "Ассет загружается с прозрачностью: " + path)
	check(state.buy_supply_item(&"lunnopuh_cage"), "Клетка покупается в лавке")
	check(not state.buy_supply_item(&"lunnopuh_cage"), "Повторная покупка не списывает деньги")
	check(state.has_supply_item(&"lunnopuh_cage"), "Купленная клетка в снаряжении")
	var sim := Mirror.new()
	check(not sim.install_cage(&"boris", false)["applied"], "Без клетки установка невозможна")
	sim.apply_action(&"boris", &"diagnose")
	check(sim.available_actions(&"boris").has("install_cage"), "Установка доступна после осмотра")
	check(sim.install_cage(&"boris", true)["applied"], "Клетка устанавливается")
	check(not sim.install_cage(&"boris", true)["applied"], "Клетка не устанавливается дважды")
	var copy := Mirror.new()
	copy.load_state(JSON.parse_string(JSON.stringify(sim.get_state())))
	check(str(copy.world_object["cage_state"]) == "installed", "Размещение клетки сохраняется")
	var old := Mirror.new()
	old.load_state({"world_object": {"portal_open": true, "covered": false}})
	check(str(old.world_object.get("cage_state", "packed")) == "packed", "В старом сохранении клетка не появляется сама")
	state.active_job_id = &"portal_mirror"
	state.jobs[&"portal_mirror"]["unlocked"] = true
	state.jobs[&"portal_mirror"]["dispatched"] = true
	state.jobs[&"portal_mirror"]["assigned"] = PackedStringArray(["boris"])
	state.skip_tutorial()
	state.set_job_repair_state(&"portal_mirror", copy.get_state())
	var room := (load("res://scenes/PortalMirrorHouse.tscn") as PackedScene).instantiate()
	root.add_child(room)
	await process_frame
	check(room.lunnopuh_cage.visible and room.lunnopuh_cage.get_node("Empty").visible, "Сцена показывает установленную пустую клетку")
	check(not room.lunnopuh.visible, "Обычная заявка не получает зверька сама")
	room.simulation.world_object["portal_silhouette"] = true
	room._apply_visual_state()
	check(room.portal_mirror.get_node("Silhouette").visible and not room.portal_mirror.get_node("Open").visible, "Портал показывает силуэт по свойству")
	room.simulation.world_object["damage"] = 1
	room._apply_visual_state()
	check(room.portal_mirror.get_node("SilhouetteHeatDamaged").visible and not room.portal_mirror.get_node("HeatDamaged").visible, "Повреждённый силуэт не перекрывается старым ассетом")
	room.simulation.world_object["covered"] = true
	room._apply_visual_state()
	check(not room.portal_mirror.get_node("SilhouetteHeatDamaged").visible, "Полотно скрывает силуэт")
	room.simulation.world_object["lunnopuh_state"] = "free"
	room._apply_visual_state()
	check(room.lunnopuh.visible and room.lunnopuh_cage.get_node("Empty").visible, "Свободный зверёк и пустая клетка отображаются раздельно")
	room.simulation.world_object["lunnopuh_state"] = "caged"
	room._apply_visual_state()
	check(not room.lunnopuh.visible and room.lunnopuh_cage.get_node("Occupied").visible, "В клетке используется цельный ассет без второго зверька")
	check(room.lunnopuh.has_node("Target"), "У свободного лунопуха отдельная точка действия")
	check(room.lunnopuh_cage.get_node("InteractionButton").visible, "Занятый лунопух в клетке кликабелен")
	state.jobs[&"portal_mirror"]["assigned"] = PackedStringArray(["boris", "liliya"])
	room.selected_employee_id = &"liliya"
	for creature_state: String in ["free", "caged"]:
		room.simulation.world_object["lunnopuh_state"] = creature_state
		room._apply_visual_state()
		var before: String = JSON.stringify(room.simulation.get_state())
		if creature_state == "free":
			room.lunnopuh.selected.emit()
		else:
			room.lunnopuh_cage.selected.emit()
		check(room.selected_object_id == &"lunnopuh" and room.tool_bar.current_object_name == "Лунопух", "Клик выбирает зверька: " + creature_state)
		check(room.tool_bar.get_node("%FreezeButton").visible and room.tool_bar.get_node("%HeatButton").visible, "Обе отказные кнопки Лилии видимы")
		for action: StringName in [&"freeze", &"heat"]:
			room._on_tool_selected(action)
			check(not room.action_in_progress and room.pending_dialogue_action.is_empty(), "Отказ не запускает заклинание")
			check(JSON.stringify(room.simulation.get_state()) == before, "Отказ не меняет зверька или зеркало")
	room.selected_employee_id = &"boris"
	room._on_lunnopuh_selected()
	room._on_tool_selected(&"diagnose")
	check(room.simulation.pending_actor_action.get("target_id") == "lunnopuh", "Незавершённый осмотр сохраняет цель")
	check(not room.simulation.world_object.get("lunnopuh_inspected", false), "Осмотр не завершён до подхода и работы")
	var pending_copy := Mirror.new()
	pending_copy.load_state(JSON.parse_string(JSON.stringify(room.simulation.get_state())))
	check(pending_copy.pending_actor_action.get("target_id") == "lunnopuh", "Цель осмотра восстанавливается после загрузки")
	room._resolve_timed_action(&"diagnose")
	check(room.simulation.world_object.get("lunnopuh_inspected", false), "Осмотр отмечает именно лунопуха")
	room.action_in_progress = false
	room.pending_physical_action = &""
	room.simulation.world_object["lunnopuh_state"] = "free"
	room.simulation.world_object["cage_state"] = "installed"
	room.selected_employee_id = &"nika"
	room.simulation.world_object["portal_open"] = true
	room.simulation.world_object["covered"] = false
	room.simulation.world_object["destroyed"] = false
	state.employees[&"nika"]["available"] = true
	state.jobs[&"portal_mirror"]["assigned"] = PackedStringArray(["boris", "liliya", "nika"])
	room._on_lunnopuh_selected()
	room._on_tool_selected(&"telekinesis")
	check(room.tool_bar.temporary_buttons.size() == 3, "Телекинез открывает два назначения и кнопку назад")
	room.repair_hud.show_employee_reaction(&"nika", "Я могу его подхватить, но посадить пока некуда. Нужна клетка. Или могу направить его сразу в портал", true)
	room.tool_bar.position = Vector2(125, 520)
	room._on_tool_selected(&"telekinesis")
	check(not room.tool_bar.get_global_rect().intersects(room.repair_hud.dialogue_portrait_frame.get_global_rect()), "Портрет не перекрывает меню телекинеза")
	check(not room.tool_bar.get_global_rect().intersects(room.repair_hud.employee_reaction_panel.get_global_rect()), "Окно реплики не перекрывает кнопки действий")

	room._on_tool_selected(&"catch_lunnopuh")
	check(room.simulation.world_object["lunnopuh_state"] == "free", "Предварительная реплика не ловит зверька")
	check(room.pending_dialogue_action == &"catch_lunnopuh", "Поимка ожидает реплику Ники")
	room.pending_dialogue_action = &""
	room._resolve_timed_action(&"catch_lunnopuh")
	check(room.lunnopuh_cage.get_node("Occupied").visible and not room.lunnopuh.visible, "Завершённая поимка переключает на ассет занятой клетки")
	state.set_job_repair_state(&"portal_mirror", room.simulation.get_state())
	var office := Office.new()
	office.game_state = state
	check("ЛУНОПУХ" in office._equipment_status(&"lunnopuh_cage"), "Склад показывает занятую клетку")
	check(preload("res://scripts/generative_job_catalog.gd").validate_catalog().is_empty(), "Каталог объектов сохраняет корректные ресурсы")
	room.simulation.world_object["lunnopuh_state"] = "free"
	room.simulation.world_object["lunnopuh_inspected"] = true
	state.set_job_repair_state(&"portal_mirror", room.simulation.get_state())
	for actor_id: StringName in [&"boris", &"grog"]:
		room.selected_employee_id = actor_id
		for cage_state: String in ["packed", "installed"]:
			room.simulation.world_object["cage_state"] = cage_state
			room._on_lunnopuh_selected()
			var labels := PackedStringArray()
			for button: Button in room.tool_bar.temporary_buttons:
				labels.append(button.text)
			check(labels.has("Поймать зверька") == (cage_state == "packed"), "Попытка руками только без установленной клетки: " + String(actor_id))
			check(labels.has("Загнать в клетку") == (cage_state == "installed"), "Загон только в установленную клетку: " + String(actor_id))
	room.selected_employee_id = &"nika"
	room.simulation.world_object["lunnopuh_offset_x"] = 0.0
	room.simulation.world_object["lunnopuh_state"] = "free"
	check(room._lunnopuh_approach_position(&"catch_hand") == room.get_node("LunnopuhRoutes/RightApproach").position, "Подход справа задаётся маркером сцены")
	room.simulation.escape_lunnopuh(room.get_node("LunnopuhRoutes/EscapeLeft").position.x - room.lunnopuh_home_position.x)
	check(float(room.simulation.world_object["lunnopuh_offset_x"]) == room.get_node("LunnopuhRoutes/EscapeLeft").position.x - room.lunnopuh_home_position.x, "Зверёк использует настроенную координату побега")
	check(room._lunnopuh_approach_position(&"catch_hand") == room.get_node("LunnopuhRoutes/LeftApproach").position, "Следующая попытка идёт к левому маркеру")
	check(room.get_node("LunnopuhRoutes/RightApproach").position.y == room.get_node("LunnopuhRoutes/LeftApproach").position.y, "Оба подхода сохраняют одинаковую высоту актёра")
	room.simulation.world_object["lunnopuh_offset_x"] = 0.0
	room.simulation.world_object["lunnopuh_escape_pending"] = false
	room._on_lunnopuh_approach_finished(&"catch_hand")
	var restored_position := Mirror.new()
	restored_position.load_state(JSON.parse_string(JSON.stringify(room.simulation.get_state())))
	check(float(restored_position.world_object["lunnopuh_offset_y"]) == float(room.simulation.world_object["lunnopuh_offset_y"]), "Высота побега сохраняется и загружается")
	room._apply_visual_state()
	check(room.lunnopuh.position + Vector2(room.lunnopuh.size.x * 0.5, room.lunnopuh.size.y) == room.get_node("LunnopuhRoutes/EscapeLeft").position, "EscapeLeft задаёт положение лап по X и Y")
	check(room._is_instant_physical_action(&"catch_hand") and room._is_instant_physical_action(&"catch_into_cage"), "Попытки поимки не запускают длительную работу")
	room.simulation.world_object["lunnopuh_offset_x"] = 0.0
	room.simulation.world_object["lunnopuh_offset_y"] = 0.0
	room.simulation.world_object["lunnopuh_escape_pending"] = false
	room.repair_hud.set_job_title("Поймать лунопуха или вернуть в его мир; закрыть или изолировать портал")
	check(room.repair_hud.job_title_label.text.split("\n")[1] == "Закрыть или изолировать портал", "Задача портала начинается на отдельной строке")
	check(room.lunnopuh.get_node("InteractionButton").mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "У зверька используется существующий курсор-лупа")
	room.simulation.world_object["portal_open"] = true
	room.simulation.world_object["covered"] = false
	room.simulation.world_object["destroyed"] = false
	room.simulation.world_object["cold_aura"] = false
	room.simulation.world_object["damage"] = 0
	check(not room.simulation.get_employee_reaction(&"boris", &"diagnose").is_empty(), "Борис говорит перед осмотром тёплого портала")
	check(not room.simulation.get_employee_reaction(&"liliya", &"freeze").is_empty() and not room.simulation.get_employee_reaction(&"liliya", &"heat").is_empty(), "Лилия использует общие температурные реплики без упоминания холода портала")
	room.simulation.world_object["lunnopuh_state"] = "free"
	room._apply_visual_state()
	room.employee_actor.action_in_progress = false
	room.employee_actor.configure_employee(&"nika", state.employees[&"nika"])
	room.employee_actor.current_action_id = &"return_lunnopuh"
	room.employee_actor.set_persistent_work_pose(true)
	room.action_in_progress = true
	room._animate_lunnopuh_return()
	await create_timer(0.5).timeout
	check(room.simulation.world_object["lunnopuh_state"] == "free" and room.returning_creature, "Возвращение не меняет состояние до окончания полёта")
	check(room.employee_actor.work_pose.visible, "Ника сохраняет рабочую позу во время полёта")
	await create_timer(1.3).timeout
	check(room.simulation.world_object["lunnopuh_state"] == "returned" and not room.lunnopuh.visible, "Зверёк исчезает в портале после полёта")
	check(room.employee_actor.neutral_pose.visible and not room.action_in_progress, "После возвращения Ника ждёт следующего действия")
	await create_timer(3.0).timeout # Завершаем ранее запущенную физическую анимацию осмотра.
	room.simulation.world_object["lunnopuh_state"] = "free"
	room.simulation.world_object["cage_state"] = "installed"
	room.selected_employee_id = &"boris"
	room._on_lunnopuh_selected()
	var installed_labels := PackedStringArray()
	for button: Button in room.tool_bar.temporary_buttons:
		installed_labels.append(button.text)
	check(not installed_labels.has("Установить клетку"), "Установка скрыта после размещения клетки")
	var outside_click := InputEventMouseButton.new()
	outside_click.button_index = MOUSE_BUTTON_LEFT
	outside_click.pressed = true
	outside_click.position = Vector2.ZERO
	room.tool_bar._input(outside_click)
	check(not room.tool_bar.visible, "Клик вне меню закрывает действия")
	room.selected_employee_id = &"nika"
	room.employee_actor.configure_employee(&"nika", state.employees[&"nika"])
	room.employee_actor.current_action_id = &"catch_lunnopuh"
	room.employee_actor.set_persistent_work_pose(true)
	room._apply_visual_state()
	room._animate_lunnopuh_transfer(&"catch_lunnopuh")
	await create_timer(0.5).timeout
	check(room.simulation.world_object["lunnopuh_state"] == "free" and room.employee_actor.work_pose.visible, "Полёт в клетку удерживает позу и не ловит зверька заранее")
	if room.lunnopuh_motion.is_running():
		await room.lunnopuh_motion.finished
	await process_frame
	check(room.simulation.world_object["lunnopuh_state"] == "caged" and room.lunnopuh_cage.get_node("Occupied").visible, "После полёта показывается зверёк в клетке")
	check(room.employee_actor.neutral_pose.visible, "После поимки Ника возвращается в ожидание")
	var previous_owned: PackedStringArray = state.owned_supply_items.duplicate()
	state.owned_supply_items.erase("lunnopuh_cage")
	room.simulation.world_object["lunnopuh_state"] = "free"
	room.simulation.world_object["cage_state"] = "packed"
	check(room._lunnopuh_telekinesis_choices().size() == 1 and room._lunnopuh_telekinesis_choices()[0]["id"] == &"return_lunnopuh", "Без клетки остаётся только открытый портал")
	room.simulation.world_object["portal_open"] = false
	check(room._lunnopuh_telekinesis_choices().is_empty(), "Без клетки и с закрытым порталом варианты скрыты")
	check(not "портал" in room._lunnopuh_missing_cage_reaction(), "Закрытый портал не упоминается в реплике Ники")
	room.simulation.world_object["portal_open"] = true
	room.simulation.world_object["covered"] = true
	check("портал" in room._lunnopuh_missing_cage_reaction(), "Полотно сохраняет прежнюю реплику о портале")
	check(room._lunnopuh_telekinesis_choices().is_empty(), "Полотно скрывает отправку, пока портал завешен")
	room.simulation.world_object["covered"] = false
	state.owned_supply_items = previous_owned
	room.simulation.world_object["lunnopuh_state"] = "caged"
	room.simulation.world_object["cage_state"] = "occupied"
	room.simulation.world_object["portal_open"] = true
	var caught_choices: Array = room._lunnopuh_telekinesis_choices()
	check(caught_choices.size() == 1 and caught_choices[0]["id"] == &"return_lunnopuh", "Из клетки доступно только возвращение в открытый портал")
	room.simulation.world_object["portal_open"] = false
	check(room._lunnopuh_telekinesis_choices().is_empty(), "Закрытый портал скрывает возвращение пойманного зверька")
	room.simulation.world_object["lunnopuh_state"] = "free"
	check(room._lunnopuh_telekinesis_choices().size() == 1, "Для свободного зверька при закрытом портале остаётся поимка")
	room.simulation.world_object["lunnopuh_state"] = "caged"
	room.simulation.world_object["portal_open"] = true
	room.employee_actor.current_action_id = &"return_lunnopuh"
	room.employee_actor.set_persistent_work_pose(true)
	room._animate_lunnopuh_transfer(&"return_lunnopuh")
	check(room.lunnopuh.visible and room.lunnopuh_cage.get_node("Empty").visible, "Полёт из клетки показывает отдельного зверька и пустую клетку")
	await room.lunnopuh_motion.finished
	await process_frame
	check(room.simulation.world_object["lunnopuh_state"] == "returned" and room.simulation.world_object["cage_state"] == "installed", "Возвращение из клетки оставляет пустую клетку")
	var pose_actor := (load("res://scenes/EmployeeActor.tscn") as PackedScene).instantiate()
	root.add_child(pose_actor)
	await process_frame
	for actor_id: StringName in [&"boris", &"grog"]:
		pose_actor.configure_employee(actor_id, state.employees[actor_id])
		for action_id: StringName in [&"catch_hand", &"catch_into_cage"]:
			check(pose_actor._pose_for_action(action_id).texture.resource_path.ends_with("/" + String(actor_id) + "/catch_pose.png"), "Поимка использует новую позу: " + String(actor_id))
	pose_actor.configure_employee(&"boris", state.employees[&"boris"])
	pose_actor.current_action_id = &"diagnose"
	pose_actor.set_persistent_work_pose(true)
	check(pose_actor.specific_pose.visible and pose_actor.specific_pose.texture.resource_path.ends_with("/boris/inspect_pose.png"), "Общий актёр удерживает позу осмотра Бориса")
	check(not pose_actor.work_pose.visible, "Осмотр не показывает ремонтный ключ")
	pose_actor.set_persistent_work_pose(false)
	check(pose_actor.neutral_pose.visible and not pose_actor.specific_pose.visible, "После осмотра возвращается ожидание")
	check(pose_actor._pose_for_action(&"repair") == pose_actor.work_pose, "Ремонт сохраняет прежнюю рабочую позу")
	pose_actor.queue_free()
	office.queue_free()
	room.queue_free()
	await process_frame
	print("LUNNOPUH ASSETS: ", "PASS" if failures == 0 else "FAIL", " (", failures, ")")
	quit(0 if failures == 0 else 1)