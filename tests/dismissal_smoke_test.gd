extends SceneTree

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.start_new_game()
	game_state.job_reports = [
		_claim("old_1", "paid"),
		_claim("old_2", "denied"),
		_claim("old_3", "paid"),
		_claim("old_4", "paid_after_denial"),
	]
	game_state.jobs[&"portal_mirror"]["unlocked"] = true
	game_state.assign_employee(&"grog", &"portal_mirror")
	game_state.begin_job(&"portal_mirror")
	game_state.advance_time(game_state.TRAVEL_TIME_MINUTES)
	_check(game_state.complete_active_job({
		"summary": "Зеркало уничтожено.", "review": "Жалоба.",
		"reward_adjustment": -200, "compensation_cost": 300, "reputation_change": -2,
	}), "Пятая претензия создаётся обычным завершением заявки")
	_check(game_state.resolve_pending_claim(false), "Решение по пятой претензии принято")
	game_state.dismiss_pending_job_report()
	_check(game_state.dismissal_triggered and game_state.dismissal_reason == &"claims", "Пять подтверждённых претензий приводят к увольнению")
	_check(not game_state.should_show_demo_completion(), "Увольнение имеет приоритет над обычным финалом")
	_check(game_state.should_play_dismissal_video(), "До просмотра документа должен проиграться ролик")

	var office := (load("res://scenes/ui/OfficeDashboard.tscn") as PackedScene).instantiate()
	root.add_child(office)
	await process_frame
	await create_timer(0.45).timeout
	_check(office.demo_video_layer.visible and not office.demo_video_player.is_playing(), "Перед роликом выдерживается чёрный экран")
	await create_timer(1.30).timeout
	_check(office.demo_video_layer.visible and office.demo_video_player.is_playing(), "Ролик увольнения запускается автоматически")
	_check("notice_of_dismissal" in office.demo_video_player.stream.resource_path, "Подключён ролик NOTICE OF DISMISSAL")
	office._finish_final_video()
	await create_timer(0.45).timeout
	_check(office.demo_video_layer.visible and not office.demo_video_player.is_playing(), "После ролика снова показывается чёрный экран")
	await create_timer(0.65).timeout
	_check(game_state.dismissal_video_seen, "Завершение ролика сохраняется")
	_check(office.dismissal_document_layer.visible, "После ролика появляется постановление")
	_check("Пять подтверждённых" in office.dismissal_document_layer.get_node("Reason").text, "В постановлении указана причина увольнения")
	office.queue_free()
	await process_frame

	game_state.start_new_game()
	game_state.job_reports = [_claim("debt_claim", "pending")]
	game_state.pending_job_report = game_state.job_reports[0].duplicate(true)
	game_state.money = -600
	_check(game_state.resolve_pending_claim(true), "Крупная компенсация может углубить долг")
	_check(game_state.money == -900 and game_state.dismissal_reason == &"debt", "Долг −800 монет или глубже приводит к увольнению")
	_finish()


func _claim(job_id: String, status: String) -> Dictionary:
	return {
		"job_id": job_id, "title": "Претензия", "claim_amount": 300,
		"claim_status": status, "compensation": 300 if status in ["paid", "paid_after_denial"] else 0,
		"completed_day": 1, "completed_time": 540,
	}


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("DISMISSAL SMOKE TEST: PASS")
		quit(0)
	else:
		print("DISMISSAL SMOKE TEST: FAIL (%d)" % failures.size())
		quit(1)
