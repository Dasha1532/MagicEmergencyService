class_name GeneratedJobGenerator
extends RefCounted

const Catalog := preload("res://scripts/generative_job_catalog.gd")

const GENERATOR_VERSION: int = 3
const JOB_ID: StringName = &"generated_wardrobe_1"
const TUTORIAL_FAUCET_JOB_ID: StringName = &"generated_faucet_tutorial_1"
const REQUESTED_ZONES: PackedStringArray = ["left_wall"]
const PERSISTENT_RESIDUAL_KEYS: PackedStringArray = ["damage", "scorched", "destroyed", "contents_damage", "replaced", "thermal_regulator_installed", "regulator_installed"]
const URGENCY_VARIANTS: Array[Dictionary] = [
	{"id": &"normal", "label": "Обычная", "initial_time": 110, "base_reward": 390},
	{"id": &"important", "label": "Важно", "initial_time": 90, "base_reward": 430},
]


static func generate(seed_value: int, available_abilities: PackedStringArray, excluded_anomaly_ids: PackedStringArray = PackedStringArray(), world_context: Dictionary = {}) -> Dictionary:
	if not Catalog.has_compatible_vertical_slice():
		return {}
	if _world_object_is_terminal("old_quarter_5.hall.wardrobe", world_context):
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var compatible: Array[Dictionary] = Catalog.compatible_anomalies(&"eleonora_room", &"wardrobe")
	compatible = compatible.filter(func(candidate: Dictionary) -> bool: return not find_safe_plans({"anomaly_id": candidate["id"], "resident_id": "eleonora"}, available_abilities, world_context).is_empty())
	if compatible.size() > 1 and not excluded_anomaly_ids.is_empty():
		var fresh: Array[Dictionary] = compatible.filter(func(anomaly: Dictionary) -> bool: return not excluded_anomaly_ids.has(str(anomaly.get("id", ""))))
		if not fresh.is_empty():
			compatible = fresh
	if compatible.is_empty():
		return {}
	var anomaly: Dictionary = compatible[rng.randi_range(0, compatible.size() - 1)]
	var anomaly_id := StringName(str(anomaly["id"]))
	var requested_zone := StringName(REQUESTED_ZONES[rng.randi_range(0, REQUESTED_ZONES.size() - 1)])
	var urgency: Dictionary = URGENCY_VARIANTS[rng.randi_range(0, URGENCY_VARIANTS.size() - 1)]
	var initial_state: Dictionary = {
		"definition_id": &"wardrobe",
		"generated_anomaly_id": anomaly_id,
		"requested_zone": requested_zone,
		"contents_type": &"dishes",
		"generated_resolution": (anomaly["resolution"] as Dictionary).duplicate(true),
		"generated_completion": (anomaly.get("completion", {}) as Dictionary).duplicate(true),
	}
	for property_name: Variant in (anomaly["initial_state"] as Dictionary):
		var value: Variant = (anomaly["initial_state"] as Dictionary)[property_name]
		if value is Array and (value as Array).size() == 2:
			value = rng.randi_range(int((value as Array)[0]), int((value as Array)[1]))
		elif str(value) == "$requested_zone":
			value = requested_zone
		elif str(value) == "$entrance":
			value = &"entrance"
		initial_state[property_name] = value
	var destination := "к левой стене"
	var presentation: Dictionary = (anomaly["presentation"] as Dictionary).duplicate(true)
	for field: String in presentation:
		presentation[field] = _render(str(presentation[field]), destination)
	initial_state["generated_resident_request"] = str(presentation.get("resident_request", ""))
	var instance: Dictionary = {
		"schema_version": 1,
		"generator_version": GENERATOR_VERSION,
		"seed": seed_value,
		"instance_id": String(JOB_ID),
		"resident_id": &"eleonora",
		"apartment_id": &"old_quarter_5",
		"room_id": &"eleonora_room",
		"object_definition_id": &"wardrobe",
		"anomaly_id": anomaly_id,
		"tutorial_eligible": bool(anomaly.get("tutorial_eligible", false)),
		"scene_path": "res://scenes/WardrobeRoom.tscn",
		"requested_zone": requested_zone,
		"contents_type": &"dishes",
		"urgency_id": urgency["id"],
		"urgency": urgency["label"],
		"initial_time": urgency["initial_time"],
		"base_reward": urgency["base_reward"],
		"initial_state": initial_state,
		"objective_ids": Array(anomaly["objective_ids"]),
		"presentation": presentation,
	}
	_attach_world_context(instance, "old_quarter_5.hall.wardrobe", world_context)
	var accessible_plans := find_safe_plans(instance, available_abilities, world_context)
	if accessible_plans.is_empty():
		return {}
	instance["validated_safe_plans"] = accessible_plans
	return instance


static func generate_tutorial_faucet(seed_value: int, available_abilities: PackedStringArray, excluded_anomaly_ids: PackedStringArray = PackedStringArray(), world_context: Dictionary = {}) -> Dictionary:
	if _world_object_is_terminal("old_quarter_5.bathroom.lava_faucet", world_context):
		return {}
	var compatible: Array[Dictionary] = Catalog.compatible_anomalies(&"ragnar_bathroom", &"lava_faucet")
	compatible = compatible.filter(func(anomaly: Dictionary) -> bool: return bool(anomaly.get("tutorial_eligible", false)))
	var resolvable: Array[Dictionary] = []
	for anomaly: Dictionary in compatible:
		var probe := {"anomaly_id": anomaly["id"], "resident_id": "ragnar"}
		if not find_safe_plans(probe, available_abilities, world_context).is_empty():
			resolvable.append(anomaly)
	if resolvable.size() > 1 and not excluded_anomaly_ids.is_empty():
		var fresh: Array[Dictionary] = resolvable.filter(func(anomaly: Dictionary) -> bool: return not excluded_anomaly_ids.has(str(anomaly.get("id", ""))))
		if not fresh.is_empty():
			resolvable = fresh
	if resolvable.is_empty():
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var anomaly: Dictionary = resolvable[rng.randi_range(0, resolvable.size() - 1)]
	var anomaly_id := StringName(str(anomaly["id"]))
	var initial_state: Dictionary = (anomaly["initial_state"] as Dictionary).duplicate(true)
	initial_state["definition_id"] = &"lava_faucet"
	initial_state["generated_anomaly_id"] = anomaly_id
	initial_state["generated_resolution"] = (anomaly["resolution"] as Dictionary).duplicate(true)
	initial_state["generated_completion"] = (anomaly.get("completion", {}) as Dictionary).duplicate(true)
	var presentation: Dictionary = (anomaly["presentation"] as Dictionary).duplicate(true)
	initial_state["generated_resident_request"] = str(presentation.get("resident_request", ""))
	var instance: Dictionary = {
		"schema_version": 1,
		"generator_version": GENERATOR_VERSION,
		"seed": seed_value,
		"instance_id": String(TUTORIAL_FAUCET_JOB_ID),
		"resident_id": &"ragnar",
		"apartment_id": &"old_quarter_5",
		"room_id": &"ragnar_bathroom",
		"object_definition_id": &"lava_faucet",
		"anomaly_id": anomaly_id,
		"tutorial_eligible": true,
		"scene_path": str(anomaly.get("scene_path", "res://scenes/RepairHouse.tscn")),
		"urgency_id": &"urgent",
		"urgency": "Срочно",
		"initial_time": 95,
		"base_reward": 500,
		"initial_state": initial_state,
		"objective_ids": Array(anomaly["objective_ids"]),
		"presentation": presentation,
		"simulation_type": StringName(str(anomaly.get("simulation_type", "lava_faucet"))),
	}
	_attach_world_context(instance, "old_quarter_5.bathroom.lava_faucet", world_context)
	instance["validated_safe_plans"] = find_safe_plans(instance, available_abilities, world_context)
	if (instance["validated_safe_plans"] as Array).is_empty():
		return {}
	return instance


static func generate_faucet_consequence(event: Dictionary, available_abilities: PackedStringArray, world_context: Dictionary) -> Dictionary:
	var anomaly_id := StringName(str((event.get("payload", {}) as Dictionary).get("anomaly_id", event.get("event_type", ""))))
	if not Catalog.ANOMALIES.has(anomaly_id):
		return {}
	if _world_object_is_terminal("old_quarter_5.bathroom.lava_faucet", world_context):
		return {}
	var anomaly: Dictionary = Catalog.ANOMALIES[anomaly_id]
	var initial_state: Dictionary = (anomaly.get("initial_state", {}) as Dictionary).duplicate(true)
	initial_state["definition_id"] = &"lava_faucet"
	initial_state["generated_anomaly_id"] = anomaly_id
	initial_state["generated_resolution"] = (anomaly.get("resolution", {}) as Dictionary).duplicate(true)
	initial_state["generated_completion"] = (anomaly.get("completion", {}) as Dictionary).duplicate(true)
	var presentation: Dictionary = (anomaly.get("presentation", {}) as Dictionary).duplicate(true)
	var relationship_tone := str((event.get("payload", {}) as Dictionary).get("relationship_tone", "neutral"))
	var relationship_text := _faucet_relationship_text(anomaly_id, relationship_tone)
	if not relationship_text.is_empty():
		presentation["resident_request"] = relationship_text
	initial_state["generated_resident_request"] = str(presentation.get("resident_request", ""))
	var event_id := str(event.get("event_id", "deferred.unknown"))
	var instance_id := "generated_faucet_consequence_%s" % event_id.replace(".", "_")
	var instance: Dictionary = {
		"schema_version": 1,
		"generator_version": GENERATOR_VERSION,
		"seed": hash(event_id),
		"instance_id": instance_id,
		"resident_id": &"ragnar",
		"apartment_id": &"old_quarter_5",
		"room_id": &"ragnar_bathroom",
		"object_definition_id": &"lava_faucet",
		"object_instance_id": "old_quarter_5.bathroom.lava_faucet",
		"anomaly_id": anomaly_id,
		"scene_path": str(anomaly.get("scene_path", "res://scenes/RepairHouse.tscn")),
		"urgency_id": &"important",
		"urgency": "Важно",
		"initial_time": 90,
		"base_reward": 420,
		"initial_state": initial_state,
		"objective_ids": Array(anomaly.get("objective_ids", [])),
		"presentation": presentation,
		"simulation_type": StringName(str(anomaly.get("simulation_type", "lava_faucet"))),
		"source_deferred_event_id": event_id,
		"source_job_id": str(event.get("source_job_id", "")),
		"cause_chain_id": str(event.get("cause_chain_id", "")),
	}
	_attach_world_context(instance, "old_quarter_5.bathroom.lava_faucet", world_context)
	var plans := find_safe_plans(instance, available_abilities, world_context)
	if plans.is_empty():
		return {}
	instance["validated_safe_plans"] = plans
	return instance


static func _faucet_relationship_text(anomaly_id: StringName, relationship_tone: String) -> String:
	var appreciative := relationship_tone == "appreciative"
	match anomaly_id:
		&"cold_trace":
			return "Спасибо за прошлую работу. Теперь из крана сыплется лёд, и ванна уже заполнена." if appreciative else "После прошлого обращения появилась новая проблема: из крана сыплется лёд, и ванна уже заполнена."
		&"faucet_freeze":
			return "Спасибо, что вчера быстро привели кран в порядок. Сегодня утром он начал покрываться льдом." if appreciative else "После прошлого обращения появилась новая проблема: сегодня утром кран начал покрываться льдом."
		&"faucet_overheat":
			return "Спасибо, что вчера быстро привели кран в порядок. Сегодня утром он начал самопроизвольно нагреваться." if appreciative else "После прошлого обращения появилась новая проблема: сегодня утром кран начал самопроизвольно нагреваться."
	return ""


static func _attach_world_context(instance: Dictionary, object_instance_id: String, world_context: Dictionary) -> void:
	var objects: Dictionary = world_context.get("objects", {}) as Dictionary
	var object_state: Dictionary = objects.get(object_instance_id, {}) as Dictionary
	var persistent_state: Dictionary = (object_state.get("properties", {}) as Dictionary).duplicate(true)
	var anomaly_state: Dictionary = (instance.get("initial_state", {}) as Dictionary).duplicate(true)
	# Постоянное состояние служит базой, а новая причинная аномалия меняет только
	# явно перечисленные ею свойства. Так старый ущерб не исчезает при публикации.
	persistent_state.merge(anomaly_state, true)
	var prior_properties: Dictionary = object_state.get("properties", {}) as Dictionary
	for property_name: String in PERSISTENT_RESIDUAL_KEYS:
		if prior_properties.has(property_name):
			persistent_state[property_name] = prior_properties[property_name]
	instance["initial_state"] = persistent_state
	instance["object_instance_id"] = object_instance_id
	instance["world_snapshot_revision"] = int(object_state.get("revision", 0))
	instance["persistent_state"] = (object_state.get("properties", {}) as Dictionary).duplicate(true)
	instance["pending_consequence_index"] = (world_context.get("consequences", []) as Array).duplicate(true)
	instance["related_initial_states"] = {}
	for related_id: String in objects:
		if related_id != object_instance_id and related_id.substr(0, related_id.rfind(".")) == object_instance_id.substr(0, object_instance_id.rfind(".")):
			instance["related_initial_states"][related_id] = (objects[related_id].get("properties", {}) as Dictionary).duplicate(true)


static func _world_object_is_terminal(object_instance_id: String, world_context: Dictionary) -> bool:
	var objects: Dictionary = world_context.get("objects", {}) as Dictionary
	var object_state: Dictionary = objects.get(object_instance_id, {}) as Dictionary
	var properties: Dictionary = object_state.get("properties", {}) as Dictionary
	return bool(properties.get("destroyed", false))


static func find_safe_plans(instance: Dictionary, abilities: PackedStringArray, world_context: Dictionary = {}) -> Array[Dictionary]:
	if instance.is_empty():
		return []
	var client_capabilities: Dictionary = world_context.get("client_capabilities", {}) as Dictionary
	var resident_id := str(instance.get("resident_id", ""))
	if client_capabilities.has(resident_id):
		abilities = PackedStringArray(client_capabilities[resident_id])
	var plans: Array[Dictionary] = []
	var anomaly_id := StringName(str(instance.get("anomaly_id", "")))
	if not Catalog.ANOMALIES.has(anomaly_id):
		return plans
	for plan_value: Variant in (Catalog.ANOMALIES[anomaly_id] as Dictionary)["solution_plans"]:
		var plan: Dictionary = plan_value as Dictionary
		var required: PackedStringArray = plan["abilities"]
		var accessible := true
		for ability: String in required:
			if not abilities.has(ability):
				accessible = false
				break
		if accessible:
			plans.append({"family": plan["family"], "actions": Array(required), "safe": true})
	return plans


static func materialize_job(instance: Dictionary) -> Dictionary:
	if instance.is_empty():
		return {}
	var presentation: Dictionary = instance.get("presentation", {}) as Dictionary
	if presentation.is_empty():
		return {}
	var resident_id := StringName(str(instance.get("resident_id", "eleonora")))
	var resident: Dictionary = Catalog.RESIDENTS.get(resident_id, Catalog.RESIDENTS[&"eleonora"])
	var room: Dictionary = Catalog.ROOMS.get(StringName(str(instance.get("room_id", "eleonora_room"))), {})
	return {
		"title": str(presentation["title"]),
		"card_title": str(presentation["card_title"]),
		"objective": str(presentation["objective"]),
		"address": str(room.get("address", "Старый квартал, 5")),
		"resident": str(resident.get("name", "")),
		"resident_portrait": str(resident.get("portrait", "")),
		"resident_portrait_region": Rect2(0, 0, 1122, 1402),
		"description": str(presentation["description"]),
		"urgency": str(instance["urgency"]),
		"initial_time": int(instance["initial_time"]),
		"time_left": int(instance["initial_time"]),
		"unlocked": false,
		"overdue": false,
		"dispatched": false,
		"danger": str(presentation["danger"]),
		"base_reward": int(instance["base_reward"]),
		"repair_scene": str(instance["scene_path"]),
		"assigned": PackedStringArray(),
		"pending_action": {},
		"generated": true,
		"consequence": not str(instance.get("source_deferred_event_id", "")).is_empty(),
		"source_deferred_event_id": str(instance.get("source_deferred_event_id", "")),
		"source_job_id": str(instance.get("source_job_id", "")),
		"restoration": bool(instance.get("restoration", false)),
		"object_definition_id": StringName(str(instance.get("object_definition_id", ""))),
		"resident_request": str(presentation.get("resident_request", "")),
		"unresolved_message": str(presentation.get("unresolved_message", "")),
		"tutorial_eligible": bool(instance.get("tutorial_eligible", false)),
		"tutorial_required_ability_sets": (instance.get("validated_safe_plans", []) as Array).map(func(plan: Dictionary) -> PackedStringArray: return PackedStringArray(plan.get("actions", []))),
		"simulation_type": StringName(str(instance.get("simulation_type", "generated_wardrobe"))),
		"generated_instance": instance.duplicate(true),
	}


static func _render(template: String, destination: String) -> String:
	return template.replace("{destination}", destination)
