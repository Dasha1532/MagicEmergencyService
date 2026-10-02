class_name RepairSimulation
extends RefCounted

const ResidentReactionResolverScript := preload("res://scripts/resident_reaction_resolver.gd")
const ObjectInteractionRulesScript := preload("res://scripts/object_interaction_rules.gd")
const THERMAL_REGULATOR_DEFINITION := preload("res://data/objects/thermal_regulator.tres")
const FAUCET_DEFINITION := preload("res://data/objects/lava_faucet.tres")

const FREEZE_STEP: int = 7
const HEAT_STEP: int = 5
const FROST_THRESHOLD: int = 2
const OVERHEAT_THRESHOLD: int = 10
const MELT_THRESHOLD: int = 15

var world_object: Dictionary = {
	"instance_id": &"old_quarter_5.bathroom.lava_faucet",
	"incarnation": 1,
	"definition_id": &"lava_faucet",
	"tags": PackedStringArray(["faucet", "lava_flowing", "pressurized"]),
	"temperature": 9,
	"pressure": 8,
	"damage": 0,
	"durability": 5,
	"mass": 8,
	"anchored": true,
	"movable": true,
	"replacement_value": 350,
	"resident_voice_variant": 1,
	"resident_intro_seen": false,
	"frozen": false,
	"burning": false,
	"scorched": false,
	"broken": false,
	"replaced": false,
	"valve_position": &"closed",
	"valve_operable": true,
	"valve_broken": false,
	"valve_frozen": false,
	"flow_content": &"water",
	"incident_flow_content": &"lava",
	"flow_blocked": false,
	"cold_source_active": false,
	"cold_leak": false,
	"heat_source_active": false,
	"lava_source_active": true,
	"magic_level": 1,
	"heat_gloves_available": false,
	"replacement_faucet_available": false,
	"thermal_regulator_available": false,
	"thermal_regulator_installed": false,
	"regulator_installed": false,
	"function_test_passed": false,
	"uses_frozen_visual": true,
	"frozen_lava_flow": false,
	"visual_state": &"emergency",
}
var action_log: Array[Dictionary] = []
var job_presentation: Dictionary = {}
var last_employee_phrases: Dictionary = {}


func initialize_from_job(job: Dictionary) -> void:
	job_presentation = {
		"title": str(job.get("title", "")),
		"resident": str(job.get("resident", "Клиент")),
		"resident_request": str(job.get("resident_request", "")),
		"unresolved_message": str(job.get("unresolved_message", "")),
	}
	var instance: Dictionary = job.get("generated_instance", {}) as Dictionary
	var initial_state: Dictionary = instance.get("initial_state", {}) as Dictionary
	for property_name: Variant in initial_state:
		var value: Variant = initial_state[property_name]
		if property_name == "tags":
			world_object["tags"] = PackedStringArray(value)
		else:
			world_object[property_name] = value
	if not initial_state.has("incident_flow_content"):
		world_object["incident_flow_content"] = StringName(str(world_object.get("flow_content", "water")))
	world_object["definition_id"] = StringName(str(job.get("object_definition_id", world_object.get("definition_id", "lava_faucet"))))


func load_state(saved_state: Dictionary) -> void:
	if saved_state.is_empty():
		return
	var saved_object: Variant = saved_state.get("world_object", {})
	if saved_object is Dictionary:
		var saved_object_dictionary: Dictionary = saved_object
		var restored_object: Dictionary = saved_object_dictionary.duplicate(true)
		var restored_tags := PackedStringArray()
		for tag: Variant in restored_object.get("tags", []):
			restored_tags.append(str(tag))
		restored_object["tags"] = restored_tags
		restored_object["definition_id"] = StringName(str(restored_object.get("definition_id", "lava_faucet")))
		restored_object["visual_state"] = StringName(str(restored_object.get("visual_state", "emergency")))
		world_object.merge(restored_object, true)
		if not restored_object.has("incident_flow_content"):
			world_object["incident_flow_content"] = &"lava" if _tags().has("lava_flowing") or bool(world_object.get("lava_source_active", false)) else StringName(str(world_object.get("flow_content", "water")))
		# Миграция сохранений, созданных до появления универсальных эффектов.
		if not restored_object.has("frozen"):
			world_object["frozen"] = _tags().has("repaired")
		# Металлический кран нагревается и плавится, но не получает состояние горения.
		world_object["burning"] = false
		if not restored_object.has("scorched"):
			world_object["scorched"] = _tags().has("overheated") or _tags().has("melted") or int(world_object["damage"]) > 0
		if world_object["visual_state"] == &"overheated":
			world_object["temperature"] = maxi(OVERHEAT_THRESHOLD, int(world_object["temperature"]))
		elif world_object["visual_state"] == &"melted" or _tags().has("melted"):
			# Старые сохранения могли оставить поток активным после расплавления крана.
			_remove_tag("lava_flowing")
			_remove_tag("pressurized")
			_add_tag("sealed_by_melt")
			world_object["pressure"] = 0

	action_log.clear()
	var saved_actions: Variant = saved_state.get("action_log", [])
	if saved_actions is Array:
		for saved_action: Variant in saved_actions:
			if saved_action is Dictionary:
				var saved_action_dictionary: Dictionary = saved_action
				action_log.append(saved_action_dictionary.duplicate(true))
	last_employee_phrases.clear()
	var saved_last_phrases: Variant = saved_state.get("last_employee_phrases", {})
	if saved_last_phrases is Dictionary:
		last_employee_phrases = (saved_last_phrases as Dictionary).duplicate(true)


func get_state() -> Dictionary:
	var saved_object := world_object.duplicate(true)
	saved_object["tags"] = Array(_tags())
	return {
		"world_object": saved_object,
		"action_log": action_log.duplicate(true),
		"last_employee_phrases": last_employee_phrases.duplicate(true),
	}


func get_resident_request() -> String:
	var generated_request := str(job_presentation.get("resident_request", ""))
	if not generated_request.is_empty():
		return generated_request
	return "Остановите лаву и приведите кран в безопасное состояние. И осторожнее с ванной — сантехника здесь дорогая!"


func get_resident_message() -> String:
	return ResidentReactionResolverScript.message_for(world_object, get_resident_request(), int(world_object["resident_voice_variant"]))


func get_resident_reaction() -> String:
	# Пустая строка означает, что нового высказывания нет. Начальная просьба
	# показывается комнатой отдельно и никогда не используется как реакция.
	return ResidentReactionResolverScript.message_for(world_object, "", int(world_object["resident_voice_variant"]))


func get_status_title() -> String:
	var fallback_title := str(job_presentation.get("title", "Из крана течёт лава"))
	return ResidentReactionResolverScript.title_for(world_object, fallback_title, "Кран")


func get_unresolved_message() -> String:
	var generated_message := str(job_presentation.get("unresolved_message", ""))
	if not generated_message.is_empty():
		return generated_message
	if _tags().has("lava_flowing"):
		return "Работу нельзя завершить: лава всё ещё течёт."
	return "Работу нельзя завершить: кран находится в опасном состоянии."


func get_employee_reaction(employee_id: StringName, action_id: StringName, employee_data: Dictionary = {}) -> String:
	var frozen := bool(world_object.get("frozen", false))
	var overheated := _tags().has("overheated") or int(world_object.get("temperature", 0)) >= OVERHEAT_THRESHOLD
	var lava_flowing := _tags().has("lava_flowing")
	var gloves := bool(world_object.get("heat_gloves_available", false))
	var heat_protected := _has_contact_heat_protection(employee_data) or gloves
	if employee_id == &"liliya" and action_id == &"freeze":
		if frozen:
			return _pick_employee_phrase(PackedStringArray([
				"Ну что ж, сделаем холодное ещё холоднее. Практического смысла немного, зато иней будет образцовый.",
				"Кран уже замёрз, но добавить ему зимнего настроения я могу.",
				"Ещё немного холода — и этот кран начнёт требовать шарф. Приступаю.",
				"Заморозить замороженное? Не самый смелый научный эксперимент, но я выполню.",
				"Холоднее он станет. Полезнее — вряд ли. Но приказ есть приказ.",
			]))
		if overheated:
			return _pick_employee_phrase(PackedStringArray([
				"Охлажу постепенно. Нам нужен кран, а не коллекция металлических осколков.",
				"Охлажу постепенно. Резкий перепад может окончательно испортить металл.",
				"Добавлю холода ровно настолько, чтобы металл перестал изображать кузницу.",
				"Сейчас остудим. Главное — не превратить перегрев в промерзание.",
			]))
		if lava_flowing:
			return _pick_employee_phrase(PackedStringArray([
				"Остужу поток и перекрою лаву холодом.",
				"Заморожу лавовый поток, но буду следить, чтобы не повредить соединения.",
			]))
		return "Охлаждение здесь не связано с видимым состоянием крана. Сначала лучше провести диагностику."
	if employee_id == &"boris" and action_id == &"repair":
		if lava_flowing:
			return "Я мастер-сантехник, не кузнец. Сначала уберите лаву — потом полезу с ключом."
		if overheated:
			return _pick_employee_phrase(PackedStringArray([
				"Металл раскалён. Пока кран не остынет, я к нему не прикоснусь.",
				"Ремонтировать здесь пока нечего — сначала нужно сделать так, чтобы инструмент не плавился в руках.",
				"Сантехнику я починю. Ожоги в мою должностную инструкцию не входят.",
				"Сначала охладите кран. Потом я проверю соединения и всё восстановлю.",
			]))
		if frozen:
			return _pick_employee_phrase(PackedStringArray([
				"Сначала отогрейте механизм. Замёрзший металл хорошо ломается и плохо ремонтируется.",
				"Ключом этот лёд не снять. Зато сорвать соединение — запросто.",
				"Пока механизм промёрз, ключом к нему лучше не лезть. Сначала отогрейте вентиль.",
				"Сначала нормальная температура, потом нормальный ремонт. Порядок именно такой.",
			]))
		return "Теперь можно работать по-сантехнически: уплотнения, соединения и никаких новых стихий."
	if employee_id == &"liliya" and action_id == &"heat":
		if lava_flowing:
			return "Нагреть кран, из которого течёт лава? Уточняю: приказ точно записан без опечатки?"
		if frozen:
			return _pick_employee_phrase(PackedStringArray([
				"Отогрею постепенно. Резкие перепады оставим погоде.",
				"Сниму лёд мягким нагревом. Металл уже достаточно натерпелся.",
				"Вернём кран из зимы, не отправляя его сразу в лето.",
				"Лёд растает. Постараюсь, чтобы вместе с ним не растаяло ничего металлического.",
			]))
		if overheated:
			return _pick_employee_phrase(PackedStringArray([
				"Он уже раскалён. Дополнительный нагрев будет не ремонтом, а проверкой температуры плавления.",
				"Могу сделать горячее. Полезнее от этого кран не станет.",
				"Если задача — узнать, как выглядит расплавленный кран, метод выбран верно.",
				"Добавить огня можно. Но сначала уточню: кран нам ещё нужен?",
			]))
	if employee_id == &"grog" and action_id == &"normal_force":
		if overheated:
			return _pick_employee_phrase(PackedStringArray(["Перчатки есть. Теперь можно действовать аккуратно и без запаха жареного орка.", "Защита от жара надета. Попробую спокойно, без лишнего геройства.", "Перчатки выдержат. Проверим, выдержит ли вентиль."]))
		return _pick_employee_phrase(PackedStringArray(["Надавил аккуратно. Кран не впечатлился, зато стена цела.", "Я вполсилы попробовал. Для крана это, видимо, считается лёгким ветерком.", "Действовал осторожно. Ничего не сломалось — и, кажется, ничего не починилось.", "Кран крепкий. Или я слишком хорошо изображаю деликатность.", "Можно сильнее. Но тогда слово «ремонт» придётся писать в кавычках."]))
	if employee_id == &"grog" and action_id == &"brute_force":
		if overheated:
			return _pick_employee_phrase(PackedStringArray(["Перчатки руки защитят. Крану такой защиты не выдали.", "Жара больше не боюсь. За целость сантехники всё ещё не обещаю.", "Теперь могу взяться как следует. Отойдите от возможных деталей.", "Руки защищены. Осталось выяснить, насколько хорошо защищён сам кран."]))
		return _pick_employee_phrase(PackedStringArray(["Раз аккуратно не получилось, теперь попробуем убедительно.", "Посторонитесь. Сейчас выясним, кто здесь крепче — я или сантехника.", "Я могу сделать быстро. Насчёт целости крана ничего не обещаю."]))
	if employee_id == &"nika" and action_id == &"telekinesis":
		return _nika_valve_reaction()
	if employee_id == &"felix" and action_id == &"antimagic":
		return _felix_reaction()
	if employee_id == &"boris" and action_id == &"turn_valve" and overheated:
		if not heat_protected:
			return _pick_employee_phrase(PackedStringArray(["Металл раскалён. Пока кран не остынет, я к нему не прикоснусь.", "Сначала охладите кран. Потом я проверю соединения и всё восстановлю."]))
		return _pick_employee_phrase(PackedStringArray(["В перчатках вентиль закрыть можно. Ремонт подождёт, пока металл остынет.", "Защита есть — перекрою кран. Но раскалённые соединения разбирать всё равно не стану.", "Теперь до вентиля доберусь безопасно. Закрываю, а потом даём металлу остыть."]))
	if employee_id == &"boris" and action_id == &"install_thermal_regulator":
		if _requires_heat_protection() and not heat_protected:
			return _pick_random_phrase(PackedStringArray([
				"Без защиты я регулятор не установлю. Сначала дайте рукавицы.",
				"Прибор есть, но крепить его к раскалённому металлу голыми руками я не стану.",
				"Сначала защита для рук, потом установка. Регулятор лечит кран, а не ожоги мастера.",
			]))
		if bool(world_object.get("lava_source_active", false)):
			return _pick_random_phrase(PackedStringArray([
				"Поставлю регулятор на подачу. Если руны не врут, дальше из крана пойдёт то, что обычно называют водой.",
				"Закреплю регулятор и перенастрою поток. Лаву оставим вулканам — у них трубы привычнее.",
				"Сейчас подключу регулятор. Он должен убедить кран, что ванная — не филиал литейной.",
			]))
		var regulator_profile: Dictionary = THERMAL_REGULATOR_DEFINITION.base_properties
		var is_cold_state := bool(world_object.get("cold_source_active", false)) or bool(world_object.get("frozen", false)) or int(world_object.get("temperature", 2)) < int(regulator_profile.get("minimum_safe_temperature", 0))
		if is_cold_state:
			return _pick_random_phrase(PackedStringArray([
				"Поставлю регулятор и выровняю температуру. Лёд должен отступить вместе с источником холода.",
				"Подключу руны нагрева. Без спешки: нам нужен оттаявший кран, а не треснувший.",
				"Стабилизирую температуру и освобожу вентиль. Посмотрим, вспомнит ли он, как поворачиваться.",
			]))
		if bool(world_object.get("heat_source_active", false)) or _is_overheated():
			return _pick_random_phrase(PackedStringArray([
				"Установлю регулятор и сниму постоянный нагрев. Потом проверим, успел ли пострадать механизм.",
				"Подключу руны охлаждения. Крану пора перестать подрабатывать кузнечным горном.",
				"Сначала стабилизирую температуру, затем осмотрю соединения. Горячий металл любит скрывать последствия.",
			]))
	return {
		&"liliya": {
			&"heat": "Кран уже не течёт и не покрыт инеем. Нагрев здесь будет только новым испытанием для металла.",
		},
		&"boris": {
			&"diagnose": _diagnosis_intro(),
		},
	}.get(employee_id, {}).get(action_id, "")


func _has_contact_heat_protection(employee_data: Dictionary) -> bool:
	var protections := PackedStringArray(employee_data.get("protections", PackedStringArray()))
	return protections.has("contact_heat")


func _nika_valve_reaction() -> String:
	if bool(world_object.get("valve_broken", false)):
		return _pick_employee_phrase(PackedStringArray(["Поворачивать больше нечего. Вентиль сломан.", "Телекинез не собирает сломанные детали обратно.", "Механизм не реагирует: связь между вентилем и краном разрушена.", "Могу поднять отломанную часть, но закрыть ею кран уже не получится."]))
	if bool(world_object.get("frozen", false)) or bool(world_object.get("valve_frozen", false)):
		return _pick_employee_phrase(PackedStringArray(["Пробую повернуть вентиль. Он не двигается — лёд заблокировал механизм.", "Телекинез срабатывает, но вентиль примёрз намертво. Сильнее тянуть опасно.", "Вентиль даже не дрогнул. Записываю: сначала отогреть, потом поворачивать.", "Воздействие точное, но вентиль удерживает лёд. Сначала его нужно отогреть."]))
	if _is_overheated():
		if StringName(str(world_object.get("valve_position", "closed"))) == &"closed":
			return "Готово. Ни царапин, ни сорванной резьбы, ни повода переписывать акт."
		return _pick_employee_phrase(PackedStringArray(["Хорошая новость: руками трогать не придётся. Плохая: металл уже начал деформироваться.", "Поворачиваю осторожно. Телекинезу перчатки не нужны.", "Металл раскалён, но механизм ещё слушается. Закрываю.", "Хороший случай для дистанционной работы. И для очень длинного инструмента, которого у нас нет."]))
	if StringName(str(world_object.get("valve_position", "closed"))) == &"closed":
		return "Готово. Ни царапин, ни сорванной резьбы, ни повода переписывать акт."
	return _pick_employee_phrase(PackedStringArray(["Вентиль поворачивается свободно. Закрываю.", "Механизм исправен. Теперь кран закрыт — подробно отмечаю это в отчёте.", "Готово. Ни царапин, ни сорванной резьбы, ни повода переписывать акт.", "Закрыла. Иногда телекинез — это просто очень вежливая длинная рука."]))


func _felix_reaction() -> String:
	if int(world_object.get("magic_level", 0)) <= 0:
		return _pick_employee_phrase(PackedStringArray(["Магического фона нет. Подавлять здесь нечего.", "Антимагия против обычного льда применяется примерно так же успешно, как печать против сосульки.", "Магического фона нет. Замёрзший металл протокола не испугается."]))
	if bool(world_object.get("cold_source_active", false)):
		return _pick_employee_phrase(PackedStringArray(["Источник магического холода подавлен. Теперь лёд можно растопить — заново появляться он не будет.", "Чары сняты. Сам лёд придётся растопить или дождаться, пока он оттает.", "Магический холод нейтрализован. Осталось обычное размораживание.", "Причина устранена. Теперь тепло сможет убрать лёд окончательно."]))
	if bool(world_object.get("heat_source_active", false)):
		return _pick_employee_phrase(PackedStringArray(["Источник перегрева подавлен. Металлу всё равно потребуется время, чтобы остыть.", "Чары нейтрализованы. Прошу не касаться крана, пока температура не войдёт в допустимые пределы.", "Магическое воздействие прекращено. Физические законы снова работают без посторонней помощи.", "Причина устранена. Последствия всё ещё раскалены."]))
	return "Сниму активные чары и проверю, что магический след исчез."


func _diagnosis_intro() -> String:
	if bool(world_object.get("broken", false)) or bool(world_object.get("valve_broken", false)):
		if bool(world_object.get("cold_leak", false)) or bool(world_object.get("cold_source_active", false)):
			return "Сначала проверю сломанный корпус и выясню, откуда через повреждение продолжает выходить холод."
		return "Сначала проверю, что именно сломано и осталась ли возможность ремонта без полной замены."
	if bool(world_object.get("frozen", false)):
		return "Сначала проверю, насколько глубоко промёрз механизм и не пострадали ли соединения."
	if _tags().has("overheated") or int(world_object.get("temperature", 0)) >= OVERHEAT_THRESHOLD:
		return "Сначала выясню, что разогревает металл и насколько сильно его уже деформировало."
	if _tags().has("lava_flowing"):
		return "Проверю соединения и найду, откуда в системе появился лавовый поток."
	return "Начну с осмотра механизма и соединений."


func _pick_employee_phrase(options: PackedStringArray) -> String:
	if options.is_empty():
		return ""
	var pool_key := str(hash(options))
	var previous_phrase := str(last_employee_phrases.get(pool_key, ""))
	var selected_index := randi_range(0, options.size() - 1)
	if options.size() > 1 and options[selected_index] == previous_phrase:
		selected_index = posmod(selected_index + randi_range(1, options.size() - 1), options.size())
	var selected_phrase := options[selected_index]
	last_employee_phrases[pool_key] = selected_phrase
	return selected_phrase


func _pick_random_phrase(options: PackedStringArray) -> String:
	return _pick_employee_phrase(options)


func apply_action(employee_id: StringName, action_id: StringName, employee_data: Dictionary = {}) -> Dictionary:
	var damage_before := int(world_object.get("damage", 0))
	var destruction_before := _is_object_destroyed()
	var applied: bool = false
	var message: String = "Это действие не меняет состояние крана."
	var extra: Dictionary = {}
	match action_id:
		&"diagnose":
			message = _diagnose_faucet()
			applied = true
		&"repair":
			var repair_result: Dictionary = _apply_technical_repair()
			message = str(repair_result["message"])
			applied = bool(repair_result["applied"])
		&"freeze":
			if _tags().has("melted"):
				message = "Кран уже расплавлен: температурные воздействия больше не могут его восстановить."
			else:
				message = _apply_freeze()
				applied = true
		&"heat":
			if _tags().has("melted"):
				message = "Кран уже расплавлен: температурные воздействия больше не могут его восстановить."
			else:
				message = _apply_heat()
				applied = true
		&"telekinesis":
			var valve_result := _turn_valve(true, employee_data)
			message = str(valve_result["message"])
			applied = bool(valve_result["applied"])
		&"turn_valve":
			var valve_result := _turn_valve(false, employee_data)
			message = str(valve_result["message"])
			applied = bool(valve_result["applied"])
		&"normal_force":
			if _is_overheated() and not (_has_contact_heat_protection(employee_data) or bool(world_object.get("heat_gloves_available", false))):
				message = "Кран не сдался. Мои ладони — да."
				extra["injured"] = true
			elif _is_overheated():
				message = _pick_employee_phrase(PackedStringArray(["Вот и всё. Руки целы, перчатки целы, результат перед вами.", "Полезная вещь. Без них я бы сейчас держал не кран, а лёд для ожогов.", "Жар чувствуется, но не кусается. Можно работать."]))
			else:
				message = "Грог приложил обычную силу. Вентиль и корпус не изменили состояние."
		&"brute_force":
			if _is_overheated() and not (_has_contact_heat_protection(employee_data) or bool(world_object.get("heat_gloves_available", false))):
				message = "Сделал. Теперь мне нужен лекарь, холодная вода и день без тяжёлых предметов."
				extra["injured"] = true
			else:
				_break_faucet()
				message = _pick_employee_phrase(PackedStringArray(["Теперь он точно не сопротивляется. Правда, краном его тоже уже не назовёшь.", "Проблема с механизмом решена. Вместе с механизмом.", "Слабое место найдено. Оно было примерно везде.", "Зато теперь сразу видно, какую деталь надо заменить. Все."]))
				applied = true
		&"replace_faucet":
			var replace_result := _replace_faucet()
			message = str(replace_result["message"])
			applied = bool(replace_result["applied"])
			if applied:
				extra["consume_item_id"] = &"replacement_faucet"
		&"install_thermal_regulator":
			var regulator_result := _apply_temperature_regulator(employee_data)
			message = str(regulator_result["message"])
			applied = bool(regulator_result["applied"])
			if regulator_result.has("employee_result"):
				extra["employee_result"] = str(regulator_result["employee_result"])
			if applied:
				extra["consume_item_id"] = &"thermal_regulator"
		&"antimagic":
			var antimagic_result := _apply_antimagic()
			message = str(antimagic_result["message"])
			applied = bool(antimagic_result["applied"])

	_update_function_test()
	var result := {
		"applied": applied,
		"message": message,
		"visual_state": world_object["visual_state"],
		"resolved": is_resolved(),
	}
	result.merge(extra, true)
	result["caused_damage"] = applied and (int(world_object.get("damage", 0)) > damage_before or (not destruction_before and _is_object_destroyed()))
	action_log.append({
		"employee_id": String(employee_id),
		"action_id": String(action_id),
		"result": result.duplicate(true),
	})
	return result


func _is_object_destroyed() -> bool:
	return bool(world_object.get("broken", false)) or bool(world_object.get("valve_broken", false)) or bool(world_object.get("destroyed", false)) or _tags().has("melted") or _tags().has("destroyed") or _tags().has("broken")


func can_begin_action(action_id: StringName, employee_data: Dictionary = {}) -> bool:
	if action_id == &"repair" and _is_object_destroyed():
		return false
	if action_id == &"turn_valve" and _is_object_destroyed():
		return false
	if action_requires_heat_contact(action_id) and _requires_heat_protection() and not _has_contact_heat_protection(employee_data):
		return false
	if action_id == &"replace_faucet" and _has_active_replacement_hazard():
		return false
	if action_id != &"repair":
		return true
	if _anomaly_id() == &"faucet_freeze" and bool(world_object.get("frozen", false)):
		return false
	return not _tags().has("melted") and not _tags().has("lava_flowing") and int(world_object["temperature"]) < OVERHEAT_THRESHOLD


func can_replace_faucet() -> bool:
	return _is_object_destroyed()


func _has_active_replacement_hazard() -> bool:
	return (
		_tags().has("lava_flowing")
		or bool(world_object.get("frozen", false))
		or bool(world_object.get("cold_source_active", false))
		or bool(world_object.get("heat_source_active", false))
		or bool(world_object.get("lava_source_active", false))
	)


func action_requires_heat_contact(action_id: StringName) -> bool:
	var contact_actions := PackedStringArray(FAUCET_DEFINITION.base_properties.get("heat_contact_actions", PackedStringArray()))
	return contact_actions.has(String(action_id))


func can_employee_start_action(action_id: StringName, employee_data: Dictionary) -> bool:
	return can_begin_action(action_id, employee_data)


func can_install_temperature_regulator() -> bool:
	if bool(world_object.get("thermal_regulator_installed", false)):
		return false
	var profile: Dictionary = THERMAL_REGULATOR_DEFINITION.base_properties
	for property_name: String in PackedStringArray(profile.get("forbidden_target_properties", PackedStringArray())):
		if bool(world_object.get(property_name, false)):
			return false
	for forbidden_tag: String in PackedStringArray(profile.get("forbidden_target_tags", PackedStringArray())):
		if _tags().has(forbidden_tag):
			return false
	for property_name: String in PackedStringArray(profile.get("neutralizes_source_properties", PackedStringArray())):
		if bool(world_object.get(property_name, false)):
			return true
	for property_name: String in PackedStringArray(profile.get("stabilizes_state_properties", PackedStringArray())):
		if bool(world_object.get(property_name, false)):
			return true
	var temperature := int(world_object.get("temperature", profile.get("stabilized_temperature", 2)))
	if temperature < int(profile.get("minimum_safe_temperature", 0)) or temperature > int(profile.get("maximum_safe_temperature", 9)):
		return true
	return false


func _turn_valve(remote: bool, employee_data: Dictionary = {}) -> Dictionary:
	if bool(world_object.get("valve_broken", false)) or bool(world_object.get("broken", false)):
		return {"applied": false, "message": "Вентиль сломан и больше не управляет краном."}
	if bool(world_object.get("frozen", false)) or bool(world_object.get("valve_frozen", false)):
		return {"applied": false, "message": "Вентиль примёрз и не поворачивается. Сначала его нужно отогреть."}
	if not bool(world_object.get("valve_operable", true)):
		return {"applied": false, "message": "Механизм вентиля заклинило."}
	var hot_contact := _requires_heat_protection()
	var protected_hot_contact := hot_contact and not remote and (_has_contact_heat_protection(employee_data) or bool(world_object.get("heat_gloves_available", false)))
	if hot_contact and not remote and not protected_hot_contact:
		return {"applied": false, "message": "Металл раскалён. Без термостойких рукавиц вентиль трогать нельзя."}
	var was_open := StringName(str(world_object.get("valve_position", "closed"))) != &"closed"
	var can_open_hazardous_valves := bool(employee_data.get("can_open_hazardous_valves", false))
	if not remote and not was_open and not _can_open_water_for_test() and not can_open_hazardous_valves:
		return {"applied": false, "message": "Вентиль закрыт. Пока активная опасность не устранена, Борис не будет открывать поток."}
	world_object["valve_position"] = &"closed" if was_open else &"open"
	if was_open:
		_remove_tag("lava_flowing")
		world_object["pressure"] = 0
		if protected_hot_contact:
			return {"applied": true, "message": _pick_employee_phrase(PackedStringArray(["Вентиль закрыт. Теперь ждём, пока кран снова станет сантехникой, а не печью.", "Поток перекрыт, руки целы. Ремонт начнём после охлаждения.", "Готово. Хорошие перчатки иногда экономят больше, чем хороший страховой полис.", "Закрыл. Дальше — охлаждение и нормальная диагностика."]))}
		return {"applied": true, "message": "Вентиль закрыт. Поток остановлен."}
	if bool(world_object.get("flow_blocked", false)):
		return {"applied": true, "message": "Вентиль открыт, но поток заблокирован."}
	if bool(world_object.get("lava_source_active", false)):
		_add_tag("lava_flowing")
		world_object["flow_content"] = &"lava"
		world_object["pressure"] = 8
		return {"applied": true, "message": "Вентиль открыт. Из крана снова идёт лава."}
	world_object["flow_content"] = &"water"
	return {"applied": true, "message": "Вентиль открыт. Из крана течёт обычная вода."}


func _break_faucet() -> void:
	var releases_cold := bool(world_object.get("cold_source_active", false)) or bool(world_object.get("frozen", false))
	world_object["broken"] = true
	world_object["valve_broken"] = true
	world_object["valve_operable"] = false
	world_object["damage"] = maxi(int(world_object.get("durability", 5)), int(world_object.get("damage", 0)))
	world_object["visual_state"] = &"broken"
	world_object["cold_leak"] = releases_cold
	_add_tag("broken")
	_remove_tag("repaired")


func _replace_faucet() -> Dictionary:
	if not can_replace_faucet():
		return {"applied": false, "message": "Кран не требует полной замены."}
	if not bool(world_object.get("replacement_faucet_available", false)):
		return {"applied": false, "message": "На складе нет запасного крана."}
	if _has_active_replacement_hazard():
		if bool(world_object.get("cold_source_active", false)) or bool(world_object.get("frozen", false)):
			return {"applied": false, "message": "Сначала устраните источник холода и отогрейте кран. После этого Борис сможет приступить к замене."}
		return {"applied": false, "message": "Сначала устраните активную опасность. После этого Борис сможет приступить к замене."}
	world_object["broken"] = false
	world_object["destroyed"] = false
	world_object["replaced"] = true
	world_object["incarnation"] = int(world_object.get("incarnation", 1)) + 1
	world_object["valve_broken"] = false
	world_object["valve_operable"] = true
	world_object["valve_position"] = &"closed"
	world_object["valve_frozen"] = false
	world_object["flow_blocked"] = false
	world_object["flow_content"] = &"water"
	world_object["frozen"] = false
	world_object["frozen_lava_flow"] = false
	world_object["cold_leak"] = false
	world_object["cold_source_active"] = false
	world_object["heat_source_active"] = false
	world_object["lava_source_active"] = false
	world_object["magic_level"] = 0
	world_object["temperature"] = 2
	world_object["damage"] = 0
	world_object["scorched"] = false
	world_object["visual_state"] = &"repaired"
	_remove_tag("broken")
	_remove_tag("destroyed")
	_remove_tag("melted")
	_add_tag("repaired")
	return {"applied": true, "message": "Борис снял уничтоженный кран и установил новый. Соединения проверены, вентиль закрыт."}


func _apply_antimagic() -> Dictionary:
	if int(world_object.get("magic_level", 0)) <= 0:
		return {"applied": false, "message": "Магического фона нет. Подавлять здесь нечего."}
	world_object["magic_level"] = 0
	world_object["cold_source_active"] = false
	world_object["heat_source_active"] = false
	world_object["lava_source_active"] = false
	world_object["cold_leak"] = false
	return {"applied": true, "message": "Активная магическая причина подавлена. Физические последствия остались на месте."}


func _apply_temperature_regulator(employee_data: Dictionary = {}) -> Dictionary:
	if not bool(world_object.get("thermal_regulator_available", false)):
		return {"applied": false, "message": "Для установки нужен рунический терморегулятор со склада."}
	if not can_install_temperature_regulator() and (bool(world_object.get("broken", false)) or bool(world_object.get("destroyed", false)) or _tags().has("melted") or _tags().has("destroyed")):
		return {"applied": false, "message": "Терморегулятор нельзя установить на разрушенный кран. Сначала требуется замена оборудования."}
	if _requires_heat_protection() and not _has_contact_heat_protection(employee_data):
		return {"applied": false, "message": "Кран раскалён. Борис не сможет установить терморегулятор без экипированных термостойких рукавиц."}
	if not can_install_temperature_regulator():
		return {"applied": false, "message": "Активного источника температурной аномалии нет. Устанавливать терморегулятор не требуется."}
	var source_kind := &"heat"
	if bool(world_object.get("lava_source_active", false)):
		source_kind = &"lava"
	elif bool(world_object.get("cold_source_active", false)) or bool(world_object.get("frozen", false)) or int(world_object.get("temperature", 2)) < int(THERMAL_REGULATOR_DEFINITION.base_properties.get("minimum_safe_temperature", 0)):
		source_kind = &"cold"
	var profile: Dictionary = THERMAL_REGULATOR_DEFINITION.base_properties
	for property_name: String in PackedStringArray(profile.get("neutralizes_source_properties", PackedStringArray())):
		world_object[property_name] = false
	for property_name: String in PackedStringArray(profile.get("stabilizes_state_properties", PackedStringArray())):
		world_object[property_name] = false
	world_object["temperature"] = int(profile.get("stabilized_temperature", 2))
	world_object["flow_content"] = StringName(str(profile.get("flow_content_after_stabilization", "water")))
	world_object["magic_level"] = 0
	world_object["frozen"] = false
	world_object["frozen_lava_flow"] = false
	world_object["valve_frozen"] = false
	world_object["flow_blocked"] = false
	world_object["cold_leak"] = false
	world_object["thermal_regulator_installed"] = true
	world_object["regulator_installed"] = true
	_remove_tag("lava_flowing")
	_remove_tag("overheated")
	_remove_tag("frozen")
	_add_tag("stabilized")
	_add_tag("repaired")
	world_object["visual_state"] = &"repaired"
	var result_phrases := {
		&"lava": PackedStringArray([
			"Регулятор установлен. Источник лавы отключён, температура в норме. Теперь проверяем обычную воду.",
			"Готово. Лава закончилась, кран остыл. Можно открывать вентиль без геологических последствий.",
			"Стабилизация завершена. В трубе снова вода — скучная, прозрачная и очень уместная.",
		]),
		&"cold": PackedStringArray([
			"Регулятор установлен. Источник холода отключён, механизм оттаял.",
			"Готово. Иней исчез, вентиль снова подвижен, температура держится в норме.",
			"Кран оттаял. Регулятор не даст ему снова устроить здесь зиму.",
		]),
		&"heat": PackedStringArray([
			"Регулятор работает. Температура нормальная, источник перегрева отключён.",
			"Готово. Кран остыл и больше не нагревается сам по себе.",
			"Нагрев остановлен. Теперь это снова сантехника, а не заготовка для подковы.",
		]),
	}
	return {
		"applied": true,
		"message": "Рунический терморегулятор установлен. Активный температурный источник подавлен, температура стабилизирована, из крана снова может идти обычная вода.",
		"employee_result": _pick_random_phrase(result_phrases[source_kind]),
	}


func _is_overheated() -> bool:
	return _tags().has("overheated") or int(world_object.get("temperature", 0)) >= OVERHEAT_THRESHOLD


func _requires_heat_protection() -> bool:
	return _is_overheated() or _tags().has("lava_flowing") or bool(world_object.get("lava_source_active", false))


func _diagnose_faucet() -> String:
	if bool(world_object.get("broken", false)) or bool(world_object.get("valve_broken", false)):
		if bool(world_object.get("cold_leak", false)) or bool(world_object.get("cold_source_active", false)):
			return "Кран механически сломан, а активный магический холод выходит через повреждённый корпус. Сначала устраните источник холода, затем замените кран."
		if bool(world_object.get("frozen", false)):
			return "Кран сломан и промёрз. Сначала безопасно уберите лёд и холод, затем потребуется полная замена."
		return "Корпус и вентиль механически сломаны. Обычный ремонт не поможет — требуется полная замена крана."
	if _tags().has("melted"):
		return "Корпус крана расплавлен. Нужна полная замена, полевой ремонт невозможен."
	if _tags().has("lava_flowing"):
		return "Внутри продолжает идти лава, а корпус крана сильно нагрет. Сначала необходимо остановить поток."
	if bool(world_object.get("frozen", false)) or bool(world_object.get("valve_frozen", false)):
		if bool(world_object.get("cold_source_active", false)):
			return "Кран промёрз, вентиль заблокирован льдом, а источник магического холода всё ещё активен. Опасность не устранена."
		return "Кран и вентиль всё ещё промёрзли. Магический источник подавлен, но физический лёд необходимо безопасно убрать."
	if bool(world_object.get("cold_source_active", false)):
		return "Источник магического холода всё ещё активен. Даже без видимого льда кран может промёрзнуть снова."
	if bool(world_object.get("heat_source_active", false)) or int(world_object["temperature"]) >= OVERHEAT_THRESHOLD:
		return "Корпус крана всё ещё раскалён и продолжает деформироваться. Прикасаться к металлу пока опасно."
	if bool(world_object.get("lava_source_active", false)):
		return "Лавовая подмена всё ещё активна. Вентиль закрыт, но при открытии опасный поток возобновится."
	if int(world_object.get("magic_level", 0)) > 0:
		return "В кране сохраняется активный магический фон. Причина аварии ещё не устранена."
	if int(world_object["damage"]) > 0:
		return "Кран безопасен, но перегрев повредил соединения. Можно выполнить обычный ремонт."
	if _tags().has("repaired"):
		if _incident_involved_lava():
			return "Лавовый поток остановлен, соединения герметичны, кран исправен."
		return "Соединения герметичны, температура безопасна, кран исправен."
	return "Активной магической опасности не обнаружено. Кран можно привести в рабочее состояние обычным ремонтом."


func _apply_technical_repair() -> Dictionary:
	if _is_object_destroyed():
		return {"applied": false, "message": "Корпус крана расплавлен. Нужна полная замена, полевой ремонт невозможен." if _tags().has("melted") else "Корпус и вентиль механически сломаны. Обычный ремонт не поможет — требуется полная замена крана."}
	if _tags().has("lava_flowing"):
		return {"applied": false, "message": "Борис не стал прикасаться к крану: сначала нужно остановить поток лавы."}
	if int(world_object["temperature"]) >= OVERHEAT_THRESHOLD:
		return {"applied": false, "message": "Металл всё ещё раскалён. Борис отказывается начинать ремонт, пока кран не остынет."}
	world_object["pressure"] = 0
	world_object["damage"] = maxi(0, int(world_object["damage"]) - 2)
	world_object["scorched"] = int(world_object["damage"]) > 0
	_remove_tag("overheated")
	_add_tag("stabilized")
	_add_tag("repaired")
	world_object["visual_state"] = &"repaired"
	return {"applied": true, "message": "Борис заменил повреждённые уплотнения, подтянул соединения и восстановил кран."}


func is_resolved() -> bool:
	if bool(world_object.get("restoration_required", false)) and (not bool(world_object.get("replaced", false)) or _is_object_destroyed()):
		return false
	if bool(world_object.get("broken", false)) or bool(world_object.get("valve_broken", false)):
		return false
	if _tags().has("melted"):
		return true
	if not bool(world_object.get("function_test_passed", false)):
		return false
	if _anomaly_id() == &"lava_leak":
		return not _tags().has("lava_flowing") and not bool(world_object.get("lava_source_active", false))
	var resolution: Dictionary = world_object.get("generated_resolution", {}) as Dictionary
	if not resolution.is_empty():
		for property_name: String in resolution.get("required_false", PackedStringArray()):
			if bool(world_object.get(property_name, false)) or _tags().has(property_name):
				return false
		for property_name: String in resolution.get("required_true", PackedStringArray()):
			if not bool(world_object.get(property_name, false)) and not _tags().has(property_name):
				return false
		return true
	return _tags().has("repaired") or _tags().has("melted")


func get_completion_result(source_job_id: StringName = &"lava_leak") -> Dictionary:
	if bool(world_object.get("restoration_required", false)) and bool(world_object.get("replaced", false)):
		return {"summary": "Уничтоженный кран заменён новым. Имущество восстановлено.", "reputation_change": 0, "actions": action_log.duplicate(true)}
	if _tags().has("melted"):
		var melted_summary := "Кран полностью расплавлен и требует замены. Оплаты не будет; стоимость оборудования предъявлена службе как претензия."
		if _incident_involved_lava():
			melted_summary = "Расплавленный металл перекрыл трубу и остановил лавовый поток, но кран полностью уничтожен. Оплаты не будет; стоимость замены оборудования предъявлена службе как претензия."
		return {
			"reward_adjustment": -500,
			"forfeit_payment": true,
			"compensation_cost": int(world_object["replacement_value"]),
			"object_destroyed": true,
			"reputation_change": -6,
			"summary": melted_summary,
			"review": "От крана остался оплавленный ком металла. В следующий раз сразу скажите, что вместо ремонта оказываете услуги по сносу.",
			"consequences": ["Кран полностью уничтожен и требует замены.", "%s: предъявлена претензия на стоимость оборудования." % str(job_presentation.get("resident", "Клиент"))],
			"actions": action_log.duplicate(true),
		}
	var damage: int = int(world_object.get("damage", 0))
	var generated_completion: Dictionary = world_object.get("generated_completion", {}) as Dictionary
	if not generated_completion.is_empty() and _anomaly_id() != &"lava_leak":
		var generated_result: Dictionary = generated_completion.duplicate(true)
		generated_result["summary"] = _factual_completion_summary()
		generated_result["reward_adjustment"] = -80 * damage
		generated_result["reputation_change"] = 1 if damage == 0 else -damage
		generated_result["consequences"] = _factual_completion_consequences(damage)
		generated_result["expense_reimbursement"] = 280 if bool(world_object.get("thermal_regulator_installed", false)) else 0
		generated_result["actions"] = action_log.duplicate(true)
		return generated_result
	var summary := "Кран принят в исправном состоянии."
	var review := "Спасибо! Кран снова работает нормально и больше не представляет опасности."
	if _incident_involved_lava():
		summary = "Лавовый поток остановлен, кран принят в исправном состоянии."
		review = "Спасибо! Из крана снова не течёт лава. Для демона звучит как жалоба, но для владельца ванной — настоящее счастье."
	if damage > 0:
		summary += tr(" За дополнительный перегрев удержана компенсация за повреждение отделки.")
		review = "Лаву вы остановили — это главное. А подпалины я назову авторской отделкой, пока не увижу счёт за ремонт." if _incident_involved_lava() else "Опасность устранена, но следы дополнительного перегрева придётся ремонтировать отдельно."
	var result := {
		"reward_adjustment": -80 * damage,
		"reputation_change": 1 if damage == 0 else -damage,
		"summary": summary,
		"review": review,
		"consequences": ["Дополнительного ущерба не зафиксировано."] if damage == 0 else ["Отделка ванной повреждена дополнительным перегревом."],
		"actions": action_log.duplicate(true),
		"expense_reimbursement": 280 if bool(world_object.get("thermal_regulator_installed", false)) else 0,
	}
	if bool(world_object.get("frozen", false)):
		result["follow_up"] = {"type": "frozen_bath", "source_job_id": String(source_job_id)}
	return result


func _update_function_test() -> void:
	world_object["function_test_passed"] = (
		not bool(world_object.get("broken", false))
		and not bool(world_object.get("valve_broken", false))
		and bool(world_object.get("valve_operable", true))
		and not bool(world_object.get("frozen", false))
		and not bool(world_object.get("flow_blocked", false))
		and not bool(world_object.get("cold_source_active", false))
		and not bool(world_object.get("heat_source_active", false))
		and not bool(world_object.get("lava_source_active", false))
		and not _tags().has("lava_flowing")
		and int(world_object.get("temperature", 0)) < OVERHEAT_THRESHOLD
		and StringName(str(world_object.get("flow_content", "water"))) == &"water"
	)


func _factual_completion_summary() -> String:
	var summary := "Кран исправен, температура безопасна."
	if _anomaly_id() == &"faucet_freeze":
		summary = "Источник магического холода устранён. Кран оттаял."
	elif _anomaly_id() == &"faucet_overheat":
		summary = "Источник магического перегрева устранён. Кран остыл."
	elif _incident_involved_lava():
		summary = "Источник лавы устранён. Из крана снова течёт обычная вода."
	if bool(world_object.get("thermal_regulator_installed", false)):
		summary += " Для постоянной стабилизации температуры установлен рунический терморегулятор."
	return summary


func _factual_completion_consequences(damage: int) -> Array[String]:
	var consequences: Array[String] = []
	if bool(world_object.get("thermal_regulator_installed", false)):
		consequences.append("Терморегулятор установлен на объекте; его стоимость подлежит возмещению.")
	consequences.append("Корпус и отделка получили повреждения." if damage > 0 else "Дополнительного ущерба не зафиксировано.")
	return consequences


func _apply_freeze() -> String:
	var had_lava_flow := _tags().has("lava_flowing")
	world_object["temperature"] = mini(FROST_THRESHOLD, int(world_object["temperature"]) - FREEZE_STEP) if had_lava_flow else int(world_object["temperature"]) - FREEZE_STEP
	world_object["frozen"] = int(world_object["temperature"]) <= FROST_THRESHOLD
	world_object["valve_frozen"] = bool(world_object["frozen"])
	world_object["flow_blocked"] = bool(world_object["frozen"])
	world_object["burning"] = false
	if int(world_object["temperature"]) <= FROST_THRESHOLD and had_lava_flow:
		world_object["frozen_lava_flow"] = true
		_remove_tag("lava_flowing")
		_remove_tag("overheated")
		_add_tag("stabilized")
		_add_tag("repaired")
		world_object["pressure"] = 1
		world_object["visual_state"] = &"repaired"
		return "Лава застыла. Кран покрылся инеем и снова безопасен."
	if int(world_object["temperature"]) < OVERHEAT_THRESHOLD and _tags().has("overheated"):
		_remove_tag("overheated")
		world_object["heat_source_active"] = false
		world_object["magic_level"] = 0
		if _tags().has("lava_flowing"):
			world_object["visual_state"] = &"emergency"
			return "Кран остыл и перестал деформироваться, но поток лавы ещё не остановлен."
		_add_tag("stabilized")
		_add_tag("repaired")
		world_object["visual_state"] = &"repaired"
		return "Кран остыл и перестал деформироваться. Следы перегрева повлияют на итог работы."
	if bool(world_object["frozen"]):
		return "Температура снизилась, поверхность крана покрылась инеем."
	return "Заморозка охладила кран, но для образования инея холода пока недостаточно."


func _apply_heat() -> String:
	var was_frozen: bool = bool(world_object["frozen"])
	var restores_lava_flow := bool(world_object.get("frozen_lava_flow", false))
	if was_frozen and not restores_lava_flow:
		world_object["temperature"] = 2
		world_object["frozen"] = false
		world_object["valve_frozen"] = false
		world_object["flow_blocked"] = false
		world_object["cold_source_active"] = false
		world_object["cold_leak"] = false
		world_object["magic_level"] = 0
		_remove_tag("frozen")
		_add_tag("stabilized")
		_add_tag("repaired")
		world_object["visual_state"] = &"repaired"
		return "Управляемый нагрев растопил магический лёд. Кран оттаял, соединения остались целы."
	world_object["temperature"] = int(world_object["temperature"]) + HEAT_STEP
	world_object["frozen"] = false
	world_object["valve_frozen"] = false
	world_object["flow_blocked"] = false
	world_object["burning"] = false
	if int(world_object["temperature"]) >= MELT_THRESHOLD:
		_remove_tag("repaired")
		_remove_tag("stabilized")
		_remove_tag("overheated")
		_remove_tag("lava_flowing")
		_remove_tag("pressurized")
		_add_tag("melted")
		_add_tag("sealed_by_melt")
		world_object["pressure"] = 0
		world_object["damage"] = maxi(6, int(world_object["damage"]))
		world_object["scorched"] = true
		world_object["visual_state"] = &"melted"
		if _incident_involved_lava():
			return "Раскалённый металл не выдержал повторного нагрева: кран расплавился и полностью сломан, а спёкшийся металл перекрыл лавовый поток."
		return "Раскалённый металл не выдержал повторного нагрева: кран расплавился и полностью сломан."
	if int(world_object["temperature"]) >= OVERHEAT_THRESHOLD:
		_remove_tag("repaired")
		_remove_tag("stabilized")
		_add_tag("overheated")
		world_object["pressure"] = 10
		world_object["damage"] = int(world_object["damage"]) + 1
		world_object["scorched"] = true
		world_object["visual_state"] = &"overheated"
		return "Кран раскалился докрасна и начал деформироваться. Ещё один нагрев расплавит металл."
	if was_frozen:
		world_object["frozen_lava_flow"] = false
		_remove_tag("repaired")
		_remove_tag("stabilized")
		_add_tag("lava_flowing")
		_add_tag("pressurized")
		world_object["pressure"] = 8
		world_object["visual_state"] = &"emergency"
		return "Нагрев растопил ледяную пробку. Лава снова течёт из крана."
	return "Кран стал горячее, но металл пока сохраняет форму."


func _can_open_water_for_test() -> bool:
	return (
		StringName(str(world_object.get("flow_content", "water"))) == &"water"
		and not bool(world_object.get("flow_blocked", false))
		and not bool(world_object.get("cold_source_active", false))
		and not bool(world_object.get("heat_source_active", false))
		and not bool(world_object.get("lava_source_active", false))
		and int(world_object.get("magic_level", 0)) <= 0
		and not _tags().has("lava_flowing")
	)


func _incident_involved_lava() -> bool:
	return StringName(str(world_object.get("incident_flow_content", "water"))) == &"lava"


func _add_tag(tag: String) -> void:
	var tags := _tags()
	if not tags.has(tag):
		tags.append(tag)
	world_object["tags"] = tags


func _remove_tag(tag: String) -> void:
	var tags := _tags()
	if tags.has(tag):
		tags.remove_at(tags.find(tag))
	world_object["tags"] = tags


func _tags() -> PackedStringArray:
	return world_object["tags"]


func _anomaly_id() -> StringName:
	return StringName(str(world_object.get("generated_anomaly_id", "lava_leak")))
