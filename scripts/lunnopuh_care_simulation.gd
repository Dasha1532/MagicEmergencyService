class_name LunnopuhCareSimulation
extends "res://scripts/portal_mirror_simulation.gd"

const CARE := preload("res://data/objects/lunnopuh_care.tres")

func _init() -> void:
	super()
	world_object.merge(CARE.base_properties["initial_state"], true)
	world_object["resolution"] = CARE.base_properties["resolution"].duplicate(true)
	world_object["source_damage"] = 0
	world_object["source_destroyed"] = false

func initialize_from_job(job: Dictionary) -> void:
	world_object.merge(job.get("object_initial_state", {}), true)
	world_object.merge(CARE.base_properties["initial_state"], true)
	world_object["resolution"] = CARE.base_properties["resolution"].duplicate(true)
	world_object["initial_cold_aura"] = bool(world_object["cold_aura"])
	world_object["source_damage"] = int(world_object["damage"])
	world_object["source_destroyed"] = bool(world_object["destroyed"])

func get_resident_request() -> String:
	return str(CARE.base_properties["request_open" if bool(world_object["portal_open"]) and not bool(world_object["destroyed"]) else "request_closed"])

func available_actions(employee_id: StringName = &"") -> PackedStringArray:
	var actions := super.available_actions(employee_id)
	actions.erase("install_cage")
	actions.erase("cover")
	actions.erase("uncover")
	if employee_id == &"boris" and not bool(world_object["inspected"]):
		return PackedStringArray(["diagnose"])
	if employee_id in [&"boris", &"grog", &"nika"] and bool(world_object["portal_open"]) and not bool(world_object["destroyed"]):
		actions.append("uncover" if bool(world_object["covered"]) else "cover")
	return actions

func lunnopuh_actions(employee_id: StringName) -> PackedStringArray:
	if str(world_object["lunnopuh_state"]) != "caged":
		return PackedStringArray()
	if employee_id == &"boris" and not bool(world_object["lunnopuh_inspected"]):
		return PackedStringArray(["diagnose"])
	var actions := PackedStringArray()
	for action: String in CARE.base_properties["object_actions"]:
		var profile: Dictionary = CARE.base_properties["object_actions"][action]
		if not PackedStringArray(profile["employee_ids"]).has(String(employee_id)):
			continue
		if action == "return_lunnopuh" and not bool(lunnopuh_properties()["portal_available"]):
			continue
		actions.append(action)
	for action: String in ["freeze", "heat", "animate", "antimagic"]:
		actions.append(action)
	if employee_id == &"nika":
		actions.append("telekinesis")
	return actions

func lunnopuh_refusal(action_id: StringName, has_cage: bool = true) -> String:
	if action_id == &"antimagic" and (not bool(world_object["portal_open"]) or bool(world_object["destroyed"])):
		return str(CARE.base_properties["closed_antimagic_refusal"])
	return super.lunnopuh_refusal(action_id, has_cage)

func care_reaction(employee_id: StringName, action_id: StringName) -> String:
	var profile: Dictionary = CARE.base_properties["object_actions"].get(String(action_id), {})
	return str((profile.get("reactions", {}) as Dictionary).get(String(employee_id), profile.get("reaction", "")))

func apply_lunnopuh_action(employee_id: StringName, action_id: StringName) -> Dictionary:
	action_before = _object_snapshots()
	if not lunnopuh_actions(employee_id).has(String(action_id)):
		return _record(employee_id, action_id, false, true, "Это действие сейчас недоступно для Лунопуха.")
	var refusal := lunnopuh_refusal(action_id)
	if not refusal.is_empty():
		return _record(employee_id, action_id, false, true, refusal)
	var profile: Dictionary = CARE.base_properties["object_actions"].get(String(action_id), {})
	if profile.is_empty():
		return _record(employee_id, action_id, false, true, "Сначала откройте путь в портал: снимите защитное полотно.")
	world_object.merge(profile.get("effects", {}), true)
	var message := str(CARE.base_properties["diagnosis_open" if bool(world_object["portal_open"]) and not bool(world_object["destroyed"]) else "diagnosis_closed"]) if action_id == &"diagnose" else str(profile["message"])
	return _record(employee_id, action_id, true, false, message)

func apply_action(employee_id: StringName, action_id: StringName, has_protective_cloth: bool = true) -> Dictionary:
	if not available_actions(employee_id).has(String(action_id)):
		action_before = _object_snapshots()
		return _record(employee_id, action_id, false, true, "Это действие сейчас недоступно для зеркала.")
	return super.apply_action(employee_id, action_id, has_protective_cloth)

func get_completion_result() -> Dictionary:
	if not is_resolved():
		return {}
	var pet_state := str(world_object["lunnopuh_state"])
	var summary := "Лунопух возвращён в родной мир." if pet_state == "returned" else "Лунопух передан под опеку приюта для магических существ."
	var facts: Array[String] = [summary]
	facts.append("Портал изолирован защитным полотном." if bool(world_object["covered"]) else "Зеркало разбито, портала нет." if bool(world_object["destroyed"]) else "Портал закрыт.")
	var new_damage := int(world_object["damage"]) > int(world_object["source_damage"])
	var cold_remains := bool(world_object["cold_aura"])
	var review := str(CARE.base_properties["reviews"][pet_state])
	var new_destroyed := bool(world_object["destroyed"]) and not bool(world_object["source_destroyed"])
	if int(world_object["damage"]) > 0:
		facts.append("Зеркало повреждено при выполнении работ." if new_damage else "Прежнее повреждение зеркала сохранилось.")
	if bool(world_object["cold_aura"]):
		facts.append("В комнате сохранился холод от портала.")
	var mirror_changed := false
	for entry: Dictionary in action_log:
		for change: Dictionary in entry.get("object_changes", []):
			if str(change.get("target_instance_id", "")) == "portal_mirror_room.portal_mirror":
				var before: Dictionary = change["before"]
				var after: Dictionary = change["after"]
				for property: String in ["portal_open", "covered", "cold_aura", "damage", "destroyed"]:
					if before.get(property) != after.get(property):
						mirror_changed = true
	if new_damage or mirror_changed:
		review += " " + str(_completion_from_properties()["review"])
	var helpful := PackedStringArray()
	for entry: Dictionary in action_log:
		if not bool(entry["result"].get("applied", false)) or bool(entry["result"].get("caused_damage", false)):
			continue
		for change: Dictionary in entry.get("object_changes", []):
			var before: Dictionary = change["before"]
			var after: Dictionary = change["after"]
			var useful := (str(before.get("state", "")) == "caged" and str(after.get("state", "")) in ["returned", "transferred"]) or (bool(before.get("portal_open", false)) and not bool(after.get("portal_open", false))) or (bool(before.get("cold_aura", false)) and not bool(after.get("cold_aura", false))) or (not bool(before.get("covered", false)) and bool(after.get("covered", false)))
			if useful and not helpful.has(str(entry["employee_id"])):
				helpful.append(str(entry["employee_id"]))
	return {
		"summary": " ".join(facts), "review": review, "consequences": facts,
		"actions": action_log.duplicate(true),
		"reward_adjustment": -200 if new_destroyed else (-int(world_object["frame_damage_payment_penalty"]) if new_damage else 0) - (int(world_object["cold_cover_payment_penalty"]) if cold_remains else 0),
		"forfeit_payment": new_destroyed,
		"compensation_cost": int(world_object["compensation_value"]) if new_destroyed else 0,
		"reputation_change": -2 if new_damage else -1 if cold_remains else 1,
		"expense_reimbursement": 0, "returned_supply_items": ["lunnopuh_cage"],
		"completion_object_updates": {"cage_state": "packed"},
		"completion_related_updates": {"portal_mirror_room.lunnopuh_cage": {"state": "packed"}},
		"successful_employee_ids": Array(helpful), "credit_helpful_work_on_damage": true,
	}
