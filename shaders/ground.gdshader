shader_type spatial;
// 地面：底層／土層／路面三層，依路徑遮罩混合；側面（懸崖、河岸、裂谷壁）用另一張貼圖。
// 遮罩先對齊到像素格再判斷，所以邊界是一格一格的鋸齒，不是平滑漸層。
// 各場景只換貼圖與色調，混合方式全場景相同。

uniform sampler2D base_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D base_n : hint_normal, filter_nearest_mipmap, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D dirt_n : hint_normal, filter_nearest_mipmap, repeat_enable;
uniform sampler2D path_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D path_n : hint_normal, filter_nearest_mipmap, repeat_enable;
uniform sampler2D side_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D side_n : hint_normal, filter_nearest_mipmap, repeat_enable;
uniform sampler2D mask_tex : filter_linear, repeat_disable; // R=路面 G=土
uniform vec3 base_tint : source_color = vec3(1.0);
uniform vec3 dirt_tint : source_color = vec3(1.0);
uniform vec3 path_tint : source_color = vec3(1.0);
uniform vec3 side_tint : source_color = vec3(1.0);
uniform float world_size = 96.0;
uniform float texel_scale = 0.5;
uniform float path_roughness = 0.78;
uniform float base_roughness = 1.0;
global uniform float rain_wetness;
global uniform float rain_intensity;
global uniform float water_reflection_y;

varying vec3 wpos;
varying vec3 wnrm;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	if (INV_VIEW_MATRIX[3].y < water_reflection_y && wpos.y < water_reflection_y - 0.02) {
		discard;
	}
	if (wnrm.y < 0.7) {
		// 側面：依朝向選投影軸；越往下越暗，裂谷才看起來深
		vec2 suv = (abs(wnrm.x) > abs(wnrm.z) ? vec2(wpos.z, -wpos.y) : vec2(wpos.x, -wpos.y)) * texel_scale;
		float depth = clamp(-wpos.y / 7.0, 0.0, 1.0);
		ALBEDO = texture(side_tex, suv).rgb * side_tint * mix(1.0, 0.18, depth);
		NORMAL_MAP = texture(side_n, suv).rgb;
		NORMAL_MAP_DEPTH = 1.4;
		ROUGHNESS = 0.95;
	} else {
		vec2 uv = wpos.xz * texel_scale;
		vec2 cell = floor(wpos.xz * 32.0);
		vec2 muv = (cell + 0.5) / 32.0 / world_size + 0.5;
		vec2 m = texture(mask_tex, muv).rg;
		float n = hash(cell) * 0.14 + hash(floor(cell / 4.0)) * 0.22 - 0.18;
		float path = step(0.5, m.r + n);
		float dirt = step(0.5, m.g + n);

		vec3 b = texture(base_tex, uv).rgb * base_tint;
		// 大片的深淺變化，避免整片同色
		float patch = hash(floor(cell / 48.0)) * 0.5 + hash(floor((cell + 17.0) / 96.0)) * 0.5;
		b *= mix(0.88, 1.06, patch);

		vec3 col = mix(b, texture(dirt_tex, uv).rgb * dirt_tint, dirt);
		col = mix(col, texture(path_tex, uv).rgb * path_tint, path);

		vec3 nm = texture(base_n, uv).rgb;
		nm = mix(nm, texture(dirt_n, uv).rgb, dirt);
		nm = mix(nm, texture(path_n, uv).rgb, path);

		float rough = mix(base_roughness, path_roughness, path);
		float spec = mix(0.2, 0.5, path);
		if (rain_wetness > 0.001) {
			// 水窪與雨滴波紋都對齊 32 px/m 世界像素格，保留鋸齒硬邊而非柔和漸層。
			vec2 p_pos = (cell + 0.5) / 32.0;
			float p_noise = vnoise(p_pos * 0.28) * 0.68 + vnoise(p_pos * 0.78 + vec2(7.3, 4.1)) * 0.32;
			float surface_hold = max(path, dirt * 0.8);
			float puddle_bias = mix(-0.18, 0.22, surface_hold);
			float puddle = step(0.54 - rain_wetness * 0.16 - puddle_bias, p_noise) * smoothstep(0.05, 0.35, rain_wetness);

			float damp = rain_wetness * mix(0.62, 1.0, surface_hold);
			col *= mix(1.0, mix(0.76, 0.52, surface_hold), damp);
			col = mix(col, col * 0.58 + vec3(0.01, 0.018, 0.03), puddle * 0.88);

			vec3 puddle_n = vec3(0.5, 0.5, 1.0);
			float ripple_glint = 0.0;
			if (puddle > 0.5 && rain_intensity > 0.01) {
				vec2 r_grid = floor(p_pos * 1.15);
				vec2 r_local = fract(p_pos * 1.15) - 0.5;
				float seed = hash(r_grid);
				float t_drop = TIME * (1.1 + seed * 0.55) + seed * 19.0;
				float cycle = fract(t_drop);
				float active = step(0.55, hash(r_grid + floor(t_drop) * 13.7));
				float fade = clamp(1.0 - cycle / 0.55, 0.0, 1.0) * active;
				vec2 drop_off = (vec2(hash(r_grid + vec2(3.1, 1.7)), hash(r_grid + vec2(9.7, 5.3))) - 0.5) * 0.42;
				float dist = length(r_local - drop_off);
				float radius = (cycle / 0.55) * 0.32;
				float ring = exp(-pow((dist - radius) * 32.0, 2.0)) * fade;
				vec2 r_dir = normalize(r_local - drop_off + vec2(0.0001));
				puddle_n.xy += r_dir * ring * 0.24 * rain_intensity;
				ripple_glint = ring * rain_intensity;
			}
			nm = mix(nm, normalize(puddle_n * 2.0 - 1.0) * 0.5 + 0.5, puddle);
			float wet_rough = mix(rough, mix(0.46, 0.16, surface_hold), rain_wetness);
			rough = mix(wet_rough, 0.025, puddle);
			float wet_spec = mix(spec, mix(0.58, 0.88, surface_hold), rain_wetness);
			spec = mix(wet_spec, 1.0, puddle);
			col += vec3(0.05, 0.07, 0.1) * ripple_glint;
		}
		ALBEDO = col;
		NORMAL_MAP = nm;
		NORMAL_MAP_DEPTH = 1.4;
		ROUGHNESS = rough;
		SPECULAR = spec;
	}
}
