class_name TutorialOverlay
extends CanvasLayer

const COLOR_PANEL := Color(0.055, 0.035, 0.022, 0.985)
const COLOR_BRASS := Color(0.76, 0.54, 0.27)
const COLOR_GOLD := Color(0.96, 0.78, 0.46)
const COLOR_TEXT := Color(0.94, 0.87, 0.74)

var context: StringName = &"office"
var host: Node
var panel: Panel
var message_label: Label
var continue_button: Button
var skip_button: Button
var spotlight: ColorRect
var confirm_layer: Control
var rendered_step: String = ""
var initial_action_count: int = -1


func configure(new_context: StringName, new_host: Node) -> void:
	context = new_context
	host = new_host


func _ready() -> void:
	layer = 90
	_build_interface()
	set_process(true)


func _process(_delta: float) -> void:
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null or not game_state.is_tutorial_active():
		visible = false
		return
	visible = true
	if _repair_dialogue_is_open():
		panel.visible = false
		spotlight.visible = false
		rendered_step = ""
		return
	_reconcile_step(game_state)
	var step := str(game_state.tutorial_state.get("step", ""))
	if step != rendered_step:
		rendered_step = step
		_render_step(step)
	_update_highlight(step)


func _repair_dialogue_is_open() -> bool:
	if context != &"repair" or host == null or host.repair_hud == null:
		return false
	var dialogue_panel: Control = host.repair_hud.employee_reaction_panel
	return dialogue_panel != null and dialogue_panel.visible


func _reconcile_step(game_state: Node) -> void:
	var step := str(game_state.tutorial_state.get("step", ""))
	var tutorial_job_id: StringName = game_state.get_tutorial_job_id()
	if context == &"office":
		# После первого дня начинается отдельная фаза обзора офиса. Не сверяем её
		# с условиями заявки, иначе шаги поочерёдно возвращают друг друга каждый кадр.
		if game_state.day > 1:
			if step not in ["personnel_overview", "supply_overview", "storage_overview", "final"]:
				host._show_hub()
				game_state.set_tutorial_step(&"personnel_overview")
			return
		if not game_state.pending_job_report.is_empty() and step not in ["report", "claim"]:
			game_state.set_tutorial_step(&"report")
		elif game_state.is_tutorial_job_completed() and game_state.pending_job_report.is_empty() and step not in ["return_board", "finish_day", "final"]:
			game_state.set_tutorial_step(&"return_board")
		elif game_state.is_job_dispatched(tutorial_job_id) and step in ["office_welcome", "open_board", "open_first_job", "job_details", "assign_employee", "employee_scroll", "crew_choice", "dispatch"]:
			game_state.set_tutorial_step(&"travel")
		elif game_state.jobs.has(tutorial_job_id) and not game_state.jobs[tutorial_job_id]["assigned"].is_empty() and step in ["office_welcome", "open_board", "open_first_job", "job_details", "assign_employee"]:
			game_state.set_tutorial_step(&"employee_scroll")
		elif step == "open_board" and host.dashboard_layer.visible and not host.hub_layer.visible:
			game_state.set_tutorial_step(&"open_first_job")
		elif step == "open_first_job" and bool(host.get_meta("tutorial_job_clicked", false)):
			game_state.set_tutorial_step(&"job_details")
		elif step == "assign_employee" and game_state.jobs.has(tutorial_job_id) and not game_state.jobs[tutorial_job_id]["assigned"].is_empty():
			game_state.set_tutorial_step(&"employee_scroll")
		elif step == "dispatch" and game_state.is_job_dispatched(tutorial_job_id):
			game_state.set_tutorial_step(&"travel")
		elif step == "open_object" and game_state.has_employee_on_site(tutorial_job_id):
			# Остаёмся на шаге до нажатия «ОТКРЫТЬ ОБЪЕКТ» и смены сцены.
			pass
		elif step == "complete_job" and not game_state.pending_job_report.is_empty():
			game_state.set_tutorial_step(&"report")
		elif step == "report" and host.job_report_layer != null and not host.job_report_layer.visible:
			if host.claim_layer != null and host.claim_layer.visible:
				game_state.set_tutorial_step(&"claim")
			elif game_state.pending_job_report.is_empty():
				game_state.set_tutorial_step(&"return_board")
		elif step == "claim" and host.claim_layer != null and not host.claim_layer.visible:
			game_state.set_tutorial_step(&"return_board")
		elif step == "return_board":
			if not host.dashboard_layer.visible or host.hub_layer.visible:
				host._open_jobs()
			game_state.set_tutorial_step(&"finish_day")
	elif context == &"repair":
		if step in ["travel", "open_object"]:
			game_state.set_tutorial_step(&"employee_auto")
		elif step == "select_faucet" and host.tool_bar.visible:
			initial_action_count = host.simulation.action_log.size()
			game_state.set_tutorial_step(&"select_action")
		elif step == "select_action" and host.simulation.action_log.size() > maxi(initial_action_count, 0):
			game_state.set_tutorial_step(&"consequences")
		elif step in ["resolve_job", "wait_resolution"] and host.simulation.is_resolved():
			game_state.set_tutorial_step(&"complete_job")


func _render_step(step: String) -> void:
	var data := _step_data(step)
	message_label.text = tr(str(data.get("text", "")))
	continue_button.visible = bool(data.get("continue", false))
	continue_button.text = tr(str(data.get("button", "ПОНЯТНО")))
	panel.visible = not message_label.text.is_empty()
	_layout_panel(step)


func _step_data(step: String) -> Dictionary:
	match step:
		"office_welcome": return {"text": "Добро пожаловать в Магическую аварийную службу. Здесь принимают вызовы, собирают бригады и разбираются с последствиями — желательно в таком порядке.", "continue": true}
		"open_board": return {"text": "Новые вызовы ждут на «ДОСКЕ ЗАЯВОК». Откройте её и посмотрим, кому сегодня особенно не повезло."}
		"open_first_job":
			var game_state := get_node_or_null("/root/GameState")
			var title := "первая заявка"
			if game_state != null and game_state.jobs.has(game_state.get_tutorial_job_id()):
				title = "«%s»" % tr(str(game_state.jobs[game_state.get_tutorial_job_id()].get("title", "Первая заявка")))
			return {"text": "Первый вызов — %s. Нажмите на карточку, чтобы прочитать адрес, описание и опасности." % title}
		"job_details": return {"text": "Справа собраны сведения о вызове: адрес, жилец, опасности и описание происшествия. Перед выездом стоит прочитать всё, что сообщил заказчик.", "continue": true}
		"assign_employee": return {"text": "Ниже находятся сотрудники службы. Нажмите на карточку любого свободного сотрудника, чтобы включить его в бригаду."}
		"employee_scroll": return {"text": "Сейчас для вызовов доступны три сотрудника — все они помещаются на экране. Когда вы наймёте новых специалистов, список можно будет прокручивать колёсиком мыши или горизонтальным ползунком.", "continue": true}
		"crew_choice": return {"text": "В бригаду можно взять любых доступных сотрудников — одного, нескольких или всех. Изучите их специализации и решите сами, кто пригодится на этом вызове.", "continue": true}
		"dispatch": return {"text": "Состав готов. Нажмите «ОТПРАВИТЬ БРИГАДУ», чтобы сотрудники выехали по адресу."}
		"travel": return {"text": "Бригада уже в пути. Дорога занимает игровое время; часы можно поставить на паузу или ускорить.", "continue": true}
		"open_object": return {"text": "Дождитесь прибытия сотрудников, затем нажмите «ОТКРЫТЬ ОБЪЕКТ». Если бригада ещё в пути, игра предложит ускорить ожидание."}
		"employee_auto": return {"text": "По прибытии первый сотрудник в бригаде выбирается автоматически. Нажмите другую карточку, если хотите поручить действие кому-то ещё.", "continue": true}
		"risk_notice": return {"text": "Осторожная работа сохраняет оплату и репутацию службы. Если пострадает имущество, жилец может потребовать компенсацию.", "continue": true}
		"select_faucet": return {"text": "Аварийный кран — интерактивный объект. Нажмите прямо на него, чтобы увидеть действия выбранного сотрудника."}
		"select_action": return {"text": "Здесь показаны действия выбранного сотрудника, доступные для крана. Выберите любое и посмотрите, к чему оно приведёт."}
		"consequences": return {"text": "Каждое воздействие меняет состояние объекта и может повлиять на помещение, оплату и репутацию. Наблюдайте за результатом и действуйте дальше по своему усмотрению.", "continue": true}
		"resolve_job": return {"text": "Продолжайте работу так, как считаете нужным. Обучение не будет подсказывать сотрудника или способ устранения аварии.", "continue": true}
		"wait_resolution": return {}
		"complete_job":
			if context == &"repair" and host != null and StringName(str(host.simulation.world_object.get("visual_state", ""))) == &"melted":
				return {"text": "Поток лавы остановлен расплавленным металлом, но кран уничтожен. Нажмите «ЗАВЕРШИТЬ РАБОТУ», чтобы принять последствия."}
			return {"text": "Причина аварии устранена. Когда будете готовы принять последствия работы, нажмите «ЗАВЕРШИТЬ РАБОТУ»."}
		"report": return {"text": "В «АКТЕ ВЫПОЛНЕННЫХ РАБОТ» указаны бригада, оплата и итог заявки. Ущерб может уменьшить результат, вызвать претензию и повлиять на репутацию службы."}
		"claim": return {"text": "Жилец потребовал компенсацию за причинённый ущерб. Можно возместить указанную сумму или отказать — решение повлияет на казну, отчёт и репутацию."}
		"return_board": return {"text": "Вызов закрыт, и первый рабочий день можно завершить. Откройте «ДОСКУ ЗАЯВОК»."}
		"finish_day": return {"text": "Нажмите «ЗАВЕРШИТЬ ДЕНЬ». Утром город принесёт новые вызовы, а служба продолжит работу."}
		"personnel_overview": return {"text": "В разделе «СОТРУДНИКИ» можно нанимать новых специалистов и отправлять сотрудников на обучение.", "continue": true, "button": "ДАЛЕЕ"}
		"supply_overview": return {"text": "В «ЛАВКЕ СНАБЖЕНИЯ» продаются полевое снаряжение и учебные книги, открывающие новые курсы.", "continue": true, "button": "ДАЛЕЕ"}
		"storage_overview": return {"text": "На «СКЛАДЕ СНАРЯЖЕНИЯ» можно проверить, какое имущество доступно службе и где оно сейчас находится.", "continue": true}
		"final": return {"text": "Первый день позади. Дальше вы сами выбираете заявки, сотрудников и способы работы. Город запомнит каждое решение вашей службы.", "continue": true, "button": "НАЧАТЬ РАБОЧИЙ ДЕНЬ"}
	return {}


func _advance_information_step() -> void:
	var game_state := get_node("/root/GameState")
	match str(game_state.tutorial_state.get("step", "")):
		"office_welcome": game_state.set_tutorial_step(&"open_board")
		"job_details": game_state.set_tutorial_step(&"assign_employee")
		"employee_scroll": game_state.set_tutorial_step(&"crew_choice")
		"crew_choice": game_state.set_tutorial_step(&"dispatch")
		"travel": game_state.set_tutorial_step(&"open_object")
		"employee_auto": game_state.set_tutorial_step(&"risk_notice")
		"risk_notice": game_state.set_tutorial_step(&"select_faucet")
		"consequences": game_state.set_tutorial_step(&"resolve_job")
		"resolve_job": game_state.set_tutorial_step(&"wait_resolution")
		"personnel_overview": game_state.set_tutorial_step(&"supply_overview")
		"supply_overview": game_state.set_tutorial_step(&"storage_overview")
		"storage_overview": game_state.set_tutorial_step(&"final")
		"final": game_state.complete_tutorial()


func _update_highlight(step: String) -> void:
	var target: Control = null
	if context == &"office" and host != null:
		match step:
			"open_board", "return_board": target = host.find_child("JobBoard", true, false) as Control
			"open_first_job":
				if host.job_list != null and host.job_list.get_child_count() > 0: target = host.job_list.get_child(0) as Control
			"job_details": target = host.detail_title.get_parent() as Control if host.detail_title != null else null
			"assign_employee", "employee_scroll", "crew_choice": target = host.employee_list.get_parent() as Control if host.employee_list != null else null
			"dispatch": target = host.depart_button
			"open_object":
				if host.arrival_dialog != null and host.arrival_dialog.visible and host.arrival_dialog.get_child_count() > 1:
					target = host.arrival_dialog.get_child(1) as Control
				else:
					target = host.depart_button
			"travel": target = host.clock_controls
			"report":
				if host.job_report_layer != null and host.job_report_layer.get_child_count() > 1: target = host.job_report_layer.get_child(1) as Control
			"claim":
				if host.claim_layer != null and host.claim_layer.get_child_count() > 1: target = host.claim_layer.get_child(1) as Control
			"finish_day": target = host.finish_day_button
			"personnel_overview": target = host.find_child("EmployeesBoard", true, false) as Control
			"supply_overview": target = host.find_child("SupplyShop", true, false) as Control
			"storage_overview": target = host.find_child("EquipmentStorage", true, false) as Control
	elif context == &"repair" and host != null:
		match step:
			"employee_auto": target = host.repair_hud.employee_panel
			"select_faucet": target = host.lava_faucet.get_node_or_null("HitArea") as Control
			"select_action": target = host.tool_bar
			"complete_job": target = host.repair_hud.complete_button
	if target == null or not is_instance_valid(target) or not target.is_visible_in_tree():
		spotlight.visible = false
		return
	var rect := target.get_global_rect()
	_update_spotlight(rect.grow(10.0))
	_place_panel_away_from(rect)


func _update_spotlight(rect: Rect2) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		spotlight.visible = false
		return
	var material := spotlight.material as ShaderMaterial
	material.set_shader_parameter("hole_center", rect.get_center() / viewport_size)
	material.set_shader_parameter("hole_half_size", rect.size * 0.5 / viewport_size)
	spotlight.visible = true


func _layout_panel(step: String) -> void:
	panel.size = Vector2(720, 150)
	panel.position = Vector2(440, 310)
	message_label.position = Vector2(28, 12)
	message_label.size = Vector2(664, 78)
	continue_button.position = Vector2(478, 99)
	continue_button.size = Vector2(210, 40)
	skip_button.position = Vector2(22, 104)
	skip_button.size = Vector2(190, 32)
	if step in ["employee_auto", "risk_notice", "select_faucet", "select_action", "complete_job"]:
		panel.position.y = 118
	elif step in ["report", "claim"]:
		panel.position.y = 10


func _place_panel_away_from(target_rect: Rect2) -> void:
	if not panel.visible:
		return
	if context == &"office" and host != null and host.arrival_dialog != null and host.arrival_dialog.visible:
		panel.position.y = 92.0
		return
	var step := str(get_node("/root/GameState").tutorial_state.get("step", ""))
	if step in ["report", "claim"]:
		panel.position.y = 10.0
		return
	if target_rect.get_center().y < 360.0:
		panel.position.y = 430.0
	elif target_rect.get_center().y > 610.0:
		panel.position.y = 120.0


func _build_interface() -> void:
	spotlight = ColorRect.new()
	spotlight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	spotlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var spotlight_shader := Shader.new()
	spotlight_shader.code = "shader_type canvas_item; uniform vec2 hole_center = vec2(0.5); uniform vec2 hole_half_size = vec2(0.1); uniform float feather = 0.012; uniform float corner = 0.018; void fragment(){ vec2 q = abs(UV - hole_center) - hole_half_size + vec2(corner); float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - corner; float a = 0.64 * smoothstep(-feather, feather, d); COLOR = vec4(0.0, 0.0, 0.0, a); }"
	var spotlight_material := ShaderMaterial.new()
	spotlight_material.shader = spotlight_shader
	spotlight.material = spotlight_material
	add_child(spotlight)

	panel = Panel.new()
	panel.position = Vector2(440, 310)
	panel.size = Vector2(720, 150)
	panel.add_theme_stylebox_override("panel", _style(COLOR_PANEL, COLOR_BRASS, 3, 12))
	add_child(panel)

	message_label = Label.new()
	message_label.position = Vector2(28, 12)
	message_label.size = Vector2(664, 78)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 18)
	message_label.add_theme_color_override("font_color", COLOR_TEXT)
	panel.add_child(message_label)

	continue_button = _button("ПОНЯТНО", Vector2(478, 99), Vector2(210, 40))
	continue_button.pressed.connect(_advance_information_step)
	panel.add_child(continue_button)

	skip_button = Button.new()
	skip_button.text = "Пропустить обучение"
	skip_button.position = Vector2(22, 104)
	skip_button.size = Vector2(190, 32)
	skip_button.flat = true
	skip_button.add_theme_font_size_override("font_size", 12)
	skip_button.add_theme_color_override("font_color", Color(0.58, 0.53, 0.46))
	skip_button.add_theme_color_override("font_hover_color", COLOR_TEXT)
	skip_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	skip_button.pressed.connect(func() -> void: confirm_layer.visible = true)
	panel.add_child(skip_button)

	confirm_layer = preload("res://scenes/ui/SkipTutorialDialog.tscn").instantiate()
	confirm_layer.visible = false
	add_child(confirm_layer)
	var confirm: Button = confirm_layer.get_node("%Confirm")
	confirm.pressed.connect(func() -> void: get_node("/root/GameState").skip_tutorial())
	var cancel: Button = confirm_layer.get_node("%Cancel")
	cancel.pressed.connect(func() -> void: confirm_layer.visible = false)


func _button(text_value: String, button_position: Vector2, button_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = button_position
	button.size = button_size
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_stylebox_override("normal", _style(Color(0.13, 0.09, 0.055, 0.98), COLOR_BRASS, 2, 8))
	button.add_theme_stylebox_override("hover", _style(Color(0.21, 0.14, 0.075, 1.0), COLOR_GOLD, 2, 8))
	return button


func _style(background: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0, 0, 0, 0.72)
	style.shadow_size = 10
	return style
