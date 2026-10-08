extends SceneTree
const Dialogue := preload("res://scripts/prison_dialogue.gd")
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var ids := PackedStringArray(["boris", "grog", "liliya", "nika", "felix"])
	# Every composition and every possible lead.
	for mask: int in range(1, 32):
		var crew := PackedStringArray()
		for index: int in 5:
			if mask & (1 << index):
				crew.append(ids[index])
		for lead: String in crew:
			var lines := Dialogue.build("conversation", crew, lead)
			assert(not lines.is_empty())
			for line: Dictionary in lines:
				var speaker := str(line["speaker"])
				assert(speaker not in ids or crew.has(speaker))
				assert(not str(line.get("text", "")).is_empty())
			var has_boris := false
			for line: Dictionary in lines:
				if str(line.get("text", "")).begins_with("Боль началась"):
					has_boris = true
			assert(has_boris == crew.has("boris"))
	var gs = preload("res://tests/prison_test_state.gd").install(root)
	gs.prepare_prison(PackedStringArray(["grog", "felix"]))
	var room = load("res://scenes/PrisonRoom.tscn").instantiate()
	root.add_child(room)
	await process_frame
	assert(room.speaker_label.text == "Охранник")
	assert(room.dialogue_open)
	room._close_conversation()
	room.simulation.state["pain_seen"] = true
	room.simulation.state["conversation_unlocked"] = true
	room.selected_employee_id = "grog"
	room._open_conversation()
	assert(room.dialogue_employee_id == "grog")
	while room.dialogue_section == "conversation":
		room._next_line()
	assert(not room.question_button.visible)
	room._close_conversation()
	room.simulation.state["record_read"] = true
	room._open_conversation()
	while room.dialogue_section == "conversation":
		room._next_line()
	assert(room.question_button.visible)
	room._set_dialogue_lines("accusation")
	assert(room.speaker_label.text == room._employee_name("grog"))
	room._close_conversation()
	room.selected_employee_id = "felix"
	room._open_conversation()
	while room.dialogue_section == "conversation":
		room._next_line()
	assert(not room.question_button.visible)
	room._close_conversation()
	room._read_record()
	assert("Основание содержания" in room.get_node("Record/Text").text)
	assert(not "преграды" in room.get_node("Record/Text").text)
	assert(not "Черновик" in room.get_node("Record/Text").text)
	room.queue_free()
	await process_frame
	print("PRISON DIALOGUE: PASS")
	quit()
