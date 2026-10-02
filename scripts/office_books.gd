extends Control

const LocalizationHelperScript := preload("res://scripts/localization_helper.gd")

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
var selected_detail_kind: StringName = &""
var selected_detail_data: Dictionary = {}


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
	selected_detail_kind = &""
	selected_detail_data = {}
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
	_restore_selected_detail()


func _restore_selected_detail() -> void:
	if selected_detail_kind == current_section and not selected_detail_data.is_empty():
		match selected_detail_kind:
			&"accounting":
				_render_financial_event(selected_detail_data)
			&"reviews", &"archive":
				var report := _find_current_report(selected_detail_data)
				if not report.is_empty():
					if selected_detail_kind == &"reviews":
						_render_review(report)
					else:
						_render_archive_report(report)


func _report_key(report: Dictionary) -> Dictionary:
	return {"job_id": str(report.get("job_id", "")), "completed_day": int(report.get("completed_day", 0)), "completed_time": int(report.get("completed_time", -1))}


func _find_current_report(key: Dictionary) -> Dictionary:
	for report_value: Variant in game_state.job_reports:
		if report_value is Dictionary:
			var report: Dictionary = report_value
			if _report_key(report) == key:
				return report
	return {}


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
	var denied_total: int = game_state.get_denied_claims_total()
	summary.text = tr("Казна: %d, доходы: %d, расходы: %d\nОтклонённые претензии: %d, финансовый риск: %s") % [
		game_state.money, income, expenses, denied_total, tr(game_state.get_financial_risk_status()),
	]
	detail_title.text = "ДЕНЕЖНЫЕ ОПЕРАЦИИ"
	detail_body.text = "Выберите запись слева, чтобы увидеть подробности."
	if game_state.financial_ledger.is_empty():
		_add_empty_entry("Операций пока нет")
		return
	for index in range(game_state.financial_ledger.size() - 1, -1, -1):
		var event: Dictionary = game_state.financial_ledger[index]
		var amount := int(event.get("amount", 0))
		var sign_text := "+%d" % amount if amount >= 0 else str(amount)
		_add_entry(tr("%s\n%s, %s монет") % [tr(str(event.get("title", "Операция"))), _event_date(event), sign_text], _show_financial_event.bind(event))


func _build_reviews() -> void:
	heading.text = "КНИГА ОТЗЫВОВ"
	var titles: PackedStringArray = game_state.get_reputation_titles(2)
	summary.text = tr("Репутация: %d — %s\nПрозвища: %s. Отзывов: %d") % [game_state.reputation, tr(game_state.get_reputation_status()), ", ".join(_translated_strings(titles)), game_state.job_reports.size()]
	detail_title.text = "ОТЗЫВЫ КЛИЕНТОВ"
	detail_body.text = "Здесь появятся оценки завершённых заявок."
	if game_state.job_reports.is_empty():
		_add_empty_entry("Завершённых заявок пока нет")
		return
	for index in range(game_state.job_reports.size() - 1, -1, -1):
		var report: Dictionary = game_state.job_reports[index]
		var rating := _report_rating(report)
		_add_entry("%s\n%s — %s" % [tr(str(report.get("resident", "Клиент"))), _stars(rating), tr(str(report.get("title", "Заявка")))], _show_review.bind(report))


func _build_archive() -> void:
	heading.text = "АРХИВ ПРОИСШЕСТВИЙ"
	summary.text = tr("Завершённых дел: %d") % game_state.job_reports.size()
	detail_title.text = "АРХИВ ЗАЯВОК"
	detail_body.text = "Выберите завершённую заявку слева."
	if game_state.job_reports.is_empty():
		_add_empty_entry("Архив пока пуст")
		return
	for index in range(game_state.job_reports.size() - 1, -1, -1):
		var report: Dictionary = game_state.job_reports[index]
		var damage_text := tr(_claim_status_text(report))
		_add_entry("%s\n%s — %s" % [tr(str(report.get("title", "Заявка"))), _report_date(report), damage_text], _show_archive_report.bind(report))


func _show_financial_event(event: Dictionary) -> void:
	selected_detail_kind = &"accounting"
	selected_detail_data = event.duplicate(true)
	_render_financial_event(event)


func _render_financial_event(event: Dictionary) -> void:
	var kind := str(event.get("kind", ""))
	var kind_text: String = {
		"opening_balance": "Начальный баланс", "job": "Завершённая заявка",
		"purchase": "Покупка", "hire": "Найм сотрудника", "compensation": "Компенсация клиенту",
		"legacy_adjustment": "Старая операция", "debug_grant": "Тестовое пополнение",
	}.get(kind, "Денежная операция")
	var amount := int(event.get("amount", 0))
	detail_title.text = LocalizationHelperScript.translate_saved_text(event.get("title", kind_text))
	detail_body.text = tr("%s\n%s\n\nИзменение средств: %s%d монет") % [tr(kind_text), _event_date(event), "+" if amount >= 0 else "", amount]
	if kind == "job":
		detail_body.text += tr("\nПолучено: %d монет") % int(event.get("income", 0))
		var claim_status := str(event.get("claim_status", "none"))
		for report_value: Variant in game_state.job_reports:
			if report_value is Dictionary:
				var report: Dictionary = report_value
				if str(report.get("job_id", "")) == str(event.get("job_id", "")) and int(report.get("completed_day", -1)) == int(event.get("completed_day", -2)) and int(report.get("completed_time", -1)) == int(event.get("completed_time", -2)):
					claim_status = str(report.get("claim_status", claim_status))
					break
		var claim_amount := int(event.get("claim_amount", 0))
		if claim_status == "pending" and claim_amount > 0:
			detail_body.text += tr("\nПредъявлена претензия: %d монет (решение не принято)") % claim_amount
		elif claim_status == "denied" and claim_amount > 0:
			detail_body.text += tr("\nПретензия на %d монет отклонена; списания не было") % claim_amount
		elif claim_status in ["paid", "paid_after_denial"] and claim_amount > 0:
			detail_body.text += tr("\nКомпенсация проведена отдельной операцией: %d монет") % claim_amount
		elif claim_status == "settled_by_restoration":
			detail_body.text += tr("\nПретензия закрыта восстановлением имущества; денежной выплаты не было.")
	if bool(event.get("legacy", false)):
		detail_body.text += tr("\n\nЗапись восстановлена из сохранения предыдущей версии.")


func _show_review(report: Dictionary) -> void:
	selected_detail_kind = &"reviews"
	selected_detail_data = _report_key(report)
	_render_review(report)


func _render_review(report: Dictionary) -> void:
	var reputation_change := int(report.get("reputation_change", 0))
	detail_title.text = "%s — %s" % [tr(str(report.get("resident", "Клиент"))), _stars(_report_rating(report))]
	detail_body.text = tr("%s\n%s\n\n%s\n\nИзменение репутации: %s%d") % [
		tr(str(report.get("title", "Заявка"))), _report_date(report), LocalizationHelperScript.translate_saved_text(_review_text(report)),
		"+" if reputation_change >= 0 else "", reputation_change,
	]
	if bool(report.get("overdue", false)):
		detail_body.text += tr("\n\nЗаявка завершена после истечения срока.")


func _review_text(report: Dictionary) -> String:
	if bool(report.get("restoration_refused", false)):
		return tr(game_state.RESTORATION_REFUSAL_REVIEW)
	var stored_review := str(report.get("review", "")).strip_edges()
	if not stored_review.is_empty():
		return LocalizationHelperScript.translate_saved_text(stored_review)
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
	selected_detail_kind = &"archive"
	selected_detail_data = _report_key(report)
	_render_archive_report(report)


func _render_archive_report(report: Dictionary) -> void:
	detail_title.text = tr(str(report.get("title", "Завершённая заявка")))
	var crew: Array = report.get("crew", [])
	var localized_crew := _translated_strings(PackedStringArray(crew))
	var text := tr("%s\nКлиент: %s\nБригада: %s\n\nИтог: %s\n\nОплата: %d монет") % [
		_report_date(report), tr(str(report.get("resident", "не указан"))), ", ".join(localized_crew) if not crew.is_empty() else tr("не указана"),
		LocalizationHelperScript.translate_saved_text(report.get("summary", "Работы завершены.")), int(report.get("reward", 0)),
	]
	var claim_status := str(report.get("claim_status", "none"))
	if claim_status == "pending":
		text += tr("\nПретензия: %d монет\nКомпенсация: решение не принято") % int(report.get("claim_amount", 0))
	elif claim_status == "denied":
		text += tr("\nПретензия: %d монет\nКомпенсация: отказано") % int(report.get("claim_amount", 0))
		text += tr("\nРешение по претензии: отказано")
		selected_claim_key = {
			"job_id": str(report.get("job_id", "")),
			"completed_day": int(report.get("completed_day", 0)),
			"completed_time": int(report.get("completed_time", -1)),
		}
		pay_claim_button.text = tr("ВЫПЛАТИТЬ %d МОНЕТ") % int(report.get("claim_amount", 0))
		pay_claim_button.visible = int(report.get("claim_amount", 0)) > 0
	elif claim_status == "paid":
		text += tr("\nКомпенсация: %d монет") % int(report.get("compensation", 0))
		text += tr("\nРешение по претензии: выплачено")
	elif claim_status == "paid_after_denial":
		text += tr("\nКомпенсация: %d монет") % int(report.get("compensation", 0))
		text += tr("\nРешение по претензии: выплачено после первоначального отказа")
	elif claim_status == "settled_by_restoration":
		text += tr("\nПретензия закрыта: имущество восстановлено за счёт службы.")
	else:
		text += tr("\nКомпенсация: не требуется")
	text += tr("\n\nПОСЛЕДСТВИЯ")
	for consequence: String in _report_consequences(report):
		text += "\n— %s" % LocalizationHelperScript.translate_saved_text(consequence)
	detail_body.text = text


func _report_consequences(report: Dictionary) -> PackedStringArray:
	var result := PackedStringArray()
	var stored: Variant = report.get("consequences", [])
	if stored is Array:
		for consequence: Variant in stored:
			var text := str(consequence).strip_edges()
			if not text.is_empty() and not result.has(text):
				result.append(LocalizationHelperScript.translate_saved_text(text))
	if bool(report.get("overdue", false)):
		result.append(tr("Заявка завершена после истечения срока."))
	match str(report.get("claim_status", "none")):
		"settled_by_restoration":
			result.append(tr("Имущество восстановлено за счёт службы. Претензия закрыта."))
		"paid":
			result.append(tr("%s: претензия удовлетворена, выплачено %d монет.") % [tr(str(report.get("resident", "Клиент"))), int(report.get("compensation", 0))])
		"paid_after_denial":
			result.append(tr("После первоначального отказа служба выплатила %d монет и восстановила потерянную из-за отказа репутацию.") % int(report.get("compensation", 0)))
		"denied":
			result.append(tr("В компенсации ущерба отказано; репутация службы снижена на %d, а сумма претензии учитывается как финансовый риск.") % int(report.get("claim_reputation_penalty", 0)))
	var follow_up: Variant = report.get("follow_up", {})
	if follow_up is Dictionary and str((follow_up as Dictionary).get("type", "")) == "escaped_ghost":
		var ghost_text := "Из портала выбрался призрак; это может создать новую заявку."
		var ghost_already_listed := false
		for consequence: String in result:
			if "призрак" in consequence.to_lower():
				ghost_already_listed = true
				break
		if not ghost_already_listed:
			result.append(tr(ghost_text))
	if result.is_empty():
		if int(report.get("compensation", 0)) > 0:
			result.append(tr("За причинённый ущерб выплачена компенсация %d монет.") % int(report.get("compensation", 0)))
		else:
			result.append(tr("Дополнительного ущерба не зафиксировано."))
	return result


func _claim_status_text(report: Dictionary) -> String:
	match str(report.get("claim_status", "none")):
		"settled_by_restoration":
			return "закрыта восстановлением имущества"
		"paid":
			return tr("выплачено: %d") % int(report.get("compensation", 0))
		"paid_after_denial":
			return tr("выплачено после отказа: %d") % int(report.get("compensation", 0))
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
		return tr("Ранее")
	return tr("День %d, %02d:%02d") % [day_value, minute_value / 60, minute_value % 60]


func _stars(rating: int) -> String:
	return "★".repeat(rating) + "☆".repeat(5 - rating)


func _translated_strings(values: PackedStringArray) -> PackedStringArray:
	var result := PackedStringArray()
	for value: String in values:
		result.append(tr(value))
	return result


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
