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

varying vec3 wpos;
varying vec3 wnrm;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
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
		ALBEDO = col;

		vec3 nm = texture(base_n, uv).rgb;
		nm = mix(nm, texture(dirt_n, uv).rgb, dirt);
		nm = mix(nm, texture(path_n, uv).rgb, path);
		NORMAL_MAP = nm;
		NORMAL_MAP_DEPTH = 1.4;
		ROUGHNESS = mix(base_roughness, path_roughness, path);
		SPECULAR = mix(0.2, 0.5, path);
	}
}
