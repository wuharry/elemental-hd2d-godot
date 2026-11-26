shader_type spatial;
render_mode blend_mix, cull_disabled, shadows_disabled, depth_draw_never;

void fragment() {
	// Layered billowing pixel-quantized mist cloud (no flat oval card look).
	vec2 p = (floor(UV * 36.0) + 0.5) / 36.0;
	vec2 centered = (p - 0.5) * vec2(1.05, 1.55);
	float billow1 = sin(p.x * 14.0 + TIME * 0.85) * cos(p.y * 11.0 - TIME * 0.55);
	float billow2 = sin((p.x - p.y) * 20.0 + TIME * 1.15);
	float cloud_r = length(centered) - 0.09 * billow1 - 0.04 * billow2;
	float fringe = 1.0 - smoothstep(0.16, 0.48, cloud_r);
	float density = 0.72 + 0.28 * (0.5 + 0.5 * billow1);
	vec3 mist_tint = mix(vec3(0.58, 0.76, 0.88), vec3(0.84, 0.94, 0.99), smoothstep(0.32, 0.08, cloud_r));
	ALBEDO = mist_tint;
	EMISSION = mist_tint * 0.22;
	ROUGHNESS = 1.0;
	ALPHA = clamp(fringe * density * 0.44, 0.0, 0.58);
}
