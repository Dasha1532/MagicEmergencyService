extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var gs = preload("res://tests/prison_test_state.gd").install(root)
	gs.prepare_prison(PackedStringArray(["boris", "grog", "felix"]))
	var room = load("res://scenes/PrisonRoom.tscn").instantiate()
	root.add_child(room)
	await process_frame
	room._next_line()
	assert(room.dialogue_portrait.texture is AtlasTexture)
	assert(room.dialogue_portrait.texture.region == Rect2(190, 0, 650, 620))
	room._close_conversation()
	room.repair_hud._select_employee(&"grog")
	assert(room.selected_employee_id == "grog")
	assert(not room.perform_action("inspect"))
	room.repair_hud._select_employee(&"boris")
	room.show_room("cells")
	room._show_actions("lock")
	assert(room.tool_bar.visible)
	for id: String in ["inspect", "repair_mechanism", "test_protection", "stop_test"]:
		assert(room.perform_action(id))
		if id == "test_protection":
			room.show_room("cells")
		assert(room.dialogue_open and room.dialogue_panel.visible)
		while room.dialogue_open:
			room._next_line()
	assert(room.talk is Control and not room.talk is Button)
	assert(room.talk.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND)
	room._show_actions("girl")
	var found_talk := false
	for button: Button in room.tool_bar.temporary_buttons:
		if button.text == "Поговорить":
			found_talk = true
			button.pressed.emit()
			break
	assert(found_talk and room.dialogue_open)
	room._close_conversation()
	assert(room._employee_name("girl") == "Заключённая")
	room.show_room("office")
	room._read_record()
	room.record.hide()
	room._refresh()
	assert(room.perform_action("authorize_shutdown"))
	room._close_conversation()
	assert(not room.perform_action("antimagic"))
	room.repair_hud._select_employee(&"felix")
	assert(room.selected_employee_id == "felix")
	assert(room.perform_action("antimagic"))
	room._close_conversation()
	room.repair_hud._select_employee(&"boris")
	assert(room.perform_action("finish_repair"))
	room._close_conversation()
	assert(not room.finish_button.disabled)
	var pause = room.get_node("PauseMenu")
	assert(not pause.menu_button.visible)
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	pause._input(esc)
	assert(pause.overlay.visible and paused)
	pause._input(esc)
	assert(not pause.overlay.visible and not paused)
	var guard: TextureRect = room.get_node("Office/Guard")
	assert(guard.idle_tween.is_running())
	assert(room.get_node("Cells/MysteriousGirl").idle_tween.is_running())
	await create_timer(0.3).timeout
	assert(guard.scale.y == 1.0 and guard.scale.x > 1.0 and guard.scale.x < 1.01)
	room.queue_free()
	await process_frame
	print("PRISON HUD: PASS")
	quit()
