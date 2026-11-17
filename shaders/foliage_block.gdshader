shader_type spatial;
#include "res://shaders/foliage_reveal.gdshaderinc"
// 樹葉方塊：依 local 座標鋪像素貼圖（同 Mats.tri），整塊隨風平移。
// 用節點原點算位移，所以方塊本身不變形，只是一塊一塊地晃。

uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_nearest_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);
uniform float texel_scale = 0.5;
uniform float sway = 0.05;
uniform bool batched = false;

varying vec3 lpos;
varying vec3 lnrm;
varying vec3 block_tint;
varying vec3 world_pos;

void vertex() {
	lpos = VERTEX;
	lnrm = NORMAL;
	block_tint = tint;
	vec3 o = NODE_POSITION_WORLD;
	float block_sway = sway;
	if (batched) {
		lpos = CUSTOM1.xyz;
		lnrm = CUSTOM2.xyz;
		block_tint = vec3(CUSTOM1.w, CUSTOM2.w, CUSTOM3.w);
		o = (MODEL_MATRIX * vec4(CUSTOM0.xyz, 1.0)).xyz;
		block_sway = CUSTOM0.w;
	}
	float gust = 0.6 + 0.4 * sin(TIME * 0.6 + o.x * 0.12 + o.z * 0.09);
	vec3 off = vec3(
		sin(TIME * 1.6 + o.x * 1.3 + o.y * 0.9),
		sin(TIME * 2.1 + o.z * 1.1) * 0.35,
		cos(TIME * 1.3 + o.z * 1.7 + o.y * 0.7)) * block_sway * gust;
	VERTEX += (inverse(MODEL_MATRIX) * vec4(off, 0.0)).xyz;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (foliage_should_discard(world_pos, FRAGCOORD.xy)) {
		discard;
	}
	vec3 an = abs(lnrm);
	vec2 uv;
	if (an.y >= an.x && an.y >= an.z) {
		uv = lpos.xz;
	} else if (an.x >= an.z) {
		uv = vec2(-lpos.z, -lpos.y);
	} else {
		uv = vec2(lpos.x, -lpos.y);
	}
	uv *= texel_scale;
	ALBEDO = texture(albedo_tex, uv).rgb * block_tint;
	NORMAL_MAP = texture(normal_tex, uv).rgb;
	NORMAL_MAP_DEPTH = 0.8;
	ROUGHNESS = 0.9;
	BACKLIGHT = ALBEDO * 0.25;
}
