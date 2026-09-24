extends SceneTree

const FrozenBathSimulationScript := preload("res://scripts/frozen_bath_simulation.gd")
const RepairSimulationScript := preload("res://scripts/repair_simulation.gd")

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.start_new_game()
	_check(not game_state._is_valid_pending_report({"claim_status": "none"}), "Пустая устаревшая запись не считается актом выполненных работ")
	_check(game_state.SUPPLY_ITEMS.has(&"thermal_regulator"), "Рунический терморегулятор добавлен в снаряжение")
	_check(not game_state.jobs[&"frozen_bath"]["unlocked"], "Заявка о замёрзшей ванне изначально скрыта")

	var source := RepairSimulationScript.new()
	source.apply_action(&"liliya", &"freeze")
	var source_result: Dictionary = source.get_completion_result()
	_check(str(source_result.get("follow_up", {}).get("type", "")) == "frozen_bath", "Заморозка лавового крана создаёт продолжение")
	game_state.completed_job_ids = PackedStringArray(["lava_leak"])
	game_state.job_reports = [{"job_id": "lava_leak", "completed_day": 1, "follow_up": source_result["follow_up"]}]
	game_state.day = 2
	game_state._unlock_frozen_bath_job_if_due()
	_check(game_state.is_job_available(&"frozen_bath"), "На следующий день открывается заявка о ванной")

	var scene := load("res://scenes/FrozenBathRoom.tscn") as PackedScene
	_check(scene != null, "Сцена замёрзшей ванной загружается")
	_check(load("res://assets/objects/frozen_bath/bath_frozen.png") != null and load("res://assets/objects/frozen_bath/bath_broken_empty.png") != null and load("res://assets/objects/frozen_bath/faucet_frozen.png") != null, "Переданные состояния ванны и крана импортированы")
	var room := scene.instantiate()
	var faucet := room.get_node("Faucet") as Control
	var source_scene := (load("res://scenes/RepairHouse.tscn") as PackedScene).instantiate()
	var source_faucet := source_scene.get_node("InteractiveObjects/LavaFaucet") as Control
	_check(faucet.position == source_faucet.position and faucet.size == source_faucet.size, "Кран использует размер и положение первой заявки")
	_check((room.get_node("FrozenBath") as TextureRect).size.x > 0.0 and (room.get_node("FrozenBath") as TextureRect).size.y > 0.0, "Ванна подключена отдельным настраиваемым слоем")
	_check((room.get_node("BrokenEmptyBath") as TextureRect).position == (room.get_node("BrokenBath") as TextureRect).position and (room.get_node("BrokenEmptyBath") as TextureRect).size == (room.get_node("BrokenBath") as TextureRect).size, "Пустая разбитая ванна совпадает с размером и положением ледяной")
	_check(room.has_node("Faucet/FrostOverlay"), "На повторно замерзающий кран добавлен отдельный слой инея")
	_check(room.has_node("PauseMenu") and not bool(room.get_node("PauseMenu").show_default_menu_button), "Esc-меню подключено без отдельной кнопки")
	room.free()
	source_scene.free()

	var heat_route := FrozenBathSimulationScript.new()
	_check(bool(heat_route.apply_action(&"liliya", &"heat")["resolved"]), "Магия огня устраняет замерзание")
	var antimagic_route := FrozenBathSimulationScript.new()
	_check(bool(antimagic_route.apply_action(&"nika", &"antimagic")["resolved"]), "Антимагия устраняет холодный след")
	_check(bool(antimagic_route.world_object["bath_still_frozen"]), "После антимагии лёд остаётся в ванне")
	_check(int(antimagic_route.get_completion_result()["reward_adjustment"]) < 0, "За оставшийся лёд жилец снижает оплату")
	_check(not antimagic_route.is_fully_resolved(), "После антимагии с ванной ещё можно взаимодействовать")
	antimagic_route.apply_action(&"liliya", &"heat")
	_check(antimagic_route.is_fully_resolved() and int(antimagic_route.get_completion_result()["reward_adjustment"]) == 0, "После антимагии лёд можно растопить и получить полную оплату")
	var regulator_route := FrozenBathSimulationScript.new()
	_check(not bool(regulator_route.apply_action(&"nika", &"install_regulator", false)["applied"]), "Без покупки регулятор установить нельзя")
	_check(bool(regulator_route.apply_action(&"nika", &"install_regulator", true)["resolved"]), "Купленный регулятор решает заявку")
	_check(not regulator_route.is_fully_resolved(), "Регулятор останавливает замерзание, но не растапливает ванну")
	_check(int(regulator_route.get_completion_result()["expense_reimbursement"]) == 280, "Стоимость установленного терморегулятора включается в оплату")
	regulator_route.apply_action(&"nika", &"telekinesis")
	_check(regulator_route.is_fully_resolved() and bool(regulator_route.world_object["ice_removed"]), "Ника убирает лёд из целой ванны и полностью завершает работу")
	var cleared_then_antimagic := FrozenBathSimulationScript.new()
	cleared_then_antimagic.apply_action(&"nika", &"telekinesis")
	var cleared_reaction := cleared_then_antimagic.get_employee_reaction(&"felix", &"antimagic")
	var cleared_result: Dictionary = cleared_then_antimagic.apply_action(&"felix", &"antimagic")
	var cleared_report: Dictionary = cleared_then_antimagic.get_completion_result()
	_check("уже убран" in cleared_reaction.to_lower(), "Феликс учитывает, что Ника уже убрала лёд")
	_check(not "лёд в ванне остался" in str(cleared_result["message"]).to_lower() and cleared_then_antimagic.is_fully_resolved(), "Результат антимагии не возвращает отсутствующий лёд")
	_check(not "лёд остался" in str(cleared_report["summary"]).to_lower() and int(cleared_report["reward_adjustment"]) == 0, "Итог заявки после телекинеза и антимагии считается полным")
	var boris_route := FrozenBathSimulationScript.new()
	_check(str(boris_route.apply_action(&"boris", &"diagnose")["message"]).is_empty() and "холодное отношение" in boris_route.get_employee_reaction(&"boris", &"diagnose"), "Осмотр Бориса объясняется его репликой без дублирующего системного сообщения")
	_check(not bool(boris_route.apply_action(&"boris", &"repair", false)["applied"]), "Борис не устанавливает отсутствующий регулятор")
	_check(bool(boris_route.apply_action(&"boris", &"repair", true)["resolved"]), "После покупки Борис устанавливает регулятор")
	var grog_route := FrozenBathSimulationScript.new()
	var impact: Dictionary = grog_route.apply_action(&"grog", &"physical_move")
	_check(bool(impact["applied"]) and not grog_route.is_resolved(), "Разбитый лёд не устраняет причину")
	_check("молот побольше" in grog_route.get_employee_reaction(&"grog", &"physical_move"), "Грог использует выбранную юмористическую реплику")
	_check(bool(grog_route.apply_action(&"liliya", &"heat")["resolved"]), "После силовой ошибки заявку всё ещё можно завершить")
	_check(bool(grog_route.world_object["bath_damaged"]), "Нагрев и антимагия не чинят разбитую ванну")
	_check(int(grog_route.get_completion_result()["compensation_cost"]) > 0, "Повреждение ванны создаёт претензию")
	var broken_antimagic_route := FrozenBathSimulationScript.new()
	broken_antimagic_route.apply_action(&"grog", &"physical_move")
	broken_antimagic_route.apply_action(&"felix", &"antimagic")
	_check(bool(broken_antimagic_route.world_object["bath_damaged"]) and int(broken_antimagic_route.get_completion_result()["compensation_cost"]) > 0, "Антимагия не восстанавливает разбитую Грогом ванну")
	broken_antimagic_route.apply_action(&"nika", &"telekinesis")
	_check(bool(broken_antimagic_route.world_object["ice_removed"]) and bool(broken_antimagic_route.world_object["bath_damaged"]), "Ника убирает лёд, не восстанавливая разбитую ванну")
	var refreeze_route := FrozenBathSimulationScript.new()
	refreeze_route.apply_action(&"liliya", &"freeze")
	_check(not bool(refreeze_route.world_object["ice_removed"]) and not bool(refreeze_route.world_object["cold_trace_removed"]) and bool(refreeze_route.world_object["bath_still_frozen"]) and bool(refreeze_route.world_object["extra_frost"]), "Повторная заморозка возвращает лёд и дополнительный иней на кран")
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("FROZEN BATH SMOKE TEST: PASS")
		quit(0)
	else:
		print("FROZEN BATH SMOKE TEST: FAIL (%d)" % failures.size())
		quit(1)
