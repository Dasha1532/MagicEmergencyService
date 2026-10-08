extends "res://scripts/game_state.gd"
# Tests use a separate in-memory campaign; never touch player saves.
func save_autosave() -> Error:
	return OK
static func install(scene_root: Window) -> Node:
	var previous := scene_root.get_node("GameState")
	scene_root.remove_child(previous)
	previous.free()
	var test_state := load("res://tests/prison_test_state.gd").new() as Node
	test_state.name = "GameState"
	scene_root.add_child(test_state)
	return test_state
func prepare_prison(crew: PackedStringArray) -> void:
	completed_job_ids = get_demo_prerequisite_job_ids()
	active_job_id = &"prison_lock"
	jobs[&"prison_lock"]["assigned"] = crew
	jobs[&"prison_lock"]["dispatched"] = true
	for id: String in crew:
		employees[StringName(id)]["available"] = true
		employees[StringName(id)]["arrival_until"] = 0
		employees[StringName(id)]["return_until"] = 0
	clock_paused = true
