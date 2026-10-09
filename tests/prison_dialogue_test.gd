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
	assert(room.speaker_label.text.is_empty())
	assert("Охранник останавливается" in room.speech_label.text)
	assert(room.dialogue_open)
	assert(room.current_room == "cells")
	assert(room.get_node("Cells/ArrivalGuard").visible)
	assert(not room.simulation.state.get("arrival_seen", false))
	room.show_room("office")
	assert(room.current_room == "cells")
	var saw_turn := false
	var saw_turn_back := false
	while room.current_room == "cells" and room.dialogue_open:
		room._next_line()
		if "Она поворачивается к пришедшим" in room.speech_label.text:
			assert(room.mysterious_girl.flip_h)
			saw_turn = true
		if "На посту, через щиток" in room.speech_label.text:
			assert(not room.mysterious_girl.flip_h)
			saw_turn_back = true
	assert(saw_turn and saw_turn_back)
	assert(room.current_room == "office")
	assert(room.get_node("Office/ProtectionHighlight").visible)
	assert(not room.get_node("Cells/ArrivalGuard").visible)
	assert(gs.clock_paused)
	while room.dialogue_open:
		room._next_line()
	assert(not room.dialogue_open)
	assert(room.current_room == "cells")
	assert(not room.get_node("Office/ProtectionHighlight").visible)
	assert(room.get_node("Cells/ArrivalGuard").visible)
	assert(room.simulation.state["arrival_seen"])
	# Repeat and interrupt the tour: the view and highlight must be cleaned up.
	room._begin_dialogue("arrival", false)
	while room.current_room == "cells":
		room._next_line()
	room._close_conversation()
	assert(room.current_room == "cells")
	assert(not room.get_node("Office/ProtectionHighlight").visible)
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
