class_name PropBuilder
extends RefCounted
## 小道具：路燈、柵欄、柴堆、水井、營火、木箱、石頭。全部用方塊堆（BLUEPRINT A3）。

const IRON := Color("#26262c")


static func lamp_post(shadow: bool) -> Node3D:
	var root := Node3D.new()
	var iron := Mats.flat(IRON, 0.6)
	Build.box(root, Vector3(0.3, 0.2, 0.3), Vector3(0, 0.1, 0), Mats.tri("stone_wall"))
	Build.box(root, Vector3(0.1, 2.1, 0.1), Vector3(0, 1.15, 0), iron)
	Build.box(root, Vector3(0.44, 0.07, 0.07), Vector3(0.18, 2.2, 0), iron)
	Build.box(root, Vector3(0.24, 0.28, 0.24), Vector3(0.36, 1.98, 0), Mats.lamp_glow())
	Build.box(root, Vector3(0.32, 0.06, 0.32), Vector3(0.36, 2.15, 0), iron)
	Build.box(root, Vector3(0.28, 0.04, 0.28), Vector3(0.36, 1.82, 0), iron)
	Build.warm_light(root, Vector3(0.36, 1.9, 0), 3.2, 9.5, shadow)
	Build.collider(root, Vector3(0.3, 3.0, 0.3), Vector3(0, 1.5, 0))
	return root


static func fence(length: float) -> Node3D:
	var root := Node3D.new()
	var wood := Mats.tri("planks", Color("#8a6a48"))
	var posts := int(length / 1.5) + 1
	for i in posts:
		var x := -length * 0.5 + i * (length / maxf(posts - 1, 1))
		Build.box(root, Vector3(0.14, 0.8, 0.14), Vector3(x, 0.4, 0), wood)
	Build.box(root, Vector3(length, 0.1, 0.07), Vector3(0, 0.62, 0), wood)
	Build.box(root, Vector3(length, 0.1, 0.07), Vector3(0, 0.32, 0), wood)
	Build.collider(root, Vector3(length, 1.2, 0.2), Vector3(0, 0.6, 0))
	return root


static func log_pile() -> Node3D:
	var root := Node3D.new()
	var bark := Mats.tri("bark")
	var cut := Mats.flat(Color("#c9a26b"))
	for row in 3:
		for i in 4 - row:
			var x := (i - (3 - row) * 0.5) * 0.36
			var y := 0.17 + row * 0.31
			Build.box(root, Vector3(0.32, 0.3, 1.5), Vector3(x, y, 0), bark)
			Build.box(root, Vector3(0.22, 0.2, 1.52), Vector3(x, y, 0), cut)
	Build.box(root, Vector3(0.12, 1.1, 0.12), Vector3(-0.82, 0.55, 0), Mats.tri("planks", Color("#6b4a2e")))
	Build.box(root, Vector3(0.12, 1.1, 0.12), Vector3(0.82, 0.55, 0), Mats.tri("planks", Color("#6b4a2e")))
	Build.collider(root, Vector3(1.8, 1.2, 1.6), Vector3(0, 0.6, 0))
	return root


static func well() -> Node3D:
	var root := Node3D.new()
	var stone := Mats.tri("stone_wall")
	var wood := Mats.tri("planks", Color("#6b4a2e"))
	for i in 4:
		var side := Node3D.new()
		side.rotation.y = PI * 0.5 * i
		root.add_child(side)
		Build.box(side, Vector3(1.3, 0.7, 0.26), Vector3(0, 0.35, 0.52), stone)
	var water := Build.box(root, Vector3(0.8, 0.05, 0.8), Vector3(0, 0.42, 0), null)
	water.material_override = _water()
	Build.box(root, Vector3(0.12, 1.7, 0.12), Vector3(-0.58, 0.85, 0), wood)
	Build.box(root, Vector3(0.12, 1.7, 0.12), Vector3(0.58, 0.85, 0), wood)
	Build.box(root, Vector3(1.4, 0.1, 0.1), Vector3(0, 1.4, 0), wood)
	var roof := Mats.tri("roof", SceneDef.ROOF_BROWN)
	Build.box(root, Vector3(1.7, 0.1, 0.9), Vector3(0, 1.86, 0.34), roof, Vector3(32, 0, 0))
	Build.box(root, Vector3(1.7, 0.1, 0.9), Vector3(0, 1.86, -0.34), roof, Vector3(-32, 0, 0))
	Build.box(root, Vector3(0.26, 0.28, 0.26), Vector3(0.16, 0.95, 0), wood)
	Build.box(root, Vector3(0.04, 0.4, 0.04), Vector3(0.16, 1.2, 0), Mats.flat(Color("#b9a27a")))
	Build.collider(root, Vector3(1.4, 2.0, 1.4), Vector3(0, 1.0, 0))
	return root


static func crate(size: float = 0.8) -> Node3D:
	var root := Node3D.new()
	Build.box(root, Vector3(size, size, size), Vector3(0, size * 0.5, 0), Mats.tri("planks", Color("#a58258")))
	var band := Mats.tri("planks", Color("#6b4a2e"))
	Build.box(root, Vector3(size + 0.04, 0.1, size + 0.04), Vector3(0, 0.08, 0), band)
	Build.box(root, Vector3(size + 0.04, 0.1, size + 0.04), Vector3(0, size - 0.08, 0), band)
	Build.collider(root, Vector3(size, 1.2, size), Vector3(0, 0.6, 0))
	return root


static func barrel() -> Node3D:
	var root := Node3D.new()
	var wood := Mats.tri("planks", Color("#8d6540"))
	var iron := Mats.flat(IRON, 0.5)
	Build.box(root, Vector3(0.62, 0.9, 0.62), Vector3(0, 0.45, 0), wood)
	Build.box(root, Vector3(0.7, 0.5, 0.7), Vector3(0, 0.45, 0), wood)
	Build.box(root, Vector3(0.72, 0.07, 0.72), Vector3(0, 0.24, 0), iron)
	Build.box(root, Vector3(0.72, 0.07, 0.72), Vector3(0, 0.66, 0), iron)
	Build.collider(root, Vector3(0.7, 1.2, 0.7), Vector3(0, 0.6, 0))
	return root


static func rock(rock_seed: int, s: float) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = rock_seed * 49979687
	var root := Node3D.new()
	var stone := Mats.tri("stone_wall", Color("#c9c4ba"), 0.95, 1.5)
	for i in 2 + rng.randi() % 2:
		var size := Vector3(rng.randf_range(0.4, 0.9), rng.randf_range(0.3, 0.6), rng.randf_range(0.4, 0.8)) * s
		Build.box(root, size, Vector3(rng.randf_range(-0.3, 0.3) * s, size.y * 0.4, rng.randf_range(-0.3, 0.3) * s), stone, Vector3(0, rng.randf() * 90.0, 0))
	return root


## 營火：石圈 + 木柴 + 會閃的光。火焰粒子由 AmbientLife 加（meta "fire" 是火心位置）。
static func campfire() -> Node3D:
	var root := Node3D.new()
	var stone := Mats.tri("stone_wall", Color("#bdb6aa"))
	for i in 8:
		var a := TAU * i / 8.0
		Build.box(root, Vector3(0.34, 0.24, 0.3), Vector3(cos(a) * 0.72, 0.12, sin(a) * 0.72), stone, Vector3(0, -rad_to_deg(a), 0))
	var bark := Mats.tri("bark", Color("#5a3d2a"))
	Build.box(root, Vector3(0.9, 0.16, 0.16), Vector3(0, 0.14, 0), bark, Vector3(0, 30, 12))
	Build.box(root, Vector3(0.9, 0.16, 0.16), Vector3(0, 0.2, 0), bark, Vector3(0, -40, -10))
	Build.box(root, Vector3(0.8, 0.14, 0.14), Vector3(0, 0.26, 0), bark, Vector3(0, 95, 14))
	Build.box(root, Vector3(0.3, 0.1, 0.3), Vector3(0, 0.1, 0), Mats.emissive(Color("#ff7a1e"), 3.0))
	# 兩段當椅子的原木
	Build.box(root, Vector3(1.5, 0.36, 0.4), Vector3(0.2, 0.18, 1.7), bark, Vector3(0, 8, 0))
	Build.box(root, Vector3(1.4, 0.36, 0.4), Vector3(-1.7, 0.18, 0.1), bark, Vector3(0, 82, 0))
	var light := OmniLight3D.new()
	light.position = Vector3(0, 0.8, 0)
	light.light_color = Color("#ff9440")
	light.omni_range = 9.0
	light.omni_attenuation = 1.4
	light.shadow_enabled = true
	light.shadow_blur = 2.5
	light.omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID
	light.light_volumetric_fog_energy = 0.5
	light.set_script(load("res://src/world/flicker_light.gd"))
	root.add_child(light)
	root.set_meta("fire", Vector3(0, 0.3, 0))
	Build.collider(root, Vector3(1.2, 1.0, 1.2), Vector3(0, 0.5, 0))
	return root


static func _water() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/water.gdshader")
	m.set_shader_parameter("normal_tex", Mats.tex("water_n"))
	return m


## 池塘：水面 + 一圈石頭與土的岸。
static func pond(rects: Array) -> Node3D:
	var root := Node3D.new()
	var water := _water()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var rim := Mats.tri("stone_wall", Color("#b8b2a6"), 0.95, 1.4)
	var mud := Mats.tri("dirt")
	for r in rects:
		var rect: Rect2 = r
		var c := rect.get_center()
		Build.box(root, Vector3(rect.size.x + 0.5, 0.1, rect.size.y + 0.5), Vector3(c.x, 0.0, c.y), mud)
		Build.box(root, Vector3(rect.size.x, 0.1, rect.size.y), Vector3(c.x, 0.03, c.y), water)
		Build.collider(root, Vector3(rect.size.x, 2.0, rect.size.y), Vector3(c.x, 1.0, c.y))
	# 岸邊石頭：沿著外框撒，落在水裡的略過
	for r in rects:
		var rect: Rect2 = r
		var steps := int((rect.size.x + rect.size.y) * 1.6)
		for i in steps:
			var t := rng.randf()
			var p: Vector2
			match rng.randi() % 4:
				0: p = Vector2(rect.position.x + rect.size.x * t, rect.position.y)
				1: p = Vector2(rect.position.x + rect.size.x * t, rect.end.y)
				2: p = Vector2(rect.position.x, rect.position.y + rect.size.y * t)
				_: p = Vector2(rect.end.x, rect.position.y + rect.size.y * t)
			var inside := 0
			for other in rects:
				if (other as Rect2).grow(-0.15).has_point(p):
					inside += 1
			if inside > 0:
				continue
			var s := rng.randf_range(0.25, 0.6)
			Build.box(root, Vector3(s, s * 0.6, s), Vector3(p.x, s * 0.2, p.y), rim, Vector3(0, rng.randf() * 90.0, 0))
	# 睡蓮
	var pad := Mats.flat(Color("#4c8f3a"))
	for i in 7:
		var rect: Rect2 = rects[i % rects.size()]
		var p := rect.position + Vector2(rng.randf(), rng.randf()) * rect.size
		Build.box(root, Vector3(0.38, 0.03, 0.38), Vector3(p.x, 0.095, p.y), pad, Vector3(0, rng.randf() * 90.0, 0))
		if i % 3 == 0:
			Build.box(root, Vector3(0.12, 0.1, 0.12), Vector3(p.x, 0.15, p.y), Mats.flat(Color("#f6d9e6")))
	return root
