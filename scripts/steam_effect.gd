extends Node2D

@export_range(1, 6, 1) var wisp_count: int = 3
@export_range(20.0, 160.0, 1.0) var rise_height: float = 78.0
@export_range(0.1, 1.5, 0.05) var rise_speed: float = 0.42
@export_range(1.0, 30.0, 1.0) var sway_width: float = 11.0
@export_range(0.01, 0.5, 0.01) var maximum_opacity: float = 0.16

var animation_time: float = 0.0


func _process(delta: float) -> void:
	animation_time += delta
	queue_redraw()


func _draw() -> void:
	for index in wisp_count:
		var base_offset := (float(index) - float(wisp_count - 1) * 0.5) * 7.0
		var phase := animation_time * rise_speed * 4.0 + float(index) * 2.1
		var previous_point := Vector2(base_offset, 0.0)
		var segment_count := 22
		for segment in range(1, segment_count + 1):
			var progress := float(segment) / float(segment_count)
			var sway := sin(phase + progress * 5.2) * sway_width * (0.25 + progress * 0.75)
			var point := Vector2(base_offset + sway, -progress * rise_height)
			var fade := sin(progress * PI)
			var pulse := 0.82 + sin(animation_time * 1.1 + float(index) * 1.7) * 0.18
			var color := Color(0.91, 0.90, 0.86, maximum_opacity * fade * pulse)
			draw_line(previous_point, point, Color(color, color.a * 0.34), 6.0, true)
			draw_line(previous_point, point, color, lerpf(2.6, 1.0, progress), true)
			previous_point = point
