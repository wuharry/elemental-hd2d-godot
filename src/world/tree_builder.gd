class_name TreeBuilder
extends RefCounted
## 方塊樹（BLUEPRINT A3）：樹冠是幾個大小不一、對齊軸向的葉子方塊。
## 葉子方塊用 Mats.foliage()，會一塊一塊隨風晃。


static func broadleaf(tree_seed: int, s: float, tint: Color) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = tree_seed * 104729
	var root := Node3D.new()
	var trunk_h := 2.0 * s
	var bark := Mats.tri("bark")
	Build.box(root, Vector3(0.45 * s, trunk_h + 0.6 * s, 0.45 * s), Vector3(0, (trunk_h + 0.6 * s) * 0.5, 0), bark)
	Build.box(root, Vector3(0.7 * s, 0.3, 0.7 * s), Vector3(0, 0.15, 0), bark)
	Build.box(root, Vector3(0.9 * s, 0.2 * s, 0.2 * s), Vector3(0.4 * s, trunk_h * 0.8, 0), bark)
	Build.box(root, Vector3(0.2 * s, 0.2 * s, 0.8 * s), Vector3(0, trunk_h * 0.9, -0.35 * s), bark)
	var mats := [Mats.foliage(tint, 0.045), Mats.foliage(tint.darkened(0.16), 0.04), Mats.foliage(tint.lightened(0.12), 0.055)]
	# 樹冠：橢球表面鋪滿小方塊，中間塞一塊實心的擋光
	var radius := Vector3(1.9, 1.45, 1.9) * s
	var center := Vector3(0, trunk_h + radius.y * 0.75, 0)
	Build.box(root, radius * 1.25, center, mats[1])
	var count := int(46 * s * s)
	for i in count:
		# 在球面上均勻取點（黃金角螺旋），再加一點亂數
		var k := (i + 0.5) / count
		var phi := acos(1.0 - 2.0 * k)
		var theta := PI * (1.0 + sqrt(5.0)) * i
		var dir := Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))
		if dir.y < -0.55:
			continue
		var size := _snap(rng.randf_range(0.5, 1.0) * s)
		var pos := center + dir * radius * rng.randf_range(0.82, 1.08)
		# 朝上的那幾塊用亮色，底下用暗色，樹冠才有體積感
		var mat: Material = mats[2] if dir.y > 0.45 else (mats[1] if dir.y < -0.1 else mats[rng.randi() % 3])
		Build.box(root, Vector3(size, size, size), _snap_v(pos), mat)
	Build.collider(root, Vector3(0.6 * s, 3.0, 0.6 * s), Vector3(0, 1.5, 0))
	return root


static func conifer(tree_seed: int, s: float, tint: Color, snow: bool = false) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = tree_seed * 15485863
	var root := Node3D.new()
	Build.box(root, Vector3(0.4 * s, 1.4 * s, 0.4 * s), Vector3(0, 0.7 * s, 0), Mats.tri("bark"))
	var mats := [Mats.foliage(tint, 0.035), Mats.foliage(tint.darkened(0.12), 0.035)]
	var sizes := [2.5, 2.0, 1.5, 1.0, 0.5]
	var y := 1.0 * s
	var snow_mat := Mats.tri("snow")
	for i in sizes.size():
		var w: float = sizes[i] * s
		var h := 0.95 * s
		# 一般針葉樹層層錯開 45 度；積雪的層層同向，每層頂上露出一圈完整的雪
		# （錯開時雪片會被上一層蓋到只剩四個角，看起來像紙三角）
		var yaw := 45.0 if (i % 2 == 1 and not snow) else 0.0
		Build.box(root, Vector3(w, h, w), Vector3(0, y + h * 0.5, 0), mats[i % 2], Vector3(0, yaw, 0))
		if snow:
			Build.box(root, Vector3(w + 0.06, 0.16, w + 0.06), Vector3(0, y + h + 0.02, 0), snow_mat)
			# 雪從層緣垂下來的幾小塊，打斷方正的輪廓
			for k in 2 + rng.randi() % 3:
				var side := rng.randi() % 4
				var along := snappedf(rng.randf_range(-0.4, 0.4) * w, 0.125)
				var edge := w * 0.5 + 0.02
				var offset := Vector3(along, 0, edge) if side == 0 else (Vector3(along, 0, -edge) if side == 1 else (Vector3(edge, 0, along) if side == 2 else Vector3(-edge, 0, along)))
				Build.box(root, Vector3(0.25, 0.22, 0.25), Vector3(0, y + h - 0.08, 0) + offset, snow_mat)
		y += h * 0.82
	root.rotation.y = rng.randf() * TAU
	Build.collider(root, Vector3(0.5 * s, 3.0, 0.5 * s), Vector3(0, 1.5, 0))
	return root


static func bush(tree_seed: int, s: float, tint: Color) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = tree_seed * 32452843
	var root := Node3D.new()
	var mats := [Mats.foliage(tint, 0.03), Mats.foliage(tint.darkened(0.12), 0.03)]
	for i in 5 + rng.randi() % 4:
		var size := _snap(rng.randf_range(0.375, 0.75) * s)
		var pos := Vector3(rng.randf_range(-0.6, 0.6) * s, size * 0.4 + rng.randf() * 0.35 * s, rng.randf_range(-0.5, 0.5) * s)
		Build.box(root, Vector3(size, size * 0.85, size), _snap_v(pos), mats[i % 2])
	return root


## 對齊到 1/8 公尺，讓方塊邊緣落在像素格上。
static func _snap(v: float) -> float:
	return maxf(0.25, snappedf(v, 0.125))


static func _snap_v(v: Vector3) -> Vector3:
	return Vector3(snappedf(v.x, 0.125), snappedf(v.y, 0.125), snappedf(v.z, 0.125))
