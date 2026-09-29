class_name GenerativeJobCatalog
extends RefCounted

static var RESIDENTS: Dictionary = {
	&"eleonora": {
		"id": &"eleonora",
		"name": "Госпожа Элеонора",
		"portrait": "res://assets/portraits/residents/eleonora.png",
		"home_id": &"old_quarter_5",
		"preferences": PackedStringArray(["tidy", "quiet", "preserve_property"]),
	},
}

static var ROOMS: Dictionary = {
	&"eleonora_room": {
		"id": &"eleonora_room",
		"apartment_id": &"old_quarter_5",
		"scene_path": "res://scenes/WardrobeRoom.tscn",
		"zones": PackedStringArray(["entrance", "left_wall", "kitchen_passage"]),
		"supported_object_ids": PackedStringArray(["wardrobe"]),
		"supported_effects": PackedStringArray(["animated", "moving", "frozen", "burning", "scorched", "damaged", "destroyed"]),
	},
}

static var OBJECTS: Dictionary = {
	&"wardrobe": {
		"id": &"wardrobe",
		"display_name": "Шкаф",
		"tags": PackedStringArray(["furniture", "wooden", "heavy", "container", "movable", "animatable", "large"]),
		"base_properties": {
			"mass": 8,
			"durability": 7,
			"temperature": 2,
			"magic_level": 0,
			"movement_force": 0,
			"mobility": 5,
			"noise": 0,
			"anchored": false,
			"movable": true,
			"replacement_value": 520,
			"contents_value": 180,
		},
		"supported_effects": PackedStringArray(["animated", "moving", "frozen", "burning", "scorched", "damaged", "destroyed"]),
	},
}

static var ANOMALIES: Dictionary = {
	&"restless_animation": {
		"id": &"restless_animation",
		"required_tags": PackedStringArray(["movable", "animatable"]),
		"forbidden_tags": PackedStringArray(["destroyed"]),
		"initial_effects": PackedStringArray(["animated", "moving"]),
		"objective_ids": PackedStringArray(["stop_uncontrolled_motion", "clear_requested_zone"]),
		"solution_families": PackedStringArray(["relocate_anchor", "relocate_antimagic", "telekinesis_anchor", "telekinesis_antimagic"]),
		"weight": 10,
	},
}

static var ACTIONS: Dictionary = {
	&"physical_move": {"effects": PackedStringArray(["relocate", "damage_supports"])},
	&"repair": {"effects": PackedStringArray(["anchor", "restore"])},
	&"telekinesis": {"effects": PackedStringArray(["relocate"])},
	&"antimagic": {"effects": PackedStringArray(["suppress_magic"])},
	&"freeze": {"effects": PackedStringArray(["cool", "extinguish", "brittle"])},
	&"heat": {"effects": PackedStringArray(["heat", "ignite_wood"])},
}

static var EFFECTS: Dictionary = {
	&"animated": {"kind": &"magic"},
	&"moving": {"kind": &"behavior"},
	&"burning": {"kind": &"hazard"},
	&"frozen": {"kind": &"elemental"},
	&"scorched": {"kind": &"damage"},
	&"destroyed": {"kind": &"terminal"},
}

static var OBJECTIVES: Dictionary = {
	&"stop_uncontrolled_motion": {"required_false": PackedStringArray(["moving", "burning", "held"])},
	&"clear_requested_zone": {"property_matches": PackedStringArray(["position_zone", "requested_zone"])},
}

static var INTERACTION_RULES: Array[Dictionary] = [
	{"id": &"heat_ignites_wood", "action": &"heat", "required_tags": PackedStringArray(["wooden"]), "adds": PackedStringArray(["burning", "scorched"])},
	{"id": &"freeze_extinguishes_fire", "action": &"freeze", "required_effects": PackedStringArray(["burning"]), "removes": PackedStringArray(["burning"]), "adds": PackedStringArray(["frozen", "scorched"])},
	{"id": &"antimagic_stops_animation", "action": &"antimagic", "required_effects": PackedStringArray(["animated"]), "removes": PackedStringArray(["animated", "moving"])},
	{"id": &"anchor_stops_movement", "action": &"repair", "required_tags": PackedStringArray(["furniture"]), "removes": PackedStringArray(["moving"]), "adds": PackedStringArray(["anchored"])},
	{"id": &"force_breaks_brittle_wood", "action": &"physical_move", "required_tags": PackedStringArray(["wooden"]), "required_effects": PackedStringArray(["frozen"]), "adds": PackedStringArray(["damaged"])},
]


static func has_compatible_vertical_slice() -> bool:
	var room: Dictionary = ROOMS[&"eleonora_room"]
	var object_definition: Dictionary = OBJECTS[&"wardrobe"]
	var anomaly: Dictionary = ANOMALIES[&"restless_animation"]
	if not (room["supported_object_ids"] as PackedStringArray).has("wardrobe"):
		return false
	var tags: PackedStringArray = object_definition["tags"]
	for required_tag: String in anomaly["required_tags"]:
		if not tags.has(required_tag):
			return false
	return true


static func restless_animation_definition() -> Dictionary:
	return ANOMALIES[&"restless_animation"]
