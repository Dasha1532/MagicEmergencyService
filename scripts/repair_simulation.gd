class_name RepairSimulation
extends RefCounted

const ResidentReactionResolverScript := preload("res://scripts/resident_reaction_resolver.gd")
const ObjectInteractionRulesScript := preload("res://scripts/object_interaction_rules.gd")

const FREEZE_STEP: int = 7
const HEAT_STEP: int = 5
const FROST_THRESHOLD: int = 2
const OVERHEAT_THRESHOLD: int = 10
const MELT_THRESHOLD: int = 15

var world_object: Dictionary = {
	"definition_id": &"lava_faucet",
	"tags": PackedStringArray(["faucet", "lava_flowing", "pressurized"]),
	"temperature": 9,
	"pressure": 8,
	"damage": 0,
	"durability": 5,
	"mass": 8,
	"anchored": true,
	"movable": true,
	"replacement_value": 350,
	"resident_voice_variant": 1,
	"resident_intro_seen": false,
	"frozen": false,
	"burning": false,
	"scorched": false,
	"visual_state": &"emergency",
}
var action_log: Array[Dictionary] = []


func load_state(saved_state: Dictionary) -> void:
	if saved_state.is_empty():
		return
	var saved_object: Variant = saved_state.get("world_object", {})
	if saved_object is Dictionary:
		var saved_object_dictionary: Dictionary = saved_object
		var restored_object: Dictionary = saved_object_dictionary.duplicate(true)
		var restored_tags := PackedStringArray()
		for tag: Variant in restored_object.get("tags", []):
			restored_tags.append(str(tag))
		restored_object["tags"] = restored_tags
		restored_object["definition_id"] = StringName(str(restored_object.get("definition_id", "lava_faucet")))
		restored_object["visual_state"] = StringName(str(restored_object.get("visual_state", "emergency")))
		world_object.merge(restored_object, true)
		# Миграция сохранений, созданных до появления универсальных эффектов.
		if not restored_object.has("frozen"):
			world_object["frozen"] = _tags().has("repaired")
		# Металлический кран нагревается и плавится, но не получает состояние горения.
		world_object["burning"] = false
		if not restored_object.has("scorched"):
			world_object["scorched"] = _tags().has("overheated") or _tags().has("melted") or int(world_object["damage"]) > 0
		if world_object["visual_state"] == &"overheated":
			world_object["temperature"] = maxi(OVERHEAT_THRESHOLD, int(world_object["temperature"]))

	action_log.clear()
	var saved_actions: Variant = saved_state.get("action_log", [])
	if saved_actions is Array:
		for saved_action: Variant in saved_actions:
			if saved_action is Dictionary:
				var saved_action_dictionary: Dictionary = saved_action
				action_log.append(saved_action_dictionary.duplicate(true))


func get_state() -> Dictionary:
	var saved_object := world_object.duplicate(true)
	saved_object["tags"] = Array(_tags())
	return {
		"world_object": saved_object,
		"action_log": action_log.duplicate(true),
	}


func get_resident_request() -> String:
	return "Остановите лаву и приведите кран в безопасное состояние. И осторожнее с ванной — сантехника здесь дорогая!"


func get_resident_message() -> String:
	return ResidentReactionResolverScript.message_for(world_object, get_resident_request(), int(world_object["resident_voice_variant"]))


func get_resident_reaction() -> String:
	# Пустая строка означает, что нового высказывания нет. Начальная просьба
	# показывается комнатой отдельно и никогда не используется как реакция.
	return ResidentReactionResolverScript.message_for(world_object, "", int(world_object["resident_voice_variant"]))


func get_status_title() -> String:
	return ResidentReactionResolverScript.title_for(world_object, "Из крана течёт лава", "Кран")


func apply_action(employee_id: StringName, action_id: StringName) -> Dictionary:
	var applied: bool = false
	var message: String = "Это действие не меняет состояние крана."
	match action_id:
		&"diagnose":
			message = _diagnose_faucet()
			applied = true
		&"repair":
			var repair_result: Dictionary = _apply_technical_repair()
			message = str(repair_result["message"])
			applied = bool(repair_result["applied"])
		&"freeze":
			if _tags().has("melted"):
				message = "Кран уже расплавлен: температурные воздействия больше не могут его восстановить."
			else:
				message = _apply_freeze()
				applied = true
		&"heat":
			if _tags().has("melted"):
				message = "Кран уже расплавлен: температурные воздействия больше не могут его восстановить."
			else:
				message = _apply_heat()
				applied = true
		&"telekinesis":
			var telekinesis_result: Dictionary = ObjectInteractionRulesScript.apply_telekinesis(world_object)
			message = str(telekinesis_result["summary"])
			applied = bool(telekinesis_result["applied"])

	var result := {
		"applied": applied,
		"message": message,
		"visual_state": world_object["visual_state"],
		"resolved": is_resolved(),
	}
	action_log.append({
		"employee_id": String(employee_id),
		"action_id": String(action_id),
		"result": result.duplicate(true),
	})
	return result


func can_begin_action(action_id: StringName) -> bool:
	if action_id != &"repair":
		return true
	return not _tags().has("melted") and not _tags().has("lava_flowing") and int(world_object["temperature"]) < OVERHEAT_THRESHOLD


func _diagnose_faucet() -> String:
	if _tags().has("melted"):
		return "Корпус крана расплавлен. Нужна полная замена, полевой ремонт невозможен."
	if _tags().has("lava_flowing"):
		return "Внутри идёт лава, давление %d, температура %d. Сначала необходимо остановить и охладить поток." % [int(world_object["pressure"]), int(world_object["temperature"])]
	if int(world_object["temperature"]) >= OVERHEAT_THRESHOLD:
		return "Поток остановлен, но металл всё ещё раскалён. Прикасаться к крану пока опасно."
	if int(world_object["damage"]) > 0:
		return "Кран безопасен, но перегрев повредил соединения. Можно выполнить обычный ремонт."
	if _tags().has("repaired"):
		return "Давление сброшено, соединения герметичны, кран исправен."
	return "Магическая опасность устранена. Кран можно привести в рабочее состояние обычным ремонтом."


func _apply_technical_repair() -> Dictionary:
	if _tags().has("melted"):
		return {"applied": false, "message": "Борис осмотрел расплавленный кран: ремонтировать уже нечего, требуется замена."}
	if _tags().has("lava_flowing"):
		return {"applied": false, "message": "Борис не стал прикасаться к крану: сначала нужно остановить поток лавы."}
	if int(world_object["temperature"]) >= OVERHEAT_THRESHOLD:
		return {"applied": false, "message": "Металл всё ещё раскалён. Борис отказывается начинать ремонт, пока кран не остынет."}
	world_object["pressure"] = 0
	world_object["damage"] = maxi(0, int(world_object["damage"]) - 2)
	world_object["scorched"] = int(world_object["damage"]) > 0
	_remove_tag("overheated")
	_add_tag("stabilized")
	_add_tag("repaired")
	world_object["visual_state"] = &"repaired"
	return {"applied": true, "message": "Борис заменил повреждённые уплотнения, подтянул соединения и восстановил кран."}


func is_resolved() -> bool:
	return _tags().has("repaired") or _tags().has("melted")


func get_completion_result() -> Dictionary:
	if _tags().has("melted"):
		return {
			"reward_adjustment": -500,
			"compensation_cost": int(world_object["replacement_value"]),
			"reputation_change": -6,
			"summary": "Кран расплавлен и полностью выведен из строя. Оплаты не будет, служба компенсирует жильцу стоимость замены оборудования.",
			"review": "Я просил починить кран, а не превратить его в современную скульптуру. Впрочем, скульптура хотя бы больше не плюётся лавой.",
			"consequences": ["Кран полностью уничтожен и требует замены.", "Служба компенсирует стоимость оборудования."],
			"actions": action_log.duplicate(true),
		}
	var damage: int = int(world_object.get("damage", 0))
	var summary := "Поток лавы остановлен, давление сброшено, кран принят в исправном состоянии."
	var review := "Спасибо! Из крана снова не течёт лава. Для демона звучит как жалоба, но для владельца ванной — настоящее счастье."
	if damage > 0:
		summary += " За дополнительный перегрев удержана компенсация за повреждение отделки."
		review = "Лаву вы остановили — это главное. А подпалины я назову авторской отделкой, пока не увижу счёт за ремонт."
	return {
		"reward_adjustment": -80 * damage,
		"reputation_change": 1 if damage == 0 else -damage,
		"summary": summary,
		"review": review,
		"consequences": ["Дополнительного ущерба не зафиксировано."] if damage == 0 else ["Отделка ванной повреждена дополнительным перегревом."],
		"actions": action_log.duplicate(true),
	}


func _apply_freeze() -> String:
	world_object["temperature"] = int(world_object["temperature"]) - FREEZE_STEP
	world_object["frozen"] = int(world_object["temperature"]) <= FROST_THRESHOLD
	world_object["burning"] = false
	if int(world_object["temperature"]) <= FROST_THRESHOLD and _tags().has("lava_flowing"):
		_remove_tag("lava_flowing")
		_remove_tag("overheated")
		_add_tag("stabilized")
		_add_tag("repaired")
		world_object["pressure"] = 1
		world_object["visual_state"] = &"repaired"
		return "Лава застыла, давление сброшено. Кран покрылся инеем и снова безопасен."
	if int(world_object["temperature"]) < OVERHEAT_THRESHOLD and _tags().has("overheated"):
		_remove_tag("overheated")
		if _tags().has("lava_flowing"):
			world_object["visual_state"] = &"emergency"
			return "Кран остыл и перестал деформироваться, но поток лавы ещё не остановлен."
		_add_tag("stabilized")
		_add_tag("repaired")
		world_object["visual_state"] = &"repaired"
		return "Кран остыл. Лава не возобновилась, но следы перегрева повлияют на итог работы."
	if bool(world_object["frozen"]):
		return "Температура снизилась, поверхность крана покрылась инеем."
	return "Заморозка охладила кран, но для образования инея холода пока недостаточно."


func _apply_heat() -> String:
	var was_frozen: bool = bool(world_object["frozen"])
	world_object["temperature"] = int(world_object["temperature"]) + HEAT_STEP
	world_object["frozen"] = false
	world_object["burning"] = false
	if int(world_object["temperature"]) >= MELT_THRESHOLD:
		_remove_tag("repaired")
		_remove_tag("stabilized")
		_remove_tag("overheated")
		_add_tag("melted")
		world_object["pressure"] = 0
		world_object["damage"] = maxi(6, int(world_object["damage"]))
		world_object["scorched"] = true
		world_object["visual_state"] = &"melted"
		return "Раскалённый металл не выдержал повторного нагрева: кран расплавился и полностью сломан."
	if int(world_object["temperature"]) >= OVERHEAT_THRESHOLD:
		_remove_tag("repaired")
		_remove_tag("stabilized")
		_add_tag("overheated")
		world_object["pressure"] = 10
		world_object["damage"] = int(world_object["damage"]) + 1
		world_object["scorched"] = true
		world_object["visual_state"] = &"overheated"
		return "Кран раскалился докрасна и начал деформироваться. Ещё один нагрев расплавит металл."
	if was_frozen:
		return "Нагрев растопил иней на кране."
	return "Кран стал горячее, но металл пока сохраняет форму."


func _add_tag(tag: String) -> void:
	var tags := _tags()
	if not tags.has(tag):
		tags.append(tag)
	world_object["tags"] = tags


func _remove_tag(tag: String) -> void:
	var tags := _tags()
	if tags.has(tag):
		tags.remove_at(tags.find(tag))
	world_object["tags"] = tags


func _tags() -> PackedStringArray:
	return world_object["tags"]
