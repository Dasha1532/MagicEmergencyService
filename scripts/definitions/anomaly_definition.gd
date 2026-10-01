class_name GenerativeAnomalyDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var generator_enabled: bool = false
@export var tutorial_eligible: bool = false
@export var compatible_object_ids: PackedStringArray
@export var required_tags: PackedStringArray
@export var forbidden_tags: PackedStringArray
@export var initial_effects: PackedStringArray
@export var objective_ids: PackedStringArray
@export var initial_state: Dictionary = {}
@export var resolution: Dictionary = {}
@export var solution_plans: Array[Dictionary] = []
@export var visual_effects: PackedStringArray
@export var presentation: Dictionary = {}
@export var completion: Dictionary = {}
@export var weight: int = 1


func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"generator_enabled": generator_enabled,
		"tutorial_eligible": tutorial_eligible,
		"compatible_object_ids": compatible_object_ids,
		"required_tags": required_tags,
		"forbidden_tags": forbidden_tags,
		"initial_effects": initial_effects,
		"objective_ids": objective_ids,
		"initial_state": initial_state.duplicate(true),
		"resolution": resolution.duplicate(true),
		"solution_plans": solution_plans.duplicate(true),
		"visual_effects": visual_effects,
		"presentation": presentation.duplicate(true),
		"completion": completion.duplicate(true),
		"weight": weight,
	}
