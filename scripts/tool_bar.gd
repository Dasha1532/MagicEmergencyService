extends MarginContainer

signal tool_selected(tool_id: StringName)
signal intent_selected(intent_id: StringName)

const TOOL_NAMES: Dictionary = {
	"FreezeButton": [&"freeze", "Заморозка"],
	"HeatButton": [&"heat", "Нагрев"],
	"MoveButton": [&"telekinesis", "Телекинез"],
	"PhysicalMoveButton": [&"physical_move", "Силовая работа"],
	"AnimateButton": [&"animate", "Оживление"],
	"AntimagicButton": [&"antimagic", "Антимагия"],
	"DiagnoseButton": [&"diagnose", "Осмотр"],
	"RepairButton": [&"repair", "Ремонт"],
}

@onready var title_label: Label = %TitleLabel
@onready var buttons_container: VBoxContainer = $Panel/ContentMargin/Content/Buttons
@onready var buttons: Array[Button] = [
	%FreezeButton,
	%HeatButton,
	%MoveButton,
	%PhysicalMoveButton,
	%AnimateButton,
	%AntimagicButton,
	%DiagnoseButton,
	%RepairButton,
]
var current_tool_id: StringName = &"freeze"
var available_buttons: Array[Button] = []
var temporary_buttons: Array[Button] = []
var current_object_name: String = "Объект"
var menu_height: float = 117.0
var current_action_labels: Dictionary = {}
var hidden_action_ids: PackedStringArray = PackedStringArray()
var configured_employee_name: String = ""
var pending_inspection_object: String = ""
var pending_inspection_log_size: int = 0


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventMouseButton:
		return
	if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local_point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if not Rect2(Vector2.ZERO, size).has_point(local_point):
			hide()


func _ready() -> void:
	get_node("/root/GameState").state_changed.connect(_record_completed_inspection)
	buttons_container.move_child(%DiagnoseButton, 0)
	buttons_container.move_child(%RepairButton, 1)
	for button in buttons:
		button.pressed.connect(_on_button_pressed.bind(button))
		button.toggle_mode = false
		button.custom_minimum_size = Vector2(320 if button == %HeatButton else 252, 46)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 15)
		button.add_theme_constant_override("h_separation", 9)
		var tool_data: Array = TOOL_NAMES[button.name]
		button.text = tr(str(tool_data[1]))
		for child: Node in button.get_children():
			if child is TextureRect:
				button.icon = child.texture
				button.expand_icon = true
				button.add_theme_constant_override("icon_max_width", 52 if button == %HeatButton else 38)
				child.visible = false
	visible = false


func configure_for_employee(employee_name: String, ability_ids: PackedStringArray, core_actions: String) -> void:
	configured_employee_name = employee_name
	_clear_temporary_buttons()
	available_buttons.clear()
	var available_count: int = 0
	for button in buttons:
		var tool_data: Array = TOOL_NAMES[button.name]
		var is_available := ability_ids.has(String(tool_data[0]))
		button.visible = is_available
		button.disabled = not is_available
		button.button_pressed = false
		if is_available:
			available_buttons.append(button)
			available_count += 1

	_resize_for_action_count(available_count)
	current_tool_id = &""
	title_label.text = "%s — %s" % [tr(employee_name), tr(core_actions)]
	visible = false


func get_selected_tool_id() -> StringName:
	return current_tool_id


func show_for_object(object_name: String, anchor_position: Vector2, action_labels: Dictionary = {}, contextual_actions: Array = [], hidden_actions: PackedStringArray = PackedStringArray()) -> void:
	current_object_name = object_name
	current_action_labels = action_labels.duplicate()
	hidden_action_ids = hidden_actions.duplicate()
	if _is_boris():
		_record_completed_inspection()
		for action: Array in TOOL_NAMES.values():
			if not _boris_action_allowed(StringName(action[0])):
				hidden_action_ids.append(String(action[0]))
		contextual_actions = contextual_actions.filter(func(action: Dictionary) -> bool: return _boris_action_allowed(StringName(str(action.get("id", "")))))
		var state: Node = get_node("/root/GameState")
		var inspected: Array = state.get_job_repair_state(state.active_job_id).get("boris_inspected_objects", [])
		if not inspected.has(object_name):
			for action: Array in TOOL_NAMES.values():
				if action[0] != &"diagnose":
					hidden_action_ids.append(String(action[0]))
			contextual_actions = []
	_show_ability_buttons()
	_add_contextual_actions(contextual_actions)
	title_label.text = tr(object_name).to_upper()
	visible = true
	position = Vector2(
		clampf(anchor_position.x + 42.0, 20.0, 1300.0),
		clampf(anchor_position.y - menu_height * 0.45, 90.0, 690.0 - menu_height)
	)
	_avoid_dialogue_overlap()
	move_to_front()


func show_intents(title: String, choices: Array) -> void:
	for button in buttons:
		button.visible = false
	_clear_temporary_buttons()
	title_label.text = tr(title).to_upper()
	for choice: Dictionary in choices:
		var button := Button.new()
		button.text = tr(str(choice.get("label", "Действие")))
		button.custom_minimum_size = Vector2(252, 46)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_copy_button_style(button)
		button.pressed.connect(_on_intent_pressed.bind(StringName(str(choice.get("id", "")))))
		buttons_container.add_child(button)
		temporary_buttons.append(button)
	var back_button := Button.new()
	back_button.text = "← %s" % tr("Назад")
	back_button.custom_minimum_size = Vector2(252, 42)
	_copy_button_style(back_button)
	back_button.pressed.connect(_show_ability_buttons)
	buttons_container.add_child(back_button)
	temporary_buttons.append(back_button)
	_resize_for_action_count(choices.size() + 1)
	position.y = clampf(position.y, 90.0, maxf(90.0, 690.0 - menu_height))
	_avoid_dialogue_overlap()


func _avoid_dialogue_overlap() -> void:
	var ancestor: Node = get_parent()
	while ancestor != null:
		if "repair_hud" in ancestor:
			var hud: Variant = ancestor.get("repair_hud")
			if hud != null and hud.employee_reaction_panel.is_visible_in_tree():
				var top: float = hud.employee_reaction_panel.get_global_rect().position.y
				if hud.dialogue_portrait_frame.is_visible_in_tree():
					top = minf(top, hud.dialogue_portrait_frame.get_global_rect().position.y)
				var bottom: float = get_global_rect().end.y
				if bottom > top - 12.0:
					position.y -= bottom - top + 12.0
			return
		ancestor = ancestor.get_parent()


func _resize_for_action_count(action_count: int) -> void:
	var visible_count: int = maxi(1, action_count)
	menu_height = 66.0 + visible_count * 53.0
	var desired_size := Vector2(280.0, menu_height)
	buttons_container.custom_minimum_size = Vector2(252.0, visible_count * 46.0 + maxi(0, visible_count - 1) * 10.0)
	custom_minimum_size = desired_size
	size = desired_size


func _on_button_pressed(button: Button) -> void:
	var tool_data: Array = TOOL_NAMES[button.name]
	current_tool_id = tool_data[0]
	if _show_state_refusal(current_tool_id):
		return
	if _is_boris() and current_tool_id == &"diagnose":
		var state: Node = get_node("/root/GameState")
		pending_inspection_object = current_object_name
		pending_inspection_log_size = state.get_job_repair_state(state.active_job_id).get("action_log", []).size()
	tool_selected.emit(current_tool_id)


func _is_boris() -> bool:
	var state: Node = get_node("/root/GameState")
	return configured_employee_name == str(state.employees[&"boris"]["name"]) or configured_employee_name == tr(str(state.employees[&"boris"]["name"]))


func _boris_action_allowed(action_id: StringName) -> bool:
	if action_id == &"diagnose":
		return true
	var ancestor: Node = get_parent()
	while ancestor != null:
		if "simulation" in ancestor:
			var sim: Variant = ancestor.get("simulation")
			if sim != null and "world_object" in sim and not preload("res://scripts/object_interaction_rules.gd").refusal_reason(action_id, sim.world_object).is_empty():
				return true
			if sim != null and sim.has_method("can_begin_action"):
				for method: Dictionary in sim.get_method_list():
					if str(method["name"]) == "can_begin_action":
						if (method["args"] as Array).size() > 1:
							var state: Node = get_node("/root/GameState")
							return bool(sim.call("can_begin_action", action_id, state.get_employee_with_equipment(&"boris")))
						return bool(sim.call("can_begin_action", action_id))
			return true
		ancestor = ancestor.get_parent()
	return true


func _record_completed_inspection() -> void:
	if pending_inspection_object.is_empty():
		return
	var state: Node = get_node("/root/GameState")
	var repair_state: Dictionary = state.get_job_repair_state(state.active_job_id)
	var entries: Array = repair_state.get("action_log", [])
	if entries.size() <= pending_inspection_log_size:
		return
	var entry: Dictionary = entries.back()
	if str(entry.get("employee_id", "")) != "boris" or str(entry.get("action_id", "")) != "diagnose" or not bool((entry.get("result", {}) as Dictionary).get("applied", false)):
		pending_inspection_object = ""
		return
	var inspected: Array = repair_state.get("boris_inspected_objects", []).duplicate()
	if not inspected.has(pending_inspection_object):
		inspected.append(pending_inspection_object)
	pending_inspection_object = ""
	repair_state["boris_inspected_objects"] = inspected
	state.job_repair_states[String(state.active_job_id)] = repair_state


func _on_intent_pressed(intent_id: StringName) -> void:
	visible = false
	intent_selected.emit(intent_id)


func _on_context_action_pressed(action_id: StringName) -> void:
	current_tool_id = action_id
	if _show_state_refusal(action_id):
		return
	tool_selected.emit(current_tool_id)


func _show_state_refusal(action_id: StringName) -> bool:
	var ancestor: Node = get_parent()
	while ancestor != null:
		if "simulation" in ancestor and "repair_hud" in ancestor:
			var sim: Variant = ancestor.get("simulation")
			if sim == null or not "world_object" in sim:
				return false
			var reason := preload("res://scripts/object_interaction_rules.gd").refusal_reason(action_id, sim.world_object)
			if reason.is_empty():
				return false
			var state: Node = get_node("/root/GameState")
			for employee_id: StringName in state.employees:
				if configured_employee_name == str(state.employees[employee_id]["name"]) or configured_employee_name == tr(str(state.employees[employee_id]["name"])):
					visible = false
					ancestor.repair_hud.show_employee_reaction(employee_id, preload("res://scripts/employee_reaction_resolver.gd").refusal_for(reason), true)
					return true
		ancestor = ancestor.get_parent()
	return false


func _show_ability_buttons() -> void:
	_clear_temporary_buttons()
	var visible_ability_count: int = 0
	for button in buttons:
		var tool_data: Array = TOOL_NAMES[button.name]
		button.text = tr(str(current_action_labels.get(tool_data[0], tool_data[1])))
		button.visible = available_buttons.has(button) and not hidden_action_ids.has(String(tool_data[0]))
		if button.visible:
			visible_ability_count += 1
	title_label.text = tr(current_object_name).to_upper()
	_resize_for_action_count(visible_ability_count)


func _clear_temporary_buttons() -> void:
	for button in temporary_buttons:
		if is_instance_valid(button):
			button.queue_free()
	temporary_buttons.clear()


func _add_contextual_actions(actions: Array) -> void:
	for action: Dictionary in actions:
		var button := Button.new()
		button.text = tr(str(action.get("label", "Действие")))
		button.custom_minimum_size = Vector2(252, 46)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_copy_button_style(button)
		button.pressed.connect(_on_context_action_pressed.bind(StringName(str(action.get("id", "")))))
		buttons_container.add_child(button)
		temporary_buttons.append(button)
	var visible_ability_count: int = 0
	for button in buttons:
		if button.visible:
			visible_ability_count += 1
	_resize_for_action_count(visible_ability_count + actions.size())


func _copy_button_style(target: Button) -> void:
	var source: Button = %DiagnoseButton
	for style_name: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus"]:
		var style: StyleBox = source.get_theme_stylebox(style_name)
		if style != null:
			target.add_theme_stylebox_override(style_name, style)
	target.add_theme_color_override("font_color", Color(0.941176, 0.827451, 0.623529, 1))
	target.add_theme_font_size_override("font_size", 15)
