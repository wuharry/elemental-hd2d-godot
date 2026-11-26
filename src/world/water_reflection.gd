extends ReflectionProbe
## 快取附近景物，補上螢幕外的倒影。只在光影時段完成切換時重新捕捉。

const GROUP := "water_reflections"
var surface_rect := Rect2()
var surface_level := 0.0
var ground_masked := false
var _refresh_pending := false
var _requested_lighting: Dictionary = {}
var _last_lighting: Dictionary = {}
var _rest_position := Vector3.ZERO
var _offset_sign := -1.0


func _ready() -> void:
	_rest_position = position
	add_to_group(GROUP)
	if ground_masked:
		_place_capture_over_water()
		var world := _world()
		if world != null:
			# populate 的後半段還會放瀑布和河石；世界 ready 才做最後一次定位，
			# 此時尚未合批，仍能用真正方塊判斷遮擋，不能拿巨大合批包圍盒代替。
			world.ready.connect(_place_capture_over_water, CONNECT_ONE_SHOT)


func _world() -> GameWorld:
	var world := get_parent()
	while world != null and not world is GameWorld:
		world = world.get_parent()
	return world as GameWorld


## 河面矩形有大部分藏在河岸下；拍攝點必須落在真正露出的水域，避開橋底。
func _place_capture_over_water() -> void:
	var world := _world()
	if world == null:
		return
	var def: SceneDef = world.def
	var capture_y: float = get_parent().to_global(Vector3(0, surface_level + 0.25, 0)).y
	var blockers: Array[AABB] = []
	for node in world.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if not mesh.mesh is BoxMesh or (mesh.layers & cull_mask) == 0:
			continue
		var material := mesh.get_active_material(0)
		if material is BaseMaterial3D and material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			continue
		var box := (mesh.global_transform * mesh.get_aabb()).grow(0.05)
		if box.position.y <= capture_y + 0.75 and box.end.y >= capture_y:
			blockers.append(box)
	var best_distance := INF
	var best := global_position + global_basis * origin_offset
	# 寬河優先離岸一公尺；只有兩格寬的水道改用較小岸距，橋距不縮小。
	for clearance: float in [1.0, 0.4]:
		for z in range(floori(surface_rect.position.y), ceili(surface_rect.end.y)):
			for x in range(floori(surface_rect.position.x), ceili(surface_rect.end.x)):
				var local := Vector3(x + 0.5, surface_level + 0.25, z + 0.5)
				if not surface_rect.has_point(Vector2(local.x, local.z)):
					continue
				var candidate: Vector3 = get_parent().to_global(local)
				var p: Vector3 = world.to_local(candidate)
				var clear := true
				for offset: Vector2 in [Vector2.ZERO, Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
					if not def.is_void(Vector2(p.x, p.z) + offset * clearance) or def.on_bridge(Vector2(p.x, p.z) + offset):
						clear = false
						break
				if clear:
					for box: AABB in blockers:
						if candidate.x >= box.position.x and candidate.x <= box.end.x \
								and candidate.z >= box.position.z and candidate.z <= box.end.z:
							clear = false
							break
				var distance := candidate.distance_squared_to(global_position)
				if clear and distance < best_distance:
					best_distance = distance
					best = candidate
		if is_finite(best_distance):
			break
	if is_finite(best_distance):
		origin_offset = to_local(best)


## 同一幀的請求以最後的光影為準。空字典供需要重新捕捉場景幾何的呼叫使用。
func refresh(lighting: Dictionary = {}) -> void:
	_requested_lighting = lighting
	if _refresh_pending:
		return
	_refresh_pending = true
	_refresh.call_deferred()


func _refresh() -> void:
	_refresh_pending = false
	if not is_inside_tree() or is_queued_for_deletion():
		return
	if not _requested_lighting.is_empty() and _requested_lighting == _last_lighting:
		return
	_last_lighting = _requested_lighting
	# UPDATE_ONCE 依 transform 變更重拍；來回位移避免多次切換後累積漂移。
	_offset_sign = -_offset_sign
	position = _rest_position + Vector3(0.001 * _offset_sign, 0.0, 0.0)
