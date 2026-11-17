class_name AmbientLife
extends RefCounted
## 讓場景活起來的東西（BLUEPRINT A10）：塵埃光點、落葉、螢火蟲、煙、火焰、蝴蝶、鳥、雲影。


## 每種會動的東西都要帶種類標記：tests/style_test.gd 依此檢查每個場景至少有四種（BLUEPRINT A10）。
## 新增一種就在這裡加一個工廠函式，回傳前呼叫 tag()。
const KINDS := ["dust", "leaves", "fireflies", "smoke", "fire", "butterflies", "birds", "snowfall", "splash", "drips", "clouds", "wind"]


static func tag(node: Node3D, kind: String) -> Node3D:
	assert(KINDS.has(kind), "unknown ambient kind: " + kind)
	node.set_meta("ambient_kind", kind)
	node.add_to_group("ambient")
	return node


static func _billboard(tex_name: String, cutout: bool, unshaded: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = Mats.tex(tex_name)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if cutout:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	else:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


static func _curve(points: Array) -> CurveTexture:
	var c := Curve.new()
	for p in points:
		c.add_point(p)
	var t := CurveTexture.new()
	t.curve = c
	return t


static func _ramp(colors: Array, offsets: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.colors = PackedColorArray(colors)
	g.offsets = PackedFloat32Array(offsets)
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


static func _quad_mesh(size: float, mat: Material) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = mat
	return q


## 飄在空中的塵埃／花粉。吃場景光，所以只有在光束裡才看得到。
static func dust() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 260
	p.lifetime = 10.0
	p.preprocess = 10.0
	p.visibility_aabb = AABB(Vector3(-40, -2, -30), Vector3(80, 16, 60))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(26, 3.2, 16)
	pm.direction = Vector3(1, 0.1, 0.3)
	pm.spread = 60.0
	pm.initial_velocity_min = 0.08
	pm.initial_velocity_max = 0.35
	pm.gravity = Vector3(0, -0.02, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.3
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 3.0
	pm.color = Color(1.0, 0.93, 0.78, 0.45)
	pm.color_ramp = _ramp([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)], [0.0, 0.15, 0.8, 1.0])
	p.process_material = pm
	var mat := _billboard("dot", false, false)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.9, 0.7)
	mat.emission_energy_multiplier = 0.12
	p.draw_pass_1 = _quad_mesh(0.06, mat)
	p.position = Vector3(0, 3.6, 0)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return tag(p, "dust")


## 樹下的落葉。
static func leaves(pos: Vector3, radius: float, tint: Color) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 14
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.visibility_aabb = AABB(Vector3(-12, -8, -12), Vector3(24, 12, 24))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(radius, 0.6, radius)
	pm.direction = Vector3(1, -0.2, 0.4)
	pm.spread = 40.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 0.9
	pm.gravity = Vector3(0.25, -0.55, 0.1)
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.angular_velocity_min = -160.0
	pm.angular_velocity_max = 160.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.9
	pm.turbulence_noise_scale = 2.0
	pm.scale_min = 0.8
	pm.scale_max = 1.2
	pm.color = tint
	pm.color_initial_ramp = _ramp([Color("#b7d66a"), Color("#f2d060"), Color("#f09a48")], [0.0, 0.6, 1.0])
	p.process_material = pm
	p.draw_pass_1 = _quad_mesh(0.25, _billboard("leaf", true, false))
	p.position = pos
	return tag(p, "leaves")


## 夜晚的螢火蟲。加入 "night_only" 群組，由 TimeOfDay 開關。
static func fireflies() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 90
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.visibility_aabb = AABB(Vector3(-40, -2, -30), Vector3(80, 10, 60))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(26, 0.9, 14)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.4
	pm.gravity = Vector3.ZERO
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.2
	pm.turbulence_noise_scale = 2.5
	pm.color = Color("#d8ff7a")
	pm.color_ramp = _ramp([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.2), Color(1, 1, 1, 1), Color(1, 1, 1, 0)], [0.0, 0.2, 0.5, 0.8, 1.0])
	p.process_material = pm
	var mat := _billboard("dot", false, true)
	mat.albedo_color = Color(2.6, 3.0, 1.2)
	p.draw_pass_1 = _quad_mesh(0.1, mat)
	p.position = Vector3(0, 1.2, 4)
	p.emitting = false
	p.add_to_group("night_only")
	return tag(p, "fireflies")


## 煙囪的煙：一顆一顆的灰白方塊，往上飄並變大。
static func smoke(pos: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 9
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.visibility_aabb = AABB(Vector3(-6, -1, -6), Vector3(12, 12, 12))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.25, 1, 0.05)
	pm.spread = 8.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 0.75
	pm.gravity = Vector3(0.12, 0.02, 0.0)
	pm.scale_min = 0.8
	pm.scale_max = 1.2
	pm.scale_curve = _curve([Vector2(0.0, 0.35), Vector2(0.6, 1.0), Vector2(1.0, 0.0)])
	pm.particle_flag_rotate_y = false
	p.process_material = pm
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.55, 0.55, 0.55)
	mesh.material = Mats.flat(Color("#d9d6d0"), 1.0)
	p.draw_pass_1 = mesh
	p.position = pos
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return tag(p, "smoke")


## 營火的火焰：發光小方塊往上竄。
static func fire(pos: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 18
	p.lifetime = 0.8
	p.preprocess = 1.0
	p.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 5, 4))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.22, 0.05, 0.22)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 14.0
	pm.initial_velocity_min = 0.9
	pm.initial_velocity_max = 1.8
	pm.gravity = Vector3(0, 0.6, 0)
	pm.scale_min = 0.7
	pm.scale_max = 1.3
	pm.scale_curve = _curve([Vector2(0.0, 1.0), Vector2(1.0, 0.1)])
	pm.color_ramp = _ramp([Color("#fff0a0"), Color("#ffb030"), Color("#ff5a18"), Color("#7a1a08")], [0.0, 0.3, 0.7, 1.0])
	p.process_material = pm
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.13, 0.13, 0.13)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1.7, 1.7, 1.7)
	mesh.material = mat
	p.draw_pass_1 = mesh
	p.position = pos
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return tag(p, "fire")


static func butterflies(homes: Array[Vector3]) -> Node3D:
	var root := Node3D.new()
	var tints := [Color("#ffe066"), Color("#ffffff"), Color("#ff9ec4"), Color("#8ec5ff"), Color("#ffb347")]
	var script: Script = load("res://src/world/butterfly.gd")
	for i in homes.size():
		var b := Node3D.new()
		b.set_script(script)
		root.add_child(b)
		b.call("setup", homes[i], tints[i % tints.size()], i)
	return tag(root, "butterflies")


static func birds(count: int, height: Vector2 = Vector2(6.5, 9.5), tint: Color = Color("#3a3440"), orbit: float = 1.0) -> Node3D:
	var root := Node3D.new()
	var script: Script = load("res://src/world/bird.gd")
	for i in count:
		var b := Node3D.new()
		b.set_script(script)
		root.add_child(b)
		b.call("setup", i, height, tint, orbit)
	return tag(root, "birds")


## 下雪：整個場景上空往下飄的白色小方塊，被風吹得斜斜的。
static func snowfall() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 900
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.visibility_aabb = AABB(Vector3(-44, -14, -34), Vector3(88, 20, 68))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(34, 0.5, 24)
	pm.direction = Vector3(0.35, -1, 0.1)
	pm.spread = 12.0
	pm.initial_velocity_min = 1.2
	pm.initial_velocity_max = 2.2
	pm.gravity = Vector3(0.3, -0.25, 0.0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.5
	pm.turbulence_noise_scale = 3.0
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	p.process_material = pm
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.06, 0.06, 0.06)
	mesh.material = Mats.flat(Color("#f4f8ff"), 1.0)
	p.draw_pass_1 = mesh
	p.position = Vector3(0, 11.0, 0)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return tag(p, "snowfall")


## 瀑布底下濺起的水花：白色小方塊往外噴再落下。
static func splash(pos: Vector3, width: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 60
	p.lifetime = 1.1
	p.preprocess = 1.5
	p.visibility_aabb = AABB(Vector3(-6, -3, -6), Vector3(12, 8, 12))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(width * 0.5, 0.1, 0.3)
	pm.direction = Vector3(0, 1, 0.5)
	pm.spread = 35.0
	pm.initial_velocity_min = 1.2
	pm.initial_velocity_max = 2.6
	pm.gravity = Vector3(0, -6.0, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	pm.scale_curve = _curve([Vector2(0.0, 1.0), Vector2(1.0, 0.2)])
	p.process_material = pm
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.12, 0.12, 0.12)
	mesh.material = Mats.flat(Color("#eef8ff"), 0.6)
	p.draw_pass_1 = mesh
	p.position = pos
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return tag(p, "splash")


## 洞頂滴下來的水滴。
static func drips(center: Vector3, extents: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 26
	p.lifetime = 1.6
	p.preprocess = 2.0
	p.visibility_aabb = AABB(Vector3(-30, -12, -20), Vector3(60, 14, 40))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = extents
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 0.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 0.8
	pm.gravity = Vector3(0, -9.0, 0)
	p.process_material = pm
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.05, 0.16, 0.05)
	mesh.material = Mats.flat(Color("#bfe6f5"), 0.2)
	p.draw_pass_1 = mesh
	p.position = center
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return tag(p, "drips")


## 雲影：高空的大方塊，只投影子不顯示，慢慢飄過整個村莊。
static func clouds() -> Node3D:
	var root := Node3D.new()
	root.set_script(load("res://src/world/cloud_drift.gd"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var mat := Mats.flat(Color.WHITE)
	for i in 9:
		var c := Node3D.new()
		c.position = Vector3(rng.randf_range(-110, 110), 46.0, rng.randf_range(-90, 60))
		for j in 3:
			var size := Vector3(rng.randf_range(9, 18), 2.0, rng.randf_range(7, 13))
			var mi := Build.box(c, size, Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-4, 4)), mat)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		root.add_child(c)
	return tag(root, "clouds")
