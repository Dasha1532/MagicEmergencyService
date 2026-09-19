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

var selected_job_id: StringName
var job_list: VBoxContainer
var employee_list: HBoxContainer
var money_label: Label
var day_label: Label
var time_label: Label
var detail_title: Label
var detail_body: Label
var assignment_label: Label
var warning_label: Label
var depart_button: Button
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
var personnel_cards: Dictionary = {}
var selected_employee_id: StringName = &"liliya"
var supply_layer: Control
var supply_money_label: Label
var supply_catalog_status: Label
var supply_purchase_button: Button
var section_dialog: Panel
var section_title: Label
var section_body: Label
var job_report_layer: Control
var job_report_title: Label
var job_report_body: Label
@onready var game_state: Node = get_node("/root/GameState")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$HotspotEditorPreview.visible = false
	$PersonnelEditorPreview.visible = false
	$ObjectHotspots.visible = true
	$BookHotspots.visible = true
	selected_job_id = game_state.selected_job_id
	_build_interface()
	game_state.state_changed.connect(_refresh)
	_refresh()


func _build_interface() -> void:
	dashboard_layer = Control.new()
	dashboard_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dashboard_layer)
	_build_top_bar()
	_build_jobs_panel()
	_build_detail_panel()
	_build_employee_panel()
	_build_dashboard_return()
	_build_office_hub()
	_build_job_report_dialog()
	_build_personnel_screen()
	_build_supply_shop()


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

	time_label = _label(game_state.format_time(), 20, COLOR_PARCHMENT)
	time_label.position = Vector2(1105, 19)
	time_label.size = Vector2(78, 36)
	panel.add_child(time_label)

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

	job_list = VBoxContainer.new()
	job_list.position = Vector2(18, 70)
	job_list.size = Vector2(379, 360)
	job_list.add_theme_constant_override("separation", 12)
	panel.add_child(job_list)


func _build_detail_panel() -> void:
	var panel := _panel(Vector2(1163, 112), Vector2(415, 455), 12)
	dashboard_layer.add_child(panel)

	detail_title = _label("", 24, COLOR_GOLD)
	detail_title.position = Vector2(22, 18)
	detail_title.size = Vector2(371, 62)
	detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(detail_title)

	detail_body = _label("", 17, COLOR_PARCHMENT)
	detail_body.position = Vector2(22, 88)
	detail_body.size = Vector2(371, 180)
	detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(detail_body)

	assignment_label = _label("", 16, COLOR_GOLD)
	assignment_label.position = Vector2(22, 274)
	assignment_label.size = Vector2(371, 58)
	assignment_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(assignment_label)

	warning_label = _label("", 14, Color(0.96, 0.62, 0.35))
	warning_label.position = Vector2(22, 332)
	warning_label.size = Vector2(371, 44)
	warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(warning_label)

	depart_button = _button("ОТПРАВИТЬ БРИГАДУ", Vector2(22, 384), Vector2(371, 52))
	depart_button.pressed.connect(_depart)
	panel.add_child(depart_button)


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

	_connect_editable_hotspot($ObjectHotspots/JobBoard, "ДОСКА ЗАЯВОК", "Что опять случилось?", _open_jobs)
	_connect_editable_hotspot($ObjectHotspots/EmployeesBoard, "СОТРУДНИКИ", "Кто сегодня работает?", _open_personnel)
	_connect_editable_hotspot($ObjectHotspots/EquipmentStorage, "СКЛАД СНАРЯЖЕНИЯ", "Чем будем чинить?", _open_section.bind("СКЛАД СНАРЯЖЕНИЯ", "Чем будем чинить?", "Здесь будет храниться обычное и магическое оборудование службы."))
	_connect_editable_hotspot($ObjectHotspots/CityMap, "КАРТА ГОРОДА", "Где опять прорвало?", _open_section.bind("КАРТА ГОРОДА", "Где опять прорвало?", "Здесь появятся районы города, адреса заявок и перемещение между объектами."))
	_connect_editable_hotspot($BookHotspots/AccountingBook, "КНИГА УЧЁТА", "Куда делись деньги?", _open_section.bind("КНИГА УЧЁТА", "Куда делись деньги?", "Здесь будут показаны доходы, расходы, зарплаты и компенсации."))
	_connect_editable_hotspot($BookHotspots/ReviewsBook, "КНИГА ОТЗЫВОВ", "Благодарности, жалобы и угрозы.", _open_section.bind("КНИГА ОТЗЫВОВ", "Благодарности, жалобы и угрозы.", "Здесь появятся оценки жильцов, отзывы и изменение репутации службы."))
	_connect_editable_hotspot($BookHotspots/IncidentArchive, "АРХИВ ПРОИСШЕСТВИЙ", "Так больше не делать.", _open_section.bind("АРХИВ ПРОИСШЕСТВИЙ", "Так больше не делать.", "Здесь будет сохраняться история решений, последствий и необычных аварий."))
	_connect_editable_hotspot($ObjectHotspots/SupplyShop, "ЛАВКА СНАБЖЕНИЯ", "Очень нужные покупки", _open_supply_shop)

	_build_office_menu_button()

	var hint := _label("Наведите курсор. Кот занят важным, его не будите.", 19, COLOR_PARCHMENT)
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
	personnel_hire_button = _button("", hire_rect.position + Vector2(10, 8), hire_rect.size - Vector2(20, 16))
	personnel_hire_button.add_theme_font_size_override("font_size", 13)
	personnel_hire_button.pressed.connect(_personnel_action_pressed)
	personnel_layer.add_child(personnel_hire_button)

	_refresh_personnel()


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

	var item: Dictionary = game_state.SUPPLY_ITEMS[&"animation_kit"]
	var item_name: String = str(item["name"])
	var item_category: String = str(item["category"])
	var item_icon_path: String = str(item["icon"])
	var item_description: String = str(item["description"])
	var item_card := _button("", Vector2(18, 68), Vector2(394, 178))
	item_card.add_theme_stylebox_override("normal", _style(COLOR_SELECTED, COLOR_GOLD, 2, 9))
	catalog_panel.add_child(item_card)
	var catalog_icon := TextureRect.new()
	catalog_icon.position = Vector2(16, 22)
	catalog_icon.size = Vector2(118, 118)
	catalog_icon.texture = load(item_icon_path) as Texture2D
	catalog_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	catalog_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	catalog_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_card.add_child(catalog_icon)
	var catalog_name := _label(item_name, 17, COLOR_GOLD)
	catalog_name.position = Vector2(146, 22)
	catalog_name.size = Vector2(228, 72)
	catalog_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	catalog_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_card.add_child(catalog_name)
	supply_catalog_status = _label("", 15, COLOR_PARCHMENT)
	supply_catalog_status.position = Vector2(146, 112)
	supply_catalog_status.size = Vector2(228, 34)
	supply_catalog_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_card.add_child(supply_catalog_status)

	var catalog_hint := _label("Ассортимент городской службы пока невелик. Зато каждая покупка проходит через три журнала.", 15, COLOR_MUTED)
	catalog_hint.position = Vector2(28, 285)
	catalog_hint.size = Vector2(374, 110)
	catalog_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	catalog_panel.add_child(catalog_hint)
	if OS.is_debug_build():
		var debug_day_button := _button("ТЕСТ: СЛЕДУЮЩИЙ ДЕНЬ", Vector2(62, 558), Vector2(306, 46))
		debug_day_button.pressed.connect(_advance_debug_day)
		catalog_panel.add_child(debug_day_button)
		var debug_money_button := _button("ТЕСТ: +500 МОНЕТ", Vector2(62, 616), Vector2(306, 46))
		debug_money_button.pressed.connect(_grant_debug_money)
		catalog_panel.add_child(debug_money_button)

	var detail_panel := _panel(Vector2(610, 124), Vector2(830, 726), 12)
	supply_layer.add_child(detail_panel)
	var detail_heading := _label(item_name, 27, COLOR_GOLD)
	detail_heading.position = Vector2(258, 36)
	detail_heading.size = Vector2(530, 82)
	detail_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_panel.add_child(detail_heading)
	var category_label := _label(item_category, 17, COLOR_MUTED)
	category_label.position = Vector2(260, 120)
	category_label.size = Vector2(500, 28)
	detail_panel.add_child(category_label)
	var detail_icon := TextureRect.new()
	detail_icon.position = Vector2(38, 38)
	detail_icon.size = Vector2(180, 180)
	detail_icon.texture = load(item_icon_path) as Texture2D
	detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_panel.add_child(detail_icon)
	var description := _label(item_description, 19, COLOR_PARCHMENT)
	description.position = Vector2(42, 260)
	description.size = Vector2(746, 140)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_panel.add_child(description)
	var delivery_note := _label("После покупки комплект поступит в собственность службы. Запустить обучение можно будет из личного дела совместимого сотрудника.", 16, COLOR_MUTED)
	delivery_note.position = Vector2(42, 420)
	delivery_note.size = Vector2(746, 92)
	delivery_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_panel.add_child(delivery_note)
	supply_purchase_button = _button("", Vector2(236, 596), Vector2(360, 68))
	supply_purchase_button.pressed.connect(_buy_animation_kit)
	detail_panel.add_child(supply_purchase_button)

	_refresh_supply_shop()


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
	button.position = Vector2(-8, 650)
	button.size = Vector2(350, 350)
	button.texture_normal = menu_texture
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = "Меню (Esc)"
	button.pivot_offset = button.size * 0.5
	button.z_index = 30

	var image := menu_texture.get_image()
	if image != null:
		var click_mask := BitMap.new()
		click_mask.create_from_image_alpha(image, 0.12)
		button.texture_click_mask = click_mask

	button.mouse_entered.connect(func() -> void:
		var tween := create_tween()
		tween.tween_property(button, "scale", Vector2(1.035, 1.035), 0.14)
	)
	button.mouse_exited.connect(func() -> void:
		var tween := create_tween()
		tween.tween_property(button, "scale", Vector2.ONE, 0.14)
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


func _attach_hotspot_caption(owner: Control, owner_size: Vector2, title_text: String, subtitle_text: String) -> void:
	var caption := Panel.new()
	var caption_width := maxf(owner_size.x - 24, 320.0)
	caption.position = Vector2((owner_size.x - caption_width) * 0.5, owner_size.y - 78)
	caption.size = Vector2(caption_width, 66)
	caption.visible = false
	caption.z_index = 20
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_stylebox_override("panel", _style(Color(0.035, 0.025, 0.018, 0.94), COLOR_BRASS, 2, 7))
	owner.add_child(caption)

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

	owner.mouse_entered.connect(func() -> void: caption.visible = true)
	owner.mouse_exited.connect(func() -> void: caption.visible = false)


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


func _open_jobs() -> void:
	hub_layer.visible = false
	personnel_layer.visible = false
	supply_layer.visible = false
	dashboard_layer.visible = true
	_refresh()


func _open_personnel() -> void:
	hub_layer.visible = false
	dashboard_layer.visible = false
	supply_layer.visible = false
	personnel_layer.visible = true
	_refresh_personnel()


func _open_supply_shop() -> void:
	hub_layer.visible = false
	dashboard_layer.visible = false
	personnel_layer.visible = false
	supply_layer.visible = true
	_refresh_supply_shop()


func _show_hub() -> void:
	dashboard_layer.visible = false
	personnel_layer.visible = false
	supply_layer.visible = false
	hub_layer.visible = true
	section_dialog.visible = false


func _open_section(title_text: String, subtitle_text: String, description: String) -> void:
	section_title.text = title_text
	section_body.text = "%s\n\n%s\n\nРаздел подготовлен для следующего этапа разработки." % [subtitle_text, description]
	section_dialog.visible = true
	section_dialog.move_to_front()


func _refresh() -> void:
	game_state.selected_job_id = selected_job_id
	if game_state.completed_job_ids.has(String(selected_job_id)):
		for available_job_id: StringName in game_state.jobs:
			if not game_state.completed_job_ids.has(String(available_job_id)):
				selected_job_id = available_job_id
				game_state.selected_job_id = available_job_id
				break
	day_label.text = "День %d" % game_state.day
	time_label.text = game_state.format_time()
	money_label.text = "%d монет" % game_state.money
	_rebuild_jobs()
	_rebuild_employees()
	_refresh_details()
	if personnel_layer != null:
		_refresh_personnel()
	if supply_layer != null:
		_refresh_supply_shop()
	_refresh_job_report()


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
	if compensation > 0:
		finance_text += "\nКомпенсация жильцу: %d монет\nИзменение средств службы: %d монет" % [compensation, int(report.get("net_change", -compensation))]
	job_report_body.text = "%s\n\nЗаказчик: %s\nБригада: %s\n\n%s\n\n%s" % [report.get("title", "Заявка"), report.get("resident", ""), crew_text, finance_text, report.get("summary", "")]


func _dismiss_job_report() -> void:
	game_state.dismiss_pending_job_report()


func _select_personnel_employee(employee_id: StringName) -> void:
	selected_employee_id = employee_id
	_refresh_personnel()


func _personnel_action_pressed() -> void:
	var employee: Dictionary = game_state.employees[selected_employee_id]
	if not bool(employee["available"]):
		game_state.hire_employee(selected_employee_id)
	else:
		game_state.train_employee(selected_employee_id, &"animate")


func _buy_animation_kit() -> void:
	game_state.buy_supply_item(&"animation_kit")


func _grant_debug_money() -> void:
	game_state.grant_debug_money(500)


func _advance_debug_day() -> void:
	game_state.advance_day(1)


func _refresh_supply_shop() -> void:
	if supply_purchase_button == null:
		return
	var item: Dictionary = game_state.SUPPLY_ITEMS[&"animation_kit"]
	var price := int(item["price"])
	var owned: bool = game_state.has_supply_item(&"animation_kit")
	supply_money_label.text = "В казне: %d монет" % game_state.money
	if owned:
		supply_catalog_status.text = "ПРИОБРЕТЕНО"
		supply_catalog_status.add_theme_color_override("font_color", COLOR_GOLD)
		supply_purchase_button.text = "ПРИОБРЕТЕНО"
		supply_purchase_button.disabled = true
	elif game_state.money < price:
		supply_catalog_status.text = "%d МОНЕТ" % price
		supply_catalog_status.add_theme_color_override("font_color", COLOR_PARCHMENT)
		supply_purchase_button.text = "НЕ ХВАТАЕТ МОНЕТ • %d" % price
		supply_purchase_button.disabled = true
	else:
		supply_catalog_status.text = "%d МОНЕТ" % price
		supply_catalog_status.add_theme_color_override("font_color", COLOR_PARCHMENT)
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
	var specialization: String = str(employee["core_actions"])
	if abilities.has("animate"):
		specialization += " • Оживление"
	personnel_traits.text = "ОСОБЕННОСТИ\n%s\n\nСПЕЦИАЛИЗАЦИЯ\n%s" % [employee["traits"], specialization]
	var is_candidate: bool = not bool(employee["available"])
	var training_state: StringName = game_state.get_training_availability(selected_employee_id, &"animate")
	var show_training_button: bool = training_state in [&"available", &"missing_supply", &"assigned", &"no_slots"]
	personnel_status.visible = not is_candidate and not show_training_button
	personnel_hire_button.visible = is_candidate or show_training_button
	if is_candidate:
		var hire_cost := int(employee.get("hire_cost", 0))
		personnel_hire_button.disabled = game_state.money < hire_cost
		personnel_hire_button.text = "НАНЯТЬ • %d МОНЕТ" % hire_cost if not personnel_hire_button.disabled else "НУЖНО %d МОНЕТ" % hire_cost
	elif show_training_button:
		personnel_hire_button.disabled = training_state != &"available"
		match training_state:
			&"available":
				personnel_hire_button.text = "ОБУЧИТЬ «ОЖИВЛЕНИЮ» • 1 ДЕНЬ"
			&"missing_supply":
				personnel_hire_button.text = "НУЖЕН КОМПЛЕКТ ИЗ ЛАВКИ"
			&"assigned":
				personnel_hire_button.text = "СНАЧАЛА СНЯТЬ С ЗАЯВКИ"
			&"no_slots":
				personnel_hire_button.text = "НЕТ СВОБОДНОЙ ЯЧЕЙКИ"


func _rebuild_jobs() -> void:
	_clear(job_list)
	for job_id: StringName in game_state.jobs:
		if game_state.completed_job_ids.has(String(job_id)):
			continue
		var job: Dictionary = game_state.jobs[job_id]
		var assigned: PackedStringArray = job["assigned"]
		var crew_text := "Бригада не назначена" if assigned.is_empty() else "Назначено: %d" % assigned.size()
		var button := _button(
			"%s\n%s\n%s  •  осталось %d мин.\n%s" % [job["title"], job["address"], job["urgency"], job["time_left"], crew_text],
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
		var selected: bool = assigned_job == selected_job_id
		var card := _button("", Vector2.ZERO, Vector2(390, 225))
		var is_training: bool = game_state.is_employee_training(employee_id)
		card.disabled = is_training
		card.tooltip_text = "Сотрудник заканчивает обучение на следующий день" if is_training else "Нажмите, чтобы назначить сотрудника на выбранную заявку или снять назначение"
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
		portrait.texture = _cropped_portrait(employee["portrait"])
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

		var method_label := _label(employee["core_actions"], 13, COLOR_MUTED)
		method_label.position = Vector2(180, 92)
		method_label.size = Vector2(198, 58)
		method_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		method_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(method_label)

		var status_color := COLOR_GOLD if selected else COLOR_MUTED
		var status_label := _label("✓ В этой бригаде" if selected else employee["status"], 13, status_color)
		status_label.position = Vector2(180, 184)
		status_label.size = Vector2(198, 26)
		status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(status_label)


func _refresh_details() -> void:
	var job: Dictionary = game_state.jobs[selected_job_id]
	var assigned: PackedStringArray = job["assigned"]
	detail_title.text = job["title"]
	detail_body.text = "%s\nЖилец: %s\nОпасность: %s\n\n%s" % [job["address"], job["resident"], job["danger"], job["description"]]

	if assigned.is_empty():
		assignment_label.text = "Бригада: не назначена"
	else:
		var names := PackedStringArray()
		for employee_id: String in assigned:
			names.append(game_state.employees[StringName(employee_id)]["name"])
		assignment_label.text = "Бригада:\n%s" % ", ".join(names)

	warning_label.text = ""
	if game_state.get_job_repair_scene(selected_job_id).is_empty():
		warning_label.text = "Объект этой заявки ещё готовится. Выезд пока недоступен."
	elif not assigned.is_empty():
		for other_job_id: StringName in game_state.jobs:
			if other_job_id == selected_job_id:
				continue
			if game_state.completed_job_ids.has(String(other_job_id)):
				continue
			var other_assigned: PackedStringArray = game_state.jobs[other_job_id]["assigned"]
			if other_assigned.is_empty():
				warning_label.text = "Внимание: «%s» останется без бригады." % game_state.jobs[other_job_id]["title"]
				break

	depart_button.disabled = assigned.is_empty()


func _select_job(job_id: StringName) -> void:
	selected_job_id = job_id
	_refresh()


func _toggle_employee(employee_id: StringName) -> void:
	game_state.assign_employee(employee_id, selected_job_id)


func _depart() -> void:
	var repair_scene: String = game_state.get_job_repair_scene(selected_job_id)
	if repair_scene.is_empty():
		warning_label.text = "Для этой заявки ещё не подготовлена отдельная локация."
		return
	if game_state.begin_job(selected_job_id):
		get_tree().change_scene_to_file(repair_scene)


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
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", COLOR_PARCHMENT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.45, 0.40, 0.34))
	button.add_theme_stylebox_override("normal", _style(COLOR_CARD, COLOR_BRASS, 2, 8))
	button.add_theme_stylebox_override("hover", _style(COLOR_CARD_HOVER, COLOR_GOLD, 2, 8))
	button.add_theme_stylebox_override("pressed", _style(COLOR_SELECTED, COLOR_GOLD, 3, 8))
	button.add_theme_stylebox_override("focus", _style(COLOR_CARD_HOVER, COLOR_GOLD, 2, 8))
	button.add_theme_stylebox_override("disabled", _style(Color(0.07, 0.055, 0.045, 0.90), Color(0.28, 0.24, 0.19), 1, 8))
	return button


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


func _cropped_portrait(path: String) -> AtlasTexture:
	var portrait := AtlasTexture.new()
	portrait.atlas = load(path)
	portrait.region = Rect2(177, 0, 900, 932)
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
