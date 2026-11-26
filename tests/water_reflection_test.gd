extends SceneTree
## 實際世界的水面覆蓋、平面鏡像反射相機數學、各場景主水位及日夜光影同步。

const Water := preload("res://src/world/water_surface.gd")
const Reflection := preload("res://src/world/water_reflection.gd")
const Batcher := preload("res://src/world/mesh_batcher.gd")
var _passed := 0
var _failed := 0


func _init() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		printerr("FAIL: ", message)


func _test_union() -> void:
	var original := [Rect2(-8.5, 6, 5.5, 3.5), Rect2(-7.5, 5.25, 3.5, 5), Rect2(-9.25, 7, 1.5, 1.75)]
	var tiles := Water.union_rects(original)
	var area := 0.0
	var disjoint := true
	for i in tiles.size():
		area += tiles[i].get_area()
		for j in range(i + 1, tiles.size()):
			disjoint = disjoint and not tiles[i].intersects(tiles[j])
	_check(disjoint and is_equal_approx(area, 25.8125), "Pond union preserves area without overlapping top faces")
	var same_coverage := true
	for yi in range(42, 82):
		for xi in range(-74, -24):
			var p := Vector2(xi + 0.5, yi + 0.5) * 0.125
			var before := false
			var after := false
			for rect: Rect2 in original:
				before = before or rect.has_point(p)
			for rect: Rect2 in tiles:
				after = after or rect.has_point(p)
			same_coverage = same_coverage and before == after
	_check(same_coverage, "Pond outline remains identical after removing overlap")


func _test_mirror_math() -> void:
	var plane_y := 0.08
	var basis := Basis.from_euler(Vector3(deg_to_rad(-33.0), deg_to_rad(22.0), 0.0))
	var src := Transform3D(basis, Vector3(6.5, 16.3, 24.0))
	var dst := Reflection.mirror_transform(src, plane_y)
	_check(is_equal_approx(dst.origin.x, src.origin.x)
		and is_equal_approx(dst.origin.z, src.origin.z)
		and is_equal_approx(dst.origin.y, 2.0 * plane_y - src.origin.y),
		"Mirrored camera reflects Y across the exact water plane")
	_check(is_equal_approx(dst.basis.determinant(), 1.0)
		and dst.basis.get_scale().is_equal_approx(Vector3.ONE),
		"Mirrored camera preserves a right-handed unit-scale basis without inverted culling")
	# 水面上任意一點在鏡像相機的局部座標須為 (x_cam, -y_cam, z_cam)，對應 UV (u, 1 - v)。
	var water_point := Vector3(-5.2, plane_y, 7.4)
	var local_main := src.affine_inverse() * water_point
	var local_refl := dst.affine_inverse() * water_point
	_check(is_equal_approx(local_refl.x, local_main.x)
		and is_equal_approx(local_refl.y, -local_main.y)
		and is_equal_approx(local_refl.z, local_main.z),
		"Water-plane points project to exact (u, 1 - v) coordinates in the mirrored camera")


func _inside_any(p: Vector2, rects: Array) -> bool:
	for rect: Rect2 in rects:
		if rect.has_point(p):
			return true
	return false


func _footprint(mesh: MeshInstance3D) -> Rect2:
	var bounds := mesh.global_transform * mesh.get_aabb()
	return Rect2(bounds.position.x, bounds.position.z, bounds.size.x, bounds.size.z)


func _test_pond_basin(world: GameWorld) -> void:
	var shoreline := world.def.ponds
	var ground: Array[Rect2] = []
	for node in world.get_child(0).find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var material := mesh.material_override as ShaderMaterial
		if material != null and material.shader.resource_path == "res://shaders/ground.gdshader":
			ground.append(_footprint(mesh))
	var pond: Node3D
	var water_area := 0.0
	for mesh: MeshInstance3D in get_nodes_in_group("water_surfaces"):
		if is_equal_approx((mesh.global_transform * mesh.get_aabb()).end.y, 0.08):
			pond = mesh.get_parent()
			water_area += _footprint(mesh).get_area()
	_check(pond != null and is_equal_approx(water_area, 25.8125), "Actual pond retains original water height and shoreline area")
	if pond == null:
		return
	var floors: Array[Dictionary] = []
	var border: Array[Rect2] = []
	var colliders: Array[Rect2] = []
	for node in pond.get_children():
		if node is MeshInstance3D:
			var bounds: AABB = node.global_transform * node.get_aabb()
			if bounds.end.y < -0.1:
				floors.append({"rect": _footprint(node), "top": bounds.end.y})
			elif String(node.name).contains("PondBorder"):
				border.append(_footprint(node))
		elif node is StaticBody3D:
			var shape := node.get_child(0) as CollisionShape3D
			var size := (shape.shape as BoxShape3D).size
			colliders.append(Rect2(node.position.x - size.x * 0.5, node.position.z - size.z * 0.5, size.x, size.z))
	var collision_unchanged := colliders.size() == shoreline.size()
	for rect: Rect2 in shoreline:
		collision_unchanged = collision_unchanged and colliders.has(rect)
	_check(collision_unchanged, "Pond collision footprints stay identical to original shoreline rectangles")
	var outer: Array[Rect2] = []
	var region: Rect2 = shoreline[0]
	for rect: Rect2 in shoreline:
		outer.append(rect.grow(0.25))
		region = region.merge(rect)
	region = region.grow(0.5)
	var ground_cut_exact := true
	var border_exact := true
	var bottom_complete := true
	var shallow_count := 0
	var deep_count := 0
	for y in range(floori(region.position.y * 8), ceili(region.end.y * 8)):
		for x in range(floori(region.position.x * 8), ceili(region.end.x * 8)):
			var p := Vector2(x + 0.5, y + 0.5) * 0.125
			var wet := _inside_any(p, shoreline)
			ground_cut_exact = ground_cut_exact and _inside_any(p, ground) != wet
			border_exact = border_exact and _inside_any(p, border) == (_inside_any(p, outer) and not wet)
			var bottom := -INF
			for floor: Dictionary in floors:
				if (floor["rect"] as Rect2).has_point(p):
					bottom = maxf(bottom, floor["top"])
			if wet:
				var depth := 0.08 - bottom
				bottom_complete = bottom_complete and depth >= 0.2 and depth <= 0.75
				if depth < 0.35:
					shallow_count += 1
				elif depth > 0.45:
					deep_count += 1
			else:
				bottom_complete = bottom_complete and is_inf(bottom)
	_check(ground_cut_exact, "Actual ground removes the exact fractional pond union and preserves surrounding land")
	_check(border_exact, "Dirt border stays on the exterior 0.25 m strip and never hides the pond bottom")
	_check(bottom_complete and shallow_count > 0 and deep_count > shallow_count,
		"Visible pond bottom covers every wet point, with a shallow shelf and a larger deeper center")


func _river_depth(p: Vector2, floors: Array[Dictionary], level: float) -> float:
	var top := -INF
	for floor: Dictionary in floors:
		if (floor["rect"] as Rect2).has_point(p):
			top = maxf(top, floor["top"])
	return level - top


func _test_river_bed(world: GameWorld) -> void:
	var water := get_nodes_in_group("water_surfaces")[0] as MeshInstance3D
	var bounds := water.global_transform * water.get_aabb()
	var level := bounds.end.y
	var area := _footprint(water)
	_check(is_equal_approx(level, -0.4) and area == Rect2(-16, -48, 28, 96) \
		and water.material_override.get_shader_parameter("flow") == Vector2(0.15, 0.9),
		"River keeps original waterline, rectangular fill and current direction")
	var floors: Array[Dictionary] = []
	var bed_area := 0.0
	for node in water.get_parent().get_children():
		if node is MeshInstance3D and String(node.name).contains("RiverBed"):
			var box: AABB = node.global_transform * node.get_aabb()
			var footprint := _footprint(node)
			floors.append({"rect": footprint, "top": box.end.y})
			bed_area += footprint.get_area()
	var ground: Array[Rect2] = []
	for node in world.get_child(0).find_children("*", "MeshInstance3D", true, false):
		var material := node.material_override as ShaderMaterial
		if material != null and material.shader.resource_path == "res://shaders/ground.gdshader":
			ground.append(_footprint(node))
	var cells := 0
	var coverage := true
	var ground_clear := true
	var depths: Array[float] = []
	for z in range(-48, 48):
		for x in range(-16, 12):
			var p := Vector2(x + 0.5, z + 0.5)
			var wet := world.def.is_void(p)
			var depth := _river_depth(p, floors, level)
			if wet:
				cells += 1
				coverage = coverage and depth >= 0.29 and depth <= 1.01
				ground_clear = ground_clear and not _inside_any(p, ground)
				var rounded := snappedf(depth, 0.1)
				if not depths.has(rounded):
					depths.append(rounded)
			else:
				coverage = coverage and is_inf(depth)
	_check(coverage and is_equal_approx(bed_area, float(cells)), "Merged riverbed covers exactly all wet ground cells without gaps or overlapping area")
	_check(ground_clear and depths.size() == 3, "No grass slab hides the riverbed, which has three actual geometric depth bands")
	var sections_ok := true
	for section: Vector2 in [Vector2(-10, -30.5), Vector2(6, 24.5)]:
		var bank_left := _river_depth(section + Vector2(-1.5, 0), floors, level)
		var center_left := _river_depth(section + Vector2(-0.5, 0), floors, level)
		var center_right := _river_depth(section + Vector2(0.5, 0), floors, level)
		var bank_right := _river_depth(section + Vector2(1.5, 0), floors, level)
		sections_ok = sections_ok and bank_left < center_left - 0.5 and bank_right < center_right - 0.5
	_check(sections_ok, "Both straight river cross-sections have genuinely deeper centers than either shore")
	_check(is_finite(_river_depth(Vector2(-2.5, 0.5), floors, level)), "Riverbed continues beneath the existing bridge")


func _check_world(world: GameWorld, expected_count: int, expected_level: float) -> void:
	var refls := get_nodes_in_group("water_reflections")
	var water := get_nodes_in_group("water_surfaces")
	var scene_id := world.def.id
	_check(refls.size() == expected_count, "%s uses %d shared planar reflection controller" % [scene_id, expected_count])
	if expected_count > 0:
		var refl := refls[0] as Reflection
		_check(refl != null and refl.viewport != null and refl.camera != null,
			"%s planar reflection owns a SubViewport and mirrored Camera3D" % scene_id)
		_check(is_equal_approx(refl.surface_level, expected_level),
			"%s locks planar reflection plane to primary water level %.2f" % [scene_id, expected_level])
		_check(refl.camera.cull_mask == Reflection.CULL_MASK
			and (refl.camera.cull_mask & Water.LAYER) == 0
			and (refl.camera.cull_mask & 2) != 0
			and (refl.camera.cull_mask & TimeOfDay.MAIN_SUN_LAYER) == 0,
			"%s reflection camera reflects world + player + reflection sun and excludes water/main sun" % scene_id)
		var probe_cam := Camera3D.new()
		probe_cam.fov = 25.0
		probe_cam.global_transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-33.0), deg_to_rad(22.0), 0.0)), Vector3(0, 16.0, 24.0))
		root.add_child(probe_cam)
		refl.sync_to_camera(probe_cam, Vector2(1600, 900))
		_check(refl.viewport.size == Vector2i(800, 450)
			and is_equal_approx(refl.camera.fov, 25.0)
			and is_equal_approx(refl.camera.global_position.y, 2.0 * expected_level - 16.0),
			"%s planar camera mirrors main camera at half viewport resolution" % scene_id)
		probe_cam.free()
	var surfaces_ok := true
	for mesh: MeshInstance3D in water:
		var mat := mesh.material_override as ShaderMaterial
		surfaces_ok = surfaces_ok and mesh.layers == Water.LAYER \
			and mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF \
			and mat != null and mat.get_shader_parameter("normal_tex") is Texture2D \
			and mat.get_shader_parameter("reflection_tex") is ViewportTexture
	_check(surfaces_ok, "%s water surfaces share normal/planar-reflection parameters and avoid self-cast shadows" % scene_id)


func _test_time_sync(tod: TimeOfDay) -> void:
	tod.set_process(false)
	tod.set_time("night")
	tod._process(tod.transition_time)
	await process_frame
	_check(is_equal_approx(tod.sun.light_energy, 0.5)
		and tod.reflection_sun.rotation.is_equal_approx(tod.sun.rotation)
		and tod.reflection_sun.light_color.is_equal_approx(tod.sun.light_color)
		and is_equal_approx(tod.reflection_sun.light_energy, tod.sun.light_energy),
		"Reflection sun follows main lighting direction, color and intensity after transition")
	_check(tod.sun.layers == TimeOfDay.MAIN_SUN_LAYER
		and tod.reflection_sun.layers == TimeOfDay.REFLECTION_SUN_LAYER
		and tod.sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		and tod.reflection_sun.directional_shadow_mode == DirectionalLight3D.SHADOW_ORTHOGONAL
		and tod.reflection_sun.shadow_enabled,
		"Main camera keeps four cascades and planar reflection keeps orthogonal shadow light")


func _run() -> void:
	_test_union()
	_test_mirror_math()
	var expected := {
		"village": {"count": 1, "level": 0.08},
		"forest": {"count": 1, "level": -0.4},
		"snow": {"count": 0, "level": 0.0},
		"dungeon": {"count": 1, "level": -0.3},
	}
	var tod: TimeOfDay
	for scene_id: String in Scenes.LIST:
		var world := GameWorld.new(Scenes.make(scene_id))
		root.add_child(world)
		if scene_id == "village":
			_test_pond_basin(world)
		elif scene_id == "forest":
			_test_river_bed(world)
		Batcher.batch(world)
		if tod == null:
			tod = TimeOfDay.new()
			root.add_child(tod)
		tod.apply_scene(world.def)
		tod.set_time("day", true)
		await process_frame
		_check_world(world, expected[scene_id]["count"], expected[scene_id]["level"])
		if scene_id == "village":
			await _test_time_sync(tod)
		tod.set_time("day", true)
		world.free()
		await process_frame
		_check(get_nodes_in_group("water_reflections").is_empty(), "%s planar reflection leaves group when scene is removed" % scene_id)
	tod.free()
	# 未進場的小水面也可能在第一次 deferred coverage 前就移除。
	var puddle := SetPieces.puddle(Vector2.ONE)
	root.add_child(puddle)
	puddle.free()
	await process_frame
	_check(get_nodes_in_group("water_reflections").is_empty(), "Deferred small-water coverage safely ignores a freed surface")
	Mats.reset()
	print("water reflections: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed else 0)
