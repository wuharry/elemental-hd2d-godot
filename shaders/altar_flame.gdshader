shader_type spatial;
render_mode unshaded, cull_disabled;

instance uniform float effect_time = 0.0;
varying vec3 local_position;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float flame_tongue(vec2 p, float center, float height, float width, float bend, float ripple) {
	float y = clamp(p.y / max(height, 0.01), 0.0, 1.5);
	float curve = bend * y * y + ripple * sin(y * 9.5) * y;
	float x = p.x - center - curve;
	float taper = mix(1.0, 0.28, pow(clamp(y, 0.0, 1.0), 1.35));
	return 1.0 - y - pow(abs(x) / max(width * taper, 0.01), 1.55);
}

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	// 32 px/m pixel-quantized flame coordinates across the crossed planes.
	vec2 p = (floor(local_position.xy * 32.0) + 0.5) / 32.0;
	p.y = (p.y + 0.66) / 1.32;
	float t = floor(effect_time * 16.0) / 16.0;

	// Multi-frequency turbulent draft so flames lick and curl upward organically.
	float sway = sin(t * 6.8) * 0.075 + sin(t * 13.4 + 1.1) * 0.035;
	float wave = sin(p.y * 15.0 - t * 14.5) * 0.032 + cos(p.y * 23.0 - t * 19.0) * 0.016;
	vec2 q = vec2(p.x + wave * smoothstep(0.06, 0.78, p.y), p.y);

	float h_main = 0.88 + 0.09 * sin(t * 9.1) + 0.04 * cos(t * 15.7);
	float body = flame_tongue(q, 0.0, h_main, 0.34, sway, 0.035);
	body = max(body, flame_tongue(q, -0.20, 0.62 + 0.10 * sin(t * 10.4 + 1.8), 0.16, -0.11 + sway * 0.5, -0.025));
	body = max(body, flame_tongue(q, 0.21, 0.66 + 0.09 * cos(t * 8.6 + 0.6), 0.15, 0.12 + sway * 0.5, 0.025));
	body = max(body, flame_tongue(q, -0.09, 0.76 + 0.08 * sin(t * 12.1 + 3.1), 0.17, -0.04 + sway * 0.8, 0.02));
	body = max(body, flame_tongue(q, 0.10, 0.72 + 0.08 * cos(t * 11.3 + 2.4), 0.16, 0.05 + sway * 0.8, -0.02));

	// Detached licking flame sparks pinching off near the upper tips.
	float wisp_y = fract(t * 1.15);
	vec2 wisp1 = vec2(sin(t * 5.2) * 0.14, 0.66 + wisp_y * 0.30);
	float wisp_y2 = fract(t * 1.15 + 0.52);
	vec2 wisp2 = vec2(-0.08 + cos(t * 6.4) * 0.15, 0.62 + wisp_y2 * 0.32);
	float wisp = max(0.065 * (1.0 - wisp_y) - length((p - wisp1) * vec2(1.4, 0.85)),
		0.058 * (1.0 - wisp_y2) - length((p - wisp2) * vec2(1.4, 0.85)));

	// Pixelated edge erosion near tips for hand-animated fire texture.
	float cell_noise = hash21(floor(vec2(p.x * 28.0, p.y * 28.0 - t * 18.0)));
	float eroded = body - smoothstep(0.45, 0.95, p.y) * cell_noise * 0.22;

	if (p.y < 0.01 || (eroded < 0.0 && wisp < 0.0)) {
		discard;
	}

	float core = flame_tongue(q, 0.0, 0.56 + 0.05 * sin(t * 13.0), 0.20, sway * 0.45, 0.015);
	float inner = flame_tongue(q, 0.0, 0.34 + 0.03 * cos(t * 16.0), 0.12, sway * 0.2, 0.0);

	// 5-band fiery ramp: crimson tip -> scarlet -> vivid orange -> amber -> sunlit gold core.
	vec3 color = vec3(0.84, 0.07, 0.012);
	float energy = 1.35;
	if (eroded > 0.12 || wisp > 0.008) {
		color = vec3(1.0, 0.24, 0.018);
		energy = 2.15;
	}
	if (eroded > 0.30) {
		color = vec3(1.0, 0.46, 0.04);
		energy = 2.95;
	}
	if (core > 0.06) {
		color = vec3(1.0, 0.68, 0.11);
		energy = 3.75;
	}
	if (inner > 0.16) {
		color = vec3(1.0, 0.88, 0.42);
		energy = 4.35;
	}
	ALBEDO = color * energy;
}
