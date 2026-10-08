extends RefCounted

var definition: Resource
var state: Dictionary = {}

func initialize(content: Resource) -> void:
	definition = content
	state = content.initial_state.duplicate(true)

func available(action_id: String) -> bool:
	if not definition.actions.has(action_id):
		return false
	var action: Dictionary = definition.actions[action_id]
	for key: String in action.get("requires", {}):
		if state.get(key) != action["requires"][key]:
			return false
	return true

func apply(action_id: String) -> bool:
	if not available(action_id):
		return false
	var action: Dictionary = definition.actions[action_id]
	state.merge(action.get("effects", {}).duplicate(true), true)
	return true

func get_state() -> Dictionary:
	return {"version": 1, "properties": state.duplicate(true)}

func load_state(saved: Dictionary) -> bool:
	if int(saved.get("version", 0)) != 1 or not saved.get("properties") is Dictionary:
		return false
	state = definition.initial_state.duplicate(true)
	state.merge(saved["properties"].duplicate(true), true)
	return true
