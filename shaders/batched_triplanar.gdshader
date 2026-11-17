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

varying vec3 source_pos;
varying vec3 source_weights;
varying vec3 source_tint;

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
}

vec3 sample_local(sampler2D tex) {
	return texture(tex, source_pos.xy).rgb * source_weights.z
		+ texture(tex, source_pos.xz).rgb * source_weights.y
		+ texture(tex, vec2(-source_pos.z, source_pos.y)).rgb * source_weights.x;
}

void fragment() {
	ALBEDO = sample_local(albedo_tex) * source_tint;
	NORMAL_MAP = sample_local(normal_tex);
	NORMAL_MAP_DEPTH = normal_depth;
	ROUGHNESS = roughness;
	METALLIC = metallic;
}
