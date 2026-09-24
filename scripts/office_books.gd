extends Control

signal back_requested

const COLOR_PANEL := Color(0.07, 0.045, 0.03, 0.95)
const COLOR_CARD := Color(0.13, 0.09, 0.055, 0.97)
const COLOR_CARD_HOVER := Color(0.21, 0.14, 0.075, 0.98)
const COLOR_SELECTED := Color(0.10, 0.16, 0.18, 0.98)
const COLOR_BRASS := Color(0.76, 0.54, 0.27)
const COLOR_GOLD := Color(0.96, 0.78, 0.46)
const COLOR_PARCHMENT := Color(0.92, 0.84, 0.69)
const COLOR_MUTED := Color(0.70, 0.63, 0.52)
@onready var game_state: Node = get_node("/root/GameState")
@onready var heading: Label = $Header/Heading
@onready var summary: Label = $Header/Summary
@onready var entry_list: VBoxContainer = $ListPanel/Scroll/Entries
@onready var detail_title: Label = $DetailPanel/Title
@onready var detail_body: Label = $DetailPanel/Scroll/Body
@onready var accounting_button: Button = $Header/Accounting
@onready var reviews_button: Button = $Header/Reviews
@onready var archive_button: Button = $Header/Archive
@onready var pay_claim_button: Button = $DetailPanel/PayClaim

var current_section: StringName = &"accounting"
var selected_claim_key: Dictionary = {}


func _ready() -> void:
	$BackButton.pressed.connect(func() -> void: back_requested.emit())
	accounting_button.pressed.connect(open_section.bind(&"accounting"))
	reviews_button.pressed.connect(open_section.bind(&"reviews"))
	archive_button.pressed.connect(open_section.bind(&"archive"))
	pay_claim_button.pressed.connect(_pay_selected_claim)
	if not game_state.state_changed.is_connected(refresh):
		game_state.state_changed.connect(refresh)
	_apply_styles()
	refresh()


func open_section(section: StringName) -> void:
	current_section = section if section in [&"accounting", &"reviews", &"archive"] else &"accounting"
	refresh()


func refresh() -> void:
	if not is_node_ready():
		return
	_update_tabs()
	_clear(entry_list)
	pay_claim_button.visible = false
	selected_claim_key = {}
	match current_section:
		&"reviews":
			_build_reviews()
		&"archive":
			_build_archive()
		_:
			_build_accounting()


func _build_accounting() -> void:
	heading.text = "КНИГА УЧЁТА"
	var income := 0
	var expenses := 0
	for event_value: Variant in game_state.financial_ledger:
		if event_value is Dictionary:
			var amount := int((event_value as Dictionary).get("amount", 0))
			if str((event_value as Dictionary).get("kind", "")) == "opening_balance":
				continue
			if amount >= 0:
				income += amount
			else:
				expenses += -amount
	summary.text = "Сейчас: %d монет • Доходы: %d • Расходы: %d" % [game_state.money, income, expenses]
	detail_title.text = "ДЕНЕЖНЫЕ ОПЕРАЦИИ"
	detail_body.text = "Выберите запись слева, чтобы увидеть подробности."
	if game_state.financial_ledger.is_empty():
		_add_empty_entry("Операций пока нет")
		return
	for index in range(game_state.financial_ledger.size() - 1, -1, -1):
		var event: Dictionary = game_state.financial_ledger[index]
		var amount := int(event.get("amount", 0))
		var sign_text := "+%d" % amount if amount >= 0 else str(amount)
		_add_entry("%s\n%s • %s монет" % [event.get("title", "Операция"), _event_date(event), sign_text], _show_financial_event.bind(event))


func _build_reviews() -> void:
	heading.text = "КНИГА ОТЗЫВОВ"
	var titles: PackedStringArray = game_state.get_reputation_titles(2)
	summary.text = "Репутация: %d • %s • Отзывов: %d" % [game_state.reputation, " • ".join(titles), game_state.job_reports.size()]
	detail_title.text = "ОТЗЫВЫ ЖИЛЬЦОВ"
	detail_body.text = "Здесь появятся оценки завершённых заявок."
	if game_state.job_reports.is_empty():
		_add_empty_entry("Завершённых заявок пока нет")
		return
	for index in range(game_state.job_reports.size() - 1, -1, -1):
		var report: Dictionary = game_state.job_reports[index]
		var rating := _report_rating(report)
		_add_entry("%s\n%s • %s" % [report.get("resident", "Жилец"), _stars(rating), report.get("title", "Заявка")], _show_review.bind(report))


func _build_archive() -> void:
	heading.text = "АРХИВ ПРОИСШЕСТВИЙ"
	summary.text = "Завершённых дел: %d" % game_state.job_reports.size()
	detail_title.text = "АРХИВ ЗАЯВОК"
	detail_body.text = "Выберите завершённую заявку слева."
	if game_state.job_reports.is_empty():
		_add_empty_entry("Архив пока пуст")
		return
	for index in range(game_state.job_reports.size() - 1, -1, -1):
		var report: Dictionary = game_state.job_reports[index]
		var damage_text := _claim_status_text(report)
		_add_entry("%s\n%s • %s" % [report.get("title", "Заявка"), _report_date(report), damage_text], _show_archive_report.bind(report))


func _show_financial_event(event: Dictionary) -> void:
	var kind := str(event.get("kind", ""))
	var kind_text: String = {
		"opening_balance": "Начальный баланс", "job": "Завершённая заявка",
		"purchase": "Покупка", "hire": "Найм сотрудника", "compensation": "Компенсация жильцу",
		"legacy_adjustment": "Старая операция", "debug_grant": "Тестовое пополнение",
	}.get(kind, "Денежная операция")
	var amount := int(event.get("amount", 0))
	detail_title.text = str(event.get("title", kind_text))
	detail_body.text = "%s\n%s\n\nИзменение средств: %s%d монет" % [kind_text, _event_date(event), "+" if amount >= 0 else "", amount]
	if kind == "job":
		detail_body.text += "\nПолучено: %d монет" % int(event.get("income", 0))
	if bool(event.get("legacy", false)):
		detail_body.text += "\n\nЗапись восстановлена из сохранения предыдущей версии."


func _show_review(report: Dictionary) -> void:
	var reputation_change := int(report.get("reputation_change", 0))
	detail_title.text = "%s — %s" % [report.get("resident", "Жилец"), _stars(_report_rating(report))]
	detail_body.text = "%s\n%s\n\n%s\n\nИзменение репутации: %s%d" % [
		report.get("title", "Заявка"), _report_date(report), _review_text(report),
		"+" if reputation_change >= 0 else "", reputation_change,
	]
	if bool(report.get("overdue", false)):
		detail_body.text += "\n\nЗаявка завершена после истечения срока."


func _review_text(report: Dictionary) -> String:
	var stored_review := str(report.get("review", "")).strip_edges()
	if not stored_review.is_empty():
		return stored_review
	var rating := _report_rating(report)
	match str(report.get("job_id", "")):
		"lava_leak":
			return "Кран больше не плюётся лавой — уже праздник. Жаль, что ванная после вашей бригады выглядит так, будто праздник был с фейерверками." if rating <= 3 else "Спасибо! Из крана снова не течёт лава. Для демона звучит как жалоба, но для владельца ванной — настоящее счастье."
		"walking_wardrobe":
			return "Шкаф больше не ходит, зато теперь ему явно нужен мебельный врач. Я просила усмирить его, а не победить в поединке." if rating <= 3 else "Шкаф снова притворяется обычной мебелью. Надеюсь, вы не научили его делать это только при проверяющих."
		"portal_mirror":
			return "Портал исчез, но зеркало пережило это хуже всех. Придётся любоваться собой по памяти." if rating <= 3 else "Наконец-то зеркало снова показывает только меня. Никогда не думала, что буду так рада обычному отражению."
	return "Авария закончилась. Подробности я лучше перескажу соседям — у них всё равно получится драматичнее."


func _show_archive_report(report: Dictionary) -> void:
	detail_title.text = str(report.get("title", "Завершённая заявка"))
	var crew: Array = report.get("crew", [])
	var text := "%s\nЖилец: %s\nБригада: %s\n\nИтог: %s\n\nОплата: %d монет\nКомпенсация: %d монет" % [
		_report_date(report), report.get("resident", "не указан"), ", ".join(PackedStringArray(crew)) if not crew.is_empty() else "не указана",
		report.get("summary", "Работы завершены."), int(report.get("reward", 0)), int(report.get("compensation", 0)),
	]
	var claim_status := str(report.get("claim_status", "none"))
	if claim_status == "denied":
		text += "\nРешение по претензии: отказано"
		selected_claim_key = {
			"job_id": str(report.get("job_id", "")),
			"completed_day": int(report.get("completed_day", 0)),
			"completed_time": int(report.get("completed_time", -1)),
		}
		pay_claim_button.text = "ВЫПЛАТИТЬ %d МОНЕТ" % int(report.get("claim_amount", 0))
		pay_claim_button.visible = int(report.get("claim_amount", 0)) > 0
	elif claim_status == "paid":
		text += "\nРешение по претензии: выплачено"
	elif claim_status == "paid_after_denial":
		text += "\nРешение по претензии: выплачено после первоначального отказа"
	text += "\n\nПОСЛЕДСТВИЯ"
	for consequence: String in _report_consequences(report):
		text += "\n• %s" % consequence
	detail_body.text = text


func _report_consequences(report: Dictionary) -> PackedStringArray:
	var result := PackedStringArray()
	var stored: Variant = report.get("consequences", [])
	if stored is Array:
		for consequence: Variant in stored:
			var text := str(consequence).strip_edges()
			if not text.is_empty() and not result.has(text):
				result.append(text)
	if bool(report.get("overdue", false)):
		result.append("Заявка завершена после истечения срока.")
	match str(report.get("claim_status", "none")):
		"paid":
			result.append("Претензия жильца удовлетворена: выплачено %d монет." % int(report.get("compensation", 0)))
		"paid_after_denial":
			result.append("После первоначального отказа служба выплатила %d монет и восстановила потерянную из-за отказа репутацию." % int(report.get("compensation", 0)))
		"denied":
			result.append("В компенсации ущерба отказано; репутация службы снижена на %d." % int(report.get("claim_reputation_penalty", 0)))
	var follow_up: Variant = report.get("follow_up", {})
	if follow_up is Dictionary and str((follow_up as Dictionary).get("type", "")) == "escaped_ghost":
		var ghost_text := "Из портала выбрался призрак; это может создать новую заявку."
		var ghost_already_listed := false
		for consequence: String in result:
			if "призрак" in consequence.to_lower():
				ghost_already_listed = true
				break
		if not ghost_already_listed:
			result.append(ghost_text)
	if result.is_empty():
		if int(report.get("compensation", 0)) > 0:
			result.append("За причинённый ущерб выплачена компенсация %d монет." % int(report.get("compensation", 0)))
		else:
			result.append("Дополнительного ущерба не зафиксировано.")
	return result


func _claim_status_text(report: Dictionary) -> String:
	match str(report.get("claim_status", "none")):
		"paid":
			return "выплачено: %d" % int(report.get("compensation", 0))
		"paid_after_denial":
			return "выплачено после отказа: %d" % int(report.get("compensation", 0))
		"denied":
			return "в компенсации отказано"
		"pending":
			return "претензия ожидает решения"
	return "без претензии"


func _pay_selected_claim() -> void:
	if selected_claim_key.is_empty():
		return
	var job_id := str(selected_claim_key.get("job_id", ""))
	var completed_day := int(selected_claim_key.get("completed_day", 0))
	var completed_time := int(selected_claim_key.get("completed_time", -1))
	if not game_state.pay_denied_claim(job_id, completed_day, completed_time):
		return
	for report_value: Variant in game_state.job_reports:
		if report_value is Dictionary:
			var report: Dictionary = report_value
			if str(report.get("job_id", "")) == job_id and int(report.get("completed_day", 0)) == completed_day and int(report.get("completed_time", -1)) == completed_time:
				_show_archive_report(report)
				return


func _report_rating(report: Dictionary) -> int:
	if report.has("rating"):
		return clampi(int(report["rating"]), 1, 5)
	var compensation := int(report.get("compensation", 0))
	var adjustment := int(report.get("reward_adjustment", 0))
	if compensation > 0 and adjustment <= -400:
		return 1
	if adjustment <= -300:
		return 2
	if adjustment < 0 or bool(report.get("overdue", false)):
		return 3
	return 5 if bool(report.get("maximum_payment", false)) else 4


func _report_date(report: Dictionary) -> String:
	return _date_text(int(report.get("completed_day", 0)), int(report.get("completed_time", -1)))


func _event_date(event: Dictionary) -> String:
	return _date_text(int(event.get("day", 0)), int(event.get("time_minutes", -1)))


func _date_text(day_value: int, minute_value: int) -> String:
	if day_value <= 0 or minute_value < 0:
		return "Ранее"
	return "День %d, %02d:%02d" % [day_value, minute_value / 60, minute_value % 60]


func _stars(rating: int) -> String:
	return "★".repeat(rating) + "☆".repeat(5 - rating)


func _add_entry(text_value: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(455, 78)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", COLOR_PARCHMENT)
	button.add_theme_stylebox_override("normal", _style(COLOR_CARD, COLOR_BRASS, 2, 7))
	button.add_theme_stylebox_override("hover", _style(COLOR_CARD_HOVER, COLOR_GOLD, 2, 7))
	button.pressed.connect(action)
	entry_list.add_child(button)


func _add_empty_entry(text_value: String) -> void:
	var label := Label.new()
	label.text = text_value
	label.custom_minimum_size = Vector2(455, 90)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", COLOR_MUTED)
	entry_list.add_child(label)


func _update_tabs() -> void:
	for tab_data: Array in [[accounting_button, &"accounting"], [reviews_button, &"reviews"], [archive_button, &"archive"]]:
		var button: Button = tab_data[0]
		var selected: bool = current_section == tab_data[1]
		button.add_theme_stylebox_override("normal", _style(COLOR_SELECTED if selected else COLOR_CARD, COLOR_GOLD if selected else COLOR_BRASS, 3 if selected else 2, 7))


func _apply_styles() -> void:
	$Header.add_theme_stylebox_override("panel", _style(COLOR_PANEL, COLOR_BRASS, 2, 10))
	$ListPanel.add_theme_stylebox_override("panel", _style(COLOR_PANEL, COLOR_BRASS, 2, 10))
	$DetailPanel.add_theme_stylebox_override("panel", _style(COLOR_PANEL, COLOR_BRASS, 2, 10))
	for button: Button in [accounting_button, reviews_button, archive_button, pay_claim_button, $BackButton]:
		button.add_theme_font_size_override("font_size", 15)
		button.add_theme_color_override("font_color", COLOR_PARCHMENT)
		button.add_theme_stylebox_override("hover", _style(COLOR_CARD_HOVER, COLOR_GOLD, 2, 7))
		button.add_theme_stylebox_override("pressed", _style(COLOR_SELECTED, COLOR_GOLD, 3, 7))
		button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, COLOR_GOLD, 2, 7))
	$BackButton.add_theme_stylebox_override("normal", _style(COLOR_CARD, COLOR_BRASS, 2, 7))
	pay_claim_button.add_theme_color_override("font_color", COLOR_GOLD)
	pay_claim_button.add_theme_color_override("font_hover_color", COLOR_GOLD)
	pay_claim_button.add_theme_stylebox_override("normal", _style(COLOR_SELECTED, COLOR_GOLD, 3, 8))
	pay_claim_button.add_theme_stylebox_override("hover", _style(COLOR_CARD_HOVER, COLOR_GOLD, 3, 8))


func _style(background: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
