shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;

instance uniform float effect_time = 0.0;
varying vec3 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	// Breathing emerald-gold botanical rune pool beneath the Life altar sprout.
	vec2 p = (floor(local_position.xy * 32.0) + 0.5) / 32.0;
	float r = length(p);
	if (r > 0.50) {
		discard;
	}
	float a = atan(p.y, p.x);
	float t = effect_time;
	float breath = 0.84 + 0.16 * sin(t * 2.2);

	// Four-leaf clover botanical ring + gentle warm-emerald aura.
	float petal = 0.31 + 0.075 * cos(a * 4.0 - t * 0.65);
	float ring = 1.0 - smoothstep(0.015, 0.045, abs(r - petal));
	float inner_well = 1.0 - smoothstep(0.05, 0.32, r);

	vec3 emerald = vec3(0.24, 0.92, 0.52);
	vec3 sunlit = vec3(0.76, 1.0, 0.52);
	vec3 col = mix(emerald * 1.4, sunlit * 2.5, clamp(ring + inner_well * 0.45, 0.0, 1.0));
	ALBEDO = col * breath;
	ALPHA = clamp((inner_well * 0.42 + ring * 0.78) * breath, 0.0, 0.85);
}
