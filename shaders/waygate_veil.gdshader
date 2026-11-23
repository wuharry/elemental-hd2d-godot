shader_type spatial;
render_mode unshaded, shadows_disabled;

// 原點是門心。門面以公尺取樣，每個光紋像素與世界材質同為 1/32 m。
instance uniform float transit_pulse : hint_range(0.0, 1.0) = 0.0;
varying vec2 gate_position;

void vertex() {
	gate_position = VERTEX.xy;
}

vec3 veil_color(vec2 xy, float pulse) {
	vec2 p = xy / vec2(0.98, 1.22);
	float radius = length(p);
	// 捲入門內的方向稍偏離正中心，讓門框和門後的入口各有自己的輪廓。
	vec2 core = vec2(-0.16, 0.10) * (1.0 - smoothstep(0.0, 1.0, radius));
	vec2 q = p - core;
	float r = length(q);
	float a = atan(q.y, q.x + 0.0001);
	float twist = 6.4 * r + 0.45 * sin(3.0 * a + r * 5.0 - TIME * 0.7);
	float phase = a * 2.0 + twist - TIME * 1.45;
	float wave = 0.5 + 0.5 * cos(phase);
	float strand = smoothstep(0.58, 0.99, wave) * smoothstep(0.06, 0.32, r);
	float edge = smoothstep(0.84, 0.99, radius);
	vec3 color = mix(vec3(0.014, 0.012, 0.084), vec3(0.15, 0.046, 0.32), radius);
	color += strand * mix(vec3(0.045, 0.108, 0.55), vec3(0.47, 0.12, 0.68),
		0.5 + 0.5 * sin(a - TIME * 0.45));
	// 細光絲、交替發亮的門沿與散布在深處的星點。
	float thread = smoothstep(0.96, 0.998, 0.5 + 0.5 * cos(phase * 2.0 + 0.80)) * strand;
	color += vec3(0.34, 0.65, 1.05) * thread * smoothstep(0.18, 0.76, r);
	color += vec3(0.46, 0.54, 1.24) * edge * (0.45 + 0.55 * wave);
	float seed = fract(sin(dot(floor(xy * 32.0), vec2(12.9898, 78.233))) * 43758.5453);
	color += vec3(0.66, 0.75, 1.02) * step(0.988, seed) * (0.65 + 0.35 * sin(seed * 320.0 + TIME * 3.2));
	// 啟動時一道光環朝門心收縮，與外側實體光屑和地面反光同步。
	float flare = 1.0 - smoothstep(0.04, 0.23, abs(r - pulse));
	return color * (1.0 + pulse * 0.5) + vec3(0.65, 1.1, 1.85) * flare * pulse;
}

void fragment() {
	vec2 xy = (floor(gate_position * 32.0) + 0.5) / 32.0;
	if (length(xy / vec2(0.98, 1.22)) > 1.0) {
		discard;
	}
	ALBEDO = veil_color(xy, transit_pulse);
}
