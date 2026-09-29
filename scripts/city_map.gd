extends Control

signal back_requested
signal job_selected(job_id: StringName)

const COLOR_PANEL := Color(0.07, 0.045, 0.03, 0.94)
const COLOR_CARD := Color(0.13, 0.09, 0.055, 0.96)
const COLOR_CARD_HOVER := Color(0.21, 0.14, 0.075, 0.98)
const COLOR_SELECTED := Color(0.10, 0.16, 0.18, 0.98)
const COLOR_BRASS := Color(0.76, 0.54, 0.27)
const COLOR_GOLD := Color(0.96, 0.78, 0.46)
const COLOR_PARCHMENT := Color(0.92, 0.84, 0.69)
const COLOR_MUTED := Color(0.70, 0.63, 0.52)
var HOUSE_DEFINITIONS: Dictionary = {
	&"ragnar_eleonora": {
		"address": "Старый квартал, 5",
		"job_ids": PackedStringArray(["lava_leak", "walking_wardrobe", "generated_wardrobe_1"]),
	},
	&"selesta": {
		"address": "Верхний город, 12",
		"job_ids": PackedStringArray(["portal_mirror", "escaped_ghost"]),
	},
	&"tower_street": {
		"address": "Башенная улица, 8",
		"job_ids": PackedStringArray(["sleeping_gargoyle"]),
	},
}

@onready var game_state: Node = get_node("/root/GameState")
@onready var ragnar_marker: Button = $MapArea/HouseMarkers/RagnarAndEleonora
@onready var selesta_marker: Button = $MapArea/HouseMarkers/Selesta
@onready var gargoyle_marker: Button = $MapArea/HouseMarkers/GargoyleAttic
@onready var house_panel: Panel = $HousePanel
@onready var house_title: Label = $HousePanel/Title
@onready var house_summary: Label = $HousePanel/Summary
@onready var job_list: VBoxContainer = $HousePanel/JobScroll/JobList

var selected_house_id: StringName = &""


func _ready() -> void:
	$BackButton.pressed.connect(func() -> void: back_requested.emit())
	ragnar_marker.pressed.connect(_select_house.bind(&"ragnar_eleonora"))
	selesta_marker.pressed.connect(_select_house.bind(&"selesta"))
	gargoyle_marker.pressed.connect(_select_house.bind(&"tower_street"))
	if not game_state.state_changed.is_connected(refresh):
		game_state.state_changed.connect(refresh)
	_apply_styles()
	refresh()


func refresh() -> void:
	_refresh_marker(ragnar_marker, &"ragnar_eleonora")
	_refresh_marker(selesta_marker, &"selesta")
	_refresh_marker(gargoyle_marker, &"tower_street")
	if not selected_house_id.is_empty():
		_refresh_house_panel()


func _apply_styles() -> void:
	$Header.add_theme_stylebox_override("panel", _style(COLOR_PANEL, COLOR_BRASS, 2, 10))
	house_panel.add_theme_stylebox_override("panel", _style(COLOR_PANEL, COLOR_BRASS, 2, 10))
	$BackButton.add_theme_stylebox_override("normal", _style(COLOR_CARD, COLOR_BRASS, 2, 8))
	$BackButton.add_theme_stylebox_override("hover", _style(COLOR_CARD_HOVER, COLOR_GOLD, 2, 8))
	for marker: Button in [ragnar_marker, selesta_marker, gargoyle_marker]:
		marker.add_theme_stylebox_override("normal", _style(COLOR_CARD, COLOR_BRASS, 2, 8))
		marker.add_theme_stylebox_override("hover", _style(COLOR_CARD_HOVER, COLOR_GOLD, 3, 8))
		marker.add_theme_stylebox_override("pressed", _style(COLOR_SELECTED, COLOR_GOLD, 3, 8))
		marker.add_theme_color_override("font_color", COLOR_PARCHMENT)
		marker.add_theme_color_override("font_hover_color", Color.WHITE)
		marker.add_theme_font_size_override("font_size", 15)


func _select_house(house_id: StringName) -> void:
	selected_house_id = house_id
	house_panel.visible = true
	_refresh_house_panel()


func _refresh_marker(marker: Button, house_id: StringName) -> void:
	var definition: Dictionary = HOUSE_DEFINITIONS[house_id]
	var active_job_ids := _active_job_ids(definition)
	marker.visible = not active_job_ids.is_empty()
	if active_job_ids.is_empty():
		if selected_house_id == house_id:
			selected_house_id = &""
			house_panel.visible = false
		return
	var deadline := _nearest_deadline(active_job_ids)
	var status := _house_crew_status(active_job_ids)
	marker.text = tr("%s\nАктивных заявок: %d, %s\n%s") % [
		tr(str(definition["address"])), active_job_ids.size(), tr(deadline), tr(status),
	]


func _refresh_house_panel() -> void:
	if not HOUSE_DEFINITIONS.has(selected_house_id):
		house_panel.visible = false
		return
	var definition: Dictionary = HOUSE_DEFINITIONS[selected_house_id]
	var active_job_ids := _active_job_ids(definition)
	if active_job_ids.is_empty():
		selected_house_id = &""
		house_panel.visible = false
		return
	house_title.text = tr(str(definition["address"]))
	house_summary.text = tr("Доступных заявок: %d") % active_job_ids.size()
	_clear(job_list)
	for job_id_string: String in active_job_ids:
		var job_id := StringName(job_id_string)
		var job: Dictionary = game_state.jobs[job_id]
		var button := Button.new()
		button.custom_minimum_size = Vector2(350, 82)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 15)
		button.add_theme_color_override("font_color", COLOR_PARCHMENT)
		button.add_theme_color_override("font_disabled_color", COLOR_MUTED)
		button.add_theme_stylebox_override("normal", _style(COLOR_CARD, COLOR_BRASS, 2, 7))
		button.add_theme_stylebox_override("hover", _style(COLOR_CARD_HOVER, COLOR_GOLD, 2, 7))
		button.add_theme_stylebox_override("disabled", _style(Color(0.07, 0.055, 0.045, 0.90), Color(0.28, 0.24, 0.19), 1, 7))
		button.text = "%s\n%s, %s" % [tr(str(job["title"])), tr(_job_deadline(job)), tr(_job_crew_status(job_id))]
		button.pressed.connect(func() -> void: job_selected.emit(job_id))
		job_list.add_child(button)


func _active_job_ids(definition: Dictionary) -> PackedStringArray:
	var result := PackedStringArray()
	for job_id_string: String in definition["job_ids"]:
		if game_state.is_job_available(StringName(job_id_string)):
			result.append(job_id_string)
	return result


func _nearest_deadline(active_job_ids: PackedStringArray) -> String:
	if active_job_ids.is_empty():
		return "Сроков нет"
	var nearest_minutes := 2147483647
	var overdue := false
	for job_id_string: String in active_job_ids:
		var job: Dictionary = game_state.jobs[StringName(job_id_string)]
		if bool(job.get("overdue", false)):
			overdue = true
		nearest_minutes = mini(nearest_minutes, int(job.get("time_left", 0)))
	return tr("Срок истёк") if overdue else tr("Ближайший срок: %d мин") % nearest_minutes


func _house_crew_status(active_job_ids: PackedStringArray) -> String:
	if active_job_ids.is_empty():
		return "Все работы завершены"
	var best_status := "Бригада не назначена"
	for job_id_string: String in active_job_ids:
		var status := _job_crew_status(StringName(job_id_string))
		if status == "Работа выполняется":
			return status
		if status == "Сотрудники на объекте":
			best_status = status
		elif status == "Сотрудники в пути" and best_status == "Бригада не назначена":
			best_status = status
	return best_status


func _job_crew_status(job_id: StringName) -> String:
	var pending_action: Dictionary = game_state.get_pending_job_action(job_id)
	if not pending_action.is_empty() and int(pending_action.get("ends_at", 0)) > game_state.time_minutes:
		return "Работа выполняется"
	if game_state.has_employee_on_site(job_id):
		return "Сотрудники на объекте"
	if game_state.has_employees_in_transit(job_id):
		return "Сотрудники в пути"
	return "Бригада не назначена"


func _job_deadline(job: Dictionary) -> String:
	if bool(job.get("overdue", false)):
		return "срок истёк"
	return tr("осталось %d мин") % int(job.get("time_left", 0))


func _style(background: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
