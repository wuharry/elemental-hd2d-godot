shader_type spatial;
// 池塘：不透明 + 低粗糙度，倒影交給螢幕空間反射（半透明物件吃不到 SSR）。
// 波紋的取樣座標對齊像素格，所以水面的閃動也是一格一格的。

uniform sampler2D normal_tex : hint_normal, filter_nearest, repeat_enable;
uniform vec3 deep : source_color = vec3(0.07, 0.19, 0.24);
uniform vec3 shallow : source_color = vec3(0.16, 0.36, 0.38);
// 水流方向與速度（公尺／秒，世界 XZ）。池塘是 0，河流才有。
uniform vec2 flow = vec2(0.0, 0.0);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = floor(wpos.xz * 32.0) / 32.0;
	vec3 n1 = texture(normal_tex, (p - flow * TIME) * 0.22 + TIME * vec2(0.021, 0.013)).rgb;
	vec3 n2 = texture(normal_tex, (p - flow * TIME * 1.4) * 0.37 - TIME * vec2(0.014, 0.019)).rgb;
	vec3 nm = mix(n1, n2, 0.5);
	float ripple = abs(nm.r - 0.5) + abs(nm.g - 0.5);
	ALBEDO = mix(deep, shallow, smoothstep(0.02, 0.12, ripple));
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = 0.35;
	ROUGHNESS = 0.05;
	METALLIC = 0.0;
	SPECULAR = 0.9;
}
