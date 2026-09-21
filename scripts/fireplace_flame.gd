extends Node2D

@export var pulse_strength: float = 0.08
@export var pulse_speed: float = 2.2

var elapsed: float = 0.0


func _process(delta: float) -> void:
	elapsed += delta
	var glow := $Glow as Polygon2D
	var pulse: float = sin(elapsed * pulse_speed) * pulse_strength
	glow.scale = Vector2.ONE * (1.0 + pulse)
	glow.modulate.a = 0.55 + pulse
