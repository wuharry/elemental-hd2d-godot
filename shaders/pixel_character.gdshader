shader_type spatial;
render_mode depth_draw_opaque, cull_disabled;
// 進階像素角色即時 3D 光照（參考 The Last Night／HD-2D 角色法線與輪廓光做法）：
// 1. 以 Y 軸看板維持像素紙片直立與俯角高度補償，法線空間不受垂直拉伸變形。
// 2. 吃預產生的立體部位法線圖，並依 flip_sign 正確翻轉左右曲率。
// 3. 每個 3D 實時光源（太陽／月亮／路燈／營火／傳送門／法術）即時驅動受光與輪廓光（Rim Light）。
// 4. 金飾帶高光，琥珀晶石自發光，並在持杖側投射柔和近距暖色反光。

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_disable;
uniform sampler2D normal_tex : hint_normal, filter_nearest, repeat_disable;
uniform sampler2D material_tex : filter_nearest, repeat_disable;
uniform float flip_sign = 1.0;
uniform float normal_strength = 1.0;
uniform float rim_strength = 0.85;
uniform float emission_strength = 1.45;
uniform vec3 bounce_color : source_color = vec3(1.0, 0.72, 0.41);
uniform float bounce_energy = 0.0;
uniform float bounce_dir_x = -0.82;
uniform float wet_amount = 0.0;

varying vec3 v_right;
varying vec3 v_up;
varying vec3 v_forward;
varying float v_rim_mask;

void vertex() {
	vec3 node_scale = vec3(
		length(MODEL_MATRIX[0].xyz),
		length(MODEL_MATRIX[1].xyz),
		length(MODEL_MATRIX[2].xyz)
	);
	// 陰影 pass 的 INV_VIEW_MATRIX 是光源視角；紙片須始終對齊主攝影機。
	vec2 fwd_xz = MAIN_CAM_INV_VIEW_MATRIX[2].xz;
	vec3 world_forward = length(fwd_xz) > 0.0001
		? normalize(vec3(fwd_xz.x, 0.0, fwd_xz.y))
		: vec3(0.0, 0.0, 1.0);
	vec3 world_up = vec3(0.0, 1.0, 0.0);
	vec3 world_right = normalize(cross(world_up, world_forward));
	mat4 bill_model = mat4(
		vec4(world_right * node_scale.x, 0.0),
		vec4(world_up * node_scale.y, 0.0),
		vec4(world_forward * node_scale.z, 0.0),
		MODEL_MATRIX[3]
	);
	MODELVIEW_MATRIX = VIEW_MATRIX * bill_model;
	mat3 view_rot = mat3(VIEW_MATRIX);
	v_right = normalize(view_rot * world_right);
	v_up = normalize(view_rot * world_up);
	v_forward = normalize(view_rot * world_forward);
	MODELVIEW_NORMAL_MATRIX = mat3(v_right, v_up, v_forward);
}

void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	ALBEDO = mix(tex.rgb, tex.rgb * vec3(0.72, 0.84, 0.98), clamp(wet_amount, 0.0, 1.0));
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;

	vec3 n_local = texture(normal_tex, UV).rgb * 2.0 - 1.0;
	n_local.x *= flip_sign;
	n_local.xy *= normal_strength;
	n_local = normalize(n_local);
	NORMAL = normalize(v_right * n_local.x + v_up * n_local.y + v_forward * n_local.z);

	vec4 mat_data = texture(material_tex, UV);
	ROUGHNESS = mix(mat_data.r, 0.14, clamp(wet_amount, 0.0, 1.0));
	METALLIC = mat_data.g;
	SPECULAR = mix(mix(0.35, 0.9, mat_data.g), 0.88, clamp(wet_amount, 0.0, 1.0));
	v_rim_mask = mat_data.b;

	vec3 crystal_emi = tex.rgb * mat_data.a * emission_strength;
	float side_face = clamp(dot(n_local, normalize(vec3(bounce_dir_x, 0.22, 0.58))), 0.0, 1.0);
	vec3 bounce_emi = tex.rgb * bounce_color * bounce_energy * side_face * (0.45 + 0.55 * v_rim_mask);
	vec3 wet_rim = vec3(0.18, 0.58, 0.92) * clamp(wet_amount, 0.0, 1.0) * v_rim_mask * 0.26;
	EMISSION = crystal_emi + bounce_emi + wet_rim;
}

void light() {
	float ndotl = dot(NORMAL, LIGHT);
	// 柔和包覆漫射：保留像素法線立體感，不讓 Q 版角色半邊死黑。
	float wrap = clamp((ndotl + 0.34) / 1.34, 0.0, 1.0);
	float lit = mix(wrap, smoothstep(0.12, 0.68, wrap), 0.22);
	DIFFUSE_LIGHT += lit * ATTENUATION * LIGHT_COLOR / PI;

	// 金扣、杖頭金叉與晶石的銳利高光
	vec3 half_vec = normalize(LIGHT + VIEW);
	float ndoth = max(dot(NORMAL, half_vec), 0.0);
	float shininess = mix(96.0, 8.0, ROUGHNESS);
	float spec_term = pow(ndoth, shininess) * (1.0 - ROUGHNESS) * (0.28 + 0.72 * METALLIC);
	vec3 spec_tint = mix(vec3(1.0), ALBEDO, METALLIC);

	// 即時 3D 光源驅動輪廓光（側逆光沿 1–2 px 剪影與法線邊緣亮起）
	float side_back = clamp(1.0 - max(dot(v_forward, LIGHT), 0.0) * 0.72, 0.22, 1.0);
	vec3 edge_n = normalize(NORMAL - v_forward * (dot(NORMAL, v_forward) * 0.65) + v_forward * 0.08);
	float light_align = clamp(dot(edge_n, LIGHT) * 0.65 + 0.35, 0.0, 1.0);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.7);
	float rim_mask = clamp(v_rim_mask * 0.94 + fresnel * 0.45, 0.0, 1.0);
	float rim = rim_mask * side_back * light_align * rim_strength;
	vec3 rim_tint = mix(vec3(1.0), ALBEDO * 1.45 + vec3(0.18), 0.32);

	SPECULAR_LIGHT += (spec_term * spec_tint * 0.5 + rim * rim_tint * 0.64) * ATTENUATION * LIGHT_COLOR / PI;
}
