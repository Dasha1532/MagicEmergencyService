extends SceneTree

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	var damage_result := {
		"summary": "Зеркало уничтожено.",
		"review": "Это было фамильное зеркало!",
		"reward_adjustment": -200,
		"compensation_cost": 300,
		"reputation_change": -2,
		"consequences": ["Старинное зеркало уничтожено."],
	}

	_prepare_job(game_state)
	var money_before: int = game_state.money
	_check(game_state.complete_active_job(damage_result), "Заявка с ущербом завершается")
	var reward := int(game_state.pending_job_report.get("reward", 0))
	_check(game_state.money == money_before + reward, "До решения начисляется оплата без автоматической компенсации")
	_check(str(game_state.pending_job_report.get("claim_status", "")) == "pending", "Претензия ожидает решения")
	_check(not game_state.pending_job_report.is_empty(), "Ожидающую претензию нельзя закрыть вместе с актом")
	_check(game_state.save_game(5) == OK, "Ожидающая претензия сохраняется")
	game_state.start_new_game()
	_check(game_state.load_game(5) == OK and str(game_state.pending_job_report.get("claim_status", "")) == "pending", "Ожидающая претензия восстанавливается из сохранения")
	var dashboard_scene := load("res://scenes/ui/OfficeDashboard.tscn") as PackedScene
	var dashboard := dashboard_scene.instantiate()
	root.add_child(dashboard)
	await process_frame
	_check(dashboard.job_report_layer.visible, "После загрузки сначала показывается акт выполненных работ")
	dashboard._dismiss_job_report()
	_check(dashboard.claim_layer.visible and not dashboard.job_report_layer.visible, "После принятия акта открывается обязательное окно претензии")
	_check(not "•" in dashboard.claim_pay_button.text and not "•" in dashboard.claim_deny_button.text, "Кнопки претензии используют понятные знаки вместо точек-разделителей")
	dashboard.queue_free()
	await process_frame
	game_state.money = 100
	var balance_before_payment: int = game_state.money
	_check(game_state.resolve_pending_claim(true), "Претензию можно компенсировать")
	_check(game_state.money == balance_before_payment - 300, "Компенсация списывается отдельным решением")
	_check(game_state.money < 0, "Компенсация допускает долг службы")
	_check(str(game_state.job_reports[-1].get("claim_status", "")) == "paid", "Архив хранит удовлетворённую претензию")
	_check(_has_ledger_kind(game_state.financial_ledger, "compensation"), "Выплата записывается отдельно в книгу учёта")

	game_state.start_new_game()
	_prepare_job(game_state)
	_check(game_state.complete_active_job(damage_result), "Вторая претензия подготовлена для проверки отказа")
	var balance_before_denial: int = game_state.money
	var reputation_before_denial: int = game_state.reputation
	_check(game_state.resolve_pending_claim(false), "В компенсации можно отказать")
	_check(game_state.money == balance_before_denial, "При отказе деньги не списываются")
	_check(game_state.reputation == reputation_before_denial - 2, "Крупная отклонённая претензия снижает репутацию на 2")
	var denied_report: Dictionary = game_state.job_reports[-1]
	_check(str(denied_report.get("claim_status", "")) == "denied", "Архив хранит отказ по претензии")
	_check("отказали" in str(denied_report.get("review", "")), "Отказ отражается в отзыве жильца")
	_check(game_state.get_denied_claims_total() == 300, "Отклонённая претензия учитывается отдельным финансовым риском")
	_check(game_state.get_financial_risk_status() == "повышенный", "Для накопленной суммы определяется понятный уровень риска")
	var balance_before_late_payment: int = game_state.money
	var reputation_before_late_payment: int = game_state.reputation
	_check(game_state.pay_denied_claim(
		str(denied_report.get("job_id", "")),
		int(denied_report.get("completed_day", 0)),
		int(denied_report.get("completed_time", -1))
	), "Отклонённую претензию можно позднее оплатить из архива")
	var paid_late_report: Dictionary = game_state.job_reports[-1]
	_check(game_state.money == balance_before_late_payment - 300, "Поздняя компенсация списывает деньги")
	_check(game_state.reputation == reputation_before_late_payment + 2, "Поздняя выплата возвращает штраф репутации за отказ")
	_check(str(paid_late_report.get("claim_status", "")) == "paid_after_denial", "Архив хранит позднюю выплату")
	_check(not "отказали" in str(paid_late_report.get("review", "")), "После выплаты отзыв больше не сообщает о действующем отказе")
	_check(game_state.get_denied_claims_total() == 0 and game_state.get_financial_risk_status() == "нет", "Поздняя выплата снимает финансовый риск претензии")
	_check(not game_state.pay_denied_claim(
		str(denied_report.get("job_id", "")),
		int(denied_report.get("completed_day", 0)),
		int(denied_report.get("completed_time", -1))
	), "Одну претензию нельзя оплатить повторно")
	var books := (load("res://scenes/ui/OfficeBooks.tscn") as PackedScene).instantiate()
	root.add_child(books)
	await process_frame
	books.open_section(&"reviews")
	_check(not books.summary.get_global_rect().intersects(books.accounting_button.get_global_rect()), "Сводка книги отзывов не заходит под кнопку учёта")
	_check("\n" in books.summary.text, "Длинная сводка книги отзывов переносится на отдельную строку")
	books.queue_free()
	_finish()


func _prepare_job(game_state: Node) -> void:
	game_state.jobs[&"portal_mirror"]["unlocked"] = true
	game_state.assign_employee(&"grog", &"portal_mirror")
	game_state.begin_job(&"portal_mirror")
	game_state.advance_time(game_state.TRAVEL_TIME_MINUTES)


func _has_ledger_kind(ledger: Array, kind: String) -> bool:
	for event: Dictionary in ledger:
		if str(event.get("kind", "")) == kind:
			return true
	return false


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("CLAIMS SMOKE TEST: PASS")
		quit(0)
	else:
		print("CLAIMS SMOKE TEST: FAIL (%d)" % failures.size())
		quit(1)
