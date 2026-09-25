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
	_check(office.get_node_or_null("DemoCompletionLayer/ContinueButton") == null, "На финальном экране нет возврата в офис")
	_check(office.get_node_or_null("DemoCompletionLayer/MenuButton") != null, "На книге есть понятная кнопка перехода в главное меню")
	_check(office.demo_video_player.stream != null, "К финалу подключён ролик Лилии")
	office._start_demo_video()
	_check(not office.demo_completion_layer.visible, "После нажатия книга закрывается")
	_check(office.demo_video_layer.visible and office.demo_video_layer.modulate.a == 1.0, "Между книгой и роликом появляется непрозрачная чёрная заставка")
	await create_timer(1.05).timeout
	_check(office.demo_video_player.is_playing(), "После чёрной заставки начинается прощальный ролик")
	_check(not game_state.demo_completion_seen, "Прерванный до конца ролик не помечает финал просмотренным")
	office.demo_video_player.stop()
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
