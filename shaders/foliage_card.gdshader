shader_type spatial;
render_mode cull_disabled;
// 花草面片（MultiMesh）：圖集選格、頂端隨風擺、法線一律朝上讓它跟地面同亮度。
// INSTANCE_CUSTOM.r = 圖集第幾格（0..cols-1），COLOR = 每株的色調。

uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
uniform float cols = 2.0;
uniform float wind = 0.11;

varying vec3 tint;

void vertex() {
	float variant = floor(INSTANCE_CUSTOM.r + 0.5);
	float top = 1.0 - UV.y;
	UV.x = (UV.x + variant) / cols;
	vec3 o = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float gust = 0.5 + 0.5 * sin(TIME * 0.7 + o.x * 0.22 + o.z * 0.16);
	float s = sin(TIME * 2.4 + o.x * 1.7 + o.z * 1.3) * (0.35 + gust);
	vec3 off = vec3(s, 0.0, s * 0.6) * wind * top * top;
	VERTEX += (inverse(MODEL_MATRIX) * vec4(off, 0.0)).xyz;
	tint = COLOR.rgb;
}

void fragment() {
	vec4 c = texture(atlas, UV);
	if (c.a < 0.5) {
		discard;
	}
	ALBEDO = c.rgb * tint;
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
}
