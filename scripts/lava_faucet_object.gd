extends Control

signal selected

@onready var normal_faucet: TextureRect = $NormalFaucet
@onready var damaged_faucet: TextureRect = $DamagedFaucet
@onready var frozen_faucet: TextureRect = $FrozenFaucet
@onready var broken_faucet: TextureRect = $BrokenFaucet
@onready var melted_faucet: TextureRect = $MeltedFaucet
@onready var regulated_faucet: TextureRect = $RegulatedFaucet
@onready var lava_stream: TextureRect = $LavaStream
@onready var water_stream: TextureRect = $WaterStream
@onready var hit_area: Button = $HitArea
@onready var overheat_damage: Node2D = $OverheatDamage


func _ready() -> void:
	hit_area.pressed.connect(func() -> void: selected.emit())
	_configure_hit_area()
	_start_lava_motion()
	_start_water_motion()


func show_emergency_state(show_lava: bool = true) -> void:
	_show_base(&"damaged")
	lava_stream.visible = show_lava
	water_stream.visible = false
	_set_melt_parameters(0.0, 0.0)
	modulate = Color.WHITE


func show_repaired_state() -> void:
	_show_base(&"normal")
	normal_faucet.modulate = Color.WHITE
	lava_stream.visible = false
	water_stream.visible = false
	modulate = Color.WHITE
	_set_melt_parameters(0.0, 0.0)


func show_overheated_state(show_lava: bool) -> void:
	# Перегрев меняет цвет исправного корпуса, но не показывает деформацию.
	# Деформированный PNG и плавление появляются только после реального ущерба.
	_show_base(&"normal")
	normal_faucet.modulate = Color(1.0, 0.34, 0.14, 1.0)
	lava_stream.visible = show_lava
	water_stream.visible = false
	modulate = Color.WHITE
	_set_melt_parameters(0.0, 0.0)
	overheat_damage.visible = false


func show_melted_state(show_lava: bool) -> void:
	_show_base(&"melted")
	lava_stream.visible = show_lava
	water_stream.visible = false
	modulate = Color.WHITE
	_set_melt_parameters(1.0, 1.0)
	overheat_damage.visible = false


func sync_from_state(object_state: Dictionary) -> void:
	var tags := PackedStringArray(object_state.get("tags", PackedStringArray()))
	var show_lava := preload("res://scripts/object_flow_rules.gd").is_flowing(object_state, "lava")
	var show_water := preload("res://scripts/object_flow_rules.gd").is_flowing(object_state, "water")
	if tags.has("melted") or StringName(str(object_state.get("visual_state", ""))) == &"melted":
		show_melted_state(show_lava)
	elif bool(object_state.get("broken", false)) or tags.has("broken"):
		_show_base(&"broken")
	elif bool(object_state.get("frozen", false)):
		_show_base(&"frozen")
	elif bool(object_state.get("thermal_regulator_installed", false)) or bool(object_state.get("regulator_installed", false)):
		_show_base(&"regulated")
	elif tags.has("overheated") or int(object_state.get("temperature", 0)) >= 10:
		show_overheated_state(show_lava)
	elif int(object_state.get("damage", 0)) > 0:
		show_emergency_state(show_lava)
	else:
		show_repaired_state()
	lava_stream.visible = show_lava
	water_stream.visible = show_water


func _show_base(state: StringName) -> void:
	normal_faucet.modulate = Color.WHITE
	normal_faucet.visible = state == &"normal"
	damaged_faucet.visible = state == &"damaged"
	frozen_faucet.visible = state == &"frozen"
	broken_faucet.visible = state == &"broken"
	melted_faucet.visible = state == &"melted"
	regulated_faucet.visible = state == &"regulated"
	modulate = Color.WHITE
	if state != &"damaged":
		_set_melt_parameters(0.0, 0.0)


func set_damage_visible(_is_visible: bool) -> void:
	# Старый процедурный отблеск и пятно отключены: ущерб показывает PNG копоти.
	overheat_damage.visible = false


func set_interaction_enabled(is_enabled: bool) -> void:
	hit_area.disabled = not is_enabled


func _configure_hit_area() -> void:
	var empty_style := StyleBoxEmpty.new()
	hit_area.add_theme_stylebox_override("normal", empty_style)
	hit_area.add_theme_stylebox_override("hover", empty_style)
	hit_area.add_theme_stylebox_override("pressed", empty_style)
	hit_area.add_theme_stylebox_override("focus", empty_style)
	hit_area.add_theme_stylebox_override("disabled", empty_style)


func _start_lava_motion() -> void:
	lava_stream.pivot_offset = lava_stream.size * 0.5
	var base_position := lava_stream.position
	var tween := create_tween().set_loops()
	tween.tween_property(lava_stream, "modulate", Color(1.0, 0.80, 0.58, 0.92), 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(lava_stream, "position", base_position + Vector2(0, 4), 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(lava_stream, "modulate", Color.WHITE, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(lava_stream, "position", base_position, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _start_water_motion() -> void:
	water_stream.pivot_offset = water_stream.size * 0.5
	var base_position := water_stream.position
	var tween := create_tween().set_loops()
	tween.tween_property(water_stream, "modulate", Color(0.86, 0.95, 1.0, 0.9), 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(water_stream, "position", base_position + Vector2(0, 3), 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(water_stream, "modulate", Color.WHITE, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(water_stream, "position", base_position, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _set_melt_parameters(heat: float, melt: float) -> void:
	var shader_material: ShaderMaterial = damaged_faucet.material as ShaderMaterial
	if shader_material == null:
		return
	shader_material.set_shader_parameter("heat", heat)
	shader_material.set_shader_parameter("melt", melt)
