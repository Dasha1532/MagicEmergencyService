extends Node

signal state_changed

const STARTING_EMPLOYEES: PackedStringArray = ["liliya", "grog", "boris"]
const SAVE_VERSION: int = 1
const SAVE_PATH: String = "user://savegame.json"

var day: int = 1
var time_minutes: int = 9 * 60
var money: int = 1240
var reputation: int = 37
var selected_job_id: StringName = &"lava_leak"
var active_job_id: StringName = &""

var employees: Dictionary = {
	&"liliya": {
		"name": "Лилия Морозова",
		"role": "Маг-практик",
		"portrait": "res://assets/portraits/employees/liliya.png",
		"status": "Свободна",
		"abilities": PackedStringArray(["freeze", "heat"]),
		"core_actions": "Магическая диагностика",
		"description": "Полевой маг широкого профиля. Определяет природу чар и аккуратно меняет температуру повреждённых объектов.",
		"strength": "Сильная сторона: диагностика и контроль стихий",
		"weakness": "Ограничение: силовой ремонт требует напарника",
		"traits": "Наблюдательна • осторожна • любит точные формулировки",
		"available": true,
	},
	&"grog": {
		"name": "Грог Кувалда",
		"role": "Орк-такелажник",
		"portrait": "res://assets/portraits/employees/grog.png",
		"status": "Свободен",
		"abilities": PackedStringArray(["move"]),
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
		"status": "Свободен",
		"abilities": PackedStringArray(),
		"core_actions": "Диагностика и точный ремонт",
		"description": "Опытный мастер по трубам, кранам и прочей инфраструктуре, которая обычно течёт в самый неподходящий момент.",
		"strength": "Сильная сторона: аккуратный обычный ремонт",
		"weakness": "Ограничение: не работает с чарами напрямую",
		"traits": "Практичен • экономен • не доверяет говорящим вентилям",
		"available": true,
	},
	&"nika": {
		"name": "Ника Искра",
		"role": "Универсальный ученик",
		"portrait": "res://assets/portraits/employees/nika.png",
		"status": "Не нанята",
		"abilities": PackedStringArray(),
		"core_actions": "Быстрое обучение",
		"description": "Кандидат на должность младшего специалиста. Быстро осваивает новые инструменты и охотно берётся за незнакомые задачи.",
		"strength": "Сильная сторона: гибкость и скорость обучения",
		"weakness": "Ограничение: мало полевого опыта",
		"traits": "Любознательна • энергична • ведёт слишком подробные записи",
		"available": false,
	},
	&"felix": {
		"name": "Феликс Пепельный",
		"role": "Магический инспектор",
		"portrait": "res://assets/portraits/employees/felix.png",
		"status": "Не нанят",
		"abilities": PackedStringArray(["antimagic"]),
		"core_actions": "Магическая изоляция",
		"description": "Кандидат-инспектор по нестабильным чарам. Локализует магические утечки и проверяет объект перед ремонтом.",
		"strength": "Сильная сторона: антимагия и безопасность",
		"weakness": "Ограничение: действует медленно и по инструкции",
		"traits": "Методичен • невозмутим • замечает нарушения с порога",
		"available": false,
	},
}

var jobs: Dictionary = {
	&"lava_leak": {
		"title": "Из крана течёт лава",
		"address": "Каменная улица, 12",
		"resident": "Господин Рагнар",
		"description": "В ванной демона из трубы идёт лава. Поток усиливается, а старая медная труба уже нагрелась.",
		"urgency": "Срочно",
		"time_left": 95,
		"danger": "Огонь • давление",
		"assigned": PackedStringArray(),
	},
	&"walking_wardrobe": {
		"title": "Шкаф ходит по квартире",
		"address": "Старый квартал, 5",
		"resident": "Госпожа Элеонора",
		"description": "Зачарованный шкаф ходит по комнатам, гремит посудой и не позволяет хозяйке открыть входную дверь.",
		"urgency": "Важно",
		"time_left": 180,
		"danger": "Магия • шум",
		"assigned": PackedStringArray(),
	},
}


func assign_employee(employee_id: StringName, job_id: StringName) -> void:
	if not employees.has(employee_id) or not jobs.has(job_id):
		return
	if not employees[employee_id]["available"]:
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


func begin_job(job_id: StringName) -> bool:
	if not jobs.has(job_id):
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


func format_time() -> String:
	return "%02d:%02d" % [time_minutes / 60, time_minutes % 60]


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func start_new_game() -> void:
	day = 1
	time_minutes = 9 * 60
	money = 1240
	reputation = 37
	selected_job_id = &"lava_leak"
	active_job_id = &""

	for job_id: StringName in jobs:
		var job: Dictionary = jobs[job_id]
		job["assigned"] = PackedStringArray()
		jobs[job_id] = job

	_reset_employee(&"liliya", true, PackedStringArray(["freeze", "heat"]), "Свободна")
	_reset_employee(&"grog", true, PackedStringArray(["move"]), "Свободен")
	_reset_employee(&"boris", true, PackedStringArray(), "Свободен")
	_reset_employee(&"nika", false, PackedStringArray(), "Не нанята")
	_reset_employee(&"felix", false, PackedStringArray(["antimagic"]), "Не нанят")

	_update_employee_statuses()
	state_changed.emit()


func _reset_employee(employee_id: StringName, available: bool, abilities: PackedStringArray, status: String) -> void:
	var employee: Dictionary = employees[employee_id]
	employee["available"] = available
	employee["abilities"] = abilities
	employee["status"] = status
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
		}

	var save_data: Dictionary = {
		"version": SAVE_VERSION,
		"day": day,
		"time_minutes": time_minutes,
		"money": money,
		"reputation": reputation,
		"selected_job_id": String(selected_job_id),
		"active_job_id": String(active_job_id),
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

	var job_assignments: Dictionary = save_data.get("job_assignments", {})
	for job_id: StringName in jobs:
		var job: Dictionary = jobs[job_id]
		var loaded_ids: Array = job_assignments.get(String(job_id), [])
		var valid_ids := PackedStringArray()
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
		employee["abilities"] = PackedStringArray(loaded_abilities)
		employees[employee_id] = employee

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
	for employee_id: StringName in STARTING_EMPLOYEES:
		var employee: Dictionary = employees[employee_id]
		var job_id := get_employee_job(employee_id)
		employee["status"] = "Свободен"
		if employee_id == &"liliya":
			employee["status"] = "Свободна"
		if not job_id.is_empty():
			employee["status"] = "Назначен: %s" % jobs[job_id]["address"]
			if employee_id == &"liliya":
				employee["status"] = "Назначена: %s" % jobs[job_id]["address"]
		employees[employee_id] = employee
