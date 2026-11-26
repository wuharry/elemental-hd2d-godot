shader_type spatial;
// MC 光影水反 × HD-2D 像素水面：
// 1. 32 px/m 像素格對齊的雙層波紋法線＋橫向水波紋理與雨滴漣漪。
// 2. 螢幕空間水下折射（含水面上方物體防暈邊保護）與 Beer-Lambert 深度吸色。
// 3. 淺水像素化焦散光網與岸線泡沫邊緣。
// 4. 即時平面鏡像反射（reflection_tex）＋ 波紋橫向打散光帶 ＋ 藝術化菲涅爾曲線。
// 5. 即時 3D 太陽／月光／路燈／營火的波峰高光碎光。

uniform sampler2D normal_tex : hint_normal, filter_nearest, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
uniform sampler2D reflection_tex : source_color, filter_nearest, repeat_disable;
uniform vec3 deep : source_color = vec3(0.05, 0.16, 0.22);
uniform vec3 shallow : source_color = vec3(0.14, 0.36, 0.40);
// 水流方向與速度（公尺／秒，世界 XZ）。池塘是 0，河流才有。
uniform vec2 flow = vec2(0.0, 0.0);
uniform float has_reflection = 0.0;
global uniform float rain_intensity;

varying vec3 wpos;
varying float top_face;

float water_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float water_vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = water_hash(i);
	float b = water_hash(i + vec2(1.0, 0.0));
	float c = water_hash(i + vec2(0.0, 1.0));
	float d = water_hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float reconstruct_world_y(vec2 uv, mat4 inv_proj, mat4 inv_view) {
	float scene_depth = textureLod(depth_tex, uv, 0.0).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(uv, scene_depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(uv * 2.0 - 1.0, scene_depth);
#endif
	vec4 floor_view = inv_proj * vec4(ndc, 1.0);
	floor_view /= floor_view.w;
	return (inv_view * floor_view).y;
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
	vec2 wp = p - flow * TIME;
	vec3 n1 = texture(normal_tex, wp * 0.24 + TIME * vec2(0.024, 0.015)).rgb * 2.0 - 1.0;
	vec3 n2 = texture(normal_tex, (p - flow * TIME * 1.35) * 0.42 - TIME * vec2(0.016, 0.022)).rgb * 2.0 - 1.0;

	// MC 光影水反招牌的橫向交錯波紋（對齊 32 px/m 世界格點），讓倒影呈現水平碎光帶。
	float w_a = sin(wp.x * 3.1 + wp.y * 5.8 + TIME * 2.1);
	float w_b = cos(wp.x * 4.7 - wp.y * 4.2 - TIME * 1.7);
	float w_c = sin(wp.y * 9.5 + wp.x * 1.8 + TIME * 2.9);
	vec2 proc_slope = vec2(w_a * 0.20 + w_b * 0.16, w_b * 0.24 + w_c * 0.22);

	vec3 n_tan = normalize(vec3((n1.xy + n2.xy) * 0.85 + proc_slope, 1.15));

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
		n_tan = normalize(n_tan + vec3(r_dir * ring * 0.65, 0.0));
		rain_glint = ring;
	}

	vec3 nm = n_tan * 0.5 + 0.5;
	vec2 wave_xy = n_tan.xy;
	float ripple = length(wave_xy);

	// 1. 深度與水下螢幕空間折射（避免把水面上方的橋柱／岸石拉進水裡產生暈邊）
	float floor_y = reconstruct_world_y(SCREEN_UV, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
	float water_depth = max(wpos.y - floor_y, 0.0);

	vec2 refr_uv = clamp(SCREEN_UV + wave_xy * 0.014 * smoothstep(0.02, 0.45, water_depth), vec2(0.002), vec2(0.998));
	float refr_floor_y = reconstruct_world_y(refr_uv, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
	vec2 safe_refr_uv = (wpos.y - refr_floor_y > 0.015) ? refr_uv : SCREEN_UV;
	float safe_depth = (wpos.y - refr_floor_y > 0.015) ? max(wpos.y - refr_floor_y, 0.0) : water_depth;

	vec3 scene_under = texture(screen_tex, safe_refr_uv).rgb;
	vec3 water_body = mix(shallow, deep, smoothstep(0.08, 1.15, safe_depth));
	// Beer-Lambert 吸色：紅光衰減快、青藍穿透深，淺灘清澈見底、深處呈通透青藍。
	vec3 absorb = exp(-safe_depth * vec3(1.25, 0.52, 0.36));
	float clarity = mix(0.88, 0.34, smoothstep(0.0, 1.35, safe_depth));
	vec3 under_col = mix(water_body, scene_under * mix(vec3(1.0), absorb, 0.78), clarity);

	// 2. 像素對齊的淺水焦散光網（跟隨水底亮度自動在陰影與夜晚淡出）
	vec2 cp = p - flow * TIME * 0.55;
	float c1 = water_vnoise(cp * 1.45 + vec2(TIME * 0.28, -TIME * 0.21));
	float c2 = water_vnoise(cp * 1.85 + vec2(-TIME * 0.24, TIME * 0.31) + vec2(5.7, 3.1));
	float caustic_web = pow(clamp(1.0 - abs(c1 - c2) * 2.4, 0.0, 1.0), 4.0);
	float caustic_depth = smoothstep(0.03, 0.16, safe_depth) * (1.0 - smoothstep(0.55, 1.35, safe_depth));
	float under_luma = dot(scene_under, vec3(0.299, 0.587, 0.114));
	under_col += vec3(0.24, 0.42, 0.44) * caustic_web * caustic_depth * clamp(under_luma * 2.4, 0.0, 0.85);

	// 3. 即時平面鏡像反射（波紋橫向打散、垂直微拉長光柱）
	vec2 base_refl_uv = vec2(SCREEN_UV.x, 1.0 - SCREEN_UV.y);
	vec2 refl_distort = vec2(wave_xy.x * 0.022, wave_xy.y * 0.046);
	vec2 refl_uv = clamp(base_refl_uv + refl_distort, vec2(0.002), vec2(0.998));
	vec3 refl_col = texture(reflection_tex, refl_uv).rgb;

	// 壓住白天／黃昏亮天空過曝，同時微幅抬高真正自發光點（暖窗／路燈／火盆／傳送門）在夜水中的明亮度。
	float refl_peak = max(refl_col.r, max(refl_col.g, refl_col.b));
	float refl_sat = refl_peak - min(refl_col.r, min(refl_col.g, refl_col.b));
	float emissive_hint = smoothstep(0.76, 0.99, refl_peak) * (0.35 + 0.65 * smoothstep(0.08, 0.40, refl_sat));
	vec3 refl_soft = refl_col / (vec3(1.0) + refl_col * 0.42);
	refl_col = refl_soft * mix(vec3(0.74, 0.87, 0.96), vec3(1.0), 0.50) * (0.82 + emissive_hint * 0.88);

	// 4. 針對 33° 俯視角調校的藝術化菲涅爾曲線（白天看得到池底與倒影並存，夜晚突顯燈火與建築輪廓）
	float ndotv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fresnel = mix(0.28, 0.78, pow(1.0 - ndotv, 2.0));
	fresnel *= mix(0.52, 1.0, smoothstep(0.0, 0.28, safe_depth));
	float lamp_boost = emissive_hint * 0.30;
	float refl_mix = clamp(fresnel + lamp_boost, 0.0, 0.86) * has_reflection;

	vec3 composed = mix(under_col, refl_col, refl_mix);

	// 5. 波峰細碎反光、岸線淺水泡沫與雨滴高光
	float crest = smoothstep(0.32, 0.52, ripple);
	composed += mix(vec3(0.04, 0.08, 0.12), vec3(0.22, 0.30, 0.34), clamp(refl_peak, 0.0, 1.0)) * crest * 0.28;

	// 岸線泡沫只在真正有水深落差的水域邊緣出現（薄水窪不整片發白）。
	float foam_band = (1.0 - smoothstep(0.035, 0.13 + ripple * 0.08, water_depth)) * smoothstep(0.028, 0.045, water_depth);
	float foam_noise = step(0.42, water_vnoise(p * 3.8 + vec2(TIME * 0.35, -TIME * 0.25)));
	vec3 foam_col = mix(vec3(0.24, 0.34, 0.40), vec3(0.72, 0.84, 0.88), clamp(under_luma * 2.2 + refl_peak * 0.45, 0.0, 1.0));
	composed = mix(composed, foam_col, foam_band * (0.32 + 0.32 * foam_noise));
	composed += vec3(0.22, 0.28, 0.36) * rain_glint;

	// 固有色保留微量水體底色接受陰影與實時高光；折射與鏡像倒影透過 EMISSION 輸出，避免夜晚二次壓黑。
	ALBEDO = water_body * 0.18;
	EMISSION = composed * 0.92;
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = 0.78;
	ROUGHNESS = 0.05;
	METALLIC = 0.0;
	SPECULAR = 1.0;
	ALPHA = 1.0;
}
