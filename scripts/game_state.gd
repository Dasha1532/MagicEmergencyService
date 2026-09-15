extends Node

signal state_changed

const STARTING_EMPLOYEES: PackedStringArray = ["liliya", "grog", "boris"]

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
		"available": true,
	},
	&"grog": {
		"name": "Грог Кувалда",
		"role": "Орк-такелажник",
		"portrait": "res://assets/portraits/employees/grog.png",
		"status": "Свободен",
		"abilities": PackedStringArray(["move"]),
		"core_actions": "Удержание и силовая работа",
		"available": true,
	},
	&"boris": {
		"name": "Борис Медяк",
		"role": "Мастер-сантехник",
		"portrait": "res://assets/portraits/employees/boris.png",
		"status": "Свободен",
		"abilities": PackedStringArray(),
		"core_actions": "Диагностика и точный ремонт",
		"available": true,
	},
	&"nika": {
		"name": "Ника Искра",
		"role": "Универсальный ученик",
		"portrait": "res://assets/portraits/employees/nika.png",
		"status": "Не нанята",
		"abilities": PackedStringArray(),
		"core_actions": "Быстрое обучение",
		"available": false,
	},
	&"felix": {
		"name": "Феликс Пепельный",
		"role": "Магический инспектор",
		"portrait": "res://assets/portraits/employees/felix.png",
		"status": "Не нанят",
		"abilities": PackedStringArray(["antimagic"]),
		"core_actions": "Магическая изоляция",
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
