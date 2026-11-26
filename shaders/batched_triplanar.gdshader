shader_type spatial;
// Mats.tri() 的合併版本：CUSTOM1/2 保存合併前座標與法線，貼圖相位和像素密度不變。
// CUSTOM1/2/3.w 保存線性色調，避免頂點 COLOR 的 8-bit 量化改變深色木材。

uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_nearest_mipmap, repeat_enable;
uniform vec3 texel_scale = vec3(0.5);
uniform vec3 texel_offset = vec3(0.0);
uniform float blend_sharpness = 60.0;
uniform float roughness = 0.95;
uniform float normal_depth = 1.0;
uniform float metallic = 0.0;
global uniform float rain_wetness;

varying vec3 source_pos;
varying vec3 source_weights;
varying vec3 source_tint;
varying float wet_top;

void vertex() {
	source_pos = (CUSTOM1.xyz * texel_scale + texel_offset) * vec3(1.0, -1.0, 1.0);
	vec3 axes = abs(CUSTOM2.xyz);
	// Rescaling before pow preserves the ratios and avoids underflow on prism slopes.
	axes /= max(max(axes.x, axes.y), axes.z);
	source_weights = pow(axes, vec3(blend_sharpness));
	source_weights /= dot(source_weights, vec3(1.0));
	source_tint = vec3(CUSTOM1.w, CUSTOM2.w, CUSTOM3.w);
	// triplanar 的切線座標系也先依原始方塊算好，再轉入合併網格座標系。
	BINORMAL = CUSTOM3.xyz;
	wet_top = smoothstep(0.32, 0.82, normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y);
}

vec3 sample_local(sampler2D tex) {
	return texture(tex, source_pos.xy).rgb * source_weights.z
		+ texture(tex, source_pos.xz).rgb * source_weights.y
		+ texture(tex, vec2(-source_pos.z, source_pos.y)).rgb * source_weights.x;
}

void fragment() {
	float wet = rain_wetness * wet_top;
	ALBEDO = sample_local(albedo_tex) * source_tint * mix(1.0, 0.74, wet);
	NORMAL_MAP = sample_local(normal_tex);
	NORMAL_MAP_DEPTH = normal_depth;
	ROUGHNESS = mix(roughness, 0.22, wet);
	METALLIC = metallic;
	SPECULAR = mix(0.5, 0.78, wet);
}
