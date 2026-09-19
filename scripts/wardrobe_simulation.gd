class_name WardrobeSimulation
extends RefCounted

const ResidentReactionResolverScript := preload("res://scripts/resident_reaction_resolver.gd")
const ObjectInteractionRulesScript := preload("res://scripts/object_interaction_rules.gd")

const ZONE_NAMES: Dictionary = {
	&"entrance": "у входной двери",
	&"left_wall": "у левой стены",
	&"kitchen_passage": "возле прохода на кухню",
}

var world_object: Dictionary = {
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
	"visual_state": &"walking",
	"damage": 0,
	"contents_type": &"dishes",
	"contents_damage": 0,
	"replacement_value": 520,
	"contents_value": 180,
	"resident_voice_variant": 0,
}
var action_log: Array[Dictionary] = []


func initialize_variant(_seed_value: int) -> void:
	# В этой заявке пожелание жильца фиксировано и прямо сообщается игроку.
	world_object["requested_zone"] = &"left_wall"
	world_object["contents_type"] = &"dishes"
	if not world_object.has("held"):
		world_object["held"] = false


func load_state(saved_state: Dictionary) -> void:
	if saved_state.is_empty():
		return
	var saved_object: Variant = saved_state.get("world_object", {})
	if saved_object is Dictionary:
		world_object.merge((saved_object as Dictionary).duplicate(true), true)
	for key: String in ["definition_id", "position_zone", "requested_zone", "visual_state", "contents_type", "size_class"]:
		world_object[key] = StringName(str(world_object.get(key, "")))
	# Совместимость с сохранениями раннего прототипа, где проход назывался center_wall.
	if world_object["position_zone"] == &"center_wall":
		world_object["position_zone"] = &"kitchen_passage"
	if world_object["requested_zone"] == &"center_wall":
		world_object["requested_zone"] = &"kitchen_passage"
	# Актуальный рисунок шкафа показывает посуду; старые сохранения безопасно мигрируют.
	world_object["requested_zone"] = &"left_wall"
	world_object["contents_type"] = &"dishes"
	action_log.clear()
	var saved_actions: Variant = saved_state.get("action_log", [])
	if saved_actions is Array:
		for saved_action: Variant in saved_actions:
			if saved_action is Dictionary:
				action_log.append((saved_action as Dictionary).duplicate(true))


func get_state() -> Dictionary:
	return {
		"world_object": world_object.duplicate(true),
		"action_log": action_log.duplicate(true),
	}


func get_resident_request() -> String:
	return "Этот проклятый шкаф снова разгуливает по комнате! Остановите его и поставьте у левой стены. Сделайте аккуратно, там хрупкая посуда."


func get_resident_message() -> String:
	var current_message: String = get_resident_request()
	if bool(world_object["anchored"]) and world_object["position_zone"] == world_object["requested_zone"]:
		current_message = "Вот теперь шкаф стоит там, где нужно, и больше никуда не уйдёт. Спасибо, именно этого я и просила!"
	return ResidentReactionResolverScript.message_for(world_object, current_message, int(world_object["resident_voice_variant"]))


func get_status_title() -> String:
	if bool(world_object["held"]):
		return "Шкаф удерживается"
	if bool(world_object["anchored"]):
		return "Шкаф закреплён"
	return ResidentReactionResolverScript.title_for(world_object, "Шкаф ходит по квартире", "Шкаф")


func apply_action(employee_id: StringName, action_id: StringName, intent: StringName = &"") -> Dictionary:
	var action_summary: String = "Это действие не изменило состояние шкафа."
	var applied: bool = false
	if bool(world_object["destroyed"]):
		return _record_result(employee_id, action_id, intent, false, "От шкафа осталась только куча пепла. Воздействовать больше не на что.")

	match action_id:
		&"diagnose":
			action_summary = _diagnose_wardrobe()
			applied = true
		&"repair":
			var repair_result: Dictionary = _apply_technical_repair()
			action_summary = str(repair_result["summary"])
			applied = bool(repair_result["applied"])
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
			world_object["frozen"] = true
			world_object["brittle"] = int(world_object["temperature"]) <= -2
			if int(world_object["temperature"]) <= 2:
				world_object["burning"] = false
				world_object["fire_spots"] = 0
			if was_burning and not bool(world_object["burning"]):
				action_summary = "Огонь погашен холодом. На шкафу осталась копоть, а древесина стала хрупкой."
			elif was_burning:
				action_summary = "Холод ослабил пожар, но шкаф всё ещё горит."
			else:
				action_summary = "Древесина промёрзла и стала хрупкой."
			applied = true
		&"heat":
			world_object["temperature"] = int(world_object["temperature"]) + 5
			world_object["frozen"] = false
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
				action_summary = "Шкаф аккуратно перенесён %s. Шкаф и посуда не повреждены." % ZONE_NAMES[world_object["position_zone"]]
			applied = bool(telekinesis_result["applied"])

	if applied:
		_sync_visual_state()
	var message: String = _compose_result_message(action_summary, action_id, intent) if applied else action_summary

	return _record_result(employee_id, action_id, intent, applied, message)


func can_begin_action(action_id: StringName) -> bool:
	if action_id != &"repair":
		return true
	if bool(world_object["destroyed"]) or bool(world_object["burning"]):
		return false
	if int(world_object["mobility"]) <= 0:
		return true
	return world_object["position_zone"] == world_object["requested_zone"]


func advance_burning() -> Dictionary:
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
			"message": "Пламя распространяется по шкафу: очагов уже %d." % int(world_object["fire_spots"]),
			"resolved": false,
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
	world_object["contents_damage"] = 6
	_sync_visual_state()
	var destroyed_result: Dictionary = {
		"changed": true,
		"message": "Шкаф полностью сгорел. От мебели и хрупкой посуды осталась куча пепла.",
		"resolved": true,
	}
	_record_environment_result(destroyed_result)
	return destroyed_result


func _record_environment_result(result: Dictionary) -> void:
	action_log.append({
		"employee_id": "",
		"action_id": "fire_spread",
		"intent": "",
		"result": result.duplicate(true),
	})


func _record_result(employee_id: StringName, action_id: StringName, intent: StringName, applied: bool, message: String) -> Dictionary:
	var result := {
		"applied": applied,
		"message": message,
		"visual_state": world_object["visual_state"],
		"position_zone": world_object["position_zone"],
		"resolved": is_resolved(),
	}
	action_log.append({
		"employee_id": String(employee_id),
		"action_id": String(action_id),
		"intent": String(intent),
		"result": result.duplicate(true),
	})
	return result


func is_resolved() -> bool:
	if bool(world_object["destroyed"]):
		return true
	if bool(world_object["held"]):
		return false
	var cannot_walk: bool = int(world_object["mobility"]) <= 0
	var entrance_is_clear: bool = world_object["position_zone"] != &"entrance"
	return not bool(world_object["moving"]) and not bool(world_object["burning"]) and (entrance_is_clear or cannot_walk or bool(world_object["anchored"]))


func get_completion_result() -> Dictionary:
	if bool(world_object["destroyed"]):
		var compensation: int = int(world_object["replacement_value"]) + int(world_object["contents_value"])
		return {
			"reward_adjustment": -420,
			"compensation_cost": compensation,
			"reputation_change": -8,
			"summary": "Вы должны были остановить шкаф, а вместо этого сожгли его вместе с посудой! Оплаты не будет, служба выплатила %d монет компенсации за мебель и содержимое." % compensation,
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
	if int(world_object["mobility"]) <= 0:
		var broken_reply: String = "Он больше не ходит, это правда. Но я просила остановить шкаф, а не покалечить его! Кто теперь будет чинить ножки?" if correct_place else "Вы сломали ножки и оставили шкаф посреди прохода? Теперь он не ходит, зато окончательно мешает пройти! Это вы называете ремонтом?"
		return {
			"reward_adjustment": adjustment,
			"reputation_change": -damage - contents_damage,
			"summary": broken_reply,
			"actions": action_log.duplicate(true),
		}
	var summary: String = "Шкаф закреплён у стены и больше не ходит, хотя чары всё ещё действуют." if bool(world_object["anchored"]) else "Шкаф остановлен и больше не ходит."
	if world_object["position_zone"] != &"entrance":
		summary += " Проход освобождён."
	if contents_damage > 0:
		summary += " Хрупкая посуда внутри шкафа повреждена."
	if not correct_place:
		summary += " Шкаф оставлен не там, где просила хозяйка."
	return {
		"reward_adjustment": adjustment,
		"reputation_change": -damage - contents_damage,
		"summary": summary,
		"actions": action_log.duplicate(true),
	}


func _apply_physical_intent(intent: StringName) -> Dictionary:
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
		return "Осмотр Бориса: от шкафа остался пепел, восстановление невозможно."
	if bool(world_object["burning"]):
		return "Осмотр Бориса: шкаф горит. До тушения приближаться и ремонтировать его опасно."
	if bool(world_object["anchored"]):
		return "Осмотр Бориса: шкаф надёжно закреплён к стене. Чары действуют, но сдвинуть его уже не могут."
	if int(world_object["mobility"]) <= 0:
		return "Осмотр Бориса: ножки сломаны, но корпус ещё можно восстановить. Чары при этом никуда не исчезли."
	if bool(world_object["held"]):
		return "Осмотр Бориса: Грог удерживает шкаф, ножки целы, а оживляющие чары продолжают действовать."
	if bool(world_object["moving"]):
		return "Осмотр Бориса: механических поломок нет. Шкаф движется из-за чар, обычный ремонт их не снимет."
	return "Осмотр Бориса: механическая часть шкафа исправна; оставшаяся проблема связана с магией."


func _apply_technical_repair() -> Dictionary:
	if bool(world_object["destroyed"]):
		return {"applied": false, "summary": "Борис осмотрел пепел: шкаф восстановлению не подлежит."}
	if bool(world_object["burning"]):
		return {"applied": false, "summary": "Борис не станет ремонтировать горящий шкаф. Сначала потушите огонь."}
	if bool(world_object["anchored"]):
		return {"applied": false, "summary": "Шкаф уже закреплён к стене."}
	if int(world_object["mobility"]) > 0:
		if world_object["position_zone"] != world_object["requested_zone"]:
			return {"applied": false, "summary": "Сначала поставьте шкаф к левой стене, чтобы Борис мог закрепить его."}
		world_object["anchored"] = true
		world_object["held"] = false
		world_object["moving"] = false
		world_object["noise"] = 0
		return {"applied": true, "summary": "Борис закрепил шкаф к стене прочными скобами. Чары всё ещё действуют, но шкаф больше не сможет ходить."}
	world_object["mobility"] = 5
	world_object["damage"] = maxi(0, int(world_object["damage"]) - 3)
	world_object["held"] = false
	world_object["moving"] = int(world_object["magic_level"]) > 0
	world_object["noise"] = 5 if bool(world_object["moving"]) else 0
	return {
		"applied": true,
		"summary": "Борис заменил сломанные ножки и укрепил основание. Чары снова заставили шкаф двигаться." if bool(world_object["moving"]) else "Борис заменил сломанные ножки и восстановил шкаф.",
	}


func _compose_result_message(action_summary: String, action_id: StringName, intent: StringName) -> String:
	if action_id == &"physical_move" and intent == &"break_legs":
		var correct_place: bool = world_object["position_zone"] == world_object["requested_zone"]
		return "Он больше не ходит, это правда. Но я просила остановить шкаф, а не покалечить его! Кто теперь будет чинить ножки?" if correct_place else "Вы сломали ножки и оставили шкаф посреди прохода? Теперь он не ходит, зато окончательно мешает пройти! Это вы называете ремонтом?"
	if action_id == &"physical_move" and intent == &"hold":
		if int(world_object["mobility"]) <= 0:
			return "Удерживать шкаф больше не требуется: его ножки сломаны."
		return "%s После освобождения он снова сможет двигаться." % action_summary
	if action_id == &"physical_move" and intent == &"release":
		return "%s Чары снова заставили его ходить." % action_summary if bool(world_object["moving"]) else "%s Шкаф остался неподвижен." % action_summary
	return "%s %s" % [action_summary, _describe_current_hazard()]


func _describe_current_hazard() -> String:
	if bool(world_object["burning"]):
		return "Шкаф горит; в комнате появилась дополнительная опасность."
	if int(world_object["mobility"]) <= 0:
		return "Ножки сломаны, поэтому шкаф больше не может ходить."
	if bool(world_object["moving"]):
		if int(world_object["magic_level"]) > 0:
			return "Чары всё ещё действуют, поэтому шкаф продолжает ходить."
		return "Шкаф продолжает двигаться."
	return "Шкаф больше не движется."


func _sync_visual_state() -> void:
	if bool(world_object["destroyed"]):
		world_object["visual_state"] = &"destroyed"
	elif int(world_object["mobility"]) <= 0:
		world_object["visual_state"] = &"broken"
	elif bool(world_object["held"]):
		world_object["visual_state"] = &"idle"
	elif bool(world_object["moving"]):
		world_object["visual_state"] = &"walking"
	else:
		world_object["visual_state"] = &"idle"


func _release_held_wardrobe() -> void:
	world_object["held"] = false
	if int(world_object["mobility"]) > 0 and int(world_object["magic_level"]) > 0 and not bool(world_object["destroyed"]) and not bool(world_object["anchored"]):
		world_object["moving"] = true
		world_object["noise"] = maxi(1, int(world_object["noise"]))
