class_name GenerativeObjectDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var tags: PackedStringArray
@export var base_properties: Dictionary = {}
@export var supported_effects: PackedStringArray
@export var scene_path: String
@export var visual_states: Dictionary = {}
@export var visual_overlays: Dictionary = {}
@export var procedural_states: PackedStringArray
@export var hidden_states: PackedStringArray


func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"tags": tags,
		"base_properties": base_properties.duplicate(true),
		"supported_effects": supported_effects,
		"visual_profile_id": id,
		"visual_profile": {
			"scene_path": scene_path,
			"states": visual_states.duplicate(true),
			"overlays": visual_overlays.duplicate(true),
			"procedural_states": procedural_states,
			"hidden_states": hidden_states,
		},
	}
