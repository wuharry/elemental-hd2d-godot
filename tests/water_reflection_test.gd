extends SceneTree
## 實際世界的水面覆蓋、探針捕捉位置及日夜切換生命週期。

const Water := preload("res://src/world/water_surface.gd")
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


func _covered(point: Vector3, probes: Array[Node]) -> bool:
	for probe: ReflectionProbe in probes:
		if AABB(-probe.size * 0.5, probe.size).has_point(probe.to_local(point)):
			return true
	return false


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
			# 直接量測真實不透明池底幾何；不靠材質參數或工廠常數代替驗證。
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


func _test_capture_headroom(world: GameWorld) -> void:
	var clear := true
	var origins: Array[Vector3] = []
	for probe: ReflectionProbe in get_nodes_in_group("water_reflections"):
		if not probe.ground_masked:
			continue
		var origin := probe.to_global(probe.origin_offset)
		origins.append(origin)
		for mesh: MeshInstance3D in world.find_children("*", "MeshInstance3D", true, false):
			if not mesh.mesh is BoxMesh or (mesh.layers & 1) == 0:
				continue
			var material := mesh.get_active_material(0)
			if material is BaseMaterial3D and material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				continue
			var box := (mesh.global_transform * mesh.get_aabb()).grow(0.049)
			clear = clear and box.intersects_segment(origin, origin + Vector3.UP * 0.75) == null
	_check(clear, "%s reflection captures have actual primitive headroom, including backdrop cliffs and later river rocks" % world.def.id)
	print("%s water capture origins: %s" % [world.def.id, origins])


func _check_world(world: GameWorld, expected_count: int) -> void:
	var probes := get_nodes_in_group("water_reflections")
	var water := get_nodes_in_group("water_surfaces")
	var scene_id := world.def.id
	_check(probes.size() == expected_count, "%s uses %d bounded shared probes" % [scene_id, expected_count])
	var probes_ok := true
	var capture_clear := true
	for probe: ReflectionProbe in probes:
		probes_ok = probes_ok and probe.update_mode == ReflectionProbe.UPDATE_ONCE \
			and probe.cull_mask == (1 | TimeOfDay.REFLECTION_SUN_LAYER) \
			and probe.reflection_mask == 4 and probe.enable_shadows \
			and is_equal_approx(probe.max_distance, TimeOfDay.REFLECTION_CAPTURE_DISTANCE) \
			and probe.ambient_mode == ReflectionProbe.AMBIENT_DISABLED and probe.box_projection \
			and probe.size.x <= 44.0 and probe.size.z <= 44.0
		if probe.ground_masked:
			var origin: Vector3 = world.to_local(probe.to_global(probe.origin_offset))
			var xz := Vector2(origin.x, origin.z)
			# 地面確實以一公尺格心決定實體岸壁；不能只看抽象河道連續曲線。
			var cell := xz.floor() + Vector2.ONE * 0.5
			capture_clear = capture_clear and world.def.is_void(xz) and world.def.is_void(cell) \
				and not world.def.on_bridge(xz) and is_equal_approx(origin.y, probe.surface_level + 0.25)
			for bridge: Rect2 in world.def.bridges:
				capture_clear = capture_clear and not bridge.grow(0.75).has_point(xz)
	_check(probes_ok, "%s probes retain shadows, affect only water and exclude characters/water from capture" % scene_id)
	_check(capture_clear, "%s captures from exposed water above water level, outside solid banks and bridges" % scene_id)
	var surfaces_ok := true
	var coverage_ok := true
	for mesh: MeshInstance3D in water:
		var mat := mesh.material_override as ShaderMaterial
		surfaces_ok = surfaces_ok and mesh.layers == 4 \
			and mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF \
			and mat != null and mat.get_shader_parameter("normal_tex") is Texture2D
		var bounds := mesh.get_aabb()
		for x: float in [bounds.position.x + 0.005, bounds.end.x - 0.005]:
			for z: float in [bounds.position.z + 0.005, bounds.end.z - 0.005]:
				coverage_ok = coverage_ok and _covered(mesh.to_global(Vector3(x, bounds.end.y, z)), probes)
	_check(surfaces_ok, "%s water shares normal-mapped material and avoids self-cast shadows" % scene_id)
	_check(coverage_ok, "%s all water surfaces, including well and puddles, have local reflection coverage" % scene_id)


func _test_time_refresh(tod: TimeOfDay, probe: ReflectionProbe) -> void:
	tod.set_process(false)
	var initial := probe.position
	tod.set_time("night", true)
	tod.set_time("day", true)
	_check(probe.position == initial, "Instant changes defer capture until all lighting changes are applied")
	await process_frame
	_check(probe.position == initial, "Returning to the already captured lighting within one frame does not recapture")
	tod.set_time("night", true)
	tod.set_time("dusk", true)
	await process_frame
	var first := probe.position
	_check(first != initial and first.distance_to(initial) <= 0.0021,
		"Multiple changes to different lighting coalesce into one tiny transform refresh")
	await process_frame
	_check(probe.position == first, "Idle frames do not recapture probes")
	tod.set_time("dusk", true)
	await process_frame
	_check(probe.position == first, "Selecting the same effective lighting again does not recapture")
	tod.set_time("night")
	tod._process(tod.transition_time * 0.5)
	await process_frame
	_check(probe.position == first, "Smooth lighting transition does not recapture every frame")
	tod._process(tod.transition_time * 0.5)
	await process_frame
	var second := probe.position
	_check(second != first and is_equal_approx(tod.sun.light_energy, 0.5), "Completed transition refreshes after final night lighting is applied")
	_check(tod.reflection_sun.rotation.is_equal_approx(tod.sun.rotation)
		and tod.reflection_sun.light_color.is_equal_approx(tod.sun.light_color)
		and is_equal_approx(tod.reflection_sun.light_energy, tod.sun.light_energy),
		"Reflection shadows follow the same direction, color and intensity as the main lighting after a transition")
	_check(tod.sun.layers == TimeOfDay.MAIN_SUN_LAYER
		and tod.reflection_sun.layers == TimeOfDay.REFLECTION_SUN_LAYER
		and tod.sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		and tod.reflection_sun.directional_shadow_mode == DirectionalLight3D.SHADOW_ORTHOGONAL
		and tod.reflection_sun.shadow_enabled,
		"Main camera keeps four cascades and reflection capture has a separate shadow-casting light")
	tod.set_time("day", true)
	await process_frame
	_check(probe.position == first, "Refresh offset alternates without cumulative drift")


func _run() -> void:
	_test_union()
	var expected := {"village": 1, "forest": 3, "snow": 0, "dungeon": 4}
	var tod: TimeOfDay
	for scene_id: String in Scenes.LIST:
		var world := GameWorld.new(Scenes.make(scene_id))
		root.add_child(world)
		if scene_id == "village":
			_test_pond_basin(world)
		elif scene_id == "forest":
			_test_river_bed(world)
		if scene_id in ["forest", "dungeon"]:
			_test_capture_headroom(world)
		# 遊戲也在 ready 後立即合批；補覆蓋的 deferred 不能丟失小水面的父節點。
		Batcher.batch(world)
		if tod == null:
			tod = TimeOfDay.new()
			root.add_child(tod)
		tod.apply_scene(world.def)
		tod.set_time("day", true)
		await process_frame
		_check_world(world, expected[scene_id])
		var probes := get_nodes_in_group("water_reflections")
		if scene_id == "village":
			await _test_time_refresh(tod, probes[0])
		if not probes.is_empty():
			var probe: ReflectionProbe = probes[0]
			var previous := probe.position
			tod.set_time("night", true)
			await process_frame
			_check(probe.position != previous, "%s newly built scene responds to existing time-of-day refresh" % scene_id)
		# 模擬切場景時仍有一個已排程的 refresh，舊探針不能留在群組或回呼已釋放節點。
		tod.set_time("day", true)
		world.free()
		await process_frame
		_check(get_nodes_in_group("water_reflections").is_empty(), "%s probes leave group when scene is removed" % scene_id)
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
