extends Node2D

const COLOR_PANEL := Color(0.07, 0.045, 0.03, 0.94)
const COLOR_GOLD := Color(0.96, 0.78, 0.46)
const COLOR_PARCHMENT := Color(0.92, 0.84, 0.69)

@onready var overview_background: TextureRect = $Background
@onready var bathroom_preview_backdrop: ColorRect = $BathroomPreviewBackdrop
@onready var bathroom_preview: TextureRect = $BathroomPreview
@onready var closeup_background: TextureRect = $BathroomCloseup
@onready var bathroom_hotspot: Button = $BathroomHotspot
@onready var lava_faucet: Control = $InteractiveObjects/LavaFaucet
@onready var back_to_house_button: Button = $Interface/BackToHouseButton
@onready var tool_bar: Control = $Interface/ToolBar
@onready var repair_hud: Control = $Interface/RepairHUD


func _ready() -> void:
	_configure_buttons()
	bathroom_hotspot.pressed.connect(_open_bathroom)
	back_to_house_button.pressed.connect(_show_house_overview)
	_show_house_overview(false)


func _open_bathroom() -> void:
	bathroom_hotspot.disabled = true
	closeup_background.visible = true
	closeup_background.modulate = Color(1, 1, 1, 0)
	closeup_background.pivot_offset = closeup_background.size * 0.5
	closeup_background.scale = Vector2(1.025, 1.025)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(closeup_background, "modulate", Color.WHITE, 0.32)
	tween.tween_property(closeup_background, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	overview_background.visible = false
	bathroom_preview_backdrop.visible = false
	bathroom_preview.visible = false
	lava_faucet.visible = true
	back_to_house_button.visible = true
	tool_bar.visible = true
	if repair_hud.has_method("set_work_ui_visible"):
		repair_hud.call("set_work_ui_visible", true)


func _show_house_overview(animated: bool = true) -> void:
	overview_background.visible = true
	bathroom_preview_backdrop.visible = true
	bathroom_preview.visible = true
	bathroom_hotspot.disabled = false
	lava_faucet.visible = false
	back_to_house_button.visible = false
	tool_bar.visible = false
	if repair_hud.has_method("set_work_ui_visible"):
		repair_hud.call("set_work_ui_visible", false)
	if not animated:
		closeup_background.visible = false
		return
	var tween := create_tween()
	tween.tween_property(closeup_background, "modulate", Color(1, 1, 1, 0), 0.24)
	await tween.finished
	closeup_background.visible = false
	closeup_background.modulate = Color.WHITE


func _configure_buttons() -> void:
	var empty_style := StyleBoxEmpty.new()
	bathroom_hotspot.add_theme_stylebox_override("normal", empty_style)
	bathroom_hotspot.add_theme_stylebox_override("pressed", empty_style)
	bathroom_hotspot.add_theme_stylebox_override("focus", empty_style)
	var room_hover := StyleBoxFlat.new()
	room_hover.bg_color = Color(1.0, 0.42, 0.08, 0.08)
	room_hover.border_color = Color(1.0, 0.68, 0.24, 0.88)
	room_hover.set_border_width_all(3)
	room_hover.set_corner_radius_all(12)
	bathroom_hotspot.add_theme_stylebox_override("hover", room_hover)

	back_to_house_button.add_theme_font_size_override("font_size", 17)
	back_to_house_button.add_theme_color_override("font_color", COLOR_PARCHMENT)
	back_to_house_button.add_theme_stylebox_override("normal", _button_style(COLOR_PANEL, Color(0.76, 0.54, 0.27), 2))
	back_to_house_button.add_theme_stylebox_override("hover", _button_style(Color(0.21, 0.14, 0.075, 0.98), COLOR_GOLD, 3))


func _button_style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(8)
	return style
