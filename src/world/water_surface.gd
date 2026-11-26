extends RefCounted
## 水材質、無重疊水面與平面鏡像水反共用入口，維持世界32px/m且不烘焙光影。

const Reflection := preload("res://src/world/water_reflection.gd")
const LAYER := 4


static func material(flow := Vector2.ZERO, deep := Color(0.05, 0.16, 0.22), shallow := Color(0.14, 0.36, 0.40)) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/water.gdshader")
	mat.set_shader_parameter("normal_tex", Mats.tex("water_n"))
	mat.set_shader_parameter("flow", flow)
	mat.set_shader_parameter("deep", deep)
	mat.set_shader_parameter("shallow", shallow)
	mat.set_shader_parameter("has_reflection", 0.0)
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
		mesh.set_meta("water_level", level)
		mesh.set_meta("water_area", rect.get_area())
		mesh.add_to_group("water_surfaces")


static func _total_area(rects: Array) -> float:
	var area := 0.0
	for rect: Rect2 in union_rects(rects):
		area += rect.get_area()
	return area


static func _find_owner(parent: Node) -> Node:
	var cur := parent
	while cur != null:
		if cur is GameWorld:
			return cur
		cur = cur.get_parent()
	return parent


static func _ensure_world_reflection(parent: Node3D, rects: Array, level: float) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree() or parent.is_queued_for_deletion():
		return
	var host := _find_owner(parent)
	var world_level := parent.to_global(Vector3(0.0, level, 0.0)).y
	var area := _total_area(rects)
	var existing: Reflection = null
	for node in host.get_children():
		if node is Reflection:
			existing = node as Reflection
			break
	if existing == null:
		existing = Reflection.new()
		existing.name = "WaterReflection"
		existing.register_surface(world_level, area)
		host.add_child(existing)
	else:
		existing.register_surface(world_level, area)


static func add_reflections(parent: Node3D, rects: Array, level: float, _ground_masked := false) -> void:
	if rects.is_empty():
		return
	if parent.is_inside_tree():
		_ensure_world_reflection(parent, rects, level)
	else:
		parent.ready.connect(func() -> void: _ensure_world_reflection(parent, rects, level), CONNECT_ONE_SHOT)


## 小水面優先共用同場景的平面鏡像反射；場景放完後若仍無反射節點才補建一個。
static func share_reflection(parent: Node3D, rects: Array, level: float) -> void:
	parent.ready.connect(func() -> void: _ensure_coverage.call_deferred(parent, rects, level), CONNECT_ONE_SHOT)


static func _ensure_coverage(parent: Variant, rects: Array, level: float) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree() or parent.is_queued_for_deletion():
		return
	var host := _find_owner(parent)
	for node in host.get_children():
		if node is Reflection:
			return
	_ensure_world_reflection(parent, rects, level)


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
