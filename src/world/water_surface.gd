extends RefCounted
## 水材質、無重疊水面與局部反射共用入口，維持世界32px/m且不烘焙光影。

const Reflection := preload("res://src/world/water_reflection.gd")
const LAYER := 4
const PROBE_SPAN := 32.0
const PROBE_MARGIN := 6.0


static func material(flow := Vector2.ZERO, deep := Color(0.07, 0.19, 0.24), shallow := Color(0.16, 0.36, 0.38)) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/water.gdshader")
	mat.set_shader_parameter("normal_tex", Mats.tex("water_n"))
	mat.set_shader_parameter("flow", flow)
	mat.set_shader_parameter("deep", deep)
	mat.set_shader_parameter("shallow", shallow)
	return mat


static func add_surface(parent: Node3D, rects: Array, level: float, thickness: float, mat: ShaderMaterial) -> void:
	for rect: Rect2 in union_rects(rects):
		var center := rect.get_center()
		var mesh := Build.box(parent, Vector3(rect.size.x, thickness, rect.size.y),
			Vector3(center.x, level - thickness * 0.5, center.y), mat)
		mesh.name = "WaterSurface"
		mesh.layers = LAYER
		# 水仍接收陰影，但薄片不能把自身與旁邊的水壓成黑塊。
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.add_to_group("water_surfaces")


static func add_reflections(parent: Node3D, rects: Array, level: float, ground_masked := false) -> void:
	if rects.is_empty():
		return
	var bounds: Rect2 = rects[0]
	for rect: Rect2 in rects:
		bounds = bounds.merge(rect)
	var columns := maxi(1, ceili(bounds.size.x / PROBE_SPAN))
	var rows := maxi(1, ceili(bounds.size.y / PROBE_SPAN))
	var tile := bounds.size / Vector2(columns, rows)
	for y in rows:
		for x in columns:
			var center := bounds.position + tile * (Vector2(x, y) + Vector2.ONE * 0.5)
			var probe := Reflection.new()
			probe.name = "WaterReflection"
			probe.position = Vector3(center.x, level + 2.0, center.y)
			probe.size = Vector3(tile.x + PROBE_MARGIN * 2.0, 10.0, tile.y + PROBE_MARGIN * 2.0)
			probe.origin_offset = Vector3(0.0, -1.75, 0.0)
			probe.surface_rect = Rect2(bounds.position + tile * Vector2(x, y), tile)
			probe.surface_level = level
			probe.ground_masked = ground_masked
			probe.box_projection = true
			probe.cull_mask = 1 # 靜態場景；排除水面及有鏡頭朝向的角色紙片。
			probe.reflection_mask = LAYER
			probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
			probe.enable_shadows = true
			probe.update_mode = ReflectionProbe.UPDATE_ONCE
			probe.max_distance = 40.0
			parent.add_child(probe)


## 小水面優先共用附近水域的倒影，場景放完後才替未覆蓋區補一個局部探針。
static func share_reflection(parent: Node3D, rects: Array, level: float) -> void:
	parent.ready.connect(func() -> void: _ensure_coverage.call_deferred(parent, rects, level), CONNECT_ONE_SHOT)


static func _ensure_coverage(parent: Variant, rects: Array, level: float) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree() or parent.is_queued_for_deletion():
		return
	for rect: Rect2 in rects:
		for corner: Vector2 in [rect.position, rect.end, Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.position.y)]:
			var point: Vector3 = parent.to_global(Vector3(corner.x, level, corner.y))
			var covered := false
			for probe: ReflectionProbe in parent.get_tree().get_nodes_in_group("water_reflections"):
				if probe.get_world_3d() == parent.get_world_3d() and AABB(-probe.size * 0.5, probe.size).has_point(probe.to_local(point)):
					covered = true
					break
			if not covered:
				add_reflections(parent, rects, level)
				return


## 將矩形聯集切成互不重疊的長條，避免共面水片的深度競爭與重複繪製。
static func union_rects(rects: Array) -> Array[Rect2]:
	var xs: Array[float] = []
	for rect: Rect2 in rects:
		if not xs.has(rect.position.x):
			xs.append(rect.position.x)
		if not xs.has(rect.end.x):
			xs.append(rect.end.x)
	xs.sort()
	var result: Array[Rect2] = []
	for i in maxi(0, xs.size() - 1):
		var x0 := xs[i]
		var x1 := xs[i + 1]
		var intervals: Array[Vector2] = []
		for rect: Rect2 in rects:
			if rect.size.x > 0.0 and rect.size.y > 0.0 and rect.position.x <= x0 and rect.end.x >= x1:
				intervals.append(Vector2(rect.position.y, rect.end.y))
		intervals.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		var merged: Array[Vector2] = []
		for interval: Vector2 in intervals:
			if not merged.is_empty() and interval.x <= merged[-1].y:
				merged[-1].y = maxf(merged[-1].y, interval.y)
			else:
				merged.append(interval)
		for interval: Vector2 in merged:
			var strip := Rect2(x0, interval.x, x1 - x0, interval.y - interval.x)
			var extended := false
			for j in result.size():
				if is_equal_approx(result[j].end.x, x0) and is_equal_approx(result[j].position.y, strip.position.y) \
						and is_equal_approx(result[j].size.y, strip.size.y):
					result[j].size.x += strip.size.x
					extended = true
					break
			if not extended:
				result.append(strip)
	return result
