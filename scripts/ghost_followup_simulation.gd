class_name GhostFollowupSimulation
extends RefCounted

var world_object: Dictionary = {
	"definition_id": &"escaped_ghost",
	"ghost_state": &"calm",
	"mirror_state": &"covered",
	"trap_state": &"packed",
	"resident_intro_seen": false,
}
var action_log: Array[Dictionary] = []


func load_state(saved_state: Dictionary) -> void:
	var saved_object: Variant = saved_state.get("world_object", {})
	if saved_object is Dictionary:
		world_object.merge((saved_object as Dictionary).duplicate(true), true)
	action_log = (saved_state.get("action_log", []) as Array).duplicate(true)


func get_state() -> Dictionary:
	return {"world_object": world_object.duplicate(true), "action_log": action_log.duplicate(true)}


func get_resident_request() -> String:
	return "Оно прошло прямо сквозь полотно! Пожалуйста, верните привидение обратно или поймайте его."


func install_trap(employee_id: StringName, has_trap: bool) -> Dictionary:
	if not has_trap:
		return _record(employee_id, &"install_trap", false, true, "В бригаде нет ловушки. Её можно купить в лавке снаряжения.")
	if StringName(world_object["trap_state"]) != &"packed":
		return _record(employee_id, &"install_trap", false, false, "Ловушка уже установлена.")
	world_object["trap_state"] = &"installed"
	return _record(employee_id, &"install_trap", true, false, "Ловушка установлена и готова к захвату привидения.")


func apply_ghost_action(employee_id: StringName, action_id: StringName) -> Dictionary:
	var state := StringName(world_object["ghost_state"])
	if state in [&"expelled", &"captured"]:
		return _record(employee_id, action_id, false, false, "Привидения в комнате больше нет.")
	match action_id:
		&"diagnose":
			return _record(employee_id, action_id, true, false, "Привидение связано с зеркалом остаточным магическим следом. Его можно вернуть в портал или изолировать в служебной ловушке.")
		&"antimagic":
			if StringName(world_object["mirror_state"]) != &"open":
				return _record(employee_id, action_id, false, true, "Путь обратно закрыт полотном. Сначала нужно открыть зеркало.")
			world_object["ghost_state"] = &"expelled"
			return _record(employee_id, action_id, true, false, "Привидение направлено обратно в портал. Теперь портал нужно закрыть.")
		&"trap":
			if StringName(world_object["trap_state"]) != &"installed":
				return _record(employee_id, action_id, false, true, "Сначала нужно установить ловушку.")
			world_object["ghost_state"] = &"captured"
			world_object["trap_state"] = &"occupied"
			return _record(employee_id, action_id, true, false, "Ловушка втянула привидение и запечатала его внутри.")
		&"freeze", &"heat", &"animate":
			world_object["ghost_state"] = &"angry"
			return _record(employee_id, action_id, true, true, "Заклинание прошло сквозь бестелесное привидение. Оно разозлилось и теперь мечется по комнате.")
		&"physical_move":
			world_object["ghost_state"] = &"angry"
			return _record(employee_id, action_id, false, true, "Грог попытался схватить привидение, но руки прошли насквозь. Привидение возмутилось.")
		&"telekinesis":
			world_object["ghost_state"] = &"angry"
			return _record(employee_id, action_id, false, true, "Телекинез не удерживает бестелесную цель. Привидение вырвалось и заметалось быстрее.")
	return _record(employee_id, action_id, false, true, "Это действие не поможет поймать привидение.")


func uncover_mirror(employee_id: StringName, antimagic_present: bool) -> Dictionary:
	if StringName(world_object["mirror_state"]) != &"covered":
		return _record(employee_id, &"uncover", false, false, "Полотно уже снято.")
	if not antimagic_present:
		return _record(employee_id, &"uncover", false, true, "Снимать полотно бесполезно: в бригаде нет специалиста по антимагии, способного закрыть портал.")
	world_object["mirror_state"] = &"open"
	if StringName(world_object["ghost_state"]) == &"captured":
		return _record(employee_id, &"uncover", true, false, "Полотно снято. Портал снова открыт.")
	return _record(employee_id, &"uncover", true, false, "Полотно снято. Портал снова открыт; теперь привидение можно вернуть внутрь.")


func close_portal(employee_id: StringName, has_antimagic: bool) -> Dictionary:
	if not has_antimagic:
		return _record(employee_id, &"antimagic", false, true, "Закрыть портал может только специалист по магической изоляции.")
	if StringName(world_object["mirror_state"]) != &"open":
		return _record(employee_id, &"antimagic", false, true, "Портал сейчас скрыт полотном.")
	if StringName(world_object["ghost_state"]) not in [&"expelled", &"captured"]:
		return _record(employee_id, &"antimagic", false, true, "Сначала нужно вернуть привидение в портал.")
	world_object["mirror_state"] = &"closed"
	return _record(employee_id, &"antimagic", true, false, "Портал закрыт. Зеркало снова стало обычным.")


func break_mirror(employee_id: StringName) -> Dictionary:
	if StringName(world_object["mirror_state"]) == &"destroyed":
		return _record(employee_id, &"physical_move", false, false, "Зеркало уже разбито.")
	world_object["mirror_state"] = &"destroyed"
	if StringName(world_object["ghost_state"]) != &"captured":
		world_object["ghost_state"] = &"expelled"
	return _record(employee_id, &"physical_move", true, true, "Грог разбил зеркало. Портал разрушен, и связь с привидением оборвалась.")


func is_resolved() -> bool:
	return StringName(world_object["mirror_state"]) == &"destroyed" or (StringName(world_object["ghost_state"]) == &"captured" and StringName(world_object["mirror_state"]) != &"open") or (
		StringName(world_object["ghost_state"]) == &"expelled" and StringName(world_object["mirror_state"]) == &"closed"
	)


func get_completion_result() -> Dictionary:
	if StringName(world_object["mirror_state"]) == &"destroyed":
		var ghost_captured := StringName(world_object["ghost_state"]) == &"captured"
		return {
			"summary": "Портал уничтожен вместе с зеркалом. Привидение осталось в ловушке." if ghost_captured else "Портал уничтожен вместе с зеркалом. Связь с привидением оборвана.",
			"review": "Это было фамильное зеркало! Теперь из него действительно больше никто не выйдет — как и моё отражение.",
			"consequences": ["Старинное зеркало уничтожено.", "Привидение изолировано в служебной ловушке.", "Служба выплачивает компенсацию за зеркало."] if ghost_captured else ["Старинное зеркало уничтожено.", "Магическая связь с привидением оборвана.", "Служба выплачивает компенсацию за зеркало."],
			"reward_adjustment": -200,
			"compensation_cost": 300,
			"reputation_change": -2,
			"actions": action_log.duplicate(true),
		}
	if StringName(world_object["ghost_state"]) == &"captured":
		var portal_closed := StringName(world_object["mirror_state"]) == &"closed"
		return {
			"summary": "Привидение поймано в служебную ловушку, портал окончательно закрыт." if portal_closed else "Привидение поймано в служебную ловушку. Зеркало осталось временно изолировано полотном.",
			"review": "Призрак в ловушке, портал закрыт. Наконец-то в этой комнате всё остаётся на своих местах." if portal_closed else "Призрак теперь сидит в банке, зеркало — под покрывалом. Не тот интерьер, который я заказывала, но хотя бы никто больше не летает сквозь мебель.",
			"consequences": ["Привидение изолировано в служебной ловушке.", "Портал окончательно закрыт."] if portal_closed else ["Привидение изолировано в служебной ловушке.", "Портал остаётся временно закрыт полотном."],
			"reward_adjustment": -50 if portal_closed else -100,
			"compensation_cost": 0,
			"reputation_change": 0,
			"actions": action_log.duplicate(true),
		}
	return {
		"summary": "Привидение возвращено в портал, портал закрыт без ущерба.",
		"review": "На этот раз из зеркала вышел только мой собственный вид — усталый, но исключительно довольный. Вот теперь это действительно закрытый портал.",
		"consequences": ["Привидение возвращено в портал.", "Портал окончательно закрыт.", "Зеркало сохранено."],
		"reward_adjustment": 0,
		"compensation_cost": 0,
		"reputation_change": 1,
		"actions": action_log.duplicate(true),
	}


func _record(employee_id: StringName, action_id: StringName, applied: bool, warning: bool, message: String) -> Dictionary:
	var result := {"applied": applied, "warning": warning, "message": message, "resolved": is_resolved()}
	action_log.append({"employee_id": String(employee_id), "action_id": String(action_id), "result": result.duplicate(true)})
	return result
