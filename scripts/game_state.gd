extends Node

const WardrobeSimulationScript := preload("res://scripts/wardrobe_simulation.gd")
const GeneratedJobGeneratorScript := preload("res://scripts/generated_job_generator.gd")
const WorldMemoryScript := preload("res://scripts/world_memory.gd")

signal state_changed
signal coins_spent(amount: int)

const STARTING_EMPLOYEES: PackedStringArray = ["liliya", "grog", "boris"]
const EMPLOYEE_ORDER: PackedStringArray = ["liliya", "grog", "boris", "nika", "felix"]
const SAVE_VERSION: int = 31
const CLIENT_GREETING_PROFILE := preload("res://data/client_relationship_greetings.gd")
const RESTORATION_PROFILE := preload("res://data/restoration/faucet.tres")
const RESTORATION_REFUSAL_REVIEW := "Заменить уничтоженный кран отказались. Придётся искать другую службу."
const LEGACY_SAVE_PATH: String = "user://savegame.json"
const AUTOSAVE_PATH: String = "user://autosave.json"
const GENERATOR_HISTORY_PATH: String = "user://generator_history.cfg"
const SAVE_SLOT_COUNT: int = 5
const TRAVEL_TIME_MINUTES: int = 15
const WARDROBE_FIRE_DURATION_MINUTES: int = 15
const WARDROBE_FIRE_SPREAD_MINUTES: int = 5
const OVERDUE_PAYMENT_PENALTY: int = 100
const REPUTATION_RELIABLE_THRESHOLD: int = 35
const REPUTATION_LICENSE_RISK_THRESHOLD: int = 25
const ELEVATED_CLAIM_RISK_THRESHOLD: int = 300
const HIGH_CLAIM_RISK_THRESHOLD: int = 600
const DISMISSAL_CLAIM_THRESHOLD: int = 4
const DISMISSAL_DEBT_THRESHOLD: int = -800
const REAL_SECONDS_PER_GAME_MINUTE: float = 3.0
const DEMO_JOB_IDS: PackedStringArray = ["lava_leak", "walking_wardrobe", "portal_mirror", "sleeping_gargoyle", "escaped_ghost", "frozen_bath"]
const DEMO_CORE_JOB_IDS: PackedStringArray = ["lava_leak", "walking_wardrobe", "portal_mirror", "sleeping_gargoyle"]
const HIDDEN_LEGACY_JOB_IDS: PackedStringArray = ["lava_leak", "walking_wardrobe", "frozen_bath"]
const SUPPLY_ITEMS: Dictionary = {
	&"lunnopuh_cage": {
		"name": "Переносная клетка",
		"catalog_name": "Переносная клетка",
		"category": "Полевое снаряжение",
		"price": 250,
		"icon": "res://assets/objects/lunnopuh_cage/empty.png",
		"description": "Переносная магическая клетка, подойдёт для поимки маленького животного.",
		"reusable": true,
	},
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
		"solution_capability": "thermal_regulator",
	},
	&"protective_cloth": {
		"name": "Защитное полотно",
		"catalog_name": "Защитное полотно",
		"category": "Расходное снаряжение",
		"price": 50,
		"icon": "res://assets/objects/protective_cloth/folded.png",
		"description": "Плотная ткань с защитными рунами и латунными зажимами. Позволяет временно изолировать активный магический объект.",
		"consumable": true,
	},
	&"heat_gloves": {
		"name": "Термостойкие рукавицы",
		"catalog_name": "Термостойкие рукавицы",
		"category": "Многоразовое снаряжение",
		"price": 120,
		"icon": "res://assets/objects/equipment/heat_gloves.png",
		"description": "Защищают руки при кратковременном контакте с раскалёнными объектами. После покупки назначаются сотруднику на складе и не расходуются.",
		"reusable": true,
		"protects_from": ["contact_heat"],
		"eligible_employee_ids": ["boris"],
	},
	&"replacement_faucet": {
		"name": "Запасной магический кран",
		"catalog_name": "Запасной кран",
		"category": "Запасное оборудование",
		"price": 250,
		"icon": "res://assets/objects/lava_faucet/faucet_normal.png",
		"description": "Новый кран для замены механически сломанного или расплавленного оборудования. Устанавливается Борисом и расходуется при замене.",
		"consumable": true,
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
var tutorial_job_id: StringName = &"lava_leak"
var owned_supply_items: PackedStringArray = PackedStringArray()
var equipped_supply_items: Dictionary = {}
var completed_job_ids: PackedStringArray = PackedStringArray()
var job_reports: Array = []
var pending_job_report: Dictionary = {}
var demo_completion_seen: bool = false
var dismissal_triggered: bool = false
var dismissal_reason: StringName = &""
var dismissal_video_seen: bool = false
var financial_ledger: Array = []
var job_repair_states: Dictionary = {}
var tutorial_state: Dictionary = {}
var campaign_seed: int = 0
var next_generated_job_index: int = 0
var generated_jobs: Dictionary = {}
var world_memory: RefCounted = WorldMemoryScript.new()
var last_generated_anomaly_id: StringName = &""
var last_generated_faucet_anomaly_id: StringName = &""
var debug_next_wardrobe_anomaly: StringName = &""
var debug_next_mirror_anomaly: StringName = &""
var debug_tutorial_bypass_day: int = 0
var debug_skipped_job_ids: PackedStringArray = []
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


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not tutorial_state.is_empty():
		save_autosave()


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
		&"replace_faucet":
			return 6
		&"install_thermal_regulator":
			return 3
		&"normal_force", &"brute_force":
			return 3
		&"turn_valve":
			return 1
		&"anchor":
			return 6
		&"antimagic":
			return 1
		&"physical_move":
			if String(intent).ends_with("_fast"):
				return int(preload("res://data/wardrobe_employee_reactions.gd").MOVE_MODES["fast"]["duration"])
			if String(intent).ends_with("_careful"):
				return int(preload("res://data/wardrobe_employee_reactions.gd").MOVE_MODES["careful"]["duration"])
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
		"request_name": "Лилию",
		"access_refusal_phrase": "Я просил больше не присылать эту магичку",
		"apology_reference": "вашей магичке",
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
		"traits": "Наблюдательна, осторожна, любит точные формулировки",
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
		"request_name": "Грога",
		"access_refusal_phrase": "Я просил больше не присылать этого орка",
		"apology_reference": "вашему орку",
		"role": "Орк-такелажник",
		"portrait": "res://assets/portraits/employees/grog.png",
		"actor_neutral_pose": "res://assets/characters/employees/grog/full_body.png",
		"actor_work_pose": "res://assets/characters/employees/grog/work_pose.png",
		"actor_catch_pose": "res://assets/characters/employees/grog/catch_pose.png",
		"actor_walk_pose": "res://assets/characters/employees/grog/walk_pose_1.png",
		"actor_walk_pose_alt": "res://assets/characters/employees/grog/walk_pose_2.png",
		"actor_walk_pose_faces_right": true,
		"actor_hold_pose": "res://assets/characters/employees/grog/hold_pose.png",
		"actor_action_style": &"physical",
		"actor_work_pose_offset": Vector2.ZERO,
		"status": "Свободен",
		"idle_status": "Свободен",
		"abilities": PackedStringArray(["physical_move"]),
		"protections": PackedStringArray(["contact_heat"]),
		"training_categories": PackedStringArray(["physical"]),
		"max_special_abilities": 2,
		"core_actions": "Удержание и силовая работа",
		"description": "Такелажник для случаев, когда аварийный объект нужно удержать, передвинуть или убедительно поставить на место.",
		"strength": "Сильная сторона: сила, устойчивость и штатная защита рук от жара",
		"weakness": "Ограничение: тонкая магия — не его участок",
		"traits": "Надёжен, терпелив, бережёт казённый инструмент",
		"available": true,
	},
	&"boris": {
		"name": "Борис Медяк",
		"request_name": "Бориса",
		"role": "Мастер-сантехник",
		"portrait": "res://assets/portraits/employees/boris.png",
		"actor_neutral_pose": "res://assets/characters/employees/boris/full_body.png",
		"actor_walk_pose": "res://assets/characters/employees/boris/walk_pose_1.png",
		"actor_walk_pose_alt": "res://assets/characters/employees/boris/walk_pose_2.png",
		"actor_work_pose": "res://assets/characters/employees/boris/work_pose.png",
		"actor_catch_pose": "res://assets/characters/employees/boris/catch_pose.png",
		"actor_inspect_pose": "res://assets/characters/employees/boris/inspect_pose.png",
		"actor_heat_protected_work_pose": "res://assets/characters/employees/boris/heat_gloves_work_pose.png",
		"actor_action_style": &"physical",
		"status": "Свободен",
		"idle_status": "Свободен",
		"abilities": PackedStringArray(["diagnose", "repair"]),
		"training_categories": PackedStringArray(["technical"]),
		"max_special_abilities": 2,
		"can_forget_abilities": false,
		"core_actions": "Диагностика и точный ремонт",
		"description": "Опытный мастер по трубам, кранам и прочей инфраструктуре, которая обычно течёт в самый неподходящий момент.",
		"strength": "Сильная сторона: аккуратный обычный ремонт",
		"weakness": "Ограничение: не работает с чарами напрямую",
		"traits": "Практичен, экономен, не доверяет говорящим вентилям",
		"action_reactions": [
			{"action_ids": ["repair", "anchor"], "object_equals": {"burning": true}, "text": "Горящее не ремонтируют. Сначала тушим."},
			{"action_ids": ["repair"], "required_tags": ["lava_flowing"], "text": "Сначала остановите поток лавы."},
		],
		"available": true,
	},
	&"nika": {
		"name": "Ника Искра",
		"request_name": "Нику",
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
		"traits": "Любознательна, энергична, ведёт слишком подробные записи",
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
		"request_name": "Феликса",
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
		"traits": "Методичен, невозмутим, замечает нарушения с порога",
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
				"Магическое нарушение устранено. Протокол доволен, клиент — посмотрим.",
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
		"danger": "Лава, высокая температура",
		"base_reward": 500,
		"repair_scene": "res://scenes/RepairHouse.tscn",
		"object_definition_id": &"lava_faucet",
		"simulation_type": &"lava_faucet",
		"tutorial_eligible": false,
		"tutorial_required_ability_sets": [PackedStringArray(["freeze"])],
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
		"danger": "Магия, шум",
		"base_reward": 420,
		"repair_scene": "res://scenes/WardrobeRoom.tscn",
		"assigned": PackedStringArray(),
	},
	&"portal_mirror": {
		"title": "В зеркале открылся портал",
		"object_initial_state": preload("res://data/anomalies/open_portal.tres").initial_state,
		"object_goal": preload("res://data/anomalies/open_portal.tres").resolution,
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
		"danger": "Магия, портал",
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
		"danger": "Магия, затопление",
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
		"danger": "Магия, привидение",
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
		"danger": "Холод, бытовая магия",
		"base_reward": 260,
		"repair_scene": "res://scenes/FrozenBathRoom.tscn",
		"assigned": PackedStringArray(),
	},
}


var loading_game: bool = false
var legacy_mirror_job: Dictionary = jobs[&"portal_mirror"].duplicate(true)


func assign_employee(employee_id: StringName, job_id: StringName) -> void:
	if not employees.has(employee_id) or not jobs.has(job_id):
		return
	if not is_job_available(job_id):
		return
	if not employees[employee_id]["available"]:
		return
	if is_employee_injured(employee_id):
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
	coins_spent.emit(hire_cost)
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
	coins_spent.emit(price)
	owned_supply_items.append(String(item_id))
	_record_financial_event(&"purchase", -price, str(item["name"]), {"item_id": String(item_id)})
	state_changed.emit()
	return true


func has_supply_item(item_id: StringName) -> bool:
	return owned_supply_items.has(String(item_id))


func equip_supply_item(item_id: StringName, employee_id: StringName) -> bool:
	if not has_supply_item(item_id) or not employees.has(employee_id):
		return false
	var eligible_ids := PackedStringArray(SUPPLY_ITEMS[item_id].get("eligible_employee_ids", []))
	if not eligible_ids.has(String(employee_id)):
		return false
	equipped_supply_items[String(item_id)] = String(employee_id)
	state_changed.emit()
	save_autosave()
	return true


func unequip_supply_item(item_id: StringName) -> bool:
	if not equipped_supply_items.has(String(item_id)):
		return false
	equipped_supply_items.erase(String(item_id))
	state_changed.emit()
	save_autosave()
	return true


func get_equipped_employee(item_id: StringName) -> StringName:
	return StringName(str(equipped_supply_items.get(String(item_id), "")))


func is_supply_equipped_by(item_id: StringName, employee_id: StringName) -> bool:
	return get_equipped_employee(item_id) == employee_id


func get_employee_with_equipment(employee_id: StringName) -> Dictionary:
	var result: Dictionary = (employees.get(employee_id, {}) as Dictionary).duplicate(true)
	var protections := PackedStringArray(result.get("protections", PackedStringArray()))
	for item_id_value: Variant in equipped_supply_items:
		var item_id := StringName(str(item_id_value))
		if get_equipped_employee(item_id) != employee_id or not SUPPLY_ITEMS.has(item_id):
			continue
		for protection_value: Variant in SUPPLY_ITEMS[item_id].get("protects_from", []):
			var protection := str(protection_value)
			if not protections.has(protection):
				protections.append(protection)
	result["protections"] = protections
	return result


func injure_employee(employee_id: StringName, recovery_days: int = 1) -> void:
	if not employees.has(employee_id):
		return
	var employee: Dictionary = employees[employee_id]
	employee["injured_until_day"] = maxi(int(employee.get("injured_until_day", 0)), day + maxi(1, recovery_days))
	employee["status"] = "Лечит ожоги до следующего дня"
	employees[employee_id] = employee
	state_changed.emit()
	save_autosave()


func is_employee_injured(employee_id: StringName) -> bool:
	return employees.has(employee_id) and day < int(employees[employee_id].get("injured_until_day", 0))


func consume_supply_item(item_id: StringName) -> bool:
	var item_index := owned_supply_items.find(String(item_id))
	if item_index < 0:
		return false
	owned_supply_items.remove_at(item_index)
	equipped_supply_items.erase(String(item_id))
	state_changed.emit()
	return true


func return_supply_item(item_id: StringName) -> void:
	if not SUPPLY_ITEMS.has(item_id) or owned_supply_items.has(String(item_id)):
		return
	owned_supply_items.append(String(item_id))
	state_changed.emit()


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
	if is_tutorial_job_completed() or debug_tutorial_bypass_day > 0:
		_update_parallel_job_unlocks()
	_unlock_gargoyle_job_if_due()
	_unlock_escaped_ghost_job_if_due()
	_unlock_frozen_bath_job_if_due()
	_publish_due_world_consequences()
	_publish_due_restoration_jobs()
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
	save_autosave()
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
	employee["status"] = tr("Учится: %s") % tr(str(TRAINING_DEFINITIONS[training_id]["name"]))
	employees[employee_id] = employee
	state_changed.emit()
	save_autosave()
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
	if not bool(employee.get("can_forget_abilities", true)):
		return &"protected"
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
	# Старые сценарные заявки сохранены для совместимости сохранений и тестовых сцен,
	# но больше не участвуют в генеративном цикле и не показываются игроку.
	if HIDDEN_LEGACY_JOB_IDS.has(String(job_id)):
		return false
	if OS.is_debug_build() and debug_skipped_job_ids.has(String(job_id)):
		return false
	return jobs.has(job_id) and bool(jobs[job_id].get("unlocked", false)) and not completed_job_ids.has(String(job_id))


func is_employee_banned_for_job(employee_id: StringName, job_id: StringName) -> bool:
	return get_employee_access_status_for_job(employee_id, job_id) == &"banned"


func get_employee_relation_for_job(employee_id: StringName, job_id: StringName) -> Dictionary:
	if not jobs.has(job_id):
		return {}
	var job: Dictionary = jobs[job_id]
	var resident_id := str((job.get("generated_instance", {}) as Dictionary).get("resident_id", job.get("resident", "")))
	return world_memory.get_relation(resident_id, String(employee_id))


func _preferred_employee_for_resident(resident_id: String) -> StringName:
	var best_id: StringName = &""
	var best_weight := 0
	var best_trust := 0
	var employee_ids: Array = employees.keys()
	employee_ids.sort()
	for employee_id: StringName in employee_ids:
		if not bool(employees[employee_id].get("available", false)):
			continue
		var relation: Dictionary = world_memory.get_relation(resident_id, String(employee_id))
		var weight := int(relation.get("preference_weight", 0))
		var trust := int(relation.get("professional_trust", 0))
		if str(relation.get("access_status", "allowed")) == "banned" or trust < 20 or weight <= 0:
			continue
		if weight > best_weight or (weight == best_weight and trust > best_trust):
			best_id = employee_id
			best_weight = weight
			best_trust = trust
	return best_id


func get_preferred_employee_for_job(job_id: StringName) -> StringName:
	if not jobs.has(job_id):
		return &""
	var job: Dictionary = jobs[job_id]
	var instance: Dictionary = job.get("generated_instance", {})
	var resident_id := str(instance.get("resident_id", job.get("resident", "")))
	var employee_id := StringName(str(instance.get("preferred_employee_id", _preferred_employee_for_resident(resident_id))))
	if not employees.has(employee_id) or not bool(employees[employee_id].get("available", false)) or is_employee_banned_for_job(employee_id, job_id):
		return &""
	return employee_id


func get_preferred_employee_request(job_id: StringName) -> String:
	var employee_id := get_preferred_employee_for_job(job_id)
	if employee_id.is_empty():
		return ""
	var employee: Dictionary = employees[employee_id]
	return tr("%s просит прислать %s") % [tr(str(jobs[job_id]["resident"])), tr(str(employee.get("request_name", employee["name"])))]


func get_apology_availability(resident_id: String, employee_id: StringName) -> StringName:
	if not employees.has(employee_id) or not bool(employees[employee_id].get("available", false)):
		return &"unavailable"
	var relation: Dictionary = world_memory.get_relation(resident_id, String(employee_id))
	if str(relation.get("access_status", "allowed")) != "banned":
		return &"not_banned"
	var damage_job_ids := PackedStringArray()
	for memory: Dictionary in relation.get("memories", []):
		if str(memory.get("event", "")) in ["destroyed_property", "caused_damage"]:
			damage_job_ids.append(str(memory.get("job_id", "")))
	var latest_damage_index := -1
	var settled_after_count := 0
	for index in job_reports.size():
		var report: Dictionary = job_reports[index]
		if str(report.get("resident_id", report.get("resident", ""))) != resident_id:
			continue
		var actors: Variant = report.get("damage_employee_ids", [])
		if not actors.has(String(employee_id)) and not damage_job_ids.has(str(report.get("job_id", ""))):
			continue
		latest_damage_index = index
		if int(report.get("claim_amount", 0)) > 0 and str(report.get("claim_status", "none")) not in ["paid", "paid_after_denial", "settled_by_restoration"] and not bool(report.get("property_restored", false)):
			return &"unsettled_damage"
		settled_after_count = maxi(settled_after_count, int(report.get("claim_settled_report_count", index + 1)))
	if latest_damage_index < 0:
		return &"unsettled_damage"
	if int(relation.get("apology_count", 0)) == 0:
		return &"available"
	for index in range(maxi(latest_damage_index + 1, settled_after_count), job_reports.size()):
		var report: Dictionary = job_reports[index]
		if str(report.get("resident_id", report.get("resident", ""))) != resident_id:
			continue
		var crew: Variant = report.get("crew_ids", [])
		var actors: Variant = report.get("damage_employee_ids", [])
		if crew.is_empty() or crew.has(String(employee_id)) or not actors.is_empty():
			continue
		if int(report.get("rating", 0)) >= 4 and not bool(report.get("overdue", false)) and int(report.get("claim_amount", 0)) == 0 and not bool(report.get("restoration_refused", false)) and not bool(report.get("object_destroyed", false)) and (not bool(report.get("payment_forfeited", false)) or bool(report.get("restoration", false))):
			return &"available"
	return &"needs_other_crew_work"


func apologize_to_resident(resident_id: String, employee_id: StringName) -> bool:
	if get_apology_availability(resident_id, employee_id) != &"available":
		return false
	if not world_memory.accept_apology(resident_id, String(employee_id), day):
		return false
	state_changed.emit()
	save_autosave()
	return true


func debug_skip_day() -> bool:
	if not OS.is_debug_build() or not active_job_id.is_empty():
		return false
	for job_id: StringName in jobs:
		if bool(jobs[job_id].get("dispatched", false)) and not completed_job_ids.has(String(job_id)):
			return false
	# Пропускаем только доступные этапы, не создавая результатов выполненной работы.
	for stage_id: StringName in [GeneratedJobGeneratorScript.JOB_ID, &"sleeping_gargoyle"]:
		if is_job_available(stage_id):
			debug_skipped_job_ids.append(String(stage_id))
			jobs[stage_id]["assigned"] = PackedStringArray()
	if not is_tutorial_job_completed() and debug_tutorial_bypass_day == 0:
		debug_tutorial_bypass_day = day
		_set_job_unlocked(tutorial_job_id, false)
		tutorial_state = {"version": 1, "status": "skipped", "step": ""}
	clock_paused = true
	advance_day()
	save_autosave()
	return true


func get_apology_reply(resident_id: String, employee_id: StringName) -> String:
	var restored_property := false
	for report: Dictionary in job_reports:
		var actors: Variant = report.get("damage_employee_ids", [])
		if str(report.get("resident_id", report.get("resident", ""))) == resident_id and actors.has(String(employee_id)):
			restored_property = bool(report.get("property_restored", false))
	var opening := "Кран заменили." if restored_property else "Ущерб возмещён."
	return "%s Ладно, дам %s ещё один шанс. Но рассчитываю, что больше ничего не пострадает." % [opening, str(employees[employee_id].get("apology_reference", "этому сотруднику"))]


func get_employee_resident_memory(employee_id: StringName) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for resident_id: Variant in world_memory.resident_relations:
		var relation: Dictionary = world_memory.get_relation(str(resident_id), String(employee_id))
		if (relation.get("memories", []) as Array).is_empty():
			continue
		var resident_name := str(resident_id)
		for report: Dictionary in job_reports:
			if str(report.get("resident_id", report.get("resident", ""))) == str(resident_id):
				resident_name = str(report.get("resident", resident_name))
				break
		entries.append({"resident_id": str(resident_id), "resident_name": resident_name, "relation": relation})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["resident_name"]) < str(b["resident_name"]))
	return entries


func get_employee_access_status_for_job(employee_id: StringName, job_id: StringName) -> StringName:
	if not jobs.has(job_id):
		return &"allowed"
	var job: Dictionary = jobs[job_id]
	var generated_instance: Dictionary = job.get("generated_instance", {}) as Dictionary
	var resident_id := str(generated_instance.get("resident_id", job.get("resident", "")))
	var relation: Dictionary = world_memory.get_relation(resident_id, String(employee_id))
	return StringName(str(relation.get("access_status", "allowed")))


func get_tutorial_job_id() -> StringName:
	return tutorial_job_id


func is_tutorial_job(job_id: StringName) -> bool:
	return not tutorial_job_id.is_empty() and job_id == tutorial_job_id


func is_tutorial_job_completed() -> bool:
	return not tutorial_job_id.is_empty() and completed_job_ids.has(String(tutorial_job_id))


func is_faucet_job(job_id: StringName) -> bool:
	if not jobs.has(job_id):
		return false
	return StringName(str((jobs[job_id] as Dictionary).get("simulation_type", ""))) == &"lava_faucet"


func is_job_dispatched(job_id: StringName) -> bool:
	return jobs.has(job_id) and bool(jobs[job_id].get("dispatched", false))


func is_employee_returning(employee_id: StringName) -> bool:
	return employees.has(employee_id) and int(employees[employee_id].get("return_until", 0)) > time_minutes


func can_employee_work_on_job(employee_id: StringName, job_id: StringName) -> bool:
	if is_employee_banned_for_job(employee_id, job_id) and not _ban_started_during_current_visit(employee_id, job_id):
		return false
	if get_employee_job(employee_id) != job_id or not is_job_dispatched(job_id):
		return false
	if is_employee_injured(employee_id):
		return false
	return int(employees[employee_id].get("arrival_until", 0)) <= time_minutes


func _ban_started_during_current_visit(employee_id: StringName, job_id: StringName) -> bool:
	# Запрет относится к следующему входу, не выгоняет уже допущенного
	# сотрудника посреди устранения аварии.
	var context: Dictionary = world_memory.job_contexts.get(String(job_id), {}) as Dictionary
	return (context.get("current_visit_ban_exemptions", []) as Array).has(String(employee_id))


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
	save_autosave()
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
	save_autosave()


func advance_time(minutes: int, excluded_job_id: StringName = &"") -> PackedStringArray:
	var newly_overdue := PackedStringArray()
	if minutes <= 0:
		return newly_overdue
	var previous_clock := time_minutes
	time_minutes += minutes
	_process_timed_job_consequences()
	var employee_arrived := false
	for employee_id: StringName in employees:
		var arrival_until := int(employees[employee_id].get("arrival_until", 0))
		if arrival_until > previous_clock and arrival_until <= time_minutes:
			employee_arrived = true
	_process_resident_access()
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
	if employee_arrived or not newly_overdue.is_empty():
		save_autosave()
	return newly_overdue


func _process_timed_job_consequences() -> void:
	for job_id: StringName in jobs:
		var job: Dictionary = jobs[job_id]
		if str(job.get("simulation_type", "")) == "cold_trace" and active_job_id != job_id and not completed_job_ids.has(String(job_id)):
			var bath_state: Dictionary = get_job_repair_state(job_id)
			if not bath_state.is_empty():
				var bath_simulation: RefCounted = load("res://scripts/frozen_bath_simulation.gd").new()
				bath_simulation.load_state(bath_state)
				bath_simulation.advance_flow_until(time_minutes)
				set_job_repair_state(job_id, bath_simulation.get_state())
			continue
		var is_wardrobe_job: bool = job_id == &"walking_wardrobe" or StringName(str(job.get("simulation_type", ""))) == &"generated_wardrobe"
		if not is_wardrobe_job:
			continue
		# Пока игрок находится на объекте, стадии огня и реакция хозяйки
		# обрабатываются комнатой. Глобальный расчёт нужен только вне объекта.
		if active_job_id == job_id or completed_job_ids.has(String(job_id)):
			continue
		var saved_state := get_job_repair_state(job_id)
		if saved_state.is_empty():
			continue
		var simulation: RefCounted = WardrobeSimulationScript.new()
		simulation.load_state(saved_state)
		if not bool(simulation.world_object.get("burning", false)):
			continue
		var results: Array[Dictionary] = simulation.advance_burning_until(time_minutes, WARDROBE_FIRE_SPREAD_MINUTES)
		if results.is_empty():
			continue
		set_job_repair_state(job_id, simulation.get_state())
		if simulation.is_resolved():
			var completion: Dictionary = simulation.get_completion_result()
			completion["summary"] = "Пока бригада отсутствовала, оставленный без присмотра пожар уничтожил шкаф и посуду. Оплаты не будет; хозяйка предъявила службе претензию."
			completion["review"] = "Вы уехали и оставили мой шкаф гореть! Когда я дозвонилась до службы, от него и всей посуды уже остался один пепел."
			completion["incident_message"] = "Срочное сообщение: оставленный без присмотра шкаф полностью сгорел. Хозяйка требует объяснений и компенсации."
			complete_job(job_id, completion)


func get_job_repair_state(job_id: StringName) -> Dictionary:
	var state: Variant = job_repair_states.get(String(job_id), {})
	if state is Dictionary:
		var state_dictionary: Dictionary = state
		return state_dictionary.duplicate(true)
	return {}


func set_job_repair_state(job_id: StringName, repair_state: Dictionary) -> void:
	var inspected: Array = get_job_repair_state(job_id).get("boris_inspected_objects", [])
	var merged_inspected: Array = (repair_state.get("boris_inspected_objects", []) as Array).duplicate()
	for object_name: Variant in inspected:
		if not merged_inspected.has(object_name):
			merged_inspected.append(object_name)
	repair_state["boris_inspected_objects"] = merged_inspected
	if not jobs.has(job_id) or completed_job_ids.has(String(job_id)):
		return
	var job: Dictionary = jobs[job_id]
	var generated_instance: Dictionary = job.get("generated_instance", {}) as Dictionary
	var initial_properties: Dictionary = generated_instance.get("initial_state", {}) as Dictionary
	var object_instance_id := str(generated_instance.get("object_instance_id", ""))
	var memory_metadata := generated_instance.duplicate(true)
	memory_metadata["resident_id"] = str(generated_instance.get("resident_id", job.get("resident", "")))
	world_memory.ensure_job_context(job_id, initial_properties, object_instance_id, memory_metadata)
	# Старые контексты сохранений ещё не содержат клиента.
	(world_memory.job_contexts[String(job_id)] as Dictionary)["resident_id"] = memory_metadata["resident_id"]
	job_repair_states[String(job_id)] = repair_state.duplicate(true)
	var previous_bans: Array = ((world_memory.job_contexts[String(job_id)] as Dictionary).get("newly_banned_employee_ids", []) as Array).duplicate()
	world_memory.record_job_state(job_id, repair_state, day, time_minutes)
	var context: Dictionary = world_memory.job_contexts[String(job_id)] as Dictionary
	var exemptions: Array = context.get("current_visit_ban_exemptions", []) as Array
	for employee_id: String in context.get("newly_banned_employee_ids", []):
		if not previous_bans.has(employee_id) and job.get("assigned", PackedStringArray()).has(employee_id) and int(employees[StringName(employee_id)].get("arrival_until", 0)) <= time_minutes:
			if not exemptions.has(employee_id):
				exemptions.append(employee_id)
	context["current_visit_ban_exemptions"] = exemptions
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
	save_autosave()
	return true


func leave_active_job() -> void:
	active_job_id = &""
	state_changed.emit()
	save_autosave()


func recall_job(job_id: StringName) -> bool:
	if not is_job_available(job_id) or not is_job_dispatched(job_id):
		return false
	if not get_pending_job_action(job_id).is_empty():
		return false
	var job: Dictionary = jobs[job_id]
	var memory_context: Dictionary = world_memory.job_contexts.get(String(job_id), {}) as Dictionary
	memory_context["current_visit_ban_exemptions"] = []
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
	return complete_job(active_job_id, result)


func complete_job(job_id: StringName, result: Dictionary = {}) -> bool:
	if job_id.is_empty() or not jobs.has(job_id):
		return false
	if not get_pending_job_action(job_id).is_empty():
		return false
	var completed_id: StringName = job_id
	if completed_job_ids.has(String(completed_id)):
		return false
	var job: Dictionary = jobs[completed_id]
	if bool(job.get("restoration", false)) and not bool(result.get("restoration_refused", false)):
		var repair_state := get_job_repair_state(job_id)
		var restoration_check: RefCounted = load("res://scripts/repair_simulation.gd").new()
		restoration_check.initialize_from_job(job)
		restoration_check.load_state(repair_state)
		if repair_state.is_empty() or not restoration_check.is_resolved():
			return false
		result = result.duplicate(true)
		result["reputation_change"] = _settle_restoration(job)
		result["reward_adjustment"] = 0
		result["compensation_cost"] = 0
		result["forfeit_payment"] = not _restoration_is_paid(job)
		result["expense_reimbursement"] = int(SUPPLY_ITEMS[&"replacement_faucet"]["price"]) if _restoration_is_paid(job) else 0
		job["base_reward"] = int(RESTORATION_PROFILE.base_properties["installation_fee"]) if _restoration_is_paid(job) else 0
	for retained_item: Variant in result.get("retained_supply_items", []):
		consume_supply_item(StringName(str(retained_item)))
	for returned_item: Variant in result.get("returned_supply_items", []):
		return_supply_item(StringName(str(returned_item)))
	var completion_updates: Dictionary = result.get("completion_object_updates", {})
	if not completion_updates.is_empty():
		var final_repair_state := get_job_repair_state(job_id).duplicate(true)
		var final_object: Dictionary = final_repair_state.get("world_object", {})
		final_object.merge(completion_updates, true)
		final_repair_state["world_object"] = final_object
		var final_related: Dictionary = final_repair_state.get("related_objects", {})
		var related_updates: Dictionary = result.get("completion_related_updates", {})
		for instance_id: Variant in related_updates:
			var related_object: Dictionary = final_related.get(instance_id, {})
			related_object.merge(related_updates[instance_id], true)
			final_related[instance_id] = related_object
		final_repair_state["related_objects"] = final_related
		set_job_repair_state(job_id, final_repair_state)
	var base_reward: int = int(job.get("base_reward", 0))
	var overdue: bool = bool(job.get("overdue", false))
	var reward_adjustment: int = int(result.get("reward_adjustment", 0)) - (OVERDUE_PAYMENT_PENALTY if overdue else 0)
	var expense_reimbursement: int = maxi(0, int(result.get("expense_reimbursement", 0)))
	var payment_forfeited: bool = bool(result.get("forfeit_payment", false))
	var reward: int = 0 if payment_forfeited else maxi(0, base_reward + reward_adjustment + expense_reimbursement)
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
	var damage_employee_ids := PackedStringArray()
	var damage_severity_by_employee: Dictionary = {}
	var action_events: Variant = result.get("actions", [])
	if action_events is Array:
		for action_event: Variant in action_events:
			if not action_event is Dictionary:
				continue
			var action_dictionary: Dictionary = action_event
			var action_result: Dictionary = action_dictionary.get("result", {}) as Dictionary
			var responsible_employee_id := str(action_dictionary.get("employee_id", ""))
			if bool(action_result.get("caused_damage", false)) and not responsible_employee_id.is_empty() and not damage_employee_ids.has(responsible_employee_id):
				damage_employee_ids.append(responsible_employee_id)
			if bool(action_result.get("caused_damage", false)) and not responsible_employee_id.is_empty() and action_result.has("destroyed_target_ids"):
				var severity := 2 if not (action_result["destroyed_target_ids"] as Array).is_empty() else 1
				damage_severity_by_employee[responsible_employee_id] = maxi(int(damage_severity_by_employee.get(responsible_employee_id, 0)), severity)
	completed_job_ids.append(String(completed_id))
	job["assigned"] = PackedStringArray()
	job["dispatched"] = false
	jobs[completed_id] = job
	var summary: String = str(result.get("summary", "Аварийные работы приняты."))
	if overdue:
		summary += tr(" Заявка выполнена после истечения срока: из оплаты удержано %d монет.") % OVERDUE_PAYMENT_PENALTY
	var completed_report: Dictionary = {
		"job_id": String(completed_id),
		"title": str(job["title"]),
		"resident": str(job["resident"]),
		"resident_id": str((job.get("generated_instance", {}) as Dictionary).get("resident_id", job["resident"])),
		"anomaly_id": str((job.get("generated_instance", {}) as Dictionary).get("anomaly_id", "")),
		"object_instance_id": str((job.get("generated_instance", {}) as Dictionary).get("object_instance_id", "")),
		"object_definition_id": str(job.get("object_definition_id", "")),
		"reward": reward,
		"base_reward": base_reward,
		"reward_adjustment": reward_adjustment,
		"expense_reimbursement": expense_reimbursement,
		"payment_forfeited": payment_forfeited,
		"maximum_payment": reward_adjustment == 0 and compensation == 0 and not payment_forfeited,
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
		"crew_ids": Array(assigned),
		"successful_employee_ids": result.get("successful_employee_ids", []),
		"credit_helpful_work_on_damage": bool(result.get("credit_helpful_work_on_damage", false)),
		"damage_employee_ids": Array(damage_employee_ids),
		"damage_severity_by_employee": damage_severity_by_employee,
		"object_destroyed": bool(result.get("object_destroyed", false)),
		"contents_state": str(result.get("contents_state", "")),
		"contents_damage": int(result.get("contents_damage", 0)),
		"restoration": bool(job.get("restoration", false)),
		"restoration_refused": bool(result.get("restoration_refused", false)),
		"job_refused": bool(result.get("job_refused", false)),
		"source_job_id": str(job.get("source_job_id", "")),
		"summary": summary,
		"review": str(result.get("review", "")),
		"consequences": result.get("consequences", []),
		"overdue": overdue,
		"follow_up": result.get("follow_up", {}),
		"actions": result.get("actions", []),
		"incident_message": str(result.get("incident_message", "")),
		"report_acknowledged": false,
	}
	if job_repair_states.has(String(completed_id)):
		world_memory.record_job_state(completed_id, job_repair_states[String(completed_id)], day, time_minutes)
	var world_result := result.duplicate(true)
	world_result["relationship_tone"] = "appreciative" if int(completed_report.get("rating", 0)) >= 4 and not overdue and compensation == 0 and not payment_forfeited else "neutral"
	var observed_bans: Array = (world_memory.job_contexts.get(String(completed_id), {}) as Dictionary).get("newly_banned_employee_ids", []) as Array
	world_memory.finalize_job(completed_id, world_result, day, time_minutes)
	var newly_banned_ids: Array[String] = world_memory.evaluate_crew_relations(completed_report)
	for employee_id: String in observed_bans:
		if not newly_banned_ids.has(employee_id):
			newly_banned_ids.append(employee_id)
	completed_report["relations_recorded"] = true
	var access_notes := PackedStringArray()
	for employee_id: String in newly_banned_ids:
		var banned_employee: Dictionary = employees.get(StringName(employee_id), {}) as Dictionary
		access_notes.append(tr("%s: запрещён вход в квартиру сотруднику %s.") % [tr(str(job.get("resident", "Клиент"))), tr(str(banned_employee.get("name", employee_id)))])
	if not access_notes.is_empty():
		completed_report["summary"] = summary + "\n\n" + "\n".join(access_notes)
	completed_report["newly_banned_employee_ids"] = newly_banned_ids
	job_reports.append(completed_report.duplicate(true))
	var source_deferred_event_id := str(job.get("source_deferred_event_id", ""))
	if not source_deferred_event_id.is_empty():
		world_memory.set_event_status(source_deferred_event_id, "resolved", {"resolved_job_id": String(completed_id)})
	if completed_id in [&"frozen_bath", &"escaped_ghost"]:
		world_memory.set_consequence_status(completed_id, "resolved")
	if pending_job_report.is_empty():
		pending_job_report = completed_report.duplicate(true)
	_record_financial_event(&"job", reward, str(job["title"]), {
		"job_id": String(completed_id), "income": reward, "expense": 0,
		"claim_amount": compensation, "claim_status": "pending" if compensation > 0 else "none",
		"completed_day": day, "completed_time": time_minutes,
	})
	job_repair_states.erase(String(completed_id))
	if active_job_id == completed_id:
		active_job_id = &""
	_update_employee_statuses()
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager != null and audio_manager.has_method(&"play_task_complete"):
		audio_manager.call(&"play_task_complete")
	state_changed.emit()
	save_autosave()
	return true


func get_resident_greeting(job_id: StringName, default_request: String = "") -> String:
	var personal_greeting := _get_relationship_greeting(job_id)
	if not personal_greeting.is_empty():
		return personal_greeting
	if not default_request.is_empty():
		return default_request
	var current_job: Dictionary = jobs.get(job_id, {})
	var history: Array[Dictionary] = []
	for report_value: Variant in job_reports:
		if report_value is Dictionary and str(report_value.get("resident", "")) == str(current_job.get("resident", "")):
			history.append(report_value)
	if history.is_empty():
		return "Здравствуйте. Вот такая у меня неприятность."
	var previous: Dictionary = history.back()
	var source_job_id := str(current_job.get("source_job_id", ""))
	if not source_job_id.is_empty():
		for report: Dictionary in history:
			if str(report.get("job_id", "")) == source_job_id:
				previous = report
	var damaged := int(previous.get("claim_amount", 0)) > 0 or int(previous.get("reward_adjustment", 0)) < 0
	if damaged:
		return "Здравствуйте. Надеюсь, в этот раз обойдётся без повреждений."
	var successful := int(previous.get("rating", 0)) >= 4 and not bool(previous.get("overdue", false)) and not bool(previous.get("payment_forfeited", false))
	if not successful:
		return "Снова здравствуйте. У меня новая неприятность."
	if bool(current_job.get("consequence", false)):
		var source_anomaly := str(previous.get("anomaly_id", ""))
		var current_anomaly := str((current_job.get("generated_instance", {}) as Dictionary).get("anomaly_id", ""))
		var thanks: Dictionary = {"faucet_freeze": "Спасибо, что в прошлый раз убрали лёд.", "faucet_overheat": "Спасибо, что в прошлый раз охладили кран.", "lava_leak": "Спасибо, что в прошлый раз остановили лаву."}
		var problems: Dictionary = {"faucet_freeze": "Теперь этот же кран начал покрываться льдом.", "faucet_overheat": "Теперь этот же кран начал сам нагреваться."}
		return str(thanks.get(source_anomaly, "В прошлый раз вы помогли, спасибо.")) + " " + str(problems.get(current_anomaly, "Теперь с тем же объектом происходит что-то новое — посмотрите."))
	return "Рад снова вас видеть. В прошлый раз вы здорово помогли."


func _get_relationship_greeting(job_id: StringName) -> String:
	if not jobs.has(job_id):
		return ""
	var pools: Dictionary = CLIENT_GREETING_PROFILE.POOLS
	var best: Dictionary = {}
	var preferred := get_preferred_employee_for_job(job_id)
	# Stable tie-breaking; only employees admitted and already on site qualify.
	for employee_id: StringName in EMPLOYEE_ORDER:
		if not jobs[job_id].get("assigned", PackedStringArray()).has(String(employee_id)):
			continue
		if not can_employee_work_on_job(employee_id, job_id):
			continue
		var relation := get_employee_relation_for_job(employee_id, job_id)
		for pool_id: String in pools:
			var pool: Dictionary = pools[pool_id]
			if pool.has("access_status"):
				if str(relation.get("access_status", "allowed")) != str(pool["access_status"]):
					continue
			elif int(relation.get("professional_trust", 0)) < int(pool.get("minimum_trust", 1)):
				continue
			var score := int(pool["priority"]) * 1000000 + (100000 if employee_id == preferred else 0) + int(relation.get("professional_trust", 0))
			if best.is_empty() or score > int(best["score"]):
				best = {"employee_id": employee_id, "pool_id": pool_id, "score": score}
	if best.is_empty():
		return ""
	var employee_id: StringName = best["employee_id"]
	var pool_id: String = best["pool_id"]
	var job: Dictionary = jobs[job_id]
	var resident_id := str((job.get("generated_instance", {}) as Dictionary).get("resident_id", job.get("resident", "")))
	var relation: Dictionary = world_memory.get_or_create_relation(resident_id, String(employee_id))
	var previous := str(relation.get("last_greeting_template", ""))
	var candidates := PackedStringArray()
	for phrase: String in pools[pool_id]["phrases"]:
		if phrase != previous:
			candidates.append(phrase)
	if candidates.is_empty():
		return ""
	var template := candidates[randi_range(0, candidates.size() - 1)]
	relation["last_greeting_template"] = template
	var employee_name := tr(str(employees[employee_id]["name"])).get_slice(" ", 0)
	return tr(template).replace("{Имя}", employee_name)


func dismiss_pending_job_report() -> void:
	if str(pending_job_report.get("claim_status", "none")) == "pending":
		return
	pending_job_report["report_acknowledged"] = true
	_sync_pending_report_to_history()
	pending_job_report = {}
	_show_next_pending_job_report()
	state_changed.emit()


func _show_next_pending_job_report() -> void:
	if not pending_job_report.is_empty():
		return
	for report_value: Variant in job_reports:
		if report_value is Dictionary and not bool((report_value as Dictionary).get("report_acknowledged", true)):
			pending_job_report = (report_value as Dictionary).duplicate(true)
			return


func is_demo_complete() -> bool:
	for job_id: String in get_demo_required_job_ids():
		if not completed_job_ids.has(job_id):
			return false
	return true


func get_demo_required_job_ids() -> PackedStringArray:
	var required := DEMO_CORE_JOB_IDS.duplicate()
	var first_job_index := required.find("lava_leak")
	if first_job_index >= 0 and not tutorial_job_id.is_empty():
		required[first_job_index] = String(tutorial_job_id)
	var wardrobe_index := required.find("walking_wardrobe")
	if wardrobe_index >= 0 and jobs.has(GeneratedJobGeneratorScript.JOB_ID):
		required[wardrobe_index] = String(GeneratedJobGeneratorScript.JOB_ID)
	for report_value: Variant in job_reports:
		if not report_value is Dictionary:
			continue
		var follow_up: Variant = (report_value as Dictionary).get("follow_up", {})
		if not follow_up is Dictionary:
			continue
		var follow_up_id := str((follow_up as Dictionary).get("type", ""))
		if follow_up_id in ["escaped_ghost", "frozen_bath"] and not required.has(follow_up_id):
			required.append(follow_up_id)
	return required


func should_show_demo_completion() -> bool:
	return not dismissal_triggered and is_demo_complete() and pending_job_report.is_empty() and not demo_completion_seen


func should_play_dismissal_video() -> bool:
	return dismissal_triggered and not dismissal_video_seen and pending_job_report.is_empty()


func should_show_dismissal_document() -> bool:
	return dismissal_triggered and dismissal_video_seen and pending_job_report.is_empty()


func mark_dismissal_video_seen() -> void:
	if dismissal_video_seen:
		return
	dismissal_video_seen = true
	state_changed.emit()
	save_autosave()


func get_confirmed_claim_count() -> int:
	var count := 0
	for report_value: Variant in job_reports:
		if not report_value is Dictionary:
			continue
		var report: Dictionary = report_value
		if int(report.get("claim_amount", 0)) > 0 and str(report.get("claim_status", "none")) in ["paid", "denied", "paid_after_denial"]:
			count += 1
	return count


func get_dismissal_reason_text() -> String:
	match dismissal_reason:
		&"claims_and_debt":
			return "Систематический ущерб имуществу жителей и критическая задолженность службы."
		&"claims":
			return "Четыре подтверждённые претензии жителей к работе службы."
		&"debt":
			return tr("Критическая задолженность службы: %d монет.") % absi(money)
	return "Городская инспекция признала дальнейшее руководство службой невозможным."


func _evaluate_dismissal() -> void:
	if dismissal_triggered:
		return
	var too_many_claims := get_confirmed_claim_count() >= DISMISSAL_CLAIM_THRESHOLD
	var critical_debt := money <= DISMISSAL_DEBT_THRESHOLD
	if not too_many_claims and not critical_debt:
		return
	dismissal_triggered = true
	dismissal_video_seen = false
	if too_many_claims and critical_debt:
		dismissal_reason = &"claims_and_debt"
	elif too_many_claims:
		dismissal_reason = &"claims"
	else:
		dismissal_reason = &"debt"


func mark_demo_completion_seen() -> void:
	if demo_completion_seen:
		return
	demo_completion_seen = true
	state_changed.emit()


func get_demo_summary() -> Dictionary:
	var required_jobs := get_demo_required_job_ids()
	var claims := 0
	var damaged_jobs := 0
	var compensation_paid := 0
	for report_value: Variant in job_reports:
		if not report_value is Dictionary:
			continue
		var report: Dictionary = report_value
		var claim_amount := maxi(int(report.get("claim_amount", 0)), int(report.get("compensation", 0)))
		if claim_amount > 0:
			damaged_jobs += 1
			claims += 1
		compensation_paid += maxi(0, int(report.get("compensation", 0)))
	return {
		"completed_jobs": required_jobs.size(),
		"required_jobs": required_jobs.size(),
		"money": money,
		"reputation": reputation,
		"titles": get_reputation_titles(2),
		"claims": claims,
		"damaged_jobs": damaged_jobs,
		"compensation_paid": compensation_paid,
		"reputation_status": get_reputation_status(),
		"denied_claims_total": get_denied_claims_total(),
		"financial_risk": get_financial_risk_status(),
		"inspection": get_demo_inspection_verdict(),
	}


func get_reputation_status() -> String:
	if reputation >= REPUTATION_RELIABLE_THRESHOLD:
		return "Надёжная служба"
	if reputation >= REPUTATION_LICENSE_RISK_THRESHOLD:
		return "Под наблюдением"
	return "Риск отзыва лицензии"


func get_denied_claims_total() -> int:
	var total := 0
	for report_value: Variant in job_reports:
		if report_value is Dictionary:
			var report: Dictionary = report_value
			if str(report.get("claim_status", "none")) == "denied":
				total += maxi(0, int(report.get("claim_amount", 0)))
	return total


func get_financial_risk_status() -> String:
	var denied_total := get_denied_claims_total()
	if denied_total <= 0:
		return "нет"
	if denied_total < ELEVATED_CLAIM_RISK_THRESHOLD:
		return "низкий"
	if denied_total < HIGH_CLAIM_RISK_THRESHOLD:
		return "повышенный"
	return "высокий"


func get_demo_inspection_verdict() -> Dictionary:
	var reputation_concern := reputation < REPUTATION_RELIABLE_THRESHOLD
	var financial_concern := money < 0 or get_denied_claims_total() >= ELEVATED_CLAIM_RISK_THRESHOLD
	if reputation_concern and financial_concern:
		return {"title": "Лицензия под угрозой", "text": "Жалобы и финансовые риски требуют срочного вмешательства городской инспекции."}
	if reputation_concern:
		return {"title": "Испытательный срок", "text": "Служба продолжит работу под наблюдением, пока не восстановит доверие жителей."}
	if financial_concern:
		return {"title": "Финансовое оздоровление", "text": "Лицензия сохранена, но службе предстоит выбраться из долга и урегулировать отклонённые претензии."}
	return {"title": "Лицензия подтверждена", "text": "Инспекция признаёт службу устойчивой и разрешает продолжить работу."}


func get_claim_denial_penalty(claim_amount: int) -> int:
	return 2 if claim_amount >= 300 else 1


func resolve_pending_claim(pay_compensation: bool) -> bool:
	if pending_job_report.is_empty() or str(pending_job_report.get("claim_status", "none")) != "pending":
		return false
	var claim_amount := maxi(0, int(pending_job_report.get("claim_amount", 0)))
	if claim_amount <= 0:
		return false
	if pay_compensation:
		money -= claim_amount
		coins_spent.emit(claim_amount)
		pending_job_report["claim_status"] = "paid"
		pending_job_report["claim_settled_report_count"] = job_reports.size()
		pending_job_report["compensation"] = claim_amount
		pending_job_report["net_change"] = int(pending_job_report.get("reward", 0)) - claim_amount
		_record_financial_event(&"compensation", -claim_amount, str(pending_job_report.get("title", "Компенсация клиенту")), {
			"job_id": str(pending_job_report.get("job_id", "")), "resident": str(pending_job_report.get("resident", "")),
		})
	else:
		var reputation_penalty := get_claim_denial_penalty(claim_amount)
		reputation = maxi(0, reputation - reputation_penalty)
		pending_job_report["claim_status"] = "denied"
		pending_job_report["claim_reputation_penalty"] = reputation_penalty
		pending_job_report["reputation_change"] = int(pending_job_report.get("reputation_change", 0)) - reputation_penalty
		var review := str(pending_job_report.get("review", "")).strip_edges()
		pending_job_report["review_before_claim_decision"] = review
		pending_job_report["review"] = "%s%s" % [tr(review), tr(" В компенсации мне ещё и отказали.") if not review.is_empty() else tr("Служба отказалась компенсировать причинённый ущерб.")]
	pending_job_report["claim_decision_day"] = day
	pending_job_report["claim_decision_time"] = time_minutes
	pending_job_report["rating"] = _calculate_report_rating(
		int(pending_job_report.get("reputation_change", 0)),
		int(pending_job_report.get("reward_adjustment", 0)),
		claim_amount
	)
	_sync_pending_report_to_history()
	_evaluate_dismissal()
	state_changed.emit()
	save_autosave()
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
		coins_spent.emit(claim_amount)
		var restored_reputation := maxi(0, int(report.get("claim_reputation_penalty", 0)))
		reputation += restored_reputation
		report["claim_status"] = "paid_after_denial"
		report["claim_settled_report_count"] = job_reports.size()
		report["compensation"] = claim_amount
		report["net_change"] = int(report.get("reward", 0)) - claim_amount
		report["reputation_change"] = int(report.get("reputation_change", 0)) + restored_reputation
		report["claim_reputation_restored"] = restored_reputation
		report["claim_reputation_penalty"] = 0
		var original_review := str(report.get("review_before_claim_decision", "")).strip_edges()
		if original_review.is_empty():
			original_review = str(report.get("review", "")).replace(" В компенсации мне ещё и отказали.", "").replace("Служба отказалась компенсировать причинённый ущерб.", "").strip_edges()
		report["review"] = "%s%s" % [tr(original_review), tr(" Позже служба всё-таки выплатила компенсацию.") if not original_review.is_empty() else tr("После первоначального отказа служба всё-таки выплатила компенсацию.")]
		report["claim_payment_day"] = day
		report["claim_payment_time"] = time_minutes
		report["rating"] = _calculate_report_rating(
			int(report.get("reputation_change", 0)),
			int(report.get("reward_adjustment", 0)),
			claim_amount
		)
		job_reports[index] = report
		_evaluate_dismissal()
		_record_financial_event(&"compensation", -claim_amount, str(report.get("title", "Компенсация клиенту")), {
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


func has_autosave() -> bool:
	return FileAccess.file_exists(AUTOSAVE_PATH)


func has_save(slot: int = 0) -> bool:
	if slot > 0:
		if slot > SAVE_SLOT_COUNT:
			return false
		return FileAccess.file_exists(save_slot_path(slot)) or (slot == 1 and FileAccess.file_exists(LEGACY_SAVE_PATH))
	if has_autosave():
		return true
	for slot_index in range(1, SAVE_SLOT_COUNT + 1):
		if has_save(slot_index):
			return true
	return false


func get_autosave_summary() -> Dictionary:
	return _save_summary_from_path(AUTOSAVE_PATH, 0)


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
	return _save_summary_from_path(path, slot)


func _save_summary_from_path(path: String, slot: int) -> Dictionary:
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
		"tutorial_label": _tutorial_summary_label(data.get("tutorial_state", {})),
	}


func _tutorial_summary_label(value: Variant) -> String:
	if not value is Dictionary:
		return ""
	var saved_tutorial: Dictionary = value
	var status := str(saved_tutorial.get("status", "inactive"))
	if status == "completed":
		return "Обучение завершено"
	if status == "skipped":
		return "Обучение пропущено"
	if status != "active":
		return ""
	var labels := {
		"office_welcome": "знакомство с офисом", "open_board": "доска заявок",
		"open_first_job": "первая заявка", "job_details": "сведения о вызове",
		"assign_employee": "состав бригады", "employee_scroll": "сотрудники",
		"crew_choice": "выбор бригады", "dispatch": "отправка бригады",
		"travel": "бригада в пути", "open_object": "прибытие на объект",
		"employee_auto": "выбор сотрудника", "risk_notice": "последствия работы",
		"select_faucet": "аварийный кран", "select_action": "выбор действия",
		"consequences": "последствия решения", "resolve_job": "самостоятельная работа",
		"wait_resolution": "устранение аварии",
		"complete_job": "завершение работы", "report": "итоговый отчёт",
		"claim": "претензия клиента", "return_board": "возвращение в офис",
		"finish_day": "завершение дня", "personnel_overview": "раздел сотрудников",
		"supply_overview": "лавка снабжения", "storage_overview": "склад снаряжения",
		"final": "новый рабочий день",
	}
	return tr("Обучение: %s") % str(labels.get(str(saved_tutorial.get("step", "")), "продолжается"))


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
	_remove_generated_job_entries()
	day = 1
	time_minutes = 9 * 60
	money = 600
	reputation = 37
	selected_job_id = &""
	active_job_id = &""
	tutorial_job_id = &""
	owned_supply_items = PackedStringArray()
	equipped_supply_items = {}
	completed_job_ids = PackedStringArray()
	job_reports = []
	pending_job_report = {}
	demo_completion_seen = false
	dismissal_triggered = false
	dismissal_reason = &""
	dismissal_video_seen = false
	financial_ledger = [_financial_event(&"opening_balance", money, "Начальные средства службы")]
	job_repair_states = {}
	world_memory.reset()
	campaign_seed = int(Time.get_unix_time_from_system()) ^ randi()
	debug_tutorial_bypass_day = 0
	debug_skipped_job_ids = PackedStringArray()
	next_generated_job_index = 0
	generated_jobs = {}
	tutorial_state = {"version": 1, "status": "active", "step": "office_welcome"}
	clock_paused = true
	clock_speed = 1
	_clock_accumulator = 0.0

	for job_id: StringName in jobs:
		var job: Dictionary = jobs[job_id]
		job["assigned"] = PackedStringArray()
		job["time_left"] = int(job.get("initial_time", job.get("time_left", 0)))
		job["overdue"] = false
		job["unlocked"] = false
		job["dispatched"] = false
		job["pending_action"] = {}
		jobs[job_id] = job

	_reset_employee(&"liliya", true, PackedStringArray(["freeze", "heat"]), "Свободна")
	_reset_employee(&"grog", true, PackedStringArray(["physical_move"]), "Свободен")
	_reset_employee(&"boris", true, PackedStringArray(["diagnose", "repair"]), "Свободен")
	_reset_employee(&"nika", false, PackedStringArray(["telekinesis"]), "Не нанята")
	_reset_employee(&"felix", false, PackedStringArray(["antimagic"]), "Не нанят")
	_publish_generated_wardrobe_job(campaign_seed)
	_set_job_unlocked(GeneratedJobGeneratorScript.JOB_ID, false)
	_publish_generated_tutorial_faucet_job(campaign_seed ^ 0x5F3759DF)
	tutorial_job_id = _choose_tutorial_job_id()
	selected_job_id = tutorial_job_id
	_set_job_unlocked(tutorial_job_id, true)
	_disable_manual_wardrobe_job()
	print_wardrobe_diagnostic("start_new_game")

	_update_employee_statuses()
	state_changed.emit()
	save_autosave()


func set_tutorial_step(step: StringName, autosave: bool = true) -> void:
	if str(tutorial_state.get("status", "inactive")) != "active":
		return
	if str(tutorial_state.get("step", "")) == String(step):
		return
	tutorial_state["step"] = String(step)
	state_changed.emit()
	if autosave:
		save_autosave()


func skip_tutorial() -> void:
	tutorial_state = {"version": 1, "status": "skipped", "step": ""}
	state_changed.emit()
	save_autosave()


func complete_tutorial() -> void:
	tutorial_state = {"version": 1, "status": "completed", "step": ""}
	state_changed.emit()
	save_autosave()


func is_tutorial_active() -> bool:
	return str(tutorial_state.get("status", "inactive")) == "active"


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
	return _save_to_path(save_slot_path(slot))


func save_autosave() -> Error:
	return _save_to_path(AUTOSAVE_PATH)


func _save_to_path(path: String) -> Error:
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
			"access_messages": jobs[job_id].get("access_messages", []),
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
		"tutorial_job_id": String(tutorial_job_id),
		"owned_supply_items": Array(owned_supply_items),
		"equipped_supply_items": equipped_supply_items.duplicate(true),
		"completed_job_ids": Array(completed_job_ids),
		"job_reports": job_reports,
		"pending_job_report": pending_job_report,
		"demo_completion_seen": demo_completion_seen,
		"dismissal_triggered": dismissal_triggered,
		"dismissal_reason": String(dismissal_reason),
		"dismissal_video_seen": dismissal_video_seen,
		"financial_ledger": financial_ledger,
		"job_repair_states": job_repair_states,
		"tutorial_state": tutorial_state,
		"campaign_seed": campaign_seed,
		"debug_tutorial_bypass_day": debug_tutorial_bypass_day,
		"debug_next_mirror_anomaly": String(debug_next_mirror_anomaly) if OS.is_debug_build() else "",
		"debug_skipped_job_ids": Array(debug_skipped_job_ids),
		"next_generated_job_index": next_generated_job_index,
		"generated_jobs": generated_jobs,
		"world_memory": world_memory.to_data(),
		"job_assignments": job_assignments,
		"job_progress": job_progress,
		"employee_progress": employee_progress,
		"clock_paused": clock_paused,
		"clock_speed": clock_speed,
	}

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	return OK


func load_game(slot: int = 0) -> Error:
	if slot < 0 or slot > SAVE_SLOT_COUNT:
		return ERR_INVALID_PARAMETER
	var target_slot := slot if slot > 0 else get_latest_save_slot()
	if target_slot < 1 or not has_save(target_slot):
		return ERR_FILE_NOT_FOUND

	return _load_from_path(_existing_save_slot_path(target_slot))


func load_autosave() -> Error:
	if not has_autosave():
		return ERR_FILE_NOT_FOUND
	return _load_from_path(AUTOSAVE_PATH)


func load_latest_game() -> Error:
	var latest_path := ""
	var latest_time := 0
	if has_autosave():
		latest_path = AUTOSAVE_PATH
		latest_time = int(FileAccess.get_modified_time(AUTOSAVE_PATH))
	for slot_index in range(1, SAVE_SLOT_COUNT + 1):
		var path := _existing_save_slot_path(slot_index)
		if path.is_empty():
			continue
		var modified := int(FileAccess.get_modified_time(path))
		if latest_path.is_empty() or modified >= latest_time:
			latest_path = path
			latest_time = modified
	if latest_path.is_empty():
		return ERR_FILE_NOT_FOUND
	return _load_from_path(latest_path)


func _load_from_path(path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()

	var save_text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var parse_error := json.parse(save_text)
	if parse_error != OK or typeof(json.data) != TYPE_DICTIONARY:
		return ERR_PARSE_ERROR

	var save_data: Dictionary = json.data
	var version := int(save_data.get("version", 0))
	if version <= 0 or version > SAVE_VERSION:
		return ERR_FILE_UNRECOGNIZED
	loading_game = true
	var loaded_world_memory: Variant = save_data.get("world_memory", {})
	var world_memory_data: Dictionary = loaded_world_memory as Dictionary if loaded_world_memory is Dictionary else {}
	world_memory.load_data(world_memory_data)
	_remove_generated_job_entries()
	generated_jobs = {}
	campaign_seed = int(save_data.get("campaign_seed", 0))
	debug_tutorial_bypass_day = int(save_data.get("debug_tutorial_bypass_day", 0)) if OS.is_debug_build() else 0
	debug_next_mirror_anomaly = StringName(str(save_data.get("debug_next_mirror_anomaly", ""))) if OS.is_debug_build() else &""
	debug_skipped_job_ids = PackedStringArray(save_data.get("debug_skipped_job_ids", [])) if OS.is_debug_build() else PackedStringArray()
	next_generated_job_index = int(save_data.get("next_generated_job_index", 0))
	var loaded_generated_jobs: Variant = save_data.get("generated_jobs", {})
	if loaded_generated_jobs is Dictionary:
		for generated_id_value: Variant in loaded_generated_jobs:
			var instance_value: Variant = (loaded_generated_jobs as Dictionary)[generated_id_value]
			if instance_value is Dictionary:
				_register_generated_job((instance_value as Dictionary).duplicate(true), false)
	tutorial_job_id = StringName(str(save_data.get("tutorial_job_id", "lava_leak")))
	if not jobs.has(tutorial_job_id):
		tutorial_job_id = &"lava_leak"

	day = maxi(1, int(save_data.get("day", day)))
	time_minutes = maxi(0, int(save_data.get("time_minutes", time_minutes)))
	money = int(save_data.get("money", money))
	reputation = int(save_data.get("reputation", reputation))
	demo_completion_seen = bool(save_data.get("demo_completion_seen", false))
	dismissal_triggered = bool(save_data.get("dismissal_triggered", false))
	dismissal_reason = StringName(str(save_data.get("dismissal_reason", "")))
	dismissal_video_seen = bool(save_data.get("dismissal_video_seen", false))
	clock_paused = bool(save_data.get("clock_paused", true))
	clock_speed = int(save_data.get("clock_speed", 1))
	_clock_accumulator = 0.0

	var loaded_selected := StringName(save_data.get("selected_job_id", String(tutorial_job_id)))
	selected_job_id = loaded_selected if jobs.has(loaded_selected) else tutorial_job_id
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
	equipped_supply_items = {}
	var loaded_equipment: Variant = save_data.get("equipped_supply_items", {})
	if loaded_equipment is Dictionary:
		for item_id_value: Variant in loaded_equipment:
			var item_id := StringName(str(item_id_value))
			var employee_id := StringName(str((loaded_equipment as Dictionary)[item_id_value]))
			if has_supply_item(item_id) and employees.has(employee_id):
				var eligible_ids := PackedStringArray(SUPPLY_ITEMS[item_id].get("eligible_employee_ids", []))
				if eligible_ids.has(String(employee_id)):
					equipped_supply_items[String(item_id)] = String(employee_id)

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
		job["unlocked"] = job_id == tutorial_job_id
		job["dispatched"] = false
		job["pending_action"] = {}
		if version < 6:
			# Старые сохранения уже показывали все заявки; не скрываем начатый прогресс.
			job["unlocked"] = true
		elif loaded_job_progress.has(String(job_id)):
			var progress: Dictionary = loaded_job_progress[String(job_id)]
			job["access_messages"] = progress.get("access_messages", [])
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
	if jobs.has(&"sleeping_gargoyle") and bool(jobs[&"sleeping_gargoyle"].get("unlocked", false)) and not completed_job_ids.has("sleeping_gargoyle"):
		_set_gargoyle_job_unlocked(true)
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
			_sanitize_internal_faucet_check_text(report)
			if not report.has("reputation_change") and bool(report.get("maximum_payment", false)) and not bool(report.get("overdue", false)):
				report["reputation_change"] = 1
				report["rating"] = 5
				migrated_reputation_bonus += 1
			job_reports.append(report.duplicate(true))
	if version < 19:
		_migrate_legacy_follow_ups_to_world_memory()
	if migrated_reputation_bonus > 0:
		reputation += migrated_reputation_bonus
	if is_tutorial_job_completed() or debug_tutorial_bypass_day > 0:
		_update_parallel_job_unlocks()
	_unlock_gargoyle_job_if_due()
	_unlock_escaped_ghost_job_if_due()
	_unlock_frozen_bath_job_if_due()
	if not is_job_available(selected_job_id):
		selected_job_id = _first_available_job_id()
	var loaded_pending_report: Variant = save_data.get("pending_job_report", {})
	if loaded_pending_report is Dictionary:
		var pending_report: Dictionary = loaded_pending_report
		_migrate_claim_fields(pending_report)
		_sanitize_internal_faucet_check_text(pending_report)
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
				var loaded_job: Dictionary = jobs[repair_job_id]
				var loaded_instance: Dictionary = loaded_job.get("generated_instance", {}) as Dictionary
				world_memory.ensure_job_context(repair_job_id, loaded_instance.get("initial_state", {}) as Dictionary, str(loaded_instance.get("object_instance_id", "")), loaded_instance)
				job_repair_states[String(repair_job_id)] = loaded_state_dictionary.duplicate(true)
				if version < 19:
					world_memory.record_job_state(repair_job_id, loaded_state_dictionary, day, time_minutes)

	var loaded_tutorial: Variant = save_data.get("tutorial_state", {})
	if loaded_tutorial is Dictionary and not (loaded_tutorial as Dictionary).is_empty():
		tutorial_state = (loaded_tutorial as Dictionary).duplicate(true)
	else:
		tutorial_state = {"version": 1, "status": "completed", "step": ""}

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
	if version < 15 and generated_jobs.is_empty():
		if campaign_seed == 0:
			campaign_seed = hash([day, time_minutes, money, completed_job_ids])
		_publish_generated_wardrobe_job(campaign_seed)
		if is_tutorial_job_completed():
			_update_parallel_job_unlocks()
	_disable_manual_wardrobe_job()
	if version < 20:
		_migrate_missing_faucet_consequences()
	_publish_due_world_consequences()
	_publish_due_restoration_jobs()

	_complete_finished_training()
	_update_employee_statuses()
	_evaluate_dismissal()
	_migrate_restoration_trust()
	_migrate_job_preferences()
	loading_game = false
	if is_tutorial_job_completed() or debug_tutorial_bypass_day > 0:
		_update_parallel_job_unlocks()
	state_changed.emit()
	return OK


func _migrate_restoration_trust() -> void:
	for report: Dictionary in job_reports:
		if not bool(report.get("restoration", false)) or bool(report.get("relations_recorded", false)):
			continue
		var missing_crew := PackedStringArray()
		var resident_id := str(report.get("resident_id", report.get("resident", "")))
		for employee_id: Variant in report.get("crew_ids", []):
			var relation: Dictionary = world_memory.get_relation(resident_id, str(employee_id))
			var already_recorded := false
			for memory: Dictionary in relation.get("memories", []):
				if str(memory.get("job_id", "")) == str(report.get("job_id", "")):
					already_recorded = true
					break
			if not already_recorded:
				missing_crew.append(str(employee_id))
		var restored_report := report.duplicate(true)
		restored_report["crew_ids"] = Array(missing_crew)
		# Только пропущенный положительный итог; ущерб и запреты не переигрываются.
		if int(report.get("rating", 0)) >= 4 and not bool(report.get("restoration_refused", false)) and (report.get("damage_employee_ids", []) as Array).is_empty():
			world_memory.evaluate_crew_relations(restored_report)
		report["relations_recorded"] = true
		if str(pending_job_report.get("job_id", "")) == str(report.get("job_id", "")):
			pending_job_report["relations_recorded"] = true


func _publish_generated_wardrobe_job(seed_value: int) -> bool:
	if generated_jobs.has(String(GeneratedJobGeneratorScript.JOB_ID)):
		return true
	if last_generated_anomaly_id.is_empty():
		last_generated_anomaly_id = _load_last_generated_anomaly()
	var excluded := PackedStringArray()
	if not last_generated_anomaly_id.is_empty():
		excluded.append(String(last_generated_anomaly_id))
	var forced_debug := OS.is_debug_build() and debug_next_wardrobe_anomaly in [&"restless_animation", &"active_fire", &"deep_freeze"]
	if forced_debug:
		excluded.clear()
		for anomaly_id: String in ["restless_animation", "active_fire", "deep_freeze"]:
			if anomaly_id != String(debug_next_wardrobe_anomaly):
				excluded.append(anomaly_id)
	var instance: Dictionary = GeneratedJobGeneratorScript.generate(seed_value, _available_ability_ids(), excluded, _generation_context())
	debug_next_wardrobe_anomaly = &""
	if instance.is_empty():
		return false
	if not forced_debug:
		last_generated_anomaly_id = StringName(str(instance.get("anomaly_id", "")))
		_save_last_generated_anomaly(last_generated_anomaly_id)
	_register_generated_job(instance)
	next_generated_job_index += 1
	return true


func _publish_generated_mirror_job() -> bool:
	if loading_game:
		return false
	var job_id := &"portal_mirror"
	if completed_job_ids.has(String(job_id)) or not jobs.has(job_id):
		return false
	var previous: Dictionary = jobs[job_id].duplicate(true)
	# Уже опубликованную или начатую заявку прежнего формата не заменяем.
	if generated_jobs.has(String(job_id)) or bool(previous.get("unlocked", false)) or bool(previous.get("dispatched", false)) or not get_job_repair_state(job_id).is_empty():
		_set_job_unlocked(job_id, true)
		return true
	var excluded := PackedStringArray()
	var history := ConfigFile.new()
	if history.load(GENERATOR_HISTORY_PATH) == OK:
		var last := str(history.get_value("generator", "last_mirror_anomaly_id", ""))
		if not last.is_empty():
			excluded.append(last)
	var forced := OS.is_debug_build() and not debug_next_mirror_anomaly.is_empty()
	if forced:
		excluded.clear()
		for anomaly: Dictionary in GeneratedJobGeneratorScript.Catalog.compatible_anomalies(&"selesta_room", &"portal_mirror"):
			if StringName(str(anomaly["id"])) != debug_next_mirror_anomaly:
				excluded.append(String(anomaly["id"]))
	var instance := GeneratedJobGeneratorScript.generate_mirror(campaign_seed ^ 0x345BA, _available_ability_ids(), _generation_context(), excluded)
	if instance.is_empty() or (forced and StringName(str(instance["anomaly_id"])) != debug_next_mirror_anomaly):
		return false
	debug_next_mirror_anomaly = &""
	_register_generated_job(instance)
	_set_job_unlocked(job_id, true)
	if not forced:
		_write_generator_history("last_mirror_anomaly_id", str(instance["anomaly_id"]))
	next_generated_job_index += 1
	return true


func _publish_generated_tutorial_faucet_job(seed_value: int) -> bool:
	var job_id := GeneratedJobGeneratorScript.TUTORIAL_FAUCET_JOB_ID
	if generated_jobs.has(String(job_id)):
		return true
	if last_generated_faucet_anomaly_id.is_empty():
		var history_reader := ConfigFile.new()
		if history_reader.load(GENERATOR_HISTORY_PATH) == OK:
			last_generated_faucet_anomaly_id = StringName(str(history_reader.get_value("generator", "last_faucet_anomaly_id", "")))
	var excluded := PackedStringArray()
	if not last_generated_faucet_anomaly_id.is_empty():
		excluded.append(String(last_generated_faucet_anomaly_id))
	var instance: Dictionary = GeneratedJobGeneratorScript.generate_tutorial_faucet(seed_value, _available_ability_ids(), excluded, _generation_context())
	if instance.is_empty():
		return false
	last_generated_faucet_anomaly_id = StringName(str(instance.get("anomaly_id", "")))
	_write_generator_history("last_faucet_anomaly_id", String(last_generated_faucet_anomaly_id))
	_register_generated_job(instance)
	next_generated_job_index += 1
	return true


func _choose_tutorial_job_id() -> StringName:
	var candidates: Array[StringName] = []
	var abilities := _available_ability_ids()
	for job_id: StringName in jobs:
		var job: Dictionary = jobs[job_id]
		if not bool(job.get("tutorial_eligible", false)):
			continue
		var required_sets: Array = job.get("tutorial_required_ability_sets", []) as Array
		var resolvable := required_sets.is_empty()
		for required_value: Variant in required_sets:
			var required := PackedStringArray(required_value)
			var has_all := true
			for ability: String in required:
				if not abilities.has(ability):
					has_all = false
					break
			if has_all:
				resolvable = true
				break
		if resolvable:
			candidates.append(job_id)
	if candidates.is_empty():
		return &"lava_leak" if jobs.has(&"lava_leak") else &""
	candidates.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	var rng := RandomNumberGenerator.new()
	rng.seed = campaign_seed
	return candidates[rng.randi_range(0, candidates.size() - 1)]


func _load_last_generated_anomaly() -> StringName:
	var config := ConfigFile.new()
	if config.load(GENERATOR_HISTORY_PATH) != OK:
		return &""
	return StringName(str(config.get_value("generator", "last_anomaly_id", "")))


func _save_last_generated_anomaly(anomaly_id: StringName) -> void:
	if anomaly_id.is_empty():
		return
	_write_generator_history("last_anomaly_id", String(anomaly_id))


func _write_generator_history(key: String, value: String, path: String = GENERATOR_HISTORY_PATH) -> Error:
	var config := ConfigFile.new()
	config.load(path)
	config.set_value("generator", key, value)
	return config.save(path)


func _register_generated_job(instance: Dictionary, capture_preference: bool = true) -> void:
	var instance_id := StringName(str(instance.get("instance_id", GeneratedJobGeneratorScript.JOB_ID)))
	if instance_id.is_empty():
		return
	if capture_preference and not instance.has("preferred_employee_id"):
		instance["preferred_employee_id"] = String(_preferred_employee_for_resident(str(instance.get("resident_id", ""))))
	generated_jobs[String(instance_id)] = instance.duplicate(true)
	var job: Dictionary = GeneratedJobGeneratorScript.materialize_job(instance)
	if not job.is_empty():
		jobs[instance_id] = job


func _migrate_job_preferences() -> void:
	for job_id: StringName in jobs:
		var job: Dictionary = jobs[job_id]
		if not bool(job.get("generated", false)):
			continue
		var instance: Dictionary = job.get("generated_instance", {})
		if instance.has("preferred_employee_id"):
			continue
		instance["preferred_employee_id"] = String(_preferred_employee_for_resident(str(instance.get("resident_id", ""))))
		job["generated_instance"] = instance
		generated_jobs[String(job_id)] = instance.duplicate(true)


func _restoration_source_report(job: Dictionary) -> Dictionary:
	for report: Dictionary in job_reports:
		if str(report.get("job_id", "")) == str(job.get("source_job_id", "")):
			return report
	return {}


func _restoration_is_paid(job: Dictionary) -> bool:
	return str(_restoration_source_report(job).get("claim_status", "none")) in ["paid", "paid_after_denial"]


func get_restoration_payment_text(job_id: StringName) -> String:
	if not jobs.has(job_id) or not bool(jobs[job_id].get("restoration", false)):
		return ""
	if _restoration_is_paid(jobs[job_id]):
		return "Оплата: %d монет за кран + %d за установку. Замена восстановит потерянную репутацию." % [int(SUPPLY_ITEMS[&"replacement_faucet"]["price"]), int(RESTORATION_PROFILE.base_properties["installation_fee"])]
	return "Без оплаты. Новый кран — за счёт службы. Замена закроет претензию и восстановит потерянную репутацию."


func _settle_restoration(job: Dictionary) -> int:
	var source := _restoration_source_report(job)
	if source.is_empty() or bool(source.get("property_restored", false)):
		return 0
	var restored := maxi(0, -int(source.get("reputation_change", 0)))
	source["property_restored"] = true
	if not source.has("claim_settled_report_count"):
		source["claim_settled_report_count"] = job_reports.size() + 1
	source["restoration_reputation_restored"] = restored
	source["claim_reputation_penalty"] = 0
	if not _restoration_is_paid(job):
		source["claim_status"] = "settled_by_restoration"
	if str(pending_job_report.get("job_id", "")) == str(source.get("job_id", "")):
		pending_job_report = source.duplicate(true)
	return restored


func _publish_due_restoration_jobs() -> void:
	var profile: Dictionary = RESTORATION_PROFILE.base_properties
	for report: Dictionary in job_reports:
		if not bool(report.get("object_destroyed", false)) or bool(report.get("restoration", false)) or bool(report.get("property_restored", false)):
			continue
		var source_id := str(report.get("job_id", ""))
		var source_instance: Dictionary = generated_jobs.get(source_id, {}) as Dictionary
		if str(report.get("object_definition_id", source_instance.get("object_definition_id", ""))) != str(profile["target_definition_id"]):
			continue
		if day < int(report.get("completed_day", day)) + int(profile["delay_days"]):
			continue
		var instance_id := source_id + "_restoration"
		if generated_jobs.has(instance_id):
			continue
		var initial_state: Dictionary = (profile["initial_state"] as Dictionary).duplicate(true)
		var resident_id := str(report.get("resident_id", source_instance.get("resident_id", "ragnar")))
		if not _has_admitted_restoration_crew(resident_id, profile):
			continue
		initial_state["instance_id"] = str(report.get("object_instance_id", source_instance.get("object_instance_id", "old_quarter_5.bathroom.lava_faucet")))
		var remembered_object: Dictionary = world_memory.objects.get(str(initial_state["instance_id"]), {}) as Dictionary
		initial_state["incarnation"] = int((remembered_object.get("properties", {}) as Dictionary).get("incarnation", 1))
		var instance := {
			"instance_id": instance_id, "restoration": true, "source_job_id": source_id,
			"resident_id": str(report.get("resident_id", source_instance.get("resident_id", "ragnar"))),
			"room_id": str(source_instance.get("room_id", "ragnar_bathroom")),
			"object_definition_id": str(profile["target_definition_id"]),
			"object_instance_id": initial_state["instance_id"], "simulation_type": "lava_faucet",
			"scene_path": RESTORATION_PROFILE.scene_path, "initial_state": initial_state,
			"urgency": "Обычная", "initial_time": int(profile["initial_time"]), "base_reward": 0,
			"presentation": {"title": RESTORATION_PROFILE.display_name, "card_title": RESTORATION_PROFILE.display_name,
				"objective": "Установить новый кран", "danger": "Кран уничтожен, нужна замена",
				"description": "Требуется купить запасной кран и установить его силами Бориса.",
				"resident_request": "Нужно установить новый кран вместо уничтоженного."},
		}
		_register_generated_job(instance)
		_set_job_unlocked(StringName(instance_id), true)


func refuse_restoration_job(job_id: StringName) -> bool:
	if not can_refuse_job(job_id) or not bool(jobs[job_id].get("restoration", false)):
		return false
	var refused_job: Dictionary = jobs[job_id]
	refused_job["base_reward"] = 0
	refused_job["assigned"] = PackedStringArray()
	refused_job["overdue"] = false
	jobs[job_id] = refused_job
	var result := {"restoration_refused": true, "forfeit_payment": true,
		"review": RESTORATION_REFUSAL_REVIEW,
		"reputation_change": -int(RESTORATION_PROFILE.base_properties["refusal_penalty"]),
		"summary": "Служба отказалась от восстановления имущества. Невыплаченная претензия остаётся открытой."}
	return complete_job(job_id, result)


func can_refuse_job(job_id: StringName) -> bool:
	return is_job_available(job_id) and not is_job_dispatched(job_id) and active_job_id != job_id and get_pending_job_action(job_id).is_empty()


func refuse_job(job_id: StringName) -> bool:
	if not can_refuse_job(job_id):
		return false
	if bool(jobs[job_id].get("restoration", false)):
		return refuse_restoration_job(job_id)
	# Assignment without dispatch does not constitute a trip or completed work.
	var job: Dictionary = jobs[job_id]
	job["assigned"] = PackedStringArray()
	job["overdue"] = false
	jobs[job_id] = job
	return complete_job(job_id, {"job_refused": true, "forfeit_payment": true,
		"reputation_change": -2, "review": "За устранение проблемы так и не взялись. Придётся искать другую службу.",
		"summary": "Служба отказалась от заявки до отправки бригады."})


func _process_resident_access() -> void:
	for job_id: StringName in jobs:
		if not is_job_available(job_id) or not is_job_dispatched(job_id):
			continue
		var job: Dictionary = jobs[job_id]
		var kept := PackedStringArray()
		var messages: Array = job.get("access_messages", [])
		for employee_id: String in job["assigned"]:
			var employee: Dictionary = employees[StringName(employee_id)]
			if int(employee.get("arrival_until", 0)) > time_minutes or not is_employee_banned_for_job(StringName(employee_id), job_id) or _ban_started_during_current_visit(StringName(employee_id), job_id):
				kept.append(employee_id)
				continue
			var phrase := str(employee.get("access_refusal_phrase", "Я просил больше не присылать этого сотрудника"))
			messages.append({"phrase": phrase, "employee_id": employee_id, "message": "Хозяин не впустил сотрудника: %s. Сотрудник возвращается в офис." % str(employee["name"])})
			employee["arrival_until"] = 0
			employee["return_until"] = time_minutes + TRAVEL_TIME_MINUTES
			employees[StringName(employee_id)] = employee
		job["assigned"] = kept
		job["access_messages"] = messages
		if kept.is_empty():
			job["dispatched"] = false
		jobs[job_id] = job


func take_access_messages(job_id: StringName) -> PackedStringArray:
	var messages := PackedStringArray()
	for event: Dictionary in take_access_events(job_id):
		messages.append(str(event["message"]))
	return messages


func take_access_events(job_id: StringName) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if not jobs.has(job_id):
		return events
	for value: Variant in jobs[job_id].get("access_messages", []):
		if value is Dictionary:
			var event := (value as Dictionary).duplicate(true)
			var employee_id := StringName(str(event.get("employee_id", "")))
			if employees.has(employee_id):
				event["message"] = "Хозяин не впустил сотрудника: %s. Сотрудник возвращается в офис." % str(employees[employee_id]["name"])
			events.append(event)
		else:
			# Совместимость с сообщениями, сохранёнными до разделения реплики и уведомления.
			var text_value := str(value)
			var phrase := text_value.get_slice("\n", 0).trim_prefix(str(jobs[job_id]["resident"]) + ": «").trim_suffix("».")
			events.append({"phrase": phrase, "message": text_value.get_slice("\n", 1)})
	jobs[job_id]["access_messages"] = []
	return events


func _publish_due_world_consequences() -> void:
	var due: Array[Dictionary] = world_memory.due_consequences(day, time_minutes)
	# Публикуем одно разрешимое последствие. Остальные остаются в памяти.
	for event: Dictionary in due:
		var instance := GeneratedJobGeneratorScript.generate_faucet_consequence(event, _available_ability_ids(), _generation_context())
		if instance.is_empty():
			continue
		var instance_id := StringName(str(instance.get("instance_id", "")))
		if generated_jobs.has(String(instance_id)):
			continue
		_register_generated_job(instance)
		_set_job_unlocked(instance_id, true)
		world_memory.set_event_status(str(event.get("event_id", "")), "claimed", {"generated_job_id": String(instance_id)})
		next_generated_job_index += 1
		return


func _migrate_missing_faucet_consequences() -> void:
	if world_memory.has_consequence(&"faucet_overheat"):
		return
	for report_value: Variant in job_reports:
		if not report_value is Dictionary:
			continue
		var report: Dictionary = report_value
		var job_id := StringName(str(report.get("job_id", "")))
		var instance: Dictionary = generated_jobs.get(String(job_id), {}) as Dictionary
		if StringName(str(instance.get("object_definition_id", ""))) != &"lava_faucet":
			continue
		var initial_state: Dictionary = instance.get("initial_state", {}) as Dictionary
		if not bool(initial_state.get("frozen", false)):
			continue
		var has_heat := false
		var invalidated := false
		for action_value: Variant in report.get("actions", []):
			if not action_value is Dictionary:
				continue
			var action_id := StringName(str((action_value as Dictionary).get("action_id", "")))
			if action_id == &"heat":
				has_heat = true
			elif action_id in [&"replace_faucet", &"install_thermal_regulator"]:
				invalidated = true
		if not has_heat or invalidated:
			continue
		var completed_day := int(report.get("completed_day", 1))
		world_memory.queue_consequence(
			&"thermal_instability", &"faucet_overheat", "old_quarter_5.bathroom.lava_faucet", job_id,
			completed_day + 1, 540, 80, {
				"anomaly_id": "faucet_overheat",
				"source_incarnation": int(initial_state.get("incarnation", 1)),
				"migrated_from_save": true,
			}, "chain.%s.thermal_instability" % String(job_id), "legacy_unknown", 1
		)
		return


func _sanitize_internal_faucet_check_text(report: Dictionary) -> void:
	for field: String in ["summary", "review", "review_before_claim_decision"]:
		if report.has(field):
			report[field] = LocalizationHelper.client_terms(str(report[field])).replace("Клиент запретил вход", str(report.get("resident", "Клиент")) + " запретил вход")
	var summary := str(report.get("summary", ""))
	summary = summary.replace("Кран автоматически проверен: механизм исправен, температура безопасна.", "Кран исправен, температура безопасна.")
	summary = summary.replace(" и прошёл автоматическую проверку исправности", "")
	summary = summary.replace("Проверка подтвердила, что кран исправен и подаёт обычную воду.", "Из крана снова течёт обычная вода.")
	report["summary"] = summary
	var cleaned_consequences: Array = []
	for consequence: Variant in report.get("consequences", []):
		if str(consequence) != "Автоматическая проверка исправности пройдена.":
			cleaned_consequences.append(LocalizationHelper.client_terms(consequence).replace("Клиент предъявил службе претензию", str(report.get("resident", "Клиент")) + ": предъявлена претензия"))
	report["consequences"] = cleaned_consequences


func _remove_generated_job_entries() -> void:
	jobs[&"portal_mirror"] = legacy_mirror_job.duplicate(true)
	var ids_to_remove: Array[StringName] = []
	for job_id: StringName in jobs:
		if bool((jobs[job_id] as Dictionary).get("generated", false)):
			ids_to_remove.append(job_id)
	for job_id: StringName in ids_to_remove:
		if job_id in [&"sleeping_gargoyle", &"portal_mirror"]:
			# This stable ID also existed before generated instances were saved.
			jobs[job_id]["generated"] = false
			jobs[job_id].erase("generated_instance")
		else:
			jobs.erase(job_id)


func _generation_context() -> Dictionary:
	var context: Dictionary = world_memory.generator_context()
	var client_capabilities: Dictionary = {}
	for resident_id: StringName in GeneratedJobGeneratorScript.Catalog.RESIDENTS:
		client_capabilities[String(resident_id)] = _available_ability_ids(String(resident_id))
	context["client_capabilities"] = client_capabilities
	var admitted_employees: Dictionary = {}
	for resident_id: StringName in GeneratedJobGeneratorScript.Catalog.RESIDENTS:
		var admitted := PackedStringArray()
		for employee_id: StringName in employees:
			if bool(employees[employee_id].get("available", false)) and str(world_memory.get_relation(String(resident_id), String(employee_id)).get("access_status", "allowed")) != "banned":
				admitted.append(String(employee_id))
		admitted_employees[String(resident_id)] = admitted
	context["admitted_employees"] = admitted_employees
	context["owned_items"] = owned_supply_items.duplicate()
	context["money"] = money
	var item_prices: Dictionary = {}
	for item_id: StringName in SUPPLY_ITEMS:
		item_prices[String(item_id)] = int(SUPPLY_ITEMS[item_id]["price"])
	context["item_prices"] = item_prices
	return context


func _has_admitted_restoration_crew(resident_id: String, profile: Dictionary) -> bool:
	for employee_id_value: Variant in profile.get("required_employee_ids", []):
		var employee_id := StringName(str(employee_id_value))
		if not employees.has(employee_id) or not bool(employees[employee_id].get("available", false)):
			return false
		if str(world_memory.get_relation(resident_id, String(employee_id)).get("access_status", "allowed")) == "banned":
			return false
	return true


func _available_ability_ids(resident_id: String = "") -> PackedStringArray:
	var result := PackedStringArray()
	for employee_id: StringName in employees:
		var employee: Dictionary = employees[employee_id]
		if not bool(employee.get("available", false)):
			continue
		if not resident_id.is_empty() and str(world_memory.get_relation(resident_id, String(employee_id)).get("access_status", "allowed")) == "banned":
			continue
		for ability_value: Variant in employee.get("abilities", PackedStringArray()):
			var ability := str(ability_value)
			if not result.has(ability):
				result.append(ability)
	for item_id_string: String in owned_supply_items:
		var item_id := StringName(item_id_string)
		if not SUPPLY_ITEMS.has(item_id):
			continue
		var capability := str((SUPPLY_ITEMS[item_id] as Dictionary).get("solution_capability", ""))
		if not capability.is_empty() and not result.has(capability):
			result.append(capability)
	for item_id_value: Variant in equipped_supply_items:
		var equipped_item_id := StringName(str(item_id_value))
		if not SUPPLY_ITEMS.has(equipped_item_id):
			continue
		for protection_value: Variant in (SUPPLY_ITEMS[equipped_item_id] as Dictionary).get("protects_from", []):
			var protection := str(protection_value)
			if not result.has(protection):
				result.append(protection)
	return result


func _record_financial_event(kind: StringName, amount: int, title: String, details: Dictionary = {}) -> void:
	var event := _financial_event(kind, amount, title)
	for key: Variant in details:
		event[key] = details[key]
	financial_ledger.append(event)


func _migrate_claim_fields(report: Dictionary) -> void:
	if not report.has("report_acknowledged"):
		report["report_acknowledged"] = str(report.get("claim_status", "none")) != "pending"
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
				"kind": "compensation", "amount": -paid_compensation, "title": str(report.get("title", "Компенсация клиенту")),
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


func _update_parallel_job_unlocks() -> void:
	var source_day := _job_completed_day(tutorial_job_id)
	if source_day <= 0 and debug_tutorial_bypass_day > 0:
		source_day = debug_tutorial_bypass_day
	var jobs_are_due := source_day > 0 and day > source_day
	_set_job_unlocked(&"walking_wardrobe", false)
	_set_job_unlocked(GeneratedJobGeneratorScript.JOB_ID, jobs_are_due)
	var frozen_bath_delays_portal := _has_follow_up(&"frozen_bath") and day <= source_day + 1
	if jobs_are_due and not frozen_bath_delays_portal:
		_publish_generated_mirror_job()
	else:
		_set_job_unlocked(&"portal_mirror", false)
	print_wardrobe_diagnostic("update_parallel_job_unlocks")


func _disable_manual_wardrobe_job() -> void:
	var manual_job_id := &"walking_wardrobe"
	if jobs.has(manual_job_id):
		var job: Dictionary = jobs[manual_job_id]
		job["unlocked"] = false
		job["assigned"] = PackedStringArray()
		job["dispatched"] = false
		job["pending_action"] = {}
		jobs[manual_job_id] = job
	job_repair_states.erase(String(manual_job_id))
	if active_job_id == manual_job_id:
		active_job_id = &""
	if selected_job_id == manual_job_id or not is_job_available(selected_job_id):
		selected_job_id = _first_available_job_id()


func print_wardrobe_diagnostic(context: String, visible_ids: PackedStringArray = PackedStringArray()) -> void:
	if not OS.is_debug_build():
		return
	var entries: Array[Dictionary] = []
	for job_id: StringName in [&"walking_wardrobe", GeneratedJobGeneratorScript.JOB_ID]:
		var job: Dictionary = jobs.get(job_id, {})
		entries.append({
			"id": String(job_id),
			"exists": not job.is_empty(),
			"unlocked_flag": bool(job.get("unlocked", false)),
			"available": is_job_available(job_id),
			"completed": completed_job_ids.has(String(job_id)),
			"generated": bool(job.get("generated", false)),
			"title": str(job.get("title", "")),
			"anomaly_id": str((job.get("generated_instance", {}) as Dictionary).get("anomaly_id", "")),
		})
	print("[WARDROBE_DIAGNOSTIC] ", JSON.stringify({
		"context": context,
		"day": day,
		"money": money,
		"visible_ids": Array(visible_ids),
		"entries": entries,
	}))


func _set_job_unlocked(job_id: StringName, unlocked: bool) -> void:
	if not jobs.has(job_id) or completed_job_ids.has(String(job_id)):
		return
	var job: Dictionary = jobs[job_id]
	job["unlocked"] = unlocked
	jobs[job_id] = job


func _has_follow_up(follow_up_id: StringName) -> bool:
	_migrate_legacy_follow_ups_to_world_memory()
	return world_memory.has_consequence(follow_up_id)


func get_follow_up_data(follow_up_id: StringName) -> Dictionary:
	_migrate_legacy_follow_ups_to_world_memory()
	return world_memory.consequence_payload(follow_up_id)


func _unlock_gargoyle_job() -> void:
	_set_gargoyle_job_unlocked(true)


func _unlock_gargoyle_job_if_due() -> void:
	if not completed_job_ids.has(String(GeneratedJobGeneratorScript.JOB_ID)) and not (OS.is_debug_build() and debug_skipped_job_ids.has(String(GeneratedJobGeneratorScript.JOB_ID))):
		return
	var portal_is_due := completed_job_ids.has("portal_mirror")
	if jobs.has(&"portal_mirror"):
		portal_is_due = portal_is_due or bool(jobs[&"portal_mirror"].get("unlocked", false))
	if portal_is_due:
		_unlock_gargoyle_job()


func _set_gargoyle_job_unlocked(unlocked: bool) -> void:
	var job_id := &"sleeping_gargoyle"
	if not jobs.has(job_id) or completed_job_ids.has(String(job_id)):
		return
	if not bool(jobs[job_id].get("generated", false)):
		var previous: Dictionary = jobs[job_id].duplicate(true)
		var instance := GeneratedJobGeneratorScript.generate_gargoyle(campaign_seed, _available_ability_ids(), _generation_context())
		if instance.is_empty():
			return
		_register_generated_job(instance)
		for key: String in ["assigned", "dispatched", "pending_action", "overdue", "time_left"]:
			if previous.has(key):
				jobs[job_id][key] = previous[key]
	var job: Dictionary = jobs[job_id]
	job["unlocked"] = unlocked
	jobs[job_id] = job


func _unlock_escaped_ghost_job_if_due() -> void:
	_migrate_legacy_follow_ups_to_world_memory()
	var source_day: int = int(world_memory.consequence_due_day(&"escaped_ghost")) - 1
	var job_id := &"escaped_ghost"
	if not jobs.has(job_id) or completed_job_ids.has(String(job_id)):
		return
	var job: Dictionary = jobs[job_id]
	job["unlocked"] = source_day > 0 and day > source_day
	jobs[job_id] = job
	if bool(job["unlocked"]):
		world_memory.set_consequence_status(&"escaped_ghost", "claimed")


func _unlock_frozen_bath_job_if_due() -> void:
	_migrate_legacy_follow_ups_to_world_memory()
	var source_day: int = int(world_memory.consequence_due_day(&"frozen_bath")) - 1
	var job_id := &"frozen_bath"
	if not jobs.has(job_id) or completed_job_ids.has(String(job_id)):
		return
	var job: Dictionary = jobs[job_id]
	job["unlocked"] = source_day > 0 and day > source_day
	jobs[job_id] = job
	if bool(job["unlocked"]):
		world_memory.set_consequence_status(&"frozen_bath", "claimed")


func _migrate_legacy_follow_ups_to_world_memory() -> void:
	for report_value: Variant in job_reports:
		if not report_value is Dictionary:
			continue
		var report: Dictionary = report_value
		var follow_up: Variant = report.get("follow_up", {})
		if not follow_up is Dictionary or (follow_up as Dictionary).is_empty():
			continue
		var event_type := StringName(str((follow_up as Dictionary).get("type", "")))
		if event_type not in [&"frozen_bath", &"escaped_ghost"]:
			continue
		var source_job_id := StringName(str(report.get("job_id", "")))
		world_memory.queue_consequence(
			&"legacy_follow_up", event_type, world_memory.instance_id_for_job(source_job_id), source_job_id,
			int(report.get("completed_day", 1)) + 1, int(report.get("completed_time", 0)), 50,
			follow_up as Dictionary, "chain.%s" % String(source_job_id), "legacy_unknown", 1
		)


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
		if is_employee_injured(employee_id):
			employee["status"] = "Лечит ожоги до следующего дня"
			employees[employee_id] = employee
			continue
		var training_id := StringName(str(employee.get("training_id", "")))
		if not training_id.is_empty() and TRAINING_DEFINITIONS.has(training_id):
			employee["status"] = tr("Учится: %s") % tr(str(TRAINING_DEFINITIONS[training_id]["name"]))
			employees[employee_id] = employee
			continue
		var job_id := get_employee_job(employee_id)
		var pending_action: Dictionary = get_pending_job_action(job_id)
		employee["status"] = employee["idle_status"]
		if int(employee.get("return_until", 0)) > time_minutes:
			employee["status"] = tr("Возвращается, прибудет в %s") % _format_minutes(int(employee["return_until"]))
		elif not job_id.is_empty() and int(employee.get("arrival_until", 0)) > time_minutes:
			employee["status"] = tr("В пути, прибудет в %s") % _format_minutes(int(employee["arrival_until"]))
		elif not job_id.is_empty() and str(pending_action.get("employee_id", "")) == String(employee_id):
			employee["status"] = tr("Работает до %s") % _format_minutes(int(pending_action.get("ends_at", time_minutes)))
		elif not job_id.is_empty():
			employee["status"] = tr("На заявке: %s") % tr(str(jobs[job_id].get("card_title", jobs[job_id]["title"])))
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
