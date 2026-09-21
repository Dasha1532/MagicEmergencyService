class_name EmployeeReactionResolver
extends RefCounted


static func reaction_for(employee: Dictionary, action_id: StringName, world_object: Dictionary, intent: StringName = &"") -> String:
	var rules: Variant = employee.get("action_reactions", [])
	if not rules is Array:
		return ""
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
		if text.is_empty():
			continue
		return text
	return ""


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
