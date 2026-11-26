extends Node3D
## 七大元素祭壇動態特效：各自具備鮮明材質與運動特徵；靜態石座仍可合批，這個腳本子樹保留動態。
## 細碎粒子／水弧／電弧使用固定容量方塊或三角柱 MultiMesh，更新 transform，不逐幀生滅節點。

var element: int
var elapsed := 0.0
var _batches: Dictionary[String, MultiMeshInstance3D] = {}
var _surfaces: Array[MeshInstance3D] = []
var _pieces: Array[Node3D] = []
var _light: OmniLight3D
var _light_energy := 0.0


func _init(element_id: int = Elements.Type.FIRE) -> void:
	element = element_id


func _ready() -> void:
	add_to_group("element_altar_fx")
	match element:
		Elements.Type.FIRE:
			_make_fire()
		Elements.Type.WATER:
			_make_water()
		Elements.Type.LIGHTNING:
			_make_lightning()
		Elements.Type.ICE:
			_make_ice()
		Elements.Type.EARTH:
			_make_earth()
		Elements.Type.ARCANE:
			_make_arcane()
		Elements.Type.LIFE:
			_make_life()
	var lighting: Dictionary = TimeOfDay.PRESETS["altar_fx"].get(element, {})
	if not lighting.is_empty():
		_light = OmniLight3D.new()
		_light.name = "ElementLight"
		_light.position = Vector3(0, 0.50, 0.18)
		_light.light_color = lighting["color"]
		_light_energy = lighting["energy"]
		_light.light_energy = _light_energy
		_light.omni_range = lighting["range"]
		_light.omni_attenuation = 1.65
		_light.shadow_enabled = false
		_light.light_volumetric_fog_energy = 0.0
		_light.add_to_group("magic_lights")
		add_child(_light)
	advance(0.0)


func _process(delta: float) -> void:
	advance(delta)


## 同一條更新路徑供實際遊戲、固定步長動態驗收使用。
func advance(delta: float) -> void:
	elapsed += maxf(delta, 0.0)
	for surface in _surfaces:
		surface.set_instance_shader_parameter("effect_time", elapsed)
	match element:
		Elements.Type.FIRE:
			_update_fire()
		Elements.Type.WATER:
			_update_water()
		Elements.Type.LIGHTNING:
			_update_lightning()
		Elements.Type.ICE:
			_update_ice()
		Elements.Type.EARTH:
			_update_earth()
		Elements.Type.ARCANE:
			_update_arcane()
		Elements.Type.LIFE:
			_update_life()


func _batch(label: String, count: int, material: Material, gradient: bool = false, use_prism: bool = false) -> void:
	var instance := MultiMeshInstance3D.new()
	instance.name = label
	instance.add_to_group("altar_fx_geometry")
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = gradient
	var primitive: PrimitiveMesh = PrismMesh.new() if use_prism else BoxMesh.new()
	primitive.size = Vector3.ONE
	multi.mesh = primitive
	multi.instance_count = count
	multi.custom_aabb = AABB(Vector3(-0.9, -0.15, -0.9), Vector3(1.8, 1.9, 1.8))
	instance.multimesh = multi
	instance.material_override = material
	add_child(instance)
	_batches[label] = instance


func _put(label: String, index: int, at: Vector3, size: Vector3, rotation_angles: Vector3 = Vector3.ZERO) -> void:
	# Instance sizes affect only untextured matter, never the world's triplanar texel density.
	var frame := Transform3D(Basis.from_euler(rotation_angles) * Basis.from_scale(size), at)
	_batches[label].multimesh.set_instance_transform(index, frame)


func _line(label: String, index: int, a: Vector3, b: Vector3, width: float) -> void:
	var direction := b - a
	var length := direction.length()
	if length < 0.0001:
		_put(label, index, a, Vector3.ONE * 0.001)
		return
	var axis := direction / length
	var quat := Quaternion(Vector3.UP, axis) if axis.dot(Vector3.UP) > -0.999 else Quaternion(Vector3.RIGHT, PI)
	var frame := Transform3D(Basis(quat) * Basis.from_scale(Vector3(width, length, width)), (a + b) * 0.5)
	_batches[label].multimesh.set_instance_transform(index, frame)


func _unshadow(mesh: MeshInstance3D) -> MeshInstance3D:
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh


# ---------- 火：三向立體燃燒火舌、熾熱炭芯與螺旋火星 ----------

func _make_fire() -> void:
	for angle: float in [0.0, 60.0, 120.0]:
		var flame := _unshadow(Build.box(self, Vector3(1.0, 1.32, 0.015625), Vector3(0, 0.66, 0),
			Mats.altar_surface("flame"), Vector3(0, angle, 0)))
		flame.name = "FlameTongues_%d" % int(angle)
		_surfaces.append(flame)
	_batch("EmberBed", 8, Mats.altar_energy(Color("#ff5b1c"), 2.4))
	_batch("FlameWisps", 10, Mats.altar_energy(Color("#ff9624"), 2.9))
	_batch("RisingEmbers", 14, Mats.altar_energy(Color("#ffd15c"), 3.0))


func _update_fire() -> void:
	for i in 8:
		var a := i * TAU / 8.0 + elapsed * 0.25
		var r := 0.12 + 0.10 * float(i % 2)
		var pulse := 0.85 + 0.25 * sin(elapsed * 8.5 + i * 1.7)
		_put("EmberBed", i, Vector3(cos(a) * r, 0.065, sin(a) * r),
			Vector3(0.10 * pulse, 0.085 * pulse, 0.10 * pulse), Vector3(0.2, a, 0.15))
	for i in 10:
		var p := fposmod(elapsed * (0.95 + i * 0.05) + i * 0.113, 1.0)
		var angle := i * 1.95 + elapsed * 1.8 + p * 2.4
		var radius := (0.24 - p * 0.14) * (0.85 + 0.15 * sin(elapsed * 9.0 + i))
		var at := Vector3(cos(angle) * radius, 0.12 + p * 0.88, sin(angle) * radius)
		var w := (0.048 * (1.0 - p * 0.7))
		_put("FlameWisps", i, at, Vector3(w, w * 2.3, w), Vector3(0.2 * sin(p * PI), angle, 0.3 * cos(angle)))
	for i in 14:
		var p := fposmod(elapsed * (0.58 + (i % 5) * 0.07) + i * 0.091, 1.0)
		var angle := i * 2.399 + elapsed * 0.9 + p * 3.1
		var radius := 0.14 + p * 0.26
		var at := Vector3(cos(angle) * radius + sin(p * 8.0 + i) * 0.05,
			0.18 + p * 1.24, sin(angle) * radius)
		var size := 0.016 + sin(p * PI) * 0.028
		_put("RisingEmbers", i, at, Vector3(size, size * 1.9, size), Vector3(0.0, angle, 0.25))
	if _light:
		_light.light_energy = _light_energy * (0.86 + 0.11 * sin(elapsed * 12.7) + 0.09 * sin(elapsed * 21.3))


# ---------- 水：湧泉水柱、四道拱形噴泉弧線、飛濺水花與漣漪泉池 ----------

func _make_water() -> void:
	var pool := _unshadow(Build.box(self, Vector3(1.02, 0.028, 1.02), Vector3(0, 0.026, 0), Mats.altar_surface("water")))
	pool.name = "RipplePool"
	_surfaces.append(pool)
	_batch("FlowingStream", 8, Mats.altar_energy(Color("#28bee8"), 2.4))
	_batch("FountainArcs", 32, Mats.altar_energy(Color("#52d8f8"), 2.2))
	_batch("FountainCrown", 8, Mats.altar_energy(Color("#a6f4ff"), 2.6))
	_batch("FallingDrops", 16, Mats.altar_energy(Color("#88eeff"), 2.3))


func _water_point(t: float) -> Vector3:
	return Vector3(0.042 * sin(t * 5.2 + elapsed * 3.2), 0.06 + t * 0.80,
		0.036 * cos(t * 5.0 + elapsed * 2.6))


func _fountain_arc_point(arc_index: int, u: float) -> Vector3:
	var base_angle := arc_index * (TAU / 4.0) + elapsed * 0.35 + sin(elapsed * 1.4 + arc_index) * 0.12
	var top := _water_point(1.0)
	var reach := 0.38 + 0.03 * sin(elapsed * 3.4 + arc_index * 1.6)
	var arch_lift := 0.18 * sin(u * PI)
	var y := lerpf(top.y, 0.04, u * u) + arch_lift * (1.0 - u * 0.35)
	var r := u * reach
	return Vector3(top.x * (1.0 - u) + cos(base_angle) * r, y, top.z * (1.0 - u) + sin(base_angle) * r)


func _update_water() -> void:
	for i in 8:
		var t := float(i) / 8.0
		var swell := 0.018 * sin(t * 9.0 - elapsed * 7.5)
		_line("FlowingStream", i, _water_point(t), _water_point(t + 0.125), 0.155 - t * 0.055 + swell)
	for arc in 4:
		for seg in 8:
			var u0 := float(seg) / 8.0
			var u1 := float(seg + 1) / 8.0
			var width := lerpf(0.065, 0.036, u0) + 0.008 * sin(u0 * 10.0 - elapsed * 9.0 + arc)
			_line("FountainArcs", arc * 8 + seg,
				_fountain_arc_point(arc, u0), _fountain_arc_point(arc, u1), width)
	var top := _water_point(1.0)
	for i in 8:
		var a := i * TAU / 8.0 + elapsed * 2.4
		var hop := absf(sin(elapsed * 5.4 + i * 1.1))
		var r := 0.06 + hop * 0.065
		var s := 0.045 + hop * 0.035
		_put("FountainCrown", i, top + Vector3(cos(a) * r, hop * 0.09, sin(a) * r),
			Vector3(s, s * 1.25, s), Vector3(0.0, a, 0.3))
	for i in 16:
		var p := fposmod(elapsed * (0.95 + (i % 4) * 0.12) + i / 16.0, 1.0)
		if i < 8:
			# 泉口飛出的水珠
			var angle := i * 2.399 + elapsed * 0.45
			var at := Vector3(cos(angle) * (0.06 + p * 0.42), 0.92 + sin(p * PI) * 0.16 - p * p * 0.88, sin(angle) * (0.06 + p * 0.42))
			_put("FallingDrops", i, at, Vector3(0.038, 0.042 + p * 0.075, 0.038))
		else:
			# 落水處濺起的小水花
			var j := i - 8
			var splash_angle := (j % 4) * (TAU / 4.0) + elapsed * 0.35 + (0.22 if j >= 4 else -0.22)
			var r := 0.36 + p * 0.10
			var y := 0.05 + sin(p * PI) * 0.22
			var s := 0.022 + sin(p * PI) * 0.028
			_put("FallingDrops", i, Vector3(cos(splash_angle) * r, y, sin(splash_angle) * r), Vector3(s, s * 1.4, s))
	if _light:
		_light.light_energy = _light_energy * (0.92 + 0.08 * sin(elapsed * 4.2))


# ---------- 雷：高壓紫色主電弧、多叉分枝、核心電漿球與飛濺電火花 ----------

func _make_lightning() -> void:
	var violet := Elements.color(Elements.Type.LIGHTNING)
	_batch("StormNexus", 6, Mats.altar_energy(violet.lerp(Color("#f4e6ff"), 0.48), 3.3))
	_batch("LightningCore", 10, Mats.altar_energy(violet.lerp(Color("#e8d4ff"), 0.28), 3.1))
	_batch("LightningBranches", 18, Mats.altar_energy(violet.darkened(0.06), 2.5))
	_batch("ElectricSparks", 22, Mats.altar_energy(violet.lerp(Color("#f2d8ff"), 0.42), 2.9))


func _noise(n: float) -> float:
	return fposmod(sin(n * 12.9898) * 43758.5453, 1.0)


func _update_lightning() -> void:
	var tick := floorf(elapsed * 18.0)
	var center := Vector3(0, 0.56, 0)
	for i in 6:
		var a := elapsed * 3.8 + i * TAU / 6.0
		var jitter := (_noise(tick * 2.1 + i * 7.3) - 0.5) * 0.08
		var pos := center + Vector3(cos(a) * (0.09 + jitter), sin(a * 2.0) * 0.07 + jitter, sin(a) * (0.09 - jitter))
		var s := 0.048 + 0.032 * _noise(tick * 1.7 + i * 3.1)
		_put("StormNexus", i, pos, Vector3(s, s, s), Vector3(a, a * 0.7, PI * 0.25))

	# 10 段連續主電弧：從底座電擊點經中央電漿核竄升到頂端放電冠。
	var points: Array[Vector3] = []
	for i in 11:
		var frac := float(i) / 10.0
		var spread := sin(frac * PI) * 0.34
		var x := (_noise(tick * 1.93 + i * 8.17) - 0.5) * spread if (i > 0 and i < 10) else 0.0
		var z := (_noise(tick * 1.41 + i * 5.73) - 0.5) * spread * 0.75 if (i > 0 and i < 10) else 0.0
		points.append(Vector3(x, 0.07 + frac * 0.98, z))
	for i in 10:
		var thickness := 0.042 if (i >= 3 and i <= 7) else 0.030
		_line("LightningCore", i, points[i], points[i + 1], thickness)

	# 6 條不對稱分枝（前 4 條劈向底座四角，後 2 條向上斜叉放電）。
	for b in 6:
		var anchor_idx := 3 + (b % 5)
		var start := points[anchor_idx]
		var active := (b < 2) or (_noise(tick * 2.7 + b * 4.3) > 0.22)
		if not active:
			for s in 3:
				_put("LightningBranches", b * 3 + s, center, Vector3.ONE * 0.001)
			continue
		var angle := b * (TAU / 6.0) + (_noise(tick + b * 6.1) - 0.5) * 0.9
		var target := Vector3(cos(angle) * 0.38, 0.08 if b < 4 else 1.02, sin(angle) * 0.34)
		var mid1 := start.lerp(target, 0.36) + Vector3((_noise(tick * 3.1 + b) - 0.5) * 0.18, 0.06, (_noise(tick * 2.3 + b) - 0.5) * 0.14)
		var mid2 := start.lerp(target, 0.72) + Vector3((_noise(tick * 4.2 + b) - 0.5) * 0.16, -0.04, (_noise(tick * 3.7 + b) - 0.5) * 0.14)
		_line("LightningBranches", b * 3 + 0, start, mid1, 0.026)
		_line("LightningBranches", b * 3 + 1, mid1, mid2, 0.022)
		_line("LightningBranches", b * 3 + 2, mid2, target, 0.018)

	# 22 道飛射紫色高壓電火花（沿飛行方向拉成細線）。
	for i in 22:
		var life := fposmod(elapsed * (1.8 + (i % 5) * 0.35) + i * 0.071, 1.0)
		var seed_tick := floorf(elapsed * (1.8 + (i % 5) * 0.35) + i * 0.071)
		var a := _noise(seed_tick * 5.1 + i * 9.4) * TAU
		var elev := (_noise(seed_tick * 3.7 + i * 6.2) - 0.35) * 1.15
		var dir := Vector3(cos(a) * cos(elev), sin(elev), sin(a) * cos(elev)).normalized()
		var dist := 0.08 + life * 0.52
		var head := center + dir * dist + Vector3(0, -0.18 * life * life, 0)
		var tail := head - dir * (0.095 * (1.0 - life * 0.65))
		_line("ElectricSparks", i, tail, head, 0.022 * (1.0 - life * 0.55))

	if _light:
		_light.light_energy = _light_energy * (0.58 + _noise(tick + 7.0) * 0.72)


# ---------- 冰：五簇棱角寒冰晶柱、低空寒氣霧環、漂浮冰刃與飄落霜雪 ----------

func _make_ice() -> void:
	var frost_mist := _unshadow(Build.quad(self, Vector2(1.16, 1.16), Vector3(0, 0.035, 0),
		Mats.altar_surface("frost"), Vector3(-90.0, 0.0, 0.0)))
	frost_mist.name = "FrostMist"
	_surfaces.append(frost_mist)

	var specs := [
		{"w": 0.26, "h": 0.86, "lo": 0.18},
		{"w": 0.20, "h": 0.58, "lo": 0.14},
		{"w": 0.19, "h": 0.52, "lo": 0.13},
		{"w": 0.15, "h": 0.40, "lo": 0.10},
		{"w": 0.15, "h": 0.36, "lo": 0.10},
	]
	for i in specs.size():
		var shard := Node3D.new()
		shard.name = "IceSpire%d" % i
		add_child(shard)
		var w: float = specs[i]["w"]
		var h: float = specs[i]["h"]
		var lo: float = specs[i]["lo"]
		var upper_size := Vector3(w, h, w)
		var lower_size := Vector3(w, lo, w)
		var up := _unshadow(Build.prism(shard, upper_size, Vector3(0, h * 0.5, 0), Mats.altar_ice(upper_size)))
		var dn := _unshadow(Build.prism(shard, lower_size, Vector3(0, -lo * 0.5, 0), Mats.altar_ice(lower_size), Vector3(0, 0, 180)))
		_surfaces.append(up)
		_surfaces.append(dn)
		_pieces.append(shard)
	_batch("FrostShards", 12, Mats.altar_energy(Color("#6ae6ff"), 2.2), false, true)
	_batch("FallingFrost", 16, Mats.altar_energy(Color("#cdf8ff"), 2.4))


func _update_ice() -> void:
	var layout := [
		{"pos": Vector3(0.0, 0.22, -0.04), "rot": Vector3(0.04, 0.35, -0.03)},
		{"pos": Vector3(-0.24, 0.18, 0.06), "rot": Vector3(0.12, 0.95, 0.28)},
		{"pos": Vector3(0.24, 0.18, 0.05), "rot": Vector3(-0.08, 1.55, -0.26)},
		{"pos": Vector3(-0.14, 0.14, -0.20), "rot": Vector3(-0.24, 2.2, 0.18)},
		{"pos": Vector3(0.15, 0.14, 0.20), "rot": Vector3(0.24, 2.8, -0.18)},
	]
	for i in _pieces.size():
		var base_pos: Vector3 = layout[i]["pos"]
		var base_rot: Vector3 = layout[i]["rot"]
		_pieces[i].position = base_pos + Vector3(0, 0.018 * sin(elapsed * 1.45 + i * 1.2), 0)
		_pieces[i].rotation = base_rot + Vector3(0, 0.06 * sin(elapsed * 0.7 + i), 0)
	for i in 12:
		var a := elapsed * 0.55 + i * TAU / 12.0
		var r := 0.36 + 0.06 * sin(elapsed * 1.6 + i * 2.1)
		var y := 0.30 + (i % 3) * 0.24 + sin(elapsed * 1.9 + i) * 0.06
		_put("FrostShards", i, Vector3(cos(a) * r, y, sin(a) * r),
			Vector3(0.038, 0.105, 0.038), Vector3(0.35, -a, 0.45))
	for i in 16:
		var p := fposmod(elapsed * (0.20 + (i % 4) * 0.04) + i * 0.083, 1.0)
		var swirl := i * 2.399 + elapsed * 0.35
		var r := 0.16 + (i % 5) * 0.07
		var at := Vector3(cos(swirl) * r + sin(elapsed * 1.5 + i) * 0.05,
			1.12 - p * 1.04, sin(swirl) * r)
		var size := 0.022 + sin(p * PI) * 0.018
		_put("FallingFrost", i, at, Vector3(size, size, size), Vector3(p * 1.5, elapsed * 0.6 + i, PI * 0.25))
	if _light:
		_light.light_energy = _light_energy * (0.90 + 0.10 * sin(elapsed * 2.0))


# ---------- 土：沉穩浮動符文岩塊群、金色地脈裂紋與底座石環 ----------

func _make_earth() -> void:
	var rock := Mats.altar_earth()
	var monolith := Node3D.new()
	monolith.name = "RockMonolith"
	add_child(monolith)
	_surfaces.append(Build.box(monolith, Vector3(0.42, 0.38, 0.38), Vector3.ZERO, rock))
	_surfaces.append(Build.box(monolith, Vector3(0.30, 0.14, 0.28), Vector3(0, 0.24, 0), rock, Vector3(0, 45, 0)))
	_surfaces.append(Build.box(monolith, Vector3(0.28, 0.14, 0.26), Vector3(0, -0.24, 0), rock, Vector3(0, 45, 0)))
	_pieces.append(monolith)
	var chunk_sizes := [
		Vector3(0.20, 0.18, 0.17),
		Vector3(0.17, 0.22, 0.16),
		Vector3(0.19, 0.15, 0.18),
		Vector3(0.14, 0.14, 0.14),
		Vector3(0.16, 0.13, 0.15),
	]
	for i in chunk_sizes.size():
		var chunk := Build.box(self, chunk_sizes[i], Vector3.ZERO, rock)
		chunk.name = "RockChunk%d" % (i + 1)
		_surfaces.append(chunk)
		_pieces.append(chunk)
	_batch("EarthRunes", 8, Mats.altar_energy(Color("#f6b94e"), 2.1))
	_batch("FallingGrit", 14, Mats.altar_energy(Color("#ffca68"), 2.4))


func _update_earth() -> void:
	_pieces[0].position = Vector3(0, 0.60 + sin(elapsed * 1.15) * 0.045, 0)
	_pieces[0].rotation = Vector3(0.12 * sin(elapsed * 0.5), elapsed * 0.28, 0.10 * cos(elapsed * 0.45))
	for i in range(1, _pieces.size()):
		var k := i - 1
		var a := elapsed * (0.36 + (k % 2) * 0.14) + k * TAU / 5.0
		var r := 0.36 + (k % 2) * 0.08
		var y := 0.34 + (k % 3) * 0.18 + sin(elapsed * 1.4 + k * 1.5) * 0.055
		_pieces[i].position = Vector3(cos(a) * r, y, sin(a) * r * 0.85)
		_pieces[i].rotation = Vector3(0.3 + a * 0.4, a * 0.7, 0.25 * sin(a))
	for i in 8:
		var a0 := -elapsed * 0.22 + i * TAU / 8.0
		var a1 := a0 + TAU / 12.0
		_line("EarthRunes", i, Vector3(cos(a0) * 0.40, 0.055, sin(a0) * 0.40),
			Vector3(cos(a1) * 0.40, 0.055, sin(a1) * 0.40), 0.032)
	for i in 14:
		var p := fposmod(elapsed * (0.45 + (i % 4) * 0.09) + i * 0.083, 1.0)
		var a := i * 2.399 + elapsed * 0.5
		var r := 0.24 + 0.14 * sin(p * PI)
		var at := Vector3(cos(a) * r, 0.12 + p * 0.76, sin(a) * r)
		var s := 0.020 + sin(p * PI) * 0.022
		_put("FallingGrit", i, at, Vector3(s, s, s), Vector3(p * 3.0, a, p * 2.0))
	if _light:
		_light.light_energy = _light_energy * (0.90 + 0.10 * sin(elapsed * 2.2))


# ---------- 奧術 / 奧能：紫到紅色漸變能量圓球 + 雙層傾斜奧能星環與光屑 ----------

func _make_arcane() -> void:
	var orb := _unshadow(Build.quad(self, Vector2(0.80, 0.80), Vector3(0, 0.60, 0), Mats.altar_surface("arcane_orb")))
	orb.name = "ArcaneOrb"
	_surfaces.append(orb)
	_batch("RuneFrames", 16, Mats.altar_arcane(), true)
	_batch("RuneMotes", 10, Mats.altar_arcane(), true)


func _update_arcane() -> void:
	var center := Vector3(0, 0.60, 0)
	for ring in 2:
		var tilt := Vector3(0.55 if ring == 0 else -0.68, elapsed * (0.62 if ring == 0 else -0.48), 0.35 if ring == 0 else -0.45)
		var basis := Basis.from_euler(tilt)
		var radius := 0.45 if ring == 0 else 0.35
		for i in 8:
			var a := TAU * i / 8.0
			var b := TAU * (i + 1) / 8.0
			var start := center + basis * Vector3(cos(a) * radius, 0.0, sin(a) * radius)
			var end := center + basis * Vector3(cos(b) * radius, 0.0, sin(b) * radius)
			_line("RuneFrames", ring * 8 + i, start, end, 0.026 if ring == 0 else 0.020)
			_batches["RuneFrames"].multimesh.set_instance_custom_data(ring * 8 + i,
				Color(_arcane_gradient(start), _arcane_gradient(end), 0, 0))
	for i in 10:
		var angle := elapsed * (0.95 if i % 2 == 0 else -0.78) + i * TAU / 10.0
		var r := 0.46 + 0.08 * sin(elapsed * 2.2 + i)
		var at := center + Vector3(cos(angle) * r, sin(angle * 2.0 + i) * 0.22, sin(angle) * r * 0.82)
		var s := 0.036 + 0.016 * sin(elapsed * 3.5 + i * 1.4)
		_put("RuneMotes", i, at, Vector3(s, s, s), Vector3(angle, angle * 0.7, PI * 0.25))
		var tone := _arcane_gradient(at)
		_batches["RuneMotes"].multimesh.set_instance_custom_data(i, Color(tone, tone, 0, 0))
	if _light:
		_light.light_energy = _light_energy * (0.86 + 0.14 * sin(elapsed * 2.6))


func _arcane_gradient(point: Vector3) -> float:
	return clampf(0.5 + point.x * 1.45 - (point.y - 0.60) * 1.15, 0.0, 1.0)


# ---------- 生命：雙股翡翠藤蔓、舒展光葉、呼吸花冠與翠金治癒花粉 ----------

func _make_life() -> void:
	var pool := _unshadow(Build.quad(self, Vector2(0.96, 0.96), Vector3(0, 0.03, 0),
		Mats.altar_surface("life"), Vector3(-90.0, 0.0, 0.0)))
	pool.name = "LifeHalo"
	_surfaces.append(pool)
	var green := Elements.color(Elements.Type.LIFE)
	_batch("LivingStem", 12, Mats.altar_energy(green.darkened(0.15), 1.8))
	_batch("UnfurlingLeaves", 20, Mats.altar_energy(green, 1.7))
	_batch("LivingVeins", 4, Mats.altar_energy(Color("#d4ff9c"), 2.7))
	_batch("LifeBlossom", 8, Mats.altar_energy(Color("#b6ff9a"), 2.8), false, true)
	_batch("RisingPollen", 16, Mats.altar_energy(Color("#c4ffab"), 2.6))


func _life_stem(t: float, strand: float = 0.0) -> Vector3:
	var breath := sin(elapsed * 1.9)
	var twist := t * 4.4 + elapsed * 0.9 + strand * PI
	var helix_r := 0.055 * sin(t * PI)
	return Vector3(sin(elapsed * 1.1) * 0.045 * t + cos(twist) * helix_r,
		0.06 + t * (0.78 + breath * 0.03),
		sin(t * PI) * 0.02 + sin(twist) * helix_r)


func _update_life() -> void:
	for strand in 2:
		for i in 6:
			var t0 := float(i) / 6.0
			var t1 := float(i + 1) / 6.0
			_line("LivingStem", strand * 6 + i,
				_life_stem(t0, float(strand)), _life_stem(t1, float(strand)), 0.038 - t0 * 0.012)
	const LEAF_WIDTHS := [0.08, 0.16, 0.22, 0.17, 0.08]
	for leaf in 4:
		var side := -1.0 if leaf % 2 == 0 else 1.0
		var top := leaf >= 2
		var attachment := _life_stem(0.68 if top else 0.34, float(leaf % 2))
		var breath := sin(elapsed * 1.9 - leaf * 0.45)
		var growth := (0.88 if top else 1.04) * (0.93 + breath * 0.08)
		var angles := Vector3(-0.22 if top else 0.18, side * 0.35 + (0.6 if top else 0.0),
			-side * (0.98 + breath * 0.12))
		var frame := Basis.from_euler(angles)
		for strip in 5:
			var center := attachment + frame * Vector3(0, (strip + 0.5) * 0.075 * growth, 0)
			_put("UnfurlingLeaves", leaf * 5 + strip, center,
				Vector3(LEAF_WIDTHS[strip] * growth, 0.075 * growth, 0.042), angles)
		var vein_start := attachment + frame * Vector3(0, 0.02, 0.026)
		var vein_end := attachment + frame * Vector3(0, 0.33 * growth, 0.026)
		_line("LivingVeins", leaf, vein_start, vein_end, 0.024)
	# 頂端綻放的生命花冠
	var crown := _life_stem(1.0, 0.0)
	var bloom := 0.5 + 0.5 * sin(elapsed * 1.9)
	for i in 8:
		var a := elapsed * 0.45 + i * TAU / 8.0
		var tilt := 0.42 + bloom * 0.32
		var out := Vector3(cos(a), 0.35, sin(a)).normalized() * (0.09 + bloom * 0.04)
		_put("LifeBlossom", i, crown + out, Vector3(0.055, 0.14, 0.032),
			Vector3(sin(a) * tilt, -a, -cos(a) * tilt))
	for i in 16:
		var phase := fposmod(elapsed * (0.24 + (i % 4) * 0.05) + i / 16.0, 1.0)
		var a := i * 2.399 + elapsed * 0.65 + phase * 2.0
		var r := 0.22 + 0.16 * sin(phase * PI)
		var at := Vector3(cos(a) * r, 0.12 + phase * 1.08, sin(a) * r)
		var size := 0.018 + sin(phase * PI) * 0.022
		_put("RisingPollen", i, at, Vector3(size, size, size), Vector3(0, a, PI * 0.25))
	if _light:
		_light.light_energy = _light_energy * (0.90 + 0.10 * sin(elapsed * 1.9))
