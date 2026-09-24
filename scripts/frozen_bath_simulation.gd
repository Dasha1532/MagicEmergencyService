class_name FrozenBathSimulation
extends RefCounted

var world_object: Dictionary = {
	"resolved": false,
	"bath_damaged": false,
	"bath_still_frozen": false,
	"ice_removed": false,
	"cold_trace_removed": false,
	"extra_frost": false,
	"regulator_installed": false,
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
	return "Я просил сделать ванную безопасной, а не перевести её из вулкана в ледник."


func apply_action(employee_id: StringName, action_id: StringName, has_regulator: bool = false) -> Dictionary:
	if is_fully_resolved():
		return _record(employee_id, action_id, false, true, "Магическая температура уже стабилизирована. Дополнительные действия не требуются.")
	var applied := true
	var warning := false
	var message := ""
	match action_id:
		&"diagnose":
			message = ""
		&"heat":
			world_object["resolved"] = true
			world_object["cold_trace_removed"] = true
			world_object["extra_frost"] = false
			world_object["bath_still_frozen"] = false
			world_object["ice_removed"] = true
			message = "Осторожный нагрев растопил лёд. Холодный след больше не действует, но прежние повреждения ванны остались." if bool(world_object["bath_damaged"]) else "Осторожный нагрев растопил лёд и завершил работу."
		&"antimagic":
			world_object["resolved"] = true
			world_object["cold_trace_removed"] = true
			world_object["extra_frost"] = false
			world_object["bath_still_frozen"] = not bool(world_object["ice_removed"])
			message = "Антимагия сняла холодный след с крана. Лёд уже убран, поэтому работа выполнена полностью." if bool(world_object["ice_removed"]) else "Антимагия сняла холодный след с крана. Новая вода больше не замёрзнет, но лёд в ванне остался."
		&"repair":
			if not has_regulator:
				return _record(employee_id, action_id, false, true, "Соединения исправны. Для стабилизации температуры нужен рунический терморегулятор из лавки снабжения.")
			world_object["resolved"] = true
			world_object["cold_trace_removed"] = true
			world_object["extra_frost"] = false
			world_object["bath_still_frozen"] = not bool(world_object["ice_removed"])
			world_object["regulator_installed"] = true
			message = "Борис установил рунический терморегулятор воды. Кран стабилизирован, а лёд уже убран." if bool(world_object["ice_removed"]) else "Борис установил рунический терморегулятор воды. Кран больше не впадает в температурные крайности, но лёд в ванне остался."
		&"install_regulator":
			if not has_regulator:
				return _record(employee_id, action_id, false, true, "Для установки нужен рунический терморегулятор из лавки снабжения.")
			world_object["resolved"] = true
			world_object["cold_trace_removed"] = true
			world_object["extra_frost"] = false
			world_object["bath_still_frozen"] = not bool(world_object["ice_removed"])
			world_object["regulator_installed"] = true
			message = "Рунический терморегулятор установлен. Он удерживает воду между состояниями «лава» и «ледяная глыба»."
		&"physical_move":
			world_object["bath_damaged"] = true
			warning = true
			message = "Лёд расколот, но холодный след остался в кране. Ванна получила трещину, а вода снова начинает замерзать."
		&"freeze":
			world_object["resolved"] = false
			world_object["cold_trace_removed"] = false
			world_object["extra_frost"] = true
			world_object["bath_still_frozen"] = true
			world_object["ice_removed"] = false
			warning = true
			message = "Кран снова покрылся инеем, а лёд в ванне стал толще. Ванная убедительно доказала, что способна замерзнуть ещё сильнее."
		&"telekinesis":
			world_object["bath_still_frozen"] = false
			world_object["ice_removed"] = true
			message = "Лёд и осколки убраны из ванны телекинезом. Повреждения ванны остались." if bool(world_object["bath_damaged"]) else "Весь лёд убран из ванны телекинезом."
		&"animate":
			applied = false
			warning = true
			message = "Оживление ванны не исправит температуру воды и добавит к заявке подвижную сантехнику."
		_:
			applied = false
			warning = true
			message = "Это действие не влияет на магическое замерзание."
	return _record(employee_id, action_id, applied, warning, message)


func get_employee_reaction(employee_id: StringName, action_id: StringName) -> String:
	if employee_id == &"grog" and action_id == &"physical_move":
		return "Лёд уберу. Если появится снова — в следующий раз принесу молот побольше."
	if employee_id == &"boris" and action_id == &"diagnose":
		return "Трубы целы, кран цел. Похоже, после прошлого ремонта у него осталось слишком холодное отношение к работе."
	match action_id:
		&"heat":
			return "Растоплю лёд постепенно. Ванне уже хватило резких перепадов температуры."
		&"antimagic":
			return "Лёд уже убран. Осталось снять холодный след с крана, чтобы он не появился снова." if bool(world_object["ice_removed"]) else "Сниму чары с крана. Сам лёд от этого не растает, но хотя бы перестанет появляться снова."
		&"repair", &"install_regulator":
			return "Лёд уже убран — поставлю терморегулятор, чтобы новая партия не успела сформироваться." if bool(world_object["ice_removed"]) else "Хорошо, установлю терморегулятор. Кран перестанет выбирать между лавой и ледником, а сам лёд придётся растопить отдельно."
		&"freeze":
			return "Заморозить ещё сильнее можно. Смысл этого решения обсудим после оттаивания."
		&"telekinesis":
			return "Лёд вынесу телекинезом. Надеюсь, во дворе как раз не хватало маленького айсберга."
		&"animate":
			return "Если оживить ванну, она, возможно, уйдёт искать место потеплее. Ремонтировать это не поможет."
	return ""


func is_resolved() -> bool:
	return bool(world_object["resolved"])


func is_fully_resolved() -> bool:
	return is_resolved() and not bool(world_object["bath_still_frozen"])


func get_completion_result() -> Dictionary:
	if not is_resolved():
		return {}
	var damaged := bool(world_object["bath_damaged"])
	var frozen := bool(world_object["bath_still_frozen"])
	var equipment_reimbursement := 280 if bool(world_object["regulator_installed"]) else 0
	if frozen:
		return {
			"summary": "Холодный магический след снят с крана, но образовавшийся лёд остался в ванне.%s" % (" Ванна по-прежнему повреждена." if damaged else ""),
			"review": "Кран вы исправили, но ванна всё ещё занята айсбергом — и теперь ещё треснула. За такой курорт полной оплаты не будет." if damaged else "Кран вы исправили, и новая вода больше не замерзает. Но ванна всё ещё занята айсбергом, поэтому полную оплату не ждите.",
			"consequences": ["Кран очищен от остаточной магии холода.", "Лёд в ванне не растоплен.", "Трещина ванны не восстановлена."] if damaged else ["Кран очищен от остаточной магии холода.", "Лёд в ванне не растоплен."],
			"reward_adjustment": -150 if damaged else -80,
			"expense_reimbursement": equipment_reimbursement,
			"compensation_cost": 180 if damaged else 0,
			"reputation_change": -1 if damaged else 0,
			"actions": action_log.duplicate(true),
		}
	return {
		"summary": "Остаточный холодный след устранён; вода в ванной больше не замерзает.",
		"review": "Ванная снова безопасна. Теперь вода просто холодная, как и положено воде без личных амбиций." if not damaged else "Вода больше не замерзает. Трещину на ванне я назову памятью о вашем особенно убедительном методе.",
		"consequences": ["Температура воды стабилизирована.", "Ванна не повреждена."] if not damaged else ["Температура воды стабилизирована.", "Край ванны треснул после силового удаления льда."],
		"reward_adjustment": 0 if not damaged else -70,
		"expense_reimbursement": equipment_reimbursement,
		"compensation_cost": 0 if not damaged else 180,
		"reputation_change": 1 if not damaged else -1,
		"actions": action_log.duplicate(true),
	}


func _record(employee_id: StringName, action_id: StringName, applied: bool, warning: bool, message: String) -> Dictionary:
	var result := {"applied": applied, "warning": warning, "message": message, "resolved": is_resolved()}
	action_log.append({"employee_id": String(employee_id), "action_id": String(action_id), "result": result.duplicate(true)})
	return result
