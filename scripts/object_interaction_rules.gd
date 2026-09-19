class_name ObjectInteractionRules
extends RefCounted


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
