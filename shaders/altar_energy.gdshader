shader_type spatial;
render_mode unshaded;

uniform vec3 energy_color : source_color = vec3(0.35, 0.65, 1.0);
uniform float core_luminance = 2.2;
varying vec3 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	// Unit boxes become beams along Y. Keep their outer color while the narrow
	// inner stroke supplies HDR to glow; unshaded ignores EMISSION entirely.
	float edge = min(abs(local_position.x), abs(local_position.z));
	float core = 1.0 - smoothstep(0.12, 0.43, edge);
	vec3 saturated = pow(energy_color, vec3(1.35));
	float luminance = max(dot(saturated, vec3(0.2126, 0.7152, 0.0722)), 0.001);
	ALBEDO = mix(energy_color * 1.15, saturated * core_luminance / luminance, core);
}
