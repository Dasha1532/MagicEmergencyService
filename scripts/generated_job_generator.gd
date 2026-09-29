class_name GeneratedJobGenerator
extends RefCounted

const Catalog := preload("res://scripts/generative_job_catalog.gd")

const GENERATOR_VERSION: int = 1
const JOB_ID: StringName = &"generated_wardrobe_1"
const REQUESTED_ZONES: PackedStringArray = ["left_wall", "kitchen_passage"]
const URGENCY_VARIANTS: Array[Dictionary] = [
	{"id": &"normal", "label": "Обычная", "initial_time": 110, "base_reward": 390},
	{"id": &"important", "label": "Важно", "initial_time": 90, "base_reward": 430},
]


static func generate(seed_value: int, available_abilities: PackedStringArray) -> Dictionary:
	if not Catalog.has_compatible_vertical_slice():
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var requested_zone := StringName(REQUESTED_ZONES[rng.randi_range(0, REQUESTED_ZONES.size() - 1)])
	var urgency: Dictionary = URGENCY_VARIANTS[rng.randi_range(0, URGENCY_VARIANTS.size() - 1)]
	var magic_level := rng.randi_range(4, 7)
	var movement_force := rng.randi_range(4, 6)
	var instance: Dictionary = {
		"schema_version": 1,
		"generator_version": GENERATOR_VERSION,
		"seed": seed_value,
		"instance_id": String(JOB_ID),
		"resident_id": &"eleonora",
		"apartment_id": &"old_quarter_5",
		"room_id": &"eleonora_room",
		"object_definition_id": &"wardrobe",
		"anomaly_id": &"restless_animation",
		"scene_path": "res://scenes/WardrobeRoom.tscn",
		"requested_zone": requested_zone,
		"contents_type": &"dishes",
		"urgency_id": urgency["id"],
		"urgency": urgency["label"],
		"initial_time": urgency["initial_time"],
		"base_reward": urgency["base_reward"],
		"initial_state": {
			"definition_id": &"wardrobe",
			"position_zone": &"entrance",
			"requested_zone": requested_zone,
			"contents_type": &"dishes",
			"magic_level": magic_level,
			"movement_force": movement_force,
			"noise": rng.randi_range(6, 8),
			"moving": true,
			"anchored": false,
		},
		"objective_ids": Array(Catalog.restless_animation_definition()["objective_ids"]),
		"supported_solution_families": Array(Catalog.restless_animation_definition()["solution_families"]),
	}
	var accessible_plans := find_safe_plans(instance, available_abilities)
	if accessible_plans.is_empty():
		return {}
	instance["validated_safe_plans"] = accessible_plans
	return instance


static func find_safe_plans(instance: Dictionary, abilities: PackedStringArray) -> Array[Dictionary]:
	if instance.is_empty() or StringName(str(instance.get("anomaly_id", ""))) != &"restless_animation":
		return []
	var plans: Array[Dictionary] = []
	if abilities.has("physical_move") and abilities.has("repair"):
		plans.append({"family": &"relocate_anchor", "actions": [&"physical_move", &"repair"], "safe": true})
	if abilities.has("physical_move") and abilities.has("antimagic"):
		plans.append({"family": &"relocate_antimagic", "actions": [&"physical_move", &"antimagic"], "safe": true})
	if abilities.has("telekinesis") and abilities.has("repair"):
		plans.append({"family": &"telekinesis_anchor", "actions": [&"telekinesis", &"repair"], "safe": true})
	if abilities.has("telekinesis") and abilities.has("antimagic"):
		plans.append({"family": &"telekinesis_antimagic", "actions": [&"telekinesis", &"antimagic"], "safe": true})
	return plans


static func materialize_job(instance: Dictionary) -> Dictionary:
	if instance.is_empty():
		return {}
	var requested_zone := StringName(str(instance["requested_zone"]))
	var destination := "к левой стене" if requested_zone == &"left_wall" else "к проходу на кухню"
	return {
		"title": "Шкаф снова разгуливает по квартире",
		"card_title": "Беспокойный шкаф",
		"objective": "Остановить шкаф и поставить %s" % destination,
		"address": "Старый квартал, 5",
		"resident": "Госпожа Элеонора",
		"resident_portrait": "res://assets/portraits/residents/eleonora.png",
		"resident_portrait_region": Rect2(0, 0, 1122, 1402),
		"description": "Знакомый зачарованный шкаф снова ожил, загремел посудой и преградил вход. Хозяйка просит аккуратно поставить его %s." % destination,
		"urgency": str(instance["urgency"]),
		"initial_time": int(instance["initial_time"]),
		"time_left": int(instance["initial_time"]),
		"unlocked": false,
		"overdue": false,
		"dispatched": false,
		"danger": "Бытовая магия, тяжёлая мебель",
		"base_reward": int(instance["base_reward"]),
		"repair_scene": str(instance["scene_path"]),
		"assigned": PackedStringArray(),
		"pending_action": {},
		"generated": true,
		"simulation_type": &"generated_wardrobe",
		"generated_instance": instance.duplicate(true),
	}
