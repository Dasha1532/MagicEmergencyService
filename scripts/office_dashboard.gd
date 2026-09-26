extends Control

const HUD_ICON_SCRIPT = preload("res://scripts/hud_icon.gd")
const COLOR_PANEL := Color(0.07, 0.045, 0.03, 0.94)
const COLOR_CARD := Color(0.13, 0.09, 0.055, 0.96)
const COLOR_CARD_HOVER := Color(0.21, 0.14, 0.075, 0.98)
const COLOR_SELECTED := Color(0.10, 0.16, 0.18, 0.98)
const COLOR_BRASS := Color(0.76, 0.54, 0.27)
const COLOR_GOLD := Color(0.96, 0.78, 0.46)
const COLOR_PARCHMENT := Color(0.92, 0.84, 0.69)
const COLOR_MUTED := Color(0.70, 0.63, 0.52)
const PERSONNEL_ORDER: PackedStringArray = ["liliya", "grog", "boris", "nika", "felix"]
const CANDIDATE_CLASP_TEXTURE = preload("res://assets/ui/candidate_clasp.png")
const CLOCK_CONTROLS_SCRIPT = preload("res://scripts/game_clock_controls.gd")
const CITY_MAP_SCENE = preload("res://scenes/ui/CityMap.tscn")
const OFFICE_BOOKS_SCENE = preload("res://scenes/ui/OfficeBooks.tscn")
const TUTORIAL_OVERLAY_SCRIPT = preload("res://scripts/tutorial_overlay.gd")

var selected_job_id: StringName
var job_list: VBoxContainer
var employee_list: HBoxContainer
var money_label: Label
var day_label: Label
var detail_title: Label
var detail_body: Label
var assignment_label: Label
var warning_label: Label
var depart_button: Button
var recall_button: Button
var cancel_dispatch_button: Button
var pending_dispatch_employee_ids: PackedStringArray = PackedStringArray()
var dashboard_layer: Control
var hub_layer: Control
var personnel_layer: Control
var personnel_name: Label
var personnel_role: Label
var personnel_description: Label
var personnel_status: Label
var personnel_strength: Label
var personnel_weakness: Label
var personnel_traits: Label
var personnel_portrait: TextureRect
var personnel_hire_button: Button
var personnel_training_button: Button
var personnel_specializations_button: Button
var specialization_layer: Control
var specialization_title: Label
var specialization_slots: VBoxContainer
var specialization_notice: Label
var specialization_confirm_layer: Control
var specialization_confirm_text: Label
var pending_forget_ability_id: StringName = &""
var finish_day_button: Button
var personnel_cards: Dictionary = {}
var selected_employee_id: StringName = &"liliya"
var supply_layer: Control
var supply_money_label: Label
var supply_catalog_list: VBoxContainer
var supply_catalog_cards: Dictionary = {}
var supply_catalog_statuses: Dictionary = {}
var supply_purchase_button: Button
var supply_detail_heading: Label
var supply_detail_category: Label
var supply_detail_icon: TextureRect
var supply_detail_description: Label
var supply_delivery_note: Label
var selected_supply_item_id: StringName = &"animation_kit"
var selected_training_id: StringName = &"animate"
var equipment_layer: Control
var equipment_cards: HBoxContainer
var city_map_layer: Control
var books_layer: Control
var section_dialog: Panel
var section_title: Label
var section_body: Label
var job_report_layer: Control
var job_report_title: Label
var job_report_body: Label
var claim_layer: Control
var claim_title: Label
var claim_body: Label
var claim_pay_button: Button
var arrival_dialog: Control
var arrival_dialog_title: Label
var arrival_dialog_body: Label
var dispatch_warning_dialog: Control
var dispatch_warning_body: Label
var demo_completion_layer: Control
var demo_completion_title: Label
var demo_completion_summary: Label
var demo_video_layer: Control
var demo_video_player: VideoStreamPlayer
var demo_video_can_skip: bool = false
var demo_video_transitioning: bool = false
var cat_click_count: int = 0
var cat_message_revision: int = 0
var cat_phrase_panel: Panel
var cat_phrase_label: Label
var risk_dispatch_confirmed: bool = false
var auto_wait_running: bool = false
var tutorial_overlay: CanvasLayer
var clock_controls: Control
@onready var game_state: Node = get_node("/root/GameState")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$CupSteam.visible = true
	$HotspotEditorPreview.visible = false
	$PersonnelEditorPreview.visible = false
	$ObjectHotspots.visible = true
	$BookHotspots.visible = true
	selected_job_id = game_state.selected_job_id
	_build_interface()
	dashboard_layer.visible = false
	tutorial_overlay = TUTORIAL_OVERLAY_SCRIPT.new()
	tutorial_overlay.configure(&"office", self)
	add_child(tutorial_overlay)
	game_state.state_changed.connect(_refresh)
	_refresh()
	set_process(true)


func _build_interface() -> void:
	dashboard_layer = Control.new()
	dashboard_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dashboard_layer)
	_build_top_bar()
	_build_jobs_panel()
	_build_detail_panel()
	_build_employee_panel()
	_build_dashboard_return()
	_build_clock_controls()
	_build_office_hub()
	_build_job_report_dialog()
	_build_claim_dialog()
	_build_arrival_dialog()
	_build_dispatch_warning_dialog()
	_build_demo_completion_dialog()
	_build_demo_video()
	_build_personnel_screen()
	_build_supply_shop()
	_build_equipment_storage()
	_build_city_map()
	_build_books()


func _build_top_bar() -> void:
	var panel := _panel(Vector2(22, 18), Vector2(1556, 74), 12)
	dashboard_layer.add_child(panel)

	var title := _label("МАГИЧЕСКАЯ АВАРИЙНАЯ СЛУЖБА", 24, COLOR_GOLD)
	title.position = Vector2(24, 12)
	title.size = Vector2(650, 44)
	panel.add_child(title)

	var motto := _label("Диспетчерская заявок", 14, COLOR_MUTED)
	motto.position = Vector2(25, 42)
	motto.size = Vector2(500, 22)
	panel.add_child(motto)

	day_label = _label("День %d" % game_state.day, 20, COLOR_PARCHMENT)
	day_label.position = Vector2(1010, 19)
	day_label.size = Vector2(90, 36)
	panel.add_child(day_label)

	_add_stat_icon(panel, 0, Vector2(1168, 18))
	money_label = _label("%d монет" % game_state.money, 20, COLOR_PARCHMENT)
	money_label.position = Vector2(1202, 19)
	money_label.size = Vector2(126, 36)
	panel.add_child(money_label)

	_add_stat_icon(panel, 1, Vector2(1338, 18))
	var reputation_label := _label("Репутация %d" % game_state.reputation, 18, COLOR_PARCHMENT)
	reputation_label.position = Vector2(1372, 20)
	reputation_label.size = Vector2(132, 34)
	panel.add_child(reputation_label)


func _build_jobs_panel() -> void:
	var panel := _panel(Vector2(22, 112), Vector2(415, 455), 12)
	dashboard_layer.add_child(panel)

	var heading := _label("ТЕКУЩИЕ ЗАЯВКИ", 21, COLOR_GOLD)
	heading.position = Vector2(20, 16)
	heading.size = Vector2(375, 32)
	panel.add_child(heading)

	var rule := ColorRect.new()
	rule.color = Color(COLOR_BRASS, 0.65)
	rule.position = Vector2(20, 53)
	rule.size = Vector2(375, 2)
	panel.add_child(rule)

	var job_scroll := ScrollContainer.new()
	job_scroll.position = Vector2(18, 70)
	job_scroll.size = Vector2(379, 367)
	job_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	job_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	panel.add_child(job_scroll)

	job_list = VBoxContainer.new()
	job_list.custom_minimum_size = Vector2(356, 360)
	job_list.add_theme_constant_override("separation", 12)
	job_scroll.add_child(job_list)


func _build_detail_panel() -> void:
	var panel := _panel(Vector2(1163, 112), Vector2(415, 455), 12)
	dashboard_layer.add_child(panel)

	detail_title = _label("", 24, COLOR_GOLD)
	detail_title.position = Vector2(22, 18)
	detail_title.size = Vector2(371, 62)
	detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(detail_title)

	detail_body = _label("", 17, COLOR_PARCHMENT)
	detail_body.position = Vector2(22, 82)
	detail_body.size = Vector2(371, 210)
	detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_body.clip_contents = true
	panel.add_child(detail_body)

	assignment_label = _label("", 16, COLOR_GOLD)
	assignment_label.position = Vector2(22, 286)
	assignment_label.size = Vector2(371, 56)
	assignment_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(assignment_label)

	warning_label = _label("", 14, Color(0.96, 0.62, 0.35))
	warning_label.position = Vector2(22, 346)
	warning_label.size = Vector2(371, 34)
	warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning_label.visible = false
	panel.add_child(warning_label)

	depart_button = _button("ОТПРАВИТЬ БРИГАДУ", Vector2(22, 384), Vector2(371, 52))
	depart_button.pressed.connect(_depart)
	panel.add_child(depart_button)
	recall_button = _button("ОТОЗВАТЬ • 15 МИН.", Vector2(216, 384), Vector2(177, 52))
	recall_button.add_theme_font_size_override("font_size", 15)
	recall_button.visible = false
	recall_button.pressed.connect(_recall_crew)
	panel.add_child(recall_button)
	cancel_dispatch_button = _button("НЕ ОТПРАВЛЯТЬ", Vector2(216, 384), Vector2(177, 52))
	cancel_dispatch_button.add_theme_font_size_override("font_size", 13)
	cancel_dispatch_button.visible = false
	cancel_dispatch_button.pressed.connect(_cancel_pending_dispatch)
	panel.add_child(cancel_dispatch_button)


func _build_employee_panel() -> void:
	var panel := _panel(Vector2(180, 585), Vector2(1240, 295), 12)
	dashboard_layer.add_child(panel)

	var heading := _label("СОТРУДНИКИ  •  выберите заявку, затем назначьте специалистов", 18, COLOR_GOLD)
	heading.position = Vector2(20, 10)
	heading.size = Vector2(1200, 28)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(heading)

	var employee_scroll := ScrollContainer.new()
	employee_scroll.position = Vector2(18, 43)
	employee_scroll.size = Vector2(1204, 234)
	employee_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	employee_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(employee_scroll)

	employee_list = HBoxContainer.new()
	employee_list.custom_minimum_size = Vector2(1204, 225)
	employee_list.alignment = BoxContainer.ALIGNMENT_CENTER
	employee_list.add_theme_constant_override("separation", 14)
	employee_scroll.add_child(employee_list)


func _build_dashboard_return() -> void:
	var back_button := _button("←  В ОФИС", Vector2(746, 30), Vector2(180, 50))
	back_button.pressed.connect(_show_hub)
	dashboard_layer.add_child(back_button)

	finish_day_button = _button("ЗАВЕРШИТЬ ДЕНЬ", Vector2(944, 30), Vector2(210, 50))
	finish_day_button.add_theme_font_size_override("font_size", 14)
	finish_day_button.pressed.connect(_finish_day)
	dashboard_layer.add_child(finish_day_button)


func _build_clock_controls() -> void:
	clock_controls = CLOCK_CONTROLS_SCRIPT.new()
	clock_controls.position = Vector2(625, 105)
	dashboard_layer.add_child(clock_controls)


func _build_office_hub() -> void:
	hub_layer = Control.new()
	hub_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(hub_layer)

	var background := TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.texture = load("res://assets/backgrounds/office_hub.png") as Texture2D
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hub_layer.add_child(background)
	var cup_steam := $CupSteam
	cup_steam.reparent(hub_layer, true)

	_connect_editable_hotspot($ObjectHotspots/JobBoard, "ДОСКА ЗАЯВОК", "Что опять случилось?", _open_jobs)
	_connect_editable_hotspot($ObjectHotspots/EmployeesBoard, "СОТРУДНИКИ", "Кто сегодня работает?", _open_personnel)
	_connect_editable_hotspot($ObjectHotspots/EquipmentStorage, "СКЛАД СНАРЯЖЕНИЯ", "Чем будем чинить?", _open_equipment_storage)
	_connect_editable_hotspot($ObjectHotspots/CityMap, "КАРТА ГОРОДА", "Где опять прорвало?", _open_city_map)
	_connect_editable_hotspot($BookHotspots/AccountingBook, "КНИГА УЧЁТА", "Куда делись деньги?", _open_books.bind(&"accounting"))
	_connect_editable_hotspot($BookHotspots/ReviewsBook, "КНИГА ОТЗЫВОВ", "Благодарности, жалобы и угрозы.", _open_books.bind(&"reviews"))
	_connect_editable_hotspot($BookHotspots/IncidentArchive, "АРХИВ ПРОИСШЕСТВИЙ", "Так больше не делать.", _open_books.bind(&"archive"))
	_connect_editable_hotspot($ObjectHotspots/SupplyShop, "ЛАВКА СНАБЖЕНИЯ", "Очень нужные покупки", _open_supply_shop)

	_build_office_menu_button()
	_build_cat_easter_egg()

	var hint := _label("Наводите курсор на предметы. Кота не будите — он занят важным.", 19, COLOR_PARCHMENT)
	hint.position = Vector2(470, 846)
	hint.size = Vector2(660, 34)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.pivot_offset = hint.size * 0.5
	hint.scale = Vector2(0.96, 0.96)
	hub_layer.add_child(hint)
	var pulse := create_tween().set_loops()
	pulse.tween_property(hint, "scale", Vector2(1.04, 1.04), 1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(hint, "scale", Vector2(0.96, 0.96), 1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_build_section_dialog()


func _build_cat_easter_egg() -> void:
	var cat_button := Button.new()
	cat_button.position = Vector2(480, 620)
	cat_button.size = Vector2(185, 105)
	cat_button.flat = true
	cat_button.focus_mode = Control.FOCUS_NONE
	cat_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	cat_button.set_meta(&"cat_purr_sound", true)
	cat_button.pressed.connect(_on_cat_pressed)
	hub_layer.add_child(cat_button)

	cat_phrase_panel = _panel(Vector2(340, 500), Vector2(560, 108), 12)
	cat_phrase_panel.visible = false
	cat_phrase_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cat_phrase_panel.z_index = 20
	hub_layer.add_child(cat_phrase_panel)
	cat_phrase_label = _label("", 17, COLOR_PARCHMENT)
	cat_phrase_label.position = Vector2(24, 14)
	cat_phrase_label.size = Vector2(512, 80)
	cat_phrase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cat_phrase_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cat_phrase_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cat_phrase_label.clip_text = true
	cat_phrase_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cat_phrase_panel.add_child(cat_phrase_label)


func _on_cat_pressed() -> void:
	cat_click_count += 1
	cat_phrase_label.text = _cat_phrase_for_click(cat_click_count)
	cat_phrase_panel.visible = true
	cat_phrase_panel.move_to_front()
	cat_message_revision += 1
	_hide_cat_phrase_later(cat_message_revision)


func _cat_phrase_for_click(click_number: int) -> String:
	if click_number == 10:
		return "Поздравляю. Вы назначены Инспектором кошачьего отдела. Должность неоплачиваемая."
	var contextual := _cat_contextual_phrases()
	if click_number % 4 == 0 and not contextual.is_empty():
		return contextual[(click_number / 4 - 1) % contextual.size()]
	if click_number <= 3:
		var calm := [
			"Кот занят. Оставьте заявку у диспетчера.",
			"Мурчание не является официальной консультацией.",
			"Складская мышь локализована. Работы ведутся.",
		]
		return calm[(click_number - 1) % calm.size()]
	if click_number <= 7:
		var annoyed := [
			"Перерыв на сон согласован с руководством.",
			"Повторное нажатие не ускоряет обработку заявки.",
			"Специалист по когтетехническому надзору просит не мешать.",
			"За срочность предусмотрена доплата сметаной.",
		]
		return annoyed[(click_number - 4) % annoyed.size()]
	var warnings := [
		"Предупреждение: терпение специалиста заканчивается.",
		"Кот внёс вас в книгу учёта. В раздел расходов.",
		"Мяу. Перевод: отойдите от рабочего места.",
		"Последнее предупреждение перед применением когтей.",
	]
	return warnings[(click_number - 8) % warnings.size()]


func _cat_contextual_phrases() -> PackedStringArray:
	var phrases := PackedStringArray()
	if game_state.completed_job_ids.has("walking_wardrobe"):
		phrases.append("Шкаф ходил подозрительно. Как собака.")
	if game_state.completed_job_ids.has("portal_mirror") or game_state.completed_job_ids.has("escaped_ghost"):
		phrases.append("Привидение в банке? Главное, чтобы не тунец.")
	if game_state.completed_job_ids.has("frozen_bath"):
		phrases.append("Замёрзшая ванна — это большая миска. Но неудобная.")
	if game_state.completed_job_ids.has("sleeping_gargoyle"):
		phrases.append("Горгулья не мяукала. Я проверял.")
	return phrases


func _hide_cat_phrase_later(revision: int) -> void:
	await get_tree().create_timer(3.0).timeout
	if revision == cat_message_revision and cat_phrase_panel != null:
		cat_phrase_panel.visible = false


func _build_personnel_screen() -> void:
	personnel_layer = Control.new()
	personnel_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	personnel_layer.visible = false
	add_child(personnel_layer)

	var background := TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.texture = load("res://assets/ui/personnel_department_background_neutral.png") as Texture2D
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	personnel_layer.add_child(background)

	var heading := _label("СОТРУДНИКИ", 30, COLOR_GOLD)
	heading.position = Vector2(520, 35)
	heading.size = Vector2(560, 52)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	personnel_layer.add_child(heading)

	var back_button := _button("←  В ОФИС", Vector2(1190, 37), Vector2(150, 48))
	back_button.pressed.connect(_show_hub)
	personnel_layer.add_child(back_button)

	for index in PERSONNEL_ORDER.size():
		var employee_id := StringName(PERSONNEL_ORDER[index])
		var employee: Dictionary = game_state.employees[employee_id]
		var card_rect := _personnel_guide_rect("EmployeeCard%d" % (index + 1))
		var card := Button.new()
		card.position = card_rect.position
		card.size = card_rect.size
		card.add_theme_stylebox_override("normal", _style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 5))
		card.add_theme_stylebox_override("hover", _style(Color(0.18, 0.12, 0.055, 0.28), COLOR_GOLD, 2, 5))
		card.add_theme_stylebox_override("pressed", _style(Color(0.24, 0.16, 0.07, 0.36), COLOR_GOLD, 2, 5))
		card.add_theme_stylebox_override("focus", _style(Color(0.18, 0.12, 0.055, 0.22), COLOR_GOLD, 2, 5))
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.pressed.connect(_select_personnel_employee.bind(employee_id))
		personnel_layer.add_child(card)

		var name_label := _label(employee["name"], 18, COLOR_GOLD)
		name_label.position = Vector2(8, 11)
		name_label.size = Vector2(card.size.x - 16, 27)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(name_label)

		var role_label := _label(employee["role"], 13, COLOR_PARCHMENT)
		role_label.position = Vector2(8, 42)
		role_label.size = Vector2(card.size.x - 16, 22)
		role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		role_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(role_label)

		var status_label := _label("", 12, COLOR_MUTED)
		status_label.position = Vector2(8, 72)
		status_label.size = Vector2(card.size.x - 16, 21)
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(status_label)

		var clasp: TextureRect = null
		if index >= 3:
			var clasp_rect := _personnel_guide_rect("CandidateClasp%dArea" % (index + 1))
			clasp = TextureRect.new()
			clasp.position = clasp_rect.position
			clasp.size = clasp_rect.size
			clasp.texture = CANDIDATE_CLASP_TEXTURE
			clasp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			clasp.stretch_mode = TextureRect.STRETCH_SCALE
			clasp.mouse_filter = Control.MOUSE_FILTER_IGNORE
			personnel_layer.add_child(clasp)

		personnel_cards[employee_id] = {"button": card, "status": status_label, "clasp": clasp}

	var portrait_clip_rect := _personnel_guide_rect("PortraitClipArea")
	var portrait_image_rect := _personnel_guide_rect("PortraitImageArea")
	var portrait_clip := Control.new()
	portrait_clip.position = portrait_clip_rect.position
	portrait_clip.size = portrait_clip_rect.size
	portrait_clip.clip_contents = true
	portrait_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	personnel_layer.add_child(portrait_clip)

	personnel_portrait = TextureRect.new()
	personnel_portrait.position = portrait_image_rect.position - portrait_clip_rect.position
	personnel_portrait.size = portrait_image_rect.size
	personnel_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	personnel_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	personnel_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_clip.add_child(personnel_portrait)

	personnel_name = _personnel_label_from_guide("NameArea", 26, Color(0.25, 0.14, 0.055))
	personnel_role = _personnel_label_from_guide("RoleArea", 19, Color(0.34, 0.22, 0.11))
	personnel_description = _personnel_label_from_guide("DescriptionArea", 17, Color(0.24, 0.16, 0.09))
	personnel_status = _personnel_label_from_guide("StatusArea", 13, Color(0.24, 0.16, 0.09))
	personnel_strength = _personnel_label_from_guide("StrengthArea", 13, Color(0.24, 0.16, 0.09))
	personnel_weakness = _personnel_label_from_guide("WeaknessArea", 13, Color(0.24, 0.16, 0.09))
	personnel_traits = _personnel_label_from_guide("TraitsArea", 14, Color(0.24, 0.16, 0.09))
	for label in [personnel_name, personnel_role, personnel_description, personnel_status, personnel_strength, personnel_weakness, personnel_traits]:
		personnel_layer.add_child(label)

	var hire_rect := _personnel_guide_rect("StatusArea")
	personnel_hire_button = _button("", hire_rect.position + Vector2(10, -2), Vector2(hire_rect.size.x - 20, 35))
	personnel_hire_button.add_theme_font_size_override("font_size", 13)
	personnel_hire_button.pressed.connect(_hire_selected_personnel)
	personnel_layer.add_child(personnel_hire_button)
	personnel_training_button = _button("", hire_rect.position + Vector2(-10, -2), Vector2(hire_rect.size.x - 20, 35))
	personnel_training_button.add_theme_font_size_override("font_size", 13)
	personnel_training_button.clip_text = true
	personnel_training_button.custom_minimum_size = Vector2.ZERO
	personnel_training_button.pressed.connect(_train_selected_personnel)
	personnel_layer.add_child(personnel_training_button)

	personnel_specializations_button = _button("СПЕЦИАЛИЗАЦИИ", hire_rect.position + Vector2(10, -2), Vector2(hire_rect.size.x - 20, 35))
	personnel_specializations_button.add_theme_font_size_override("font_size", 12)
	personnel_specializations_button.clip_text = true
	personnel_specializations_button.custom_minimum_size = Vector2.ZERO
	personnel_specializations_button.size = Vector2(hire_rect.size.x - 20, 35)
	personnel_specializations_button.pressed.connect(_open_specializations)
	personnel_layer.add_child(personnel_specializations_button)
	_build_specialization_dialog()

	_refresh_personnel()


func _build_specialization_dialog() -> void:
	specialization_layer = Control.new()
	specialization_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	specialization_layer.visible = false
	specialization_layer.z_index = 120
	personnel_layer.add_child(specialization_layer)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.01, 0.008, 0.76)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	specialization_layer.add_child(shade)

	var panel := _panel(Vector2(500, 190), Vector2(600, 520), 14)
	specialization_layer.add_child(panel)
	specialization_title = _label("СПЕЦИАЛИЗАЦИИ", 26, COLOR_GOLD)
	specialization_title.position = Vector2(35, 30)
	specialization_title.size = Vector2(530, 42)
	specialization_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(specialization_title)
	var explanation := _label("У сотрудника две ячейки.\nЗабытая способность исчезнет из доступных действий.\nПри необходимости её можно изучить заново.", 16, COLOR_PARCHMENT)
	explanation.position = Vector2(48, 84)
	explanation.size = Vector2(504, 66)
	explanation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	explanation.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	explanation.clip_text = true
	panel.add_child(explanation)
	specialization_slots = VBoxContainer.new()
	specialization_slots.position = Vector2(60, 166)
	specialization_slots.size = Vector2(480, 150)
	specialization_slots.add_theme_constant_override("separation", 14)
	panel.add_child(specialization_slots)
	specialization_notice = _label("", 14, Color(0.96, 0.62, 0.35))
	specialization_notice.position = Vector2(55, 330)
	specialization_notice.size = Vector2(490, 50)
	specialization_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	specialization_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(specialization_notice)
	var close_button := _button("ЗАКРЫТЬ", Vector2(150, 420), Vector2(300, 54))
	close_button.pressed.connect(_close_specializations)
	panel.add_child(close_button)

	specialization_confirm_layer = Control.new()
	specialization_confirm_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	specialization_confirm_layer.visible = false
	specialization_confirm_layer.z_index = 130
	personnel_layer.add_child(specialization_confirm_layer)
	var confirm_shade := ColorRect.new()
	confirm_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirm_shade.color = Color(0.015, 0.01, 0.008, 0.82)
	confirm_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	specialization_confirm_layer.add_child(confirm_shade)
	var confirm_panel := _panel(Vector2(530, 305), Vector2(540, 290), 14)
	specialization_confirm_layer.add_child(confirm_panel)
	var confirm_title := _label("ЗАБЫТЬ СПЕЦИАЛИЗАЦИЮ?", 23, COLOR_GOLD)
	confirm_title.position = Vector2(30, 30)
	confirm_title.size = Vector2(480, 38)
	confirm_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_panel.add_child(confirm_title)
	specialization_confirm_text = _label("", 17, COLOR_PARCHMENT)
	specialization_confirm_text.position = Vector2(45, 86)
	specialization_confirm_text.size = Vector2(450, 80)
	specialization_confirm_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	specialization_confirm_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_panel.add_child(specialization_confirm_text)
	var confirm_button := _button("ЗАБЫТЬ", Vector2(45, 205), Vector2(210, 52))
	confirm_button.pressed.connect(_confirm_forget_specialization)
	confirm_panel.add_child(confirm_button)
	var cancel_button := _button("ОТМЕНА", Vector2(285, 205), Vector2(210, 52))
	cancel_button.pressed.connect(_cancel_forget_specialization)
	confirm_panel.add_child(cancel_button)


func _build_supply_shop() -> void:
	supply_layer = Control.new()
	supply_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	supply_layer.visible = false
	add_child(supply_layer)

	var background := TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.texture = load("res://assets/backgrounds/office_hub.png") as Texture2D
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.modulate = Color(0.62, 0.56, 0.48)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	supply_layer.add_child(background)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.018, 0.012, 0.008, 0.45)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	supply_layer.add_child(shade)

	var top_panel := _panel(Vector2(160, 24), Vector2(1280, 82), 12)
	supply_layer.add_child(top_panel)
	var heading := _label("ЛАВКА СНАБЖЕНИЯ", 29, COLOR_GOLD)
	heading.position = Vector2(28, 16)
	heading.size = Vector2(650, 48)
	top_panel.add_child(heading)
	supply_money_label = _label("", 20, COLOR_PARCHMENT)
	supply_money_label.position = Vector2(805, 22)
	supply_money_label.size = Vector2(210, 38)
	supply_money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_panel.add_child(supply_money_label)
	var back_button := _button("←  В ОФИС", Vector2(1040, 14), Vector2(210, 54))
	back_button.pressed.connect(_show_hub)
	top_panel.add_child(back_button)

	var catalog_panel := _panel(Vector2(160, 124), Vector2(430, 726), 12)
	supply_layer.add_child(catalog_panel)
	var catalog_heading := _label("КАТАЛОГ", 22, COLOR_GOLD)
	catalog_heading.position = Vector2(22, 17)
	catalog_heading.size = Vector2(386, 34)
	catalog_panel.add_child(catalog_heading)
	var catalog_scroll := ScrollContainer.new()
	catalog_scroll.position = Vector2(18, 60)
	catalog_scroll.size = Vector2(394, 548)
	catalog_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	catalog_panel.add_child(catalog_scroll)
	supply_catalog_list = VBoxContainer.new()
	supply_catalog_list.custom_minimum_size = Vector2(350, 0)
	supply_catalog_list.add_theme_constant_override("separation", 10)
	catalog_scroll.add_child(supply_catalog_list)
	_add_supply_catalog_section("СНАРЯЖЕНИЕ", [&"ghost_trap", &"thermal_regulator"])
	_add_supply_catalog_section("МАГИЧЕСКИЕ КУРСЫ", [&"animation_kit", &"freeze_grimoire", &"heat_grimoire", &"telekinesis_grimoire", &"antimagic_grimoire"])

	var catalog_hint := _label("Книги открывают курсы. Снаряжение остаётся у службы.", 13, COLOR_MUTED)
	catalog_hint.position = Vector2(28, 622)
	catalog_hint.size = Vector2(374, 38)
	catalog_hint.clip_text = true
	catalog_panel.add_child(catalog_hint)
	var debug_money_button := _button("ТЕСТ: +500 МОНЕТ", Vector2(28, 669), Vector2(374, 42))
	debug_money_button.add_theme_font_size_override("font_size", 14)
	debug_money_button.pressed.connect(_grant_debug_money)
	catalog_panel.add_child(debug_money_button)

	var detail_panel := _panel(Vector2(610, 124), Vector2(830, 726), 12)
	supply_layer.add_child(detail_panel)
	supply_detail_heading = _label("", 27, COLOR_GOLD)
	supply_detail_heading.position = Vector2(258, 36)
	supply_detail_heading.size = Vector2(530, 96)
	supply_detail_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_panel.add_child(supply_detail_heading)
	supply_detail_category = _label("", 17, COLOR_MUTED)
	supply_detail_category.position = Vector2(260, 134)
	supply_detail_category.size = Vector2(500, 28)
	detail_panel.add_child(supply_detail_category)
	supply_detail_icon = TextureRect.new()
	supply_detail_icon.position = Vector2(38, 38)
	supply_detail_icon.size = Vector2(180, 180)
	supply_detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	supply_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	supply_detail_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_panel.add_child(supply_detail_icon)
	supply_detail_description = _label("", 19, COLOR_PARCHMENT)
	supply_detail_description.position = Vector2(42, 260)
	supply_detail_description.size = Vector2(746, 160)
	supply_detail_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_panel.add_child(supply_detail_description)
	supply_delivery_note = _label("", 16, COLOR_MUTED)
	supply_delivery_note.position = Vector2(42, 438)
	supply_delivery_note.size = Vector2(746, 92)
	supply_delivery_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_panel.add_child(supply_delivery_note)
	supply_purchase_button = _button("", Vector2(236, 596), Vector2(360, 68))
	supply_purchase_button.pressed.connect(_buy_selected_supply_item)
	detail_panel.add_child(supply_purchase_button)

	_refresh_supply_shop()


func _add_supply_catalog_section(title: String, item_ids: Array[StringName]) -> void:
	var section_label := _label(title, 15, COLOR_MUTED)
	section_label.custom_minimum_size = Vector2(350, 30)
	section_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	supply_catalog_list.add_child(section_label)
	for item_id: StringName in item_ids:
		var item: Dictionary = game_state.SUPPLY_ITEMS[item_id]
		var item_card := _button("", Vector2.ZERO, Vector2(350, 106))
		item_card.custom_minimum_size = Vector2(350, 106)
		item_card.pressed.connect(_select_supply_item.bind(item_id))
		supply_catalog_list.add_child(item_card)
		var catalog_icon := TextureRect.new()
		catalog_icon.position = Vector2(10, 10)
		catalog_icon.size = Vector2(82, 82)
		catalog_icon.texture = load(str(item["icon"])) as Texture2D
		catalog_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		catalog_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		catalog_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_card.add_child(catalog_icon)
		var catalog_name := _label(str(item.get("catalog_name", item["name"])), 14, COLOR_GOLD)
		catalog_name.position = Vector2(100, 12)
		catalog_name.size = Vector2(234, 46)
		catalog_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		catalog_name.clip_text = true
		catalog_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_card.add_child(catalog_name)
		var status := _label("", 13, COLOR_PARCHMENT)
		status.position = Vector2(100, 68)
		status.size = Vector2(234, 24)
		status.clip_text = true
		status.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_card.add_child(status)
		supply_catalog_cards[item_id] = item_card
		supply_catalog_statuses[item_id] = status


func _personnel_label(label_position: Vector2, label_size: Vector2, font_size: int, color: Color) -> Label:
	var label := _label("", font_size, color)
	label.position = label_position
	label.size = label_size
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.clip_text = true
	label.add_theme_color_override("font_shadow_color", Color(1, 0.92, 0.72, 0.25))
	return label


func _personnel_label_from_guide(guide_name: String, font_size: int, color: Color) -> Label:
	var guide_rect := _personnel_guide_rect(guide_name)
	return _personnel_label(guide_rect.position, guide_rect.size, font_size, color)


func _personnel_guide_rect(guide_name: String) -> Rect2:
	var guide := get_node("PersonnelEditorPreview/%s" % guide_name) as Control
	return Rect2(guide.position, guide.size)


func _build_office_menu_button() -> void:
	var menu_texture := load("res://assets/ui/office_menu.png") as Texture2D
	if menu_texture == null:
		return

	var button := TextureButton.new()
	button.name = "OfficeMenuButton"
	button.position = Vector2(-8, 650)
	button.size = Vector2(350, 350)
	button.texture_normal = menu_texture
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = "Меню (Esc)"
	button.pivot_offset = button.size * 0.5
	button.z_index = 30
	button.self_modulate = Color(0.68, 0.65, 0.72, 1.0)

	var image := menu_texture.get_image()
	if image != null:
		var click_mask := BitMap.new()
		click_mask.create_from_image_alpha(image, 0.12)
		button.texture_click_mask = click_mask

	button.mouse_entered.connect(func() -> void:
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(button, "scale", Vector2(1.035, 1.035), 0.14)
		tween.tween_property(button, "self_modulate", Color(0.76, 0.72, 0.78, 1.0), 0.14)
	)
	button.mouse_exited.connect(func() -> void:
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(button, "scale", Vector2.ONE, 0.14)
		tween.tween_property(button, "self_modulate", Color(0.68, 0.65, 0.72, 1.0), 0.14)
	)
	button.pressed.connect(_open_pause_menu)
	hub_layer.add_child(button)


func _open_pause_menu() -> void:
	var pause_menu := get_tree().current_scene.get_node_or_null("PauseMenu")
	if pause_menu != null and pause_menu.has_method("open_menu"):
		pause_menu.call("open_menu")


func _add_hotspot(area: Rect2, title_text: String, subtitle_text: String, action: Callable) -> void:
	var button := Button.new()
	button.position = area.position
	button.size = area.size
	button.add_theme_stylebox_override("normal", _style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 10))
	button.add_theme_stylebox_override("hover", _style(Color(0.15, 0.10, 0.035, 0.20), COLOR_GOLD, 3, 10))
	button.add_theme_stylebox_override("pressed", _style(Color(0.10, 0.16, 0.18, 0.30), COLOR_GOLD, 4, 10))
	button.add_theme_stylebox_override("focus", _style(Color(0.15, 0.10, 0.035, 0.16), COLOR_GOLD, 3, 10))
	button.pressed.connect(action)
	hub_layer.add_child(button)
	_attach_hotspot_caption(button, area.size, title_text, subtitle_text)


func _connect_editable_hotspot(hotspot: Control, title_text: String, subtitle_text: String, action: Callable) -> void:
	hotspot.reparent(hub_layer, true)
	hotspot.activated.connect(action)
	_attach_hotspot_caption(hotspot, hotspot.size, title_text, subtitle_text)


func _attach_hotspot_caption(hotspot_owner: Control, owner_size: Vector2, title_text: String, subtitle_text: String) -> void:
	var caption := Panel.new()
	var caption_width := maxf(owner_size.x - 24, 320.0)
	caption.position = Vector2((owner_size.x - caption_width) * 0.5, owner_size.y - 78)
	caption.size = Vector2(caption_width, 66)
	caption.visible = false
	caption.z_index = 20
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_stylebox_override("panel", _style(Color(0.035, 0.025, 0.018, 0.94), COLOR_BRASS, 2, 7))
	hotspot_owner.add_child(caption)

	var title_label := _label(title_text, 19, COLOR_GOLD)
	title_label.position = Vector2(10, 7)
	title_label.size = Vector2(caption.size.x - 20, 27)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_child(title_label)

	var subtitle_label := _label(subtitle_text, 14, COLOR_PARCHMENT)
	subtitle_label.position = Vector2(10, 34)
	subtitle_label.size = Vector2(caption.size.x - 20, 22)
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_child(subtitle_label)

	hotspot_owner.mouse_entered.connect(func() -> void: caption.visible = true)
	hotspot_owner.mouse_exited.connect(func() -> void: caption.visible = false)


func _build_section_dialog() -> void:
	section_dialog = _panel(Vector2(480, 260), Vector2(640, 380), 14)
	section_dialog.visible = false
	hub_layer.add_child(section_dialog)

	section_title = _label("", 28, COLOR_GOLD)
	section_title.position = Vector2(35, 32)
	section_title.size = Vector2(570, 44)
	section_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section_dialog.add_child(section_title)

	section_body = _label("", 18, COLOR_PARCHMENT)
	section_body.position = Vector2(48, 98)
	section_body.size = Vector2(544, 160)
	section_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	section_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section_dialog.add_child(section_body)

	var close_button := _button("ВЕРНУТЬСЯ В ОФИС", Vector2(120, 292), Vector2(400, 58))
	close_button.pressed.connect(func() -> void: section_dialog.visible = false)
	section_dialog.add_child(close_button)


func _build_job_report_dialog() -> void:
	job_report_layer = Control.new()
	job_report_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	job_report_layer.visible = false
	job_report_layer.z_index = 100
	hub_layer.add_child(job_report_layer)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.01, 0.008, 0.72)
	job_report_layer.add_child(shade)

	var panel := _panel(Vector2(410, 165), Vector2(780, 570), 14)
	job_report_layer.add_child(panel)
	job_report_title = _label("АКТ ВЫПОЛНЕННЫХ РАБОТ", 27, COLOR_GOLD)
	job_report_title.position = Vector2(42, 34)
	job_report_title.size = Vector2(696, 48)
	job_report_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(job_report_title)
	job_report_body = _label("", 18, COLOR_PARCHMENT)
	job_report_body.position = Vector2(66, 108)
	job_report_body.size = Vector2(648, 328)
	job_report_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	job_report_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(job_report_body)
	var close_button := _button("ПРИНЯТЬ ОТЧЁТ", Vector2(210, 468), Vector2(360, 62))
	close_button.pressed.connect(_dismiss_job_report)
	panel.add_child(close_button)


func _build_claim_dialog() -> void:
	claim_layer = Control.new()
	claim_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	claim_layer.visible = false
	claim_layer.z_index = 110
	hub_layer.add_child(claim_layer)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.01, 0.008, 0.78)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	claim_layer.add_child(shade)
	var panel := _panel(Vector2(390, 225), Vector2(820, 450), 14)
	claim_layer.add_child(panel)
	claim_title = _label("ПРЕТЕНЗИЯ ЖИЛЬЦА", 28, COLOR_GOLD)
	claim_title.position = Vector2(45, 34)
	claim_title.size = Vector2(730, 48)
	claim_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(claim_title)
	claim_body = _label("", 19, COLOR_PARCHMENT)
	claim_body.position = Vector2(70, 102)
	claim_body.size = Vector2(680, 190)
	claim_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	claim_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	claim_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(claim_body)
	claim_pay_button = _button("", Vector2(55, 340), Vector2(330, 68))
	claim_pay_button.pressed.connect(_resolve_claim.bind(true))
	panel.add_child(claim_pay_button)
	var deny_button := _button("ОТКАЗАТЬ В КОМПЕНСАЦИИ", Vector2(435, 340), Vector2(330, 68))
	deny_button.pressed.connect(_resolve_claim.bind(false))
	panel.add_child(deny_button)


func _build_arrival_dialog() -> void:
	arrival_dialog = Control.new()
	arrival_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	arrival_dialog.visible = false
	arrival_dialog.z_index = 200
	add_child(arrival_dialog)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.01, 0.008, 0.72)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	arrival_dialog.add_child(shade)
	var panel := _panel(Vector2(430, 285), Vector2(740, 330), 14)
	arrival_dialog.add_child(panel)
	arrival_dialog_title = _label("БРИГАДА ЕЩЁ В ПУТИ", 25, COLOR_GOLD)
	arrival_dialog_title.position = Vector2(38, 34)
	arrival_dialog_title.size = Vector2(664, 42)
	arrival_dialog_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(arrival_dialog_title)
	arrival_dialog_body = _label("На объекте пока никого нет. Ускорить время до прибытия первого сотрудника?", 18, COLOR_PARCHMENT)
	arrival_dialog_body.position = Vector2(64, 104)
	arrival_dialog_body.size = Vector2(612, 92)
	arrival_dialog_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrival_dialog_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrival_dialog_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(arrival_dialog_body)
	var yes_button := _button("ДА, УСКОРИТЬ", Vector2(74, 232), Vector2(280, 58))
	yes_button.pressed.connect(_start_auto_wait)
	panel.add_child(yes_button)
	var no_button := _button("НЕТ", Vector2(386, 232), Vector2(280, 58))
	no_button.pressed.connect(func() -> void: arrival_dialog.visible = false)
	panel.add_child(no_button)


func _build_dispatch_warning_dialog() -> void:
	dispatch_warning_dialog = Control.new()
	dispatch_warning_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dispatch_warning_dialog.visible = false
	dispatch_warning_dialog.z_index = 210
	add_child(dispatch_warning_dialog)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.01, 0.008, 0.76)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	dispatch_warning_dialog.add_child(shade)
	var panel := _panel(Vector2(410, 260), Vector2(780, 380), 14)
	dispatch_warning_dialog.add_child(panel)
	var title := _label("В БРИГАДЕ НЕТ АНТИМАГИИ", 25, COLOR_GOLD)
	title.position = Vector2(38, 34)
	title.size = Vector2(704, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)
	dispatch_warning_body = _label("", 18, COLOR_PARCHMENT)
	dispatch_warning_body.position = Vector2(70, 100)
	dispatch_warning_body.size = Vector2(640, 120)
	dispatch_warning_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dispatch_warning_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dispatch_warning_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(dispatch_warning_body)
	var proceed_button := _button("ВСЁ РАВНО ОТПРАВИТЬ", Vector2(60, 278), Vector2(310, 62))
	proceed_button.pressed.connect(_confirm_risky_dispatch)
	panel.add_child(proceed_button)
	var back_button := _button("ВЕРНУТЬСЯ К СОСТАВУ", Vector2(410, 278), Vector2(310, 62))
	back_button.pressed.connect(func() -> void: dispatch_warning_dialog.visible = false)
	panel.add_child(back_button)


func _build_demo_completion_dialog() -> void:
	demo_completion_layer = $DemoCompletionLayer
	demo_completion_layer.visible = false
	demo_completion_title = $DemoCompletionLayer/Title
	demo_completion_summary = $DemoCompletionLayer/Summary
	var menu_button: Button = $DemoCompletionLayer/MenuButton
	_style_button(menu_button)
	menu_button.pressed.connect(_start_demo_video)


func _build_demo_video() -> void:
	demo_video_layer = Control.new()
	demo_video_layer.name = "DemoVideoLayer"
	demo_video_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	demo_video_layer.z_index = 310
	demo_video_layer.visible = false
	add_child(demo_video_layer)

	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color.BLACK
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	demo_video_layer.add_child(background)

	demo_video_player = VideoStreamPlayer.new()
	demo_video_player.name = "LiliyaFarewell"
	demo_video_player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	demo_video_player.expand = true
	demo_video_player.modulate = Color(1, 1, 1, 0)
	demo_video_player.stream = load("res://assets/video/lili_buy.ogv") as VideoStream
	demo_video_player.finished.connect(_finish_demo_video)
	demo_video_layer.add_child(demo_video_player)


func _input(event: InputEvent) -> void:
	var is_action_button := event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton
	if not is_action_button or not event.is_pressed() or event.is_echo():
		return
	if demo_completion_layer != null and demo_completion_layer.visible:
		get_viewport().set_input_as_handled()
		_start_demo_video()
	elif demo_video_layer != null and demo_video_layer.visible and demo_video_can_skip:
		get_viewport().set_input_as_handled()
		_finish_demo_video()


func _start_demo_video() -> void:
	if demo_video_transitioning or demo_video_layer == null or demo_video_player == null:
		return
	demo_video_transitioning = true
	demo_video_can_skip = false
	demo_completion_layer.visible = false
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager != null and audio_manager.has_method(&"stop_office_music"):
		audio_manager.call(&"stop_office_music")
	demo_video_layer.modulate = Color.WHITE
	demo_video_layer.visible = true
	demo_video_layer.move_to_front()
	demo_video_player.modulate = Color(1, 1, 1, 0)
	await get_tree().create_timer(0.4).timeout
	demo_video_player.play()
	var fade := create_tween()
	fade.tween_property(demo_video_player, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.55).timeout
	demo_video_can_skip = true
	demo_video_transitioning = false


func _finish_demo_video() -> void:
	if demo_video_transitioning or demo_video_layer == null or not demo_video_layer.visible:
		return
	demo_video_transitioning = true
	demo_video_can_skip = false
	game_state.mark_demo_completion_seen()
	var fade := create_tween()
	fade.tween_property(demo_video_player, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await fade.finished
	demo_video_player.stop()
	await get_tree().create_timer(0.35).timeout
	get_tree().change_scene_to_file("res://scenes/TitleScreen.tscn")


func _open_jobs() -> void:
	hub_layer.visible = false
	personnel_layer.visible = false
	supply_layer.visible = false
	equipment_layer.visible = false
	city_map_layer.visible = false
	books_layer.visible = false
	dashboard_layer.visible = true
	_refresh()


func _open_personnel() -> void:
	hub_layer.visible = false
	dashboard_layer.visible = false
	supply_layer.visible = false
	equipment_layer.visible = false
	city_map_layer.visible = false
	books_layer.visible = false
	personnel_layer.visible = true
	_refresh_personnel()


func _open_supply_shop() -> void:
	hub_layer.visible = false
	dashboard_layer.visible = false
	personnel_layer.visible = false
	city_map_layer.visible = false
	books_layer.visible = false
	equipment_layer.visible = false
	supply_layer.visible = true
	_refresh_supply_shop()


func _build_equipment_storage() -> void:
	equipment_layer = Control.new()
	equipment_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	equipment_layer.visible = false
	add_child(equipment_layer)

	var background := TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.texture = load("res://assets/backgrounds/office_hub.png") as Texture2D
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	equipment_layer.add_child(background)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.01, 0.008, 0.76)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	equipment_layer.add_child(shade)

	var top_panel := _panel(Vector2(150, 80), Vector2(1300, 100), 14)
	equipment_layer.add_child(top_panel)
	var heading := _label("СКЛАД СНАРЯЖЕНИЯ", 28, COLOR_GOLD)
	heading.position = Vector2(28, 17)
	heading.size = Vector2(700, 42)
	top_panel.add_child(heading)
	var subtitle := _label("Служебное имущество и купленное полевое оборудование", 15, COLOR_MUTED)
	subtitle.position = Vector2(30, 55)
	subtitle.size = Vector2(760, 28)
	top_panel.add_child(subtitle)
	var back_button := _button("←  В ОФИС", Vector2(1068, 20), Vector2(204, 60))
	back_button.pressed.connect(_show_hub)
	top_panel.add_child(back_button)

	var content_panel := _panel(Vector2(150, 198), Vector2(1300, 620), 14)
	equipment_layer.add_child(content_panel)
	equipment_cards = HBoxContainer.new()
	equipment_cards.position = Vector2(34, 40)
	equipment_cards.size = Vector2(1232, 510)
	equipment_cards.add_theme_constant_override("separation", 22)
	content_panel.add_child(equipment_cards)
	var hint := _label("Магические книги хранятся в учебном фонде и на склад не поступают.", 15, COLOR_MUTED)
	hint.position = Vector2(40, 566)
	hint.size = Vector2(1220, 28)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_panel.add_child(hint)
	_refresh_equipment_storage()


func _open_equipment_storage() -> void:
	hub_layer.visible = false
	dashboard_layer.visible = false
	personnel_layer.visible = false
	supply_layer.visible = false
	city_map_layer.visible = false
	books_layer.visible = false
	equipment_layer.visible = true
	_refresh_equipment_storage()


func _refresh_equipment_storage() -> void:
	if equipment_cards == null:
		return
	for child: Node in equipment_cards.get_children():
		child.queue_free()
	_add_equipment_card(
		"Ремонтный набор Бориса",
		"СЛУЖЕБНОЕ СНАРЯЖЕНИЕ\nВСЕГДА В НАЛИЧИИ",
		"res://assets/objects/repair_kit/toolbox.png",
		"Инструменты Бориса для диагностики\nи обычного ремонта. Набор не расходуется."
	)
	if game_state.has_supply_item(&"ghost_trap"):
		_add_equipment_card(
			str(game_state.SUPPLY_ITEMS[&"ghost_trap"]["name"]),
			_equipment_status(&"ghost_trap"),
			str(game_state.SUPPLY_ITEMS[&"ghost_trap"]["icon"]),
			"Переносная ловушка для безопасного захвата бестелесных существ."
		)
	if game_state.has_supply_item(&"thermal_regulator"):
		_add_equipment_card(
			str(game_state.SUPPLY_ITEMS[&"thermal_regulator"]["name"]),
			_equipment_status(&"thermal_regulator"),
			str(game_state.SUPPLY_ITEMS[&"thermal_regulator"]["icon"]),
			"Стабилизирует магическую температуру воды после установки на объекте."
		)


func _add_equipment_card(item_name: String, status_text: String, icon_path: String, description: String) -> void:
	var card := Panel.new()
	card.custom_minimum_size = Vector2(395, 500)
	card.add_theme_stylebox_override("panel", _style(COLOR_CARD, COLOR_BRASS, 2, 12))
	equipment_cards.add_child(card)
	var icon := TextureRect.new()
	icon.position = Vector2(72, 28)
	icon.size = Vector2(250, 225)
	icon.texture = load(icon_path) as Texture2D
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(icon)
	var title := _label(item_name, 21, COLOR_GOLD)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.position = Vector2(28, 270)
	title.size = Vector2(339, 62)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card.add_child(title)
	var status := _label(status_text, 14, Color(0.96, 0.68, 0.34))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.position = Vector2(24, 342)
	status.size = Vector2(347, 44)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.clip_text = true
	card.add_child(status)
	var body := _label(description, 15, COLOR_PARCHMENT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.position = Vector2(34, 404)
	body.size = Vector2(327, 72)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	body.clip_text = true
	card.add_child(body)


func _equipment_status(item_id: StringName) -> String:
	var job_id: StringName = &"escaped_ghost" if item_id == &"ghost_trap" else &"frozen_bath"
	var active_state: Dictionary = game_state.get_job_repair_state(job_id)
	var active_object: Variant = active_state.get("world_object", {})
	if active_object is Dictionary:
		if item_id == &"ghost_trap":
			var trap_state := StringName(str((active_object as Dictionary).get("trap_state", "packed")))
			if trap_state == &"occupied":
				return "ЗАНЯТА • ПРИВИДЕНИЕ В ЛОВУШКЕ"
			if trap_state == &"installed":
				return "УСТАНОВЛЕНА НА ОБЪЕКТЕ"
		elif bool((active_object as Dictionary).get("regulator_installed", false)):
			return "УСТАНОВЛЕН • СТАРЫЙ КВАРТАЛ, 5"
	for report_value: Variant in game_state.job_reports:
		if not report_value is Dictionary:
			continue
		var report: Dictionary = report_value
		if item_id == &"ghost_trap" and str(report.get("job_id", "")) == "escaped_ghost":
			for action_value: Variant in report.get("actions", []):
				if action_value is Dictionary and str((action_value as Dictionary).get("action_id", "")) == "trap":
					var action_result: Variant = (action_value as Dictionary).get("result", {})
					if action_result is Dictionary and bool((action_result as Dictionary).get("applied", false)):
						return "ЗАНЯТА • ПРИВИДЕНИЕ В ЛОВУШКЕ"
		elif item_id == &"thermal_regulator" and str(report.get("job_id", "")) == "frozen_bath" and int(report.get("expense_reimbursement", 0)) > 0:
			return "УСТАНОВЛЕН • СТАРЫЙ КВАРТАЛ, 5"
	return "НА СКЛАДЕ • ГОТОВО К ВЫЕЗДУ"


func _build_city_map() -> void:
	city_map_layer = CITY_MAP_SCENE.instantiate()
	city_map_layer.visible = false
	city_map_layer.back_requested.connect(_show_hub)
	city_map_layer.job_selected.connect(_open_job_from_map)
	add_child(city_map_layer)


func _open_city_map() -> void:
	hub_layer.visible = false
	dashboard_layer.visible = false
	personnel_layer.visible = false
	supply_layer.visible = false
	equipment_layer.visible = false
	books_layer.visible = false
	city_map_layer.visible = true
	city_map_layer.refresh()


func _open_job_from_map(job_id: StringName) -> void:
	selected_job_id = job_id
	pending_dispatch_employee_ids.clear()
	_open_jobs()


func _build_books() -> void:
	books_layer = OFFICE_BOOKS_SCENE.instantiate()
	books_layer.visible = false
	books_layer.back_requested.connect(_show_hub)
	add_child(books_layer)


func _open_books(section: StringName) -> void:
	hub_layer.visible = false
	dashboard_layer.visible = false
	personnel_layer.visible = false
	supply_layer.visible = false
	equipment_layer.visible = false
	city_map_layer.visible = false
	books_layer.visible = true
	books_layer.open_section(section)


func _show_hub() -> void:
	dashboard_layer.visible = false
	personnel_layer.visible = false
	supply_layer.visible = false
	equipment_layer.visible = false
	city_map_layer.visible = false
	books_layer.visible = false
	hub_layer.visible = true
	section_dialog.visible = false


func _open_section(title_text: String, subtitle_text: String, description: String) -> void:
	section_title.text = title_text
	section_body.text = "%s\n\n%s\n\nРаздел подготовлен для следующего этапа разработки." % [subtitle_text, description]
	section_dialog.visible = true
	section_dialog.move_to_front()


func _refresh() -> void:
	game_state.selected_job_id = selected_job_id
	if not game_state.is_job_available(selected_job_id):
		selected_job_id = &""
		for available_job_id: StringName in game_state.jobs:
			if game_state.is_job_available(available_job_id):
				selected_job_id = available_job_id
				game_state.selected_job_id = available_job_id
				break
	day_label.text = "День %d" % game_state.day
	money_label.text = "%d монет" % game_state.money
	_rebuild_jobs()
	_rebuild_employees()
	_refresh_details()
	if personnel_layer != null:
		_refresh_personnel()
	if supply_layer != null:
		_refresh_supply_shop()
	if equipment_layer != null:
		_refresh_equipment_storage()
	_refresh_job_report()
	_refresh_demo_completion()


func _refresh_demo_completion() -> void:
	if demo_completion_layer == null:
		return
	var should_show: bool = game_state.should_show_demo_completion()
	demo_completion_layer.visible = should_show
	if not should_show:
		return
	var summary: Dictionary = game_state.get_demo_summary()
	var titles: PackedStringArray = summary.get("titles", PackedStringArray(["Новая служба"]))
	demo_completion_summary.text = "Выполнено заявок: %d из %d\nРепутация: %d\nПрозвища службы:\n%s\nКазна: %d монет\nЗаявок с ущербом: %d\nПретензий жильцов: %d\nВыплачено компенсаций: %d монет" % [
		int(summary.get("completed_jobs", 0)), int(summary.get("required_jobs", 0)), int(summary.get("reputation", 0)),
		", ".join(titles), int(summary.get("money", 0)), int(summary.get("damaged_jobs", 0)),
		int(summary.get("claims", 0)), int(summary.get("compensation_paid", 0)),
	]
	demo_completion_layer.move_to_front()


func _refresh_job_report() -> void:
	if job_report_layer == null:
		return
	var report: Dictionary = game_state.pending_job_report
	job_report_layer.visible = not report.is_empty()
	if report.is_empty():
		return
	var crew: Array = report.get("crew", [])
	var crew_text: String = ", ".join(PackedStringArray(crew)) if not crew.is_empty() else "бригада не указана"
	var compensation: int = int(report.get("compensation", 0))
	var finance_text: String = "Оплата: %d монет" % int(report.get("reward", 0))
	var expense_reimbursement := int(report.get("expense_reimbursement", 0))
	if expense_reimbursement > 0:
		finance_text += "\nВключено возмещение снаряжения: %d монет" % expense_reimbursement
	if bool(report.get("maximum_payment", false)):
		finance_text += " — максимальная по заявке\nОценка выполнения: отлично"
	if compensation > 0:
		finance_text += "\nКомпенсация жильцу: %d монет\nИзменение средств службы: %d монет" % [compensation, int(report.get("net_change", -compensation))]
	elif int(report.get("claim_amount", 0)) > 0:
		finance_text += "\nПретензия жильца: %d монет\nРешение потребуется после принятия акта" % int(report.get("claim_amount", 0))
	job_report_body.text = "%s\n\nЗаказчик: %s\nБригада: %s\n\n%s\n\n%s" % [report.get("title", "Заявка"), report.get("resident", ""), crew_text, finance_text, report.get("summary", "")]


func _dismiss_job_report() -> void:
	if str(game_state.pending_job_report.get("claim_status", "none")) == "pending":
		job_report_layer.visible = false
		_show_claim_dialog()
		return
	game_state.dismiss_pending_job_report()


func _show_claim_dialog() -> void:
	var report: Dictionary = game_state.pending_job_report
	var amount := int(report.get("claim_amount", 0))
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager != null and audio_manager.has_method(&"play_complaint"):
		audio_manager.call(&"play_complaint")
	claim_title.text = "ПРЕТЕНЗИЯ • %s" % str(report.get("resident", "Жилец"))
	claim_body.text = "%s\n\nТребование за причинённый ущерб: %d монет.\n\nКомпенсировать ущерб или отказать жильцу?" % [report.get("title", "Завершённая заявка"), amount]
	claim_pay_button.text = "КОМПЕНСИРОВАТЬ • %d" % amount
	claim_layer.visible = true
	claim_layer.move_to_front()


func _resolve_claim(pay_compensation: bool) -> void:
	if not game_state.resolve_pending_claim(pay_compensation):
		return
	claim_layer.visible = false
	game_state.dismiss_pending_job_report()


func _select_personnel_employee(employee_id: StringName) -> void:
	selected_employee_id = employee_id
	if specialization_layer != null:
		specialization_layer.visible = false
	if specialization_confirm_layer != null:
		specialization_confirm_layer.visible = false
	_refresh_personnel()


func _hire_selected_personnel() -> void:
	game_state.hire_employee(selected_employee_id)


func _train_selected_personnel() -> void:
	game_state.train_employee(selected_employee_id, selected_training_id)


func _open_specializations() -> void:
	if not bool(game_state.employees[selected_employee_id]["available"]):
		return
	pending_forget_ability_id = &""
	specialization_confirm_layer.visible = false
	specialization_layer.visible = true
	_refresh_specialization_dialog()


func _close_specializations() -> void:
	pending_forget_ability_id = &""
	specialization_confirm_layer.visible = false
	specialization_layer.visible = false


func _refresh_specialization_dialog() -> void:
	if specialization_slots == null or not game_state.employees.has(selected_employee_id):
		return
	_clear(specialization_slots)
	var employee: Dictionary = game_state.employees[selected_employee_id]
	specialization_title.text = "СПЕЦИАЛИЗАЦИИ • %s" % employee["name"]
	var abilities: PackedStringArray = employee["abilities"]
	var slot_count: int = int(employee.get("max_special_abilities", 2))
	for slot_index in slot_count:
		if slot_index >= abilities.size():
			var empty_button := _button("ЯЧЕЙКА %d • СВОБОДНА" % (slot_index + 1), Vector2.ZERO, Vector2(480, 58))
			empty_button.disabled = true
			specialization_slots.add_child(empty_button)
			continue
		var ability_id := StringName(abilities[slot_index])
		var forget_state: StringName = game_state.get_forget_availability(selected_employee_id, ability_id)
		var ability_button := _button("%s  •  ЗАБЫТЬ" % game_state.get_ability_name(ability_id).to_upper(), Vector2.ZERO, Vector2(480, 58))
		ability_button.disabled = forget_state != &"available"
		ability_button.tooltip_text = _forget_state_text(forget_state)
		ability_button.pressed.connect(_request_forget_specialization.bind(ability_id))
		specialization_slots.add_child(ability_button)
	var general_state: StringName = game_state.get_forget_availability(selected_employee_id, StringName(abilities[0])) if not abilities.is_empty() else &"available"
	specialization_notice.text = _forget_state_text(general_state) if general_state != &"available" else "Выберите занятую ячейку, чтобы освободить её."


func _request_forget_specialization(ability_id: StringName) -> void:
	if game_state.get_forget_availability(selected_employee_id, ability_id) != &"available":
		_refresh_specialization_dialog()
		return
	pending_forget_ability_id = ability_id
	specialization_confirm_text.text = "%s забудет специализацию «%s». Это действие нельзя отменить без повторного обучения." % [
		game_state.employees[selected_employee_id]["name"], game_state.get_ability_name(ability_id),
	]
	specialization_confirm_layer.visible = true


func _cancel_forget_specialization() -> void:
	pending_forget_ability_id = &""
	specialization_confirm_layer.visible = false


func _confirm_forget_specialization() -> void:
	if not pending_forget_ability_id.is_empty():
		game_state.forget_employee_ability(selected_employee_id, pending_forget_ability_id)
	pending_forget_ability_id = &""
	specialization_confirm_layer.visible = false
	_refresh_specialization_dialog()


func _forget_state_text(state: StringName) -> String:
	match state:
		&"available":
			return "Специализацию можно забыть."
		&"assigned":
			return "Сначала снимите сотрудника с заявки."
		&"returning":
			return "Дождитесь возвращения сотрудника."
		&"training":
			return "Нельзя забывать способности во время обучения."
		&"not_hired":
			return "Сотрудник ещё не нанят."
	return "Специализацию сейчас нельзя забыть."


func _select_supply_item(item_id: StringName) -> void:
	if not game_state.SUPPLY_ITEMS.has(item_id):
		return
	selected_supply_item_id = item_id
	var training_id := StringName(str(game_state.SUPPLY_ITEMS[item_id].get("training_id", "")))
	if not training_id.is_empty():
		selected_training_id = training_id
	_refresh_supply_shop()


func _buy_selected_supply_item() -> void:
	game_state.buy_supply_item(selected_supply_item_id)


func _grant_debug_money() -> void:
	game_state.grant_debug_money(500)


func _advance_debug_day() -> void:
	game_state.advance_day(1)


func _finish_day() -> void:
	if game_state.try_finish_day():
		game_state.save_autosave()


func _refresh_supply_shop() -> void:
	if supply_purchase_button == null:
		return
	if not game_state.SUPPLY_ITEMS.has(selected_supply_item_id):
		selected_supply_item_id = &"animation_kit"
	var item: Dictionary = game_state.SUPPLY_ITEMS[selected_supply_item_id]
	var price := int(item["price"])
	var owned: bool = game_state.has_supply_item(selected_supply_item_id)
	supply_money_label.text = "В казне: %d монет" % game_state.money
	for item_id_value: Variant in game_state.SUPPLY_ITEMS:
		var item_id := StringName(str(item_id_value))
		var catalog_item: Dictionary = game_state.SUPPLY_ITEMS[item_id]
		var card: Button = supply_catalog_cards.get(item_id)
		var status: Label = supply_catalog_statuses.get(item_id)
		var catalog_owned: bool = game_state.has_supply_item(item_id)
		status.text = "ПРИОБРЕТЕНО" if catalog_owned else "%d МОНЕТ" % int(catalog_item["price"])
		status.add_theme_color_override("font_color", COLOR_GOLD if catalog_owned else COLOR_PARCHMENT)
		card.add_theme_stylebox_override("normal", _style(COLOR_SELECTED if item_id == selected_supply_item_id else COLOR_CARD, COLOR_GOLD if item_id == selected_supply_item_id else COLOR_BRASS, 2, 9))
	supply_detail_heading.text = str(item["name"])
	supply_detail_category.text = str(item["category"])
	supply_detail_icon.texture = load(str(item["icon"])) as Texture2D
	supply_detail_description.text = str(item["description"])
	var training_id := StringName(str(item.get("training_id", "")))
	if training_id.is_empty():
		supply_delivery_note.text = "После покупки снаряжение поступит в собственность службы и станет доступно на подходящих заявках."
	else:
		supply_delivery_note.text = "После покупки книга откроет курс «%s». Выберите её в каталоге, затем откройте личное дело совместимого сотрудника." % game_state.TRAINING_DEFINITIONS[training_id]["name"]
	if owned:
		supply_purchase_button.text = "ПРИОБРЕТЕНО"
		supply_purchase_button.disabled = true
	elif game_state.money < price:
		supply_purchase_button.text = "НЕ ХВАТАЕТ МОНЕТ • %d" % price
		supply_purchase_button.disabled = true
	else:
		supply_purchase_button.text = "КУПИТЬ • %d МОНЕТ" % price
		supply_purchase_button.disabled = false


func _refresh_personnel() -> void:
	if personnel_portrait == null or not game_state.employees.has(selected_employee_id):
		return
	for employee_id: StringName in personnel_cards:
		var card_data: Dictionary = personnel_cards[employee_id]
		var card: Button = card_data["button"]
		var status_label: Label = card_data["status"]
		var listed_employee: Dictionary = game_state.employees[employee_id]
		var clasp: TextureRect = card_data["clasp"]
		if clasp != null:
			clasp.visible = not listed_employee["available"]
		if not listed_employee["available"]:
			status_label.text = "КАНДИДАТ"
		elif not game_state.get_employee_job(employee_id).is_empty():
			status_label.text = "НА ЗАЯВКЕ"
		else:
			status_label.text = listed_employee["status"].to_upper()
		if employee_id == selected_employee_id:
			card.add_theme_stylebox_override("normal", _style(Color(0.22, 0.145, 0.06, 0.30), COLOR_GOLD, 2, 5))
			status_label.add_theme_color_override("font_color", COLOR_GOLD)
		else:
			card.add_theme_stylebox_override("normal", _style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 5))
			status_label.add_theme_color_override("font_color", COLOR_MUTED)
	var employee: Dictionary = game_state.employees[selected_employee_id]
	personnel_portrait.texture = load(employee["portrait"]) as Texture2D
	personnel_name.text = employee["name"]
	personnel_role.text = employee["role"]
	personnel_description.text = employee["description"]
	personnel_status.text = "СТАТУС\n%s" % employee["status"]
	personnel_strength.text = employee["strength"]
	personnel_weakness.text = employee["weakness"]
	var abilities: PackedStringArray = employee["abilities"]
	var specialization: String = _employee_specialization_text(employee)
	if not game_state.TRAINING_DEFINITIONS.has(selected_training_id):
		selected_training_id = &"animate"
	var training_state: StringName = game_state.get_training_availability(selected_employee_id, selected_training_id)
	var training_definition: Dictionary = game_state.TRAINING_DEFINITIONS[selected_training_id]
	personnel_traits.text = "ОСОБЕННОСТИ\n%s\n\nСПЕЦИАЛИЗАЦИЯ\n%s\n\nКУРС «%s»\n%s" % [
		employee["traits"], specialization, training_definition["name"], _training_state_text(training_state, employee),
	]
	var is_candidate: bool = not bool(employee["available"])
	var specialization_slots_full: bool = abilities.size() >= int(employee.get("max_special_abilities", 2))
	personnel_status.visible = false
	personnel_hire_button.visible = is_candidate
	personnel_training_button.visible = not is_candidate and not specialization_slots_full
	personnel_specializations_button.visible = not is_candidate and specialization_slots_full
	if is_candidate:
		var hire_cost := int(employee.get("hire_cost", 0))
		personnel_hire_button.disabled = game_state.money < hire_cost
		personnel_hire_button.text = "НАНЯТЬ • %d МОНЕТ" % hire_cost if not personnel_hire_button.disabled else "НУЖНО %d МОНЕТ" % hire_cost
	else:
		var action_rect := _personnel_guide_rect("StatusArea")
		personnel_training_button.position = action_rect.position + Vector2(-10 if training_state == &"available" else 10, -2)
		personnel_training_button.size = Vector2(action_rect.size.x - 20, 35)
		personnel_training_button.disabled = training_state != &"available"
		match training_state:
			&"available":
				personnel_training_button.text = "НАЧАТЬ КУРС «%s» • %d ДЕНЬ" % [training_definition["name"].to_upper(), int(training_definition["duration_days"])]
			&"missing_supply":
				personnel_training_button.text = "НУЖЕН КОМПЛЕКТ ИЗ ЛАВКИ"
			&"assigned":
				personnel_training_button.text = "СНАЧАЛА СНЯТЬ С ЗАЯВКИ"
			&"returning":
				personnel_training_button.text = "СОТРУДНИК ЕЩЁ ВОЗВРАЩАЕТСЯ"
			&"no_slots":
				personnel_training_button.text = "НЕТ СВОБОДНОЙ ЯЧЕЙКИ"
			&"incompatible":
				personnel_training_button.text = "КУРС НЕ ПОДХОДИТ СОТРУДНИКУ"
			&"training":
				personnel_training_button.text = "ОБУЧЕНИЕ ИДЁТ ДО ДНЯ %d" % int(employee.get("training_end_day", game_state.day + 1))
			&"learned":
				personnel_training_button.text = "КУРС УЖЕ ПРОЙДЕН"
			_:
				personnel_training_button.text = "ОБУЧЕНИЕ НЕДОСТУПНО"
	if finish_day_button != null:
		finish_day_button.disabled = not game_state.can_finish_day()
		finish_day_button.tooltip_text = "Сначала завершите доступные заявки." if finish_day_button.disabled else "Перейти к следующему рабочему дню."


func _training_state_text(training_state: StringName, employee: Dictionary) -> String:
	match training_state:
		&"available":
			return "Совместим. Можно начать обучение."
		&"missing_supply":
			return "Совместим, но учебный комплект ещё не куплен."
		&"assigned":
			return "Сначала освободите сотрудника от заявки."
		&"returning":
			return "Обучение начнётся после возвращения сотрудника."
		&"no_slots":
			return "Все ячейки изучаемых способностей заняты."
		&"incompatible":
			return "Несовместим с магическим обучением этого типа."
		&"training":
			return "Обучается до начала дня %d." % int(employee.get("training_end_day", game_state.day + 1))
		&"learned":
			return "Курс пройден, действие доступно на объектах."
		&"not_hired":
			return "Сначала сотрудника нужно нанять."
	return "Курс пока недоступен."


func _employee_specialization_text(employee: Dictionary) -> String:
	var specialization_names := PackedStringArray()
	var abilities: PackedStringArray = employee["abilities"]
	for ability_id_string: String in abilities:
		specialization_names.append(game_state.get_ability_name(StringName(ability_id_string)))
	if specialization_names.is_empty():
		return "Нет изученных специализаций"
	return " • ".join(specialization_names)


func _rebuild_jobs() -> void:
	_clear(job_list)
	for job_id: StringName in game_state.jobs:
		if not game_state.is_job_available(job_id):
			continue
		var job: Dictionary = game_state.jobs[job_id]
		var assigned: PackedStringArray = job["assigned"]
		var crew_text := "Бригада не назначена" if assigned.is_empty() else "Назначено: %d" % assigned.size()
		var deadline_text := "ПРОСРОЧЕНО" if bool(job.get("overdue", false)) else "осталось %d мин." % int(job["time_left"])
		var button := _button(
			"%s\n%s\n%s  •  %s\n%s" % [job["title"], job["address"], job["urgency"], deadline_text, crew_text],
			Vector2.ZERO,
			Vector2(379, 150)
		)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 16)
		button.add_theme_stylebox_override("normal", _style(COLOR_SELECTED if job_id == selected_job_id else COLOR_CARD, COLOR_GOLD if job_id == selected_job_id else COLOR_BRASS, 3 if job_id == selected_job_id else 2, 9))
		button.pressed.connect(_select_job.bind(job_id))
		job_list.add_child(button)


func _rebuild_employees() -> void:
	_clear(employee_list)
	for employee_id: StringName in game_state.EMPLOYEE_ORDER:
		var employee: Dictionary = game_state.employees[employee_id]
		if not employee["available"]:
			continue
		var assigned_job: StringName = game_state.get_employee_job(employee_id)
		var pending_selected: bool = pending_dispatch_employee_ids.has(String(employee_id))
		var selected: bool = assigned_job == selected_job_id or pending_selected
		var dispatched: bool = not assigned_job.is_empty() and game_state.is_job_dispatched(assigned_job)
		var on_site: bool = dispatched and game_state.can_employee_work_on_job(employee_id, assigned_job)
		var in_transit: bool = dispatched and not on_site
		var returning: bool = game_state.is_employee_returning(employee_id)
		var card := _button("", Vector2.ZERO, Vector2(390, 225))
		var is_training: bool = game_state.is_employee_training(employee_id)
		card.disabled = is_training or dispatched or returning
		card.tooltip_text = employee["status"] if in_transit or returning else ("Сотрудник находится на объекте" if on_site else ("Сотрудник заканчивает обучение на следующий день" if is_training else "Нажмите, чтобы назначить сотрудника на выбранную заявку или снять назначение"))
		card.add_theme_stylebox_override("normal", _style(COLOR_SELECTED if selected else COLOR_CARD, COLOR_GOLD if selected else COLOR_BRASS, 3 if selected else 2, 9))
		card.pressed.connect(_toggle_employee.bind(employee_id))
		employee_list.add_child(card)

		var portrait_frame := Panel.new()
		portrait_frame.position = Vector2(8, 8)
		portrait_frame.size = Vector2(160, 209)
		portrait_frame.clip_contents = true
		portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait_frame.add_theme_stylebox_override("panel", _style(Color(0.035, 0.03, 0.028, 1), COLOR_BRASS, 1, 6))
		card.add_child(portrait_frame)

		var portrait := TextureRect.new()
		portrait.position = Vector2(2, 2)
		portrait.size = Vector2(156, 207)
		portrait.texture = _cropped_portrait(employee)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait_frame.add_child(portrait)

		var name_label := _label(employee["name"], 19, COLOR_GOLD)
		name_label.position = Vector2(180, 20)
		name_label.size = Vector2(198, 30)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(name_label)

		var role_label := _label(employee["role"], 14, COLOR_PARCHMENT)
		role_label.position = Vector2(180, 55)
		role_label.size = Vector2(198, 26)
		role_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(role_label)

		var method_label := _label(_employee_specialization_text(employee), 13, COLOR_MUTED)
		method_label.position = Vector2(180, 92)
		method_label.size = Vector2(198, 58)
		method_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		method_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(method_label)

		var status_color := COLOR_MUTED if in_transit or returning else (COLOR_GOLD if selected else COLOR_MUTED)
		var status_text: String = _employee_card_status(employee, pending_selected, selected, on_site, in_transit, returning)
		var status_label := _label(status_text, 12, status_color)
		status_label.position = Vector2(180, 168)
		status_label.size = Vector2(198, 44)
		status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(status_label)


func _employee_card_status(employee: Dictionary, pending_selected: bool, selected: bool, on_site: bool, in_transit: bool, returning: bool) -> String:
	if pending_selected:
		return "Выбран для отправки"
	if returning:
		return str(employee["status"]).replace(" • прибудет в ", "\nПрибудет в ")
	if in_transit:
		return str(employee["status"])
	if selected and on_site:
		return "✓ На объекте"
	if selected:
		return "✓ В этой бригаде"
	return str(employee["status"])


func _refresh_details() -> void:
	if selected_job_id.is_empty() or not game_state.is_job_available(selected_job_id):
		detail_title.text = "Все доступные заявки выполнены"
		detail_body.text = "Новые вызовы появятся на следующем этапе игрового цикла."
		assignment_label.text = ""
		warning_label.text = ""
		depart_button.disabled = true
		recall_button.visible = false
		cancel_dispatch_button.visible = false
		return
	var job: Dictionary = game_state.jobs[selected_job_id]
	var assigned: PackedStringArray = job["assigned"]
	detail_title.text = job["title"]
	detail_body.text = "%s\nЖилец: %s\nОпасность: %s\n%s" % [job["address"], job["resident"], job["danger"], job["description"]]

	if assigned.is_empty():
		assignment_label.text = "Бригада: не назначена"
	else:
		var names := PackedStringArray()
		for employee_id: String in assigned:
			names.append(game_state.employees[StringName(employee_id)]["name"])
		assignment_label.text = "Бригада:\n%s" % ", ".join(names)

	warning_label.text = ""
	var dispatched: bool = game_state.is_job_dispatched(selected_job_id)
	var confirming_extra_employees: bool = dispatched and not pending_dispatch_employee_ids.is_empty()
	var can_cancel_trip: bool = dispatched and pending_dispatch_employee_ids.is_empty() and game_state.clock_paused and game_state.has_employees_in_transit(selected_job_id)
	depart_button.text = "ОТПРАВИТЬ ВЫБРАННЫХ" if confirming_extra_employees else ("ОТКРЫТЬ ОБЪЕКТ" if dispatched else "ОТПРАВИТЬ БРИГАДУ")
	depart_button.position = Vector2(22, 384)
	depart_button.custom_minimum_size = Vector2(371, 52) if confirming_extra_employees or not dispatched else Vector2(177, 52)
	depart_button.size = depart_button.custom_minimum_size
	depart_button.add_theme_font_size_override("font_size", 15 if confirming_extra_employees or dispatched else 17)
	depart_button.disabled = assigned.is_empty() and not confirming_extra_employees
	recall_button.visible = dispatched and not confirming_extra_employees and not can_cancel_trip
	recall_button.disabled = not dispatched
	cancel_dispatch_button.visible = can_cancel_trip


func _crew_has_ability(assigned: PackedStringArray, ability_id: StringName) -> bool:
	for employee_id: String in assigned:
		var employee: Dictionary = game_state.employees.get(StringName(employee_id), {})
		if (employee.get("abilities", PackedStringArray()) as PackedStringArray).has(String(ability_id)):
			return true
	return false


func _select_job(job_id: StringName) -> void:
	set_meta("tutorial_job_clicked", true)
	pending_dispatch_employee_ids.clear()
	selected_job_id = job_id
	_refresh()


func _toggle_employee(employee_id: StringName) -> void:
	if selected_job_id.is_empty() or not game_state.is_job_available(selected_job_id):
		return
	if game_state.is_job_dispatched(selected_job_id):
		if game_state.get_employee_job(employee_id).is_empty():
			var employee_key := String(employee_id)
			if pending_dispatch_employee_ids.has(employee_key):
				pending_dispatch_employee_ids.remove_at(pending_dispatch_employee_ids.find(employee_key))
			else:
				pending_dispatch_employee_ids.append(employee_key)
			_refresh()
		return
	game_state.assign_employee(employee_id, selected_job_id)


func _cancel_pending_dispatch() -> void:
	if selected_job_id.is_empty():
		return
	game_state.cancel_job_arrivals(selected_job_id)


func _depart() -> void:
	if selected_job_id.is_empty() or not game_state.is_job_available(selected_job_id):
		return
	var repair_scene: String = game_state.get_job_repair_scene(selected_job_id)
	if repair_scene.is_empty():
		return
	if game_state.is_job_dispatched(selected_job_id) and not pending_dispatch_employee_ids.is_empty():
		var employee_ids := pending_dispatch_employee_ids.duplicate()
		pending_dispatch_employee_ids.clear()
		for employee_id: String in employee_ids:
			game_state.assign_employee(StringName(employee_id), selected_job_id)
		return
	if not game_state.is_job_dispatched(selected_job_id):
		var assigned: PackedStringArray = game_state.jobs[selected_job_id]["assigned"]
		if selected_job_id == &"escaped_ghost" and not risk_dispatch_confirmed and not _crew_has_ability(assigned, &"antimagic"):
			dispatch_warning_body.text = "Изгнать призрака такой бригадой не получится. Купленная служебная ловушка позволит поймать привидение. Всё равно отправить бригаду?" if game_state.has_supply_item(&"ghost_trap") else "Изгнать призрака такой бригадой не получится. Может потребоваться служебная ловушка — её можно купить в лавке снаряжения. Всё равно отправить бригаду?"
			dispatch_warning_dialog.visible = true
			dispatch_warning_dialog.move_to_front()
			return
		if game_state.begin_job(selected_job_id):
			game_state.leave_active_job()
			warning_label.text = ""
		return
	if game_state.has_employee_on_site(selected_job_id):
		if game_state.begin_job(selected_job_id):
			get_tree().change_scene_to_file(repair_scene)
		return
	game_state.set_clock_paused(true)
	arrival_dialog.visible = true
	arrival_dialog.move_to_front()


func _confirm_risky_dispatch() -> void:
	dispatch_warning_dialog.visible = false
	risk_dispatch_confirmed = true
	_depart()
	risk_dispatch_confirmed = false


func _start_auto_wait() -> void:
	if auto_wait_running or selected_job_id.is_empty():
		return
	var job_id := selected_job_id
	var arrival_time: int = game_state.get_next_arrival_time(job_id)
	if arrival_time < 0:
		return
	auto_wait_running = true
	arrival_dialog.visible = false
	game_state.set_clock_paused(true)
	while game_state.time_minutes < arrival_time:
		game_state.advance_time(1)
		await get_tree().create_timer(0.055).timeout
	auto_wait_running = false
	game_state.set_clock_paused(true)
	var repair_scene: String = game_state.get_job_repair_scene(job_id)
	if game_state.has_employee_on_site(job_id) and game_state.begin_job(job_id) and not repair_scene.is_empty():
		get_tree().change_scene_to_file(repair_scene)


func _recall_crew() -> void:
	if selected_job_id.is_empty():
		return
	game_state.recall_job(selected_job_id)


func _panel(panel_position: Vector2, panel_size: Vector2, radius: int) -> Panel:
	var panel := Panel.new()
	panel.position = panel_position
	panel.size = panel_size
	panel.add_theme_stylebox_override("panel", _style(COLOR_PANEL, COLOR_BRASS, 2, radius))
	return panel


func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label


func _button(text_value: String, button_position: Vector2, button_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = button_position
	button.custom_minimum_size = button_size
	button.size = button_size
	_style_button(button)
	return button


func _style_button(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", COLOR_PARCHMENT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.45, 0.40, 0.34))
	button.add_theme_stylebox_override("normal", _style(COLOR_CARD, COLOR_BRASS, 2, 8))
	button.add_theme_stylebox_override("hover", _style(COLOR_CARD_HOVER, COLOR_GOLD, 2, 8))
	button.add_theme_stylebox_override("pressed", _style(COLOR_SELECTED, COLOR_GOLD, 3, 8))
	button.add_theme_stylebox_override("focus", _style(COLOR_CARD_HOVER, COLOR_GOLD, 2, 8))
	button.add_theme_stylebox_override("disabled", _style(Color(0.07, 0.055, 0.045, 0.90), Color(0.28, 0.24, 0.19), 1, 8))


func _style(background: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _cropped_portrait(employee: Dictionary) -> AtlasTexture:
	var portrait := AtlasTexture.new()
	portrait.atlas = load(str(employee["portrait"]))
	var configured_region: Variant = employee.get("portrait_region", Rect2(177, 0, 900, 932))
	portrait.region = configured_region if configured_region is Rect2 else Rect2(177, 0, 900, 932)
	portrait.filter_clip = true
	return portrait


func _add_stat_icon(parent: Control, icon_kind: int, icon_position: Vector2) -> void:
	var icon: Control = HUD_ICON_SCRIPT.new()
	icon.kind = icon_kind
	icon.position = icon_position
	icon.size = Vector2(28, 28)
	parent.add_child(icon)


func _clear(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()
