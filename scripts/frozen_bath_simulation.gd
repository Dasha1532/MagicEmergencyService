class_name FrozenBathSimulation
extends RefCounted

const FlowRules := preload("res://scripts/object_flow_rules.gd")
const ActionRules := preload("res://scripts/object_interaction_rules.gd")
const BATH_INSTANCE_ID := "old_quarter_5.bathroom.bath"
const FAUCET_INSTANCE_ID := "old_quarter_5.bathroom.lava_faucet"

const BORIS_BATH_DIAGNOSIS := "Ванна цела, слив не забит. Проблема в том, что воду теперь можно вынимать отсюда одним куском."

var world_object: Dictionary = {
	"resolved": false,
	"bath_damaged": false,
	"bath_still_frozen": false,
	"ice_removed": false,
	"cold_trace_removed": false,
	"extra_frost": false,
	"regulator_installed": false,
	"resident_intro_seen": false,
	"faucet_diagnosed": false,
}
var action_log: Array[Dictionary] = []
var last_flow_minute: int = -1
var resident_request: String = ""
var action_before: Dictionary = {}

func _object_snapshots() -> Dictionary:
	return {FAUCET_INSTANCE_ID: world_object.duplicate(true), BATH_INSTANCE_ID: {"contains_ice": not bool(world_object["ice_removed"]), "damaged": bool(world_object["bath_damaged"])}}


func initialize_from_job(job: Dictionary) -> void:
	resident_request = str(job.get("resident_request", ""))
	var instance: Dictionary = job.get("generated_instance", {}) as Dictionary
	world_object.merge((instance.get("initial_state", {}) as Dictionary).duplicate(true), true)
	var remembered: Dictionary = (instance.get("related_initial_states", {}) as Dictionary).get(BATH_INSTANCE_ID, {}) as Dictionary
	world_object["bath_damaged"] = bool(remembered.get("damaged", world_object.get("bath_damaged", false)))
	_sync_object_properties()


func _sync_object_properties() -> void:
	world_object["definition_id"] = &"lava_faucet"
	world_object["cold_trace_active"] = not bool(world_object["cold_trace_removed"])
	world_object["cold_source_active"] = bool(world_object["cold_trace_active"])
	world_object["flow_content"] = &"ice" if bool(world_object["cold_trace_active"]) else &"water"
	world_object["valve_position"] = world_object.get("valve_position", &"open")
	world_object["flow_blocked"] = bool(world_object.get("flow_blocked", false))
	# Обледенение корпуса не блокирует исправный вентиль.
	world_object["frozen"] = bool(world_object["cold_trace_active"]) or bool(world_object.get("extra_frost", false))
	world_object["valve_frozen"] = bool(world_object.get("valve_frozen", false))
	world_object["regulator_installed"] = bool(world_object.get("regulator_installed", false))
	world_object["thermal_regulator_installed"] = world_object["regulator_installed"]
	world_object["function_test_passed"] = bool(world_object["cold_trace_removed"])


func advance_flow_until(time_minutes: int) -> bool:
	if last_flow_minute < 0:
		last_flow_minute = time_minutes
		return false
	if time_minutes == last_flow_minute:
		return false
	last_flow_minute = time_minutes
	_sync_object_properties()
	var bath := {"contains_ice": not bool(world_object["ice_removed"])}
	if not FlowRules.apply_flow(world_object, bath):
		return false
	world_object["ice_removed"] = not bool(bath["contains_ice"])
	world_object["bath_still_frozen"] = bool(bath["contains_ice"])
	return true


func load_state(saved_state: Dictionary) -> void:
	last_flow_minute = int(saved_state.get("last_flow_minute", -1))
	var saved_object: Variant = saved_state.get("world_object", {})
	if saved_object is Dictionary:
		world_object.merge((saved_object as Dictionary).duplicate(true), true)
	action_log.clear()
	var saved_actions: Variant = saved_state.get("action_log", [])
	if saved_actions is Array:
		for saved_action: Variant in saved_actions:
			if saved_action is Dictionary:
				action_log.append((saved_action as Dictionary).duplicate(true))
	_sync_object_properties()


func get_state() -> Dictionary:
	_sync_object_properties()
	return {"world_object": world_object.duplicate(true), "action_log": action_log.duplicate(true), "last_flow_minute": last_flow_minute,
		"related_objects": {BATH_INSTANCE_ID: {"contains_ice": not bool(world_object["ice_removed"]), "damaged": bool(world_object["bath_damaged"])}}}


func get_resident_request() -> String:
	if not resident_request.is_empty():
		return resident_request
	return "Я просил сделать ванную безопасной, а не перевести её из вулкана в ледник."


func apply_action(employee_id: StringName, action_id: StringName, has_regulator: bool = false, target_id: StringName = &"all", employee_data: Dictionary = {}) -> Dictionary:
	action_before = _object_snapshots()
	if action_id == &"turn_valve":
		var blocked := ActionRules.valve_block_reason(world_object, employee_data)
		if not blocked.is_empty():
			return _record(employee_id, action_id, false, true, blocked)
		var opening := str(world_object.get("valve_position", "open")) != "open"
		world_object["valve_position"] = &"open" if opening else &"closed"
		return _record(employee_id, action_id, true, false, "Кран открыт." if opening else "Кран закрыт. Холодный след остаётся." if not bool(world_object["cold_trace_removed"]) else "Кран закрыт.")
	if is_fully_resolved():
		return _record(employee_id, action_id, false, true, "Магическая температура уже стабилизирована. Дополнительные действия не требуются.")
	if action_id == &"antimagic" and bool(world_object["cold_trace_removed"]):
		return _record(employee_id, action_id, false, false, "Холодный след с крана уже снят. Повторная антимагия не требуется.")
	if action_id == &"telekinesis" and bool(world_object["ice_removed"]):
		return _record(employee_id, action_id, false, false, "Лёд из ванны уже убран. Телекинезу больше нечего перемещать.")
	if action_id == &"heat" and target_id == &"faucet" and bool(world_object["cold_trace_removed"]):
		return _record(employee_id, action_id, false, false, "Холодный след с крана уже снят. Повторный нагрев не требуется.")
	if action_id == &"heat" and target_id == &"bath" and bool(world_object["ice_removed"]):
		return _record(employee_id, action_id, false, false, "Лёд в ванне уже растоплен. Повторный нагрев не требуется.")
	var applied := true
	var warning := false
	var message := ""
	match action_id:
		&"diagnose":
			if target_id != &"bath":
				world_object["faucet_diagnosed"] = true
			message = _bath_diagnosis() if target_id == &"bath" else "Соединения исправны. Для стабилизации температуры нужен рунический терморегулятор из лавки снабжения."
		&"heat":
			if target_id == &"faucet":
				world_object["resolved"] = true
				world_object["cold_trace_removed"] = true
				world_object["extra_frost"] = false
				world_object["bath_still_frozen"] = not bool(world_object["ice_removed"])
				message = "Осторожный нагрев снял холодный след с крана. Новая вода больше не замёрзнет, но лёд в ванне нужно убрать отдельно." if not bool(world_object["ice_removed"]) else "Осторожный нагрев снял холодный след с крана и полностью завершил работу."
			elif target_id == &"bath":
				world_object["bath_still_frozen"] = false
				world_object["ice_removed"] = true
				message = "Осторожный нагрев растопил лёд в ванне, но холодный след на кране ещё нужно снять." if not bool(world_object["cold_trace_removed"]) else "Осторожный нагрев растопил оставшийся лёд и полностью завершил работу."
			else:
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
			if target_id == &"faucet":
				world_object["resolved"] = false
				world_object["cold_trace_removed"] = false
				world_object["extra_frost"] = true
				message = "Заморозка усилила холодный след на кране. Состояние ванны не изменилось."
			elif target_id == &"bath":
				world_object["bath_still_frozen"] = true
				world_object["ice_removed"] = false
				message = "Заморозка снова сковала ванну льдом. Состояние крана не изменилось."
			else:
				world_object["resolved"] = false
				world_object["cold_trace_removed"] = false
				world_object["extra_frost"] = true
				world_object["bath_still_frozen"] = true
				world_object["ice_removed"] = false
				message = "Кран снова покрылся инеем, а лёд в ванне стал толще. Ванная убедительно доказала, что способна замерзнуть ещё сильнее."
			warning = true
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


func _bath_diagnosis(personal: bool = false) -> String:
	if bool(world_object.get("bath_damaged", false)):
		return "Ванна повреждена: в корпусе трещина. Лёд внутри остался." if not bool(world_object.get("ice_removed", false)) else "Ванна повреждена: в корпусе трещина. Лёд уже убран."
	if bool(world_object.get("ice_removed", false)):
		return "Ванна цела, слив не забит. Лёд уже убран."
	return BORIS_BATH_DIAGNOSIS if personal else "Ванна цела, слив не забит. Внутри находится цельная масса льда."


func get_employee_reaction(employee_id: StringName, action_id: StringName, target_id: StringName = &"all") -> String:
	if employee_id == &"felix" and action_id == &"antimagic" and bool(world_object["cold_trace_removed"]):
		return "Холодный след уже снят. Повторно гасить отсутствующие чары не стану."
	if employee_id == &"nika" and action_id == &"telekinesis" and bool(world_object["ice_removed"]):
		return "Лёд уже убран. Второй раз выносить из пустой ванны нечего."
	if employee_id == &"grog" and action_id == &"physical_move":
		return "Лёд уберу. Если появится снова — в следующий раз принесу молот побольше."
	if employee_id == &"boris" and action_id == &"diagnose":
		if target_id == &"bath":
			return _bath_diagnosis(true)
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
			"summary": tr("Холодный магический след снят с крана, но образовавшийся лёд остался в ванне.%s") % (tr(" Ванна по-прежнему повреждена.") if damaged else ""),
			"review": "Кран вы исправили, но ванна всё ещё занята айсбергом — и теперь ещё треснула. За такой курорт полной оплаты не будет." if damaged else "Кран вы исправили, и новая вода больше не замерзает. Но ванна всё ещё занята айсбергом, поэтому полную оплату не ждите.",
			"consequences": ["Кран очищен от остаточной магии холода.", "Лёд в ванне не растоплен.", "Трещина ванны не восстановлена."] if damaged else ["Кран очищен от остаточной магии холода.", "Лёд в ванне не растоплен."],
			"reward_adjustment": -150 if damaged else -80,
			"expense_reimbursement": equipment_reimbursement,
			"compensation_cost": 180 if damaged else 0,
			"reputation_change": -1 if damaged else 0,
			"actions": action_log.duplicate(true),
		}
	return {
		"summary": "Остаточный холодный след устранён; вода в ванной больше не замерзает. После силового удаления льда ванна треснула, повреждение не устранено." if damaged else "Остаточный холодный след устранён; вода в ванной больше не замерзает. Ванна не повреждена.",
		"review": "Ванная снова безопасна. Теперь вода просто холодная, как и положено воде без личных амбиций." if not damaged else "Вода больше не замерзает. Трещину на ванне я назову памятью о вашем особенно убедительном методе.",
		"consequences": ["Температура воды стабилизирована.", "Ванна не повреждена."] if not damaged else ["Температура воды стабилизирована.", "Край ванны треснул после силового удаления льда."],
		"reward_adjustment": 0 if not damaged else -70,
		"expense_reimbursement": equipment_reimbursement,
		"compensation_cost": 0 if not damaged else 180,
		"reputation_change": 1 if not damaged else -1,
		"actions": action_log.duplicate(true),
	}


func _record(employee_id: StringName, action_id: StringName, applied: bool, warning: bool, message: String) -> Dictionary:
	_sync_object_properties()
	var result := {"applied": applied, "warning": warning, "message": message, "resolved": is_resolved()}
	action_log.append(ActionRules.action_event(employee_id, action_id, action_before, _object_snapshots(), result))
	return result
