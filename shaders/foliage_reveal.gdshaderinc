// Only cut a viewing corridor in front of the player; keep the full shadow silhouette.
global uniform vec3 foliage_focus;
global uniform vec3 foliage_eye;
global uniform float foliage_reveal;

bool foliage_should_discard(vec3 world_pos, vec2 pixel) {
	if (foliage_reveal < 0.5 || IN_SHADOW_PASS) {
		return false;
	}
	vec3 ray = foliage_focus - foliage_eye;
	float length_squared = dot(ray, ray);
	if (length_squared < 0.01) {
		return false;
	}
	float along = dot(world_pos - foliage_eye, ray) / length_squared;
	// The feet sit slightly behind the chest focus plane in this pitched camera.
	// Include the sprite's full depth extent so lower leaf blocks cannot cover its legs.
	float far_limit = 1.0 + 0.8 / sqrt(length_squared);
	if (along <= 0.0 || along >= far_limit) {
		return false;
	}
	float distance_to_ray = length(world_pos - foliage_eye - ray * along);
	// Leave room for the wide weapon silhouette and foreground depth-of-field blur.
	float radius = 1.5 * along;
	float opening = 1.0 - smoothstep(radius * 0.7, radius, distance_to_ray);
	// Screen-aligned 2px Bayer cells line up through overlapping leaf blocks.
	const int bayer[16] = {0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5};
	ivec2 cell = ivec2(mod(floor(pixel / 2.0), 4.0));
	float threshold = (float(bayer[cell.y * 4 + cell.x]) + 0.5) / 16.0;
	return opening > threshold;
}
