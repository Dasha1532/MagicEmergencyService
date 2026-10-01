class_name WorldMemory
extends RefCounted

const SCHEMA_VERSION: int = 2
const MAX_RECENT_EVENTS: int = 256
const MAX_SIGNIFICANT_EVENTS: int = 128
const MAX_CAUSE_DEPTH: int = 4
const SYSTEMIC_ANOMALIES: Array[Dictionary] = [
	{
		"id": "thermal_instability",
		"definition_id": "lava_faucet",
		"required_final_properties": {"broken": false, "thermal_regulator_installed": false, "function_test_passed": true},
		"score_property": "thermal_instability",
		"minimum_score": 40.0,
		"required_systemic_properties": {"last_thermal_direction": "heat"},
		"event_type": "faucet_overheat",
		"delay_days": 1,
		"due_minutes": 540,
		"priority": 80,
	},
	{
		"id": "thermal_instability",
		"definition_id": "lava_faucet",
		"required_final_properties": {"broken": false, "thermal_regulator_installed": false, "function_test_passed": true},
		"score_property": "thermal_instability",
		"minimum_score": 40.0,
		"required_systemic_properties": {"last_thermal_direction": "cold"},
		"event_type": "faucet_freeze",
		"delay_days": 1,
		"due_minutes": 540,
		"priority": 80,
	},
]

const OBJECT_DEFINITIONS: Dictionary = {
	"old_quarter_5.bathroom.lava_faucet": {
		"definition_id": "lava_faucet",
		"property_keys": [
			"incarnation", "temperature", "pressure", "damage", "durability", "anchored", "movable",
			"frozen", "scorched", "broken", "replaced", "valve_position", "valve_operable",
			"valve_broken", "valve_frozen", "flow_content", "flow_blocked",
			"cold_source_active", "cold_leak", "heat_source_active", "lava_source_active",
			"magic_level", "thermal_regulator_installed", "regulator_installed",
			"function_test_passed", "frozen_lava_flow", "visual_state", "tags",
		],
		"significant_keys": [
			"frozen", "scorched", "broken", "replaced", "valve_broken", "flow_blocked",
			"cold_source_active", "heat_source_active", "lava_source_active", "magic_level",
			"thermal_regulator_installed", "regulator_installed", "function_test_passed",
			"frozen_lava_flow", "visual_state", "damage",
		],
	},
	"old_quarter_5.hall.wardrobe": {
		"definition_id": "walking_wardrobe",
		"property_keys": [
			"mass", "durability", "temperature", "magic_level", "movement_force", "mobility",
			"noise", "anchored", "movable", "position_zone", "requested_zone", "moving",
			"held", "frozen", "brittle", "burning", "scorched", "destroyed", "fire_spots",
			"burn_stage", "damage", "contents_type", "contents_damage", "visual_state",
		],
		"significant_keys": [
			"magic_level", "mobility", "anchored", "position_zone", "moving", "frozen",
			"brittle", "burning", "scorched", "destroyed", "damage", "contents_damage",
			"visual_state",
		],
	},
}

var objects: Dictionary = {}
var recent_events: Array[Dictionary] = []
var significant_events: Array[Dictionary] = []
var deferred_events: Array[Dictionary] = []
var job_contexts: Dictionary = {}
var _job_event_counts: Dictionary = {}
var _next_event_serial: int = 1


func reset() -> void:
	objects.clear()
	recent_events.clear()
	significant_events.clear()
	deferred_events.clear()
	job_contexts.clear()
	_job_event_counts.clear()
	_next_event_serial = 1
	_ensure_default_objects()


func load_data(data: Dictionary) -> void:
	reset()
	_next_event_serial = maxi(1, int(data.get("next_event_serial", 1)))
	var loaded_objects: Variant = data.get("objects", {})
	if loaded_objects is Dictionary:
		for instance_id: Variant in loaded_objects:
			var value: Variant = loaded_objects[instance_id]
			if value is Dictionary and OBJECT_DEFINITIONS.has(str(instance_id)):
				objects[str(instance_id)] = (value as Dictionary).duplicate(true)
	_load_dictionary_array(data.get("recent_events", []), recent_events, MAX_RECENT_EVENTS)
	_load_dictionary_array(data.get("significant_events", []), significant_events, MAX_SIGNIFICANT_EVENTS)
	_load_dictionary_array(data.get("deferred_events", []), deferred_events, MAX_SIGNIFICANT_EVENTS)
	var loaded_contexts: Variant = data.get("job_contexts", {})
	if loaded_contexts is Dictionary:
		job_contexts = (loaded_contexts as Dictionary).duplicate(true)
	_ensure_default_objects()
	_rebuild_job_event_counts()


func to_data() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"objects": objects.duplicate(true),
		"recent_events": recent_events.duplicate(true),
		"significant_events": significant_events.duplicate(true),
		"deferred_events": deferred_events.duplicate(true),
		"job_contexts": job_contexts.duplicate(true),
		"next_event_serial": _next_event_serial,
	}


func instance_id_for_job(job_id: StringName, definition_id: StringName = &"") -> String:
	if definition_id == &"lava_faucet" or job_id == &"lava_leak" or String(job_id).begins_with("generated_faucet"):
		return "old_quarter_5.bathroom.lava_faucet"
	if definition_id in [&"walking_wardrobe", &"wardrobe"] or job_id in [&"walking_wardrobe", &"generated_wardrobe_1"]:
		return "old_quarter_5.hall.wardrobe"
	return ""


func ensure_job_context(job_id: StringName, initial_properties: Dictionary, target_instance_id: String = "", metadata: Dictionary = {}) -> void:
	if job_contexts.has(String(job_id)):
		return
	job_contexts[String(job_id)] = {
		"target_instance_id": target_instance_id,
		"initial_properties": initial_properties.duplicate(true),
		"processed_action_count": 0,
		"is_consequence": not str(metadata.get("source_deferred_event_id", "")).is_empty(),
	}


func record_job_state(job_id: StringName, state: Dictionary, day: int, time_minutes: int) -> void:
	var world_object: Variant = state.get("world_object", {})
	if not world_object is Dictionary:
		return
	var definition_id := StringName(str((world_object as Dictionary).get("definition_id", "")))
	var instance_id := instance_id_for_job(job_id, definition_id)
	if instance_id.is_empty():
		return
	if not job_contexts.has(String(job_id)):
		ensure_job_context(job_id, world_object as Dictionary, instance_id)
	_ensure_object(instance_id)
	var job_context: Dictionary = job_contexts.get(String(job_id), {}) as Dictionary
	var known_count := int(job_context.get("processed_action_count", _job_event_counts.get(String(job_id), 0)))
	var actions: Variant = state.get("action_log", [])
	if actions is Array:
		for action_index: int in range(known_count, (actions as Array).size()):
			var action: Variant = (actions as Array)[action_index]
			if action is Dictionary:
				_record_action(instance_id, job_id, action as Dictionary, world_object as Dictionary, day, time_minutes)
		_job_event_counts[String(job_id)] = (actions as Array).size()
		job_context["processed_action_count"] = (actions as Array).size()
		job_contexts[String(job_id)] = job_context
	_update_object_snapshot(instance_id, world_object as Dictionary)


func finalize_job(job_id: StringName, result: Dictionary, day: int, time_minutes: int) -> void:
	var follow_up: Variant = result.get("follow_up", {})
	if follow_up is Dictionary and not (follow_up as Dictionary).is_empty():
		var target_id := StringName(str((follow_up as Dictionary).get("type", "")))
		var source_instance_id := instance_id_for_job(job_id)
		queue_consequence(
			&"legacy_follow_up", target_id, source_instance_id, job_id,
			day + 1, time_minutes, 50, follow_up as Dictionary,
			"chain.%s" % String(job_id), "", 1
		)
	_evaluate_systemic_consequences(job_id, result, day, time_minutes)
	_job_event_counts.erase(String(job_id))
	job_contexts.erase(String(job_id))


func due_consequences(day: int, time_minutes: int) -> Array[Dictionary]:
	var due: Array[Dictionary] = []
	for event: Dictionary in deferred_events:
		if str(event.get("status", "")) != "pending":
			continue
		if int(event.get("due_day", 0)) > day:
			continue
		if int(event.get("due_day", 0)) == day and int(event.get("due_minutes", 0)) > time_minutes:
			continue
		var source_object_id := str(event.get("source_object_id", ""))
		var payload: Dictionary = event.get("payload", {}) as Dictionary
		if objects.has(source_object_id):
			var properties: Dictionary = (objects[source_object_id] as Dictionary).get("properties", {}) as Dictionary
			if int(payload.get("source_incarnation", int(properties.get("incarnation", 1)))) != int(properties.get("incarnation", 1)):
				set_event_status(str(event.get("event_id", "")), "cancelled", {"cancel_reason": "object_replaced"})
				continue
		due.append(event.duplicate(true))
	due.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("priority", 0)) > int(b.get("priority", 0)))
	return due


func set_event_status(event_id: String, status: String, payload_patch: Dictionary = {}) -> void:
	if status not in ["pending", "claimed", "cancelled", "resolved"]:
		return
	for index: int in deferred_events.size():
		var event: Dictionary = deferred_events[index]
		if str(event.get("event_id", "")) != event_id:
			continue
		event["status"] = status
		var payload: Dictionary = event.get("payload", {}) as Dictionary
		payload.merge(payload_patch, true)
		event["payload"] = payload
		if status == "claimed":
			event["attempt_count"] = int(event.get("attempt_count", 0)) + 1
		deferred_events[index] = event
		return


func queue_consequence(rule_id: StringName, event_type: StringName, source_object_id: String, source_job_id: StringName, due_day: int, due_minutes: int, priority: int, payload: Dictionary, cause_chain_id: String, source_event_id: String, depth: int) -> String:
	if event_type.is_empty() or depth > MAX_CAUSE_DEPTH:
		return ""
	var signature := "%s|%s|%s|%s" % [String(rule_id), source_object_id, String(event_type), cause_chain_id]
	for event: Dictionary in deferred_events:
		if str(event.get("signature", "")) == signature and str(event.get("status", "")) in ["pending", "claimed", "resolved"]:
			return str(event.get("event_id", ""))
	var event_id := _new_event_id("deferred")
	deferred_events.append({
		"event_id": event_id,
		"rule_id": String(rule_id),
		"event_type": String(event_type),
		"reason": str(payload.get("reason", String(rule_id))),
		"due_day": maxi(1, due_day),
		"due_minutes": maxi(0, due_minutes),
		"source_object_id": source_object_id,
		"source_job_id": String(source_job_id),
		"source_event_id": source_event_id,
		"cause_chain_id": cause_chain_id,
		"depth": depth,
		"priority": priority,
		"status": "pending",
		"attempt_count": 0,
		"signature": signature,
		"payload": payload.duplicate(true),
	})
	_trim(deferred_events, MAX_SIGNIFICANT_EVENTS)
	return event_id


func has_consequence(event_type: StringName) -> bool:
	for event: Dictionary in deferred_events:
		if StringName(str(event.get("event_type", ""))) == event_type and str(event.get("status", "")) in ["pending", "claimed"]:
			return true
	return false


func consequence_payload(event_type: StringName) -> Dictionary:
	for event: Dictionary in deferred_events:
		if StringName(str(event.get("event_type", ""))) == event_type and str(event.get("status", "")) in ["pending", "claimed"]:
			return (event.get("payload", {}) as Dictionary).duplicate(true)
	return {}


func consequence_due_day(event_type: StringName) -> int:
	for event: Dictionary in deferred_events:
		if StringName(str(event.get("event_type", ""))) == event_type and str(event.get("status", "")) in ["pending", "claimed"]:
			return int(event.get("due_day", 0))
	return 0


func set_consequence_status(event_type: StringName, status: String) -> void:
	if status not in ["pending", "claimed", "cancelled", "resolved"]:
		return
	for index: int in deferred_events.size():
		var event: Dictionary = deferred_events[index]
		if StringName(str(event.get("event_type", ""))) == event_type and str(event.get("status", "")) in ["pending", "claimed"]:
			if str(event.get("status", "")) == status:
				return
			event["status"] = status
			if status == "claimed":
				event["attempt_count"] = int(event.get("attempt_count", 0)) + 1
			deferred_events[index] = event
			return


func generator_context() -> Dictionary:
	var consequence_index: Array[Dictionary] = []
	for event: Dictionary in deferred_events:
		if str(event.get("status", "")) == "pending":
			consequence_index.append({"event_id": event.get("event_id", ""), "event_type": event.get("event_type", ""), "priority": event.get("priority", 0), "source_object_id": event.get("source_object_id", "")})
	return {"objects": objects.duplicate(true), "consequences": consequence_index}


func _record_action(instance_id: String, job_id: StringName, action: Dictionary, final_object: Dictionary, day: int, time_minutes: int) -> void:
	var object_state: Dictionary = objects[instance_id]
	var previous: Dictionary = object_state.get("properties", {}) as Dictionary
	var filtered := _filtered_properties(instance_id, final_object)
	var transitions: Array[Dictionary] = []
	var significant := false
	var significant_keys := PackedStringArray(OBJECT_DEFINITIONS[instance_id]["significant_keys"])
	for key: String in filtered:
		if not previous.has(key) or previous[key] != filtered[key]:
			transitions.append({"property": key, "from": previous.get(key), "to": filtered[key]})
			if significant_keys.has(key):
				significant = true
	if transitions.is_empty() and not bool((action.get("result", {}) as Dictionary).get("applied", false)):
		return
	var event := {
		"event_id": _new_event_id("action"),
		"day": day,
		"time_minutes": time_minutes,
		"job_id": String(job_id),
		"actor_id": str(action.get("employee_id", "")),
		"action_id": str(action.get("action_id", "")),
		"intent_id": str(action.get("intent", "")),
		"target_instance_id": instance_id,
		"cause_event_id": str(action.get("cause_event_id", "")),
		"reason": str(action.get("reason", "")),
		"count": 1,
		"transitions": transitions,
		"significant": significant,
	}
	if not significant and _can_merge_with_last(event):
		_merge_with_last(event)
	else:
		recent_events.append(event)
	if significant:
		significant_events.append(event.duplicate(true))
		_update_origins(instance_id, event)
	_trim(recent_events, MAX_RECENT_EVENTS)
	_trim(significant_events, MAX_SIGNIFICANT_EVENTS)
	_update_systemic_memory(instance_id, job_id, str(action.get("action_id", "")), final_object)


func _evaluate_systemic_consequences(job_id: StringName, result: Dictionary, day: int, time_minutes: int) -> void:
	var job_context: Dictionary = job_contexts.get(String(job_id), {}) as Dictionary
	if bool(job_context.get("is_consequence", false)):
		return
	for anomaly: Dictionary in SYSTEMIC_ANOMALIES:
		var target_instance_id := _instance_id_for_definition(str(anomaly.get("definition_id", "")))
		if target_instance_id.is_empty() or not objects.has(target_instance_id):
			continue
		var object_state: Dictionary = objects[target_instance_id]
		var properties: Dictionary = object_state.get("properties", {}) as Dictionary
		var systemic: Dictionary = object_state.get("systemic", {}) as Dictionary
		if not _properties_match(properties, anomaly.get("required_final_properties", {}) as Dictionary):
			continue
		if not _properties_match(systemic, anomaly.get("required_systemic_properties", {}) as Dictionary):
			continue
		if int(systemic.get("consequence_budget", 0)) <= 0 or day < int(systemic.get("cooldown_until_day", 0)):
			continue
		if float(systemic.get(str(anomaly.get("score_property", "")), 0.0)) < float(anomaly.get("minimum_score", 0.0)):
			continue
		var ordered_events := _events_for_job(job_id)
		var source_event_id := str(ordered_events[-1].get("event_id", "")) if not ordered_events.is_empty() else ""
		queue_consequence(
			StringName(str(anomaly.get("id", ""))), StringName(str(anomaly.get("event_type", ""))),
			target_instance_id, job_id, day + int(anomaly.get("delay_days", 1)), int(anomaly.get("due_minutes", time_minutes)),
			int(anomaly.get("priority", 0)), {
				"anomaly_id": str(anomaly.get("event_type", "")),
				"source_incarnation": int(properties.get("incarnation", 1)),
				"systemic_score": float(systemic.get(str(anomaly.get("score_property", "")), 0.0)),
				"relationship_tone": str(result.get("relationship_tone", "neutral")),
			}, "chain.%s.%s" % [String(job_id), str(anomaly.get("id", ""))], source_event_id, 1
		)
		systemic["consequence_budget"] = 0
		systemic["cooldown_until_day"] = day + 3
		systemic["last_generated_family"] = "thermal"
		object_state["systemic"] = systemic
		objects[target_instance_id] = object_state
		return


func _update_systemic_memory(instance_id: String, job_id: StringName, action_id: String, final_object: Dictionary) -> void:
	var object_state: Dictionary = objects[instance_id]
	var systemic: Dictionary = object_state.get("systemic", {}) as Dictionary
	if action_id in ["replace_faucet", "install_thermal_regulator"] or bool(final_object.get("thermal_regulator_installed", false)):
		systemic = {"thermal_instability": 0.0, "consequence_budget": 0, "last_thermal_direction": "", "cooldown_until_day": 0}
	else:
		var context: Dictionary = job_contexts.get(String(job_id), {}) as Dictionary
		var initial: Dictionary = context.get("initial_properties", {}) as Dictionary
		var initial_temperature := float(initial.get("temperature", final_object.get("temperature", 0.0)))
		var final_temperature := float(final_object.get("temperature", initial_temperature))
		var previous_direction := str(systemic.get("last_thermal_direction", ""))
		var direction := "heat" if action_id == "heat" or final_temperature > initial_temperature else ("cold" if action_id == "freeze" or final_temperature < initial_temperature else "")
		var excursion := absf(final_temperature - initial_temperature)
		if bool(initial.get("frozen", false)):
			excursion += 35.0
		var initial_tags := PackedStringArray(initial.get("tags", PackedStringArray()))
		if direction == "cold" and (bool(initial.get("heat_source_active", false)) or initial_temperature >= 10.0 or initial_tags.has("overheated")):
			excursion += 35.0
		if not direction.is_empty():
			var instability := float(systemic.get("thermal_instability", 0.0)) + excursion
			if not previous_direction.is_empty() and previous_direction != direction:
				instability += 20.0
			systemic["thermal_instability"] = minf(100.0, instability)
			systemic["last_thermal_direction"] = direction
			if not bool(context.get("is_consequence", false)) and instability >= 40.0:
				systemic["consequence_budget"] = 1
	object_state["systemic"] = systemic
	objects[instance_id] = object_state


func _events_for_job(job_id: StringName) -> Array[Dictionary]:
	var by_id: Dictionary = {}
	for event: Dictionary in recent_events:
		if StringName(str(event.get("job_id", ""))) == job_id:
			by_id[str(event.get("event_id", ""))] = event
	for event: Dictionary in significant_events:
		if StringName(str(event.get("job_id", ""))) == job_id:
			by_id[str(event.get("event_id", ""))] = event
	var result: Array[Dictionary] = []
	for event: Variant in by_id.values():
		result.append((event as Dictionary).duplicate(true))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _event_serial(a) < _event_serial(b))
	return result


func _event_serial(event: Dictionary) -> int:
	return int(str(event.get("event_id", "0")).get_slice(".", 1))


func _contains_ordered_sequence(actions: PackedStringArray, required: PackedStringArray) -> bool:
	var required_index := 0
	for action_id: String in actions:
		if required_index < required.size() and action_id == required[required_index]:
			required_index += 1
	return required_index == required.size() and not required.is_empty()


func _properties_match(properties: Dictionary, query: Dictionary) -> bool:
	for property_name: String in query:
		if properties.get(property_name) != query[property_name]:
			return false
	return true


func _instance_id_for_definition(definition_id: String) -> String:
	for instance_id: String in OBJECT_DEFINITIONS:
		if str((OBJECT_DEFINITIONS[instance_id] as Dictionary).get("definition_id", "")) == definition_id:
			return instance_id
	return ""


func _update_object_snapshot(instance_id: String, world_object: Dictionary) -> void:
	var object_state: Dictionary = objects[instance_id]
	object_state["properties"] = _filtered_properties(instance_id, world_object)
	object_state["revision"] = int(object_state.get("revision", 0)) + 1
	objects[instance_id] = object_state


func _update_origins(instance_id: String, event: Dictionary) -> void:
	var object_state: Dictionary = objects[instance_id]
	var origins: Dictionary = object_state.get("origins", {}) as Dictionary
	for transition: Dictionary in event.get("transitions", []):
		var key := str(transition.get("property", ""))
		var active := _is_active_value(transition.get("to"))
		if active:
			origins[key] = {
				"origin_event_id": event["event_id"], "origin_action_id": event["action_id"],
				"origin_actor_id": event["actor_id"], "origin_job_id": event["job_id"],
				"previous_value": transition.get("from"), "active": true, "resolved_by_event_id": "",
			}
		elif origins.has(key) and bool((origins[key] as Dictionary).get("active", false)):
			var origin: Dictionary = origins[key]
			origin["active"] = false
			origin["resolved_by_event_id"] = event["event_id"]
			origins[key] = origin
	object_state["origins"] = origins
	objects[instance_id] = object_state


func _can_merge_with_last(event: Dictionary) -> bool:
	if recent_events.is_empty():
		return false
	var previous: Dictionary = recent_events[-1]
	return not bool(previous.get("significant", false)) and previous.get("job_id") == event.get("job_id") and previous.get("actor_id") == event.get("actor_id") and previous.get("action_id") == event.get("action_id") and previous.get("intent_id") == event.get("intent_id") and previous.get("target_instance_id") == event.get("target_instance_id")


func _merge_with_last(event: Dictionary) -> void:
	var previous: Dictionary = recent_events[-1]
	previous["count"] = int(previous.get("count", 1)) + 1
	var merged: Dictionary = {}
	for transition: Dictionary in previous.get("transitions", []):
		merged[str(transition["property"])] = transition.duplicate(true)
	for transition: Dictionary in event.get("transitions", []):
		var key := str(transition["property"])
		if merged.has(key):
			var existing: Dictionary = merged[key]
			existing["to"] = transition.get("to")
			merged[key] = existing
		else:
			merged[key] = transition.duplicate(true)
	previous["transitions"] = merged.values()
	previous["time_minutes"] = event.get("time_minutes", previous.get("time_minutes", 0))
	recent_events[-1] = previous


func _filtered_properties(instance_id: String, source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: String in OBJECT_DEFINITIONS[instance_id]["property_keys"]:
		if source.has(key):
			var value: Variant = source[key]
			result[key] = Array(value) if value is PackedStringArray else value
	return result


func _ensure_default_objects() -> void:
	for instance_id: String in OBJECT_DEFINITIONS:
		_ensure_object(instance_id)


func _ensure_object(instance_id: String) -> void:
	if objects.has(instance_id):
		return
	objects[instance_id] = {"instance_id": instance_id, "definition_id": OBJECT_DEFINITIONS[instance_id]["definition_id"], "properties": {}, "origins": {}, "systemic": {}, "revision": 0}


func _new_event_id(prefix: String) -> String:
	var value := "%s.%d" % [prefix, _next_event_serial]
	_next_event_serial += 1
	return value


func _is_active_value(value: Variant) -> bool:
	if value is bool:
		return value
	if value is int or value is float:
		return value != 0
	return not str(value).is_empty() and str(value) not in ["idle", "normal", "closed", "water"]


func _load_dictionary_array(source: Variant, target: Array[Dictionary], limit: int) -> void:
	if source is Array:
		for value: Variant in source:
			if value is Dictionary:
				target.append((value as Dictionary).duplicate(true))
	_trim(target, limit)


func _trim(target: Array[Dictionary], limit: int) -> void:
	while target.size() > limit:
		target.pop_front()


func _rebuild_job_event_counts() -> void:
	_job_event_counts.clear()
