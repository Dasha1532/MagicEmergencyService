extends Control

signal selected

@onready var dormant_pose: TextureRect = $Dormant
@onready var dormant_clean_pose: TextureRect = $DormantClean
@onready var awakened_pose: TextureRect = $Awakened
@onready var damaged_pose: TextureRect = $Damaged
@onready var damaged_clean_pose: TextureRect = $DamagedClean
@onready var frozen_pose: TextureRect = $Frozen
@onready var interaction_button: Button = $InteractionButton
@onready var target_marker: Marker2D = $Target


func _ready() -> void:
	interaction_button.pressed.connect(func() -> void: selected.emit())
	var empty_style := StyleBoxEmpty.new()
	for state: StringName in [&"normal", &"pressed", &"focus", &"hover", &"hover_pressed", &"disabled"]:
		interaction_button.add_theme_stylebox_override(state, empty_style)


func show_state(state: StringName) -> void:
	dormant_pose.visible = state == &"dormant"
	dormant_clean_pose.visible = state == &"dormant_clean"
	awakened_pose.visible = state == &"awakened"
	damaged_pose.visible = state == &"damaged"
	damaged_clean_pose.visible = state == &"damaged_clean"
	frozen_pose.visible = state == &"frozen"
	interaction_button.visible = true


func set_interaction_enabled(enabled: bool) -> void:
	interaction_button.disabled = not enabled


func target_global_position() -> Vector2:
	return target_marker.global_position
