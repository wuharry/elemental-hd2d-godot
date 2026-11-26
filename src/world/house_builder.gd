class_name HouseBuilder
extends RefCounted
## 木屋：石砌底層 + 原木上層 + 斜屋頂。原點在地面中心，正面朝 +Z。
## 回傳的節點帶兩個 meta：
##   flower_spots：窗台花箱的位置（local），由 FoliageField 統一種花
##   chimney：煙囪口位置（local），由 AmbientLife 放煙

const TRIM := Color("#553a27")
const FRAME := Color("#d6c09c")
const SHUTTER := [Color("#5d7f6a"), Color("#8a5a4a"), Color("#56708c")]


static func build(cfg: Dictionary) -> Node3D:
	var w: float = cfg["w"]
	var d: float = cfg["d"]
	var base_h: float = cfg["base_h"]
	var wall_h: float = cfg["wall_h"]
	var roof_h: float = cfg["roof_h"]
	var gable_front: bool = cfg["gable_front"]
	var cols: int = cfg["cols"]
	var floors: int = cfg["floors"]
	var shed: bool = cfg.get("shed", false)
	var snow: bool = cfg.get("snow", false)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(cfg["seed"]) * 7919

	var root := Node3D.new()
	var flower_spots: Array[Vector3] = []
	var stone := Mats.tri("stone_wall", Color.WHITE, 0.95, 1.3)
	var wall := Mats.tri("planks" if shed else "log_wall", Color.WHITE, 0.9, 1.2)
	var trim := Mats.tri("planks", TRIM)

	Build.box(root, Vector3(w, base_h, d), Vector3(0, base_h * 0.5, 0), stone)
	Build.box(root, Vector3(w + 0.2, wall_h, d + 0.2), Vector3(0, base_h + wall_h * 0.5, 0), wall)
	Build.box(root, Vector3(w + 0.36, 0.16, d + 0.36), Vector3(0, base_h, 0), trim)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Build.box(root, Vector3(0.24, wall_h, 0.24), Vector3(sx * (w * 0.5 + 0.1), base_h + wall_h * 0.5, sz * (d * 0.5 + 0.1)), trim)

	# 屋頂：一律在「屋脊沿 X」的座標系裡蓋，山牆朝前時整組轉 90 度
	var top := base_h + wall_h
	var roof := Node3D.new()
	roof.position.y = top
	root.add_child(roof)
	var ridge_len := w + 0.2
	var span := d + 0.2
	if gable_front:
		roof.rotation.y = PI * 0.5
		ridge_len = d + 0.2
		span = w + 0.2
	_roof(roof, ridge_len, span, roof_h, cfg["roof_tint"], wall, trim, snow)

	if shed:
		Build.quad(root, Vector2(1.0, 1.5), Vector3(0, 0.8, d * 0.5 + 0.11), Mats.quad("door"))
	else:
		_door(root, d, rng)
		var front_z := d * 0.5 + 0.1
		var side_x := w * 0.5 + 0.1
		var idx := 0
		for f in floors:
			var y := base_h + 0.85 + f * 1.6
			for c in cols:
				var x := (c - (cols - 1) * 0.5) * (w / cols)
				_window(root, Vector3(x, y, front_z), 0.0, rng, flower_spots, f == 0 and not snow)
				idx += 1
			# 兩側牆各一扇
			_window(root, Vector3(side_x, y, 0.0), 90.0, rng, flower_spots, false)
			_window(root, Vector3(-side_x, y, 0.0), -90.0, rng, flower_spots, false)
		# 石砌底層的小窗（避開門）
		if w >= 4.4:
			_window(root, Vector3(w * 0.3, 0.98, d * 0.5), 0.0, rng, flower_spots, false)
		# 山牆上的閣樓窗
		if gable_front and roof_h >= 2.2:
			_window(root, Vector3(0, top + 0.72, front_z), 0.0, rng, flower_spots, false)
		# 煙囪
		var chim := Vector3(w * 0.24, top + roof_h * 0.55, -d * 0.18)
		Build.box(root, Vector3(0.56, roof_h * 0.9 + 0.5, 0.56), chim, stone)
		Build.box(root, Vector3(0.7, 0.12, 0.7), chim + Vector3(0, roof_h * 0.45 + 0.25, 0), trim)
		root.set_meta("chimney", chim + Vector3(0, roof_h * 0.45 + 0.45, 0))

	Build.collider(root, Vector3(w + 0.2, 4.0, d + 0.2), Vector3(0, 2.0, 0))
	# 貼著牆角的幾塊基石，讓房子像是從地上長出來的
	for i in 3:
		var sx := -1.0 if rng.randf() < 0.5 else 1.0
		var s := snappedf(rng.randf_range(0.25, 0.5), 0.125)
		Build.box(root, Vector3(s, s * 0.7, s), Vector3(sx * (w * 0.5 + 0.15), s * 0.3, d * 0.5 - rng.randf() * 0.6 + 0.2), stone, Vector3(0, rng.randf() * 40.0, 0))
	root.set_meta("flower_spots", flower_spots)
	return root


static func _roof(parent: Node3D, ridge_len: float, span: float, roof_h: float, tint: Color, gable_mat: Material, trim: Material, snow: bool = false) -> void:
	var eave := 0.42
	var gable_ov := 0.32
	var thick := 0.14
	var half := span * 0.5
	var a := atan2(roof_h, half)
	var slope_len := sqrt(half * half + roof_h * roof_h) + eave
	var mat := Mats.tri("roof", tint, 0.85, 1.3)
	var snow_mat := Mats.tri("snow", Color.WHITE, 0.82, 1.0) if snow else null
	var dir := Vector3(0, -sin(a), cos(a))
	var nrm := Vector3(0, cos(a), sin(a))
	for side in 2:
		# 背面那片是正面那片繞 Y 轉 180 度，屋瓦的重疊方向才會都朝下
		var pivot := Node3D.new()
		pivot.rotation.y = PI * side
		parent.add_child(pivot)
		var center := Vector3(0, roof_h, 0) + dir * (slope_len * 0.5 - 0.06) + nrm * (thick * 0.5)
		var slab := Build.box(pivot, Vector3(ridge_len + gable_ov * 2.0, thick, slope_len), center, mat)
		slab.rotation.x = a
		if snow:
			# 屋坡積雪覆層，讓冬日村莊屋頂呈現厚實的方塊積雪。
			var cap := Build.box(pivot, Vector3(ridge_len + gable_ov * 2.0 + 0.04, 0.12, slope_len - 0.08),
				center + nrm * (thick * 0.5 + 0.05), snow_mat)
			cap.rotation.x = a
		# 封簷板
		var fascia := Build.box(pivot, Vector3(ridge_len + gable_ov * 2.0 + 0.04, 0.2, 0.08), Vector3(0, roof_h, 0) + dir * (slope_len - 0.04) + nrm * 0.04, trim)
		fascia.rotation.x = a
	# 山牆的三角形
	Build.prism(parent, Vector3(span, roof_h, ridge_len), Vector3(0, roof_h * 0.5, 0), gable_mat, Vector3(0, 90, 0))
	# 屋脊蓋板
	Build.box(parent, Vector3(ridge_len + gable_ov * 2.0 + 0.1, 0.16, 0.34), Vector3(0, roof_h + 0.14, 0), snow_mat if snow else trim)


static func _door(root: Node3D, d: float, rng: RandomNumberGenerator) -> void:
	var z := d * 0.5
	var trim := Mats.tri("planks", TRIM)
	Build.box(root, Vector3(1.28, 1.7, 0.24), Vector3(0, 0.85, z + 0.1), trim)
	Build.quad(root, Vector2(1.0, 1.5), Vector3(0, 0.75, z + 0.225), Mats.quad("door"))
	Build.box(root, Vector3(1.5, 0.12, 0.7), Vector3(0, 0.06, z + 0.45), Mats.tri("stone_wall"))
	# 門燈
	Build.box(root, Vector3(0.08, 0.08, 0.3), Vector3(0.86, 1.7, z + 0.22), Mats.flat(Color("#26262c")))
	Build.box(root, Vector3(0.18, 0.22, 0.18), Vector3(0.86, 1.54, z + 0.36), Mats.lamp_glow())
	Build.box(root, Vector3(0.24, 0.05, 0.24), Vector3(0.86, 1.67, z + 0.36), Mats.flat(Color("#26262c")))
	Build.warm_light(root, Vector3(0.86, 1.5, z + 0.65), 1.6 + rng.randf() * 0.5, 6.0)


static func _window(root: Node3D, pos: Vector3, yaw_deg: float, rng: RandomNumberGenerator, flower_spots: Array[Vector3], allow_box: bool) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = yaw_deg
	root.add_child(n)
	var frame := Mats.tri("planks", FRAME)
	var trim := Mats.tri("planks", TRIM)
	var shutter := Mats.tri("planks", SHUTTER[rng.randi() % SHUTTER.size()])
	var variant := 0
	var roll := rng.randf()
	if roll > 0.75:
		variant = 2
	elif roll > 0.4:
		variant = 1
	# 窗戶 0.75 公尺見方 = 24px（BLUEPRINT A1）
	Build.box(n, Vector3(0.85, 0.85, 0.1), Vector3(0, 0, 0.03), frame)
	Build.quad(n, Vector2(0.75, 0.75), Vector3(0, 0, 0.085), Mats.window(variant))
	Build.box(n, Vector3(1.0, 0.07, 0.2), Vector3(0, -0.46, 0.08), trim)
	Build.box(n, Vector3(0.26, 0.84, 0.06), Vector3(-0.57, 0, 0.03), shutter)
	Build.box(n, Vector3(0.26, 0.84, 0.06), Vector3(0.57, 0, 0.03), shutter)
	if allow_box and rng.randf() < 0.75:
		Build.box(n, Vector3(0.84, 0.16, 0.22), Vector3(0, -0.58, 0.2), trim)
		for i in 4:
			var local := Vector3(-0.3 + i * 0.2, -0.5, 0.2)
			flower_spots.append(n.transform * local)
