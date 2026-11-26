shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;

instance uniform vec4 primary_color : source_color = vec4(1.0, 0.35, 0.12, 1.0);
instance uniform vec4 accent_color : source_color = vec4(1.0, 0.86, 0.38, 1.0);
instance uniform float effect_time = 0.0;

varying vec2 local_uv;

void vertex() {
	local_uv = UV * 2.0 - 1.0;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(INV_VIEW_MATRIX[0].xyz), 0.0),
		vec4(normalize(INV_VIEW_MATRIX[1].xyz), 0.0),
		vec4(normalize(INV_VIEW_MATRIX[2].xyz), 0.0),
		MODEL_MATRIX[3]
	);
}

void fragment() {
	vec2 q = (floor(local_uv * 10.0) + 0.5) / 10.0;
	float r = length(q);
	float a = atan(q.y, q.x);
	float flicker = 0.09 * sin(a * 5.0 - effect_time * 16.0);
	if (r > 0.86 + flicker) {
		discard;
	}
	float core = 1.0 - smoothstep(0.0, 0.48, r);
	float halo = 1.0 - smoothstep(0.35, 0.88 + flicker, r);
	vec3 col = mix(primary_color.rgb * 2.2, accent_color.rgb * 4.4, core);
	ALBEDO = col;
	ALPHA = clamp(halo * 0.95 + core, 0.0, 1.0);
}
