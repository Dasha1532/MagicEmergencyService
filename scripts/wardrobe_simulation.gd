class_name WardrobeSimulation
extends RefCounted

const ResidentReactionResolverScript := preload("res://scripts/resident_reaction_resolver.gd")
const ObjectInteractionRulesScript := preload("res://scripts/object_interaction_rules.gd")
const EmployeeReactionResolverScript := preload("res://scripts/employee_reaction_resolver.gd")
const Reactions := preload("res://data/wardrobe_employee_reactions.gd")

const ZONE_NAMES: Dictionary = {
	&"entrance": "у входной двери",
	&"left_wall": "у левой стены",
	&"kitchen_passage": "возле прохода на кухню",
}

var world_object: Dictionary = {
	"instance_id": &"old_quarter_5.hall.wardrobe",
	"definition_id": &"walking_wardrobe",
	"mass": 8,
	"durability": 7,
	"temperature": 2,
	"magic_level": 6,
	"movement_force": 5,
	"mobility": 5,
	"noise": 7,
	"anchored": false,
	"movable": true,
	"position_zone": &"entrance",
	"requested_zone": &"left_wall",
	"moving": true,
	"movement_seen": true,
	"held": false,
	"frozen": false,
	"brittle": false,
	"burning": false,
	"scorched": false,
	"destroyed": false,
	"size_class": &"large",
	"max_fire_spots": 3,
	"fire_spots": 0,
	"burn_stage": 0,
	"next_fire_spread_at": -1,
	"visual_state": &"walking",
	"damage": 0,
	"contents_type": &"dishes",
	"contents_damage": 0,
	"contents_damage_limit": 3,
	"contents_state": "intact",
	"replacement_value": 520,
	"contents_value": 180,
	"resident_voice_variant": 0,
	"resident_intro_seen": false,
}
var action_log: Array[Dictionary] = []
var action_before: Dictionary = {}
var last_no_force_phrase: int = -1
var last_dish_break_phrase: int = -1

func _snapshots() -> Dictionary:
	_sync_contents_state()
	return {String(world_object["instance_id"]): world_object.duplicate(true), String(world_object["instance_id"]) + ".contents": {"damage": int(world_object["contents_damage"]), "contents_state": world_object["contents_state"], "destroyed": world_object["contents_state"] == "all_broken"}}


func _sync_contents_state() -> void:
	world_object["contents_damage"] = clampi(int(world_object["contents_damage"]), 0, 3)
	world_object["contents_state"] = Reactions.CONTENTS_STATES[int(world_object["contents_damage"])]


func _dish_break_phrase() -> String:
	var candidates: Array[int] = []
	for index: int in Reactions.DISH_BREAK_PHRASES.size():
		if index != last_dish_break_phrase:
			candidates.append(index)
	last_dish_break_phrase = candidates.pick_random()
	return Reactions.DISH_BREAK_PHRASES[last_dish_break_phrase]


func initialize_variant(_seed_value: int) -> void:
	# В этой заявке пожелание жильца фиксировано и прямо сообщается игроку.
	world_object["requested_zone"] = &"left_wall"
	world_object["contents_type"] = &"dishes"
	if not world_object.has("held"):
		world_object["held"] = false


func initialize_generated(instance: Dictionary) -> void:
	var initial_state: Variant = instance.get("initial_state", {})
	if initial_state is Dictionary:
		world_object.merge((initial_state as Dictionary).duplicate(true), true)
	for key: String in ["definition_id", "generated_anomaly_id", "position_zone", "requested_zone", "visual_state", "contents_type", "size_class"]:
		world_object[key] = StringName(str(world_object.get(key, "")))
	world_object["generated_instance_id"] = str(instance.get("instance_id", ""))
	world_object["movement_seen"] = bool(world_object["moving"]) or int(world_object["magic_level"]) > 0
	world_object["generator_version"] = int(instance.get("generator_version", 1))
	_sync_visual_state()


func load_state(saved_state: Dictionary) -> void:
	if saved_state.is_empty():
		return
	last_no_force_phrase = int(saved_state.get("last_no_force_phrase", -1))
	last_dish_break_phrase = int(saved_state.get("last_dish_break_phrase", -1))
	var saved_object: Variant = saved_state.get("world_object", {})
	if saved_object is Dictionary:
		world_object.merge((saved_object as Dictionary).duplicate(true), true)
		if not saved_object.has("movement_seen"):
			world_object["movement_seen"] = bool(world_object["moving"]) or int(world_object["magic_level"]) > 0 or str(world_object.get("generated_anomaly_id", "restless_animation")) == "restless_animation"
	for key: String in ["definition_id", "generated_anomaly_id", "position_zone", "requested_zone", "visual_state", "contents_type", "size_class"]:
		world_object[key] = StringName(str(world_object.get(key, "")))
	# Совместимость с сохранениями раннего прототипа, где проход назывался center_wall.
	if world_object["position_zone"] == &"center_wall":
		world_object["position_zone"] = &"kitchen_passage"
	if world_object["requested_zone"] == &"center_wall":
		world_object["requested_zone"] = &"kitchen_passage"
	# Актуальный рисунок шкафа показывает посуду; старые сохранения безопасно мигрируют.
	if world_object["requested_zone"].is_empty():
		world_object["requested_zone"] = &"left_wall"
	world_object["contents_type"] = &"dishes"
	action_log.clear()
	var saved_actions: Variant = saved_state.get("action_log", [])
	if saved_actions is Array:
		for saved_action: Variant in saved_actions:
			if saved_action is Dictionary:
				action_log.append((saved_action as Dictionary).duplicate(true))
				for change: Dictionary in (saved_action as Dictionary).get("object_changes", []):
					if bool((change.get("before", {}) as Dictionary).get("moving", false)) or bool((change.get("after", {}) as Dictionary).get("moving", false)):
						world_object["movement_seen"] = true
	_sync_visual_state()


func physical_intents() -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	if bool(world_object["destroyed"]):
		return choices
	if bool(world_object["held"]):
		choices.append({"id": &"release", "label": "Отпустить"})
	elif bool(world_object["moving"]):
		choices.append({"id": &"hold", "label": "Удерживать"})
	var needs_move: bool = bool(world_object["moving"]) or int(world_object["magic_level"]) > 0 or world_object["position_zone"] != world_object["requested_zone"]
	if needs_move and bool(world_object["movable"]) and not bool(world_object["anchored"]) and not bool(world_object["frozen"]):
		if world_object["position_zone"] != &"left_wall":
			choices.append({"id": &"move_left_fast", "label": "Быстро к левой стене"})
			choices.append({"id": &"move_left_careful", "label": "Аккуратно к левой стене"})
		if world_object["position_zone"] != &"kitchen_passage":
			choices.append({"id": &"move_kitchen_fast", "label": "Быстро в проход на кухню"})
			choices.append({"id": &"move_kitchen_careful", "label": "Аккуратно в проход на кухню"})
	if bool(world_object["moving"]) and int(world_object["mobility"]) > 0:
		choices.append({"id": &"break_legs", "label": "Сломать ножки"})
	return choices


func needs_repair() -> bool:
	return not bool(world_object["destroyed"]) and (int(world_object["damage"]) > 0 or int(world_object["mobility"]) <= 0)


func offers_force_inspection() -> bool:
	return physical_intents().is_empty()


func _no_force_phrase() -> String:
	var candidates: Array[int] = []
	for index: int in Reactions.NO_FORCE_PHRASES.size():
		if index != last_no_force_phrase:
			candidates.append(index)
	last_no_force_phrase = candidates[randi_range(0, candidates.size() - 1)]
	return Reactions.NO_FORCE_PHRASES[last_no_force_phrase]


func needs_anchor() -> bool:
	return not bool(world_object["destroyed"]) and not bool(world_object["anchored"]) and int(world_object["magic_level"]) > 0


func get_state() -> Dictionary:
	return {
		"last_no_force_phrase": last_no_force_phrase,
		"last_dish_break_phrase": last_dish_break_phrase,
		"world_object": world_object.duplicate(true),
		"related_objects": {String(world_object["instance_id"]) + ".contents": _snapshots()[String(world_object["instance_id"]) + ".contents"]},
		"action_log": action_log.duplicate(true),
	}


func start_burning_clock(current_minutes: int, spread_minutes: int) -> void:
	if bool(world_object["burning"]) and int(world_object.get("next_fire_spread_at", -1)) < 0:
		world_object["next_fire_spread_at"] = current_minutes + maxi(1, spread_minutes)


func advance_burning_until(current_minutes: int, spread_minutes: int) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if not bool(world_object["burning"]):
		world_object["next_fire_spread_at"] = -1
		return results
	start_burning_clock(current_minutes, spread_minutes)
	while bool(world_object["burning"]) and current_minutes >= int(world_object["next_fire_spread_at"]):
		var result: Dictionary = advance_burning()
		if not bool(result.get("changed", false)):
			break
		results.append(result)
		if bool(world_object["burning"]):
			world_object["next_fire_spread_at"] = int(world_object["next_fire_spread_at"]) + maxi(1, spread_minutes)
		else:
			world_object["next_fire_spread_at"] = -1
	return results


func get_resident_request() -> String:
	var generated_request := str(world_object.get("generated_resident_request", ""))
	if not generated_request.is_empty():
		return generated_request.replace("пока от мебели и посуды ничего не осталось!", "пока огонь не добрался до посуды!")
	return tr("Этот проклятый шкаф снова разгуливает по комнате! Остановите его и поставьте %s. Сделайте аккуратно, там хрупкая посуда.") % tr(_requested_zone_phrase())


func get_resident_message() -> String:
	var current_message: String = get_resident_request()
	if bool(world_object["anchored"]) and world_object["position_zone"] == world_object["requested_zone"]:
		current_message = "Вот теперь шкаф стоит там, где нужно, и больше никуда не уйдёт. Спасибо, именно этого я и просила!"
	return ResidentReactionResolverScript.message_for(world_object, current_message, int(world_object["resident_voice_variant"]))


func get_resident_reaction() -> String:
	var state_reaction: String = ResidentReactionResolverScript.message_for(world_object, "", int(world_object["resident_voice_variant"]))
	if not state_reaction.is_empty():
		return state_reaction
	if bool(world_object["anchored"]) and world_object["position_zone"] == world_object["requested_zone"]:
		return "Вот теперь шкаф стоит там, где нужно, и больше никуда не уйдёт. Спасибо, именно этого я и просила!"
	return ""


func get_status_title() -> String:
	if bool(world_object["held"]):
		return "Шкаф удерживается"
	if bool(world_object["anchored"]):
		return "Шкаф закреплён"
	return ResidentReactionResolverScript.title_for(world_object, "Шкаф ходит по квартире", "Шкаф")


func get_employee_reaction(employee_id: StringName, action_id: StringName, intent: StringName = &"") -> String:
	if employee_id == &"grog" and action_id == &"physical_move":
		if String(intent).ends_with("_fast"):
			return "Быстро переставлю. Только посуда внутри может не пережить тряску."
		if String(intent).ends_with("_careful"):
			return "Переставлю без спешки и толчков. Посуду побережём."
	if employee_id == &"boris" and action_id == &"anchor" and world_object["position_zone"] != world_object["requested_zone"]:
		return "Шкаф стоит не там, где просила хозяйка. Сначала поставьте его %s." % _requested_zone_phrase()
	if employee_id == &"boris" and action_id == &"repair" and int(world_object["mobility"]) > 0 and int(world_object["damage"]) == 0 and not bool(world_object["destroyed"]):
		return "Ремонтировать здесь нечего: ножки целы, корпус исправен." + (" Шкаф ходит из-за чар, а не из-за поломки." if bool(world_object["moving"]) else "")
	return EmployeeReactionResolverScript.reaction_for({"action_reactions": Reactions.RULES.get(employee_id, [])}, action_id, world_object, intent)


func apply_action(employee_id: StringName, action_id: StringName, intent: StringName = &"") -> Dictionary:
	action_before = _snapshots()
	var damage_before := int(world_object.get("damage", 0))
	var contents_damage_before := int(world_object.get("contents_damage", 0))
	var destroyed_before := bool(world_object.get("destroyed", false))
	var burning_before := bool(world_object.get("burning", false))
	var action_summary: String = "Это действие не изменило состояние шкафа."
	var applied: bool = false
	if bool(world_object["destroyed"]) and action_id != &"diagnose":
		return _record_result(employee_id, action_id, intent, false, "От шкафа осталась только куча пепла. Воздействовать больше не на что.")

	match action_id:
		&"diagnose":
			action_summary = _diagnose_wardrobe()
			if employee_id == &"grog":
				action_summary = _no_force_phrase() if offers_force_inspection() else "Здесь есть работа для моей силы. Выберите, что нужно сделать."
			applied = true
		&"repair":
			var repair_result: Dictionary = _apply_technical_repair()
			action_summary = str(repair_result["summary"])
			applied = bool(repair_result["applied"])
		&"anchor":
			var anchor_result: Dictionary = _apply_wall_anchor()
			action_summary = str(anchor_result["summary"])
			applied = bool(anchor_result["applied"])
		&"physical_move":
			var physical_result: Dictionary = _apply_physical_intent(intent)
			action_summary = str(physical_result["summary"])
			applied = bool(physical_result["applied"])
		&"antimagic":
			world_object["magic_level"] = maxi(0, int(world_object["magic_level"]) - 6)
			world_object["moving"] = false
			world_object["noise"] = 0
			action_summary = "Антимагия погасила чары."
			applied = true
		&"freeze":
			var was_burning: bool = bool(world_object["burning"])
			world_object["temperature"] = int(world_object["temperature"]) - 5
			world_object["frozen"] = int(world_object["temperature"]) <= -2
			world_object["brittle"] = int(world_object["temperature"]) <= -2
			if int(world_object["temperature"]) <= 2:
				world_object["burning"] = false
				world_object["fire_spots"] = 0
			if was_burning and not bool(world_object["burning"]):
				action_summary = "Огонь погашен холодом. На шкафу осталась копоть."
				if bool(world_object["brittle"]):
					action_summary += " Древесина промёрзла и стала хрупкой."
			elif was_burning:
				action_summary = "Холод ослабил пожар, но шкаф всё ещё горит."
			else:
				action_summary = "Древесина промёрзла и стала хрупкой."
			applied = true
		&"heat":
			world_object["temperature"] = int(world_object["temperature"]) + 5
			world_object["frozen"] = int(world_object["temperature"]) <= -2
			world_object["brittle"] = int(world_object["temperature"]) <= -2
			world_object["burning"] = int(world_object["temperature"]) >= 7
			if bool(world_object["burning"]):
				world_object["damage"] = int(world_object["damage"]) + 2
				world_object["scorched"] = true
				world_object["fire_spots"] = maxi(1, int(world_object["fire_spots"]))
				action_summary = "Дерево загорелось. Если не потушить огонь, пожар распространится по шкафу."
			else:
				action_summary = "Шкаф нагрелся."
			applied = true
		&"animate":
			world_object["magic_level"] = int(world_object["magic_level"]) + 3
			if int(world_object["mobility"]) > 0 and not bool(world_object["anchored"]):
				world_object["moving"] = true
				world_object["noise"] = int(world_object["noise"]) + 2
			action_summary = "Чары оживления усилились."
			applied = true
		&"telekinesis":
			var target_zone: StringName = {
				&"move_left": &"left_wall",
				&"move_kitchen": &"kitchen_passage",
			}.get(intent, &"")
			var telekinesis_result: Dictionary = ObjectInteractionRulesScript.apply_telekinesis(world_object, target_zone)
			action_summary = str(telekinesis_result["summary"])
			if bool(telekinesis_result["applied"]):
				action_summary = tr("Шкаф аккуратно перенесён %s. Шкаф и посуда не повреждены.") % tr(str(ZONE_NAMES[world_object["position_zone"]]))
			applied = bool(telekinesis_result["applied"])

	if applied:
		_sync_visual_state()
	var message: String = _compose_result_message(action_summary, action_id, intent) if applied and not (employee_id == &"grog" and action_id == &"diagnose") else action_summary
	var caused_damage := applied and (
		int(world_object.get("damage", 0)) > damage_before
		or int(world_object.get("contents_damage", 0)) > contents_damage_before
		or (not destroyed_before and bool(world_object.get("destroyed", false)))
	)
	if applied and not burning_before and bool(world_object.get("burning", false)):
		world_object["fire_origin_employee_id"] = String(employee_id)
	return _record_result(employee_id, action_id, intent, applied, message, caused_damage)


func can_begin_action(action_id: StringName) -> bool:
	if action_id not in [&"repair", &"anchor"]:
		return true
	if bool(world_object["destroyed"]) or bool(world_object["burning"]):
		return false
	if action_id == &"anchor":
		return world_object["position_zone"] == world_object["requested_zone"]
	return true


func advance_burning() -> Dictionary:
	action_before = _snapshots()
	if not bool(world_object["burning"]) or bool(world_object["destroyed"]):
		return {"changed": false, "message": "", "resolved": is_resolved()}
	world_object["burn_stage"] = int(world_object["burn_stage"]) + 1
	world_object["scorched"] = true
	world_object["damage"] = int(world_object["damage"]) + 2
	var max_fire_spots: int = int(world_object["max_fire_spots"])
	if int(world_object["fire_spots"]) < max_fire_spots:
		world_object["fire_spots"] = int(world_object["fire_spots"]) + 1
		var spread_result: Dictionary = {
			"changed": true,
			"message": tr("Пламя распространяется по шкафу: очагов уже %d.") % int(world_object["fire_spots"]),
			"resolved": false,
			"caused_damage": true,
		}
		_record_environment_result(spread_result)
		return spread_result
	world_object["destroyed"] = true
	world_object["burning"] = false
	world_object["moving"] = false
	world_object["held"] = false
	world_object["mobility"] = 0
	world_object["noise"] = 0
	world_object["fire_spots"] = 0
	world_object["damage"] = 10
	world_object["contents_damage"] = 3
	_sync_visual_state()
	var destroyed_result: Dictionary = {
		"changed": true,
		"message": "Шкаф полностью сгорел. От мебели и хрупкой посуды осталась куча пепла.",
		"resolved": true,
		"caused_damage": true,
		"object_destroyed": true,
		"audio_cues": PackedStringArray(["play_heavy_impact", "play_breaking_wood"]),
	}
	_record_environment_result(destroyed_result)
	return destroyed_result


func _record_environment_result(result: Dictionary) -> void:
	result["applied"] = bool(result.get("changed", false))
	action_log.append(ObjectInteractionRulesScript.action_event(StringName(str(world_object.get("fire_origin_employee_id", ""))), &"fire_spread", action_before, _snapshots(), result))


func _record_result(employee_id: StringName, action_id: StringName, intent: StringName, applied: bool, message: String, caused_damage: bool = false) -> Dictionary:
	var result := {
		"applied": applied,
		"message": message,
		"visual_state": world_object["visual_state"],
		"position_zone": world_object["position_zone"],
		"resolved": is_resolved(),
		"caused_damage": caused_damage,
	}
	var event := ObjectInteractionRulesScript.action_event(employee_id, action_id, action_before, _snapshots(), result)
	var previous_contents: Dictionary = action_before.get(String(world_object["instance_id"]) + ".contents", {}) as Dictionary
	if applied and int(world_object["contents_damage"]) > int(previous_contents.get("damage", 0)):
		result["contents_damaged"] = true
		result["resident_message"] = _dish_break_phrase()
		event["result"] = result.duplicate(true)
	event["intent"] = String(intent)
	action_log.append(event)
	return result


func is_resolved() -> bool:
	if bool(world_object["destroyed"]):
		return true
	var generated_resolution: Dictionary = world_object.get("generated_resolution", {}) as Dictionary
	if not generated_resolution.is_empty():
		for property_name: String in generated_resolution.get("required_false", PackedStringArray()):
			if bool(world_object.get(property_name, false)):
				return false
		for property_name: String in generated_resolution.get("required_true", PackedStringArray()):
			if not bool(world_object.get(property_name, false)):
				return false
		var alternatives: PackedStringArray = generated_resolution.get("one_of", PackedStringArray())
		if not alternatives.is_empty() and not _matches_any_resolution_condition(alternatives):
			return false
		return true
	if bool(world_object["held"]):
		return false
	var cannot_walk: bool = int(world_object["mobility"]) <= 0
	var magic_removed: bool = int(world_object["magic_level"]) <= 0
	var entrance_is_clear: bool = world_object["position_zone"] != &"entrance"
	return not bool(world_object["moving"]) and not bool(world_object["burning"]) and (magic_removed or entrance_is_clear or cannot_walk or bool(world_object["anchored"]))


func get_completion_result() -> Dictionary:
	_sync_contents_state()
	var result := _build_completion_result()
	result["review"] = _property_review()
	result["contents_state"] = world_object["contents_state"]
	result["contents_damage"] = int(world_object["contents_damage"])
	if int(world_object["contents_damage"]) > 0:
		var state_description: String = Reactions.CONTENTS_REPORTS[int(world_object["contents_damage"])]
		if state_description not in str(result["summary"]):
			result["summary"] += " " + state_description
	return result


func _property_review() -> String:
	if bool(world_object["destroyed"]):
		return "Не удалось сохранить ни шкаф, ни посуду. После такой работы мне остаётся только подсчитывать потери."
	var notes: Array[String] = []
	if not str(world_object.get("fire_origin_employee_id", "")).is_empty():
		notes.append("До вашего вмешательства шкаф хотя бы не горел. Теперь после работы остались последствия пожара.")
	if int(world_object["mobility"]) <= 0:
		notes.append("Шкаф теперь неподвижен, но ножки сломаны. Такой способ остановить мебель меня совершенно не устраивает.")
	elif int(world_object["damage"]) > 0:
		notes.append("С основной проблемой справились, но шкаф теперь повреждён. Я рассчитывала получить помощь, а не новую заботу о ремонте.")
	if int(world_object["contents_damage"]) > 0:
		notes.append(Reactions.CONTENTS_REPORTS[int(world_object["contents_damage"])] + " За такую помощь трудно быть благодарной.")
	if bool(world_object["frozen"]):
		notes.append("Шкаф оставили покрытым инеем. Хотелось бы пользоваться им сразу, а не ждать, пока он оттает.")
	if bool(world_object.get("movement_seen", false)) and world_object["position_zone"] != world_object["requested_zone"]:
		notes.append("Но шкаф так и не поставили туда, куда я просила.")
	if not notes.is_empty():
		return " ".join(notes)
	var initial_fire := false
	var initial_cold := false
	var initial_found := false
	if not action_log.is_empty():
		for event: Dictionary in action_log:
			for change: Dictionary in event.get("object_changes", []):
				if str(change.get("target_instance_id", "")) == String(world_object["instance_id"]):
					var initial: Dictionary = change.get("before", {}) as Dictionary
					initial_fire = bool(initial.get("burning", false))
					initial_cold = bool(initial.get("frozen", false))
					initial_found = true
					break
			if initial_found:
				break
	if initial_fire or bool(world_object["scorched"]):
		return "Пожар потушили, шкаф и посуду спасли. Следы копоти переживу — главное, что всё удалось сохранить."
	if initial_cold:
		return "Шкаф отогрели, древесину и посуду сохранили. Наконец можно открыть дверцы без опасения что-нибудь расколоть. Спасибо за аккуратность!"
	return "Шкаф наконец стоит спокойно, посуда цела. Теперь можно пройти по комнате, не уступая дорогу собственной мебели. Спасибо!"


func _build_completion_result() -> Dictionary:
	if bool(world_object["destroyed"]):
		var compensation: int = int(world_object["replacement_value"]) + int(world_object["contents_value"])
		return {
			"reward_adjustment": -420,
			"forfeit_payment": true,
			"compensation_cost": compensation,
			"object_destroyed": true,
			"reputation_change": -8,
			"summary": tr("Шкаф и его содержимое уничтожены огнём. Оплата отменена, назначена компенсация %d монет.") % compensation,
			"review": "Я просила усмирить зачарованный шкаф, а не устроить погребальный костёр для всей моей посуды! В следующий раз я лучше вызову экзорциста.",
			"consequences": ["Шкаф уничтожен огнём.", "Хрупкая посуда внутри уничтожена.", "Хозяйка предъявила претензию на стоимость мебели и содержимого."],
			"actions": action_log.duplicate(true),
		}
	var generated_completion: Dictionary = world_object.get("generated_completion", {}) as Dictionary
	if not generated_completion.is_empty() and is_resolved() and int(world_object["damage"]) == 0 and int(world_object["contents_damage"]) == 0:
		return {
			"reward_adjustment": 0,
			"reputation_change": 1,
			"summary": str(generated_completion.get("summary", "Работа выполнена.")),
			"review": str(generated_completion.get("review", "")),
			"consequences": (generated_completion.get("consequences", []) as Array).duplicate(true),
			"actions": action_log.duplicate(true),
		}
	var damage := int(world_object["damage"])
	var contents_damage := int(world_object["contents_damage"])
	var correct_place: bool = world_object["position_zone"] == world_object["requested_zone"]
	var furniture_penalty: int
	if int(world_object["mobility"]) <= 0:
		# Сломанные ножки дают заметный, но не обнуляющий всю заявку штраф.
		furniture_penalty = 150 + maxi(0, damage - 3) * 60
	else:
		furniture_penalty = mini(damage * 60, 240)
	var contents_penalty: int = mini(contents_damage, 3) * 35
	var adjustment: int = -furniture_penalty - contents_penalty
	if not correct_place:
		adjustment -= 60
	if not generated_completion.is_empty():
		var consequences := _completion_consequences(damage, contents_damage, correct_place)
		return {"reward_adjustment": adjustment, "reputation_change": -damage - contents_damage,
			"summary": "Причина аварии устранена. " + " ".join(consequences),
			"review": "Авария устранена, но имущество получило повреждения.",
			"consequences": consequences, "actions": action_log.duplicate(true)}
	if int(world_object["mobility"]) <= 0:
		var broken_reply: String = "Он больше не ходит, это правда. Но я просила остановить шкаф, а не покалечить его! Кто теперь будет чинить ножки?" if correct_place else "Вы сломали ножки и оставили шкаф посреди прохода? Теперь он не ходит, зато окончательно мешает пройти! Это вы называете ремонтом?"
		return {
			"reward_adjustment": adjustment,
			"reputation_change": -damage - contents_damage,
			"summary": tr("Шкаф остановлен повреждением ножек%s.") % (tr(" и оставлен не в заказанном месте") if not correct_place else ""),
			"review": broken_reply,
			"consequences": ["Ножки шкафа сломаны.", "Шкаф оставлен не в заказанном месте."] if not correct_place else ["Ножки шкафа сломаны."],
			"actions": action_log.duplicate(true),
		}
	var summary: String = tr("Шкаф закреплён у стены и больше не ходит, хотя чары всё ещё действуют.") if bool(world_object["anchored"]) else tr("Шкаф остановлен и больше не ходит.")
	if world_object["position_zone"] != &"entrance":
		summary += tr(" Проход освобождён.")
	if contents_damage > 0:
		summary += tr(" Хрупкая посуда внутри шкафа повреждена.")
	if damage > 0:
		summary += tr(" Корпус шкафа обгорел, на нём остались следы потушенного пожара.")
	if not correct_place:
		summary += tr(" Шкаф оставлен не там, где просила хозяйка.")
	var review := tr("Наконец-то шкаф стоит %s и ведёт себя как приличная мебель. Посуда тоже цела — я уже отвыкла от такой роскоши.") % tr(_requested_zone_phrase())
	if contents_damage > 0:
		review = "Шкаф больше не гуляет, зато посуда внутри пережила небольшое землетрясение. В следующий раз предупреждайте чашки заранее."
	elif damage > 0:
		review = "Шкаф наконец стоит на месте. Но зачем было сначала поджигать его? Обгоревший корпус сам себя не восстановит."
	elif not correct_place:
		review = "Шкаф вы остановили, спасибо. Но до левой стены он так и не дошёл — видимо, устал раньше ваших сотрудников."
	return {
		"reward_adjustment": adjustment,
		"reputation_change": 1 if damage == 0 and contents_damage == 0 and correct_place else -damage - contents_damage,
		"summary": summary,
		"review": review,
		"consequences": _completion_consequences(damage, contents_damage, correct_place),
		"actions": action_log.duplicate(true),
	}


func _completion_consequences(damage: int, contents_damage: int, correct_place: bool) -> Array[String]:
	var consequences: Array[String] = []
	if damage > 0:
		consequences.append("Шкаф получил повреждения.")
	if contents_damage > 0:
		consequences.append(Reactions.CONTENTS_REPORTS[mini(contents_damage, 3)])
	if not correct_place:
		consequences.append("Шкаф оставлен не в заказанном месте.")
	if consequences.is_empty():
		consequences.append("Дополнительного ущерба не зафиксировано.")
	return consequences


func _requested_zone_phrase() -> String:
	return "у левой стены" if world_object["requested_zone"] == &"left_wall" else "у прохода на кухню"


func _apply_physical_intent(intent: StringName) -> Dictionary:
	var intent_text := String(intent)
	if intent_text.ends_with("_fast") or intent_text.ends_with("_careful"):
		var base_intent := StringName(intent_text.trim_suffix("_fast").trim_suffix("_careful"))
		if base_intent not in [&"move_left", &"move_kitchen"]:
			return {"applied": false, "summary": "Выберите место для шкафа."}
		var move_result := _apply_physical_intent(base_intent)
		if bool(move_result["applied"]):
			var mode: Dictionary = Reactions.MOVE_MODES["fast" if intent_text.ends_with("_fast") else "careful"]
			if world_object["contents_type"] == &"dishes" and int(world_object["contents_damage"]) < int(world_object["contents_damage_limit"]) and randf() < float(mode["contents_damage_chance"]):
				world_object["contents_damage"] = int(world_object["contents_damage"]) + 1
				_sync_contents_state()
				move_result["summary"] += " " + Reactions.CONTENTS_REPORTS[int(world_object["contents_damage"])]
			else:
				move_result["summary"] += " Дополнительного ущерба посуде нет."
		return move_result
	match intent:
		&"hold":
			if int(world_object["mobility"]) <= 0:
				return {"applied": false, "summary": "Удерживать шкаф больше не требуется: его ножки сломаны."}
			world_object["held"] = true
			world_object["moving"] = false
			return {"applied": true, "summary": "Грог удержал шкаф на месте."}
		&"release":
			if not bool(world_object["held"]):
				return {"applied": false, "summary": "Грог сейчас не удерживает шкаф."}
			_release_held_wardrobe()
			return {"applied": true, "summary": "Грог отпустил шкаф."}
		&"move_left":
			_release_held_wardrobe()
			world_object["anchored"] = false
			world_object["position_zone"] = &"left_wall"
			return {"applied": true, "summary": "Шкаф поставлен к левой стене."}
		&"move_kitchen":
			_release_held_wardrobe()
			world_object["anchored"] = false
			world_object["position_zone"] = &"kitchen_passage"
			return {"applied": true, "summary": "Шкаф поставлен в проход на кухню."}
		&"break_legs":
			world_object["held"] = false
			world_object["mobility"] = 0
			world_object["moving"] = false
			world_object["noise"] = 0
			world_object["damage"] = int(world_object["damage"]) + (4 if bool(world_object["brittle"]) else 3)
			return {"applied": true, "summary": "Ножки шкафа сломаны."}
	return {"applied": false, "summary": "Выберите, что именно Грог должен сделать со шкафом."}


func _diagnose_wardrobe() -> String:
	if bool(world_object["destroyed"]):
		return "От шкафа остался пепел, восстановление невозможно."
	if bool(world_object["burning"]):
		return "Шкаф горит. До тушения приближаться и ремонтировать его опасно."
	if bool(world_object["frozen"]):
		return "Шкаф промёрз. Древесина хрупкая — сначала нужно осторожно отогреть его."
	if int(world_object["damage"]) > 0 and int(world_object["mobility"]) > 0:
		return "Ножки целы, но корпус шкафа повреждён. Требуется ремонт."
	if bool(world_object["anchored"]):
		return "Шкаф надёжно закреплён к стене." + (" Чары действуют, но сдвинуть его уже не могут." if int(world_object["magic_level"]) > 0 else "")
	if int(world_object["mobility"]) <= 0:
		return "Ножки сломаны, но корпус ещё можно восстановить. Чары при этом никуда не исчезли."
	if bool(world_object["held"]):
		return "Грог удерживает шкаф, ножки целы, а оживляющие чары продолжают действовать."
	if bool(world_object["moving"]):
		return "Механических поломок нет. Шкаф движется из-за чар, обычный ремонт их не снимет."
	return "Механическая часть шкафа исправна." + (" Оставшаяся проблема связана с магией." if int(world_object["magic_level"]) > 0 else "")


func _apply_technical_repair() -> Dictionary:
	if bool(world_object["destroyed"]):
		return {"applied": false, "summary": "Борис осмотрел пепел: шкаф восстановлению не подлежит."}
	if bool(world_object["burning"]):
		return {"applied": false, "summary": "Борис не станет ремонтировать горящий шкаф. Сначала потушите огонь."}
	if bool(world_object["anchored"]) and int(world_object["damage"]) == 0:
		return {"applied": false, "summary": "Шкаф исправен и уже закреплён к стене."}
	if int(world_object["mobility"]) > 0 and int(world_object["damage"]) == 0:
		return {"applied": false, "summary": "Ножки шкафа не повреждены — ремонт не требуется."}
	var had_broken_legs := int(world_object["mobility"]) <= 0
	world_object["mobility"] = 5
	world_object["damage"] = maxi(0, int(world_object["damage"]) - 3)
	world_object["held"] = false
	world_object["moving"] = int(world_object["magic_level"]) > 0 and not bool(world_object["anchored"])
	world_object["noise"] = 5 if bool(world_object["moving"]) else 0
	return {
		"applied": true,
		"summary": ("Борис заменил сломанные ножки и укрепил основание." if had_broken_legs else "Борис укрепил повреждённый корпус шкафа.") + (" Чары снова заставили шкаф двигаться." if bool(world_object["moving"]) else ""),
	}


func _apply_wall_anchor() -> Dictionary:
	if bool(world_object["destroyed"]):
		return {"applied": false, "summary": "Закреплять больше нечего: от шкафа остался пепел."}
	if bool(world_object["burning"]):
		return {"applied": false, "summary": "Горящий шкаф нельзя закреплять. Сначала потушите огонь."}
	if bool(world_object["anchored"]):
		return {"applied": false, "summary": "Шкаф уже закреплён к стене."}
	if world_object["position_zone"] != world_object["requested_zone"]:
		return {"applied": false, "summary": "Сначала поставьте шкаф к левой стене."}
	world_object["anchored"] = true
	world_object["held"] = false
	world_object["moving"] = false
	world_object["noise"] = 0
	return {"applied": true, "summary": "Борис закрепил шкаф к стене прочными скобами. Чары всё ещё действуют, но шкаф больше не сможет ходить."}


func _compose_result_message(action_summary: String, action_id: StringName, intent: StringName) -> String:
	# Diagnosis is complete; thermal actions already describe the fire/temperature.
	if action_id == &"diagnose":
		return tr(action_summary)
	if action_id == &"heat" or action_id == &"freeze":
		return ("%s %s" % [tr(action_summary), tr(_describe_movement())]).strip_edges()
	if action_id == &"physical_move" and intent == &"break_legs":
		var correct_place: bool = world_object["position_zone"] == world_object["requested_zone"]
		return "Шкаф больше не ходит: ножки сломаны. Он стоит у левой стены, но повреждён." if correct_place else "Шкаф больше не ходит: ножки сломаны. Он повреждён и остался не у левой стены."
	if action_id == &"physical_move" and intent == &"hold":
		if int(world_object["mobility"]) <= 0:
			return "Удерживать шкаф больше не требуется: его ножки сломаны."
		return tr("%s После освобождения он снова сможет двигаться.") % tr(action_summary)
	if action_id == &"physical_move" and intent == &"release":
		return tr("%s Чары снова заставили его ходить.") % tr(action_summary) if bool(world_object["moving"]) else tr("%s Шкаф остался неподвижен.") % tr(action_summary)
	return "%s %s" % [tr(action_summary), tr(_describe_current_hazard())]


func _describe_current_hazard() -> String:
	if bool(world_object["burning"]):
		return "Шкаф горит; в комнате появилась дополнительная опасность."
	return _describe_movement()


func _describe_movement() -> String:
	if int(world_object["mobility"]) <= 0:
		return "Ножки шкафа сломаны." if not bool(world_object.get("movement_seen", false)) else "Ножки сломаны, поэтому шкаф больше не может ходить."
	if bool(world_object["moving"]):
		if int(world_object["magic_level"]) > 0:
			return "Чары всё ещё действуют, поэтому шкаф продолжает ходить."
		return "Шкаф продолжает двигаться."
	return "Шкаф больше не движется." if bool(world_object.get("movement_seen", false)) else ""


func _sync_visual_state() -> void:
	_sync_contents_state()
	if bool(world_object["moving"]):
		world_object["movement_seen"] = true
	if bool(world_object["destroyed"]):
		world_object["visual_state"] = &"destroyed"
	elif int(world_object["mobility"]) <= 0:
		world_object["visual_state"] = &"broken"
	elif bool(world_object["held"]):
		world_object["visual_state"] = &"idle"
	elif bool(world_object["moving"]):
		world_object["visual_state"] = &"walking"
	elif bool(world_object["frozen"]) and int(world_object["magic_level"]) == 0 and int(world_object["damage"]) == 0:
		world_object["visual_state"] = &"frozen"
	else:
		world_object["visual_state"] = &"idle"
	world_object["uses_frozen_visual"] = world_object["visual_state"] == &"frozen"


func _matches_any_resolution_condition(conditions: PackedStringArray) -> bool:
	for condition: String in conditions:
		match condition:
			"magic_removed":
				if int(world_object.get("magic_level", 0)) <= 0:
					return true
			"entrance_clear":
				if StringName(str(world_object.get("position_zone", ""))) != &"entrance":
					return true
			"mobility_lost":
				if int(world_object.get("mobility", 0)) <= 0:
					return true
			"anchored":
				if bool(world_object.get("anchored", false)):
					return true
	return false


func _release_held_wardrobe() -> void:
	world_object["held"] = false
	if int(world_object["mobility"]) > 0 and int(world_object["magic_level"]) > 0 and not bool(world_object["destroyed"]) and not bool(world_object["anchored"]):
		world_object["moving"] = true
		world_object["noise"] = maxi(1, int(world_object["noise"]))
