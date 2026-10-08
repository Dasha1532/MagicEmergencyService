extends SceneTree

const Sim := preload("res://scripts/wardrobe_simulation.gd")
const Memory := preload("res://scripts/world_memory.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var sim: RefCounted = Sim.new()
	check("до послушания" in sim.get_employee_reaction(&"liliya", &"heat"), "Walking cabinet retains heat objection")
	sim.world_object["frozen"] = true
	check("Осторожно отогрею" in sim.get_employee_reaction(&"liliya", &"heat"), "Frozen state takes precedence over movement in heat reaction")
	sim.world_object["burning"] = true
	check("усилит пожар" in sim.get_employee_reaction(&"liliya", &"heat"), "Burning state takes precedence over frost in heat reaction")
	sim.world_object["destroyed"] = true
	check("пепел" in sim.get_employee_reaction(&"liliya", &"heat"), "Destroyed state takes precedence in heat reaction")
	sim.world_object["destroyed"] = false
	sim.world_object["burning"] = false
	sim.world_object.merge({"moving": false, "magic_level": 0, "temperature": -3, "frozen": true, "brittle": true, "position_zone": &"left_wall", "generated_completion": {"summary": "Шкаф отогрет, посуда цела.", "review": "Всё цело."}}, true)
	sim._sync_visual_state()
	check(sim.world_object["visual_state"] == &"frozen" and sim.world_object["uses_frozen_visual"], "Stationary frozen cabinet uses asset")
	var stationary: RefCounted = Sim.new()
	stationary.initialize_generated({"initial_state": {"moving": false, "magic_level": 0, "frozen": true, "brittle": true, "position_zone": &"left_wall", "generated_anomaly_id": "deep_freeze"}})
	check(stationary.physical_intents().is_empty() and not stationary.needs_anchor() and not stationary.needs_repair(), "Stationary frozen cabinet has no obsolete force, anchor or repair actions")
	check(Sim.Reactions.NO_FORCE_PHRASES.has(stationary.apply_action(&"grog", &"diagnose")["message"]), "Grog uses personal no-force pool after inspection")
	var first_grog_phrase: String = stationary.action_log.back()["result"]["message"]
	check(stationary.apply_action(&"grog", &"diagnose")["message"] != first_grog_phrase, "Grog inspection avoids immediate repeat")
	check(stationary.offers_force_inspection() and not Sim.new().offers_force_inspection(), "Grog inspection offered only without force actions")
	check("уже промёрз" in stationary.get_employee_reaction(&"liliya", &"freeze"), "Liliya freezing stationary ice does not use walking pool")
	check("Осторожно отогрею" in stationary.get_employee_reaction(&"liliya", &"heat"), "Liliya thawing uses cold pool")
	check("двиг" not in stationary.get_employee_reaction(&"boris", &"repair"), "Boris does not invent movement in stationary repair response")
	check("Древесина промёрзла" in stationary.get_employee_reaction(&"nika", &"telekinesis"), "Nika uses frozen state response")
	check("Оживляющих чар здесь нет" in stationary.get_employee_reaction(&"felix", &"antimagic"), "Felix does not promise removing nonexistent animation")
	stationary.world_object["burning"] = true
	check("Потушу" in stationary.get_employee_reaction(&"liliya", &"freeze"), "Fire extinguishing outranks frost and movement")
	stationary.world_object["burning"] = false
	check("движ" not in stationary.apply_action(&"boris", &"diagnose")["message"], "Stationary diagnosis does not claim movement stopped")
	var stationary_loaded: RefCounted = Sim.new()
	stationary_loaded.load_state(JSON.parse_string(JSON.stringify(stationary.get_state())))
	check(not stationary_loaded.world_object["movement_seen"], "Stationary movement history survives reload")
	check("уже промёрз" in stationary_loaded.get_employee_reaction(&"liliya", &"freeze"), "Correct cold reaction survives reload")
	var previous_phrase: String = stationary_loaded.apply_action(&"grog", &"diagnose")["message"]
	var observed_phrases := {}
	for attempt: int in 20:
		var phrase: String = stationary_loaded.apply_action(&"grog", &"diagnose")["message"]
		check(phrase != previous_phrase and Sim.Reactions.NO_FORCE_PHRASES.has(phrase), "Grog inspection stays in its pool without adjacent repeats")
		observed_phrases[phrase] = true
		previous_phrase = phrase
	check(observed_phrases.size() > 1, "Grog inspection uses several phrases")
	var phrase_reload: RefCounted = Sim.new()
	phrase_reload.load_state(JSON.parse_string(JSON.stringify(stationary_loaded.get_state())))
	check(phrase_reload.apply_action(&"grog", &"diagnose")["message"] != previous_phrase, "No-force repetition protection survives reload")
	var moving_profile: RefCounted = Sim.new()
	check("ненадолго" in moving_profile.get_employee_reaction(&"liliya", &"freeze"), "Walking freeze retains appropriate pool")
	check("Осталось договориться" in moving_profile.get_employee_reaction(&"nika", &"telekinesis"), "Nika walking reaction remains available")
	check("Чары сниму" in moving_profile.get_employee_reaction(&"felix", &"antimagic"), "Felix animation reaction remains available")
	moving_profile.apply_action(&"felix", &"antimagic")
	check("Чары сниму" not in moving_profile.get_employee_reaction(&"felix", &"antimagic"), "Removed magic does not keep animation reaction")
	stationary.world_object["moving"] = true
	stationary._sync_visual_state()
	stationary.world_object["moving"] = false
	check("больше не движется" in stationary._describe_current_hazard(), "Movement introduced during work is remembered")
	check(not Sim.new().physical_intents().is_empty() and Sim.new().needs_anchor(), "Walking cabinet retains relevant force and anchor actions")
	sim.world_object["magic_level"] = 6
	sim.world_object["moving"] = true
	sim._sync_visual_state()
	check(sim.world_object["visual_state"] == &"walking" and not sim.world_object["uses_frozen_visual"], "Animated frozen cabinet retains walking pose and frost")
	# Проверяем ущерб на движущемся шкафу, для которого доступно силовое действие.
	sim.world_object.merge({"magic_level": 6, "moving": true, "frozen": false}, true)
	var damage: Dictionary = sim.apply_action(&"grog", &"physical_move", &"break_legs")
	check(damage["caused_damage"] and not damage["damage_target_ids"].is_empty(), "Damage has typed target events")
	sim.apply_action(&"liliya", &"heat")
	check(not sim.world_object["brittle"] and not sim.world_object["frozen"], "Thaw removes cold brittleness")
	var result: Dictionary = sim.get_completion_result()
	check(int(result["reward_adjustment"]) < 0 and "Всё цело" != str(result["review"]), "Damage cannot use success template")
	var loaded: RefCounted = Sim.new()
	loaded.load_state(JSON.parse_string(JSON.stringify(sim.get_state())))
	check(loaded.world_object["damage"] == sim.world_object["damage"] and loaded.world_object["visual_state"] == sim.world_object["visual_state"], "Reload preserves damage and visual")
	var memory: RefCounted = Memory.new()
	memory.reset()
	memory.ensure_job_context(&"wardrobe_contract", {}, String(sim.world_object["instance_id"]), {"resident_id": "eleonora"})
	memory.record_job_state(&"wardrobe_contract", sim.get_state(), 2, 550)
	check(str(memory.get_relation("eleonora", "grog").get("access_status", "")) == "warned", "Client remembers furniture damage immediately")
	var natural_fire: RefCounted = Sim.new()
	natural_fire.world_object["burning"] = true
	natural_fire.apply_action(&"boris", &"diagnose")
	check(str(natural_fire.world_object.get("fire_origin_employee_id", "")).is_empty(), "Inspection cannot make employee responsible for pre-existing fire")
	var ignited: RefCounted = Sim.new()
	ignited.apply_action(&"liliya", &"heat")
	ignited.advance_burning()
	check(ignited.world_object["fire_origin_employee_id"] == "liliya" and not ignited.action_log.back()["result"]["damage_target_ids"].is_empty(), "Fire spread preserves culprit and typed damage")
	var body: RefCounted = Sim.new()
	body.world_object.merge({"damage": 2, "anchored": true, "moving": false}, true)
	var repaired: Dictionary = body.apply_action(&"boris", &"repair")
	check(not body.world_object["moving"] and "ножки" not in str(repaired["message"]), "Body repair neither invents broken legs nor removes anchoring")
	var deep_cold: RefCounted = Sim.new()
	deep_cold.world_object.merge({"temperature": -13, "frozen": true, "brittle": true}, true)
	deep_cold.apply_action(&"liliya", &"heat")
	check(deep_cold.world_object["frozen"] and deep_cold.world_object["brittle"], "Insufficient heating cannot thaw deeply frozen wood")
	var scene = load("res://scenes/WardrobeRoom.tscn").instantiate()
	var careful: RefCounted = Sim.new()
	check(careful.physical_intents().any(func(choice: Dictionary) -> bool: return choice["id"] == &"move_left_careful"), "Careful move is available without telekinesis")
	careful.apply_action(&"grog", &"physical_move", &"move_left_careful")
	check(careful.world_object["position_zone"] == &"left_wall" and careful.world_object["contents_damage"] == 0 and careful.world_object["damage"] == 0, "Careful move preserves cabinet and contents")
	var damaged_moves := 0
	var dishes: RefCounted = Sim.new()
	var last_reaction := ""
	var hit_count := 0
	for attempt: int in 100:
		var old_damage: int = dishes.world_object["contents_damage"]
		var hit: Dictionary = dishes.apply_action(&"grog", &"physical_move", &"move_left_fast" if attempt % 2 == 0 else &"move_kitchen_fast")
		if int(dishes.world_object["contents_damage"]) > old_damage:
			hit_count += 1
			var reaction: String = hit.get("resident_message", "")
			check(Sim.Reactions.DISH_BREAK_PHRASES.has(reaction) and reaction != last_reaction, "Each new dish damage triggers approved phrase without adjacent repeat")
			last_reaction = reaction
			var report: Dictionary = dishes.get_completion_result()
			check(Sim.Reactions.CONTENTS_REPORTS[hit_count] in report["summary"] and report["contents_state"] == Sim.Reactions.CONTENTS_STATES[hit_count], "Report describes part, half or all dishes")
			check(int(report["reward_adjustment"]) == -35 * hit_count - (60 if dishes.world_object["position_zone"] != dishes.world_object["requested_zone"] else 0), "Dish withholding follows three damage stages")
			var round_trip: RefCounted = Sim.new()
			round_trip.load_state(JSON.parse_string(JSON.stringify(dishes.get_state())))
			check(round_trip.last_dish_break_phrase == dishes.last_dish_break_phrase and round_trip.world_object["contents_state"] == dishes.world_object["contents_state"], "Dish state and last phrase survive reload")
		else:
			check(not hit.has("resident_message") and not hit.get("contents_damaged", false), "No dish break produces no dish reaction")
	check(hit_count == 3 and dishes.world_object["contents_damage"] == 3, "All dishes break after three hits; further moves do not increase damage")
	var legacy_dishes: RefCounted = Sim.new()
	legacy_dishes.load_state({"world_object": {"contents_damage": 6, "destroyed": true}})
	check(legacy_dishes.world_object["contents_state"] == "all_broken" and legacy_dishes.world_object["contents_damage"] == 3, "Old six-point destruction migrates to all broken dishes")
	var safe_moves := 0
	for attempt: int in 100:
		var fast: RefCounted = Sim.new()
		var move: Dictionary = fast.apply_action(&"grog", &"physical_move", &"move_left_fast")
		check(fast.world_object["damage"] == 0, "Fast move never damages cabinet body")
		if fast.world_object["contents_damage"] > 0:
			damaged_moves += 1
			check(move["caused_damage"] and "посуды" in fast.get_completion_result()["review"], "Broken dishes generate damage event and property review")
			var restored: RefCounted = Sim.new()
			restored.load_state(JSON.parse_string(JSON.stringify(fast.get_state())))
			check(restored.world_object["contents_damage"] == 1, "Dish damage survives save round trip")
		else:
			safe_moves += 1
	check(damaged_moves > 0 and safe_moves > 0, "Fast move can preserve or damage contents")
	var fire_message: RefCounted = Sim.new()
	fire_message.world_object.merge({"burning": true, "temperature": 12, "moving": false, "magic_level": 0, "movement_seen": false}, true)
	var diagnosis: String = fire_message.apply_action(&"boris", &"diagnose")["message"]
	check(diagnosis.count("горит") == 1 and "дополнительная опасность" not in diagnosis, "Fire diagnosis does not repeat fire state")
	var cooling: String = fire_message.apply_action(&"liliya", &"freeze")["message"]
	check(cooling.count("горит") == 1 and "дополнительная опасность" not in cooling, "Insufficient cooling does not repeat fire state")
	fire_message.world_object["generated_resident_request"] = "Шкаф сам загорелся! Потушите его скорее, пока от мебели и посуды ничего не осталось!"
	check("пока огонь не добрался до посуды!" in fire_message.get_resident_request(), "Existing saved request receives corrected wording")
	var fire_definition = load("res://data/anomalies/active_fire.tres")
	var thaw_cycle: RefCounted = Sim.new()
	thaw_cycle.world_object.merge({"burning": true, "temperature": 7, "moving": false, "magic_level": 0}, true)
	thaw_cycle.apply_action(&"liliya", &"freeze")
	check(not thaw_cycle.world_object["burning"] and not thaw_cycle.world_object["frozen"] and not thaw_cycle.world_object["brittle"], "Extinguishing warm wood does not leave false frost")
	thaw_cycle.apply_action(&"liliya", &"freeze")
	check(thaw_cycle.world_object["frozen"], "Further cooling really freezes wood")
	thaw_cycle.apply_action(&"liliya", &"heat")
	check(not thaw_cycle.world_object["frozen"] and not thaw_cycle.world_object["burning"], "Frozen extinguished cabinet thaws without catching fire")
	check("пока огонь не добрался до посуды!" in str(fire_definition.presentation["resident_request"]), "New fire requests use corrected wording")
	check(scene.get_node("Wardrobe/Frozen").texture != null, "Editable frozen asset is connected")
	scene.free()
	print("Wardrobe object contract: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
