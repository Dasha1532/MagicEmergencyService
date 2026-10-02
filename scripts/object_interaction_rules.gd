class_name ObjectInteractionRules
extends RefCounted

const FAUCET := preload("res://data/objects/lava_faucet.tres")

# Наличие действия не зависит от временных препятствий (жар, лёд, экипировка).
static func action_profile(action_id: StringName) -> Dictionary:
	return (FAUCET.base_properties.get("object_actions", {}) as Dictionary).get(String(action_id), {}) as Dictionary

static func is_destroyed(properties: Dictionary) -> bool:
	var tags := PackedStringArray(properties.get("tags", []))
	return bool(properties.get("destroyed", false)) or bool(properties.get("broken", false)) or bool(properties.get("valve_broken", false)) or tags.has("destroyed") or tags.has("broken") or tags.has("melted")

static func is_applicable(action_id: StringName, properties: Dictionary) -> bool:
	var profile := action_profile(action_id)
	if bool(profile.get("requires_intact_target", false)) and is_destroyed(properties):
		return false
	for feature: String in PackedStringArray(profile.get("required_features", [])):
		if not bool(properties.get(feature, FAUCET.base_properties.get(feature, false))):
			return false
	return true

static func contextual_actions(properties: Dictionary, employee: Dictionary) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	var abilities := PackedStringArray(employee.get("abilities", []))
	for action_id: String in (FAUCET.base_properties.get("object_actions", {}) as Dictionary):
		var profile := action_profile(StringName(action_id))
		if not bool(profile.get("contextual", false)) or not is_applicable(StringName(action_id), properties):
			continue
		for ability: String in PackedStringArray(profile.get("actor_abilities", [])):
			if abilities.has(ability):
				actions.append({"id": StringName(action_id), "label": str(profile["label"])})
				break
	return actions

static func resolves_on_impact(action_id: StringName) -> bool:
	return str(action_profile(action_id).get("execution", "timed")) == "impact"

static func valve_block_reason(properties: Dictionary, employee: Dictionary = {}, remote: bool = false) -> String:
	if is_destroyed(properties) or bool(properties.get("valve_broken", false)):
		return "Вентиль сломан и больше не управляет краном."
	if bool(properties.get("valve_frozen", properties.get("frozen", false))):
		return "Вентиль примёрз и не поворачивается. Сначала его нужно отогреть."
	if not bool(properties.get("valve_operable", true)):
		return "Механизм вентиля заклинило."
	var tags := PackedStringArray(properties.get("tags", []))
	var hot := int(properties.get("temperature", 0)) >= int(FAUCET.base_properties.get("contact_heat_threshold", 10)) or tags.has("overheated") or tags.has("lava_flowing") or bool(properties.get("lava_source_active", false))
	var protected := PackedStringArray(employee.get("protections", [])).has("contact_heat") or bool(properties.get("heat_gloves_available", false))
	if hot and not remote and not protected:
		return "Металл раскалён. Без термостойких рукавиц вентиль трогать нельзя."
	return ""

static func valve_preflight_reason(properties: Dictionary, employee: Dictionary = {}) -> String:
	# Лёд и заклинивание обнаруживаются при попытке, опасный контакт — заранее.
	var contact_properties := properties.duplicate(true)
	contact_properties["valve_frozen"] = false
	contact_properties["valve_operable"] = true
	return valve_block_reason(contact_properties, employee)

# Один контракт переходов для акта, компенсации и памяти: ущерб определяется
# изменением свойств, а не именем сотрудника или названием заявки.
static func action_event(employee_id: StringName, action_id: StringName, before: Dictionary, after: Dictionary, result: Dictionary) -> Dictionary:
	var changes: Array[Dictionary] = []
	var damaged_targets: Array[String] = []
	var destroyed_targets: Array[String] = []
	for target_id: String in after:
		var old: Dictionary = before.get(target_id, {}) as Dictionary
		var current: Dictionary = after[target_id] as Dictionary
		var destroyed := not is_destroyed(old) and is_destroyed(current)
		var damaged := destroyed or int(current.get("damage", 0)) > int(old.get("damage", 0)) or (bool(current.get("damaged", false)) and not bool(old.get("damaged", false)))
		if damaged:
			damaged_targets.append(target_id)
		if destroyed:
			destroyed_targets.append(target_id)
		if old != current:
			changes.append({"target_instance_id": target_id, "before": old.duplicate(true), "after": current.duplicate(true)})
	result["caused_damage"] = bool(result.get("applied", false)) and not damaged_targets.is_empty()
	result["damage_target_ids"] = damaged_targets if bool(result["caused_damage"]) else []
	result["destroyed_target_ids"] = destroyed_targets if bool(result["caused_damage"]) else []
	return {"employee_id": String(employee_id), "action_id": String(action_id), "object_changes": changes, "result": result.duplicate(true)}


static func apply_telekinesis(world_object: Dictionary, target_zone: StringName = &"") -> Dictionary:
	if bool(world_object.get("destroyed", false)):
		return _result(false, "Объект уничтожен: телекинезу больше не на что воздействовать.")
	if bool(world_object.get("anchored", false)):
		return _result(false, "Объект закреплён и не может быть перемещён телекинезом.")
	if not bool(world_object.get("movable", true)):
		return _result(false, "Свойства объекта не позволяют переместить его телекинезом.")

	if target_zone.is_empty():
		return _result(false, "Сначала выберите место, куда нужно переместить объект.")
	if StringName(str(world_object.get("position_zone", ""))) == target_zone:
		return _result(false, "Объект уже находится в выбранном месте.")

	world_object["position_zone"] = target_zone
	world_object["held"] = false
	return _result(true, "Объект аккуратно перемещён в выбранное место.")


static func _result(applied: bool, summary: String) -> Dictionary:
	return {
		"applied": applied,
		"summary": summary,
	}
