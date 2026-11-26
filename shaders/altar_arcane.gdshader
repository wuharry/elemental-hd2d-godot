shader_type spatial;
render_mode unshaded;

uniform vec3 violet_color : source_color = vec3(0.702, 0.353, 0.886);
uniform vec3 ruby_color : source_color = vec3(0.9373, 0.2510, 0.3412);
uniform bool instance_gradient = true;
varying float gradient_position;
varying vec3 local_position;

void vertex() {
	local_position = VERTEX / (instance_gradient ? 1.0 : 0.18);
	// Rune edges are unit cubes extended along local Y. Each endpoint carries
	// its place on the same spatial violet-to-ruby field, so joins stay smooth.
	if (instance_gradient) {
		gradient_position = mix(INSTANCE_CUSTOM.x, INSTANCE_CUSTOM.y, VERTEX.y + 0.5);
	} else {
		gradient_position = clamp((VERTEX.x + VERTEX.y) / 0.36 + 0.5, 0.0, 1.0);
	}
}

void fragment() {
	float ramp = smoothstep(0.24, 0.76, gradient_position);
	vec3 color = mix(violet_color, ruby_color, ramp);
	float edge = min(abs(local_position.x), abs(local_position.z));
	float core = 1.0 - smoothstep(0.06, 0.26, edge);
	vec3 saturated = pow(color, vec3(2.8));
	float luminance = max(dot(saturated, vec3(0.2126, 0.7152, 0.0722)), 0.001);
	ALBEDO = mix(color * 1.15, saturated * 1.5 / luminance, core);
}
