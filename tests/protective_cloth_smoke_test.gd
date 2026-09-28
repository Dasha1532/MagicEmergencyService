extends SceneTree

const PortalMirrorSimulationScript := preload("res://scripts/portal_mirror_simulation.gd")

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.start_new_game()
	_check(game_state.SUPPLY_ITEMS.has(&"protective_cloth"), "Защитное полотно добавлено в каталог")
	_check(int(game_state.SUPPLY_ITEMS[&"protective_cloth"]["price"]) == 50, "Защитное полотно стоит 50 монет")
	_check(load(str(game_state.SUPPLY_ITEMS[&"protective_cloth"]["icon"])) != null, "Ассет защитного полотна загружается")
	_check(game_state.buy_supply_item(&"protective_cloth"), "Защитное полотно покупается в лавке")
	_check(game_state.has_supply_item(&"protective_cloth"), "Купленное полотно поступает на склад")

	var simulation: RefCounted = PortalMirrorSimulationScript.new()
	var installed: Dictionary = simulation.apply_action(&"boris", &"cover", game_state.has_supply_item(&"protective_cloth"))
	_check(bool(installed["applied"]), "Борис устанавливает купленное полотно")
	_check(game_state.consume_supply_item(&"protective_cloth"), "Установленное полотно списывается со склада")
	_check(not game_state.has_supply_item(&"protective_cloth"), "Установленного полотна больше нет на складе")
	_check(int(simulation.get_completion_result()["expense_reimbursement"]) == 50, "Стоимость оставленного полотна включается в акт")

	var removed: Dictionary = simulation.apply_action(&"boris", &"uncover", false)
	_check(bool(removed["applied"]), "Борис может снять установленное полотно")
	game_state.return_supply_item(&"protective_cloth")
	_check(game_state.has_supply_item(&"protective_cloth"), "Снятое полотно возвращается на склад")
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("PROTECTIVE CLOTH SMOKE TEST: PASS")
		quit(0)
	else:
		print("PROTECTIVE CLOTH SMOKE TEST: FAIL (%d)" % failures.size())
		quit(1)
