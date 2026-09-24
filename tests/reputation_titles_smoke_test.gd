extends SceneTree

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.start_new_game()
	_check(game_state.get_reputation_titles() == PackedStringArray(["Новая служба"]), "Без истории служба получает нейтральное прозвище")

	game_state.job_reports = [
		_report("one", 0, "none", ["freeze", "heat"], ["Лилия Морозова"]),
		_report("two", 0, "none", ["repair"], ["Борис Медяк"]),
		_report("three", 0, "none", ["animate"], ["Ника Искра"]),
	]
	var careful_titles: PackedStringArray = game_state.get_reputation_titles()
	_check(careful_titles.has("Безупречные мастера"), "Три чистых ремонта дают прозвище за аккуратность")
	_check(careful_titles.has("Смелые экспериментаторы"), "Четыре типа действий дают прозвище за разнообразие")

	game_state.job_reports = [
		_report("damage_one", 300, "denied", ["physical_move"], ["Грог Кувалда"]),
		_report("damage_two", 220, "denied", ["physical_move"], ["Грог Кувалда"]),
	]
	var destructive_titles: PackedStringArray = game_state.get_reputation_titles()
	_check(destructive_titles == PackedStringArray(["Скупая контора", "Гроза интерьеров"]), "Отказы и ущерб получают приоритетные прозвища")
	game_state.job_reports[0]["claim_status"] = "paid_after_denial"
	game_state.job_reports[1]["claim_status"] = "paid_after_denial"
	_check(not game_state.get_reputation_titles().has("Скупая контора"), "Поздние выплаты снимают прозвище за действующие отказы")
	_finish()


func _report(job_id: String, claim_amount: int, claim_status: String, action_ids: Array[String], crew: Array[String]) -> Dictionary:
	var actions: Array[Dictionary] = []
	for action_id: String in action_ids:
		actions.append({"action_id": action_id})
	return {
		"job_id": job_id,
		"claim_amount": claim_amount,
		"claim_status": claim_status,
		"reputation_change": 1 if claim_amount == 0 else -2,
		"overdue": false,
		"actions": actions,
		"crew": crew,
	}


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("REPUTATION TITLES SMOKE TEST: PASS")
		quit(0)
	else:
		print("REPUTATION TITLES SMOKE TEST: FAIL (%d)" % failures.size())
		quit(1)
