class_name PortalMirrorSimulation
extends RefCounted

var world_object: Dictionary = {
	"definition_id": &"portal_mirror",
	"magic_level": 9,
	"temperature": 2,
	"portal_open": true,
	"covered": false,
	"cold_aura": true,
	"stable": false,
	"destroyed": false,
	"damage": 0,
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
	return "Из зеркала тянет ледяным холодом. Пожалуйста, остановите это — в комнате уже невозможно находиться."


func get_employee_reaction(employee_id: StringName, action_id: StringName) -> String:
	return {
		&"boris": {
			&"diagnose": "Зеркало показывает потусторонний мир. Гарантия, полагаю, уже закончилась.",
			&"cover": "Полотно повешу. Если портал обидится — пусть пишет претензию.",
		},
		&"grog": {&"physical_move": "Разбить зеркало могу. Семь лет несчастья в наряд не входят."},
		&"liliya": {
			&"freeze": "Холодный портал предлагается заморозить. Люблю последовательные технические задания.",
			&"heat": "Согрею комнату. Портал, вероятно, воспримет это как личное оскорбление.",
		},
		&"nika": {&"telekinesis": "Сдвину осторожно. Если за зеркалом другой мир, надеюсь, он не прибит к стене."},
		&"felix": {&"antimagic": "Закрою канал. Незарегистрированным порталам здесь не место."},
	}.get(employee_id, {}).get(action_id, "")


func get_resident_reaction(action_id: StringName) -> String:
	match action_id:
		&"antimagic":
			return "Зеркало снова обычное. И этот ужасный холод исчез."
		&"heat":
			if int(world_object["damage"]) > 0:
				return "Осторожнее! Рама уже начинает плавиться."
			return "Наконец-то стало теплее. Но портал всё ещё открыт."
		&"freeze":
			return "Здесь и без того было холодно!"
		&"cover":
			if bool(world_object["cold_aura"]):
				return "Портала не видно, но холод никуда не делся. Это точно поможет?"
			return "Так гораздо лучше. Надеюсь, полотно действительно его удержит."
		&"physical_move":
			return "Это было фамильное зеркало!"
	return ""


func apply_action(employee_id: StringName, action_id: StringName) -> Dictionary:
	var applied := false
	var warning := false
	var message := "Действие не изменило состояние зеркала."
	if bool(world_object["destroyed"]):
		message = "Зеркало разбито. Воздействовать больше не на что."
		return _record(employee_id, action_id, false, true, message)
	if not bool(world_object["portal_open"]) and action_id != &"diagnose":
		message = "Портал уже закрыт. Зеркало выглядит обычным."
		return _record(employee_id, action_id, false, false, message)

	match action_id:
		&"diagnose":
			applied = true
			if bool(world_object["covered"]):
				message = "Полотно удерживается креплениями, но портал под ним остаётся открытым. Бестелесное существо сможет пройти сквозь ткань."
			else:
				message = "Портал излучает холод. Связь можно закрыть антимагией, временно изолировать защитным полотном или оборвать, уничтожив зеркало."
		&"antimagic":
			applied = true
			world_object["magic_level"] = 0
			world_object["portal_open"] = false
			message = "Антимагия погасила связь. Портал закрыт, зеркало не повреждено."
		&"freeze":
			applied = true
			world_object["temperature"] = int(world_object["temperature"]) - 5
			world_object["stable"] = true
			message = "Холод стабилизировал края портала, но не закрыл его."
		&"heat":
			applied = true
			world_object["temperature"] = int(world_object["temperature"]) + 5
			if bool(world_object["cold_aura"]):
				world_object["cold_aura"] = false
				message = "Лилия рассеяла холод вокруг портала. Иней растаял, в комнате снова стало тепло."
			else:
				warning = true
				world_object["stable"] = false
				world_object["damage"] = int(world_object["damage"]) + 1
				message = "Повторный нагрев расшатал портал. Рама зеркала начала деформироваться."
		&"telekinesis":
			warning = true
			message = "Активный портал удерживает зеркало на месте. Телекинез не может безопасно его сдвинуть."
		&"repair":
			warning = true
			message = "Такую раму нельзя восстановить на выезде: потребуется мастерская или изготовление замены."
		&"cover":
			if bool(world_object["covered"]):
				message = "Защитное полотно уже закреплено на раме."
			else:
				applied = true
				world_object["covered"] = true
				message = "Портал закрыт плотным защитным полотном, закреплённым механическими зажимами. Это временная изоляция: портал остаётся открытым под тканью."
		&"physical_move":
			applied = true
			warning = true
			world_object["portal_open"] = false
			world_object["destroyed"] = true
			world_object["magic_level"] = 0
			world_object["damage"] = 10
			message = "Зеркало разбито. Портал исчез, но имущество уничтожено."

	return _record(employee_id, action_id, applied, warning, message)


func is_resolved() -> bool:
	return not bool(world_object["portal_open"]) or bool(world_object["covered"])


func visual_state() -> StringName:
	if bool(world_object["destroyed"]):
		return &"destroyed"
	if bool(world_object["covered"]):
		return &"covered"
	if bool(world_object["portal_open"]) and int(world_object["damage"]) > 0:
		return &"heat_damaged"
	return &"closed" if is_resolved() else &"open"


func get_completion_result() -> Dictionary:
	var destroyed := bool(world_object["destroyed"])
	var covered := bool(world_object["covered"])
	var cold_remains := bool(world_object["cold_aura"])
	if covered:
		return {
			"summary": "Портал закрыт полотном, но в комнате всё ещё холодно." if cold_remains else "Холод устранён, портал временно изолирован защитным полотном.",
			"review": "Полотно очень милое. Голоса из зеркала стали тише, а зубы всё ещё стучат в полный голос." if cold_remains else "Портал теперь под покрывалом. Не совсем ремонт, зато отражение наконец перестало спорить со мной.",
			"consequences": ["Портал только временно изолирован.", "В комнате сохранилась аномальная стужа.", "Из портала успел выбраться призрак."] if cold_remains else ["Портал временно изолирован защитным полотном.", "Из портала успел выбраться призрак."],
			"reward_adjustment": -150 if cold_remains else -80,
			"compensation_cost": 0,
			"reputation_change": -1 if cold_remains else 0,
			"follow_up": {
				"type": "escaped_ghost",
				"source_job_id": "portal_mirror",
				"cold_aura": cold_remains,
			},
			"actions": action_log.duplicate(true),
		}
	return {
		"summary": "Портал закрыт, зеркало сохранено." if not destroyed else "Портал закрыт ценой уничтоженного зеркала.",
		"review": "Наконец-то зеркало снова показывает только меня. Никогда не думала, что буду так рада обычному отражению." if not destroyed else "Портал закрыт. Зеркало тоже, причём навсегда. Придётся любоваться собой по памяти.",
		"consequences": ["Дополнительного ущерба не зафиксировано."] if not destroyed else ["Старинное зеркало уничтожено.", "Служба выплачивает компенсацию за зеркало."],
		"reward_adjustment": 0 if not destroyed else -200,
		"compensation_cost": 0 if not destroyed else 300,
		"reputation_change": 1 if not destroyed else -2,
		"actions": action_log.duplicate(true),
	}


func _record(employee_id: StringName, action_id: StringName, applied: bool, warning: bool, message: String) -> Dictionary:
	var result := {"applied": applied, "warning": warning, "message": message, "resolved": is_resolved()}
	action_log.append({"employee_id": String(employee_id), "action_id": String(action_id), "result": result.duplicate(true)})
	return result
