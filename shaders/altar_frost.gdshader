shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;

instance uniform float effect_time = 0.0;
varying vec3 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	// Swirling pixel-quantized chill vapor & 6-pointed hoarfrost ring on the ice pedestal.
	vec2 p = (floor(local_position.xy * 32.0) + 0.5) / 32.0;
	float r = length(p);
	if (r > 0.56) {
		discard;
	}
	float a = atan(p.y, p.x);
	float t = effect_time;

	float swirl = 0.5 + 0.5 * sin(a * 6.0 - t * 1.4 + r * 10.0);
	float vapor = (1.0 - smoothstep(0.14, 0.55, r)) * (0.55 + 0.45 * swirl);

	// Crisp geometric snowflake/frost rune ring inside the mist.
	float spoke = pow(abs(cos(a * 3.0 - t * 0.35)), 12.0) * smoothstep(0.48, 0.12, r) * smoothstep(0.08, 0.18, r);
	float frost_ring = 1.0 - smoothstep(0.015, 0.045, abs(r - 0.39));

	vec3 mist_col = vec3(0.45, 0.88, 1.0);
	vec3 rune_col = vec3(0.82, 0.97, 1.0);
	float rune_mask = clamp(spoke * 0.9 + frost_ring * 0.85, 0.0, 1.0);
	ALBEDO = mix(mist_col * 1.25, rune_col * 2.4, rune_mask);
	ALPHA = clamp(vapor * 0.48 + rune_mask * 0.52, 0.0, 0.82);
}
