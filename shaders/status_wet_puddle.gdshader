shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;

instance uniform float effect_time = 0.0;
varying vec2 local_xy;

void vertex() {
	local_xy = UV * 2.0 - 1.0;
}

void fragment() {
	// 32 px/m pixel-quantized soaked puddle beneath wet targets/characters,
	// with staggered expanding concentric drip rings where water droplets land.
	vec2 q = (floor(local_xy * 22.0) + 0.5) / 22.0;
	float a = atan(q.y, q.x);
	float limit = 0.80 + 0.10 * sin(a * 3.0 + 0.7) + 0.06 * cos(a * 5.0 - 1.1);
	float r = length(q);
	if (r > limit) {
		discard;
	}
	float t = effect_time;
	float edge = 1.0 - smoothstep(limit - 0.16, limit, r);

	// Three staggered expanding drip ripples across the puddle.
	float r1 = length(q - vec2(-0.24, 0.14));
	float r2 = length(q - vec2(0.26, -0.10));
	float r3 = length(q - vec2(-0.04, -0.26));
	float p1 = fract(t * 1.35 + 0.05);
	float p2 = fract(t * 1.35 + 0.38);
	float p3 = fract(t * 1.35 + 0.72);
	float ring1 = (1.0 - smoothstep(0.015, 0.065, abs(r1 - p1 * 0.42))) * (1.0 - p1);
	float ring2 = (1.0 - smoothstep(0.015, 0.065, abs(r2 - p2 * 0.42))) * (1.0 - p2);
	float ring3 = (1.0 - smoothstep(0.015, 0.065, abs(r3 - p3 * 0.42))) * (1.0 - p3);
	float ripples = clamp(ring1 + ring2 + ring3, 0.0, 1.0);

	// Dark soaked ground center + bright turquoise-white ripple sheen.
	vec3 dark_wet = vec3(0.06, 0.19, 0.34);
	vec3 glint = vec3(0.56, 0.92, 1.0);
	ALBEDO = mix(dark_wet * 0.95, glint * 2.4, ripples * 0.9);
	ALPHA = clamp((0.46 + ripples * 0.46) * edge, 0.0, 0.86);
}
