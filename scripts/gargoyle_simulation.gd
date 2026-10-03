class_name GargoyleSimulation
extends RefCounted

const ObjectRules := preload("res://scripts/object_interaction_rules.gd")
const Definition := preload("res://data/objects/drain_gargoyle.tres")
const Anomaly := preload("res://data/anomalies/sleeping_drain.tres")

var world_object: Dictionary = {
	"definition_id": &"drain_gargoyle",
	"frozen_action_refusals": {"repair": "frozen_repair", "physical_move": "frozen_force", "antimagic": "ordinary_ice"},
	"awake": false,
	"clogged": true,
	"bypass_open": false,
	"damaged": false,
	"clog_removed_before_damage": false,
	"frozen": false,
	"room_frozen": false,
	"room_ice_payment_penalty": 30,
	"force_can_open_drain": true,
	"magic_level": 3,
	"damage": 0,
	"resident_intro_seen": false,
}
var action_log: Array[Dictionary] = []
var action_before: Dictionary = {}
var last_intro_employee: StringName = &""
var last_intro_action: StringName = &""
var last_intro_message: String = ""


func _init() -> void:
	world_object.merge(Definition.base_properties, true)
	world_object["instance_id"] = "tower_street_8.attic.drain_gargoyle"
	_sync_properties()


func initialize_from_job(job: Dictionary) -> void:
	var instance: Dictionary = job.get("generated_instance", {}) as Dictionary
	world_object.merge(instance.get("initial_state", {}), true)
	_sync_properties()


func _sync_properties() -> void:
	world_object["damaged"] = bool(world_object["damaged"]) or int(world_object["damage"]) >= int(world_object["durability"])
	world_object["flooding"] = not is_resolved()
	world_object["visual_state"] = visual_state()


func available_actions() -> PackedStringArray:
	var actions := PackedStringArray(["diagnose"])
	if is_terminal():
		if bool(world_object["awake"]) and not bool(world_object["damaged"]) and int(world_object["magic_level"]) > 0:
			actions.append("antimagic")
		return actions
	if not bool(world_object["bypass_open"]):
		actions.append("repair")
	if bool(world_object["clogged"]):
		actions.append("telekinesis")
	if bool(world_object["clogged"]) or bool(world_object.get("force_can_open_drain", false)):
		actions.append("physical_move")
	if not bool(world_object["frozen"]):
		actions.append("freeze")
	actions.append("heat")
	if int(world_object["magic_level"]) > 0 or bool(world_object["frozen"]):
		actions.append("antimagic")
	actions.append("animate")
	return actions


func can_begin_action(action_id: StringName) -> bool:
	return available_actions().has(String(action_id)) and not (action_id == &"repair" and bool(world_object["frozen"]))


func load_state(saved_state: Dictionary) -> void:
	var saved_object: Variant = saved_state.get("world_object", {})
	if saved_object is Dictionary:
		world_object.merge((saved_object as Dictionary).duplicate(true), true)
	action_log.clear()
	var saved_actions: Variant = saved_state.get("action_log", [])
	if saved_actions is Array:
		for saved_action: Variant in saved_actions:
			if saved_action is Dictionary:
				action_log.append((saved_action as Dictionary).duplicate(true))
	if saved_object is Dictionary and not (saved_object as Dictionary).has("room_frozen"):
		world_object["room_frozen"] = bool(world_object["frozen"])
		for entry: Dictionary in action_log:
			if str(entry.get("action_id", "")) == "freeze" and bool((entry.get("result", {}) as Dictionary).get("applied", false)):
				world_object["room_frozen"] = true
	_sync_properties()


func get_state() -> Dictionary:
	_sync_properties()
	return {"world_object": world_object.duplicate(true), "action_log": action_log.duplicate(true)}


func get_resident_request() -> String:
	return str(Anomaly.presentation["resident_request"])


func get_employee_reaction(employee_id: StringName, action_id: StringName) -> String:
	if employee_id == &"liliya" and action_id in [&"freeze", &"heat"]:
		var pool_id := "heat_without_ice" if action_id == &"heat" and not bool(world_object["frozen"]) else String(action_id)
		var pools: Dictionary = Definition.base_properties.get("action_reaction_pools", {})
		var phrase := preload("res://scripts/employee_reaction_resolver.gd").phrase_from_pool(StringName("gargoyle_liliya_" + pool_id), pools.get(pool_id, []))
		if not phrase.is_empty():
			last_intro_employee = employee_id
			last_intro_action = action_id
			last_intro_message = phrase
			return phrase
	if action_id == &"repair" and bool(world_object["frozen"]):
		return "В пасти ледяная пробка. Сначала нужно растопить лёд — прочищать замёрзший канал я не буду."
	if action_id == &"diagnose":
		if employee_id == &"nika":
			return "Посмотрю, могу ли ещё чем-нибудь помочь."
		if employee_id == &"grog":
			return "Посмотрю, есть ли здесь работа для моей силы."
		return "Осмотрю каменный корпус, канал и состояние чар."
	if action_id == &"repair" and not bool(world_object["clogged"]):
		return "Канал уже очищен. Подключу механический водоотвод."
	if action_id == &"telekinesis" and not bool(world_object["clogged"]):
		return "Листья уже убраны. Здесь больше нечего вытаскивать."
	if action_id == &"heat" and not bool(world_object["frozen"]):
		return "Льда нет. Нагрев не восстановит водоотвод."
	if action_id == &"animate" and bool(world_object["frozen"]):
		return "Попробую запустить чары и освободить пасть от ледяной пробки."
	if action_id == &"antimagic" and bool(world_object["awake"]):
		return "Погашу поддерживающие чары. Горгулья снова уснёт."
	return {
		&"boris": {
			&"diagnose": "Крепления целы, канал забит, чары спят. Обычный понедельник, только под крышей.",
			&"repair": "Сделаем обычную трубу. Она хотя бы не притворяется архитектурой.",
		},
		&"grog": {&"physical_move": "Разбудить камень могу. Насколько целым он проснётся — другой вопрос."},
		&"liliya": {
			&"freeze": "Заморозить воду можно. Но каток на чердаке в заявку, кажется, не входил.",
			&"heat": "Камень прогрею. Если она проснётся сердитой, разговаривать будете вы.",
		},
		&"nika": {&"telekinesis": "Листья вытащу. Надеюсь, горгулья не считает их своей коллекцией."},
		&"felix": {
			&"antimagic": "Чары здесь и без того едва работают. Но если приказ требует окончательной тишины — зафиксирую.",
			&"animate": "Будим горгулью. Прошу не стоять у неё перед пастью: рабочее настроение не гарантируется.",
		},
	}.get(employee_id, {}).get(action_id, "")


func get_resident_reaction(action_id: StringName) -> String:
	match action_id:
		&"animate":
			return "Проснулась! И смотрит так, будто это мы мешали ей работать. Главное — вода снова уходит."
		&"antimagic":
			return "Снова уснула? Хорошо хоть обходная труба продолжает работать." if bool(world_object["bypass_open"]) else "Она снова уснула, и вода опять течёт на чердак! Верните водоотвод в рабочее состояние."
		&"repair":
			if not bool(world_object["clogged"]):
				return "Вот теперь вода уходит как положено: листья убраны, канал восстановлен. Отличная работа вдвоём."
			return "Пусть спит, если хочет. Обходная труба работает тише неё и хотя бы не требует уговоров."
		&"physical_move":
			return "Вода ушла через трещину. Вместе с частью горгульи и моей верой в аккуратный ремонт."
		&"freeze":
			return "Теперь у нас не потоп, а каток на чердаке. Не уверена, что это улучшение."
	return ""


func apply_action(employee_id: StringName, action_id: StringName) -> Dictionary:
	action_before = {String(world_object["instance_id"]): world_object.duplicate(true)}
	var refusal := ObjectRules.refusal_reason(action_id, world_object)
	if not refusal.is_empty():
		return _record(employee_id, action_id, false, true, preload("res://scripts/employee_reaction_resolver.gd").refusal_for(refusal))
	var applied := false
	var warning := false
	var message := "Действие не изменило состояние водостока."
	if bool(world_object["damaged"]) and action_id != &"diagnose":
		return _record(employee_id, action_id, false, true, "Горгулья уже повреждена. Вода уходит через образовавшийся пролом; дополнительные действия не требуются.")
	if bool(world_object["awake"]) and action_id not in [&"diagnose", &"antimagic"]:
		return _record(employee_id, action_id, false, true, "Горгулья уже оживлена и исправно отводит воду. Дополнительные действия не требуются.")

	match action_id:
		&"diagnose":
			applied = true
			if employee_id == &"nika":
				var replies := ["Листья я убрала. Дальше нужно восстановить сам водоотвод — телекинез здесь не поможет", "Засора больше нет. Остальное моими умениями не исправить", "Здесь я больше ничего сделать не могу. Нужен другой специалист"]
				return _record(employee_id, action_id, true, false, str(replies[randi() % replies.size()]))
			if employee_id == &"felix":
				message = "Снимать больше нечего: чары погашены. Для восстановления водоотвода нужен другой подход." if int(world_object["magic_level"]) == 0 else "Чары здесь спят. Антимагия может их погасить, но не восстановит водоотвод."
				if bool(world_object["awake"]):
					message = "Горгулья оживлена, поддерживающие чары активны. Антимагия усыпит её снова."
				if bool(world_object["frozen"]):
					message += " Лёд нужно убрать отдельно."
				return _record(employee_id, action_id, true, false, message)
			if employee_id == &"grog":
				message = "Засор можно выбить, но камень при этом расколется. Лучше обойтись без удара." if bool(world_object["clogged"]) and not is_terminal() else "Здесь силой уже ничего не исправить. Каменный корпус лучше не трогать."
				return _record(employee_id, action_id, applied, false, message)
			if bool(world_object["damaged"]):
				message = "Каменный корпус расколот, но вода уходит через образовавшийся пролом. Потребуется замена крепления и реставрация."
			elif bool(world_object["awake"]):
				message = "Горгулья активна, засор удалён, водосточный канал работает штатно."
			else:
				var facts: Array[String] = []
				facts.append("Камень получил повреждения." if int(world_object["damage"]) > 0 else "Крепления и корпус целы.")
				facts.append("Канал забит листьями." if bool(world_object["clogged"]) else "Листья убраны, канал свободен.")
				if bool(world_object["frozen"]):
					facts.append("В пасти ледяная пробка.")
				facts.append("Механический обход работает." if bool(world_object["bypass_open"]) else "Чары не поддерживают водоотвод. Нужен запуск чар или механический обход.")
				message = " ".join(facts)
		&"animate":
			var had_clog := bool(world_object["clogged"])
			var had_ice := bool(world_object["frozen"])
			applied = true
			world_object["awake"] = true
			world_object["clogged"] = false
			world_object["frozen"] = false
			world_object["magic_level"] = 8
			message = "Оживление разбудило горгулью. Она выплюнула засор и снова направила дождевую воду в трубу." if had_clog else "Оживление разбудило уже очищенную горгулью. Она снова направила дождевую воду в трубу."
			if had_ice:
				message = "Горгулья ожила, выплюнула лёд вместе с листьями и снова направила воду в трубу." if had_clog else "Горгулья ожила, выплюнула ледяную пробку и снова направила воду в трубу."
				message += " Лёд на чердаке остался."
		&"repair":
			if bool(world_object["frozen"]):
				return _record(employee_id, action_id, false, true, "В пасти ледяная пробка. Сначала нужно растопить лёд — прочищать замёрзший канал я не буду.")
			applied = true
			if bool(world_object["bypass_open"]):
				return _record(employee_id, action_id, false, false, "Механический обход уже работает.")
			world_object["bypass_open"] = true
			if bool(world_object["clogged"]):
				message = "Борис прочистил боковой канал и открыл механический обход. Вода уходит, хотя горгулья продолжает спать."
			else:
				message = "Очищенный основной канал подключён к механическому водоотводу."
		&"physical_move":
			applied = true
			warning = true
			world_object["clog_removed_before_damage"] = not bool(world_object["clogged"])
			world_object["damaged"] = true
			world_object["clogged"] = false
			world_object["damage"] = 8
			message = "Силовой удар расколол каменную пасть. Вода уходит через пролом, но горгулья серьёзно повреждена."
		&"telekinesis":
			if not bool(world_object["clogged"]):
				return _record(employee_id, action_id, false, false, "Листья уже убраны, повторная очистка не требуется.")
			applied = true
			world_object["clogged"] = false
			message = "Телекинез вытащил листья. Механический водоотвод теперь работает без засора." if bool(world_object["bypass_open"]) else "Телекинез вытащил листья, но спящая горгулья не направляет воду в трубу. Нужен запуск чар или механический обход."
		&"antimagic":
			applied = true
			warning = true
			var was_awake := bool(world_object["awake"])
			world_object["awake"] = false
			world_object["magic_level"] = 0
			if bool(world_object["bypass_open"]):
				message = "Чары погашены, но механический обход продолжает отводить воду."
			elif was_awake:
				message = "Антимагия погасила поддерживающие чары. Горгулья снова уснула, и вода опять поступает на чердак."
			else:
				message = "Антимагия окончательно заглушила поддерживающие чары. Горгулья не проснулась, вода продолжает поступать на чердак."
		&"freeze":
			if bool(world_object["frozen"]):
				return _record(employee_id, action_id, false, true, "Вода уже замёрзла. Дополнительная заморозка не требуется.")
			applied = true
			warning = true
			world_object["awake"] = false
			world_object["frozen"] = true
			world_object["room_frozen"] = true
			world_object["damage"] = int(world_object["damage"]) + 1
			message = "Вода в пасти замёрзла. Поток временно остановлен, но ледяная пробка давит на старый камень."
		&"heat":
			if not bool(world_object["frozen"]):
				var no_ice_message := last_intro_message if last_intro_employee == employee_id and last_intro_action == action_id and not last_intro_message.is_empty() else "Льда нет. Нагрев не восстановит водоотвод."
				return _record(employee_id, action_id, false, false, no_ice_message)
			applied = true
			world_object["frozen"] = false
			message = "Нагрев растопил лёд. Механический водоотвод снова работает." if bool(world_object["bypass_open"]) else "Нагрев растопил лёд и подсушил камень, но не разбудил горгулью и не восстановил водоотвод."

	return _record(employee_id, action_id, applied, warning, message)


func is_resolved() -> bool:
	if bool(world_object["damaged"]):
		return true
	return not bool(world_object["frozen"]) and (bool(world_object["awake"]) and not bool(world_object["clogged"]) or bool(world_object["bypass_open"]))


func is_terminal() -> bool:
	return bool(world_object["damaged"]) or bool(world_object["awake"])


func visual_state() -> StringName:
	if bool(world_object["damaged"]):
		return &"damaged_clean" if bool(world_object["clog_removed_before_damage"]) else &"damaged"
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
	if not is_resolved():
		return {}
	var result := _completion_from_properties()
	if result.is_empty():
		return result
	if bool(world_object.get("room_frozen", false)):
		result["consequences"].append("На чердаке остался лёд; восстановление водоотвода его не растопило.")
		result["summary"] = str(result["summary"]) + " На чердаке остался лёд."
		if not bool(result.get("forfeit_payment", false)):
			var ice_penalty := int(world_object.get("room_ice_payment_penalty", 30))
			result["reward_adjustment"] = int(result["reward_adjustment"]) - ice_penalty
			result["summary"] += " За оставшийся лёд из оплаты удержано %d монет." % ice_penalty
	var helpful_ids := PackedStringArray()
	for entry: Dictionary in action_log:
		for change: Dictionary in entry.get("object_changes", []):
			var before: Dictionary = change.get("before", {})
			var after: Dictionary = change.get("after", {})
			var useful := (bool(before.get("clogged", false)) and not bool(after.get("clogged", false))) or (not bool(before.get("bypass_open", false)) and bool(after.get("bypass_open", false))) or (not bool(before.get("awake", false)) and bool(after.get("awake", false)))
			var emp_id := str(entry.get("employee_id", ""))
			if useful and not bool((entry.get("result", {}) as Dictionary).get("caused_damage", false)) and not emp_id.is_empty() and not helpful_ids.has(emp_id):
				helpful_ids.append(emp_id)
	result["successful_employee_ids"] = Array(helpful_ids) if is_resolved() else []
	if int(world_object["damage"]) > 0 and not bool(world_object["damaged"]):
		result["summary"] = str(result["summary"]) + " На каменном корпусе остались повреждения после заморозки."
		result["consequences"] = (result["consequences"] as Array).filter(func(text: String) -> bool: return "без повреждений" not in text and "ущерба не зафиксировано" not in text)
		result["consequences"].append("Камень повреждён давлением ледяной пробки.")
		result["review"] = "Водоотвод восстановили, но на камне остались повреждения после заморозки. Рассчитывала на более аккуратную работу."
		result["reputation_change"] = -int(world_object["damage"])
		result["reward_adjustment"] = int(result["reward_adjustment"]) - int(world_object["damage"]) * int(world_object.get("damage_payment_penalty", 20))
	return result


func _completion_from_properties() -> Dictionary:
	if bool(world_object["damaged"]):
		return {
			"summary": "Водоотвод восстановлен через пролом в повреждённой горгулье.",
			"review": "Потоп остановили. Горгулью тоже — теперь она состоит из нескольких очень спокойных частей.",
			"consequences": ["Каменная горгулья серьёзно повреждена.", "Требуется реставрация крепления и корпуса.", "Ущерб общедомовому имуществу предъявлен службе как претензия."],
			"reward_adjustment": -120,
			"forfeit_payment": true,
			"compensation_cost": int(world_object["compensation_value"]),
			"reputation_change": -2,
			"actions": action_log.duplicate(true),
		}
	if bool(world_object["awake"]):
		return {
			"summary": "Горгулья пробуждена и снова работает как штатный водосток.",
			"review": "Горгулья снова отводит воду. Если бы ещё научили её не ворчать на дождь, я бы поставила шестую звезду.",
			"consequences": ["Засор удалён.", "Магический водосток полностью восстановлен.", "Дополнительного ущерба не зафиксировано."],
			"reward_adjustment": 0,
			"compensation_cost": 0,
			"reputation_change": 1,
			"actions": action_log.duplicate(true),
		}
	if bool(world_object["bypass_open"]):
		if not bool(world_object["clogged"]):
			return {
				"summary": "Засор удалён, основной канал очищен и подключён к исправному механическому водоотводу.",
				"review": "Листья убрали, канал наладили — вода снова уходит как положено. Горгулья может спокойно досмотреть свой каменный сон.",
				"consequences": ["Засор удалён без повреждений.", "Водоотвод полностью восстановлен совместной работой бригады.", "Дополнительного ущерба не зафиксировано."],
				"reward_adjustment": 0,
				"compensation_cost": 0,
				"reputation_change": 1,
				"actions": action_log.duplicate(true),
			}
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
	_sync_properties()
	var result := {"applied": applied, "warning": warning, "message": message, "resolved": is_resolved()}
	action_log.append(ObjectRules.action_event(employee_id, action_id, action_before, {String(world_object["instance_id"]): world_object.duplicate(true)}, result))
	return result
