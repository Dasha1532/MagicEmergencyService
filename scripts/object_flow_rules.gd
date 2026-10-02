extends RefCounted

# Поток меняет содержимое принимающего объекта, а не цель заявки.
const CONTENT_RULES: Array[Dictionary] = [
	{"content": "ice", "target_property": "contains_ice", "value": true},
]

static func is_flowing(source: Dictionary, content: String = "") -> bool:
	if PackedStringArray(source.get("tags", [])).has("sealed_by_melt"):
		return false
	if str(source.get("valve_position", "closed")) != "open" or bool(source.get("flow_blocked", false)):
		return false
	if not bool(source.get("valve_operable", true)) or bool(source.get("broken", false)):
		return false
	return content.is_empty() or str(source.get("flow_content", "none")) == content

static func apply_flow(source: Dictionary, target: Dictionary) -> bool:
	if not is_flowing(source):
		return false
	var changed := false
	for rule: Dictionary in CONTENT_RULES:
		if str(source.get("flow_content", "none")) != str(rule["content"]):
			continue
		var property_name := str(rule["target_property"])
		if target.get(property_name) != rule["value"]:
			target[property_name] = rule["value"]
			changed = true
	return changed
