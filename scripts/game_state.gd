extends Node

signal state_changed

const STARTING_EMPLOYEES: PackedStringArray = ["liliya", "grog", "boris"]
const EMPLOYEE_ORDER: PackedStringArray = ["liliya", "grog", "boris", "nika", "felix"]
const SAVE_VERSION: int = 11
const LEGACY_SAVE_PATH: String = "user://savegame.json"
const SAVE_SLOT_COUNT: int = 5
const TRAVEL_TIME_MINUTES: int = 15
const OVERDUE_PAYMENT_PENALTY: int = 100
const REAL_SECONDS_PER_GAME_MINUTE: float = 3.0
const SUPPLY_ITEMS: Dictionary = {
	&"animation_kit": {
		"name": "Практическое оживление бытовых предметов",
		"catalog_name": "Практическое оживление",
		"category": "Учебный комплект",
		"price": 400,
		"icon": "res://assets/icons/tools/tool_animate.png",
		"description": "Служебное руководство, учебный кристалл и набор безопасных печатей. Открывает однодневный курс «Оживление» для совместимого сотрудника.",
		"training_id": "animate",
	},
	&"ghost_trap": {
		"name": "Служебная ловушка для привидений",
		"catalog_name": "Ловушка для привидений",
		"category": "Полевое снаряжение",
		"price": 250,
		"icon": "res://assets/objects/ghost_trap/empty.png",
		"description": "Переносной зачарованный контейнер. После двухминутной установки позволяет поймать бестелесное существо без открытия портала.",
	},
	&"thermal_regulator": {
		"name": "Рунический терморегулятор", "catalog_name": "Рунический терморегулятор", "category": "Полевое снаряжение", "price": 280,
		"icon": "res://assets/objects/frozen_bath/regulator.png",
		"description": "Переносной регулятор с рунами тепла и холода. Стабилизирует магическую температуру крана после установки.",
	},
	&"freeze_grimoire": {
		"name": "Основы практической заморозки", "catalog_name": "Практическая заморозка", "category": "Книга заклинания", "price": 350,
		"icon": "res://assets/icons/tools/tool_freeze.png",
		"description": "Практический курс управления холодом. Открывает однодневное обучение заморозке для совместимого сотрудника.",
		"training_id": "freeze",
	},
	&"heat_grimoire": {
		"name": "Управляемое магическое пламя", "catalog_name": "Магическое пламя", "category": "Книга заклинания", "price": 350,
		"icon": "res://assets/icons/tools/tool_heat.png",
		"description": "Учебник безопасного нагрева и магического огня. Открывает однодневное обучение для совместимого сотрудника.",
		"training_id": "heat",
	},
	&"telekinesis_grimoire": {
		"name": "Телекинез для полевых работ", "catalog_name": "Полевой телекинез", "category": "Книга заклинания", "price": 400,
		"icon": "res://assets/icons/tools/tool_move.png",
		"description": "Курс дистанционного перемещения незакреплённых предметов. Открывает однодневное обучение телекинезу.",
		"training_id": "telekinesis",
	},
	&"antimagic_grimoire": {
		"name": "Прикладная антимагия", "catalog_name": "Прикладная антимагия", "category": "Книга заклинания", "price": 550,
		"icon": "res://assets/icons/tools/tool_antimagic.png",
		"description": "Лицензированное руководство по подавлению чар и закрытию магических каналов. Открывает однодневное обучение антимагии.",
		"training_id": "antimagic",
	},
}
const REPUTATION_TITLE_RULES: Array[Dictionary] = [
	{"metric": &"denied_claims", "threshold": 2, "title": "Скупая контора"},
	{"metric": &"damaged_jobs", "threshold": 2, "title": "Гроза интерьеров"},
	{"metric": &"clean_jobs", "threshold": 3, "title": "Безупречные мастера"},
	{"metric": &"action_types", "threshold": 4, "title": "Смелые экспериментаторы"},
	{"metric": &"crew_members", "threshold": 4, "title": "Мастера на все руки"},
	{"metric": &"completed_jobs", "threshold": 3, "title": "Проверенные делом"},
]
const TRAINING_DEFINITIONS: Dictionary = {
	&"animate": {
		"name": "Оживление",
		"supply_item_id": &"animation_kit",
		"category": &"magic",
		"duration_days": 1,
		"description": "Наделяет подходящие неживые объекты автономным поведением. Неосторожное применение может усилить уже действующие чары.",
	},
	&"freeze": {"name": "Заморозка", "supply_item_id": &"freeze_grimoire", "category": &"magic", "duration_days": 1, "description": "Контроль холода и остановка опасных потоков."},
	&"heat": {"name": "Магия огня", "supply_item_id": &"heat_grimoire", "category": &"magic", "duration_days": 1, "description": "Управляемый нагрев и магическое пламя."},
	&"telekinesis": {"name": "Телекинез", "supply_item_id": &"telekinesis_grimoire", "category": &"magic", "duration_days": 1, "description": "Дистанционное перемещение незакреплённых предметов."},
	&"antimagic": {"name": "Антимагия", "supply_item_id": &"antimagic_grimoire", "category": &"magic", "duration_days": 1, "description": "Подавление чар и закрытие магических каналов."},
}
const ABILITY_NAMES: Dictionary = {
	&"freeze": "Заморозка",
	&"heat": "Магия огня",
	&"physical_move": "Силовая работа",
	&"diagnose": "Диагностика",
	&"repair": "Точный ремонт",
	&"telekinesis": "Телекинез",
	&"antimagic": "Магическая изоляция",
	&"animate": "Оживление",
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
var financial_ledger: Array = []
var job_repair_states: Dictionary = {}
var clock_paused: bool = true
var clock_speed: int = 1
var _clock_accumulator: float = 0.0


func _process(delta: float) -> void:
	if clock_paused:
		return
	var current_scene := get_tree().current_scene
	if current_scene == null or current_scene.scene_file_path.ends_with("TitleScreen.tscn"):
		return
	_clock_accumulator += delta * float(clock_speed)
	var elapsed_minutes: int = floori(_clock_accumulator / REAL_SECONDS_PER_GAME_MINUTE)
	if elapsed_minutes <= 0:
		return
	_clock_accumulator -= float(elapsed_minutes) * REAL_SECONDS_PER_GAME_MINUTE
	advance_time(elapsed_minutes)


func set_clock_paused(is_paused: bool) -> void:
	clock_paused = is_paused
	state_changed.emit()


func set_clock_speed(speed: int) -> void:
	clock_speed = speed if speed in [1, 2, 4] else 1
	clock_paused = false
	state_changed.emit()


func get_action_duration(action_id: StringName, intent: StringName = &"") -> int:
	match action_id:
		&"diagnose":
			return 2
		&"repair":
			return 6
		&"anchor":
			return 6
		&"antimagic":
			return 1
		&"physical_move":
			return 4 if intent in [&"move_left", &"move_kitchen", &"break_legs"] else 2
		&"telekinesis":
			return 1
		&"freeze", &"heat":
			return 1
		_:
			return 2

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
		"description": "Полевой маг широкого профиля. Аккуратно меняет температуру повреждённых объектов и сдерживает стихийные аварии.",
		"strength": "Сильная сторона: контроль температуры и стихий",
		"weakness": "Ограничение: силовой ремонт требует напарника",
		"traits": "Наблюдательна • осторожна • любит точные формулировки",
		"ability_reactions": {
			&"freeze": "Добавлю холода ровно столько, сколько нужно. Ни градусом больше.",
			&"heat": "Прогрею постепенно. Резкие перепады оставим погоде.",
		},
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
		"actor_walk_pose": "res://assets/characters/employees/boris/walk_pose_1.png",
		"actor_walk_pose_alt": "res://assets/characters/employees/boris/walk_pose_2.png",
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
		"core_actions": "Телекинез",
		"description": "Маг-телекинетик. Аккуратно перемещает незакреплённые объекты на расстоянии и быстро осваивает новые инструменты.",
		"strength": "Сильная сторона: дистанционное и бережное перемещение",
		"weakness": "Ограничение: мало полевого опыта",
		"traits": "Любознательна • энергична • ведёт слишком подробные записи",
		"ability_reactions": {
			&"freeze": "Попробую заморозку. Для отчёта уже придумала отдельную колонку «неожиданный иней».",
			&"heat": "Добавлю тепла аккуратно. Заметки о пожаре сегодня не планировала.",
			&"telekinesis": "Подниму всё разом и постараюсь ничего не уронить. Особенно важна вторая часть.",
		},
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
		"description": "Инспектор по нестабильным чарам. Локализует магические утечки и безопасно подавляет опасные заклинания.",
		"strength": "Сильная сторона: антимагия и безопасность",
		"weakness": "Ограничение: действует медленно и по инструкции",
		"traits": "Методичен • невозмутим • замечает нарушения с порога",
		"ability_reactions": {
			&"freeze": "Применю контролируемое охлаждение. Неконтролируемого здесь и без нас достаточно.",
			&"heat": "Выполняю регулируемый нагрев. Любые языки пламени сверх нормы будут занесены в протокол.",
			&"antimagic": "Сниму активные чары. Прошу до окончания проверки не накладывать новые.",
		},
		"action_reactions": [
			{"action_ids": ["antimagic"], "object_equals": {"destroyed": true}, "text": "Подавлять уже нечего. Оформляю акт."},
			{"action_ids": ["antimagic"], "object_equals": {"burning": true}, "text": "Возражаю: антимагия пожар не тушит."},
			{"action_ids": ["antimagic"], "object_max": {"magic_level": 0}, "text": "Магического фона нет."},
			{"action_ids": ["antimagic"], "texts": [
				"Магический фон подавлен. Можете приступать к обычному ремонту — желательно обычным способом.",
				"Аномалия локализована. Прошу не создавать новую до составления акта.",
				"Заклинание прекращено. Гарантия на мебель в мои обязанности не входит.",
				"Очаг нестабильности погашен. Всё остальное классифицируется как обычная поломка.",
				"Чары сняты. Если объект всё ещё ведёт себя странно, это уже вопрос к мастеру.",
				"Магическое нарушение устранено. Протокол доволен, жилец — посмотрим.",
			]},
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
		"resident_portrait_region": Rect2(0, 0, 1122, 1402),
		"description": "В ванной демона из трубы идёт лава. Поток усиливается, а старая медная труба уже нагрелась.",
		"urgency": "Срочно",
		"initial_time": 95,
		"time_left": 95,
		"unlocked": true,
		"overdue": false,
		"dispatched": false,
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
		"resident_portrait_region": Rect2(0, 0, 1122, 1402),
		"description": "Зачарованный шкаф ходит по комнатам, гремит хрупкой посудой и не позволяет хозяйке открыть входную дверь.",
		"urgency": "Важно",
		"initial_time": 90,
		"time_left": 90,
		"unlocked": false,
		"overdue": false,
		"dispatched": false,
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
		"resident_portrait": "res://assets/portraits/residents/selesta.png",
		"resident_portrait_region": Rect2(0, 0, 1024, 1536),
		"description": "Старинное зеркало превратилось в нестабильный портал. Из отражения доносятся голоса, а магическое поле в комнате усиливается.",
		"urgency": "Срочно",
		"initial_time": 65,
		"time_left": 65,
		"unlocked": false,
		"overdue": false,
		"dispatched": false,
		"danger": "Магия • портал",
		"base_reward": 600,
		"repair_scene": "res://scenes/PortalMirrorHouse.tscn",
		"assigned": PackedStringArray(),
	},
	&"sleeping_gargoyle": {
		"title": "Восстановить водоотвод на чердаке",
		"objective": "Восстановить водоотвод на чердаке",
		"address": "Башенная улица, 8",
		"resident": "Госпожа Мирабель",
		"resident_portrait": "res://assets/portraits/residents/mirabel.png",
		"resident_portrait_region": Rect2(0, 0, 1122, 1402),
		"description": "Водосточная горгулья уснула и забилась листьями. Дождевая вода уже затапливает чердак.",
		"urgency": "Срочно",
		"initial_time": 80,
		"time_left": 80,
		"unlocked": false,
		"overdue": false,
		"dispatched": false,
		"danger": "Магия • затопление",
		"base_reward": 580,
		"repair_scene": "res://scenes/GargoyleAttic.tscn",
		"assigned": PackedStringArray(),
	},
	&"escaped_ghost": {
		"title": "Привидение выбралось из зеркала",
		"objective": "Изгнать или поймать привидение",
		"address": "Верхний город, 12",
		"resident": "Госпожа Селеста",
		"resident_portrait": "res://assets/portraits/residents/selesta.png",
		"resident_portrait_region": Rect2(0, 0, 1024, 1536),
		"description": "Защитное полотно осталось на зеркале, но привидение прошло сквозь него и теперь мечется по гостиной.",
		"urgency": "Срочно",
		"initial_time": 75,
		"time_left": 75,
		"unlocked": false,
		"overdue": false,
		"dispatched": false,
		"danger": "Магия • привидение",
		"base_reward": 620,
		"repair_scene": "res://scenes/GhostMirrorRoom.tscn",
		"assigned": PackedStringArray(),
	},
	&"frozen_bath": {
		"title": "Вода в ванной замерзает сама",
		"card_title": "Замёрзшая ванна",
		"objective": "Остановить магическое замерзание ванны",
		"address": "Старый квартал, 5",
		"resident": "Господин Рагнар",
		"resident_portrait": "res://assets/portraits/residents/ragnar.png",
		"resident_portrait_region": Rect2(0, 0, 1122, 1402),
		"description": "После ремонта лавового крана вода начала замерзать прямо в тёплой ванной. На кране остался устойчивый холодный магический след.",
		"urgency": "Обычная",
		"initial_time": 110,
		"time_left": 110,
		"unlocked": false,
		"overdue": false,
		"dispatched": false,
		"danger": "Холод • бытовая магия",
		"base_reward": 260,
		"repair_scene": "res://scenes/FrozenBathRoom.tscn",
		"assigned": PackedStringArray(),
	},
}


func assign_employee(employee_id: StringName, job_id: StringName) -> void:
	if not employees.has(employee_id) or not jobs.has(job_id):
		return
	if not is_job_available(job_id):
		return
	if not employees[employee_id]["available"]:
		return
	if is_employee_returning(employee_id):
		return
	if is_employee_training(employee_id):
		return
	var current_job := get_employee_job(employee_id)
	if not current_job.is_empty() and is_job_dispatched(current_job):
		return

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
		if is_job_dispatched(job_id):
			var employee: Dictionary = employees[employee_id]
			employee["arrival_until"] = time_minutes + TRAVEL_TIME_MINUTES
			employees[employee_id] = employee

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
	_record_financial_event(&"hire", -hire_cost, str(employee["name"]), {"employee_id": String(employee_id)})
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
	_record_financial_event(&"purchase", -price, str(item["name"]), {"item_id": String(item_id)})
	state_changed.emit()
	return true


func has_supply_item(item_id: StringName) -> bool:
	return owned_supply_items.has(String(item_id))


func grant_debug_money(amount: int = 500) -> void:
	if not OS.is_debug_build() or amount <= 0:
		return
	money += amount
	_record_financial_event(&"debug_grant", amount, "Тестовое пополнение")
	state_changed.emit()


func advance_day(days: int = 1) -> void:
	if days <= 0:
		return
	day += days
	time_minutes = 9 * 60
	if completed_job_ids.has("lava_leak"):
		_unlock_parallel_jobs()
	if completed_job_ids.has("walking_wardrobe") and completed_job_ids.has("portal_mirror"):
		_unlock_gargoyle_job()
	_unlock_escaped_ghost_job_if_due()
	_unlock_frozen_bath_job_if_due()
	for employee_id: StringName in EMPLOYEE_ORDER:
		var employee: Dictionary = employees[employee_id]
		employee["arrival_until"] = 0
		employee["return_until"] = 0
		employees[employee_id] = employee
	_complete_finished_training()
	_update_employee_statuses()
	state_changed.emit()


func can_finish_day() -> bool:
	for job_id: StringName in jobs:
		if is_job_available(job_id):
			return false
	return true


func try_finish_day() -> bool:
	if not can_finish_day():
		return false
	advance_day(1)
	return true


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
	if is_employee_returning(employee_id):
		return &"returning"
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


func get_ability_name(ability_id: StringName) -> String:
	return str(ABILITY_NAMES.get(ability_id, String(ability_id).capitalize()))


func get_forget_availability(employee_id: StringName, ability_id: StringName) -> StringName:
	if not employees.has(employee_id):
		return &"unknown"
	var employee: Dictionary = employees[employee_id]
	if not bool(employee["available"]):
		return &"not_hired"
	var abilities: PackedStringArray = employee["abilities"]
	if not abilities.has(String(ability_id)):
		return &"missing"
	if is_employee_training(employee_id):
		return &"training"
	if not get_employee_job(employee_id).is_empty():
		return &"assigned"
	if is_employee_returning(employee_id):
		return &"returning"
	return &"available"


func forget_employee_ability(employee_id: StringName, ability_id: StringName) -> bool:
	if get_forget_availability(employee_id, ability_id) != &"available":
		return false
	var employee: Dictionary = employees[employee_id]
	var abilities: PackedStringArray = employee["abilities"]
	abilities.remove_at(abilities.find(String(ability_id)))
	employee["abilities"] = abilities
	var learned_abilities: PackedStringArray = employee.get("learned_abilities", PackedStringArray())
	var learned_index := learned_abilities.find(String(ability_id))
	if learned_index >= 0:
		learned_abilities.remove_at(learned_index)
	employee["learned_abilities"] = learned_abilities
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


func is_job_available(job_id: StringName) -> bool:
	return jobs.has(job_id) and bool(jobs[job_id].get("unlocked", false)) and not completed_job_ids.has(String(job_id))


func is_job_dispatched(job_id: StringName) -> bool:
	return jobs.has(job_id) and bool(jobs[job_id].get("dispatched", false))


func is_employee_returning(employee_id: StringName) -> bool:
	return employees.has(employee_id) and int(employees[employee_id].get("return_until", 0)) > time_minutes


func can_employee_work_on_job(employee_id: StringName, job_id: StringName) -> bool:
	if get_employee_job(employee_id) != job_id or not is_job_dispatched(job_id):
		return false
	return int(employees[employee_id].get("arrival_until", 0)) <= time_minutes


func has_employee_on_site(job_id: StringName) -> bool:
	if not jobs.has(job_id):
		return false
	for employee_id: String in jobs[job_id].get("assigned", PackedStringArray()):
		if can_employee_work_on_job(StringName(employee_id), job_id):
			return true
	return false


func has_employees_in_transit(job_id: StringName) -> bool:
	if not jobs.has(job_id):
		return false
	for employee_id: String in jobs[job_id].get("assigned", PackedStringArray()):
		if int(employees[StringName(employee_id)].get("arrival_until", 0)) > time_minutes:
			return true
	return false


func cancel_job_arrivals(job_id: StringName) -> int:
	if not jobs.has(job_id) or not is_job_dispatched(job_id) or not clock_paused:
		return 0
	var job: Dictionary = jobs[job_id]
	var assigned: PackedStringArray = job.get("assigned", PackedStringArray())
	var kept := PackedStringArray()
	var cancelled: int = 0
	for employee_id: String in assigned:
		var employee_key := StringName(employee_id)
		var employee: Dictionary = employees[employee_key]
		if int(employee.get("arrival_until", 0)) > time_minutes:
			employee["arrival_until"] = 0
			employees[employee_key] = employee
			cancelled += 1
		else:
			kept.append(employee_id)
	job["assigned"] = kept
	if kept.is_empty():
		job["dispatched"] = false
	jobs[job_id] = job
	_update_employee_statuses()
	state_changed.emit()
	return cancelled


func get_next_arrival_time(job_id: StringName) -> int:
	if not jobs.has(job_id):
		return -1
	var next_arrival: int = -1
	for employee_id: String in jobs[job_id].get("assigned", PackedStringArray()):
		var arrival: int = int(employees[StringName(employee_id)].get("arrival_until", 0))
		if arrival <= time_minutes:
			return time_minutes
		if next_arrival < 0 or arrival < next_arrival:
			next_arrival = arrival
	return next_arrival


func start_job_action(job_id: StringName, employee_id: StringName, action_id: StringName, intent: StringName, duration: int) -> bool:
	if not is_job_available(job_id) or not can_employee_work_on_job(employee_id, job_id):
		return false
	var job: Dictionary = jobs[job_id]
	var existing: Variant = job.get("pending_action", {})
	if existing is Dictionary and not (existing as Dictionary).is_empty():
		return false
	job["pending_action"] = {
		"employee_id": String(employee_id), "action_id": String(action_id), "intent": String(intent),
		"started_at": time_minutes, "ends_at": time_minutes + maxi(1, duration),
	}
	jobs[job_id] = job
	state_changed.emit()
	return true


func get_pending_job_action(job_id: StringName) -> Dictionary:
	if not jobs.has(job_id):
		return {}
	var pending: Variant = jobs[job_id].get("pending_action", {})
	return (pending as Dictionary).duplicate(true) if pending is Dictionary else {}


func clear_pending_job_action(job_id: StringName) -> void:
	if not jobs.has(job_id):
		return
	var job: Dictionary = jobs[job_id]
	job["pending_action"] = {}
	jobs[job_id] = job
	state_changed.emit()


func advance_time(minutes: int, excluded_job_id: StringName = &"") -> PackedStringArray:
	var newly_overdue := PackedStringArray()
	if minutes <= 0:
		return newly_overdue
	time_minutes += minutes
	_update_employee_statuses()
	for job_id: StringName in jobs:
		if job_id == excluded_job_id or not is_job_available(job_id):
			continue
		var job: Dictionary = jobs[job_id]
		var previous_time: int = maxi(0, int(job.get("time_left", 0)))
		var remaining_time: int = maxi(0, previous_time - minutes)
		job["time_left"] = remaining_time
		if previous_time > 0 and remaining_time == 0 and not bool(job.get("overdue", false)):
			job["overdue"] = true
			newly_overdue.append(String(job_id))
		jobs[job_id] = job
	state_changed.emit()
	return newly_overdue


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
	if not is_job_available(job_id):
		return false
	if get_job_repair_scene(job_id).is_empty():
		return false
	var assigned: PackedStringArray = jobs[job_id]["assigned"]
	if assigned.is_empty():
		return false
	active_job_id = job_id
	if not is_job_dispatched(job_id):
		var job: Dictionary = jobs[job_id]
		job["dispatched"] = true
		jobs[job_id] = job
		for employee_id: String in assigned:
			var employee: Dictionary = employees[StringName(employee_id)]
			employee["arrival_until"] = time_minutes + TRAVEL_TIME_MINUTES
			employees[StringName(employee_id)] = employee
		_update_employee_statuses()
		state_changed.emit()
	else:
		state_changed.emit()
	return true


func leave_active_job() -> void:
	active_job_id = &""
	state_changed.emit()


func recall_job(job_id: StringName) -> bool:
	if not is_job_available(job_id) or not is_job_dispatched(job_id):
		return false
	if not get_pending_job_action(job_id).is_empty():
		return false
	var job: Dictionary = jobs[job_id]
	for employee_id: String in job["assigned"]:
		var employee: Dictionary = employees[StringName(employee_id)]
		employee["arrival_until"] = 0
		employee["return_until"] = time_minutes + TRAVEL_TIME_MINUTES
		employees[StringName(employee_id)] = employee
	job["assigned"] = PackedStringArray()
	job["dispatched"] = false
	jobs[job_id] = job
	if active_job_id == job_id:
		active_job_id = &""
	_update_employee_statuses()
	state_changed.emit()
	return true


func complete_active_job(result: Dictionary = {}) -> bool:
	if active_job_id.is_empty() or not jobs.has(active_job_id):
		return false
	if not get_pending_job_action(active_job_id).is_empty():
		return false
	var completed_id: StringName = active_job_id
	if completed_job_ids.has(String(completed_id)):
		return false
	var job: Dictionary = jobs[completed_id]
	var base_reward: int = int(job.get("base_reward", 0))
	var overdue: bool = bool(job.get("overdue", false))
	var reward_adjustment: int = int(result.get("reward_adjustment", 0)) - (OVERDUE_PAYMENT_PENALTY if overdue else 0)
	var expense_reimbursement: int = maxi(0, int(result.get("expense_reimbursement", 0)))
	var reward: int = maxi(0, base_reward + reward_adjustment + expense_reimbursement)
	var compensation: int = maxi(0, int(result.get("compensation_cost", 0)))
	var assigned: PackedStringArray = job["assigned"]
	var crew_names: PackedStringArray = PackedStringArray()
	for employee_id: String in assigned:
		var employee_key: StringName = StringName(employee_id)
		if employees.has(employee_key):
			crew_names.append(str(employees[employee_key]["name"]))
	for employee_id: String in assigned:
		var returning_employee: Dictionary = employees[StringName(employee_id)]
		returning_employee["arrival_until"] = 0
		returning_employee["return_until"] = time_minutes + TRAVEL_TIME_MINUTES
		employees[StringName(employee_id)] = returning_employee
	money += reward
	var reputation_change: int = int(result.get("reputation_change", 0)) - (1 if overdue else 0)
	reputation = maxi(0, reputation + reputation_change)
	completed_job_ids.append(String(completed_id))
	job["assigned"] = PackedStringArray()
	job["dispatched"] = false
	jobs[completed_id] = job
	var summary: String = str(result.get("summary", "Аварийные работы приняты."))
	if overdue:
		summary += " Заявка выполнена после истечения срока: из оплаты удержано %d монет." % OVERDUE_PAYMENT_PENALTY
	pending_job_report = {
		"job_id": String(completed_id),
		"title": str(job["title"]),
		"resident": str(job["resident"]),
		"reward": reward,
		"base_reward": base_reward,
		"reward_adjustment": reward_adjustment,
		"expense_reimbursement": expense_reimbursement,
		"maximum_payment": reward_adjustment == 0 and compensation == 0,
		"compensation": 0,
		"claim_amount": compensation,
		"claim_status": "pending" if compensation > 0 else "none",
		"claim_reputation_penalty": 0,
		"net_change": reward,
		"reputation_change": reputation_change,
		"rating": _calculate_report_rating(reputation_change, reward_adjustment, compensation),
		"completed_day": day,
		"completed_time": time_minutes,
		"crew": Array(crew_names),
		"summary": summary,
		"review": str(result.get("review", "")),
		"consequences": result.get("consequences", []),
		"overdue": overdue,
		"follow_up": result.get("follow_up", {}),
		"actions": result.get("actions", []),
	}
	job_reports.append(pending_job_report.duplicate(true))
	_record_financial_event(&"job", reward, str(job["title"]), {
		"job_id": String(completed_id), "income": reward, "expense": 0,
	})
	job_repair_states.erase(String(completed_id))
	active_job_id = &""
	_update_employee_statuses()
	state_changed.emit()
	return true


func dismiss_pending_job_report() -> void:
	if str(pending_job_report.get("claim_status", "none")) == "pending":
		return
	pending_job_report = {}
	state_changed.emit()


func resolve_pending_claim(pay_compensation: bool) -> bool:
	if pending_job_report.is_empty() or str(pending_job_report.get("claim_status", "none")) != "pending":
		return false
	var claim_amount := maxi(0, int(pending_job_report.get("claim_amount", 0)))
	if claim_amount <= 0:
		return false
	if pay_compensation:
		money -= claim_amount
		pending_job_report["claim_status"] = "paid"
		pending_job_report["compensation"] = claim_amount
		pending_job_report["net_change"] = int(pending_job_report.get("reward", 0)) - claim_amount
		_record_financial_event(&"compensation", -claim_amount, str(pending_job_report.get("title", "Компенсация жильцу")), {
			"job_id": str(pending_job_report.get("job_id", "")), "resident": str(pending_job_report.get("resident", "")),
		})
	else:
		var reputation_penalty := 2 if claim_amount >= 300 else 1
		reputation = maxi(0, reputation - reputation_penalty)
		pending_job_report["claim_status"] = "denied"
		pending_job_report["claim_reputation_penalty"] = reputation_penalty
		pending_job_report["reputation_change"] = int(pending_job_report.get("reputation_change", 0)) - reputation_penalty
		var review := str(pending_job_report.get("review", "")).strip_edges()
		pending_job_report["review_before_claim_decision"] = review
		pending_job_report["review"] = "%s%s" % [review, " В компенсации мне ещё и отказали." if not review.is_empty() else "Служба отказалась компенсировать причинённый ущерб."]
	pending_job_report["claim_decision_day"] = day
	pending_job_report["claim_decision_time"] = time_minutes
	pending_job_report["rating"] = _calculate_report_rating(
		int(pending_job_report.get("reputation_change", 0)),
		int(pending_job_report.get("reward_adjustment", 0)),
		claim_amount
	)
	_sync_pending_report_to_history()
	state_changed.emit()
	return true


func pay_denied_claim(job_id: String, completed_day: int, completed_time: int) -> bool:
	for index in range(job_reports.size() - 1, -1, -1):
		var report_value: Variant = job_reports[index]
		if not report_value is Dictionary:
			continue
		var report: Dictionary = report_value
		if str(report.get("job_id", "")) != job_id or int(report.get("completed_day", 0)) != completed_day or int(report.get("completed_time", -1)) != completed_time:
			continue
		if str(report.get("claim_status", "none")) != "denied":
			return false
		var claim_amount := maxi(0, int(report.get("claim_amount", 0)))
		if claim_amount <= 0:
			return false
		money -= claim_amount
		var restored_reputation := maxi(0, int(report.get("claim_reputation_penalty", 0)))
		reputation += restored_reputation
		report["claim_status"] = "paid_after_denial"
		report["compensation"] = claim_amount
		report["net_change"] = int(report.get("reward", 0)) - claim_amount
		report["reputation_change"] = int(report.get("reputation_change", 0)) + restored_reputation
		report["claim_reputation_restored"] = restored_reputation
		report["claim_reputation_penalty"] = 0
		var original_review := str(report.get("review_before_claim_decision", "")).strip_edges()
		if original_review.is_empty():
			original_review = str(report.get("review", "")).replace(" В компенсации мне ещё и отказали.", "").replace("Служба отказалась компенсировать причинённый ущерб.", "").strip_edges()
		report["review"] = "%s%s" % [original_review, " Позже служба всё-таки выплатила компенсацию." if not original_review.is_empty() else "После первоначального отказа служба всё-таки выплатила компенсацию."]
		report["claim_payment_day"] = day
		report["claim_payment_time"] = time_minutes
		report["rating"] = _calculate_report_rating(
			int(report.get("reputation_change", 0)),
			int(report.get("reward_adjustment", 0)),
			claim_amount
		)
		job_reports[index] = report
		_record_financial_event(&"compensation", -claim_amount, str(report.get("title", "Компенсация жильцу")), {
			"job_id": job_id, "resident": str(report.get("resident", "")), "late_payment": true,
		})
		state_changed.emit()
		return true
	return false


func _sync_pending_report_to_history() -> void:
	var job_id := str(pending_job_report.get("job_id", ""))
	var completed_day := int(pending_job_report.get("completed_day", 0))
	var completed_time := int(pending_job_report.get("completed_time", -1))
	for index in range(job_reports.size() - 1, -1, -1):
		var report_value: Variant = job_reports[index]
		if not report_value is Dictionary:
			continue
		var report: Dictionary = report_value
		if str(report.get("job_id", "")) == job_id and int(report.get("completed_day", 0)) == completed_day and int(report.get("completed_time", -1)) == completed_time:
			job_reports[index] = pending_job_report.duplicate(true)
			return


func format_time() -> String:
	return "%02d:%02d" % [floori(float(time_minutes) / 60.0), time_minutes % 60]


func get_reputation_titles(max_titles: int = 2) -> PackedStringArray:
	var metrics := {
		&"completed_jobs": 0,
		&"clean_jobs": 0,
		&"damaged_jobs": 0,
		&"denied_claims": 0,
		&"action_types": 0,
		&"crew_members": 0,
	}
	var action_types := {}
	var crew_members := {}
	for report_value: Variant in job_reports:
		if not report_value is Dictionary:
			continue
		var report: Dictionary = report_value
		metrics[&"completed_jobs"] += 1
		var claim_amount := maxi(int(report.get("claim_amount", 0)), int(report.get("compensation", 0)))
		if claim_amount > 0:
			metrics[&"damaged_jobs"] += 1
		elif not bool(report.get("overdue", false)) and int(report.get("reputation_change", 0)) >= 0:
			metrics[&"clean_jobs"] += 1
		if str(report.get("claim_status", "none")) == "denied":
			metrics[&"denied_claims"] += 1
		var actions_value: Variant = report.get("actions", [])
		if actions_value is Array:
			for action_value: Variant in actions_value:
				if action_value is Dictionary:
					var action_id := str((action_value as Dictionary).get("action_id", (action_value as Dictionary).get("intent", "")))
					if not action_id.is_empty():
						action_types[action_id] = true
		var crew_value: Variant = report.get("crew", [])
		if crew_value is Array:
			for member_value: Variant in crew_value:
				var member := str(member_value)
				if not member.is_empty():
					crew_members[member] = true
	metrics[&"action_types"] = action_types.size()
	metrics[&"crew_members"] = crew_members.size()
	var result := PackedStringArray()
	for rule: Dictionary in REPUTATION_TITLE_RULES:
		var metric := StringName(str(rule.get("metric", "")))
		if int(metrics.get(metric, 0)) >= int(rule.get("threshold", 0)):
			result.append(str(rule.get("title", "")))
			if result.size() >= maxi(1, max_titles):
				break
	if result.is_empty():
		result.append("Новая служба")
	return result


func save_slot_path(slot: int) -> String:
	return "user://save_slot_%d.json" % clampi(slot, 1, SAVE_SLOT_COUNT)


func has_save(slot: int = 0) -> bool:
	if slot > 0:
		if slot > SAVE_SLOT_COUNT:
			return false
		return FileAccess.file_exists(save_slot_path(slot)) or (slot == 1 and FileAccess.file_exists(LEGACY_SAVE_PATH))
	for slot_index in range(1, SAVE_SLOT_COUNT + 1):
		if has_save(slot_index):
			return true
	return false


func get_latest_save_slot() -> int:
	var latest_slot := 0
	var latest_time := 0
	for slot_index in range(1, SAVE_SLOT_COUNT + 1):
		var path := _existing_save_slot_path(slot_index)
		if path.is_empty():
			continue
		var modified := int(FileAccess.get_modified_time(path))
		if latest_slot == 0 or modified >= latest_time:
			latest_slot = slot_index
			latest_time = modified
	return latest_slot


func get_save_slot_summary(slot: int) -> Dictionary:
	var path := _existing_save_slot_path(slot)
	if path.is_empty():
		return {"exists": false, "slot": slot}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"exists": false, "slot": slot}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {"exists": false, "slot": slot}
	var data: Dictionary = parsed
	var minutes := maxi(0, int(data.get("time_minutes", 9 * 60)))
	return {
		"exists": true,
		"slot": slot,
		"day": maxi(1, int(data.get("day", 1))),
		"time": "%02d:%02d" % [floori(float(minutes) / 60.0), minutes % 60],
		"money": int(data.get("money", 0)),
		"reputation": int(data.get("reputation", 0)),
		"active_job_id": str(data.get("active_job_id", "")),
	}


func _existing_save_slot_path(slot: int) -> String:
	if slot < 1 or slot > SAVE_SLOT_COUNT:
		return ""
	var slot_path := save_slot_path(slot)
	if FileAccess.file_exists(slot_path):
		return slot_path
	if slot == 1 and FileAccess.file_exists(LEGACY_SAVE_PATH):
		return LEGACY_SAVE_PATH
	return ""


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
	financial_ledger = [_financial_event(&"opening_balance", money, "Начальные средства службы")]
	job_repair_states = {}
	clock_paused = true
	clock_speed = 1
	_clock_accumulator = 0.0

	for job_id: StringName in jobs:
		var job: Dictionary = jobs[job_id]
		job["assigned"] = PackedStringArray()
		job["time_left"] = int(job.get("initial_time", job.get("time_left", 0)))
		job["overdue"] = false
		job["unlocked"] = job_id == &"lava_leak"
		job["dispatched"] = false
		job["pending_action"] = {}
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
	employee["learned_abilities"] = PackedStringArray()
	employee["arrival_until"] = 0
	employee["return_until"] = 0
	employees[employee_id] = employee


func save_game(slot: int = 1) -> Error:
	if slot < 1 or slot > SAVE_SLOT_COUNT:
		return ERR_INVALID_PARAMETER
	var job_assignments: Dictionary = {}
	var job_progress: Dictionary = {}
	for job_id: StringName in jobs:
		var assigned: PackedStringArray = jobs[job_id]["assigned"]
		job_assignments[String(job_id)] = Array(assigned)
		job_progress[String(job_id)] = {
			"time_left": int(jobs[job_id].get("time_left", 0)),
			"overdue": bool(jobs[job_id].get("overdue", false)),
			"unlocked": bool(jobs[job_id].get("unlocked", false)),
			"dispatched": bool(jobs[job_id].get("dispatched", false)),
			"pending_action": jobs[job_id].get("pending_action", {}),
		}

	var employee_progress: Dictionary = {}
	for employee_id: StringName in employees:
		var employee: Dictionary = employees[employee_id]
		employee_progress[String(employee_id)] = {
			"available": employee["available"],
			"abilities": Array(employee["abilities"]),
			"learned_abilities": Array(employee.get("learned_abilities", PackedStringArray())),
			"training_id": str(employee.get("training_id", "")),
			"training_end_day": int(employee.get("training_end_day", 0)),
			"arrival_until": int(employee.get("arrival_until", 0)),
			"return_until": int(employee.get("return_until", 0)),
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
		"financial_ledger": financial_ledger,
		"job_repair_states": job_repair_states,
		"job_assignments": job_assignments,
		"job_progress": job_progress,
		"employee_progress": employee_progress,
		"clock_paused": clock_paused,
		"clock_speed": clock_speed,
	}

	var file := FileAccess.open(save_slot_path(slot), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(save_data, "\t"))
	return OK


func load_game(slot: int = 0) -> Error:
	if slot < 0 or slot > SAVE_SLOT_COUNT:
		return ERR_INVALID_PARAMETER
	var target_slot := slot if slot > 0 else get_latest_save_slot()
	if target_slot < 1 or not has_save(target_slot):
		return ERR_FILE_NOT_FOUND

	var file := FileAccess.open(_existing_save_slot_path(target_slot), FileAccess.READ)
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
	clock_paused = bool(save_data.get("clock_paused", true))
	clock_speed = int(save_data.get("clock_speed", 1))
	_clock_accumulator = 0.0

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

	var loaded_job_progress: Dictionary = save_data.get("job_progress", {})
	for job_id: StringName in jobs:
		var job: Dictionary = jobs[job_id]
		job["time_left"] = int(job.get("initial_time", job.get("time_left", 0)))
		job["overdue"] = false
		job["unlocked"] = job_id == &"lava_leak"
		job["dispatched"] = false
		job["pending_action"] = {}
		if version < 6:
			# Старые сохранения уже показывали все заявки; не скрываем начатый прогресс.
			job["unlocked"] = true
		elif loaded_job_progress.has(String(job_id)):
			var progress: Dictionary = loaded_job_progress[String(job_id)]
			job["time_left"] = maxi(0, int(progress.get("time_left", job["time_left"])))
			job["overdue"] = bool(progress.get("overdue", false)) or int(job["time_left"]) == 0
			job["unlocked"] = bool(progress.get("unlocked", job["unlocked"]))
			job["dispatched"] = bool(progress.get("dispatched", false))
			var pending_action: Variant = progress.get("pending_action", {})
			job["pending_action"] = (pending_action as Dictionary).duplicate(true) if pending_action is Dictionary else {}
		jobs[job_id] = job
	if not active_job_id.is_empty() and jobs.has(active_job_id):
		var active_job: Dictionary = jobs[active_job_id]
		active_job["dispatched"] = true
		jobs[active_job_id] = active_job
	if not active_job_id.is_empty() and not is_job_available(active_job_id):
		active_job_id = &""
	if not is_job_available(selected_job_id):
		selected_job_id = _first_available_job_id()
	job_reports = []
	var migrated_reputation_bonus := 0
	var loaded_reports: Array = save_data.get("job_reports", [])
	for loaded_report: Variant in loaded_reports:
		if loaded_report is Dictionary:
			var report: Dictionary = loaded_report
			_migrate_claim_fields(report)
			if not report.has("reputation_change") and bool(report.get("maximum_payment", false)) and not bool(report.get("overdue", false)):
				report["reputation_change"] = 1
				report["rating"] = 5
				migrated_reputation_bonus += 1
			job_reports.append(report.duplicate(true))
	if migrated_reputation_bonus > 0:
		reputation += migrated_reputation_bonus
	if completed_job_ids.has("lava_leak"):
		_set_parallel_jobs_unlocked(day > _job_completed_day(&"lava_leak"))
	if completed_job_ids.has("walking_wardrobe") and completed_job_ids.has("portal_mirror"):
		var last_second_day_completion := maxi(
			_job_completed_day(&"walking_wardrobe"),
			_job_completed_day(&"portal_mirror")
		)
		_set_gargoyle_job_unlocked(day > last_second_day_completion)
	_unlock_escaped_ghost_job_if_due()
	_unlock_frozen_bath_job_if_due()
	if not is_job_available(selected_job_id):
		selected_job_id = _first_available_job_id()
	var loaded_pending_report: Variant = save_data.get("pending_job_report", {})
	if loaded_pending_report is Dictionary:
		var pending_report: Dictionary = loaded_pending_report
		_migrate_claim_fields(pending_report)
		pending_job_report = pending_report.duplicate(true) if _is_valid_pending_report(pending_report) else {}
	else:
		pending_job_report = {}
	financial_ledger = []
	var loaded_ledger: Variant = save_data.get("financial_ledger", [])
	if loaded_ledger is Array:
		for loaded_event: Variant in loaded_ledger:
			if loaded_event is Dictionary:
				financial_ledger.append((loaded_event as Dictionary).duplicate(true))

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
		if is_job_available(job_id):
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
		var loaded_learned_abilities: Array = loaded_employee.get("learned_abilities", [])
		var learned_abilities := PackedStringArray()
		for learned_ability_value: Variant in loaded_learned_abilities:
			var learned_ability := StringName(str(learned_ability_value))
			if TRAINING_DEFINITIONS.has(learned_ability) and not learned_abilities.has(String(learned_ability)):
				learned_abilities.append(String(learned_ability))
		for ability_value: Variant in loaded_abilities:
			var migrated_learned_ability := StringName(str(ability_value))
			if TRAINING_DEFINITIONS.has(migrated_learned_ability) and not learned_abilities.has(String(migrated_learned_ability)):
				learned_abilities.append(String(migrated_learned_ability))
		employee["learned_abilities"] = learned_abilities
		if version < 10 and employee_id == &"boris":
			var boris_abilities: PackedStringArray = employee["abilities"]
			for required_ability: String in PackedStringArray(["diagnose", "repair"]):
				if not boris_abilities.has(required_ability):
					boris_abilities.append(required_ability)
			employee["abilities"] = boris_abilities
		if version < 10 and employee_id == &"liliya":
			var liliya_abilities: PackedStringArray = employee["abilities"]
			var diagnose_index: int = liliya_abilities.find("diagnose")
			if diagnose_index >= 0:
				liliya_abilities.remove_at(diagnose_index)
			employee["abilities"] = liliya_abilities
		if version < 10 and employee_id == &"nika":
			var nika_abilities: PackedStringArray = employee["abilities"]
			if not nika_abilities.has("telekinesis"):
				nika_abilities.append("telekinesis")
			employee["abilities"] = nika_abilities
		var loaded_training_id := StringName(str(loaded_employee.get("training_id", "")))
		employee["training_id"] = loaded_training_id if TRAINING_DEFINITIONS.has(loaded_training_id) else &""
		employee["training_end_day"] = int(loaded_employee.get("training_end_day", 0))
		employee["arrival_until"] = int(loaded_employee.get("arrival_until", 0))
		employee["return_until"] = int(loaded_employee.get("return_until", 0))
		employees[employee_id] = employee

	if version < 9 or financial_ledger.is_empty():
		_rebuild_legacy_financial_ledger()

	_complete_finished_training()
	_update_employee_statuses()
	state_changed.emit()
	return OK


func _record_financial_event(kind: StringName, amount: int, title: String, details: Dictionary = {}) -> void:
	var event := _financial_event(kind, amount, title)
	for key: Variant in details:
		event[key] = details[key]
	financial_ledger.append(event)


func _migrate_claim_fields(report: Dictionary) -> void:
	if report.has("claim_status"):
		return
	var legacy_compensation := maxi(0, int(report.get("compensation", 0)))
	report["claim_amount"] = legacy_compensation
	report["claim_status"] = "paid" if legacy_compensation > 0 else "none"
	report["claim_reputation_penalty"] = 0


func _is_valid_pending_report(report: Dictionary) -> bool:
	var job_id := str(report.get("job_id", "")).strip_edges()
	var title := str(report.get("title", "")).strip_edges()
	return not job_id.is_empty() and not title.is_empty() and completed_job_ids.has(job_id)


func _financial_event(kind: StringName, amount: int, title: String) -> Dictionary:
	return {
		"kind": String(kind), "amount": amount, "title": title,
		"day": day, "time_minutes": time_minutes,
	}


func _calculate_report_rating(reputation_change: int, reward_adjustment: int, compensation: int) -> int:
	if compensation > 0 and reward_adjustment <= -400:
		return 1
	if reputation_change <= -4:
		return 1
	if reputation_change <= -2:
		return 2
	if reputation_change < 0:
		return 3
	if reward_adjustment < 0 or compensation > 0:
		return 4
	return 5


func _rebuild_legacy_financial_ledger() -> void:
	financial_ledger = [{
		"kind": "opening_balance", "amount": 600, "title": "Начальные средства службы",
		"day": 0, "time_minutes": -1, "legacy": true,
	}]
	var known_balance := 600
	for report_value: Variant in job_reports:
		if not report_value is Dictionary:
			continue
		var report: Dictionary = report_value
		var income := int(report.get("reward", 0))
		financial_ledger.append({
			"kind": "job", "amount": income, "title": str(report.get("title", "Завершённая заявка")),
			"income": income, "expense": 0,
			"day": int(report.get("completed_day", 0)), "time_minutes": int(report.get("completed_time", -1)), "legacy": true,
		})
		known_balance += income
		var claim_status := str(report.get("claim_status", "paid"))
		var paid_compensation := int(report.get("compensation", 0)) if claim_status in ["paid", "paid_after_denial"] else 0
		if paid_compensation > 0:
			financial_ledger.append({
				"kind": "compensation", "amount": -paid_compensation, "title": str(report.get("title", "Компенсация жильцу")),
				"job_id": str(report.get("job_id", "")), "resident": str(report.get("resident", "")),
				"day": int(report.get("claim_decision_day", report.get("completed_day", 0))),
				"time_minutes": int(report.get("claim_decision_time", report.get("completed_time", -1))), "legacy": true,
			})
			known_balance -= paid_compensation
	for item_id_string: String in owned_supply_items:
		var item_id := StringName(item_id_string)
		if not SUPPLY_ITEMS.has(item_id):
			continue
		var price := int(SUPPLY_ITEMS[item_id]["price"])
		financial_ledger.append({"kind": "purchase", "amount": -price, "title": str(SUPPLY_ITEMS[item_id]["name"]), "day": 0, "time_minutes": -1, "legacy": true})
		known_balance -= price
	for employee_id: StringName in EMPLOYEE_ORDER:
		var employee: Dictionary = employees[employee_id]
		var hire_cost := int(employee.get("hire_cost", 0))
		if hire_cost <= 0 or not bool(employee.get("available", false)):
			continue
		financial_ledger.append({"kind": "hire", "amount": -hire_cost, "title": str(employee["name"]), "day": 0, "time_minutes": -1, "legacy": true})
		known_balance -= hire_cost
	if known_balance != money:
		financial_ledger.append({"kind": "legacy_adjustment", "amount": money - known_balance, "title": "Операции прежней версии сохранения", "day": 0, "time_minutes": -1, "legacy": true})


func _remove_employee_from_all_jobs(employee_id: StringName) -> void:
	for job_id: StringName in jobs:
		var job: Dictionary = jobs[job_id]
		var assigned: PackedStringArray = job["assigned"]
		var index := assigned.find(String(employee_id))
		if index >= 0:
			assigned.remove_at(index)
			job["assigned"] = assigned
			jobs[job_id] = job


func _unlock_parallel_jobs() -> void:
	_set_parallel_jobs_unlocked(true)


func _set_parallel_jobs_unlocked(unlocked: bool) -> void:
	for job_id: StringName in PackedStringArray(["walking_wardrobe", "portal_mirror"]):
		if not jobs.has(job_id) or completed_job_ids.has(String(job_id)):
			continue
		var job: Dictionary = jobs[job_id]
		job["unlocked"] = unlocked
		jobs[job_id] = job


func _unlock_gargoyle_job() -> void:
	_set_gargoyle_job_unlocked(true)


func _set_gargoyle_job_unlocked(unlocked: bool) -> void:
	var job_id := &"sleeping_gargoyle"
	if not jobs.has(job_id) or completed_job_ids.has(String(job_id)):
		return
	var job: Dictionary = jobs[job_id]
	job["unlocked"] = unlocked
	jobs[job_id] = job


func _unlock_escaped_ghost_job_if_due() -> void:
	var source_day := 0
	for report_value: Variant in job_reports:
		if not report_value is Dictionary:
			continue
		var report: Dictionary = report_value
		var follow_up: Variant = report.get("follow_up", {})
		if follow_up is Dictionary and str((follow_up as Dictionary).get("type", "")) == "escaped_ghost":
			source_day = int(report.get("completed_day", 0))
			break
	var job_id := &"escaped_ghost"
	if not jobs.has(job_id) or completed_job_ids.has(String(job_id)):
		return
	var job: Dictionary = jobs[job_id]
	job["unlocked"] = source_day > 0 and day > source_day
	jobs[job_id] = job


func _unlock_frozen_bath_job_if_due() -> void:
	var source_day := 0
	for report_value: Variant in job_reports:
		if not report_value is Dictionary:
			continue
		var report: Dictionary = report_value
		var follow_up: Variant = report.get("follow_up", {})
		if follow_up is Dictionary and str((follow_up as Dictionary).get("type", "")) == "frozen_bath":
			source_day = int(report.get("completed_day", 0))
			break
	var job_id := &"frozen_bath"
	if not jobs.has(job_id) or completed_job_ids.has(String(job_id)):
		return
	var job: Dictionary = jobs[job_id]
	job["unlocked"] = source_day > 0 and day > source_day
	jobs[job_id] = job


func _job_completed_day(job_id: StringName) -> int:
	for report_value: Variant in job_reports:
		if report_value is Dictionary:
			var report: Dictionary = report_value
			if StringName(str(report.get("job_id", ""))) == job_id:
				return int(report.get("completed_day", 0))
	return 0


func _first_available_job_id() -> StringName:
	for job_id: StringName in jobs:
		if is_job_available(job_id):
			return job_id
	return &""


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
		var pending_action: Dictionary = get_pending_job_action(job_id)
		employee["status"] = employee["idle_status"]
		if int(employee.get("return_until", 0)) > time_minutes:
			employee["status"] = "Возвращается • прибудет в %s" % _format_minutes(int(employee["return_until"]))
		elif not job_id.is_empty() and int(employee.get("arrival_until", 0)) > time_minutes:
			employee["status"] = "В пути • прибудет в %s" % _format_minutes(int(employee["arrival_until"]))
		elif not job_id.is_empty() and str(pending_action.get("employee_id", "")) == String(employee_id):
			employee["status"] = "Работает • до %s" % _format_minutes(int(pending_action.get("ends_at", time_minutes)))
		elif not job_id.is_empty():
			employee["status"] = "На заявке: %s" % jobs[job_id].get("card_title", jobs[job_id]["title"])
		employees[employee_id] = employee


func _format_minutes(value: int) -> String:
	return "%02d:%02d" % [floori(float(value) / 60.0), value % 60]


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
		var learned_abilities: PackedStringArray = employee.get("learned_abilities", PackedStringArray())
		if not learned_abilities.has(String(training_id)):
			learned_abilities.append(String(training_id))
		employee["learned_abilities"] = learned_abilities
		employee["training_id"] = &""
		employee["training_end_day"] = 0
		employee["status"] = employee["idle_status"]
		employees[employee_id] = employee
