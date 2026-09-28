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
	_check(str(summary["reputation_status"]) == "Надёжная служба", "Итог показывает словесный статус репутации")
	_check(str((summary["inspection"] as Dictionary).get("title", "")) == "Лицензия подтверждена", "Устойчивой службе инспекция подтверждает лицензию")
	game_state.money = -50
	_check(str(game_state.get_demo_inspection_verdict().get("title", "")) == "Финансовое оздоровление", "Долг влияет на заключение инспекции")
	game_state.reputation = 24
	_check(str(game_state.get_demo_inspection_verdict().get("title", "")) == "Лицензия под угрозой", "Долг вместе с низкой репутацией создаёт худшее заключение")
	game_state.money = 600
	game_state.reputation = 37

	var office := (load("res://scenes/ui/OfficeDashboard.tscn") as PackedScene).instantiate()
	root.add_child(office)
	await process_frame
	_check(office.demo_completion_layer.visible, "После последней заявки появляется явный финальный экран")
	game_state.pending_job_report = {
		"title": "Проверка акта", "resident": "Заказчик", "crew": [],
		"reward": 620, "reputation_change": 1, "summary": "Работа завершена.",
	}
	office._refresh_job_report()
	_check("Изменение репутации: +1" in office.job_report_body.text, "Акт явно показывает положительное изменение репутации")
	var report_button := office.job_report_layer.find_child("ПРИНЯТЬ ОТЧЁТ", true, false) as Button
	if report_button == null:
		for child: Node in office.job_report_layer.find_children("*", "Button", true, false):
			if (child as Button).text == "ПРИНЯТЬ ОТЧЁТ":
				report_button = child as Button
				break
	_check(report_button != null and report_button.position.y - (office.job_report_body.position.y + office.job_report_body.size.y) >= 50.0, "Между текстом акта и кнопкой оставлен заметный отступ")
	game_state.pending_job_report = {}
	office._refresh_job_report()
	_check("ДЕМОНСТРАЦИЯ" in office.demo_completion_title.text, "Финальный экран явно сообщает о завершении демонстрации")
	_check(not "ВЕРТИКАЛЬНЫЙ СРЕЗ" in office.demo_completion_title.text, "Техническая формулировка вертикального среза убрана")
	_check("Лицензия подтверждена" in office.demo_completion_summary.text, "Финальная книга показывает заключение инспекции")
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
	office.demo_video_layer.visible = false
	office._show_demo_exit_blackout()
	_check(office.demo_video_layer.visible and office.demo_video_player.modulate.a == 0.0, "После ролика остаётся непрозрачный чёрный экран без показа офиса")
	var office_cat := (office.cat_poses[&"sleeping"] as TextureRect).get_parent() as Control
	_check(office_cat.modulate.r <= 0.6 and office_cat.modulate.g <= 0.6 and office_cat.modulate.b <= 0.6, "Все состояния кота приглушены общим затемнением в тени стола")
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
