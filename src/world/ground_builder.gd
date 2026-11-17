class_name GroundBuilder
extends RefCounted
## 地面：核心區切成 1 公尺的格子，跳過空洞（河、裂谷、水道），其餘合併成大方塊鋪上去。
## 方塊有厚度，所以空洞邊緣看得到岸壁。外圍依場景設定加台地或牆當背景。

const CELL := 1.0
const THICKNESS := 8.0


static func build(def: SceneDef) -> Node3D:
	var root := Node3D.new()
	var mat := _material(def)

	# --- 核心區：逐列找出「不是空洞」的連續區段，上下相同的區段合併成一塊 ---
	var half := int(def.world_size * 0.5)
	var open: Dictionary = {}   # "x0:x1" → 起始列 z
	for zi in range(-half, half + 1):
		var runs: Array = []
		if zi < half:
			var start := -half
			var inside := false
			for xi in range(-half, half + 1):
				var solid := xi < half and not def.is_void(Vector2(xi + 0.5, zi + 0.5) * CELL)
				if solid and not inside:
					start = xi
					inside = true
				elif not solid and inside:
					runs.append("%d:%d" % [start, xi])
					inside = false
		# 這一列沒有延續下去的區段，在這裡收尾成方塊
		for key in open.keys():
			if not runs.has(key):
				_slab(root, key, int(open[key]), zi, mat)
				open.erase(key)
		for key in runs:
			if not open.has(key):
				open[key] = zi

	# --- 外圍一圈大地 ---
	if def.outer_ground:
		var h := def.world_size * 0.5
		var far := 110.0
		_box(root, Rect2(-far, -far, far * 2.0, far - h), mat)
		_box(root, Rect2(-far, h, far * 2.0, far - h), mat)
		_box(root, Rect2(-far, -h, far - h, h * 2.0), mat)
		_box(root, Rect2(h, -h, far - h, h * 2.0), mat)

	# --- 可走的平面 + 活動範圍的隱形牆 + 空洞的隱形牆 ---
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	floor_body.add_child(shape)
	root.add_child(floor_body)
	var hx := def.play_half.x
	var hz := def.play_half.y
	Build.collider(root, Vector3(hx * 2.0 + 2.0, 6.0, 1.0), Vector3(0, 3.0, hz + 0.5))
	Build.collider(root, Vector3(hx * 2.0 + 2.0, 6.0, 1.0), Vector3(0, 3.0, -hz - 0.5))
	Build.collider(root, Vector3(1.0, 6.0, hz * 2.0 + 2.0), Vector3(hx + 0.5, 3.0, 0))
	Build.collider(root, Vector3(1.0, 6.0, hz * 2.0 + 2.0), Vector3(-hx - 0.5, 3.0, 0))
	_void_colliders(root, def)

	match def.backdrop.get("kind", "none"):
		"terraces":
			_terraces(root, def)
		"walls":
			_walls(root, def)
	return root


static func _material(def: SceneDef) -> ShaderMaterial:
	var g: Dictionary = def.ground
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ground.gdshader")
	for layer in ["base", "dirt", "path", "side"]:
		var name: String = g[layer]
		mat.set_shader_parameter(layer + "_tex", Mats.tex(name))
		mat.set_shader_parameter(layer + "_n", Mats.normal_or_flat(name))
		mat.set_shader_parameter(layer + "_tint", g[layer + "_tint"])
	mat.set_shader_parameter("mask_tex", _mask(def))
	mat.set_shader_parameter("world_size", def.world_size)
	mat.set_shader_parameter("texel_scale", Mats.TEXEL_SCALE)
	mat.set_shader_parameter("path_roughness", g.get("path_roughness", 0.78))
	mat.set_shader_parameter("base_roughness", g.get("base_roughness", 1.0))
	return mat


static func _slab(root: Node3D, key: String, z0: int, z1: int, mat: Material) -> void:
	var parts := key.split(":")
	var x0 := int(parts[0])
	var x1 := int(parts[1])
	_box(root, Rect2(x0 * CELL, z0 * CELL, (x1 - x0) * CELL, (z1 - z0) * CELL), mat)


static func _box(root: Node3D, r: Rect2, mat: Material) -> void:
	var c := r.get_center()
	var mi := Build.box(root, Vector3(r.size.x, THICKNESS, r.size.y), Vector3(c.x, -THICKNESS * 0.5, c.y), mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## 活動範圍內的空洞擋起來（橋面除外），角色才不會走到水上或裂谷上。
static func _void_colliders(root: Node3D, def: SceneDef) -> void:
	var hx := int(def.play_half.x) + 1
	var hz := int(def.play_half.y) + 1
	for zi in range(-hz, hz):
		var start := 0
		var inside := false
		for xi in range(-hx, hx + 1):
			var p := Vector2(xi + 0.5, zi + 0.5) * CELL
			var blocked := xi < hx and def.is_void(p) and not def.on_bridge(p)
			if blocked and not inside:
				start = xi
				inside = true
			elif not blocked and inside:
				inside = false
				var w := (xi - start) * CELL
				Build.collider(root, Vector3(w, 4.0, CELL), Vector3(start * CELL + w * 0.5, 2.0, (zi + 0.5) * CELL))


## 路徑遮罩：R = 路面、G = 裸土。256px 蓋整個核心區，shader 裡再對齊像素格。
static func _mask(def: SceneDef) -> ImageTexture:
	var res := 256
	var img := Image.create(res, res, false, Image.FORMAT_RGB8)
	for y in res:
		for x in res:
			var p := Vector2((x + 0.5) / res - 0.5, (y + 0.5) / res - 0.5) * def.world_size
			img.set_pixel(x, y, Color(def.path_at(p), def.dirt_at(p), 0.0))
	return ImageTexture.create_from_image(img)


## 背景台地：畫面深處一層一層墊高，上面種針葉林，擋住地平線。
static func _terraces(root: Node3D, def: SceneDef) -> void:
	var b: Dictionary = def.backdrop
	var cliff := Mats.tri("stone_wall", b["cliff_tint"], 0.95, 1.5)
	var top := Mats.tri(b["top"])
	var snow: bool = b.get("snow", false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var steps := [
		{"z": -27.0, "h": 2.0, "depth": 10.0},
		{"z": -35.0, "h": 4.5, "depth": 12.0},
		{"z": -46.0, "h": 8.0, "depth": 20.0},
	]
	for st in steps:
		var z: float = st["z"]
		var h: float = st["h"]
		var depth: float = st["depth"]
		# 分段錯開，邊緣才不會是一條直線
		var x := -70.0
		while x < 70.0:
			var seg := rng.randf_range(7.0, 14.0)
			var zo := snappedf(rng.randf_range(-1.5, 1.5), 0.5)
			var ho := snappedf(rng.randf_range(-0.5, 0.5), 0.25)
			Build.box(root, Vector3(seg, h + ho, depth), Vector3(x + seg * 0.5, (h + ho) * 0.5, z + zo - depth * 0.5), cliff)
			Build.box(root, Vector3(seg + 0.2, 0.3, depth + 0.2), Vector3(x + seg * 0.5, h + ho + 0.1, z + zo - depth * 0.5), top)
			for i in int(seg * 0.5):
				var tint: Color = (b["tree_tint_a"] as Color).lerp(b["tree_tint_b"], rng.randf())
				var tree := TreeBuilder.conifer(rng.randi(), rng.randf_range(1.2, 1.9), tint, snow)
				tree.position = Vector3(x + rng.randf() * seg, h + ho + 0.2, z + zo - rng.randf_range(1.0, depth - 1.0))
				root.add_child(tree)
			x += seg


## 室內的牆：後牆與兩側牆，每隔一段有壁柱；鏡頭那一側不蓋牆。
## 天花板只投影子不顯示，中間留一個洞讓「太陽」變成一道天光。
static func _walls(root: Node3D, def: SceneDef) -> void:
	var b: Dictionary = def.backdrop
	var wall := Mats.tri(b.get("wall", "brick"), b.get("wall_tint", Color.WHITE), 0.95, 1.4)
	var trim := Mats.tri("stone_wall", b.get("trim_tint", Color("#8a8690")), 0.95, 1.4)
	var hx: float = def.play_half.x + 1.0
	var hz: float = def.play_half.y + 1.0
	var h: float = b.get("height", 9.0)
	Build.box(root, Vector3(hx * 2.0 + 4.0, h, 2.0), Vector3(0, h * 0.5, -hz - 1.0), wall)
	Build.box(root, Vector3(2.0, h, hz * 2.0 + 2.0), Vector3(-hx - 1.0, h * 0.5, 0), wall)
	Build.box(root, Vector3(2.0, h, hz * 2.0 + 2.0), Vector3(hx + 1.0, h * 0.5, 0), wall)
	# 牆腳與壁柱
	Build.box(root, Vector3(hx * 2.0, 0.6, 0.4), Vector3(0, 0.3, -hz + 0.2), trim)
	var x := -hx + 3.0
	while x < hx:
		Build.box(root, Vector3(1.0, h, 0.6), Vector3(x, h * 0.5, -hz + 0.3), trim)
		Build.box(root, Vector3(1.3, 0.5, 0.9), Vector3(x, 0.25, -hz + 0.45), trim)
		Build.box(root, Vector3(1.3, 0.4, 0.9), Vector3(x, 4.4, -hz + 0.45), trim)
		x += 6.0
	# 只投影子的天花板：四塊圍出一個天窗
	var hole: Rect2 = b.get("skylight", Rect2(-3, -6, 6, 5))
	var top_y := h + 1.0
	var mat := Mats.flat(Color.BLACK)
	var big := 80.0
	var pieces := [
		Rect2(-big, -big, big * 2.0, big + hole.position.y),
		Rect2(-big, hole.end.y, big * 2.0, big - hole.end.y),
		Rect2(-big, hole.position.y, big + hole.position.x, hole.size.y),
		Rect2(hole.end.x, hole.position.y, big - hole.end.x, hole.size.y),
	]
	for r in pieces:
		var rect: Rect2 = r
		var c := rect.get_center()
		var mi := Build.box(root, Vector3(rect.size.x, 0.5, rect.size.y), Vector3(c.x, top_y, c.y), mat)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
