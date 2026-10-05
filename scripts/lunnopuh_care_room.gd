extends Node2D

const CareSimulation := preload("res://scripts/lunnopuh_care_simulation.gd")
@onready var game_state: Node = get_node("/root/GameState")
@onready var mirror: Control = $MirrorPlacement
@onready var cage: Control = $LunnopuhTablePlacement/LunnopuhCagePlacement
@onready var pet: TextureRect = $LunnopuhTransfer
@onready var employee_actor: Control = $EmployeeActor
@onready var tool_bar: Control = $Interface/ToolBar
@onready var repair_hud: Control = $Interface/RepairHUD
var simulation: LunnopuhCareSimulation
var selected_employee_id: StringName = &""
var selected_target: StringName = &"lunnopuh"
var pending_dialogue_action: StringName = &""
var action_in_progress := false
var actor_finished := false
var effect_finished := false
var transfer_in_progress := false
var last_intro := ""
var cage_home: Vector2
var motion: Tween

func _ready() -> void:
	if game_state.active_job_id != &"lunnopuh_care":
		get_tree().change_scene_to_file("res://scenes/main.tscn")
		return
	cage_home = cage.position
	simulation = CareSimulation.new()
	simulation.initialize_from_job(game_state.jobs[game_state.active_job_id])
	var saved: Dictionary = game_state.get_job_repair_state(game_state.active_job_id)
	if not saved.is_empty():
		simulation.load_state(saved)
	mirror.selected.connect(_select_mirror)
	cage.selected.connect(_select_pet)
	tool_bar.tool_selected.connect(_on_tool_selected)
	tool_bar.intent_selected.connect(_on_tool_selected)
	repair_hud.employee_selected.connect(_select_employee)
	repair_hud.dialogue_finished.connect(_on_dialogue_finished)
	repair_hud.completion_requested.connect(_complete)
	repair_hud.long_action_started.connect(func(_id: StringName) -> void: employee_actor.set_persistent_work_pose(true))
	repair_hud.long_action_finished.connect(func(_id: StringName) -> void: employee_actor.set_persistent_work_pose(false))
	employee_actor.action_impact.connect(_on_impact)
	employee_actor.action_finished.connect(_on_actor_finished)
	selected_employee_id = repair_hud.get_selected_employee_id()
	_configure_actor()
	_apply_visual_state()
	var timed: Dictionary = game_state.get_pending_job_action(game_state.active_job_id)
	var pending := simulation.pending_actor_action
	if not timed.is_empty():
		selected_employee_id = StringName(str(timed["employee_id"]))
		selected_target = StringName(str(pending.get("target_id", "lunnopuh")))
		_configure_actor()
		action_in_progress = true
		actor_finished = true
		repair_hud.resume_timed_action(_resolve.bind(StringName(str(timed["action_id"]))))
	elif not pending.is_empty():
		selected_employee_id = StringName(str(pending["employee_id"]))
		selected_target = StringName(str(pending["target_id"]))
		_configure_actor()
		_begin_action(StringName(str(pending["action_id"])))
	elif not bool(simulation.world_object["resident_intro_seen"]):
		simulation.world_object["resident_intro_seen"] = true
		_save()
		repair_hud.show_resident_dialogue(simulation.get_resident_request())

func _save() -> void:
	game_state.set_job_repair_state(game_state.active_job_id, simulation.get_state())
	game_state.save_autosave()

func _configure_actor() -> void:
	if selected_employee_id.is_empty() or not game_state.employees.has(selected_employee_id) or not game_state.can_employee_work_on_job(selected_employee_id, game_state.active_job_id):
		employee_actor.hide()
		return
	employee_actor.visible = employee_actor.configure_employee(selected_employee_id, game_state.employees[selected_employee_id])
	employee_actor.set_horizontal_flip(true)

func _select_employee(employee_id: StringName) -> void:
	if action_in_progress or not pending_dialogue_action.is_empty():
		return
	selected_employee_id = employee_id
	tool_bar.hide()
	_configure_actor()

func _select_pet() -> void:
	_show_actions(&"lunnopuh")

func _select_mirror() -> void:
	_show_actions(&"mirror")

func _show_actions(target: StringName) -> void:
	if action_in_progress or not pending_dialogue_action.is_empty() or selected_employee_id.is_empty():
		return
	selected_target = target
	simulation.interaction_target = &"lunnopuh" if target == &"lunnopuh" else &"portal_mirror"
	var employee: Dictionary = game_state.employees[selected_employee_id]
	var allowed := simulation.lunnopuh_actions(selected_employee_id) if target == &"lunnopuh" else simulation.available_actions(selected_employee_id)
	var hidden := PackedStringArray()
	for action: String in ["diagnose", "repair", "physical_move", "telekinesis", "antimagic", "freeze", "heat", "animate"]:
		if not allowed.has(action) or (target == &"mirror" and action in ["repair", "animate"]):
			hidden.append(action)
	var custom: Array[Dictionary] = []
	for action: String in ["transport_lunnopuh", "cover", "uncover"]:
		if allowed.has(action):
			custom.append({"id": StringName(action), "label": "Отвезти в приют" if action == "transport_lunnopuh" else "Снять полотно" if action == "uncover" else "Закрыть защитным полотном"})
	tool_bar.configure_for_employee(str(employee["name"]), employee["abilities"], str(employee["core_actions"]))
	tool_bar.show_for_object("Лунопух" if target == &"lunnopuh" else "Зеркало", cage.target_global_position() if target == &"lunnopuh" else mirror.target_global_position(), {&"diagnose": "Осмотреть", &"physical_move": "Разбить зеркало", &"antimagic": "Применить антимагию" if target == &"lunnopuh" else "Закрыть портал"}, custom, hidden)

func _on_tool_selected(action_id: StringName) -> void:
	if action_in_progress or not pending_dialogue_action.is_empty() or repair_hud.is_timed_action_active():
		return
	if not game_state.can_employee_work_on_job(selected_employee_id, game_state.active_job_id):
		return
	var allowed := simulation.lunnopuh_actions(selected_employee_id) if selected_target == &"lunnopuh" else simulation.available_actions(selected_employee_id)
	if not allowed.has(String(action_id)):
		return
	if selected_target == &"lunnopuh" and action_id == &"telekinesis":
		if allowed.has("return_lunnopuh"):
			tool_bar.show_intents("Телекинез", [{"id": &"return_lunnopuh", "label": "Вернуть домой"}])
		else:
			tool_bar.hide()
			repair_hud.show_system_message("Для возвращения Лунопуха нужен открытый портал без полотна." if bool(simulation.world_object["portal_open"]) else "Портал закрыт. Вернуть Лунопуха этим путём нельзя.", true)
		return
	tool_bar.hide()
	var refusal := simulation.lunnopuh_refusal(action_id) if selected_target == &"lunnopuh" else simulation.refusal_message(action_id, game_state.has_supply_item(&"protective_cloth"))
	last_intro = refusal if not refusal.is_empty() else simulation.care_reaction(selected_employee_id, action_id) if selected_target == &"lunnopuh" else simulation.get_employee_reaction(selected_employee_id, action_id, game_state.has_supply_item(&"protective_cloth"))
	if not refusal.is_empty():
		repair_hud.show_employee_reaction(selected_employee_id, last_intro)
		return
	if not last_intro.is_empty() and repair_hud.show_employee_reaction(selected_employee_id, last_intro):
		pending_dialogue_action = action_id
		return
	_begin_action(action_id)

func _on_dialogue_finished() -> void:
	if pending_dialogue_action.is_empty():
		return
	var action := pending_dialogue_action
	pending_dialogue_action = &""
	_begin_action(action)

func _begin_action(action_id: StringName) -> void:
	actor_finished = false
	effect_finished = false
	action_in_progress = true
	simulation.pending_actor_action = {"employee_id": String(selected_employee_id), "target_id": String(selected_target), "action_id": String(action_id)}
	_save()
	tool_bar.hide()
	mirror.set_interaction_enabled(false)
	cage.get_node("InteractionButton").disabled = true
	var physical: bool = game_state.employees[selected_employee_id].get("actor_action_style", &"magic") == &"physical"
	var approach: Vector2 = $PetApproach.position if selected_target == &"lunnopuh" else $MirrorPhysicalApproach.position
	if action_id == &"return_lunnopuh":
		employee_actor.set_persistent_work_pose(true)
	employee_actor.play_action(action_id, cage.target_global_position() if selected_target == &"lunnopuh" else mirror.target_global_position(), approach if physical else Vector2.INF, &"catch" if action_id == &"transport_lunnopuh" else &"work")

func _on_impact(action_id: StringName) -> void:
	if action_id == &"return_lunnopuh":
		_return_pet()
	elif action_id == &"transport_lunnopuh":
		_transport_pet()
	elif game_state.employees[selected_employee_id].get("actor_action_style", &"magic") == &"physical":
		repair_hud.start_timed_action(selected_employee_id, action_id, _resolve.bind(action_id))
		_save()
	else:
		_resolve(action_id)

func _return_pet() -> void:
	transfer_in_progress = true
	simulation.pending_actor_action["phase"] = "transfer"
	_save()
	cage.show_state(&"installed")
	pet.position = to_local(cage.target_global_position()) - pet.size * 0.5
	pet.modulate.a = 1.0
	pet.show()
	motion = create_tween()
	motion.tween_property(pet, "position", pet.position + Vector2(0, -65), 0.35)
	motion.tween_property(pet, "position", to_local(mirror.target_global_position()) - pet.size * 0.5, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	motion.tween_property(pet, "modulate:a", 0.0, 0.3)
	await motion.finished
	employee_actor.set_persistent_work_pose(false)
	transfer_in_progress = false
	_resolve(&"return_lunnopuh")

func _transport_pet() -> void:
	transfer_in_progress = true
	simulation.pending_actor_action["phase"] = "transport"
	_save()
	await employee_actor.action_finished
	employee_actor.hide()
	cage.hide()
	simulation.world_object["transport_employee_id"] = String(selected_employee_id)
	transfer_in_progress = false
	_resolve(&"transport_lunnopuh")
	game_state.begin_employee_delivery(selected_employee_id)


func _on_actor_finished() -> void:
	actor_finished = true
	_finish_if_ready()

func _resolve(action_id: StringName) -> void:
	var result := simulation.apply_lunnopuh_action(selected_employee_id, action_id) if selected_target == &"lunnopuh" else simulation.apply_action(selected_employee_id, action_id, game_state.has_supply_item(&"protective_cloth"))
	if bool(result["applied"]) and selected_target == &"mirror":
		if action_id == &"uncover":
			game_state.return_supply_item(&"protective_cloth")
		elif action_id == &"cover":
			game_state.consume_supply_item(&"protective_cloth")
	simulation.pending_actor_action = {}
	effect_finished = true
	_save()
	_apply_visual_state()
	if str(result["message"]) != last_intro:
		if action_id == &"diagnose":
			repair_hud.show_dialogue("Результат осмотра", str(result["message"]))
		else:
			repair_hud.show_system_message(str(result["message"]), bool(result["warning"]))
	_finish_if_ready()

func _finish_if_ready() -> void:
	if actor_finished and effect_finished and not transfer_in_progress:
		action_in_progress = false
		mirror.set_interaction_enabled(true)
		cage.get_node("InteractionButton").disabled = false

func _apply_visual_state() -> void:
	mirror.show_state(simulation.visual_state())
	$GhostPlacement.hide()
	var caged := str(simulation.world_object["lunnopuh_state"]) == "caged"
	cage.position = cage_home
	cage.show_state(&"occupied" if caged else &"installed" if str(simulation.world_object["lunnopuh_state"]) == "returned" else &"packed")
	$LunnopuhTablePlacement.show()
	pet.hide()
	var trap: Dictionary = (game_state.world_memory.objects.get("portal_mirror_room.ghost_trap", {}) as Dictionary).get("properties", {})
	$TrapPlacement/Empty.hide()
	$TrapPlacement/Occupied.visible = str(trap.get("state", "packed")) == "occupied"
	repair_hud.set_completion_ready(simulation.is_resolved())

func _complete() -> void:
	if action_in_progress or not pending_dialogue_action.is_empty() or repair_hud.is_timed_action_active():
		return
	if not simulation.is_resolved():
		repair_hud.show_system_message("Сначала помогите Лунопуху и закройте или изолируйте открытый портал.", true)
		return
	if game_state.complete_active_job(simulation.get_completion_result()):
		get_tree().change_scene_to_file("res://scenes/main.tscn")
