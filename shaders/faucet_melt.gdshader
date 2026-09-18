shader_type canvas_item;

uniform float heat : hint_range(0.0, 1.0) = 0.0;
uniform float melt : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 source_uv = UV;
	// Маска охватывает только изогнутый излив и его наконечник. Плавные
	// границы не дают шву появиться на корпусе крана.
	float spout_left = smoothstep(0.60, 0.72, UV.x);
	float spout_right = 1.0 - smoothstep(0.94, 0.995, UV.x);
	float spout_lower = smoothstep(0.43, 0.62, UV.y);
	float spout_mask = spout_left * spout_right * spout_lower;
	float deformation = spout_mask * melt;

	// Нижняя часть берёт цвет всё выше исходной точки, поэтому металл
	// действительно вытягивается вниз. Одновременно наконечник загибается
	// к центру, что делает изменение силуэта заметным даже в масштабе комнаты.
	float vertical_pull = smoothstep(0.48, 0.98, UV.y);
	source_uv.y -= deformation * vertical_pull * 0.34;
	source_uv.x += deformation * vertical_pull * 0.075;
	source_uv = clamp(source_uv, vec2(0.0), vec2(1.0));

	vec4 sampled = texture(TEXTURE, source_uv);
	vec3 hot_tint = vec3(1.0, 0.16, 0.035);
	float metal_glow = heat * smoothstep(0.08, 0.85, sampled.a);
	sampled.rgb = mix(sampled.rgb, sampled.rgb * 0.42 + hot_tint * 0.82, metal_glow * 0.78);
	COLOR = sampled * COLOR;
}
