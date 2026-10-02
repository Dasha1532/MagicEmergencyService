extends SceneTree

const Generator = preload("res://scripts/generated_job_generator.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var state = root.get_node("GameState")
	state.start_new_game()
	state.skip_tutorial()
	state.world_memory.reset()
	state.world_memory.get_or_create_relation("ragnar", "liliya")["access_status"] = "banned"
	var context: Dictionary = state._generation_context()
	var abilities: PackedStringArray = state._available_ability_ids()
	_check(not state._available_ability_ids("ragnar").has("heat"), "Banned heat provider counted")
	_check(state._available_ability_ids("eleonora").has("heat"), "Ban leaked to another client")
	_check(Generator.generate_tutorial_faucet(17, abilities, [], context).is_empty(), "Impossible faucet published")
	for seed_value in range(1, 40):
		_check(not Generator.generate(seed_value, abilities, [], context).is_empty(), "Solvable wardrobe missing")
	var event := {"event_id": "solvability.test", "event_type": "faucet_freeze", "payload": {"anomaly_id": "faucet_freeze"}}
	_check(Generator.generate_faucet_consequence(event, abilities, context).is_empty(), "Impossible consequence published")
	_check(state.world_memory.get_relation("ragnar", "liliya")["access_status"] == "banned", "Generator removed ban")
	state.employees[&"nika"]["available"] = true
	state.employees[&"nika"]["abilities"] = PackedStringArray(["heat"])
	state.employees[&"nika"]["return_until"] = state.time_minutes + 60
	context = state._generation_context()
	_check(not Generator.generate_faucet_consequence(event, abilities, context).is_empty(), "Busy admitted alternate ignored")
	var faucet: Dictionary = Generator.generate_tutorial_faucet(17, abilities, ["faucet_freeze"], context)
	_check(str(faucet.get("anomaly_id", "")) == "faucet_freeze", "History excluded only solvable anomaly")
	state.employees[&"boris"]["return_until"] = state.time_minutes + 60
	var profile: Dictionary = state.RESTORATION_PROFILE.base_properties
	_check(state._has_admitted_restoration_crew("ragnar", profile), "Busy installer ignored")
	state.world_memory.get_or_create_relation("ragnar", "boris")["access_status"] = "banned"
	_check(not state._has_admitted_restoration_crew("ragnar", profile), "Banned installer counted")
	state.world_memory.get_or_create_relation("ragnar", "boris")["access_status"] = "allowed"
	state.employees[&"boris"]["available"] = false
	_check(not state._has_admitted_restoration_crew("ragnar", profile), "Unhired installer counted")
	state.employees[&"boris"]["available"] = true
	state.employees[&"nika"]["available"] = false
	state.world_memory.queue_consequence(&"test_freeze", &"faucet_freeze", "old_quarter_5.bathroom.lava_faucet", &"test_source", state.day, state.time_minutes, 100, {"anomaly_id": "faucet_freeze"}, "test_chain", "", 1)
	state._publish_due_world_consequences()
	_check(state.world_memory.due_consequences(state.day, state.time_minutes).size() == 1, "Impossible event lost")
	state.world_memory.get_or_create_relation("ragnar", "liliya")["access_status"] = "warned"
	state._publish_due_world_consequences()
	_check(state.world_memory.due_consequences(state.day, state.time_minutes).is_empty(), "Event not retried after admission restored")
	var only_repair := {"client_capabilities": {"eleonora": PackedStringArray(["repair"])}}
	_check(Generator.generate(5, abilities, [], only_repair).is_empty(), "Incomplete mandatory action set accepted")
	var relocation := {"client_capabilities": {"eleonora": PackedStringArray(["repair", "physical_move"])}}
	for seed_value in range(1, 40):
		var wardrobe: Dictionary = Generator.generate(seed_value, abilities, ["restless_animation"], relocation)
		_check(str(wardrobe.get("anomaly_id", "")) == "restless_animation", "Random choice missed the only complete plan")
	if failures.is_empty():
		print("Client solvability smoke test: PASS")
	quit(0 if failures.is_empty() else 1)
