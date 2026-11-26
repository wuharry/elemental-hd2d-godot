shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 violet_color : source_color = vec3(0.62, 0.24, 0.94);
uniform vec3 ruby_color : source_color = vec3(0.95, 0.18, 0.34);
instance uniform float effect_time = 0.0;
varying vec2 local_uv;

void vertex() {
	local_uv = UV * 2.0 - 1.0;
	// Full camera-facing billboard preserving unit node scale so the orb reads
	// as a crisp pixel-quantized energy sphere from every angle.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(INV_VIEW_MATRIX[0].xyz), 0.0),
		vec4(normalize(INV_VIEW_MATRIX[1].xyz), 0.0),
		vec4(normalize(INV_VIEW_MATRIX[2].xyz), 0.0),
		MODEL_MATRIX[3]
	);
}

void fragment() {
	// Quantize to a crisp 26x26 pixel grid (~32 px/m on a 0.80m quad).
	vec2 q = (floor(local_uv * 13.0) + 0.5) / 13.0;
	float r = length(q);
	float t = effect_time;

	float sphere_r = 0.66;
	float angle = atan(q.y, q.x);

	// Corona plasma flares licking softly outside the sphere rim.
	float corona_wave = 0.5 + 0.5 * sin(angle * 5.0 - t * 3.8) * cos(angle * 3.0 + t * 2.6);
	float corona_limit = sphere_r + 0.12 + corona_wave * 0.14;
	if (r > corona_limit) {
		discard;
	}

	// Spatial violet-to-ruby gradient swirling dynamically across the sphere.
	vec2 rot_p = vec2(
		q.x * cos(t * 0.55) - q.y * sin(t * 0.55),
		q.x * sin(t * 0.55) + q.y * cos(t * 0.55)
	);
	float swirl_bias = sin(r * 9.0 - t * 3.2 + angle * 2.0) * 0.16;
	float grad_t = clamp(0.5 + rot_p.x * 0.82 - rot_p.y * 0.68 + swirl_bias, 0.0, 1.0);
	// Slight stepped quantization to preserve crisp HD-2D pixel art feel.
	grad_t = mix(grad_t, floor(grad_t * 6.0) / 6.0, 0.35);
	vec3 base_col = mix(violet_color, ruby_color, smoothstep(0.14, 0.86, grad_t));

	if (r > sphere_r) {
		// Outer glowing pixel corona motes.
		float fade = 1.0 - smoothstep(sphere_r, corona_limit, r);
		if (fade < 0.35) {
			discard;
		}
		ALBEDO = base_col * (2.2 + 0.5 * corona_wave);
	} else {
		float rn = r / sphere_r;
		float nz = sqrt(max(0.0, 1.0 - rn * rn));
		float fresnel = pow(1.0 - nz, 1.85);

		// Internal swirling arcane energy bands across the spherical surface.
		float band1 = 0.5 + 0.5 * sin((q.x * 11.0 + q.y * 7.0) / max(nz + 0.35, 0.35) - t * 4.0);
		float band2 = 0.5 + 0.5 * cos((q.x * 8.0 - q.y * 12.0) + t * 3.1);
		float filaments = smoothstep(0.58, 0.92, band1 * 0.6 + band2 * 0.4);

		// Incandescent heart + saturated mid-body + blazing Fresnel rim.
		float heart = 1.0 - smoothstep(0.0, 0.34, rn);
		vec3 deep_body = pow(base_col, vec3(1.55)) * 1.15;
		vec3 bright_band = mix(base_col, vec3(1.0, 0.84, 0.96), 0.38) * 2.6;
		vec3 rim_glow = mix(base_col, vec3(1.0, 0.72, 0.95), 0.25) * 3.4;
		vec3 core_glow = mix(base_col, vec3(1.0, 0.90, 0.98), 0.55) * 3.8;

		vec3 col = mix(deep_body, bright_band, filaments * 0.78);
		col = mix(col, rim_glow, fresnel * 0.92);
		col = mix(col, core_glow, heart * 0.82);
		ALBEDO = col;
	}
}
