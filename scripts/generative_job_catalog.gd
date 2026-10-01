class_name GenerativeJobCatalog
extends RefCounted

const OBJECT_DEFINITIONS_PATH := "res://data/objects"
const ANOMALY_DEFINITIONS_PATH := "res://data/anomalies"

static var CATALOG_LOAD_ERRORS := PackedStringArray()
static var OBJECTS: Dictionary = _load_definitions(OBJECT_DEFINITIONS_PATH)
static var ANOMALIES: Dictionary = _load_definitions(ANOMALY_DEFINITIONS_PATH)

static var RESIDENTS: Dictionary = {
	&"eleonora": {"id": &"eleonora", "name": "Госпожа Элеонора", "portrait": "res://assets/portraits/residents/eleonora.png", "home_id": &"old_quarter_5", "preferences": PackedStringArray(["tidy", "quiet", "preserve_property"])},
	&"ragnar": {"id": &"ragnar", "name": "Господин Рагнар", "portrait": "res://assets/portraits/residents/ragnar.png", "home_id": &"old_quarter_5", "preferences": PackedStringArray(["fast_response", "preserve_plumbing"])},
}

static var ROOMS: Dictionary = {
	&"eleonora_room": {
		"id": &"eleonora_room", "apartment_id": &"old_quarter_5", "scene_path": "res://scenes/WardrobeRoom.tscn",
		"zones": PackedStringArray(["entrance", "left_wall", "kitchen_passage"]),
		"supported_object_ids": PackedStringArray(["wardrobe"]),
		"supported_effects": PackedStringArray(["animated", "moving", "frozen", "burning", "scorched", "damaged", "destroyed"]),
	},
	&"ragnar_bathroom": {
		"id": &"ragnar_bathroom", "apartment_id": &"old_quarter_5", "address": "Старый квартал, 5", "scene_path": "res://scenes/RepairHouse.tscn",
		"zones": PackedStringArray(["bathroom"]),
		"supported_object_ids": PackedStringArray(["lava_faucet"]),
		"supported_effects": PackedStringArray(["lava_flowing", "frozen", "overheated", "melted", "scorched", "damaged"]),
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
	&"animated": {"kind": &"magic"}, &"moving": {"kind": &"behavior"}, &"burning": {"kind": &"hazard"},
	&"frozen": {"kind": &"elemental"}, &"scorched": {"kind": &"damage"}, &"destroyed": {"kind": &"terminal"},
	&"lava_flowing": {"kind": &"hazard"}, &"overheated": {"kind": &"hazard"}, &"melted": {"kind": &"terminal"},
	&"portal_open": {"kind": &"magic"}, &"cold_aura": {"kind": &"elemental"}, &"covered": {"kind": &"containment"},
	&"closed": {"kind": &"resolved"}, &"heat_damaged": {"kind": &"damage"}, &"dormant": {"kind": &"behavior"},
	&"awake": {"kind": &"behavior"}, &"clogged": {"kind": &"hazard"}, &"flooding": {"kind": &"hazard"},
	&"calm": {"kind": &"behavior"}, &"angry": {"kind": &"behavior"}, &"captured": {"kind": &"resolved"},
	&"expelled": {"kind": &"resolved"}, &"installed": {"kind": &"equipment"}, &"occupied": {"kind": &"equipment"},
	&"ice_removed": {"kind": &"resolved"},
}

static var OBJECTIVES: Dictionary = {
	&"stop_uncontrolled_motion": {"required_false": PackedStringArray(["moving", "burning", "held"])},
	&"clear_requested_zone": {"property_matches": PackedStringArray(["position_zone", "requested_zone"])},
	&"extinguish_fire": {"required_false": PackedStringArray(["burning"])},
	&"thaw_object": {"required_false": PackedStringArray(["frozen"])},
	&"stabilize_temperature": {"required_false": PackedStringArray(["overheated"])},
	&"stop_flow": {"required_false": PackedStringArray(["lava_flowing"])},
	&"close_portal": {"required_false": PackedStringArray(["portal_open"])},
	&"restore_drainage": {"required_false": PackedStringArray(["clogged", "flooding"])},
	&"contain_spirit": {"required_any": PackedStringArray(["captured", "expelled"])},
	&"remove_cold_trace": {"required_true": PackedStringArray(["cold_trace_removed"])},
	&"remove_ice": {"required_true": PackedStringArray(["ice_removed"])},
}

static var INTERACTION_RULES: Array[Dictionary] = [
	{"id": &"heat_ignites_wood", "action": &"heat", "required_tags": PackedStringArray(["wooden"]), "adds": PackedStringArray(["burning", "scorched"])},
	{"id": &"freeze_extinguishes_fire", "action": &"freeze", "required_effects": PackedStringArray(["burning"]), "removes": PackedStringArray(["burning"]), "adds": PackedStringArray(["frozen", "scorched"])},
	{"id": &"antimagic_stops_animation", "action": &"antimagic", "required_effects": PackedStringArray(["animated"]), "removes": PackedStringArray(["animated", "moving"])},
	{"id": &"anchor_stops_movement", "action": &"repair", "required_tags": PackedStringArray(["furniture"]), "removes": PackedStringArray(["moving"]), "adds": PackedStringArray(["anchored"])},
	{"id": &"force_breaks_brittle_wood", "action": &"physical_move", "required_tags": PackedStringArray(["wooden"]), "required_effects": PackedStringArray(["frozen"]), "adds": PackedStringArray(["damaged"])},
]

const REQUIRED_OBJECT_FIELDS: PackedStringArray = ["id", "display_name", "tags", "base_properties", "supported_effects", "visual_profile_id", "visual_profile"]
const REQUIRED_BASE_PROPERTIES: PackedStringArray = ["mass", "durability", "temperature", "magic_level", "damage", "anchored", "movable", "replacement_value"]
const REQUIRED_ANOMALY_FIELDS: PackedStringArray = ["id", "display_name", "generator_enabled", "tutorial_eligible", "compatible_object_ids", "required_tags", "forbidden_tags", "initial_effects", "objective_ids", "initial_state", "resolution", "solution_plans", "visual_effects", "presentation", "weight"]


static func compatible_anomalies(room_id: StringName, object_id: StringName, generator_only: bool = true) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not ROOMS.has(room_id) or not OBJECTS.has(object_id):
		return result
	var room: Dictionary = ROOMS[room_id]
	if not (room["supported_object_ids"] as PackedStringArray).has(String(object_id)):
		return result
	var object_definition: Dictionary = OBJECTS[object_id]
	var tags: PackedStringArray = object_definition["tags"]
	var supported_effects: PackedStringArray = object_definition["supported_effects"]
	for anomaly_id: StringName in ANOMALIES:
		var anomaly: Dictionary = ANOMALIES[anomaly_id]
		var compatible_object_ids: PackedStringArray = anomaly.get("compatible_object_ids", PackedStringArray())
		if not compatible_object_ids.is_empty() and not compatible_object_ids.has(String(object_id)):
			continue
		if generator_only and not bool(anomaly.get("generator_enabled", false)):
			continue
		if not _contains_all(tags, anomaly["required_tags"] as PackedStringArray):
			continue
		if _contains_any(tags, anomaly["forbidden_tags"] as PackedStringArray):
			continue
		if not _contains_all(supported_effects, anomaly["visual_effects"] as PackedStringArray):
			continue
		result.append(anomaly)
	return result


static func validate_catalog() -> PackedStringArray:
	var errors := CATALOG_LOAD_ERRORS.duplicate()
	if OBJECTS.is_empty():
		errors.append("Каталог объектов пуст: %s" % OBJECT_DEFINITIONS_PATH)
	if ANOMALIES.is_empty():
		errors.append("Каталог аномалий пуст: %s" % ANOMALY_DEFINITIONS_PATH)
	for object_id: StringName in OBJECTS:
		var object_definition: Dictionary = OBJECTS[object_id]
		for field: String in REQUIRED_OBJECT_FIELDS:
			if not object_definition.has(field):
				errors.append("Объект %s: отсутствует поле %s" % [object_id, field])
		var properties: Dictionary = object_definition.get("base_properties", {}) as Dictionary
		for property_name: String in REQUIRED_BASE_PROPERTIES:
			if not properties.has(property_name):
				errors.append("Объект %s: не задано свойство %s" % [object_id, property_name])
		_validate_visual_profile(object_id, object_definition.get("visual_profile", {}) as Dictionary, errors)
	for anomaly_id: StringName in ANOMALIES:
		var anomaly: Dictionary = ANOMALIES[anomaly_id]
		for field: String in REQUIRED_ANOMALY_FIELDS:
			if not anomaly.has(field):
				errors.append("Аномалия %s: отсутствует поле %s" % [anomaly_id, field])
		for objective_id: String in anomaly.get("objective_ids", PackedStringArray()):
			if not OBJECTIVES.has(StringName(objective_id)):
				errors.append("Аномалия %s: неизвестная цель %s" % [anomaly_id, objective_id])
		for effect_id: String in anomaly.get("initial_effects", PackedStringArray()):
			if not EFFECTS.has(StringName(effect_id)):
				errors.append("Аномалия %s: неизвестный начальный эффект %s" % [anomaly_id, effect_id])
		if not _has_compatible_object_definition(anomaly):
			errors.append("Аномалия %s: нет совместимого объекта с визуальной поддержкой" % anomaly_id)
		if bool(anomaly.get("generator_enabled", false)):
			_validate_enabled_anomaly(anomaly_id, anomaly, errors)
	return errors


static func has_compatible_vertical_slice() -> bool:
	return validate_catalog().is_empty() and not compatible_anomalies(&"eleonora_room", &"wardrobe").is_empty()


static func _load_definitions(directory_path: String) -> Dictionary:
	var result: Dictionary = {}
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(directory_path)):
		CATALOG_LOAD_ERRORS.append("Папка определений не найдена: %s" % directory_path)
		return result
	var file_names := DirAccess.get_files_at(directory_path)
	file_names.sort()
	for file_name: String in file_names:
		if file_name.get_extension().to_lower() != "tres":
			continue
		var resource_path := "%s/%s" % [directory_path, file_name]
		var definition := ResourceLoader.load(resource_path)
		if definition == null or not definition.has_method(&"to_dictionary"):
			CATALOG_LOAD_ERRORS.append("Не удалось загрузить определение: %s" % resource_path)
			continue
		var data: Dictionary = definition.call(&"to_dictionary")
		var definition_id := StringName(str(data.get("id", "")))
		if definition_id.is_empty():
			CATALOG_LOAD_ERRORS.append("В определении не задан id: %s" % resource_path)
			continue
		if result.has(definition_id):
			CATALOG_LOAD_ERRORS.append("Повторяющийся id %s: %s" % [definition_id, resource_path])
			continue
		data["resource_path"] = resource_path
		result[definition_id] = data
	return result


static func _validate_visual_profile(object_id: StringName, profile: Dictionary, errors: PackedStringArray) -> void:
	var scene_path := str(profile.get("scene_path", ""))
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		errors.append("Объект %s: сцена не найдена: %s" % [object_id, scene_path])
	for group_name: String in ["states", "overlays"]:
		var assets: Dictionary = profile.get(group_name, {}) as Dictionary
		for state_id: Variant in assets:
			var asset_path := str(assets[state_id])
			if not ResourceLoader.exists(asset_path):
				errors.append("Объект %s: ассет состояния %s не найден: %s" % [object_id, state_id, asset_path])


static func _validate_enabled_anomaly(anomaly_id: StringName, anomaly: Dictionary, errors: PackedStringArray) -> void:
	var presentation: Dictionary = anomaly.get("presentation", {}) as Dictionary
	for field: String in ["title", "card_title", "objective", "description", "danger", "resident_request"]:
		if str(presentation.get(field, "")).is_empty():
			errors.append("Аномалия %s: для генератора не задан текст %s" % [anomaly_id, field])
	if (anomaly.get("solution_plans", []) as Array).is_empty():
		errors.append("Аномалия %s: для генератора не задан безопасный план" % anomaly_id)


static func _has_compatible_object_definition(anomaly: Dictionary) -> bool:
	for object_id: StringName in OBJECTS:
		var object_definition: Dictionary = OBJECTS[object_id]
		var tags: PackedStringArray = object_definition["tags"]
		if not _contains_all(tags, anomaly["required_tags"] as PackedStringArray):
			continue
		if _contains_any(tags, anomaly["forbidden_tags"] as PackedStringArray):
			continue
		if _contains_all(object_definition["supported_effects"] as PackedStringArray, anomaly["visual_effects"] as PackedStringArray):
			return true
	return false


static func _contains_all(values: PackedStringArray, required: PackedStringArray) -> bool:
	for value: String in required:
		if not values.has(value):
			return false
	return true


static func _contains_any(values: PackedStringArray, candidates: PackedStringArray) -> bool:
	for value: String in candidates:
		if values.has(value):
			return true
	return false
