extends Control

signal selected

@onready var normal_faucet: TextureRect = $NormalFaucet
@onready var damaged_faucet: TextureRect = $DamagedFaucet
@onready var lava_stream: TextureRect = $LavaStream
@onready var hit_area: Button = $HitArea


func _ready() -> void:
	hit_area.pressed.connect(func() -> void: selected.emit())
	_configure_hit_area()
	_start_lava_motion()


func show_emergency_state() -> void:
	normal_faucet.visible = false
	damaged_faucet.visible = true
	lava_stream.visible = true


func show_repaired_state() -> void:
	normal_faucet.visible = true
	damaged_faucet.visible = false
	lava_stream.visible = false
	modulate = Color.WHITE


func show_overheated_state() -> void:
	normal_faucet.visible = false
	damaged_faucet.visible = true
	lava_stream.visible = true
	modulate = Color(1.22, 0.72, 0.52, 1.0)


func _configure_hit_area() -> void:
	var empty_style := StyleBoxEmpty.new()
	hit_area.add_theme_stylebox_override("normal", empty_style)
	hit_area.add_theme_stylebox_override("hover", empty_style)
	hit_area.add_theme_stylebox_override("pressed", empty_style)
	hit_area.add_theme_stylebox_override("focus", empty_style)


func _start_lava_motion() -> void:
	lava_stream.pivot_offset = lava_stream.size * 0.5
	var base_position := lava_stream.position
	var tween := create_tween().set_loops()
	tween.tween_property(lava_stream, "modulate", Color(1.0, 0.80, 0.58, 0.92), 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(lava_stream, "position", base_position + Vector2(0, 4), 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(lava_stream, "modulate", Color.WHITE, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(lava_stream, "position", base_position, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
