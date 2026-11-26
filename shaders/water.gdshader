shader_type spatial;
// 半透明水保留底色與受光；倒影由水域探針提供（透明材質不走 SSR）。
// 波紋的取樣座標對齊像素格，所以水面的閃動也是一格一格的。

uniform sampler2D normal_tex : hint_normal, filter_nearest, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform vec3 deep : source_color = vec3(0.07, 0.19, 0.24);
uniform vec3 shallow : source_color = vec3(0.16, 0.36, 0.38);
// 水流方向與速度（公尺／秒，世界 XZ）。池塘是 0，河流才有。
uniform vec2 flow = vec2(0.0, 0.0);
global uniform float rain_intensity;

varying vec3 wpos;
varying float top_face;

float water_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	top_face = NORMAL.y;
}

void fragment() {
	// 方塊只呈現液面；相鄰水片的垂直側面不能重複混色形成暗接縫。
	if (top_face < 0.5) {
		discard;
	}
	vec2 p = floor(wpos.xz * 32.0) / 32.0;
	vec3 n1 = texture(normal_tex, (p - flow * TIME) * 0.22 + TIME * vec2(0.021, 0.013)).rgb;
	vec3 n2 = texture(normal_tex, (p - flow * TIME * 1.4) * 0.37 - TIME * vec2(0.014, 0.019)).rgb;
	vec3 nm = normalize((n1 * 2.0 - 1.0) + (n2 * 2.0 - 1.0)) * 0.5 + 0.5;
	float rain_glint = 0.0;
	if (rain_intensity > 0.01) {
		vec2 r_grid = floor(p * 1.6);
		vec2 r_local = fract(p * 1.6) - 0.5;
		float seed = water_hash(r_grid);
		float cycle = fract(TIME * (1.6 + seed * 0.7) + seed * 23.0);
		vec2 drop_off = (vec2(water_hash(r_grid + vec2(4.1, 2.3)), water_hash(r_grid + vec2(8.7, 6.1))) - 0.5) * 0.42;
		float dist = length(r_local - drop_off);
		float ring = exp(-pow((dist - cycle * 0.36) * 26.0, 2.0)) * (1.0 - cycle) * rain_intensity;
		vec2 r_dir = normalize(r_local - drop_off + vec2(0.0001));
		nm = normalize((nm * 2.0 - 1.0) + vec3(r_dir * ring * 0.65, 0.0)) * 0.5 + 0.5;
		rain_glint = ring;
	}
	float ripple = abs(nm.r - 0.5) + abs(nm.g - 0.5);
	// 固有色只留小幅變化；亮紋由波面法線反射真正的天空、景物和燈光。
	ALBEDO = mix(deep, shallow, 0.12 + 0.12 * smoothstep(0.02, 0.12, ripple)) + vec3(0.22, 0.28, 0.34) * rain_glint;
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = 0.55;
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.9;
	// 深度只控制吸色程度；淺水看得見池底，深水仍保留藍綠色與反光。
	float scene_depth = textureLod(depth_tex, SCREEN_UV, 0.0).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, scene_depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, scene_depth);
#endif
	vec4 floor_view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	floor_view /= floor_view.w;
	float water_depth = max(wpos.y - (INV_VIEW_MATRIX * floor_view).y, 0.0);
	ALPHA = mix(0.48, 0.82, smoothstep(0.0, 1.2, water_depth));
}
