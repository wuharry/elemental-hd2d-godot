shader_type spatial;

uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_nearest_mipmap, repeat_enable;
uniform vec3 rock_tint : source_color = vec3(0.78, 0.68, 0.52);
instance uniform float effect_time = 0.0;
varying vec3 local_position;
varying vec3 local_weights;

void vertex() {
	local_position = VERTEX;
	local_weights = pow(abs(NORMAL), vec3(60.0));
	local_weights /= dot(local_weights, vec3(1.0));
	vec3 n = abs(NORMAL);
	TANGENT = normalize(vec3(n.y + n.z, 0.0, -n.x));
	BINORMAL = normalize(vec3(0.0, n.x + n.z, -n.y));
}

void fragment() {
	// The rock's source texture remains local triplanar at 32 px/m. Geomantic
	// fissures follow that same grid, pulsing with golden-ochre earth magic.
	vec3 p = local_position * vec3(0.5, -0.5, 0.5);
	vec3 stone = texture(albedo_tex, p.xy).rgb * local_weights.z
		+ texture(albedo_tex, p.xz).rgb * local_weights.y
		+ texture(albedo_tex, vec2(-p.z, p.y)).rgb * local_weights.x;
	NORMAL_MAP = texture(normal_tex, p.xy).rgb * local_weights.z
		+ texture(normal_tex, p.xz).rgb * local_weights.y
		+ texture(normal_tex, vec2(-p.z, p.y)).rgb * local_weights.x;
	vec3 cell = floor(local_position * 32.0);
	float seam_x = cell.x - floor(cell.y * 0.45) - floor(sin(cell.z * 0.85) * 1.5);
	float seam_z = cell.z + floor(cell.y * 0.55) + 2.0;
	float seam_y = cell.y + floor(sin((cell.x - cell.z) * 0.6) * 1.4);
	float dist = min(min(abs(seam_x), abs(seam_z)), abs(seam_y) + 0.35);
	float crack = 1.0 - step(0.32, dist);
	float pulse = 0.78 + 0.22 * sin(effect_time * 2.2 + local_position.y * 5.0);
	// Warm geomantic golden-amber (distinct from Fire's red-orange flames).
	vec3 ley_gold = vec3(1.0, 0.68, 0.16);
	ALBEDO = mix(stone * rock_tint, ley_gold * 0.65, crack);
	EMISSION = ley_gold * crack * (4.6 * pulse);
	NORMAL_MAP_DEPTH = mix(1.3, 0.0, crack);
	ROUGHNESS = 0.94;
}
