class_name GhostFollowupSimulation
extends RefCounted

const GHOST := preload("res://data/objects/escaped_ghost.tres")
const MIRROR := preload("res://data/objects/haunted_portal_mirror.tres")
const SharedMirror := preload("res://scripts/portal_mirror_simulation.gd")
const Rules := preload("res://scripts/object_interaction_rules.gd")

var world_object: Dictionary = GHOST.base_properties["initial_state"].duplicate(true)
var action_log: Array[Dictionary] = []
var pending_actor_action: Dictionary = {}
var interaction_target: StringName = &"ghost"
var last_snapshot: Dictionary = {}


func load_state(saved_state: Dictionary) -> void:
	world_object.merge((saved_state.get("world_object", {}) as Dictionary).duplicate(true), true)
	world_object["definition_id"] = &"portal_mirror"
	if not (saved_state.get("world_object", {}) as Dictionary).has("source_frame_damage"):
		world_object["source_frame_damage"] = int(world_object.get("frame_damage", 0))
	pending_actor_action = (saved_state.get("pending_actor_action", {}) as Dictionary).duplicate(true)
	action_log.clear()
	for entry: Dictionary in saved_state.get("action_log", []):
		action_log.append(entry.duplicate(true))
		if str(entry.get("employee_id", "")) == "boris" and str(entry.get("action_id", "")) == "diagnose":
			world_object["ghost_inspected"] = true
	# Old saves recorded destruction without object transitions. Preserve its author.
	if str(world_object["mirror_state"]) == "destroyed":
		for entry: Dictionary in action_log:
			if str(entry.get("action_id", "")) == "physical_move" and bool(entry.get("result", {}).get("applied", false)) and entry.get("object_changes", []).is_empty():
				var after := snapshots()
				var before := after.duplicate(true)
				before["portal_mirror_room.portal_mirror"]["destroyed"] = false
				before["portal_mirror_room.portal_mirror"]["damage"] = int(world_object.get("frame_damage", 0))
				entry.merge(Rules.action_event(StringName(str(entry["employee_id"])), &"physical_move", before, after, entry["result"]), true)
	last_snapshot = snapshots()


func get_state() -> Dictionary:
	var objects := snapshots()
	var saved_world := world_object.duplicate(true)
	saved_world.merge(objects["portal_mirror_room.portal_mirror"], true)
	return {"world_object": saved_world, "related_objects": {"portal_mirror_room.escaped_ghost": objects["portal_mirror_room.escaped_ghost"], "portal_mirror_room.ghost_trap": objects["portal_mirror_room.ghost_trap"]}, "action_log": action_log.duplicate(true), "pending_actor_action": pending_actor_action.duplicate(true), "boris_inspected_objects": (["Привидение"] if bool(world_object.get("ghost_inspected", false)) else []) + (["Зеркало"] if bool(world_object.get("mirror_inspected", false)) else [])}


func snapshots() -> Dictionary:
	var mirror := {"definition_id": "portal_mirror", "frame_damage": int(world_object.get("frame_damage", 0)), "lunnopuh_state": str(world_object.get("lunnopuh_state", "absent")), "cage_state": str(world_object.get("cage_state", "packed"))}
	mirror["portal_open"] = str(world_object["mirror_state"]) in ["covered", "open"]
	mirror["covered"] = str(world_object["mirror_state"]) == "covered"
	mirror["destroyed"] = str(world_object["mirror_state"]) == "destroyed"
	mirror["damage"] = maxi(10, int(world_object.get("frame_damage", 0))) if mirror["destroyed"] else int(world_object.get("frame_damage", 0))
	mirror["visual_state"] = String(mirror_visual_state())
	for key: String in ["temperature", "magic_level", "stable", "cold_aura"]:
		mirror[key] = world_object[key]
	return {"portal_mirror_room.portal_mirror": mirror, "portal_mirror_room.escaped_ghost": {"state": str(world_object["ghost_state"]), "inspected": bool(world_object.get("ghost_inspected", false)), "damage": 0}, "portal_mirror_room.ghost_trap": {"state": str(world_object["trap_state"]), "damage": 0}}


func can_begin_action(action_id: StringName) -> bool:
	return action_id == &"diagnose" or bool(world_object.get(String(interaction_target) + "_inspected", false))


func properties(target: StringName, context: Dictionary = {}) -> Dictionary:
	var properties := world_object.duplicate(true)
	properties.merge(context, true)
	properties["covered"] = str(world_object["mirror_state"]) == "covered"
	properties["ghost_present"] = str(world_object["ghost_state"]) in ["calm", "angry"]
	properties["trap_ready"] = str(world_object["trap_state"]) == "installed"
	properties["trap_packed"] = str(world_object["trap_state"]) == "packed"
	properties["action_refusal_rules"] = (GHOST if target == &"ghost" else MIRROR).base_properties["action_refusal_rules"]
	return properties


func shared_mirror() -> RefCounted:
	var mirror := SharedMirror.new()
	mirror.world_object.merge(snapshots()["portal_mirror_room.portal_mirror"], true)
	mirror.world_object["initial_cold_aura"] = bool(world_object.get("initial_cold_aura", false))
	mirror.world_object["inspected"] = bool(world_object.get("mirror_inspected", false))
	return mirror


func is_shared_mirror_action(action_id: StringName) -> bool:
	return PackedStringArray(MIRROR.base_properties.get("shared_mirror_actions", [])).has(String(action_id))


func get_mirror_reaction(employee_id: StringName, action_id: StringName, has_cloth: bool) -> String:
	return shared_mirror().get_employee_reaction(employee_id, action_id, has_cloth)


func refusal_message(target: StringName, action_id: StringName, context: Dictionary = {}) -> String:
	if target == &"mirror" and is_shared_mirror_action(action_id):
		return shared_mirror().refusal_message(action_id, bool(context.get("protective_cloth_available", true)))
	return Rules.state_refusal_message(action_id, properties(target, context))


func _matches(expected: Dictionary, actual: Dictionary) -> bool:
	for key: String in expected:
		if actual.get(key) != expected[key]:
			return false
	return true


func can_employee_perform(target: StringName, action_id: StringName, employee_id: StringName) -> bool:
	var profile: Dictionary = (GHOST if target == &"ghost" else MIRROR).base_properties["object_actions"].get(String(action_id), {})
	var employees := PackedStringArray(profile.get("employee_ids", []))
	return employees.is_empty() or employees.has(String(employee_id))


func perform(target: StringName, employee_id: StringName, action_id: StringName, context: Dictionary = {}) -> Dictionary:
	last_snapshot = snapshots()
	if not can_employee_perform(target, action_id, employee_id):
		return _record(employee_id, action_id, false, true, "Установить ловушку может Борис." if action_id == &"install_trap" else "Снять полотно могут Борис, Грог или Ника.")
	var refusal := refusal_message(target, action_id, context)
	if not refusal.is_empty():
		return _record(employee_id, action_id, false, true, refusal)
	if target == &"mirror" and is_shared_mirror_action(action_id):
		var mirror: RefCounted = shared_mirror()
		var result: Dictionary = mirror.apply_action(employee_id, action_id)
		for key: String in ["temperature", "magic_level", "stable", "cold_aura"]:
			world_object[key] = mirror.world_object[key]
		world_object["frame_damage"] = int(mirror.world_object["damage"])
		return _record(employee_id, action_id, bool(result["applied"]), bool(result["warning"]), str(result["message"]))
	var profile: Dictionary = (GHOST if target == &"ghost" else MIRROR).base_properties["object_actions"].get(String(action_id), {})
	if profile.is_empty():
		return _record(employee_id, action_id, false, true, "Это действие не поможет поймать привидение.")
	var current := properties(target, context)
	var message := str(profile["message"])
	if action_id == &"diagnose" and target == &"mirror":
		message = "Зеркало разбито. Магическая связь с привидением оборвана." if str(world_object["mirror_state"]) == "destroyed" else "Портал закрыт. Зеркало снова стало обычным." if str(world_object["mirror_state"]) == "closed" else "Портал скрыт полотном. Сначала нужно открыть путь обратно, а затем закрыть портал." if str(world_object["mirror_state"]) == "covered" else "Портал открыт. После возвращения или поимки привидения его нужно закрыть."
		if int(world_object.get("frame_damage", 0)) > 0:
			message += " Рама деформирована после нагрева."
	for variant: Dictionary in profile.get("variants", []):
		if _matches(variant["equals"], current):
			message = str(variant["message"])
	world_object.merge(profile.get("effects", {}), true)
	for effect: Dictionary in profile.get("conditional_effects", []):
		if _matches(effect["equals"], current):
			world_object.merge(effect["effects"], true)
	return _record(employee_id, action_id, bool(profile.get("applied", true)), bool(profile.get("warning", false)), message)


func get_resident_request() -> String:
	return "Оно прошло прямо сквозь полотно! Пожалуйста, верните привидение обратно или поймайте его."


func apply_source_follow_up(follow_up: Dictionary) -> void:
	world_object["frame_damage"] = maxi(0, int(follow_up.get("frame_damage", 0)))
	world_object["source_frame_damage"] = int(world_object["frame_damage"])
	world_object["cold_aura"] = bool(follow_up.get("cold_aura", false))
	world_object["initial_cold_aura"] = bool(world_object["cold_aura"])
	world_object["lunnopuh_state"] = str(follow_up.get("lunnopuh_state", "absent"))
	world_object["cage_state"] = str(follow_up.get("cage_state", "packed"))


func mirror_visual_state() -> StringName:
	var state := StringName(world_object["mirror_state"])
	if int(world_object.get("frame_damage", 0)) <= 0 or state == &"destroyed":
		return state
	match state:
		&"covered":
			return &"covered_heat_damaged"
		&"open":
			return &"heat_damaged"
		&"closed":
			return &"closed_heat_damaged"
	return state


func install_trap(employee_id: StringName, has_trap: bool) -> Dictionary:
	return perform(&"ghost", employee_id, &"install_trap", {"has_trap": has_trap})


func apply_ghost_action(employee_id: StringName, action_id: StringName) -> Dictionary:
	return perform(&"ghost", employee_id, action_id)


func can_return_ghost_to_portal() -> bool:
	return refusal_message(&"ghost", &"antimagic").is_empty()


func can_close_portal() -> bool:
	return refusal_message(&"mirror", &"antimagic", {"has_antimagic": true}).is_empty()


func uncover_mirror(employee_id: StringName, antimagic_present: bool) -> Dictionary:
	return perform(&"mirror", employee_id, &"uncover", {"antimagic_present": antimagic_present})


func close_portal(employee_id: StringName, has_antimagic: bool) -> Dictionary:
	return perform(&"mirror", employee_id, &"antimagic", {"has_antimagic": has_antimagic})


func break_mirror(employee_id: StringName) -> Dictionary:
	return perform(&"mirror", employee_id, &"physical_move")


func is_resolved() -> bool:
	for rule: Dictionary in GHOST.base_properties["resolution_rules"]:
		if _matches(rule, world_object):
			return true
	return false


func get_completion_result() -> Dictionary:
	if not is_resolved():
		return {}
	var result := _completion_result()
	var outcome := "destroyed" if str(world_object["mirror_state"]) == "destroyed" else "captured_closed" if str(world_object["ghost_state"]) == "captured" and str(world_object["mirror_state"]) == "closed" else "captured_covered" if str(world_object["ghost_state"]) == "captured" else "returned_covered" if str(world_object["mirror_state"]) == "covered" else "returned"
	result.merge(GHOST.base_properties["completion_payments"][outcome], true)
	result["expense_reimbursement"] = int(GHOST.base_properties["trap_reimbursement"]) if str(world_object["trap_state"]) == "occupied" else 0
	result["credit_helpful_work_on_damage"] = true
	if bool(world_object["cold_aura"]) and str(world_object["mirror_state"]) == "covered":
		result["summary"] += " В комнате по-прежнему холодно."
		result["consequences"].append("Под полотном остаётся портал, излучающий холод.")
	if str(world_object["trap_state"]) == "occupied":
		result["retained_supply_items"] = ["ghost_trap"]
	elif str(world_object["trap_state"]) == "installed":
		result["returned_supply_items"] = ["ghost_trap"]
		result["completion_object_updates"] = {"trap_state": "packed"}
		result["completion_related_updates"] = {"portal_mirror_room.ghost_trap": {"state": "packed", "damage": 0}}
	var helpful: Array[String] = []
	for entry: Dictionary in action_log:
		if str(entry.get("action_id", "")) in ["install_trap", "trap", "uncover", "cover", "antimagic"] and bool(entry.get("result", {}).get("applied", false)):
			var employee := str(entry["employee_id"])
			if not helpful.has(employee):
				helpful.append(employee)
	for entry: Dictionary in action_log:
		for change: Dictionary in entry.get("object_changes", []):
			if str(change.get("target_instance_id", "")) != "portal_mirror_room.portal_mirror":
				continue
			var before: Dictionary = change.get("before", {})
			var after: Dictionary = change.get("after", {})
			if bool(before.get("cold_aura", false)) and not bool(after.get("cold_aura", false)) and not bool(entry.get("result", {}).get("caused_damage", false)):
				var employee := str(entry["employee_id"])
				if not helpful.has(employee):
					helpful.append(employee)
	result["successful_employee_ids"] = helpful
	return result


func _completion_result() -> Dictionary:
	if StringName(world_object["mirror_state"]) == &"destroyed":
		var ghost_captured := StringName(world_object["ghost_state"]) == &"captured"
		return {
			"summary": "Портал уничтожен вместе с зеркалом. Привидение осталось в ловушке." if ghost_captured else "Портал уничтожен вместе с зеркалом. Связь с привидением оборвана.",
			"review": "Это было фамильное зеркало! Теперь из него действительно больше никто не выйдет — как и моё отражение.",
			"consequences": ["Старинное зеркало уничтожено.", "Привидение изолировано в служебной ловушке.", "Служба выплачивает компенсацию за зеркало."] if ghost_captured else ["Старинное зеркало уничтожено.", "Магическая связь с привидением оборвана.", "Служба выплачивает компенсацию за зеркало."],
			"reward_adjustment": -200,
			"expense_reimbursement": 250 if ghost_captured else 0,
			"compensation_cost": 300,
			"reputation_change": -2,
			"actions": action_log.duplicate(true),
		}
	if StringName(world_object["ghost_state"]) == &"captured":
		var portal_closed := StringName(world_object["mirror_state"]) == &"closed"
		var frame_damaged := int(world_object.get("frame_damage", 0)) > 0
		var summary := "Привидение поймано в служебную ловушку, портал окончательно закрыт." if portal_closed else "Привидение поймано в служебную ловушку. Зеркало осталось временно изолировано полотном."
		var consequences: Array[String] = ["Привидение изолировано в служебной ловушке.", "Портал окончательно закрыт." if portal_closed else "Портал остаётся временно закрыт полотном."]
		if frame_damaged:
			summary += tr(" Оплавленная рама осталась деформированной.")
			consequences.append("Рама зеркала осталась деформированной после нагрева.")
		return {
			"summary": summary,
			"review": "Призрак в ловушке, портал закрыт. Наконец-то в этой комнате всё остаётся на своих местах." if portal_closed else "Призрак теперь сидит в банке, зеркало — под покрывалом. Не тот интерьер, который я заказывала, но хотя бы никто больше не летает сквозь мебель.",
			"consequences": consequences,
			"reward_adjustment": -50 if portal_closed else -100,
			"expense_reimbursement": 250,
			"compensation_cost": 0,
			"reputation_change": 0,
			"actions": action_log.duplicate(true),
		}
	if StringName(world_object["mirror_state"]) == &"covered":
		var mirror := shared_mirror()
		var isolation: Dictionary = mirror._completion_from_properties()
		return {
			"summary": "Привидение возвращено в портал. Зеркало осталось временно изолировано полотном." + (" Рама зеркала осталась деформированной после нагрева." if int(world_object.get("frame_damage", 0)) > 0 else ""),
			"review": isolation["review"],
			"consequences": ["Привидение возвращено в портал.", "Портал остаётся временно закрыт полотном."] + (["Рама зеркала осталась деформированной после нагрева."] if int(world_object.get("frame_damage", 0)) > 0 else []),
			"expense_reimbursement": 0,
			"actions": action_log.duplicate(true),
		}
	var frame_damaged := int(world_object.get("frame_damage", 0)) > 0
	return {
		"summary": "Привидение возвращено в портал, портал закрыт. Оплавленная рама осталась деформированной." if frame_damaged else "Привидение возвращено в портал, портал закрыт без ущерба.",
		"review": "На этот раз из зеркала вышел только мой собственный вид — усталый, но исключительно довольный. Вот теперь это действительно закрытый портал.",
		"consequences": ["Привидение возвращено в портал.", "Портал окончательно закрыт.", "Рама зеркала осталась деформированной после нагрева."] if frame_damaged else ["Привидение возвращено в портал.", "Портал окончательно закрыт.", "Зеркало сохранено."],
		"reward_adjustment": 0,
		"expense_reimbursement": 0,
		"compensation_cost": 0,
		"reputation_change": 1,
		"actions": action_log.duplicate(true),
	}


func _record(employee_id: StringName, action_id: StringName, applied: bool, warning: bool, message: String) -> Dictionary:
	var result := {"applied": applied, "warning": warning, "message": message, "resolved": is_resolved()}
	action_log.append(Rules.action_event(employee_id, action_id, last_snapshot, snapshots(), result))
	last_snapshot = snapshots()
	return result
