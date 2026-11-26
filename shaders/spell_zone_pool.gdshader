shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;

instance uniform vec4 primary_color : source_color = vec4(0.95, 0.45, 0.15, 1.0);
instance uniform vec4 accent_color : source_color = vec4(1.0, 0.85, 0.25, 1.0);
instance uniform float effect_time = 0.0;
instance uniform float fade_alpha = 1.0;
instance uniform float style_id = 0.0;

varying vec2 local_xy;

void vertex() {
	local_xy = UV * 2.0 - 1.0;
}

void fragment() {
	vec2 q = (floor(local_xy * 28.0) + 0.5) / 28.0;
	float r = length(q);
	float a = atan(q.y, q.x);
	float t = effect_time;

	// Wobbly organic boundary for pools, crisp rune boundary for rings/fields.
	float wobble = (style_id < 2.5) ? (0.07 * sin(a * 5.0 + t * 1.8) + 0.04 * cos(a * 8.0 - t * 2.3)) : 0.0;
	float limit = 0.90 + wobble;
	if (r > limit) {
		discard;
	}

	float rn = r / max(limit, 0.01);
	float detail = 0.0;
	float alpha_base = 0.0;
	if (style_id < 0.5) {
		// Lava pool: glowing magma crust + bright molten veins
		float crust = sin(q.x * 13.0 + t * 1.2) * cos(q.y * 13.0 - t * 0.9) + 0.5 * sin(r * 16.0 - t * 2.6);
		detail = smoothstep(0.15, 0.85, 0.5 + 0.5 * crust);
		alpha_base = (1.0 - smoothstep(0.75, 1.0, rn)) * 0.88;
	} else if (style_id < 1.5) {
		// Poison puddle: seething bubbling toxic rings
		float bubbles = sin(q.x * 18.0 + t * 2.5) * sin(q.y * 18.0 - t * 2.2);
		float ring = 1.0 - smoothstep(0.02, 0.08, abs(rn - fract(t * 0.55)));
		detail = clamp(smoothstep(0.45, 0.95, 0.5 + 0.5 * bubbles) + ring * 0.7, 0.0, 1.0);
		alpha_base = (1.0 - smoothstep(0.72, 1.0, rn)) * 0.78;
	} else if (style_id < 2.5) {
		// Fire patch: blazing ground flame carpet
		float licks = 0.5 + 0.5 * sin(r * 18.0 - t * 8.5 + sin(a * 5.0 + t * 3.0));
		detail = smoothstep(0.25, 0.92, licks);
		alpha_base = (1.0 - smoothstep(0.68, 1.0, rn)) * 0.82;
	} else {
		// Superconduct / Magnetism / Healing shockwave rune circle
		float outer = 1.0 - smoothstep(0.02, 0.09, abs(rn - 0.88));
		float mid = 1.0 - smoothstep(0.02, 0.07, abs(rn - 0.56));
		float pulse_wave = 1.0 - smoothstep(0.02, 0.11, abs(rn - fract(t * 0.95)));
		float spokes = step(0.6, sin(a * 8.0 - t * 3.2)) * smoothstep(0.92, 0.25, rn);
		detail = clamp(outer + mid * 0.7 + pulse_wave * 0.9 + spokes * 0.4, 0.0, 1.0);
		alpha_base = clamp(detail * 0.85 + (1.0 - rn) * 0.20, 0.0, 0.92);
	}

	vec3 col = mix(primary_color.rgb * 1.4, accent_color.rgb * 3.0, detail);
	ALBEDO = col;
	ALPHA = clamp(alpha_base * fade_alpha, 0.0, 0.92);
}
