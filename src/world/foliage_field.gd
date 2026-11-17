class_name FoliageField
extends RefCounted
## 花草：兩個 MultiMesh（草叢、花），整片一次畫完。
## 每株是兩片交叉的面片，大小固定 0.5 公尺（16px → 32 px／公尺，BLUEPRINT A1）。

const AREA := Rect2(-36.0, -22.0, 72.0, 48.0)


static func build(def: SceneDef, extra_flower_spots: Array[Vector3]) -> Node3D:
	var root := Node3D.new()
	var GRASS_COUNT: int = def.grass_count
	var FLOWER_COUNT: int = def.flower_count
	var tints: Array = def.grass_tints
	var mesh := _cross_mesh(0.5, 0.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261117

	# --- 草 ---
	var grass_xf: Array[Transform3D] = []
	var grass_col: Array[Color] = []
	var grass_var: Array[float] = []
	var tries := 0
	while grass_xf.size() < GRASS_COUNT and tries < GRASS_COUNT * 4:
		tries += 1
		var p := AREA.position + Vector2(rng.randf(), rng.randf()) * AREA.size
		if not def.can_grow(p):
			continue
		# 靠近路邊稀一點，草地中央密
		if rng.randf() > def.grow_density(p):
			continue
		var patch := _patch(p, 0.09, 3.1)
		grass_xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(p.x, 0.0, p.y)))
		var c: Color = (tints[0] as Color).lerp(tints[1], patch)
		c = c.lerp(tints[2], _patch(p, 0.05, 9.7) * 0.3)
		grass_col.append(c * rng.randf_range(0.88, 1.06))
		grass_var.append(float(rng.randi() % 2))
	root.add_child(_multimesh(mesh, def.grass_atlas, 2.0, grass_xf, grass_col, grass_var, 0.11))

	# --- 花：成片出現，而不是平均撒 ---
	var flower_xf: Array[Transform3D] = []
	var flower_col: Array[Color] = []
	var flower_var: Array[float] = []
	tries = 0
	while flower_xf.size() < FLOWER_COUNT and tries < FLOWER_COUNT * 30:
		tries += 1
		var p := AREA.position + Vector2(rng.randf(), rng.randf()) * AREA.size
		if not def.can_grow(p):
			continue
		var bed := _patch(p, 0.16, 5.5)
		var near_path := def.dirt_at(p)
		if bed < 0.56 and near_path < 0.12:
			continue
		# 每片花床以一兩種顏色為主
		var kind := int(_patch(p, 0.07, 21.3) * 3.99)
		if rng.randf() < 0.3:
			kind = rng.randi() % 4
		flower_xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(p.x, 0.0, p.y)))
		flower_col.append(Color.WHITE * rng.randf_range(0.92, 1.05))
		flower_var.append(float(kind))
	for spot in extra_flower_spots:
		flower_xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), spot))
		flower_col.append(Color.WHITE)
		flower_var.append(float(rng.randi() % 4))
	root.add_child(_multimesh(mesh, "flowers", 4.0, flower_xf, flower_col, flower_var, 0.08))
	return root


## 低頻雜訊 0..1，用來決定草色與花床位置（跟貼圖產生器無關，只在擺放時用）。
## 場景檔要讓草成叢分布時用這個（同一個低頻雜訊，0..1）。
static func patch(p: Vector2, freq: float, offset: float) -> float:
	return _patch(p, freq, offset)


static func _patch(p: Vector2, freq: float, offset: float) -> float:
	var v := sin(p.x * freq * 6.0 + offset) * cos(p.y * freq * 5.0 - offset * 1.7)
	v += sin((p.x + p.y) * freq * 3.3 + offset * 2.3) * 0.6
	v += sin((p.x - p.y * 1.3) * freq * 9.1 - offset) * 0.3
	return clampf(v / 3.8 + 0.5, 0.0, 1.0)


static func _multimesh(mesh: Mesh, atlas: String, cols: float, xfs: Array[Transform3D], colors: Array[Color], variants: Array[float], wind: float) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		mm.set_instance_color(i, colors[i])
		mm.set_instance_custom_data(i, Color(variants[i], 0, 0, 0))
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/foliage_card.gdshader")
	mat.set_shader_parameter("atlas", Mats.tex(atlas))
	mat.set_shader_parameter("cols", cols)
	mat.set_shader_parameter("wind", wind)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if wind > 0.0:
		AmbientLife.tag(mmi, "wind")
	return mmi


## 兩片交叉的直立面片，原點在底部中央。
static func _cross_mesh(w: float, h: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for q in 2:
		var dir := Vector3(1, 0, 0) if q == 0 else Vector3(0, 0, 1)
		var base := verts.size()
		verts.append(-dir * w * 0.5)
		verts.append(dir * w * 0.5)
		verts.append(dir * w * 0.5 + Vector3(0, h, 0))
		verts.append(-dir * w * 0.5 + Vector3(0, h, 0))
		uvs.append(Vector2(0, 1))
		uvs.append(Vector2(1, 1))
		uvs.append(Vector2(1, 0))
		uvs.append(Vector2(0, 0))
		for i in 4:
			normals.append(Vector3.UP)
		indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
