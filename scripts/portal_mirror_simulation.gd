class_name PortalMirrorSimulation
extends RefCounted

const ObjectRules := preload("res://scripts/object_interaction_rules.gd")
const Definition := preload("res://data/objects/portal_mirror.tres")
const Lunnopuh := preload("res://data/objects/lunnopuh.tres")
const Cage := preload("res://data/objects/lunnopuh_cage.tres")
var interaction_target: StringName = &"portal_mirror"

const Anomaly := preload("res://data/anomalies/open_portal.tres")

var world_object: Dictionary = {"definition_id": &"portal_mirror", "resident_intro_seen": false}
var action_log: Array[Dictionary] = []
var action_before: Dictionary = {}
var pending_actor_action: Dictionary = {}


func _init() -> void:
	world_object.merge(Definition.base_properties, true)
	world_object.merge(Anomaly.initial_state, true)
	world_object["instance_id"] = "portal_mirror_room.portal_mirror"
	world_object["inspected"] = false


func initialize_from_job(job: Dictionary) -> void:
	var instance: Dictionary = job.get("generated_instance", {})
	world_object.merge(job.get("object_initial_state", Anomaly.initial_state), true)
	world_object.merge(instance.get("initial_state", {}), true)
	world_object["resolution"] = (world_object.get("generated_resolution", job.get("object_goal", Anomaly.resolution)) as Dictionary).duplicate(true)
	world_object["resident_request"] = str(job.get("resident_request", world_object.get("generated_resident_request", "")))


func available_actions(employee_id: StringName = &"") -> PackedStringArray:
	if employee_id == &"boris" and not bool(world_object.get("inspected", false)):
		return PackedStringArray(["diagnose"])
	var actions := PackedStringArray(world_object.get("supported_actions", []))
	actions.append("uncover" if bool(world_object["covered"]) else "cover")
	if str(world_object.get("cage_state", "packed")) == "packed":
		actions.append("install_cage")
	return actions


func can_begin_action(action_id: StringName, employee: Dictionary = {}) -> bool:
	if interaction_target == &"lunnopuh":
		return lunnopuh_actions(StringName(str(employee.get("id", "boris")))).has(String(action_id))
	return available_actions(StringName(str(employee.get("id", "boris")))).has(String(action_id))


func load_state(saved_state: Dictionary) -> void:
	pending_actor_action = (saved_state.get("pending_actor_action", {}) as Dictionary).duplicate(true)
	var saved_object: Variant = saved_state.get("world_object", {})
	if saved_object is Dictionary:
		world_object.merge((saved_object as Dictionary).duplicate(true), true)
	action_log.clear()
	var saved_actions: Variant = saved_state.get("action_log", [])
	if saved_actions is Array:
		for saved_action: Variant in saved_actions:
			if saved_action is Dictionary:
				action_log.append((saved_action as Dictionary).duplicate(true))

	# Сохранения прежнего формата не содержали переходов и признака осмотра.
	if saved_object is Dictionary and not (saved_object as Dictionary).has("inspected"):
		world_object["inspected"] = (saved_state.get("boris_inspected_objects", []) as Array).has("Зеркало")
		for entry: Dictionary in action_log:
			if str(entry.get("employee_id", "")) == "boris" and str(entry.get("action_id", "")) == "diagnose":
				world_object["inspected"] = true
	for entry: Dictionary in action_log:
		if entry.has("object_changes"):
			continue
		var result: Dictionary = entry.get("result", {})
		var action := str(entry.get("action_id", ""))
		var message := str(result.get("message", ""))
		var damaged := bool(result.get("applied", false)) and (action == "physical_move" or (action == "heat" and "начала деформироваться" in message))
		entry["legacy_useful_work"] = bool(result.get("applied", false)) and not damaged and (action in ["antimagic", "cover"] or (action == "heat" and ("рассеяла холод" in message or "Иней растаял" in message)))
		result["caused_damage"] = damaged
		result["damage_target_ids"] = [String(world_object["instance_id"])] if damaged else []
		result["destroyed_target_ids"] = [String(world_object["instance_id"])] if damaged and action == "physical_move" else []
		if action == "freeze" and bool(result.get("applied", false)):
			world_object["freeze_reaction_seen"] = true


func get_state() -> Dictionary:
	if bool(world_object["destroyed"]):
		world_object["covered"] = false
		world_object["cold_aura"] = false
	return {"world_object": world_object.duplicate(true), "related_objects": {"portal_mirror_room.lunnopuh": lunnopuh_properties(), "portal_mirror_room.lunnopuh_cage": cage_properties()}, "action_log": action_log.duplicate(true), "pending_actor_action": pending_actor_action.duplicate(true), "boris_inspected_objects": (["Зеркало"] if bool(world_object.get("inspected", false)) else []) + (["Лунопух"] if bool(world_object.get("lunnopuh_inspected", false)) else [])}


func get_resident_request() -> String:
	if str(world_object.get("resident_request", "")) in ["Он такой милый. Я бы оставила его себе. Если не получится оставить, то отправьте его домой", "Этот зверёк выбрался из зеркала. Боюсь, он испортит мебель, но он такой милый — я бы оставила его себе! Только поймать не могу. Поймайте его, пожалуйста. Если не получится — отправьте домой и закройте портал"]:
		return "Из зеркала выбрался этот зверёк. Такой милый — я даже назвала его Лунопухом! Хотела бы оставить его себе, но он носится по комнате, а я боюсь за мебель. Поймайте его, пожалуйста. Если не получится — отправьте домой и закройте портал"
	if not str(world_object.get("resident_request", "")).is_empty():
		return str(world_object["resident_request"])
	return "Из зеркала тянет ледяным холодом. Пожалуйста, остановите это — в комнате уже невозможно находиться."


func refusal_message(action_id: StringName, has_protective_cloth: bool = true) -> String:
	var properties := world_object.duplicate(true)
	properties["protective_cloth_available"] = has_protective_cloth
	return ObjectRules.state_refusal_message(action_id, properties)


func get_employee_reaction(employee_id: StringName, action_id: StringName, has_protective_cloth: bool = true) -> String:
	var refusal := ObjectRules.refusal_reason(action_id, world_object)
	if not refusal.is_empty():
		return preload("res://scripts/employee_reaction_resolver.gd").refusal_for(refusal)
	var state_refusal := refusal_message(action_id, has_protective_cloth)
	if not state_refusal.is_empty():
		return state_refusal
	if action_id == &"diagnose" and (not bool(world_object["portal_open"]) or bool(world_object["covered"]) or int(world_object["damage"]) > 0):
		return ""
	if action_id in [&"heat", &"freeze"] and not bool(world_object["cold_aura"]):
		return str(preload("res://scripts/employee_reaction_resolver.gd").ABILITY_REACTION_FALLBACKS.get(action_id, ""))
	return {
		&"boris": {
			&"diagnose": "Зеркало показывает потусторонний мир. Гарантия, полагаю, уже закончилась.",
			&"cover": "Полотно повешу. Если портал обидится — пусть пишет претензию.",
		},
		&"grog": {&"physical_move": "Разбить зеркало могу. Семь лет несчастья в наряд не входят."},
		&"liliya": {
			&"freeze": "Холодный портал предлагается заморозить. Люблю последовательные технические задания.",
			&"heat": "Согрею комнату. Портал, вероятно, воспримет это как личное оскорбление.",
		},
		&"nika": {&"telekinesis": "Сдвину осторожно. Если за зеркалом другой мир, надеюсь, он не прибит к стене."},
		&"felix": {&"antimagic": "Закрою канал. Незарегистрированным порталам здесь не место."},
	}.get(employee_id, {}).get(action_id, "")


func get_resident_reaction(action_id: StringName) -> String:
	match action_id:
		&"antimagic":
			return "Зеркало снова обычное. И этот ужасный холод исчез." if bool(world_object.get("initial_cold_aura", true)) else "Зеркало снова обычное."
		&"heat":
			if int(world_object["damage"]) > 0:
				return "Осторожнее! Рама уже начинает плавиться."
			return "Наконец-то стало теплее. Но портал всё ещё открыт." if bool(world_object.get("initial_cold_aura", true)) else ""
		&"freeze":
			return "Здесь и без того было холодно!" if bool(world_object.get("initial_cold_aura", true)) else ""
		&"cover":
			return "Завешенное зеркало — не то, чего я ожидала от ремонта. Но если другого выхода нет, пусть пока будет так."
		&"physical_move":
			return "Это было фамильное зеркало!"
	return ""


func install_cage(employee_id: StringName, has_cage: bool) -> Dictionary:
	action_before = _object_snapshots()
	if not has_cage:
		return _record(employee_id, &"install_cage", false, true, "Клетки нет в снаряжении бригады.")
	if str(world_object.get("cage_state", "packed")) != "packed":
		return _record(employee_id, &"install_cage", false, false, "Клетка уже установлена.")
	world_object["cage_state"] = "installed"
	return _record(employee_id, &"install_cage", true, false, "Клетка установлена.")


func apply_action(employee_id: StringName, action_id: StringName, has_protective_cloth: bool = true) -> Dictionary:
	action_before = _object_snapshots()
	var refusal := ObjectRules.refusal_reason(action_id, world_object)
	if not refusal.is_empty():
		return _record(employee_id, action_id, false, true, preload("res://scripts/employee_reaction_resolver.gd").refusal_for(refusal))
	var applied := false
	var warning := false
	var message := "Действие не изменило состояние зеркала."
	var state_refusal := refusal_message(action_id, has_protective_cloth)
	if action_id != &"diagnose" and not state_refusal.is_empty():
		return _record(employee_id, action_id, false, true, state_refusal)

	match action_id:
		&"diagnose":
			applied = true
			if employee_id == &"boris":
				world_object["inspected"] = true
			if bool(world_object["destroyed"]):
				message = "Зеркало разбито. Воздействовать больше не на что."
			elif not bool(world_object["portal_open"]):
				message = "Портал уже закрыт. Зеркало выглядит обычным."
			elif bool(world_object["covered"]):
				message = "Полотно удерживается креплениями, но портал под ним остаётся открытым. Бестелесное существо сможет пройти сквозь ткань."
			else:
				message = ("Портал излучает холод. " if bool(world_object["cold_aura"]) else "" if not bool(world_object.get("initial_cold_aura", true)) else "Иней растаял, в комнате снова стало тепло. ") + "Связь можно закрыть антимагией, временно изолировать защитным полотном или оборвать, уничтожив зеркало."
		&"antimagic":
			if bool(world_object["covered"]):
				warning = true
				message = "Закрыть портал через защитное полотно нельзя. Сначала снимите полотно."
			else:
				applied = true
				world_object["magic_level"] = 0
				world_object["portal_open"] = false
				world_object["cold_aura"] = false
				message = "Антимагия погасила связь. Портал закрыт, зеркало не повреждено." if int(world_object["damage"]) == 0 else "Портал закрыт, но рама зеркала осталась деформированной после нагрева."
		&"freeze":
			applied = true
			world_object["temperature"] = int(world_object["temperature"]) - int(world_object["temperature_step"])
			world_object["stable"] = true
			message = "Холод стабилизировал края портала, но не закрыл его."
		&"heat":
			applied = true
			world_object["temperature"] = int(world_object["temperature"]) + int(world_object["temperature_step"])
			if bool(world_object["cold_aura"]):
				world_object["cold_aura"] = false
				message = "Иней растаял, в комнате снова стало тепло."
			else:
				warning = true
				world_object["stable"] = false
				if int(world_object["damage"]) == 0:
					world_object["damage"] = 1
					message = "Повторный нагрев расшатал портал. Рама зеркала начала деформироваться."
				else:
					message = "Огонь снова охватил уже оплавленную раму, но её состояние заметно не изменилось."
		&"telekinesis":
			warning = true
			message = "Активный портал удерживает зеркало на месте. Телекинез не может безопасно его сдвинуть."
		&"repair":
			warning = true
			message = "Такую раму нельзя восстановить на выезде: потребуется мастерская или изготовление замены."
		&"cover":
			if not has_protective_cloth:
				warning = true
				message = "В бригаде нет защитного полотна. Его можно купить в лавке снабжения."
			elif bool(world_object["covered"]):
				message = "Защитное полотно уже закреплено на раме."
			else:
				applied = true
				world_object["covered"] = true
				message = "Портал закрыт плотным защитным полотном, закреплённым механическими зажимами. Это временная изоляция: портал остаётся открытым под тканью."
		&"uncover":
			if not bool(world_object["covered"]):
				message = "Защитное полотно уже снято."
			else:
				applied = true
				world_object["covered"] = false
				message = "Борис снял защитное полотно. Портал снова открыт и доступен для работы."
		&"physical_move":
			applied = true
			warning = true
			world_object["portal_open"] = false
			world_object["destroyed"] = true
			world_object["magic_level"] = 0
			world_object["damage"] = 10
			world_object["covered"] = false
			world_object["cold_aura"] = false
			message = "Зеркало разбито. Портал исчез, но имущество уничтожено."

	if action_id == &"diagnose" and bool(world_object.get("portal_silhouette", false)) and bool(world_object["portal_open"]) and not bool(world_object["covered"]):
		message += " В портале виден силуэт."
	if action_id == &"diagnose" and int(world_object["damage"]) > 0 and not bool(world_object["destroyed"]):
		message += " Рама зеркала деформирована нагревом."
	return _record(employee_id, action_id, applied, warning, message)


func lunnopuh_properties() -> Dictionary:
	var properties := Lunnopuh.base_properties.duplicate(true)
	properties["definition_id"] = &"lunnopuh"
	properties["instance_id"] = "portal_mirror_room.lunnopuh"
	properties["state"] = str(world_object.get("lunnopuh_state", "absent"))
	properties["inspected"] = bool(world_object.get("lunnopuh_inspected", false))
	properties["position_offset_x"] = float(world_object.get("lunnopuh_offset_x", 0.0))
	properties["position_offset_y"] = float(world_object.get("lunnopuh_offset_y", 0.0))
	properties["cage_packed"] = str(world_object.get("cage_state", "packed")) == "packed"
	properties["cage_ready"] = str(world_object.get("cage_state", "packed")) == "installed"
	properties["portal_available"] = bool(world_object["portal_open"]) and not bool(world_object["covered"]) and not bool(world_object["destroyed"])
	return properties


func cage_properties() -> Dictionary:
	var properties := Cage.base_properties.duplicate(true)
	properties["definition_id"] = &"lunnopuh_cage"
	properties["state"] = "occupied" if str(world_object.get("lunnopuh_state", "absent")) == "caged" else str(world_object.get("cage_state", "packed"))
	return properties


func _object_snapshots() -> Dictionary:
	return {String(world_object["instance_id"]): world_object.duplicate(true), "portal_mirror_room.lunnopuh": lunnopuh_properties(), "portal_mirror_room.lunnopuh_cage": cage_properties()}


func lunnopuh_actions(employee_id: StringName) -> PackedStringArray:
	if str(world_object.get("lunnopuh_state", "absent")) not in ["free", "caged"]:
		return PackedStringArray()
	if employee_id == &"boris" and not bool(world_object.get("lunnopuh_inspected", false)):
		return PackedStringArray(["diagnose"])
	var actions := PackedStringArray(Lunnopuh.base_properties.get("supported_actions", []))
	var object_actions: Dictionary = Lunnopuh.base_properties.get("object_actions", {})
	for action: String in object_actions:
		var profile: Dictionary = object_actions.get(action, {})
		if not PackedStringArray(profile.get("states", [])).has(str(world_object.get("lunnopuh_state", "absent"))):
			continue
		var actor_ids := PackedStringArray(profile.get("employee_ids", []))
		if not actor_ids.is_empty() and not actor_ids.has(String(employee_id)):
			continue
		actions.append(action)
	return actions


func lunnopuh_refusal(action_id: StringName, has_cage: bool = true) -> String:
	var properties := lunnopuh_properties()
	properties["cage_available"] = has_cage
	return ObjectRules.state_refusal_message(action_id, properties)


func lunnopuh_reaction(action_id: StringName, after_action: bool = false, employee_id: StringName = &"") -> String:
	var profile: Dictionary = (Lunnopuh.base_properties.get("object_actions", {}) as Dictionary).get(String(action_id), {})
	if after_action:
		var replies: Dictionary = profile.get("reaction_after_by_employee", {})
		if replies.has(String(employee_id)):
			return str(replies[String(employee_id)])
	return str(profile.get("reaction_after" if after_action else "reaction", ""))


func apply_lunnopuh_action(employee_id: StringName, action_id: StringName) -> Dictionary:
	action_before = _object_snapshots()
	if not lunnopuh_actions(employee_id).has(String(action_id)):
		return _record(employee_id, action_id, false, true, "Это действие сейчас недоступно для лунопуха.")
	var refusal := lunnopuh_refusal(action_id)
	if not refusal.is_empty():
		return _record(employee_id, action_id, false, true, refusal)
	if action_id == &"install_cage":
		return install_cage(employee_id, bool(world_object.get("cage_available", false)))
	if action_id in [&"catch_hand", &"catch_into_cage"]:
		if not bool(world_object.get("lunnopuh_escape_pending", false)):
			escape_lunnopuh()
		world_object["lunnopuh_escape_pending"] = false
		return _record(employee_id, action_id, false, false, "Лунопух убежал. Поймать его руками не удалось.")
	if action_id == &"catch_lunnopuh":
		world_object["lunnopuh_state"] = "caged"
		world_object["cage_state"] = "occupied"
		return _record(employee_id, action_id, true, false, "Лунопух пойман в клетку.")
	if action_id == &"return_lunnopuh":
		world_object["lunnopuh_state"] = "returned"
		if str(world_object.get("cage_state", "packed")) == "occupied":
			world_object["cage_state"] = "installed"
		return _record(employee_id, action_id, true, false, "Лунопух вернулся в свой мир. Портал всё ещё открыт.")
	if action_id == &"diagnose":
		world_object["lunnopuh_inspected"] = true
		return _record(employee_id, action_id, true, false, "Лунопух находится в клетке." if str(world_object.get("lunnopuh_state", "absent")) == "caged" else "Зверек на вид быстрый и осторожный, возможно получится его загнать в клетку. Еще как вариант - загнать обратно в портал.")
	return _record(employee_id, action_id, false, true, "Это действие сейчас недоступно для лунопуха.")


func escape_lunnopuh(left_offset: float = -668.0, top_offset: float = 0.0) -> void:
	var moving_left := float(world_object.get("lunnopuh_offset_x", 0.0)) == 0.0 and float(world_object.get("lunnopuh_offset_y", 0.0)) == 0.0
	world_object["lunnopuh_offset_x"] = left_offset if moving_left else 0.0
	world_object["lunnopuh_offset_y"] = top_offset if moving_left else 0.0
	world_object["lunnopuh_escape_pending"] = true


func is_resolved() -> bool:
	var goal: Dictionary = world_object.get("resolution", Anomaly.resolution)
	for property_name: String in goal.get("allowed_values", {}):
		if not PackedStringArray(goal["allowed_values"][property_name]).has(str(world_object.get(property_name, ""))):
			return false
	for key: String in goal.get("required_false", []):
		if not bool(world_object.get(key, false)):
			return true
	for key: String in goal.get("alternative_true", []):
		if bool(world_object.get(key, false)):
			return true
	return false


func visual_state() -> StringName:
	if bool(world_object["destroyed"]):
		return &"destroyed"
	if bool(world_object["covered"]):
		return &"covered_heat_damaged" if int(world_object["damage"]) > 0 else &"covered"
	if bool(world_object["portal_open"]) and int(world_object["damage"]) > 0:
		return &"heat_damaged"
	if not bool(world_object["portal_open"]):
		return &"closed_heat_damaged" if int(world_object["damage"]) > 0 else &"closed"
	return &"open"


func get_completion_result() -> Dictionary:
	if not is_resolved():
		return {}
	var result := _completion_from_properties()
	var helpful := PackedStringArray()
	for entry: Dictionary in action_log:
		var legacy_useful := bool(entry.get("legacy_useful_work", false)) and (str(entry.get("action_id", "")) != "cover" or bool(world_object["covered"]))
		if legacy_useful and not helpful.has(str(entry.get("employee_id", ""))):
			helpful.append(str(entry["employee_id"]))
		for change: Dictionary in entry.get("object_changes", []):
			var before: Dictionary = change.get("before", {})
			var after: Dictionary = change.get("after", {})
			var useful := (bool(before.get("portal_open", false)) and not bool(after.get("portal_open", false))) or (bool(before.get("cold_aura", false)) and not bool(after.get("cold_aura", false))) or (not bool(before.get("covered", false)) and bool(after.get("covered", false)) and bool(world_object["covered"]))
			var employee := str(entry.get("employee_id", ""))
			if useful and not bool((entry.get("result", {}) as Dictionary).get("caused_damage", false)) and not helpful.has(employee):
				helpful.append(employee)
	for entry: Dictionary in action_log:
		for change: Dictionary in entry.get("object_changes", []):
			if str(change.get("target_instance_id", "")) != "portal_mirror_room.lunnopuh":
				continue
			var before: Dictionary = change.get("before", {})
			var after: Dictionary = change.get("after", {})
			if str(before.get("state", "")) in ["free", "caged"] and str(after.get("state", "")) in ["caged", "returned"] and before.get("state") != after.get("state"):
				var employee := str(entry.get("employee_id", ""))
				if not helpful.has(employee):
					helpful.append(employee)
	var creature_state := str(world_object.get("lunnopuh_state", "absent"))
	if creature_state in ["caged", "returned"]:
		var fact := "Лунопух пойман и оставлен в клетке у Селесты." if creature_state == "caged" else "Лунопух возвращён в свой мир."
		result["summary"] = str(result.get("summary", "")) + " " + fact
		(result["consequences"] as Array).append(fact)
	if creature_state in ["caged", "returned"]:
		var pet_review := "Я так рада новому питомцу! Спасибо, что поймали Лунопуха" if creature_state == "caged" else "Какой милый был зверёк… Но теперь он дома, и я за него спокойна. Спасибо!"
		result["review"] = str(result.get("review", "")) + " " + pet_review
	if creature_state == "caged":
		for entry: Dictionary in action_log:
			for change: Dictionary in entry.get("object_changes", []):
				if str(change.get("target_instance_id", "")) == "portal_mirror_room.lunnopuh_cage" and str(change["before"].get("state", "packed")) == "packed" and str(change["after"].get("state", "")) == "installed":
					var employee := str(entry.get("employee_id", ""))
					if not helpful.has(employee):
						helpful.append(employee)
	if creature_state == "caged":
		result["expense_reimbursement"] = int(result.get("expense_reimbursement", 0)) + int(Cage.base_properties.get("replacement_value", 250))
		result["retained_supply_items"] = ["lunnopuh_cage"]
	elif str(world_object.get("cage_state", "packed")) == "installed":
		result["returned_supply_items"] = ["lunnopuh_cage"]
		result["completion_object_updates"] = {"cage_state": "packed"}
		result["completion_related_updates"] = {"portal_mirror_room.lunnopuh_cage": {"state": "packed"}}
	result["credit_helpful_work_on_damage"] = bool(world_object.get("credit_helpful_work_on_damage", false))
	result["successful_employee_ids"] = Array(helpful)
	return result


func _completion_from_properties() -> Dictionary:
	var destroyed := bool(world_object["destroyed"])
	var covered := bool(world_object["covered"]) and not destroyed
	var cold_remains := bool(world_object["cold_aura"])
	if covered:
		var frame_damage := int(world_object["damage"])
		var consequences: Array[String] = ["Портал только временно изолирован."]
		if cold_remains:
			consequences.append("В комнате сохранилась аномальная стужа.")
		if frame_damage > 0:
			consequences.append("Рама зеркала деформирована нагревом.")
		consequences.append("Из портала успел выбраться призрак.")
		var summary := "Портал закрыт полотном, но в комнате всё ещё холодно." if cold_remains else "Холод устранён, портал временно изолирован защитным полотном." if bool(world_object.get("initial_cold_aura", true)) else "Портал временно изолирован защитным полотном."
		if frame_damage > 0:
			summary += tr(" Рама зеркала деформирована нагревом.")
		var review := "Полотно очень милое. Голоса из зеркала стали тише, а зубы всё ещё стучат в полный голос." if cold_remains else "Портал теперь под покрывалом. Не совсем ремонт, зато отражение наконец перестало спорить со мной."
		if frame_damage > 0:
			review = "Портал вы спрятали под полотном, но раму перед этим успели оплавить. Теперь зеркало выглядит так, будто его ремонтировали свечой."
		return {
			"summary": summary,
			"review": review,
			"consequences": consequences,
			"reward_adjustment": (-int(world_object["cold_cover_payment_penalty"]) if cold_remains else -int(world_object["warm_cover_payment_penalty"])) - (int(world_object["frame_damage_payment_penalty"]) if frame_damage > 0 else 0),
			"expense_reimbursement": int(world_object["cloth_reimbursement"]),
			"compensation_cost": 0,
			"reputation_change": -2 if frame_damage > 0 else (-1 if cold_remains else 0),
			"follow_up": {
				"type": "escaped_ghost",
				"source_job_id": "portal_mirror",
				"cold_aura": cold_remains,
				"frame_damage": frame_damage,
				"lunnopuh_state": str(world_object.get("lunnopuh_state", "absent")),
				"cage_state": str(world_object.get("cage_state", "packed")),
			},
			"actions": action_log.duplicate(true),
		}
	if destroyed:
		return {
			"summary": "Портал закрыт ценой уничтоженного зеркала.",
			"review": "Портал закрыт. Зеркало тоже, причём навсегда. Придётся любоваться собой по памяти.",
			"consequences": ["Старинное зеркало уничтожено.", "Служба выплачивает компенсацию за зеркало."],
			"reward_adjustment": -200,
			"forfeit_payment": true,
			"compensation_cost": int(world_object["compensation_value"]),
			"reputation_change": -2,
			"actions": action_log.duplicate(true),
		}
	var closed_frame_damage := int(world_object["damage"])
	return {
		"summary": "Портал закрыт, зеркало сохранено." if closed_frame_damage == 0 else "Портал закрыт, но рама зеркала осталась деформированной после нагрева.",
		"review": "Наконец-то зеркало снова показывает только меня. Никогда не думала, что буду так рада обычному отражению." if closed_frame_damage == 0 else "Портал закрыт, но оплавленная рама никуда не делась. Хорошо хоть отражение снова моё.",
		"consequences": ["Дополнительного ущерба не зафиксировано."] if closed_frame_damage == 0 else ["Рама зеркала деформирована нагревом."],
		"reward_adjustment": -int(world_object["frame_damage_payment_penalty"]) if closed_frame_damage > 0 else 0,
		"compensation_cost": 0,
		"reputation_change": -1 if closed_frame_damage > 0 else 1,
		"actions": action_log.duplicate(true),
	}


func _record(employee_id: StringName, action_id: StringName, applied: bool, warning: bool, message: String) -> Dictionary:
	var result := {"applied": applied, "warning": warning, "message": message, "resolved": is_resolved()}
	world_object["visual_state"] = visual_state()
	action_log.append(ObjectRules.action_event(employee_id, action_id, action_before, _object_snapshots(), result))
	return result
