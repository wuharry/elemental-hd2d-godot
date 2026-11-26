class_name TrainingTarget
extends StaticBody3D
## 木樁與金屬測試標的；受傷與狀態仍由純 CombatState 決定。
## 狀態視覺參考 Magicka：潮濕呈現深色濕亮反光、全身滴落水珠與腳下漣漪水窪；
## 燃燒起火、冰凍覆冰、中毒冒毒泡、纏繞生藤。

var combat_state := CombatState.new()
var is_metal := false
var home := Vector3.ZERO
var _bars: Array[MeshInstance3D] = []
var _body: Node3D
var _body_meshes: Array[MeshInstance3D] = []
var _dry_mat: Material
var _wet_mat: Material
var _wet_root: Node3D
var _wet_puddle: MeshInstance3D
var _wet_drips: Array[MeshInstance3D] = []
var _wet_splashes: Array[MeshInstance3D] = []
var _burn_root: Node3D
var _burn_flames: Array[MeshInstance3D] = []
var _burn_embers: Array[MeshInstance3D] = []
var _freeze_root: Node3D
var _freeze_flakes: Array[MeshInstance3D] = []
var _poison_root: Node3D
var _poison_bubbles: Array[MeshInstance3D] = []
var _root_vines: Node3D
var _reset_after := 0.0
var _time := 0.0

# 水滴從頭頂、雙肩、橫臂與身軀各處自然滴落
const DRIP_ORIGINS := [
	Vector3(-0.42, 1.02, 0.10), Vector3(0.42, 1.02, -0.08),
	Vector3(-0.24, 1.32, 0.16), Vector3(0.24, 1.30, 0.14),
	Vector3(-0.14, 1.56, 0.15), Vector3(0.16, 1.52, -0.14),
	Vector3(-0.28, 0.92, -0.16), Vector3(0.28, 0.95, 0.16),
	Vector3(0.0, 1.24, 0.22), Vector3(-0.36, 0.96, 0.02),
]


func _ready() -> void:
	add_to_group("training_targets")
	home = position
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.75, 1.55, 0.45)
	shape.shape = box
	shape.position.y = 0.775
	add_child(shape)

	_body = Node3D.new()
	add_child(_body)
	_dry_mat = Mats.metal(Color("#a1a9b4")) if is_metal else Mats.tri("planks", Color("#ac8354"))
	# 濕透材質：大幅降粗糙度並加深冷藍水潤感（Magicka 濕身質感）
	_wet_mat = Mats.tri("stone_wall", Color("#566c86"), 0.14, 0.9) if is_metal \
		else Mats.tri("planks", Color("#5e4b45"), 0.14, 1.1)

	for spec: Array in [
		[Vector3(0.18, 1.1, 0.18), Vector3(0, 0.55, 0)],
		[Vector3(0.95, 0.18, 0.22), Vector3(0, 1.0, 0)],
		[Vector3(0.56, 0.62, 0.36), Vector3(0, 1.0, 0)],
		[Vector3(0.35, 0.32, 0.32), Vector3(0, 1.48, 0)],
	]:
		_body_meshes.append(Build.box(_body, spec[0], spec[1], _dry_mat))
	Build.box(_body, Vector3(0.22, 0.22, 0.035), Vector3(0, 1.1, 0.20), Mats.flat(Color("#8d3f41")))
	Build.box(_body, Vector3(0.12, 0.12, 0.04), Vector3(0, 1.1, 0.23), Mats.flat(Color("#e9d3a5")))

	for i in 10:
		_bars.append(Build.box(self, Vector3(0.055, 0.055, 0.055), Vector3(-0.31 + i * 0.068, 1.92, 0),
			Mats.altar_energy(Color("#8dd58b"), 1.1)))

	_build_status_fx()
	combat_state.changed.connect(_refresh)
	_refresh()


func _build_status_fx() -> void:
	# 1. 潮濕：腳下濕地水窪漣漪 + 10 顆重力下滴藍青水珠 + 4 顆落地濺起水花
	_wet_root = Node3D.new()
	_wet_root.name = "WetStatusFX"
	add_child(_wet_root)
	_wet_puddle = Build.quad(_wet_root, Vector2(1.25, 1.25), Vector3(0, 0.03, 0),
		Mats.status_wet_puddle(), Vector3(-90.0, 0.0, 0.0))
	_wet_puddle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var drop_mat_a := Mats.altar_energy(Color("#38bfff"), 2.4)
	var drop_mat_b := Mats.altar_energy(Color("#9ef3ff"), 2.6)
	for i in DRIP_ORIGINS.size():
		var drip := Build.box(_wet_root, Vector3(0.042, 0.095, 0.042), DRIP_ORIGINS[i],
			drop_mat_b if i % 3 == 0 else drop_mat_a)
		drip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_wet_drips.append(drip)
	for i in 4:
		var splash := Build.box(_wet_root, Vector3(0.036, 0.048, 0.036), Vector3.ZERO, drop_mat_b)
		splash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_wet_splashes.append(splash)

	# 2. 燃燒：交叉像素火舌包覆身軀與肩頭 + 上升火星
	_burn_root = Node3D.new()
	_burn_root.name = "BurnStatusFX"
	add_child(_burn_root)
	for angle: float in [25.0, 115.0]:
		var flame := Build.box(_burn_root, Vector3(1.18, 1.38, 0.015625), Vector3(0, 1.12, 0),
			Mats.altar_surface("flame"), Vector3(0, angle, 0))
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_burn_flames.append(flame)
	for i in 6:
		var ember := Build.box(_burn_root, Vector3(0.04, 0.065, 0.04), Vector3.ZERO,
			Mats.altar_energy(Color("#ffb038"), 2.6))
		ember.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_burn_embers.append(ember)

	# 3. 冰凍：棱角寒冰晶簇包覆身軀 + 飄落冰屑
	_freeze_root = Node3D.new()
	_freeze_root.name = "FreezeStatusFX"
	add_child(_freeze_root)
	var ice_main := Vector3(0.76, 1.32, 0.56)
	var ice_side := Vector3(0.42, 0.85, 0.36)
	for spec: Array in [
		[ice_main, Vector3(0, 0.68, 0), Vector3(0, 12, 0)],
		[ice_side, Vector3(-0.28, 0.44, 0.14), Vector3(8, 30, 18)],
		[ice_side, Vector3(0.28, 0.42, -0.10), Vector3(-6, -24, -16)],
	]:
		var crystal := Build.prism(_freeze_root, spec[0], spec[1], Mats.altar_ice(spec[0]), spec[2])
		crystal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 4:
		var flake := Build.box(_freeze_root, Vector3(0.04, 0.04, 0.04), Vector3.ZERO,
			Mats.altar_energy(Color("#c4f7ff"), 2.3))
		flake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_freeze_flakes.append(flake)

	# 4. 中毒：湧升的螢光毒泡
	_poison_root = Node3D.new()
	_poison_root.name = "PoisonStatusFX"
	add_child(_poison_root)
	for i in 6:
		var bubble := Build.box(_poison_root, Vector3(0.065, 0.065, 0.065), Vector3.ZERO,
			Mats.altar_energy(Color("#a8e840") if i % 2 == 0 else Color("#d8ff72"), 2.2))
		bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_poison_bubbles.append(bubble)

	# 5. 纏繞：環抱底座的木質藤蔓
	_root_vines = Node3D.new()
	_root_vines.name = "RootedStatusFX"
	add_child(_root_vines)
	var vine_mat := Mats.tri("bark", Color("#6da856"))
	for i in 4:
		var a := float(i) * TAU / 4.0
		Build.box(_root_vines, Vector3(0.11, 0.62, 0.11), Vector3(cos(a) * 0.28, 0.30, sin(a) * 0.28),
			vine_mat, Vector3(14 * sin(a), rad_to_deg(-a), 14 * cos(a)))


func _physics_process(delta: float) -> void:
	_time += delta
	combat_state.tick(delta)
	if combat_state.health <= 0:
		_reset_after += delta
		_body.rotation.z = lerpf(_body.rotation.z, 1.25, delta * 5)
		if _reset_after >= 2.5:
			reset_target()
	else:
		_body.rotation.z = sin(_time * 10) * _reset_after * 0.04
		_reset_after = maxf(0, _reset_after - delta)
	_animate_status_fx()


func _animate_status_fx() -> void:
	if _wet_root.visible:
		_wet_puddle.set_instance_shader_parameter("effect_time", _time)
		for i in _wet_drips.size():
			var speed := 1.05 + float(i % 4) * 0.18
			var phase := fposmod(_time * speed + float(i) * 0.193, 1.0)
			var start: Vector3 = DRIP_ORIGINS[i]
			# 前 15% 掛在身體邊緣凝結，後 85% 受重力加速下墜！
			var fall := clampf((phase - 0.15) / 0.85, 0.0, 1.0)
			var y := lerpf(start.y, 0.05, fall * fall)
			_wet_drips[i].position = Vector3(start.x, y, start.z)
		for i in _wet_splashes.size():
			var p := fposmod(_time * 1.65 + float(i) * 0.27, 1.0)
			var a := float(i) * TAU / 4.0 + _time * 0.4
			var r := 0.18 + p * 0.28
			_wet_splashes[i].position = Vector3(cos(a) * r, 0.04 + sin(p * PI) * 0.18, sin(a) * r)

	if _burn_root.visible:
		for flame in _burn_flames:
			flame.set_instance_shader_parameter("effect_time", _time)
		for i in _burn_embers.size():
			var p := fposmod(_time * 0.95 + float(i) / 6.0, 1.0)
			var a := float(i) * TAU / 6.0 + _time * 1.4
			_burn_embers[i].position = Vector3(cos(a) * (0.28 + p * 0.16), 0.55 + p * 1.25, sin(a) * (0.24 + p * 0.14))

	if _freeze_root.visible:
		for i in _freeze_flakes.size():
			var p := fposmod(_time * 0.35 + float(i) * 0.25, 1.0)
			var a := float(i) * TAU / 4.0 + _time * 0.6
			_freeze_flakes[i].position = Vector3(cos(a) * 0.48, 1.65 - p * 1.5, sin(a) * 0.42)
			_freeze_flakes[i].rotation = Vector3(0, a, PI * 0.25)

	if _poison_root.visible:
		for i in _poison_bubbles.size():
			var p := fposmod(_time * 0.72 + float(i) / 6.0, 1.0)
			var a := float(i) * TAU / 6.0 + sin(_time * 2.0 + i) * 0.4
			_poison_bubbles[i].position = Vector3(cos(a) * 0.34, 0.35 + p * 1.35, sin(a) * 0.30)


func take_spell(elements: Array[int], damage: float) -> Dictionary:
	if combat_state.health <= 0:
		return {}
	var result := combat_state.apply(elements, damage)
	_reset_after = 0.35
	_refresh()
	return result


func reset_target() -> void:
	combat_state.reset()
	position = home
	_reset_after = 0.0
	_body.rotation = Vector3.ZERO
	combat_state.changed.emit()


func _refresh() -> void:
	for i in _bars.size():
		_bars[i].visible = combat_state.health > i * combat_state.max_health / 10.0
	var wet := combat_state.has_status("wet")
	var body_mat := _wet_mat if wet else _dry_mat
	for mi in _body_meshes:
		mi.material_override = body_mat
	_wet_root.visible = wet
	_burn_root.visible = combat_state.has_status("burning")
	_freeze_root.visible = combat_state.has_status("frozen")
	_poison_root.visible = combat_state.has_status("poisoned")
	_root_vines.visible = combat_state.has_status("rooted")
	_animate_status_fx()
