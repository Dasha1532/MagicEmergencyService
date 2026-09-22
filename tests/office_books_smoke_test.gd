extends SceneTree

const REPAIR_SIMULATION_SCRIPT = preload("res://scripts/repair_simulation.gd")

var failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.start_new_game()
	_check(game_state.SAVE_VERSION == 9, "Используется формат сохранения 9")
	_check(game_state.financial_ledger.size() == 1, "Новая игра начинает единый денежный журнал")

	var books_scene := load("res://scenes/ui/OfficeBooks.tscn") as PackedScene
	_check(books_scene != null, "Сцена служебных книг загружается")
	if books_scene == null:
		_finish()
		return
	var books := books_scene.instantiate()
	root.add_child(books)
	await process_frame
	books.open_section(&"reviews")
	_check("Отзывов: 0" in books.summary.text, "Книга отзывов показывает пустое состояние")
	books.open_section(&"archive")
	_check("Завершённых дел: 0" in books.summary.text, "Архив показывает пустое состояние")

	game_state.grant_debug_money(1000)
	_check(game_state.buy_supply_item(&"animation_kit"), "Покупка выполнена")
	_check(game_state.hire_employee(&"nika"), "Найм выполнен")
	_check(_has_ledger_kind(game_state.financial_ledger, "purchase"), "Покупка записана в книгу учёта")
	_check(_has_ledger_kind(game_state.financial_ledger, "hire"), "Найм записан в книгу учёта")

	game_state.assign_employee(&"liliya", &"lava_leak")
	game_state.begin_job(&"lava_leak")
	game_state.advance_time(game_state.TRAVEL_TIME_MINUTES)
	var result := {
		"summary": "Поток остановлен, жильцу всё понравилось.",
		"review": "Теперь ванна снова годится для купания, а не для приготовления демона в собственном соку.",
		"reward_adjustment": 0,
		"reputation_change": 1,
		"consequences": ["Дополнительного ущерба не зафиксировано."],
		"actions": [{
			"employee_id": "liliya", "action_id": "freeze",
			"result": {"message": "Лава безопасно заморожена."},
		}],
	}
	_check(game_state.complete_active_job(result), "Заявка завершена для проверки книг")
	_check(game_state.job_reports.size() == 1, "Общий отчёт добавлен")
	var report: Dictionary = game_state.job_reports[0]
	_check(int(report.get("rating", 0)) == 5, "Отчёт получил оценку")
	_check(int(report.get("completed_day", 0)) == 1, "В отчёте сохранена дата завершения")
	_check(_has_ledger_kind(game_state.financial_ledger, "job"), "Доход заявки записан в книгу учёта")

	books.open_section(&"reviews")
	_check("Отзывов: 1" in books.summary.text, "Книга отзывов обновилась")
	var review_button := books.entry_list.get_child(0) as Button
	review_button.pressed.emit()
	_check("★★★★★" in books.detail_title.text, "Отзыв показывает оценку")
	_check("приготовления демона" in books.detail_body.text, "Отзыв показывает живую реплику жильца")
	_check("Поток остановлен" not in books.detail_body.text, "Технический итог не подставляется вместо отзыва")

	books.open_section(&"archive")
	var archive_button := books.entry_list.get_child(0) as Button
	archive_button.pressed.emit()
	_check("ПОСЛЕДСТВИЯ" in books.detail_body.text, "Архив показывает раздел последствий")
	_check("Дополнительного ущерба не зафиксировано" in books.detail_body.text, "Архив показывает отсутствие ущерба")
	_check("Лилия Морозова — Заморозка" not in books.detail_body.text, "Архив не показывает пошаговый журнал действий")

	var repair_simulation = REPAIR_SIMULATION_SCRIPT.new()
	repair_simulation.world_object["tags"] = PackedStringArray(["faucet", "stabilized", "repaired"])
	repair_simulation.world_object["damage"] = 0
	var clean_repair_result: Dictionary = repair_simulation.get_completion_result()
	_check(int(clean_repair_result.get("reputation_change", 0)) == 1, "Безупречный ремонт повышает репутацию")
	_check((clean_repair_result.get("consequences", []) as Array).has("Дополнительного ущерба не зафиксировано."), "Чистый ремонт фиксирует отсутствие ущерба")

	books.open_section(&"accounting")
	_check("Сейчас: %d монет" % game_state.money in books.summary.text, "Книга учёта показывает текущий баланс")
	_check(books.entry_list.get_child_count() == game_state.financial_ledger.size(), "Все денежные операции показаны")
	var ledger_balance := 0
	for event: Dictionary in game_state.financial_ledger:
		ledger_balance += int(event.get("amount", 0))
	_check(ledger_balance == game_state.money, "Текущий денежный журнал сходится с балансом")

	game_state.financial_ledger = []
	game_state._rebuild_legacy_financial_ledger()
	var reconstructed_balance := 0
	for event: Dictionary in game_state.financial_ledger:
		reconstructed_balance += int(event.get("amount", 0))
	_check(reconstructed_balance == game_state.money, "Старый денежный журнал восстанавливает текущий баланс")
	_finish()


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
		print("OFFICE BOOKS SMOKE TEST: PASS")
		quit(0)
	else:
		print("OFFICE BOOKS SMOKE TEST: FAIL (%d)" % failures.size())
		quit(1)
