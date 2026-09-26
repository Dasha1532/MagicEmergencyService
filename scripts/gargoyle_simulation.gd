class_name GargoyleSimulation
extends RefCounted

var world_object: Dictionary = {
	"definition_id": &"drain_gargoyle",
	"awake": false,
	"clogged": true,
	"bypass_open": false,
	"damaged": false,
	"frozen": false,
	"magic_level": 3,
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
	return "Горгулья уснула прямо во время ливня. На чердаке уже можно разводить уток — разбудите её или хотя бы отведите воду."


func get_resident_reaction(action_id: StringName) -> String:
	match action_id:
		&"animate":
			return "Проснулась! И смотрит так, будто это мы мешали ей работать. Главное — вода снова уходит."
		&"repair":
			return "Пусть спит, если хочет. Обходная труба работает тише неё и хотя бы не требует уговоров."
		&"physical_move":
			return "Вода ушла через трещину. Вместе с частью горгульи и моей верой в аккуратный ремонт."
		&"freeze":
			return "Теперь у нас не потоп, а каток на чердаке. Не уверена, что это улучшение."
	return ""


func apply_action(employee_id: StringName, action_id: StringName) -> Dictionary:
	var applied := false
	var warning := false
	var message := "Действие не изменило состояние водостока."
	if bool(world_object["damaged"]):
		return _record(employee_id, action_id, false, true, "Горгулья уже повреждена. Вода уходит через образовавшийся пролом; дополнительные действия не требуются.")
	if bool(world_object["awake"]):
		return _record(employee_id, action_id, false, true, "Горгулья уже оживлена и исправно отводит воду. Дополнительные действия не требуются.")

	match action_id:
		&"diagnose":
			applied = true
			if bool(world_object["damaged"]):
				message = "Каменный корпус расколот, но вода уходит через образовавшийся пролом. Потребуется замена крепления и реставрация."
			elif bool(world_object["awake"]):
				message = "Горгулья активна, засор удалён, водосточный канал работает штатно."
			else:
				message = "Крепления целы. Канал забит листьями, а поддерживающие чары спят. Горгулью можно оживить или открыть механический обход."
		&"animate":
			applied = true
			world_object["awake"] = true
			world_object["clogged"] = false
			world_object["frozen"] = false
			world_object["magic_level"] = 8
			message = "Оживление разбудило горгулью. Она выплюнула засор и снова направила дождевую воду в трубу."
		&"repair":
			applied = true
			world_object["bypass_open"] = true
			world_object["frozen"] = false
			message = "Борис прочистил боковой канал и открыл механический обход. Вода уходит, хотя горгулья продолжает спать."
		&"physical_move":
			applied = true
			warning = true
			world_object["damaged"] = true
			world_object["clogged"] = false
			world_object["damage"] = 8
			message = "Силовой удар расколол каменную пасть. Вода уходит через пролом, но горгулья серьёзно повреждена."
		&"telekinesis":
			applied = true
			world_object["clogged"] = false
			message = "Телекинез вытащил листья, но спящая горгулья не направляет воду в трубу. Нужен запуск чар или механический обход."
		&"antimagic":
			applied = true
			warning = true
			var was_awake := bool(world_object["awake"])
			world_object["awake"] = false
			world_object["magic_level"] = 0
			if was_awake:
				message = "Антимагия погасила поддерживающие чары. Горгулья снова уснула, и вода опять поступает на чердак."
			else:
				message = "Антимагия окончательно заглушила поддерживающие чары. Горгулья не проснулась, вода продолжает поступать на чердак."
		&"freeze":
			applied = true
			warning = true
			world_object["awake"] = false
			world_object["frozen"] = true
			world_object["damage"] = int(world_object["damage"]) + 1
			message = "Вода в пасти замёрзла. Поток временно остановлен, но ледяная пробка давит на старый камень."
		&"heat":
			applied = true
			world_object["frozen"] = false
			message = "Нагрев растопил лёд и подсушил камень, но не разбудил горгулью и не восстановил водоотвод."

	return _record(employee_id, action_id, applied, warning, message)


func is_resolved() -> bool:
	if bool(world_object["damaged"]):
		return true
	return not bool(world_object["frozen"]) and (bool(world_object["awake"]) or bool(world_object["bypass_open"]))


func is_terminal() -> bool:
	return bool(world_object["damaged"]) or bool(world_object["awake"])


func visual_state() -> StringName:
	if bool(world_object["damaged"]):
		return &"damaged"
	if bool(world_object["frozen"]):
		return &"frozen"
	if not bool(world_object["clogged"]):
		return &"awakened" if bool(world_object["awake"]) else &"dormant_clean"
	return &"awakened" if bool(world_object["awake"]) else &"dormant"


func flooding_state() -> StringName:
	if is_resolved():
		return &"none"
	return &"frozen" if bool(world_object["frozen"]) else &"water"


func get_completion_result() -> Dictionary:
	if bool(world_object["damaged"]):
		return {
			"summary": "Водоотвод восстановлен через пролом в повреждённой горгулье.",
			"review": "Потоп остановили. Горгулью тоже — теперь она состоит из нескольких очень спокойных частей.",
			"consequences": ["Каменная горгулья серьёзно повреждена.", "Требуется реставрация крепления и корпуса.", "Ущерб общедомовому имуществу предъявлен службе как претензия."],
			"reward_adjustment": -120,
			"compensation_cost": 220,
			"reputation_change": -2,
			"actions": action_log.duplicate(true),
		}
	if bool(world_object["awake"]):
		return {
			"summary": "Горгулья пробуждена и снова работает как штатный водосток.",
			"review": "Разбудили с первого раза. Если бы ещё научили её не ворчать на дождь, я бы поставила шестую звезду.",
			"consequences": ["Засор удалён.", "Магический водосток полностью восстановлен.", "Дополнительного ущерба не зафиксировано."],
			"reward_adjustment": 0,
			"compensation_cost": 0,
			"reputation_change": 1,
			"actions": action_log.duplicate(true),
		}
	if bool(world_object["bypass_open"]):
		return {
			"summary": "Открыт механический обходной водосток; чердак больше не затапливает.",
			"review": "Горгулья всё ещё спит, зато новая труба трудится без жалоб и перерывов на мистический сон.",
			"consequences": ["Вода отведена через механический обход.", "Горгулья осталась неактивной и потребует отдельного обслуживания чар."],
			"reward_adjustment": -60,
			"compensation_cost": 0,
			"reputation_change": 0,
			"actions": action_log.duplicate(true),
		}
	return {}


func _record(employee_id: StringName, action_id: StringName, applied: bool, warning: bool, message: String) -> Dictionary:
	var result := {"applied": applied, "warning": warning, "message": message, "resolved": is_resolved()}
	action_log.append({"employee_id": String(employee_id), "action_id": String(action_id), "result": result.duplicate(true)})
	return result
