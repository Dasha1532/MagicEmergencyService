extends SceneTree

const GhostSimulationScript := preload("res://scripts/ghost_followup_simulation.gd")

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.start_new_game()
	_check(not game_state.jobs[&"escaped_ghost"]["unlocked"], "Заявка-последствие скрыта до исхода с полотном")
	game_state.day = 2
	game_state.completed_job_ids = PackedStringArray(["portal_mirror"])
	game_state.job_reports = [{
		"job_id": "portal_mirror",
		"completed_day": 2,
		"follow_up": {"type": "escaped_ghost", "source_job_id": "portal_mirror"},
	}]
	game_state.advance_day()
	_check(game_state.is_job_available(&"escaped_ghost"), "На следующее утро открывается заявка о привидении")
	_check(game_state.jobs[&"escaped_ghost"]["repair_scene"] == "res://scenes/GhostMirrorRoom.tscn", "Заявка ведёт сразу в гостиную")

	var room_scene := load("res://scenes/GhostMirrorRoom.tscn") as PackedScene
	_check(room_scene != null, "Сцена заявки загружается")
	_check(load("res://assets/objects/escaped_ghost/calm.png") != null, "Спокойный призрак загружается")
	_check(load("res://assets/objects/escaped_ghost/angry.png") != null, "Злой призрак загружается")
	_check(load("res://assets/objects/ghost_trap/empty.png") != null, "Пустая ловушка загружается")
	_check(load("res://assets/objects/ghost_trap/occupied.png") != null, "Заполненная ловушка загружается")
	_check(game_state.SUPPLY_ITEMS.has(&"ghost_trap"), "Ловушка добавлена в каталог снаряжения")
	game_state.employees[&"felix"]["available"] = true
	game_state.assign_employee(&"felix", &"escaped_ghost")
	game_state.begin_job(&"escaped_ghost")
	game_state.advance_time(game_state.TRAVEL_TIME_MINUTES)
	var room := room_scene.instantiate()
	root.add_child(room)
	await process_frame
	_check(room.get_node_or_null("GhostPlacement") != null and room.get_node_or_null("MirrorPlacement") != null, "Интерактивные объекты создаются без ошибок")
	_check(not room.get_node("TrapPlacement/Empty").visible and not room.get_node("TrapPlacement/Occupied").visible, "При входе в комнату ловушка не установлена")
	_check(room.get_node("MirrorPlacement/Open").texture is AtlasTexture, "Открытое зеркало использует тот же кадр и размер, что в исходной заявке")
	var original_mirror_scene := (load("res://scenes/PortalMirrorHouse.tscn") as PackedScene).instantiate()
	root.add_child(original_mirror_scene)
	var followup_destroyed := room.get_node("MirrorPlacement/Destroyed") as TextureRect
	var original_destroyed := original_mirror_scene.get_node("PortalMirror/Destroyed") as TextureRect
	_check(followup_destroyed.position == original_destroyed.position and followup_destroyed.size == original_destroyed.size, "Разбитое зеркало сохраняет размер из предыдущей заявки")
	original_mirror_scene.queue_free()
	room.queue_free()
	await process_frame

	var felix_route: RefCounted = GhostSimulationScript.new()
	_check(not felix_route.get_resident_request().contains("не снимайте ткань"), "Во вступительной просьбе Селесты убрано лишнее указание")
	var refused: Dictionary = felix_route.uncover_mirror(&"boris", false)
	_check(not bool(refused["applied"]), "Без Феликса сотрудники не снимают полотно")
	_check(StringName(felix_route.world_object["mirror_state"]) == &"covered", "После отказа зеркало остаётся накрытым")
	var uncover_result: Dictionary = felix_route.uncover_mirror(&"nika", true)
	_check(bool(uncover_result["applied"]) and not str(uncover_result["message"]).contains("Феликс"), "При наличии антимагии можно снять полотно без упоминания конкретного сотрудника")
	_check(bool(felix_route.apply_ghost_action(&"felix", &"antimagic")["applied"]), "Феликс возвращает призрака в открытый портал")
	_check(not felix_route.is_resolved(), "После изгнания портал ещё требуется закрыть")
	_check(bool(felix_route.close_portal(&"felix", true)["applied"]), "Феликс закрывает портал вторым действием")
	_check(felix_route.is_resolved(), "Возврат призрака и закрытие портала завершают работу")
	_check(int(felix_route.get_completion_result()["reputation_change"]) == 1, "Идеальное решение повышает репутацию")

	var trap_route: RefCounted = GhostSimulationScript.new()
	_check(not bool(trap_route.apply_ghost_action(&"boris", &"trap")["applied"]), "До установки ловушка не может поймать привидение")
	_check(bool(trap_route.install_trap(&"boris", true)["applied"]), "Купленную ловушку можно установить")
	_check(StringName(trap_route.world_object["trap_state"]) == &"installed", "После установки пустая ловушка готова к работе")
	_check(bool(trap_route.apply_ghost_action(&"boris", &"trap")["applied"]), "После установки привидение можно загнать в ловушку")
	_check(trap_route.is_resolved() and StringName(trap_route.world_object["mirror_state"]) == &"covered", "Ловушка завершает заявку без открытия портала")
	_check(int(trap_route.get_completion_result()["reward_adjustment"]) < 0, "Альтернативное решение оплачивается ниже идеального")
	var captured_uncover: Dictionary = trap_route.uncover_mirror(&"boris", true)
	_check(bool(captured_uncover["applied"]) and not str(captured_uncover["message"]).contains("вернуть"), "После поимки снятие полотна не предлагает возвращать привидение в портал")
	_check(not trap_route.is_resolved(), "Открытый портал после поимки ещё требуется закрыть")
	_check(bool(trap_route.close_portal(&"felix", true)["applied"]), "Антимагия закрывает портал, когда привидение уже находится в ловушке")
	_check(trap_route.is_resolved(), "Пойманное привидение и закрытый портал завершают работу")
	_check(str(trap_route.get_completion_result()["summary"]).contains("окончательно закрыт"), "Итог учитывает закрытие портала после поимки")

	var broken_route: RefCounted = GhostSimulationScript.new()
	var broken_result: Dictionary = broken_route.break_mirror(&"grog")
	_check(bool(broken_result["applied"]) and broken_route.is_resolved(), "Грог может разбить зеркало и окончательно оборвать портал")
	_check(StringName(broken_route.world_object["mirror_state"]) == &"destroyed", "После силового действия показывается разбитое зеркало")
	_check(int(broken_route.get_completion_result()["compensation_cost"]) == 300, "Разбитое зеркало приводит к компенсации как в предыдущей заявке")

	var failed_magic: RefCounted = GhostSimulationScript.new()
	failed_magic.apply_ghost_action(&"liliya", &"freeze")
	_check(StringName(failed_magic.world_object["ghost_state"]) == &"angry", "Температурная магия злит призрака")
	_check(not failed_magic.is_resolved(), "Разозлённый призрак не считается пойманным")
	var grog_attempt: Dictionary = failed_magic.apply_ghost_action(&"grog", &"physical_move")
	_check(not bool(grog_attempt["applied"]), "Грог не может схватить бестелесного призрака")
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("GHOST FOLLOW-UP SMOKE TEST: PASS")
		quit(0)
	else:
		print("GHOST FOLLOW-UP SMOKE TEST: FAIL (%d)" % failures.size())
		quit(1)
