shader_type spatial;

uniform vec3 crystal_size = vec3(0.26, 0.82, 0.26);
instance uniform float effect_time = 0.0;
varying vec3 local_position;
varying vec3 local_normal;

void vertex() {
	local_position = VERTEX;
	local_normal = NORMAL;
}

void fragment() {
	vec3 cell = (floor(local_position * 32.0) + 0.5) / 32.0;
	// A PrismMesh narrows from full width at its foot to zero at its tip.
	// Profile distance describes the front/back triangle border only. On a
	// sloping face every point lies on that profile, so instead trace the Z
	// extrusion edges and the tip/base. Leave the interior of each face blue.
	float half_width = crystal_size.x * (0.25 - 0.5 * cell.y / crystal_size.y);
	float profile_distance = abs(half_width - abs(cell.x));
	float z_distance = abs(crystal_size.z * 0.5 - abs(cell.z));
	float y_distance = abs(crystal_size.y * 0.5 - abs(cell.y));
	float border_distance;
	if (abs(local_normal.z) > 0.5) {
		border_distance = min(profile_distance, y_distance);
	} else if (local_normal.y < -0.5) {
		border_distance = min(abs(crystal_size.x * 0.5 - abs(cell.x)), z_distance);
	} else {
		border_distance = min(z_distance, y_distance);
	}
	float edge = 1.0 - step(0.03125, border_distance);
	float facet = clamp(abs(local_normal.x) * 0.65 + max(local_normal.z, 0.0) * 0.35, 0.0, 1.0);
	float height_t = clamp((cell.y / max(crystal_size.y, 0.01)) + 0.5, 0.0, 1.0);
	// Subtle internal glacial fracture shimmer moving gently upward.
	float glint = smoothstep(0.84, 0.98, sin((cell.y * 26.0 - cell.x * 18.0) - effect_time * 2.2));
	vec3 deep_ice = vec3(0.014, 0.16, 0.38);
	vec3 bright_ice = vec3(0.04, 0.40, 0.62);
	vec3 blue = mix(deep_ice, bright_ice, clamp(facet * 0.8 + height_t * 0.2, 0.0, 1.0));
	ALBEDO = blue;
	EMISSION = blue * (0.42 + glint * 0.25) + vec3(0.08, 0.76, 1.0) * edge * (3.0 + 0.45 * sin(effect_time * 2.8));
	ROUGHNESS = 0.12;
	SPECULAR = 0.82;
}
