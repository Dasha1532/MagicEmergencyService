extends SceneTree

var failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.start_new_game()
	_check(not game_state.is_demo_complete(), "Новая игра не считается завершённой демонстрацией")
	game_state.completed_job_ids = game_state.DEMO_CORE_JOB_IDS.duplicate()
	game_state.job_reports = [
		{"job_id": "lava_leak", "claim_amount": 0, "compensation": 0},
		{"job_id": "walking_wardrobe", "claim_amount": 180, "compensation": 180},
	]
	_check(game_state.is_demo_complete(), "Основные заявки завершают демонстрацию, если последствия не создавались")
	game_state.job_reports[0]["follow_up"] = {"type": "frozen_bath"}
	_check(not game_state.is_demo_complete(), "Созданная заявка-последствие становится обязательной")
	game_state.completed_job_ids.append("frozen_bath")
	_check(game_state.is_demo_complete(), "Выполненная заявка-последствие завершает выбранную ветку")
	_check(game_state.should_show_demo_completion(), "Финальный экран готов к показу после последнего отчёта")
	var summary: Dictionary = game_state.get_demo_summary()
	_check(int(summary["completed_jobs"]) == 5 and int(summary["required_jobs"]) == 5, "Итог показывает фактическое число заявок выбранной ветки")
	_check(int(summary["damaged_jobs"]) == 1 and int(summary["compensation_paid"]) == 180, "Итог учитывает ущерб и компенсации")

	var office := (load("res://scenes/ui/OfficeDashboard.tscn") as PackedScene).instantiate()
	root.add_child(office)
	await process_frame
	_check(office.demo_completion_layer.visible, "После последней заявки появляется явный финальный экран")
	_check("ДЕМОНСТРАЦИЯ" in office.demo_completion_title.text, "Финальный экран явно сообщает о завершении демонстрации")
	_check(not "ВЕРТИКАЛЬНЫЙ СРЕЗ" in office.demo_completion_title.text, "Техническая формулировка вертикального среза убрана")
	office._continue_after_demo()
	_check(game_state.demo_completion_seen and not office.demo_completion_layer.visible, "Игрок может остаться в офисе после просмотра итогов")
	_check(not game_state.should_show_demo_completion(), "Просмотренный финал повторно не всплывает")
	office.queue_free()
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("DEMO COMPLETION SMOKE TEST: PASS")
		quit(0)
	else:
		print("DEMO COMPLETION SMOKE TEST: FAIL (%d)" % failures.size())
		quit(1)
