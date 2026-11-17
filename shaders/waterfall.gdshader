shader_type spatial;
render_mode cull_disabled;
// 瀑布：一條一條往下流的白色水紋。座標對齊像素格，所以水紋是一格一格往下跳。

uniform vec3 water : source_color = vec3(0.35, 0.66, 0.82);
uniform vec3 foam : source_color = vec3(0.93, 0.98, 1.0);

varying vec3 lpos;

float hash(float p) {
	return fract(sin(p * 91.7) * 43758.5453);
}

void vertex() {
	lpos = VERTEX;
}

void fragment() {
	vec2 p = floor(lpos.xy * 32.0) / 32.0;
	float col = floor(p.x * 8.0);
	float h = hash(col);
	float v = fract(p.y * 0.55 + TIME * (0.9 + h * 0.7) + h * 7.0);
	float streak = step(0.62, v) * step(0.35, h);
	ALBEDO = mix(water, foam, streak);
	EMISSION = foam * streak * 0.08;
	ROUGHNESS = 0.25;
	SPECULAR = 0.7;
}
