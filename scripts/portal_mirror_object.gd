extends Control

signal selected

@onready var open_pose: TextureRect = $Open
@onready var heat_damaged_pose: TextureRect = $HeatDamaged
@onready var closed_pose: TextureRect = $Closed
@onready var destroyed_pose: TextureRect = $Destroyed
@onready var covered_pose: TextureRect = $Covered
@onready var frost_aura: TextureRect = $FrostAura
@onready var interaction_button: Button = $InteractionButton
@onready var target_marker: Marker2D = $Target


func _ready() -> void:
	interaction_button.pressed.connect(func() -> void: selected.emit())
	var empty_style := StyleBoxEmpty.new()
	for state: StringName in [&"normal", &"pressed", &"focus", &"hover", &"hover_pressed", &"disabled"]:
		interaction_button.add_theme_stylebox_override(state, empty_style)


func show_state(state: StringName, cold_aura_visible: bool = true) -> void:
	open_pose.visible = state == &"open"
	heat_damaged_pose.visible = state == &"heat_damaged"
	closed_pose.visible = state == &"closed"
	destroyed_pose.visible = state == &"destroyed"
	covered_pose.visible = state == &"covered"
	frost_aura.visible = cold_aura_visible and state not in [&"closed", &"destroyed"]
	interaction_button.visible = true


func set_interaction_enabled(enabled: bool) -> void:
	interaction_button.disabled = not enabled


func target_global_position() -> Vector2:
	return target_marker.global_position
