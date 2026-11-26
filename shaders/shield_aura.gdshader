shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;

instance uniform vec4 primary_color : source_color = vec4(1.0, 0.45, 0.18, 1.0);
instance uniform vec4 accent_color : source_color = vec4(1.0, 0.85, 0.35, 1.0);
instance uniform float effect_time = 0.0;
instance uniform float fade_alpha = 1.0;
instance uniform float cast_flash = 0.0;
instance uniform float style_id = 0.0;

varying vec2 local_uv;

void vertex() {
	local_uv = UV * 2.0 - 1.0;
	// Full billboarded protective aura dome centered around the character;
	// interior stays translucent so the pixel mage's face and hat stay sharp.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(INV_VIEW_MATRIX[0].xyz), 0.0),
		vec4(normalize(INV_VIEW_MATRIX[1].xyz), 0.0),
		vec4(normalize(INV_VIEW_MATRIX[2].xyz), 0.0),
		MODEL_MATRIX[3]
	);
}

void fragment() {
	// Crisp pixel-quantized spherical energy membrane (~32 px/m on a 1.88m quad).
	vec2 q = (floor(local_uv * 28.0) + 0.5) / 28.0;
	float r = length(q);
	if (r > 0.94) {
		discard;
	}
	float a = atan(q.y, q.x);
	float t = effect_time;
	float rn = clamp(r / 0.90, 0.0, 1.0);
	float nz = sqrt(max(0.0, 1.0 - rn * rn));

	// Keep the center crystal clear (leaving mage completely readable), push glow to rim!
	float fresnel = pow(1.0 - nz, 2.35);
	float rim_band = 1.0 - smoothstep(0.02, 0.09, abs(r - 0.87));

	// Element-driven energy surface pattern (hex/wave/flame/arc shimmer along the barrier).
	float pattern = 0.0;
	if (style_id < 0.5) {
		// Water: rippling vertical caustics
		pattern = 0.5 + 0.5 * sin(q.y * 16.0 - t * 4.5 + sin(q.x * 10.0 + t * 2.5));
	} else if (style_id < 1.5) {
		// Fire: rising flame-lick eddies
		pattern = smoothstep(0.35, 0.95, 0.5 + 0.5 * sin(q.x * 14.0 + sin(q.y * 10.0 - t * 7.5)) * cos(q.y * 9.0 - t * 6.5));
	} else if (style_id < 2.5) {
		// Lightning: high-frequency crackling static bands
		float st = floor(t * 16.0) / 16.0;
		pattern = step(0.72, sin(a * 9.0 + st * 21.0) * cos(r * 24.0 - st * 17.0) * 0.5 + 0.5);
	} else if (style_id < 3.5) {
		// Ice: faceted hexagonal frost lattice
		float hex = abs(sin((q.x * 10.0 + q.y * 6.0))) * abs(sin((q.x * 10.0 - q.y * 6.0)));
		pattern = smoothstep(0.65, 0.92, hex + 0.35 * sin(t * 2.0 + a * 6.0));
	} else if (style_id < 4.5) {
		// Earth: diamond geomantic ward plates
		float diag = abs(sin((q.x + q.y) * 9.0 - t * 1.4)) * abs(sin((q.x - q.y) * 9.0 + t * 1.4));
		pattern = smoothstep(0.55, 0.92, diag);
	} else if (style_id < 5.5) {
		// Arcane: swirling cosmic vortex spiral
		pattern = 0.5 + 0.5 * sin(a * 4.0 + r * 14.0 - t * 4.2);
	} else {
		// Life: gentle breathing botanical rings
		pattern = 0.5 + 0.5 * sin(r * 16.0 - t * 3.0) * cos(a * 4.0 + t * 1.2);
	}

	// Spatial gradient across the barrier (makes Arcane violet-to-crimson unmistakably vivid!).
	float grad = clamp(0.5 + q.x * 0.55 - q.y * 0.55 + 0.12 * sin(t * 1.8 + a), 0.0, 1.0);
	vec3 base_col = mix(primary_color.rgb, accent_color.rgb, grad);
	vec3 hot_rim = mix(base_col, vec3(1.0, 0.96, 1.0), 0.18);

	float shimmer = fresnel * (0.68 + 0.42 * pattern) + rim_band * 0.95 + cast_flash * 0.85;
	float edge_fade = 1.0 - smoothstep(0.86, 0.94, r);
	ALBEDO = mix(base_col * 1.65, hot_rim * 2.55, clamp(rim_band + cast_flash * 0.55, 0.0, 1.0));
	float alpha = (0.045 + shimmer * 0.56) * edge_fade * fade_alpha;
	ALPHA = clamp(alpha, 0.0, 0.82);
}
