shader_type canvas_item;

uniform float shine_position = -0.35;
uniform float shine_width : hint_range(0.03, 0.25) = 0.105;
uniform float shine_strength : hint_range(0.0, 1.0) = 0.68;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float diagonal_position = UV.x + UV.y * 0.16;
	float distance_to_shine = abs(diagonal_position - shine_position);
	float narrow_highlight = 1.0 - smoothstep(0.0, shine_width, distance_to_shine);
	float soft_reflection = 1.0 - smoothstep(shine_width, shine_width * 3.2, distance_to_shine);
	float metal_luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	float metal_mask = smoothstep(0.06, 0.42, metal_luminance) * source.a;
	vec3 warm_light = vec3(1.0, 0.82, 0.48) * soft_reflection * 0.20;
	vec3 white_glint = vec3(1.0, 0.97, 0.86) * narrow_highlight * shine_strength;
	vec3 lit_color = source.rgb + (warm_light + white_glint) * metal_mask;
	COLOR = vec4(lit_color, source.a);
}
