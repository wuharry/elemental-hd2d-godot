shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;

instance uniform vec4 primary_color : source_color = vec4(1.0, 0.45, 0.18, 1.0);
instance uniform vec4 accent_color : source_color = vec4(1.0, 0.85, 0.35, 1.0);
instance uniform float effect_time = 0.0;
instance uniform float fade_alpha = 1.0;
instance uniform float pulse_speed = 2.0;

varying vec2 local_xy;

void vertex() {
	local_xy = UV * 2.0 - 1.0;
}

void fragment() {
	// 32 px/m pixel-quantized magic barrier seal on the ground beneath the player.
	vec2 q = (floor(local_xy * 26.0) + 0.5) / 26.0;
	float r = length(q);
	if (r > 0.98) {
		discard;
	}
	float a = atan(q.y, q.x);
	float t = effect_time;

	// Outer double rune circle + rotating 8-point arcane ticks.
	float outer_ring = 1.0 - smoothstep(0.015, 0.065, abs(r - 0.88));
	float inner_ring = 1.0 - smoothstep(0.012, 0.050, abs(r - 0.66));
	float rune_ticks = step(0.55, sin(a * 8.0 + t * 1.6)) * (1.0 - smoothstep(0.02, 0.11, abs(r - 0.77)));

	// Rotating geometric octagram star woven inside the circle.
	float sa1 = mod(a + t * 0.55, 1.5707963) - 0.78539816;
	float sa2 = mod(a - t * 0.42 + 0.78539816, 1.5707963) - 0.78539816;
	float poly1 = abs(r * cos(sa1) - 0.56);
	float poly2 = abs(r * cos(sa2) - 0.56);
	float star = 1.0 - smoothstep(0.014, 0.048, min(poly1, poly2));
	star *= step(r, 0.84);

	float wash = (1.0 - smoothstep(0.18, 0.90, r)) * (0.20 + 0.08 * sin(r * 14.0 - t * 4.5));
	float grad = clamp(0.5 + 0.5 * sin(a * 2.0 - t * 1.2), 0.0, 1.0);
	vec3 col = mix(primary_color.rgb, accent_color.rgb, grad);

	float lines = clamp(outer_ring * 1.0 + inner_ring * 0.75 + rune_ticks * 0.9 + star * 0.65, 0.0, 1.0);
	float pulse = 0.82 + 0.18 * sin(t * pulse_speed);
	ALBEDO = mix(col * 1.5, mix(col, vec3(1.0), 0.35) * 3.1, lines) * pulse;
	ALPHA = clamp((wash + lines * 0.88) * fade_alpha, 0.0, 0.95);
}
