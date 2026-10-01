extends SceneTree

const RepairSimulationScript := preload("res://scripts/repair_simulation.gd")

var failures := PackedStringArray()


func _initialize() -> void:
	var simulation: RefCounted = RepairSimulationScript.new()
	var previous_phrase := ""
	var seen_phrases: Dictionary = {}
	for attempt: int in range(20):
		var phrase: String = simulation.get_employee_reaction(&"grog", &"normal_force")
		_check(phrase != previous_phrase, "Реплика не повторяется два раза подряд")
		seen_phrases[phrase] = true
		previous_phrase = phrase
	_check(seen_phrases.size() > 1, "Используется больше одной реплики из утверждённого пула")

	var restored_simulation: RefCounted = RepairSimulationScript.new()
	restored_simulation.load_state(simulation.get_state())
	_check(
		restored_simulation.get_employee_reaction(&"grog", &"normal_force") != previous_phrase,
		"Последняя реплика учитывается после сохранения и загрузки"
	)

	if failures.is_empty():
		print("EMPLOYEE PHRASE RANDOMNESS SMOKE TEST: PASS")
		quit(0)
	else:
		print("EMPLOYEE PHRASE RANDOMNESS SMOKE TEST: FAIL (%d)" % failures.size())
		quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: %s" % message)
