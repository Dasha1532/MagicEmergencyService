extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _check(panel: Panel, body: Label) -> void:
	assert(body.size.y >= body.get_minimum_size().y)
	assert(panel.size.y < 852)
	var last_bottom := 0.0
	for child in panel.get_children():
		if child is Button:
			assert(child.position.y >= body.position.y + body.size.y + 20)
			assert(child.size.x < 360)
			last_bottom = maxf(last_bottom, child.position.y + child.size.y)
	assert(is_equal_approx(panel.size.y - last_bottom, 28))

func _run() -> void:
	var state = root.get_node("GameState")
	state.start_new_game()
	state.skip_tutorial()
	var office = load("res://scenes/ui/OfficeDashboard.tscn").instantiate()
	root.add_child(office)
	await process_frame
	var ui: Dictionary = office._build_notice_overlay("ВХОД В КВАРТИРУ", "Хозяин не впустил сотрудника: Лилия Морозова. Сотрудник возвращается в офис.", "ПОНЯТНО", "", Callable())
	ui.overlay.visible = true
	await process_frame
	await process_frame
	_check(ui.panel, ui.body)
	assert(ui.panel.size.y < 300)
	var short_height: float = ui.panel.size.y
	ui.overlay.visible = false
	ui.body.text = "Длинное уведомление с несколькими строками. ".repeat(12)
	ui.overlay.visible = true
	await process_frame
	await process_frame
	_check(ui.panel, ui.body)
	assert(ui.panel.size.y > short_height)
	office.arrival_dialog.visible = true
	await process_frame
	await process_frame
	_check(office.arrival_dialog_body.get_parent(), office.arrival_dialog_body)
	office.restoration_refuse_dialog.visible = true
	await process_frame
	await process_frame
	_check(office.restoration_refuse_dialog.get_child(1), office.restoration_refuse_dialog.get_child(1).get_child(1))
	office.claim_body.text = "Претензия: 350 монет.\nКомпенсация покроет уничтоженное имущество."
	office.claim_pay_button.text = "ВЫПЛАТИТЬ"
	office.claim_deny_button.text = "ОТКАЗАТЬ"
	office.claim_layer.visible = true
	await process_frame
	await process_frame
	_check(office.claim_body.get_parent(), office.claim_body)
	office.dispatch_warning_body.text = "В бригаде нет специалиста с антимагией. Продолжить?"
	office.dispatch_warning_dialog.visible = true
	await process_frame
	await process_frame
	_check(office.dispatch_warning_body.get_parent(), office.dispatch_warning_body)
	office.selected_employee_id = &"liliya"
	office.personnel_layer.visible = true
	office._open_specializations()
	await process_frame
	await process_frame
	var specialization_panel: Panel = office.specialization_title.get_parent()
	var specialization_close: Button = specialization_panel.get_meta("compact_close")
	assert(specialization_close.position.y >= office.specialization_notice.position.y + office.specialization_notice.size.y + 18)
	assert(specialization_panel.size.y < 500)
	assert(is_equal_approx(specialization_panel.size.y - specialization_close.position.y - specialization_close.size.y, 28))
	office.specialization_confirm_text.text = "Забыть заморозку? Способность можно изучить заново."
	office.specialization_confirm_layer.visible = true
	await process_frame
	await process_frame
	_check(office.specialization_confirm_text.get_parent(), office.specialization_confirm_text)
	office.job_report_body.text = "Короткий акт.\nРабота выполнена."
	await process_frame
	office._fit_job_report_dialog_to_content()
	assert(office.job_report_panel.size.y < 350)
	assert(not office.job_report_body.scroll_active)
	office.job_report_body.text = "Длинный акт с подробным описанием работ.\n".repeat(100)
	await process_frame
	office._fit_job_report_dialog_to_content()
	assert(office.job_report_panel.size.y <= 780)
	assert(office.job_report_body.scroll_active)
	assert(office.job_report_close_button.position.y >= office.job_report_body.position.y + office.job_report_body.size.y + 20)
	office.detail_expanded_title.text = "Кран покрылся магическим льдом"
	office.detail_expanded_body.text = "Короткое описание."
	office.dashboard_layer.visible = true
	office.detail_expanded_panel.visible = true
	await process_frame
	office._layout_expanded_details()
	assert(office.detail_expanded_panel.size.y < 350)
	assert(not office.detail_expanded_body.scroll_active)
	assert(office.detail_resident_button.position.y >= office.detail_expanded_title.position.y + office.detail_expanded_title.size.y + 14)
	office.queue_free()
	await process_frame
	print("COMPACT DIALOG SMOKE TEST: PASS")
	quit()
