shader_type spatial;

instance uniform float effect_time = 0.0;
varying vec3 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	vec2 p = (floor(local_position.xz * 32.0) + 0.5) / 32.0;
	float radius = length(p);
	if (radius > 0.48) {
		discard;
	}
	float angle = atan(p.y, p.x);
	float t = effect_time;

	// Layered spring ripples radiating from the geyser center plus secondary arc splash ring.
	float ripple_main = sin(radius * 44.0 - t * 8.2);
	float ripple_splash = sin(abs(radius - 0.36) * 52.0 - t * 9.5) * smoothstep(0.20, 0.36, radius);
	float swirl = sin(angle * 4.0 + radius * 16.0 - t * 4.2);

	// Deep sapphire-cerulean spring grading up to bright turquoise center and rim foam.
	float center_well = 1.0 - smoothstep(0.06, 0.24, radius);
	float outer_foam = smoothstep(0.41, 0.47, radius) * (0.65 + 0.35 * swirl);
	float crest = step(0.76, ripple_main) + step(0.84, ripple_splash) * 0.75;
	float sparkle = step(0.92, sin(p.x * 58.0 + t * 6.0) * cos(p.y * 58.0 - t * 5.2));

	vec3 deep = vec3(0.02, 0.24, 0.56);
	vec3 mid = vec3(0.06, 0.54, 0.80);
	vec3 foam = vec3(0.42, 0.90, 1.0);
	vec3 water = mix(deep, mid, clamp(center_well * 0.85 + 0.28 + swirl * 0.12, 0.0, 1.0));
	float highlight = clamp(crest + center_well * 0.65 + outer_foam * 0.75 + sparkle, 0.0, 1.0);
	water = mix(water, foam, highlight * 0.82);

	ALBEDO = water;
	ROUGHNESS = 0.12;
	SPECULAR = 0.85;
	EMISSION = water * (0.75 + highlight * 2.6 + center_well * 1.4);
}
