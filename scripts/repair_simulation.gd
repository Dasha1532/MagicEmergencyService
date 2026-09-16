class_name RepairSimulation
extends RefCounted

static var REACTION_RULES: Array[Dictionary] = [
	{
		"action_id": &"freeze",
		"required_tag": &"lava_flowing",
		"add_tags": ["stabilized", "repaired"],
		"remove_tags": ["lava_flowing", "overheated"],
		"message": "Лава застыла, давление сброшено. Кран снова безопасен.",
		"visual_state": &"repaired",
	},
	{
		"action_id": &"heat",
		"required_tag": &"lava_flowing",
		"forbidden_tag": &"overheated",
		"add_tags": ["overheated"],
		"damage": 1,
		"message": "Нагрев усилил течение. Отделке нанесён дополнительный ущерб.",
		"visual_state": &"overheated",
	},
]

var world_object: Dictionary = {
	"definition_id": &"lava_faucet",
	"tags": PackedStringArray(["faucet", "lava_flowing", "pressurized"]),
	"temperature": 9,
	"pressure": 8,
	"damage": 0,
	"visual_state": &"emergency",
}
var action_log: Array[Dictionary] = []


func apply_action(employee_id: StringName, action_id: StringName) -> Dictionary:
	for rule: Dictionary in REACTION_RULES:
		if rule["action_id"] != action_id or not _matches(rule):
			continue
		_apply_rule(rule)
		var result := {
			"applied": true,
			"message": str(rule["message"]),
			"visual_state": rule["visual_state"],
			"resolved": is_resolved(),
		}
		action_log.append({
			"employee_id": String(employee_id),
			"action_id": String(action_id),
			"result": result.duplicate(true),
		})
		return result

	var no_effect := {
		"applied": false,
		"message": "Это действие не влияет на раскалённый кран.",
		"visual_state": world_object["visual_state"],
		"resolved": is_resolved(),
	}
	action_log.append({
		"employee_id": String(employee_id),
		"action_id": String(action_id),
		"result": no_effect.duplicate(true),
	})
	return no_effect


func is_resolved() -> bool:
	return _tags().has("repaired")


func get_completion_result() -> Dictionary:
	var damage: int = int(world_object.get("damage", 0))
	var summary := "Поток лавы остановлен, давление сброшено, кран принят в исправном состоянии."
	if damage > 0:
		summary += " За дополнительный перегрев удержана компенсация за повреждение отделки."
	return {
		"reward_adjustment": -80 * damage,
		"reputation_change": -damage,
		"summary": summary,
		"actions": action_log.duplicate(true),
	}


func _matches(rule: Dictionary) -> bool:
	var tags := _tags()
	if not tags.has(String(rule.get("required_tag", ""))):
		return false
	var forbidden_tag := String(rule.get("forbidden_tag", ""))
	return forbidden_tag.is_empty() or not tags.has(forbidden_tag)


func _apply_rule(rule: Dictionary) -> void:
	var tags := _tags()
	for removed_tag: String in rule.get("remove_tags", PackedStringArray()):
		if tags.has(removed_tag):
			tags.remove_at(tags.find(removed_tag))
	for added_tag: String in rule.get("add_tags", PackedStringArray()):
		if not tags.has(added_tag):
			tags.append(added_tag)
	world_object["tags"] = tags
	world_object["damage"] = int(world_object.get("damage", 0)) + int(rule.get("damage", 0))
	world_object["visual_state"] = rule["visual_state"]
	if rule["action_id"] == &"freeze":
		world_object["temperature"] = 2
		world_object["pressure"] = 1
	elif rule["action_id"] == &"heat":
		world_object["temperature"] = 10
		world_object["pressure"] = 10


func _tags() -> PackedStringArray:
	return world_object["tags"]
