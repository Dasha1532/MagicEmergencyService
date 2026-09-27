class_name EmployeeReactionResolver
extends RefCounted

const ABILITY_REACTION_FALLBACKS: Dictionary = {
	&"freeze": "Понижу температуру. Надеюсь, в этот раз холод действительно нужен.",
	&"heat": "Подниму температуру постепенно, без новых аварийных эффектов.",
	&"telekinesis": "Уберу это с дороги, ничего лишнего не задевая.",
	&"antimagic": "Сниму активные чары и проверю, что магический след исчез.",
	&"animate": "Попробую оживление. Сначала убедимся, что предмет настроен дружелюбно.",
}


static func reaction_for(employee: Dictionary, action_id: StringName, world_object: Dictionary, intent: StringName = &"", contextual_text: String = "", include_ability_fallback: bool = false) -> String:
	if not contextual_text.strip_edges().is_empty():
		return contextual_text.strip_edges()
	var rules: Variant = employee.get("action_reactions", [])
	if rules is Array:
		for rule_variant: Variant in rules:
			if not rule_variant is Dictionary:
				continue
			var rule: Dictionary = rule_variant
			if not _matches_ids(rule.get("action_ids", []), action_id):
				continue
			if rule.has("intent_ids") and not _matches_ids(rule.get("intent_ids", []), intent):
				continue
			if not _matches_object(rule, world_object):
				continue
			var text := str(rule.get("text", ""))
			if not text.is_empty():
				return text
			var texts: Variant = rule.get("texts", [])
			if texts is Array and not texts.is_empty():
				var variant_index := posmod(hash([String(action_id), String(intent), world_object]), texts.size())
				return str(texts[variant_index])
	if include_ability_fallback:
		var personal_value: Variant = employee.get("ability_reactions", {})
		if personal_value is Dictionary:
			var personal: Dictionary = personal_value
			var personal_text := str(personal.get(action_id, "")).strip_edges()
			if not personal_text.is_empty():
				return personal_text
		return str(ABILITY_REACTION_FALLBACKS.get(action_id, "")).strip_edges()
	return ""


static func no_effect_for(employee_id: StringName) -> String:
	return {
		&"liliya": "Похоже, без изменений. Значит, одного температурного воздействия здесь недостаточно.",
		&"grog": "Не поддалось. Давить сильнее без причины не буду.",
		&"boris": "Без изменений. Значит, причина не в механике — или сначала требуется другое действие.",
		&"nika": "Не сдвинулось ни на палец. Либо закреплено, либо очень упрямо.",
		&"felix": "Воздействие результата не дало. Магический фон не изменился.",
	}.get(employee_id, "Действие не изменило состояние объекта.")


static func _matches_ids(configured_ids: Variant, actual_id: StringName) -> bool:
	if configured_ids is PackedStringArray:
		return (configured_ids as PackedStringArray).has(String(actual_id))
	if configured_ids is Array:
		for configured_id: Variant in configured_ids:
			if StringName(str(configured_id)) == actual_id:
				return true
	return false


static func _matches_object(rule: Dictionary, world_object: Dictionary) -> bool:
	var equals: Variant = rule.get("object_equals", {})
	if equals is Dictionary:
		for key: Variant in equals:
			if not world_object.has(key) or world_object[key] != equals[key]:
				return false

	var minimums: Variant = rule.get("object_min", {})
	if minimums is Dictionary:
		for key: Variant in minimums:
			if not world_object.has(key) or float(world_object[key]) < float(minimums[key]):
				return false

	var maximums: Variant = rule.get("object_max", {})
	if maximums is Dictionary:
		for key: Variant in maximums:
			if not world_object.has(key) or float(world_object[key]) > float(maximums[key]):
				return false

	var required_tags: Variant = rule.get("required_tags", [])
	if required_tags is Array or required_tags is PackedStringArray:
		var object_tags := PackedStringArray(world_object.get("tags", PackedStringArray()))
		for required_tag: Variant in required_tags:
			if not object_tags.has(str(required_tag)):
				return false
	return true
