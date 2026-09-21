extends Node

signal state_changed

const STARTING_EMPLOYEES: PackedStringArray = ["liliya", "grog", "boris"]
const EMPLOYEE_ORDER: PackedStringArray = ["liliya", "grog", "boris", "nika", "felix"]
const SAVE_VERSION: int = 5
const SAVE_PATH: String = "user://savegame.json"
const SUPPLY_ITEMS: Dictionary = {
	&"animation_kit": {
		"name": "Практическое оживление бытовых предметов",
		"category": "Учебный комплект",
		"price": 400,
		"icon": "res://assets/icons/tools/tool_animate.png",
		"description": "Служебное руководство, учебный кристалл и набор безопасных печатей. Открывает однодневный курс «Оживление» для совместимого сотрудника.",
		"training_id": "animate",
	},
}
const TRAINING_DEFINITIONS: Dictionary = {
	&"animate": {
		"name": "Оживление",
		"supply_item_id": &"animation_kit",
		"category": &"magic",
		"duration_days": 1,
	},
}

var day: int = 1
var time_minutes: int = 9 * 60
var money: int = 600
var reputation: int = 37
var selected_job_id: StringName = &"lava_leak"
var active_job_id: StringName = &""
var owned_supply_items: PackedStringArray = PackedStringArray()
var completed_job_ids: PackedStringArray = PackedStringArray()
var job_reports: Array = []
var pending_job_report: Dictionary = {}
var job_repair_states: Dictionary = {}

var employees: Dictionary = {
	&"liliya": {
		"name": "Лилия Морозова",
		"role": "Маг-практик",
		"portrait": "res://assets/portraits/employees/liliya.png",
		"actor_neutral_pose": "res://assets/characters/employees/liliya/full_body.png",
		"actor_work_pose": "res://assets/characters/employees/liliya/cast_pose.png",
		"actor_action_style": &"magic",
		"actor_action_origin": Vector2(350, 180),
		"actor_work_pose_offset": Vector2(-36, -8),
		"status": "Свободна",
		"idle_status": "Свободна",
		"abilities": PackedStringArray(["freeze", "heat"]),
		"training_categories": PackedStringArray(["magic"]),
		"max_special_abilities": 2,
		"core_actions": "Заморозка и магия огня",
		"description": "Полевой маг широкого профиля. Определяет природу чар и аккуратно меняет температуру повреждённых объектов.",
		"strength": "Сильная сторона: диагностика и контроль стихий",
		"weakness": "Ограничение: силовой ремонт требует напарника",
		"traits": "Наблюдательна • осторожна • любит точные формулировки",
		"action_reactions": [
			{"action_ids": ["heat"], "object_equals": {"burning": true}, "text": "Возражаю: нагрев усилит пожар."},
			{"action_ids": ["freeze"], "object_equals": {"burning": true}, "text": "Потушу холодом, но древесина станет хрупкой."},
		],
		"available": true,
	},
	&"grog": {
		"name": "Грог Кувалда",
		"role": "Орк-такелажник",
		"portrait": "res://assets/portraits/employees/grog.png",
		"actor_neutral_pose": "res://assets/characters/employees/grog/full_body.png",
		"actor_work_pose": "res://assets/characters/employees/grog/work_pose.png",
		"actor_walk_pose": "res://assets/characters/employees/grog/walk_pose.png",
		"actor_hold_pose": "res://assets/characters/employees/grog/hold_pose.png",
		"actor_action_style": &"physical",
		"actor_work_pose_offset": Vector2.ZERO,
		"status": "Свободен",
		"idle_status": "Свободен",
		"abilities": PackedStringArray(["physical_move"]),
		"training_categories": PackedStringArray(["physical"]),
		"max_special_abilities": 2,
		"core_actions": "Удержание и силовая работа",
		"description": "Такелажник для случаев, когда аварийный объект нужно удержать, передвинуть или убедительно поставить на место.",
		"strength": "Сильная сторона: сила и устойчивость",
		"weakness": "Ограничение: тонкая магия — не его участок",
		"traits": "Надёжен • терпелив • бережёт казённый инструмент",
		"available": true,
	},
	&"boris": {
		"name": "Борис Медяк",
		"role": "Мастер-сантехник",
		"portrait": "res://assets/portraits/employees/boris.png",
		"actor_neutral_pose": "res://assets/characters/employees/boris/full_body.png",
		"actor_walk_pose": "res://assets/characters/employees/boris/walk_pose.png",
		"actor_work_pose": "res://assets/characters/employees/boris/work_pose.png",
		"actor_action_style": &"physical",
		"status": "Свободен",
		"idle_status": "Свободен",
		"abilities": PackedStringArray(["diagnose", "repair"]),
		"training_categories": PackedStringArray(["technical"]),
		"max_special_abilities": 2,
		"core_actions": "Диагностика и точный ремонт",
		"description": "Опытный мастер по трубам, кранам и прочей инфраструктуре, которая обычно течёт в самый неподходящий момент.",
		"strength": "Сильная сторона: аккуратный обычный ремонт",
		"weakness": "Ограничение: не работает с чарами напрямую",
		"traits": "Практичен • экономен • не доверяет говорящим вентилям",
		"action_reactions": [
			{"action_ids": ["repair", "anchor"], "object_equals": {"burning": true}, "text": "Горящее не ремонтируют. Сначала тушим."},
			{"action_ids": ["repair"], "required_tags": ["lava_flowing"], "text": "Сначала остановите поток лавы."},
		],
		"available": true,
	},
	&"nika": {
		"name": "Ника Искра",
		"role": "Маг-телекинетик",
		"portrait": "res://assets/portraits/employees/nika.png",
		"portrait_region": Rect2(0, 0, 1254, 1254),
		"actor_neutral_pose": "res://assets/characters/employees/nika/full_body.png",
		"actor_work_pose": "res://assets/characters/employees/nika/telekinesis_pose.png",
		"actor_action_style": &"magic",
		"actor_action_origin": Vector2(166, 151),
		"actor_action_origin_from_data": true,
		"status": "Не нанята",
		"idle_status": "Свободна",
		"hire_cost": 350,
		"abilities": PackedStringArray(["telekinesis"]),
		"training_categories": PackedStringArray(["magic", "technical"]),
		"max_special_abilities": 2,
		"core_actions": "Дистанционный телекинез",
		"description": "Маг-телекинетик. Аккуратно перемещает незакреплённые объекты на расстоянии и быстро осваивает новые инструменты.",
		"strength": "Сильная сторона: дистанционное и бережное перемещение",
		"weakness": "Ограничение: мало полевого опыта",
		"traits": "Любознательна • энергична • ведёт слишком подробные записи",
		"action_reactions": [
			{"action_ids": ["telekinesis"], "object_equals": {"destroyed": true}, "text": "Перемещать уже нечего."},
			{"action_ids": ["telekinesis"], "object_equals": {"anchored": true}, "text": "Объект закреплён. Тянуть опасно."},
		],
		"available": false,
	},
	&"felix": {
		"name": "Феликс Пепельный",
		"role": "Магический инспектор",
		"portrait": "res://assets/portraits/employees/felix.png",
		"actor_neutral_pose": "res://assets/characters/employees/felix/full_body.png",
		"actor_work_pose": "res://assets/characters/employees/felix/antimagic_pose.png",
		"actor_action_style": &"magic",
		"actor_action_origin": Vector2(145, 145),
		"actor_action_origin_from_data": true,
		"status": "Не нанят",
		"idle_status": "Свободен",
		"hire_cost": 650,
		"abilities": PackedStringArray(["antimagic"]),
		"training_categories": PackedStringArray(["magic"]),
		"incompatible_abilities": PackedStringArray(["animate"]),
		"max_special_abilities": 2,
		"core_actions": "Магическая изоляция",
		"description": "Инспектор по нестабильным чарам. Локализует магические утечки и проверяет объект перед ремонтом.",
		"strength": "Сильная сторона: антимагия и безопасность",
		"weakness": "Ограничение: действует медленно и по инструкции",
		"traits": "Методичен • невозмутим • замечает нарушения с порога",
		"action_reactions": [
			{"action_ids": ["antimagic"], "object_equals": {"destroyed": true}, "text": "Подавлять уже нечего. Оформляю акт."},
			{"action_ids": ["antimagic"], "object_equals": {"burning": true}, "text": "Возражаю: антимагия пожар не тушит."},
			{"action_ids": ["antimagic"], "object_max": {"magic_level": 0}, "text": "Магического фона нет."},
			{"action_ids": ["antimagic"], "text": "Подавление чар — не ремонт."},
		],
		"available": false,
	},
}

var jobs: Dictionary = {
	&"lava_leak": {
		"title": "Из крана течёт лава",
		"objective": "Остановить лаву из крана",
		"address": "Старый квартал, 5",
		"resident": "Господин Рагнар",
		"resident_portrait": "res://assets/portraits/residents/ragnar.png",
		"description": "В ванной демона из трубы идёт лава. Поток усиливается, а старая медная труба уже нагрелась.",
		"urgency": "Срочно",
		"time_left": 95,
		"danger": "Огонь • давление",
		"base_reward": 500,
		"repair_scene": "res://scenes/RepairHouse.tscn",
		"assigned": PackedStringArray(),
	},
	&"walking_wardrobe": {
		"title": "Шкаф ходит по квартире",
		"objective": "Остановить шкаф и поставить к левой стене",
		"address": "Старый квартал, 5",
		"resident": "Госпожа Элеонора",
		"resident_portrait": "res://assets/portraits/residents/eleonora.png",
		"description": "Зачарованный шкаф ходит по комнатам, гремит хрупкой посудой и не позволяет хозяйке открыть входную дверь.",
		"urgency": "Важно",
		"time_left": 180,
		"danger": "Магия • шум",
		"base_reward": 420,
		"repair_scene": "res://scenes/WardrobeRoom.tscn",
		"assigned": PackedStringArray(),
	},
	&"portal_mirror": {
		"title": "В зеркале открылся портал",
		"objective": "Закрыть портал в зеркале",
		"address": "Верхний город, 12",
		"resident": "Госпожа Селеста",
		"resident_portrait": "",
		"description": "Старинное зеркало превратилось в нестабильный портал. Из отражения доносятся голоса, а магическое поле в комнате усиливается.",
		"urgency": "Срочно",
		"time_left": 120,
		"danger": "Магия • портал",
		"base_reward": 600,
		"repair_scene": "res://scenes/PortalMirrorHouse.tscn",
		"assigned": PackedStringArray(),
	},
}


func assign_employee(employee_id: StringName, job_id: StringName) -> void:
	if not employees.has(employee_id) or not jobs.has(job_id):
		return
	if not employees[employee_id]["available"]:
		return
	if is_employee_training(employee_id):
		return

	var current_job := get_employee_job(employee_id)
	if current_job == job_id:
		var selected_job: Dictionary = jobs[job_id]
		var selected_assigned: PackedStringArray = selected_job["assigned"]
		selected_assigned.remove_at(selected_assigned.find(String(employee_id)))
		selected_job["assigned"] = selected_assigned
		jobs[job_id] = selected_job
	else:
		_remove_employee_from_all_jobs(employee_id)
		var target_job: Dictionary = jobs[job_id]
		var target_assigned: PackedStringArray = target_job["assigned"]
		target_assigned.append(String(employee_id))
		target_job["assigned"] = target_assigned
		jobs[job_id] = target_job

	_update_employee_statuses()
	state_changed.emit()


func hire_employee(employee_id: StringName) -> bool:
	if not employees.has(employee_id):
		return false
	var employee: Dictionary = employees[employee_id]
	if employee["available"]:
		return false
	var hire_cost := int(employee.get("hire_cost", 0))
	if hire_cost <= 0 or money < hire_cost:
		return false
	money -= hire_cost
	employee["available"] = true
	employee["status"] = employee["idle_status"]
	employees[employee_id] = employee
	state_changed.emit()
	return true


func buy_supply_item(item_id: StringName) -> bool:
	if not SUPPLY_ITEMS.has(item_id) or owned_supply_items.has(String(item_id)):
		return false
	var item: Dictionary = SUPPLY_ITEMS[item_id]
	var price := int(item["price"])
	if price <= 0 or money < price:
		return false
	money -= price
	owned_supply_items.append(String(item_id))
	state_changed.emit()
	return true


func has_supply_item(item_id: StringName) -> bool:
	return owned_supply_items.has(String(item_id))


func grant_debug_money(amount: int = 500) -> void:
	if not OS.is_debug_build() or amount <= 0:
		return
	money += amount
	state_changed.emit()


func advance_day(days: int = 1) -> void:
	if days <= 0:
		return
	day += days
	time_minutes = 9 * 60
	_complete_finished_training()
	_update_employee_statuses()
	state_changed.emit()


func is_employee_training(employee_id: StringName) -> bool:
	if not employees.has(employee_id):
		return false
	var employee: Dictionary = employees[employee_id]
	return not StringName(str(employee.get("training_id", ""))).is_empty()


func get_training_availability(employee_id: StringName, training_id: StringName) -> StringName:
	if not employees.has(employee_id) or not TRAINING_DEFINITIONS.has(training_id):
		return &"unknown"
	var employee: Dictionary = employees[employee_id]
	var training: Dictionary = TRAINING_DEFINITIONS[training_id]
	if not bool(employee["available"]):
		return &"not_hired"
	if is_employee_training(employee_id):
		return &"training"
	var abilities: PackedStringArray = employee["abilities"]
	if abilities.has(String(training_id)):
		return &"learned"
	var incompatible: PackedStringArray = employee.get("incompatible_abilities", PackedStringArray())
	if incompatible.has(String(training_id)):
		return &"incompatible"
	var categories: PackedStringArray = employee.get("training_categories", PackedStringArray())
	if not categories.has(String(training["category"])):
		return &"incompatible"
	if abilities.size() >= int(employee.get("max_special_abilities", 2)):
		return &"no_slots"
	if not get_employee_job(employee_id).is_empty():
		return &"assigned"
	var supply_item_id: StringName = StringName(str(training["supply_item_id"]))
	if not has_supply_item(supply_item_id):
		return &"missing_supply"
	return &"available"


func train_employee(employee_id: StringName, training_id: StringName) -> bool:
	if get_training_availability(employee_id, training_id) != &"available":
		return false
	var employee: Dictionary = employees[employee_id]
	employee["training_id"] = training_id
	employee["training_end_day"] = day + maxi(1, int(TRAINING_DEFINITIONS[training_id]["duration_days"]))
	employee["status"] = "Учится: %s" % TRAINING_DEFINITIONS[training_id]["name"]
	employees[employee_id] = employee
	state_changed.emit()
	return true


func get_employee_job(employee_id: StringName) -> StringName:
	for job_id: StringName in jobs:
		var assigned: PackedStringArray = jobs[job_id]["assigned"]
		if assigned.has(String(employee_id)):
			return job_id
	return &""


func get_active_job() -> Dictionary:
	if jobs.has(active_job_id):
		return jobs[active_job_id]
	return {}


func get_job_repair_scene(job_id: StringName) -> String:
	if not jobs.has(job_id):
		return ""
	return str(jobs[job_id].get("repair_scene", ""))


func get_active_job_repair_scene() -> String:
	return get_job_repair_scene(active_job_id)


func get_job_repair_state(job_id: StringName) -> Dictionary:
	var state: Variant = job_repair_states.get(String(job_id), {})
	if state is Dictionary:
		var state_dictionary: Dictionary = state
		return state_dictionary.duplicate(true)
	return {}


func set_job_repair_state(job_id: StringName, repair_state: Dictionary) -> void:
	if not jobs.has(job_id) or completed_job_ids.has(String(job_id)):
		return
	job_repair_states[String(job_id)] = repair_state.duplicate(true)
	state_changed.emit()


func begin_job(job_id: StringName) -> bool:
	if not jobs.has(job_id) or completed_job_ids.has(String(job_id)):
		return false
	if get_job_repair_scene(job_id).is_empty():
		return false
	var assigned: PackedStringArray = jobs[job_id]["assigned"]
	if assigned.is_empty():
		return false
	active_job_id = job_id
	state_changed.emit()
	return true


func leave_active_job() -> void:
	active_job_id = &""
	state_changed.emit()


func complete_active_job(result: Dictionary = {}) -> bool:
	if active_job_id.is_empty() or not jobs.has(active_job_id):
		return false
	var completed_id: StringName = active_job_id
	if completed_job_ids.has(String(completed_id)):
		return false
	var job: Dictionary = jobs[completed_id]
	var base_reward: int = int(job.get("base_reward", 0))
	var reward_adjustment: int = int(result.get("reward_adjustment", 0))
	var reward: int = maxi(0, base_reward + reward_adjustment)
	var compensation: int = maxi(0, int(result.get("compensation_cost", 0)))
	var assigned: PackedStringArray = job["assigned"]
	var crew_names: PackedStringArray = PackedStringArray()
	for employee_id: String in assigned:
		var employee_key: StringName = StringName(employee_id)
		if employees.has(employee_key):
			crew_names.append(str(employees[employee_key]["name"]))
	money += reward - compensation
	reputation = maxi(0, reputation + int(result.get("reputation_change", 0)))
	completed_job_ids.append(String(completed_id))
	job["assigned"] = PackedStringArray()
	jobs[completed_id] = job
	pending_job_report = {
		"job_id": String(completed_id),
		"title": str(job["title"]),
		"resident": str(job["resident"]),
		"reward": reward,
		"base_reward": base_reward,
		"reward_adjustment": reward_adjustment,
		"maximum_payment": reward_adjustment == 0 and compensation == 0,
		"compensation": compensation,
		"net_change": reward - compensation,
		"crew": Array(crew_names),
		"summary": str(result.get("summary", "Аварийные работы приняты.")),
		"follow_up": result.get("follow_up", {}),
		"actions": result.get("actions", []),
	}
	job_reports.append(pending_job_report.duplicate(true))
	job_repair_states.erase(String(completed_id))
	active_job_id = &""
	_update_employee_statuses()
	state_changed.emit()
	return true


func dismiss_pending_job_report() -> void:
	pending_job_report = {}
	state_changed.emit()


func format_time() -> String:
	return "%02d:%02d" % [time_minutes / 60, time_minutes % 60]


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func start_new_game() -> void:
	day = 1
	time_minutes = 9 * 60
	money = 600
	reputation = 37
	selected_job_id = &"lava_leak"
	active_job_id = &""
	owned_supply_items = PackedStringArray()
	completed_job_ids = PackedStringArray()
	job_reports = []
	pending_job_report = {}
	job_repair_states = {}

	for job_id: StringName in jobs:
		var job: Dictionary = jobs[job_id]
		job["assigned"] = PackedStringArray()
		jobs[job_id] = job

	_reset_employee(&"liliya", true, PackedStringArray(["freeze", "heat"]), "Свободна")
	_reset_employee(&"grog", true, PackedStringArray(["physical_move"]), "Свободен")
	_reset_employee(&"boris", true, PackedStringArray(["diagnose", "repair"]), "Свободен")
	_reset_employee(&"nika", false, PackedStringArray(["telekinesis"]), "Не нанята")
	_reset_employee(&"felix", false, PackedStringArray(["antimagic"]), "Не нанят")

	_update_employee_statuses()
	state_changed.emit()


func _reset_employee(employee_id: StringName, available: bool, abilities: PackedStringArray, status: String) -> void:
	var employee: Dictionary = employees[employee_id]
	employee["available"] = available
	employee["abilities"] = abilities
	employee["status"] = status
	employee["training_id"] = &""
	employee["training_end_day"] = 0
	employees[employee_id] = employee


func save_game() -> Error:
	var job_assignments: Dictionary = {}
	for job_id: StringName in jobs:
		var assigned: PackedStringArray = jobs[job_id]["assigned"]
		job_assignments[String(job_id)] = Array(assigned)

	var employee_progress: Dictionary = {}
	for employee_id: StringName in employees:
		var employee: Dictionary = employees[employee_id]
		employee_progress[String(employee_id)] = {
			"available": employee["available"],
			"abilities": Array(employee["abilities"]),
			"training_id": str(employee.get("training_id", "")),
			"training_end_day": int(employee.get("training_end_day", 0)),
		}

	var save_data: Dictionary = {
		"version": SAVE_VERSION,
		"day": day,
		"time_minutes": time_minutes,
		"money": money,
		"reputation": reputation,
		"selected_job_id": String(selected_job_id),
		"active_job_id": String(active_job_id),
		"owned_supply_items": Array(owned_supply_items),
		"completed_job_ids": Array(completed_job_ids),
		"job_reports": job_reports,
		"pending_job_report": pending_job_report,
		"job_repair_states": job_repair_states,
		"job_assignments": job_assignments,
		"employee_progress": employee_progress,
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(save_data, "\t"))
	return OK


func load_game() -> Error:
	if not has_save():
		return ERR_FILE_NOT_FOUND

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()

	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	if parse_error != OK or typeof(json.data) != TYPE_DICTIONARY:
		return ERR_PARSE_ERROR

	var save_data: Dictionary = json.data
	var version := int(save_data.get("version", 0))
	if version <= 0 or version > SAVE_VERSION:
		return ERR_FILE_UNRECOGNIZED

	day = maxi(1, int(save_data.get("day", day)))
	time_minutes = maxi(0, int(save_data.get("time_minutes", time_minutes)))
	money = int(save_data.get("money", money))
	reputation = int(save_data.get("reputation", reputation))

	var loaded_selected := StringName(save_data.get("selected_job_id", "lava_leak"))
	selected_job_id = loaded_selected if jobs.has(loaded_selected) else &"lava_leak"
	var loaded_active := StringName(save_data.get("active_job_id", ""))
	active_job_id = loaded_active if jobs.has(loaded_active) else &""
	if not active_job_id.is_empty() and get_active_job_repair_scene().is_empty():
		active_job_id = &""

	owned_supply_items = PackedStringArray()
	var loaded_supply_items: Array = save_data.get("owned_supply_items", [])
	for loaded_item_id: Variant in loaded_supply_items:
		var item_id := StringName(str(loaded_item_id))
		if SUPPLY_ITEMS.has(item_id) and not owned_supply_items.has(String(item_id)):
			owned_supply_items.append(String(item_id))

	completed_job_ids = PackedStringArray()
	var loaded_completed_jobs: Array = save_data.get("completed_job_ids", [])
	for loaded_job_id: Variant in loaded_completed_jobs:
		var completed_id := StringName(str(loaded_job_id))
		if jobs.has(completed_id) and not completed_job_ids.has(String(completed_id)):
			completed_job_ids.append(String(completed_id))
	if completed_job_ids.has(String(active_job_id)):
		active_job_id = &""
	job_reports = []
	var loaded_reports: Array = save_data.get("job_reports", [])
	for loaded_report: Variant in loaded_reports:
		if loaded_report is Dictionary:
			var report: Dictionary = loaded_report
			job_reports.append(report.duplicate(true))
	var loaded_pending_report: Variant = save_data.get("pending_job_report", {})
	if loaded_pending_report is Dictionary:
		var pending_report: Dictionary = loaded_pending_report
		pending_job_report = pending_report.duplicate(true)
	else:
		pending_job_report = {}

	job_repair_states = {}
	var loaded_repair_states: Variant = save_data.get("job_repair_states", {})
	if loaded_repair_states is Dictionary:
		for loaded_job_id: Variant in loaded_repair_states:
			var repair_job_id := StringName(str(loaded_job_id))
			var loaded_state: Variant = loaded_repair_states[loaded_job_id]
			if jobs.has(repair_job_id) and not completed_job_ids.has(String(repair_job_id)) and loaded_state is Dictionary:
				var loaded_state_dictionary: Dictionary = loaded_state
				job_repair_states[String(repair_job_id)] = loaded_state_dictionary.duplicate(true)

	var job_assignments: Dictionary = save_data.get("job_assignments", {})
	for job_id: StringName in jobs:
		var job: Dictionary = jobs[job_id]
		var loaded_ids: Array = job_assignments.get(String(job_id), [])
		var valid_ids := PackedStringArray()
		if not completed_job_ids.has(String(job_id)):
			for employee_id: Variant in loaded_ids:
				var employee_key := StringName(str(employee_id))
				if employees.has(employee_key) and not valid_ids.has(String(employee_key)):
					valid_ids.append(String(employee_key))
		job["assigned"] = valid_ids
		jobs[job_id] = job

	var employee_progress: Dictionary = save_data.get("employee_progress", {})
	for employee_id: StringName in employees:
		if not employee_progress.has(String(employee_id)):
			continue
		var employee: Dictionary = employees[employee_id]
		var loaded_employee: Dictionary = employee_progress[String(employee_id)]
		employee["available"] = bool(loaded_employee.get("available", employee["available"]))
		var loaded_abilities: Array = loaded_employee.get("abilities", Array(employee["abilities"]))
		for ability_index in loaded_abilities.size():
			if str(loaded_abilities[ability_index]) == "move":
				loaded_abilities[ability_index] = "physical_move" if employee_id == &"grog" else "telekinesis"
		employee["abilities"] = PackedStringArray(loaded_abilities)
		if employee_id == &"boris":
			var boris_abilities: PackedStringArray = employee["abilities"]
			for required_ability: String in PackedStringArray(["diagnose", "repair"]):
				if not boris_abilities.has(required_ability):
					boris_abilities.append(required_ability)
			employee["abilities"] = boris_abilities
		if employee_id == &"liliya":
			var liliya_abilities: PackedStringArray = employee["abilities"]
			var diagnose_index: int = liliya_abilities.find("diagnose")
			if diagnose_index >= 0:
				liliya_abilities.remove_at(diagnose_index)
			employee["abilities"] = liliya_abilities
		if employee_id == &"nika":
			var nika_abilities: PackedStringArray = employee["abilities"]
			if not nika_abilities.has("telekinesis"):
				nika_abilities.append("telekinesis")
			employee["abilities"] = nika_abilities
		var loaded_training_id := StringName(str(loaded_employee.get("training_id", "")))
		employee["training_id"] = loaded_training_id if TRAINING_DEFINITIONS.has(loaded_training_id) else &""
		employee["training_end_day"] = int(loaded_employee.get("training_end_day", 0))
		employees[employee_id] = employee

	_complete_finished_training()
	_update_employee_statuses()
	state_changed.emit()
	return OK


func _remove_employee_from_all_jobs(employee_id: StringName) -> void:
	for job_id: StringName in jobs:
		var job: Dictionary = jobs[job_id]
		var assigned: PackedStringArray = job["assigned"]
		var index := assigned.find(String(employee_id))
		if index >= 0:
			assigned.remove_at(index)
			job["assigned"] = assigned
			jobs[job_id] = job


func _update_employee_statuses() -> void:
	for employee_id: StringName in EMPLOYEE_ORDER:
		var employee: Dictionary = employees[employee_id]
		if not employee["available"]:
			continue
		var training_id := StringName(str(employee.get("training_id", "")))
		if not training_id.is_empty() and TRAINING_DEFINITIONS.has(training_id):
			employee["status"] = "Учится: %s" % TRAINING_DEFINITIONS[training_id]["name"]
			employees[employee_id] = employee
			continue
		var job_id := get_employee_job(employee_id)
		employee["status"] = employee["idle_status"]
		if not job_id.is_empty():
			employee["status"] = "На заявке: %s" % jobs[job_id]["title"]
		employees[employee_id] = employee


func _complete_finished_training() -> void:
	for employee_id: StringName in EMPLOYEE_ORDER:
		var employee: Dictionary = employees[employee_id]
		var training_id := StringName(str(employee.get("training_id", "")))
		if training_id.is_empty() or day < int(employee.get("training_end_day", 0)):
			continue
		var abilities: PackedStringArray = employee["abilities"]
		if not abilities.has(String(training_id)):
			abilities.append(String(training_id))
		employee["abilities"] = abilities
		employee["training_id"] = &""
		employee["training_end_day"] = 0
		employee["status"] = employee["idle_status"]
		employees[employee_id] = employee
