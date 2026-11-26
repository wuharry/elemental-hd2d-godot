class_name SpellRuntime
extends Node3D
## 第一階段場上法術：純配方／狀態在 combat，此處只負責碰撞、空間與效果生命週期。
## 數值都是訓練原型；世界切換時整棵子樹一起釋放，沒有跨場景的延遲還原計時器。

signal feedback(message: String)

const MAX_PROJECTILES := 32
const MAX_ZONES := 8
const MAX_STRUCTURES := 8
const MAX_FLASHES := 48
const TURRET_INTERVAL := 2.2
const TURRET_RANGE := 7.0
const PROJECTILE_SPEED := 11.0
const ZONE_TICK := 0.5
const REACTION_LABELS := {
	"wet": "潮濕", "frozen": "冰凍", "burning": "燃燒", "poisoned": "中毒",
	"electrified": "導電", "extinguished": "滅火", "melted": "融冰",
	"healed": "治療", "blocked": "護盾抵擋",
}

var player: Player
var time_of_day: TimeOfDay
var knowledge: SpellKnowledge
var targets: Array[TrainingTarget] = []
var projectiles: Array[Dictionary] = []
var zones: Array[Dictionary] = []
var structures: Array[Dictionary] = []
var turret_mode := -1
var turret_shots := 0
var _def: SceneDef
var _passthrough: Array[RID] = []
var _flashes: Array[Dictionary] = []
var _turret: StaticBody3D
var _turret_core: MeshInstance3D
var _turret_timer := 0.0
var _book: Node3D
var _shield: Node3D
var _shield_circle: MeshInstance3D
var _shield_aura: MeshInstance3D
var _shield_wards: Array[MeshInstance3D] = []
var _shield_sparks: Array[MeshInstance3D] = []
var _shield_light: OmniLight3D
var _shield_element := -1
var _shield_cast_flash := 0.0
var _shield_was_active := false
var _player_wet_root: Node3D
var _player_wet_puddle: MeshInstance3D
var _player_wet_drips: Array[MeshInstance3D] = []
var _clock := 0.0


func setup(owner_player: Player, lighting: TimeOfDay, spells: SpellKnowledge) -> void:
	player = owner_player
	time_of_day = lighting
	knowledge = spells
	_def = (get_parent() as GameWorld).def
	name = "SpellRuntime"
	add_to_group("spell_runtime")
	_collect_passthrough(get_parent())
	for i in _def.training_targets.size():
		var target := TrainingTarget.new()
		target.name = "MetalTarget" if i == 2 else "WoodTarget%d" % (i + 1)
		target.is_metal = i == 2
		var at := _def.training_targets[i]
		target.position = Vector3(at.x, 0, at.y)
		add_child(target)
		targets.append(target)
	if _def.interactions.has("mage_workshop"):
		var bench := TrainingProps.workshop()
		var p: Vector2 = _def.interactions["mage_workshop"]
		bench.position = Vector3(p.x - 1.3, 0, p.y - 1.3)
		add_child(bench)
	if _def.interactions.has("rain_book"):
		var lectern := TrainingProps.lectern()
		var p: Vector2 = _def.interactions["rain_book"]
		lectern.position = Vector3(p.x, 0, p.y - 0.65)
		add_child(lectern)
		_book = lectern.get_node("Spellbook")
		refresh_book()
	if _def.training_turret.is_finite():
		_build_turret()
	_build_shield()
	_build_player_wet_fx()


func _collect_passthrough(node: Node) -> void:
	if node is CollisionObject3D and node.get_meta("spell_passthrough", false):
		_passthrough.append((node as CollisionObject3D).get_rid())
	for child in node.get_children():
		_collect_passthrough(child)


func refresh_book() -> void:
	if is_instance_valid(_book):
		_book.visible = not knowledge.is_unlocked("rain")


func toggle_turret() -> void:
	if not is_instance_valid(_turret):
		return
	if turret_mode < 0:
		turret_mode = Elements.Type.FIRE
	elif turret_mode == Elements.Type.FIRE:
		turret_mode = Elements.Type.LIGHTNING
	else:
		turret_mode = -1
	_turret_timer = TURRET_INTERVAL
	_turret_core.material_override = Mats.flat(Color("#494a58")) if turret_mode < 0 \
		else Mats.altar_energy(Elements.color(turret_mode), 1.9)
	feedback.emit("訓練砲台：關閉" if turret_mode < 0 else "訓練砲台：%s（霧可遮蔽鎖定）" % Elements.display_name(turret_mode))


func _build_turret() -> void:
	_turret = StaticBody3D.new()
	_turret.name = "TrainingTurret"
	_turret.position = Vector3(_def.training_turret.x, 0, _def.training_turret.y)
	add_child(_turret)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.7, 1.3, 0.7)
	shape.shape = box
	shape.position.y = 0.65
	_turret.add_child(shape)
	Build.box(_turret, Vector3(0.9, 0.25, 0.9), Vector3(0, 0.125, 0), Mats.tri("stone_wall"))
	Build.box(_turret, Vector3(0.40, 0.70, 0.40), Vector3(0, 0.6, 0), Mats.tri("stone_wall", Color("#86799b")))
	Build.box(_turret, Vector3(0.7, 0.18, 0.7), Vector3(0, 1.02, 0), Mats.metal(Color("#c2ac7e")))
	_turret_core = Build.prism(_turret, Vector3(0.4, 0.45, 0.4), Vector3(0, 1.3, 0), Mats.flat(Color("#494a58")))


# ---------- HD-2D 元素護盾（腳下法陣 + 邊緣半透能量罩 + 屬性環繞護符 + 局部光） ----------

func _build_shield() -> void:
	_shield = Node3D.new()
	_shield.name = "ElementShield"
	add_child(_shield)

	_shield_circle = Build.quad(_shield, Vector2(1.70, 1.70), Vector3(0, 0.04, 0),
		Mats.shield_circle(), Vector3(-90.0, 0.0, 0.0))
	_shield_circle.name = "ShieldCircle"
	_shield_circle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_shield_aura = Build.quad(_shield, Vector2(1.88, 1.88), Vector3(0, 0.88, 0), Mats.shield_aura())
	_shield_aura.name = "ShieldAura"
	_shield_aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	for i in 6:
		var ward := Build.prism(_shield, Vector3(0.11, 0.22, 0.07), Vector3.ZERO, Mats.altar_energy(Color.WHITE, 2.0))
		ward.name = "ShieldWard%d" % i
		ward.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_shield_wards.append(ward)

	for i in 6:
		var spark := Build.box(_shield, Vector3(0.042, 0.065, 0.042), Vector3.ZERO, Mats.altar_energy(Color.WHITE, 2.4))
		spark.name = "ShieldSpark%d" % i
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_shield_sparks.append(spark)

	_shield_light = OmniLight3D.new()
	_shield_light.name = "ShieldLight"
	_shield_light.position = Vector3(0, 0.72, 0.15)
	_shield_light.omni_range = 2.4
	_shield_light.omni_attenuation = 1.6
	_shield_light.shadow_enabled = false
	_shield_light.light_volumetric_fog_energy = 0.0
	_shield_light.add_to_group("magic_lights")
	_shield.add_child(_shield_light)
	_shield.visible = false


func _element_palette(e: int) -> Array[Color]:
	match e:
		Elements.Type.WATER:
			return [Color("#28a8f5"), Color("#8ef2ff")]
		Elements.Type.FIRE:
			return [Color("#ff4e1c"), Color("#ffd258")]
		Elements.Type.LIGHTNING:
			return [Color("#9a5cff"), Color("#edd8ff")]
		Elements.Type.ICE:
			return [Color("#42c6f5"), Color("#d6fbff")]
		Elements.Type.EARTH:
			return [Color("#c98a3c"), Color("#ffe082")]
		Elements.Type.ARCANE:
			return [Elements.color(Elements.Type.ARCANE), Elements.gradient_color(Elements.Type.ARCANE, 1.0)]
		Elements.Type.LIFE:
			return [Color("#42d67c"), Color("#d4ff9c")]
		Elements.Type.STEAM:
			return [Color("#c9dce8"), Color("#ffffff")]
		Elements.Type.MIST:
			return [Color("#9ec4de"), Color("#e8f5ff")]
		Elements.Type.WOOD:
			return [Color("#60a84c"), Color("#b8eb80")]
		Elements.Type.POISON:
			return [Color("#72c432"), Color("#d6ff68")]
		Elements.Type.LAVA:
			return [Color("#e84214"), Color("#ffbe3b")]
		Elements.Type.PLASMA:
			return [Color("#c94ef2"), Color("#ffd0ff")]
		Elements.Type.CRYSTAL:
			return [Color("#54cad6"), Color("#d4ffff")]
		Elements.Type.SUPERCONDUCT:
			return [Color("#6898ff"), Color("#e0f4ff")]
		Elements.Type.METAL:
			return [Color("#8da2ba"), Color("#e2eef8")]
		Elements.Type.LIGHT:
			return [Color("#ffda6b"), Color("#fffde6")]
		Elements.Type.MAGNETISM:
			return [Color("#db4a92"), Color("#ffb8df")]
		Elements.Type.MAGIC_CRYSTAL:
			return [Color("#b26ef0"), Color("#ff82b8")]
	var base := Elements.color(e)
	return [base, base.lightened(0.45)]


func _shield_style_id(e: int) -> float:
	match e:
		Elements.Type.WATER: return 0.0
		Elements.Type.FIRE: return 1.0
		Elements.Type.LIGHTNING: return 2.0
		Elements.Type.ICE: return 3.0
		Elements.Type.EARTH: return 4.0
		Elements.Type.ARCANE: return 5.0
		Elements.Type.LIFE: return 6.0
	return 0.0


func _configure_shield_element(e: int) -> void:
	_shield_element = e
	var pal := _element_palette(e)
	var primary := pal[0]
	var accent := pal[1]
	_shield_circle.set_instance_shader_parameter("primary_color", primary)
	_shield_circle.set_instance_shader_parameter("accent_color", accent)
	_shield_aura.set_instance_shader_parameter("primary_color", primary)
	_shield_aura.set_instance_shader_parameter("accent_color", accent)
	_shield_aura.set_instance_shader_parameter("style_id", _shield_style_id(e))
	_shield_light.light_color = primary.lerp(accent, 0.35)

	for i in _shield_wards.size():
		var ward := _shield_wards[i]
		var is_arcane := e == Elements.Type.ARCANE
		if e == Elements.Type.ICE:
			ward.mesh = _sized_prism(Vector3(0.09, 0.28, 0.08))
			ward.material_override = Mats.altar_ice(Vector3(0.09, 0.28, 0.08))
		elif e == Elements.Type.EARTH:
			ward.mesh = _sized_box(Vector3(0.18, 0.22, 0.06))
			ward.material_override = Mats.altar_earth()
		elif e == Elements.Type.LIGHTNING:
			ward.mesh = _sized_box(Vector3(0.036, 0.28, 0.036))
			ward.material_override = Mats.altar_energy(accent if i % 2 == 0 else primary, 2.7)
		elif is_arcane:
			ward.mesh = _sized_prism(Vector3(0.10, 0.20, 0.07))
			ward.material_override = Mats.altar_energy(primary.lerp(accent, float(i) / 5.0), 2.5)
		else:
			ward.mesh = _sized_prism(Vector3(0.10, 0.21, 0.07))
			ward.material_override = Mats.altar_energy(primary.lerp(accent, 0.35 if i % 2 == 0 else 0.7), 2.3)

	for i in _shield_sparks.size():
		var col := primary.lerp(accent, float(i % 3) * 0.45)
		_shield_sparks[i].material_override = Mats.altar_energy(col, 2.6)


func _sized_box(s: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = s
	return m


func _sized_prism(s: Vector3) -> PrismMesh:
	var m := PrismMesh.new()
	m.size = s
	return m


func _update_shield(delta: float) -> void:
	_shield.global_position = player.global_position
	var active := player.combat_state.shield_remaining > 0.0
	_shield.visible = active
	if not active:
		_shield_was_active = false
		return
	var e: int = player.combat_state.shield_element
	if not _shield_was_active or _shield_element != e:
		_shield_was_active = true
		_shield_cast_flash = 1.0
		_configure_shield_element(e)
	_shield_cast_flash = maxf(0.0, _shield_cast_flash - delta * 3.2)

	var rem := player.combat_state.shield_remaining
	# 倒數 1.2 秒改用呼吸明暗脈衝提示，不再整顆護盾粗暴開關閃爍。
	var fade := 1.0 if rem > 1.2 else (0.48 + 0.52 * (0.5 + 0.5 * sin(_clock * 14.0)))
	var pulse_speed := 10.0 if rem < 1.2 else 2.6
	_shield_circle.set_instance_shader_parameter("effect_time", _clock)
	_shield_circle.set_instance_shader_parameter("fade_alpha", fade)
	_shield_circle.set_instance_shader_parameter("pulse_speed", pulse_speed)
	_shield_aura.set_instance_shader_parameter("effect_time", _clock)
	_shield_aura.set_instance_shader_parameter("fade_alpha", fade)
	_shield_aura.set_instance_shader_parameter("cast_flash", _shield_cast_flash)
	_shield_light.light_energy = (0.72 + _shield_cast_flash * 0.85) * fade

	var orbit_r := 0.74
	for i in _shield_wards.size():
		var w := _shield_wards[i]
		var base_a := float(i) * TAU / 6.0
		match e:
			Elements.Type.FIRE:
				var a := _clock * 1.9 + base_a
				var y := 0.55 + fposmod(_clock * 0.65 + float(i) / 6.0, 1.0) * 0.72
				w.position = Vector3(cos(a) * orbit_r, y, sin(a) * orbit_r)
				w.rotation = Vector3(0.25, -a, 0.18 * sin(_clock * 8.0 + i))
			Elements.Type.WATER:
				var a := _clock * 1.45 + base_a
				var y := 0.74 + sin(_clock * 3.4 + base_a * 2.0) * 0.24
				w.position = Vector3(cos(a) * orbit_r, y, sin(a) * orbit_r)
				w.rotation = Vector3(0.2, -a + PI * 0.5, 0.35 * cos(_clock * 3.4 + i))
			Elements.Type.LIGHTNING:
				var tick := floorf(_clock * 15.0)
				var a := _clock * 2.6 + base_a + sin(tick * 3.1 + i * 5.7) * 0.22
				var y := 0.48 + fposmod(sin(tick * 2.3 + i * 7.1) * 43.7, 0.78)
				w.position = Vector3(cos(a) * orbit_r, y, sin(a) * orbit_r)
				w.rotation = Vector3(sin(tick + i) * 0.8, -a, cos(tick * 1.7 + i) * 0.9)
			Elements.Type.ICE:
				var a := _clock * 0.85 + base_a
				var y := 0.80 + (0.14 if i % 2 == 0 else -0.12) + sin(_clock * 1.8 + i) * 0.05
				w.position = Vector3(cos(a) * (orbit_r + 0.04), y, sin(a) * (orbit_r + 0.04))
				w.rotation = Vector3(0.18, -a, -0.22 if i % 2 == 0 else 0.22)
			Elements.Type.EARTH:
				var a := _clock * 0.65 + base_a
				var y := 0.70 + sin(_clock * 1.5 + i * 1.2) * 0.05
				w.position = Vector3(cos(a) * (orbit_r + 0.02), y, sin(a) * (orbit_r + 0.02))
				w.rotation = Vector3(0.0, -a + PI * 0.5, 0.08 * sin(_clock * 2.0 + i))
			Elements.Type.ARCANE:
				var track := -1.0 if i % 2 == 0 else 1.0
				var a := _clock * (1.35 * track) + base_a
				var y := 0.82 + sin(a) * 0.32 * track
				w.position = Vector3(cos(a) * (orbit_r + 0.05), y, sin(a) * (orbit_r + 0.05))
				w.rotation = Vector3(a * 0.6, -a, PI * 0.25)
			_:
				# Life
				var a := _clock * 1.05 + base_a
				var y := 0.68 + sin(_clock * 2.2 + i * 1.3) * 0.20
				w.position = Vector3(cos(a) * orbit_r, y, sin(a) * orbit_r)
				w.rotation = Vector3(0.35, -a, 0.25 * sin(_clock * 2.4 + i))

	for i in _shield_sparks.size():
		var p := fposmod(_clock * (0.72 + (i % 3) * 0.16) + float(i) / 6.0, 1.0)
		var a := _clock * 1.1 + float(i) * TAU / 6.0 + p * 1.8
		var r := 0.62 + sin(p * PI) * 0.18
		_shield_sparks[i].position = Vector3(cos(a) * r, 0.14 + p * 1.35, sin(a) * r)
		_shield_sparks[i].rotation = Vector3(p * 3.0, a, PI * 0.25)


func _build_player_wet_fx() -> void:
	_player_wet_root = Node3D.new()
	_player_wet_root.name = "PlayerWetFX"
	add_child(_player_wet_root)
	_player_wet_puddle = Build.quad(_player_wet_root, Vector2(1.20, 1.20), Vector3(0, 0.032, 0),
		Mats.status_wet_puddle(), Vector3(-90.0, 0.0, 0.0))
	_player_wet_puddle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat_a := Mats.altar_energy(Color("#38bfff"), 2.3)
	var mat_b := Mats.altar_energy(Color("#a2f4ff"), 2.5)
	for i in 8:
		var drip := Build.box(_player_wet_root, Vector3(0.038, 0.085, 0.038), Vector3.ZERO,
			mat_b if i % 2 == 0 else mat_a)
		drip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_player_wet_drips.append(drip)
	_player_wet_root.visible = false


func _update_player_wet_fx() -> void:
	_player_wet_root.global_position = player.global_position
	var wet := player.combat_state.has_status("wet")
	_player_wet_root.visible = wet
	if not wet:
		return
	_player_wet_puddle.set_instance_shader_parameter("effect_time", _clock)
	for i in _player_wet_drips.size():
		var speed := 1.1 + float(i % 4) * 0.17
		var phase := fposmod(_clock * speed + float(i) * 0.173, 1.0)
		var fall := clampf((phase - 0.14) / 0.86, 0.0, 1.0)
		var a := float(i) * TAU / 8.0 + 0.35
		var r := 0.34 if i % 2 == 0 else 0.22
		var start_y := 1.32 if i % 2 == 0 else 0.88
		_player_wet_drips[i].position = Vector3(cos(a) * r, lerpf(start_y, 0.05, fall * fall), sin(a) * r)


# ---------- 法術施放與場上結算 ----------

func cast_spell(spell: Dictionary, origin: Vector3, direction: Vector3) -> void:
	if spell.is_empty() or not is_instance_valid(player):
		return
	var dir := Vector3(direction.x, 0, direction.z).normalized()
	if dir.is_zero_approx():
		return
	var context := {"spell": spell.duplicate(true), "credited": false}
	if spell.get("kind") == "rain":
		if not _def.outer_ground:
			feedback.emit("室內沒有降雨；這次不改變天氣")
			return
		var changed_weather := time_of_day.weather != "rain"
		time_of_day.set_weather("rain")
		if changed_weather:
			_credit(context)
		_ring(player.global_position, Elements.Type.WATER, 1.8)
		feedback.emit("降雨：露天目標逐漸潮濕、熄滅燃燒；R 可切回晴天")
		return
	var element: int = spell["dominant"]
	# 出杖點可能比角色碰撞半徑更靠前；先檢查身體到出杖點，不能穿過薄牆。
	if element != Elements.Type.LIFE:
		var muzzle_hit := _trace(player.global_position + Vector3.UP * 0.9, origin, [player.get_rid()])
		if not muzzle_hit.is_empty():
			_flash(muzzle_hit["position"], element)
			feedback.emit("施法位置被前方物件擋住")
			return
	var distance: float = spell["range"]
	match element:
		Elements.Type.WATER, Elements.Type.ICE, Elements.Type.STEAM:
			_cone(context, origin, dir)
		Elements.Type.LIGHTNING, Elements.Type.ARCANE, Elements.Type.PLASMA, Elements.Type.LIGHT:
			_beam(context, origin, dir, distance, 0, [])
		Elements.Type.LIFE:
			var result := player.combat_state.apply(spell["elements"], float(spell["damage"]))
			if float(result.get("healed", 0)) > 0:
				_credit(context)
			_ring(player.global_position, element, 1.25)
		Elements.Type.MIST, Elements.Type.POISON, Elements.Type.LAVA, Elements.Type.SUPERCONDUCT:
			_zone(context, _landing(origin, dir, minf(distance, 3.0)), element)
		Elements.Type.WOOD, Elements.Type.METAL, Elements.Type.CRYSTAL, Elements.Type.MAGIC_CRYSTAL:
			_structure(context, _landing(origin, dir, minf(distance, 2.8)), element)
		Elements.Type.MAGNETISM:
			_magnet(context, _landing(origin, dir, minf(distance, 3.0)))
		_:
			_projectile(context, origin, dir, false)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(time_of_day):
		return
	_clock += delta
	var rain := _def.outer_ground and time_of_day.rain_intensity > 0.15
	player.combat_state.is_concealed = is_in_mist(player.global_position)
	if rain:
		player.combat_state.rain_exposure(delta)
	for target in targets:
		target.combat_state.is_concealed = is_in_mist(target.global_position)
		if rain:
			target.combat_state.rain_exposure(delta)
	_tick_projectiles(delta)
	_tick_zones(delta)
	_tick_structures(delta)
	_tick_flashes(delta)
	_tick_turret(delta)
	_update_shield(delta)
	_update_player_wet_fx()


func _projectile(context: Dictionary, origin: Vector3, dir: Vector3, hostile: bool) -> void:
	if projectiles.size() >= MAX_PROJECTILES:
		_remove_effect(projectiles, 0)
	var n := Node3D.new()
	n.name = "HostileBolt" if hostile else "SpellProjectile"
	add_child(n)
	n.global_position = origin
	var spell: Dictionary = context["spell"]
	var e: int = spell["dominant"]
	var pal := _element_palette(e)
	var rocky := e == Elements.Type.EARTH
	var core := Node3D.new()
	core.name = "Core"
	n.add_child(core)
	var orb_mesh: MeshInstance3D = null
	var trail_nodes: Array[Node3D] = []
	if rocky:
		var rock_mat := Mats.altar_earth()
		Build.box(core, Vector3(0.36, 0.32, 0.34), Vector3.ZERO, rock_mat)
		Build.box(core, Vector3(0.24, 0.20, 0.24), Vector3(0.10, 0.12, -0.06), rock_mat, Vector3(25, 35, 15))
		for i in 4:
			var pebble := Build.box(n, Vector3.ONE * (0.09 - i * 0.015), -dir * (0.28 + i * 0.16), Mats.altar_energy(pal[1], 1.8))
			pebble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			trail_nodes.append(pebble)
	else:
		orb_mesh = Build.quad(n, Vector2(0.50, 0.50), Vector3.ZERO, Mats.spell_orb())
		orb_mesh.set_instance_shader_parameter("primary_color", pal[0])
		orb_mesh.set_instance_shader_parameter("accent_color", pal[1])
		orb_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var inner := Build.box(core, Vector3.ONE * 0.15, Vector3.ZERO, Mats.altar_energy(pal[1], 2.6))
		inner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in 5:
			var wisp_col := pal[0].lerp(pal[1], 1.0 - float(i) * 0.2)
			var wisp := Build.box(n, Vector3.ONE * (0.11 - i * 0.016), -dir * (0.16 + i * 0.13), Mats.altar_energy(wisp_col, 2.2))
			wisp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			trail_nodes.append(wisp)
	var light := OmniLight3D.new()
	light.light_color = pal[0].lerp(pal[1], 0.3)
	light.light_energy = 1.15
	light.omni_range = 2.6
	light.omni_attenuation = 1.6
	light.shadow_enabled = false
	light.light_volumetric_fog_energy = 0.0
	light.add_to_group("magic_lights")
	n.add_child(light)
	projectiles.append({"node": n, "core": core, "orb": orb_mesh, "trails": trail_nodes,
		"context": context, "dir": dir, "age": 0.0,
		"remaining": float(spell["range"]), "hostile": hostile, "speed": 7.0 if rocky else PROJECTILE_SPEED})


func _tick_projectiles(delta: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var bolt: Dictionary = projectiles[i]
		var n: Node3D = bolt["node"]
		bolt["age"] = float(bolt["age"]) + delta
		var age: float = bolt["age"]
		var dir: Vector3 = bolt["dir"]
		var step := minf(float(bolt["remaining"]), float(bolt["speed"]) * delta)
		var start := n.global_position
		var finish: Vector3 = start + dir * step
		var exclude: Array[RID] = []
		if bolt["hostile"] and is_instance_valid(_turret):
			exclude.append(_turret.get_rid())
		else:
			exclude.append(player.get_rid())
		var hit := _trace(start, finish, exclude)
		if not hit.is_empty():
			var collider: Object = hit["collider"]
			if collider == player and bolt["hostile"]:
				var spell: Dictionary = bolt["context"]["spell"]
				var result := player.combat_state.apply(spell["elements"], spell["damage"])
				feedback.emit("護盾擋住%s" % Elements.display_name(spell["dominant"]) if result.get("blocked", false) else "受到訓練砲台攻擊")
			elif not bolt["hostile"]:
				_hit(collider, bolt["context"], dir)
			_flash(hit["position"], int(bolt["context"]["spell"]["dominant"]))
			_remove_effect(projectiles, i)
			continue
		n.global_position = finish
		var core: Node3D = bolt["core"]
		core.rotation += Vector3(2.8, 3.6, 1.9) * delta
		if is_instance_valid(bolt["orb"]):
			(bolt["orb"] as MeshInstance3D).set_instance_shader_parameter("effect_time", _clock + age)
		var side := dir.cross(Vector3.UP).normalized()
		var trails: Array = bolt["trails"]
		for j in trails.size():
			var t_node: Node3D = trails[j]
			var sway := sin(age * 20.0 - j * 1.4) * 0.065 * float(j + 1) * 0.35
			var lift := cos(age * 16.0 - j * 1.1) * 0.045 * float(j + 1) * 0.35
			t_node.position = -dir * (0.16 + j * 0.14) + side * sway + Vector3.UP * lift
			t_node.rotation = Vector3(age * 4.0 + j, age * 5.0, j)
		bolt["remaining"] = float(bolt["remaining"]) - step
		if float(bolt["remaining"]) <= 0:
			_remove_effect(projectiles, i)


func _cone(context: Dictionary, origin: Vector3, dir: Vector3) -> void:
	var spell: Dictionary = context["spell"]
	var e: int = spell["dominant"]
	var pal := _element_palette(e)
	var distance := minf(float(spell["range"]), 4.5)
	_spawn_cone_vfx(origin, dir, distance, e, pal)
	for target in targets:
		var toward := target.global_position + Vector3.UP * 0.85 - origin
		if toward.length() <= distance and toward.normalized().dot(dir) > 0.78 \
				and _clear_to(origin, target.global_position + Vector3.UP * 0.85, target, [player.get_rid()]):
			_hit(target, context, dir)
	_environment_reactions(context, origin, origin + dir * distance, 1.4)


func _spawn_cone_vfx(origin: Vector3, dir: Vector3, distance: float, e: int, pal: Array[Color]) -> void:
	if _flashes.size() >= MAX_FLASHES:
		_remove_effect(_flashes, 0)
	var root := Node3D.new()
	root.name = "ConeVFX"
	add_child(root)
	var movers: Array[Dictionary] = []
	for i in 9:
		var spread := (float(i) - 4.0) * 0.095
		var ray := dir.rotated(Vector3.UP, spread)
		var hit := _trace(origin, origin + ray * distance, [player.get_rid()])
		var end: Vector3 = hit.get("position", origin + ray * distance)
		var seg_len := origin.distance_to(end)
		if seg_len < 0.08:
			continue
		var col := pal[0].lerp(pal[1], 0.35 if i % 2 == 0 else 0.75)
		if e == Elements.Type.STEAM:
			# 蒸汽：多團翻滾膨脹的白銀熱氣團 + 熱壓流線
			for k in 3:
				var frac := 0.22 + k * 0.30
				var puff := Build.quad(root, Vector2(0.75 + k * 0.35, 0.65 + k * 0.25),
					origin.lerp(end, frac) + Vector3(0, 0.05 * k, 0), Mats.spell_mist())
				puff.rotation.y = float(i + k) * 0.8
				puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				movers.append({"node": puff, "vel": ray * (2.6 + k * 0.8) + Vector3.UP * 0.85})
		elif e == Elements.Type.ICE:
			# 寒冰：銳利冰錐飛刃與冰霜碎屑扇面
			var mat := Mats.altar_energy(col, 2.2)
			for k in 2:
				var d := minf(0.35 + k * 0.75, seg_len * (0.35 + k * 0.30))
				var shard := Build.prism(root, Vector3(0.085, 0.28 + k * 0.08, 0.085),
					origin + ray * d, mat)
				shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				shard.look_at(end, Vector3.UP)
				shard.rotate_object_local(Vector3.RIGHT, -PI * 0.5)
				movers.append({"node": shard, "vel": ray * (6.2 + k * 1.4)})
		else:
			# 水流：波浪起伏的高壓水柱與飛濺水珠
			var stream := Build.box(root, Vector3(0.065, 0.055, seg_len * 0.85),
				origin.lerp(end, 0.45), Mats.altar_energy(col, 2.1))
			stream.look_at(end, Vector3.UP)
			stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var d := minf(0.4 + (i % 3) * 0.55, seg_len * 0.65)
			var drop := Build.box(root, Vector3(0.06, 0.06, 0.14), origin + ray * d,
				Mats.altar_energy(pal[1], 2.4))
			drop.look_at(end, Vector3.UP)
			drop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			movers.append({"node": drop, "vel": ray * 7.5 + Vector3.UP * 0.55})
	_flashes.append({"node": root, "remaining": 0.34, "duration": 0.34, "movers": movers})


func _beam(context: Dictionary, origin: Vector3, dir: Vector3, distance: float, bounce: int, excluded: Array[RID]) -> void:
	if distance <= 0.05 or bounce > 3:
		return
	var spell: Dictionary = context["spell"]
	var e: int = spell["dominant"]
	var omit: Array[RID] = excluded.duplicate()
	if not omit.has(player.get_rid()):
		omit.append(player.get_rid())
	var hit := _trace(origin, origin + dir * distance, omit)
	var end: Vector3 = hit.get("position", origin + dir * distance)
	_spawn_beam_vfx(origin, end, e)
	_environment_reactions(context, origin, end, 0.4)
	if hit.is_empty():
		return
	var collider: Object = hit["collider"]
	var structure := _find_structure(collider)
	if not structure.is_empty():
		if e == Elements.Type.LIGHT and int(structure["element"]) == Elements.Type.CRYSTAL:
			var reflected := dir.bounce(hit["normal"]).normalized()
			_flash(end, Elements.Type.LIGHT)
			_credit(context)
			_beam(context, end + reflected * 0.04, reflected, distance - origin.distance_to(end), bounce + 1, [])
			return
		if int(structure["element"]) == Elements.Type.MAGIC_CRYSTAL:
			if e == Elements.Type.ARCANE:
				structure["charge"] = minf(float(structure["charge"]) + float(spell["damage"]), 80.0)
				_flash(end, Elements.Type.ARCANE)
				_credit(context)
				feedback.emit("魔晶儲能 %.0f；用光束觸發釋放" % float(structure["charge"]))
				return
			if e == Elements.Type.LIGHT and float(structure["charge"]) > 0:
				# 釋放與後續命中是同一次施法；複製增加傷害前先沿用已計數的狀態。
				_credit(context)
				var charged := context.duplicate(true)
				charged["spell"]["damage"] += float(structure["charge"])
				structure["charge"] = 0.0
				_flash(end, Elements.Type.MAGIC_CRYSTAL)
				omit.append((collider as CollisionObject3D).get_rid())
				_beam(charged, end + dir * 0.04, dir, distance - origin.distance_to(end), bounce + 1, omit)
				return
	_flash(end, e)
	_hit(collider, context, dir)
	if e == Elements.Type.PLASMA and collider is TrainingTarget:
		omit.append((collider as CollisionObject3D).get_rid())
		_beam(context, end + dir * 0.04, dir, distance - origin.distance_to(end), bounce + 1, omit)
	if e == Elements.Type.LIGHTNING:
		_chain(context, collider, end)


func _spawn_beam_vfx(start: Vector3, end: Vector3, e: int) -> void:
	var total := start.distance_to(end)
	if total < 0.04:
		return
	if _flashes.size() >= MAX_FLASHES:
		_remove_effect(_flashes, 0)
	var root := Node3D.new()
	root.name = "BeamVFX"
	add_child(root)
	var pal := _element_palette(e)
	var dir := (end - start) / total
	var side := dir.cross(Vector3.UP)
	if side.length_squared() < 0.001:
		side = Vector3.RIGHT
	else:
		side = side.normalized()

	if e == Elements.Type.LIGHTNING:
		# 紫色多段鋸齒閃電 + 分叉電弧火花
		var segs := clampi(int(total / 0.55), 3, 14)
		var pts: Array[Vector3] = []
		for i in segs + 1:
			var frac := float(i) / float(segs)
			var p := start.lerp(end, frac)
			if i > 0 and i < segs:
				var jitter := sin(_clock * 47.0 + float(i) * 5.3) * 0.22
				var y_jit := cos(_clock * 39.0 + float(i) * 7.1) * 0.11
				p += side * jitter + Vector3.UP * y_jit
			pts.append(p)
		for i in segs:
			_add_segment(root, pts[i], pts[i + 1], pal[1], 0.032, 3.0)
			_add_segment(root, pts[i], pts[i + 1], pal[0], 0.058, 1.7)
			if i % 2 == 1:
				var fork_end := pts[i] + side * (0.34 if i % 4 == 1 else -0.34) + dir * 0.25 + Vector3.UP * 0.08
				_add_segment(root, pts[i], fork_end, pal[0], 0.022, 2.4)
	elif e == Elements.Type.ARCANE:
		# 奧術：紫到紅雙層螺旋能量束
		var segs := clampi(int(total / 0.65), 3, 12)
		for i in segs:
			var t0 := float(i) / float(segs)
			var t1 := float(i + 1) / float(segs)
			var col := pal[0].lerp(pal[1], (t0 + t1) * 0.5)
			_add_segment(root, start.lerp(end, t0), start.lerp(end, t1), col, 0.058, 2.5)
			var spiral0 := start.lerp(end, t0) + side * sin(t0 * 14.0 + _clock * 8.0) * 0.12 + Vector3.UP * cos(t0 * 14.0 + _clock * 8.0) * 0.10
			var spiral1 := start.lerp(end, t1) + side * sin(t1 * 14.0 + _clock * 8.0) * 0.12 + Vector3.UP * cos(t1 * 14.0 + _clock * 8.0) * 0.10
			_add_segment(root, spiral0, spiral1, pal[1].lerp(pal[0], t0), 0.026, 2.8)
	elif e == Elements.Type.PLASMA:
		# 電漿：粗熾白紫粉貫穿核心 + 外圍電離光束
		_add_segment(root, start, end, pal[1], 0.065, 3.4)
		_add_segment(root, start, end, pal[0], 0.115, 2.0)
	else:
		# 光束或其他：明亮雙層光軸
		_add_segment(root, start, end, pal[1], 0.042, 3.2)
		_add_segment(root, start, end, pal[0], 0.075, 1.9)

	_flashes.append({"node": root, "remaining": 0.26, "duration": 0.26})


func _add_segment(parent: Node3D, a: Vector3, b: Vector3, color: Color, width: float, lum: float) -> void:
	var dist := a.distance_to(b)
	if dist < 0.02:
		return
	var mi := Build.box(parent, Vector3(width, width, dist), (a + b) * 0.5, Mats.altar_energy(color, lum))
	var up := Vector3.RIGHT if absf(a.direction_to(b).dot(Vector3.UP)) > 0.98 else Vector3.UP
	mi.look_at(b, up)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _chain(context: Dictionary, first: Object, at: Vector3) -> void:
	var first_target := first as TrainingTarget
	var structure := _find_structure(first)
	if first_target != null and not first_target.is_metal \
			and not first_target.combat_state.statuses.has("wet") \
			and not first_target.combat_state.statuses.has("conductive"):
		return
	if first_target == null and (structure.is_empty() or int(structure["element"]) != Elements.Type.METAL):
		return
	var omitted: Array[RID] = [player.get_rid()]
	if first is CollisionObject3D:
		omitted.append((first as CollisionObject3D).get_rid())
	for target in targets:
		if target == first or target.combat_state.health <= 0:
			continue
		var tip := target.global_position + Vector3.UP * 0.9
		if at.distance_to(tip) > 3.4 or _mist_blocks(at, tip):
			continue
		if not target.is_metal and not target.combat_state.statuses.has("wet") \
				and not target.combat_state.statuses.has("conductive"):
			continue
		if _clear_to(at, tip, target, omitted):
			_spawn_beam_vfx(at, tip, Elements.Type.LIGHTNING)
			_hit(target, context, Vector3.ZERO)


func _hit(collider: Object, context: Dictionary, dir: Vector3) -> void:
	var spell: Dictionary = context["spell"]
	if collider is TrainingTarget:
		var target := collider as TrainingTarget
		var damage: float = spell["damage"]
		if target.combat_state.statuses.has("vulnerable"):
			damage *= 1.25
		var result := target.take_spell(spell["elements"], damage)
		if result.is_empty():
			return
		_credit(context)
		if spell["dominant"] in [Elements.Type.EARTH, Elements.Type.STEAM]:
			_move_target(target, dir * 0.65)
		if not String(result.get("reaction", "")).is_empty():
			var labels := PackedStringArray()
			for reaction: String in String(result["reaction"]).split("+"):
				if REACTION_LABELS.has(reaction):
					labels.append(REACTION_LABELS[reaction])
			if not labels.is_empty():
				feedback.emit("%s：%s" % ["金屬標的" if target.is_metal else "木樁", "／".join(labels)])
		return
	var structure := _find_structure(collider)
	if structure.is_empty():
		return
	if int(structure["element"]) == Elements.Type.WOOD and (spell["elements"] as Array).has(Elements.Type.FIRE):
		var p: Vector3 = (structure["node"] as Node3D).global_position
		structure["remaining"] = 0.0
		_zone(context, p, Elements.Type.FIRE)
		_credit(context)
		feedback.emit("木構造被點燃")


func _landing(origin: Vector3, dir: Vector3, distance: float) -> Vector3:
	var hit := _trace(origin, origin + dir * distance, [player.get_rid()])
	var p: Vector3 = hit.get("position", origin + dir * distance)
	if not hit.is_empty():
		p -= dir * 0.6
	p.y = 0.03
	return p


func _zone(context: Dictionary, at: Vector3, element: int) -> void:
	if _def.is_void(Vector2(at.x, at.z)):
		return
	if zones.size() >= MAX_ZONES:
		_remove_effect(zones, 0)
	var spell: Dictionary = context["spell"]
	var radius := clampf(float(spell["radius"]), 1.1, 2.6)
	if element == Elements.Type.MIST:
		radius = maxf(radius, 2.2)
	var n := Node3D.new()
	n.name = "SpellZone"
	add_child(n)
	n.global_position = at
	var pal := _element_palette(element)
	var pool_mesh: MeshInstance3D = null
	var motes: Array[Node3D] = []
	if element == Elements.Type.MIST:
		for i in 12:
			var a := float(i) * TAU / 12.0
			var dist := radius * (0.28 if i % 3 == 0 else 0.62)
			var puff := Build.quad(n, Vector2(2.3, 1.6), Vector3(sin(a) * dist, 0.65 + (i % 3) * 0.24, cos(a) * dist), Mats.spell_mist())
			puff.rotation.y = float(i % 4) * PI / 4.0
			puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			motes.append(puff)
	else:
		var style := 3.0
		if element == Elements.Type.LAVA:
			style = 0.0
		elif element == Elements.Type.POISON:
			style = 1.0
		elif element == Elements.Type.FIRE:
			style = 2.0
		pool_mesh = Build.quad(n, Vector2(radius * 2.1, radius * 2.1), Vector3(0, 0.03, 0),
			Mats.spell_zone_pool(), Vector3(-90.0, 0.0, 0.0))
		pool_mesh.set_instance_shader_parameter("primary_color", pal[0])
		pool_mesh.set_instance_shader_parameter("accent_color", pal[1])
		pool_mesh.set_instance_shader_parameter("style_id", style)
		pool_mesh.set_instance_shader_parameter("fade_alpha", 1.0)
		pool_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in 8:
			var a := float(i) * TAU / 8.0
			var r := radius * (0.35 + 0.45 * float(i % 2))
			var col := pal[1] if i % 2 == 0 else pal[0]
			var s := Vector3(0.06, 0.14, 0.06) if element == Elements.Type.FIRE else Vector3(0.075, 0.075, 0.075)
			var mote := Build.box(n, s, Vector3(cos(a) * r, 0.15, sin(a) * r), Mats.altar_energy(col, 2.2))
			mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			motes.append(mote)
		var light := OmniLight3D.new()
		light.position = Vector3(0, 0.45, 0)
		light.light_color = pal[0].lerp(pal[1], 0.35)
		light.light_energy = 0.85
		light.omni_range = radius + 1.4
		light.omni_attenuation = 1.6
		light.shadow_enabled = false
		light.light_volumetric_fog_energy = 0.0
		light.add_to_group("magic_lights")
		n.add_child(light)
	zones.append({"node": n, "pool": pool_mesh, "motes": motes, "element": element, "radius": radius,
		"remaining": clampf(float(spell["duration"]), 4.0, 12.0), "tick": 0.0, "context": context})
	_credit(context)


func _tick_zones(delta: float) -> void:
	for i in range(zones.size() - 1, -1, -1):
		var zone: Dictionary = zones[i]
		var n: Node3D = zone["node"]
		zone["remaining"] = float(zone["remaining"]) - delta
		zone["tick"] = float(zone["tick"]) - delta
		var e: int = zone["element"]
		var radius: float = zone["radius"]
		var motes: Array = zone["motes"]
		if is_instance_valid(zone["pool"]):
			var pool := zone["pool"] as MeshInstance3D
			pool.set_instance_shader_parameter("effect_time", _clock)
			pool.set_instance_shader_parameter("fade_alpha", clampf(float(zone["remaining"]) / 0.8, 0.0, 1.0))
		if e == Elements.Type.MIST:
			for j in motes.size():
				var puff: Node3D = motes[j]
				puff.position.y = 0.65 + (j % 3) * 0.24 + sin(_clock * 0.9 + j) * 0.16
		else:
			for j in motes.size():
				var mote: Node3D = motes[j]
				var p := fposmod(_clock * (0.75 + (j % 3) * 0.22) + float(j) / float(motes.size()), 1.0)
				var a := float(j) * TAU / float(motes.size()) + _clock * 0.45
				var r := radius * (0.28 + 0.55 * float(j % 2))
				mote.position = Vector3(cos(a) * r, 0.08 + p * (0.75 if e == Elements.Type.FIRE else 0.52), sin(a) * r)
				mote.rotation = Vector3(p * 2.5, a, PI * 0.25)
		if float(zone["tick"]) <= 0:
			zone["tick"] = ZONE_TICK
			var components: Array[int] = []
			for component: int in zone["context"]["spell"]["elements"]:
				if component != Elements.Type.MIST:
					components.append(component)
			if e != Elements.Type.MIST and not components.has(e):
				components = [e]
			for target in targets:
				if not _within(n.global_position, target.global_position, radius) or target.combat_state.health <= 0:
					continue
				if not _clear_to(n.global_position + Vector3.UP * 0.5, target.global_position + Vector3.UP * 0.9, target, [player.get_rid()]):
					continue
				if e == Elements.Type.SUPERCONDUCT:
					target.combat_state.statuses["conductive"] = 2.0
					target.combat_state.statuses["vulnerable"] = 2.0
					_ring(target.global_position, e, 0.72)
					_apply_extra_payload(zone["context"], target, e)
				elif e == Elements.Type.MIST:
					_apply_mist_payload(zone["context"], target.combat_state, components)
				elif not components.is_empty():
					target.take_spell(components, 4.0)
				_credit(zone["context"])
			if e == Elements.Type.MIST \
					and _within(n.global_position, player.global_position, radius) \
					and _clear_to(n.global_position + Vector3.UP * 0.5, player.global_position + Vector3.UP * 0.9, player, []):
				# 第一版自我作用只接水／生命支援；友傷規則仍待另一階段。
				var support: Array[int] = []
				for component: int in components:
					if component in [Elements.Type.WATER, Elements.Type.LIFE]:
						support.append(component)
				_apply_mist_payload(zone["context"], player.combat_state, support)
		if float(zone["remaining"]) <= 0:
			_remove_effect(zones, i)


func _structure(context: Dictionary, at: Vector3, element: int) -> void:
	if not _can_place(at):
		return
	if structures.size() >= MAX_STRUCTURES:
		_remove_effect(structures, 0)
	var n := Node3D.new()
	n.name = "ElementStructure"
	add_child(n)
	n.global_position = at
	var core_mesh: MeshInstance3D = null
	var orbiters: Array[Node3D] = []
	if element == Elements.Type.CRYSTAL:
		var main_sz := Vector3(0.56, 1.42, 0.44)
		core_mesh = Build.prism(n, main_sz, Vector3(0, 0.71, 0), Mats.altar_ice(main_sz))
		var side_sz := Vector3(0.32, 0.82, 0.28)
		Build.prism(n, side_sz, Vector3(-0.28, 0.40, 0.06), Mats.altar_ice(side_sz), Vector3(0, 12, 16))
		Build.prism(n, side_sz, Vector3(0.28, 0.36, -0.05), Mats.altar_ice(side_sz), Vector3(0, -14, -18))
	elif element == Elements.Type.MAGIC_CRYSTAL:
		core_mesh = Build.prism(n, Vector3(0.58, 1.38, 0.44), Vector3(0, 0.72, 0), Mats.altar_energy(Elements.color(element), 1.4))
		Build.box(n, Vector3(0.76, 0.14, 0.60), Vector3(0, 0.07, 0), Mats.tri("flagstone", Color("#64567a")))
		for i in 4:
			var col := Elements.color(Elements.Type.ARCANE) if i % 2 == 0 else Elements.gradient_color(Elements.Type.ARCANE, 1.0)
			var mote := Build.box(n, Vector3(0.06, 0.06, 0.06), Vector3.ZERO, Mats.altar_energy(col, 2.3))
			mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			orbiters.append(mote)
	elif element == Elements.Type.WOOD:
		var bark := Mats.tri("bark", Color("#98aa72"))
		var leaf := Mats.foliage(Color("#a8e07a"), 0.02)
		core_mesh = Build.box(n, Vector3(0.34, 1.05, 0.30), Vector3(0, 0.52, 0), bark)
		Build.box(n, Vector3(0.24, 0.84, 0.26), Vector3(-0.26, 0.42, 0.04), bark, Vector3(0, 8, 9))
		Build.box(n, Vector3(0.24, 0.90, 0.24), Vector3(0.26, 0.45, -0.04), bark, Vector3(0, -10, -8))
		Build.box(n, Vector3(0.84, 0.28, 0.52), Vector3(0, 1.08, 0), leaf)
	elif element == Elements.Type.METAL:
		var steel := Mats.metal(Color("#9ab0c4"))
		var trim := Mats.metal(Color("#5d6d82"))
		core_mesh = Build.box(n, Vector3(0.62, 1.02, 0.38), Vector3(0, 0.51, 0), steel)
		Build.box(n, Vector3(0.74, 0.14, 0.48), Vector3(0, 0.07, 0), trim)
		Build.box(n, Vector3(0.70, 0.10, 0.44), Vector3(0, 1.04, 0), trim)
		Build.prism(n, Vector3(0.24, 0.34, 0.24), Vector3(0, 1.24, 0), Mats.altar_energy(Color("#b6d6ff"), 1.6))
	else:
		# Earth / solidified lava monolith
		var stone := Mats.tri("stone_wall", Color("#766e72"))
		core_mesh = Build.box(n, Vector3(0.46, 1.05, 0.38), Vector3(0, 0.52, 0), stone)
		Build.box(n, Vector3(0.26, 0.78, 0.32), Vector3(-0.28, 0.39, 0.04), stone, Vector3(0, 12, 5))
		Build.box(n, Vector3(0.26, 0.84, 0.30), Vector3(0.28, 0.42, -0.04), stone, Vector3(0, -10, -6))
	var body := Build.collider(n, Vector3(0.8, 1.4, 0.45), Vector3(0, 0.7, 0))
	n.rotation.y = PI / 4.0 if element == Elements.Type.CRYSTAL else 0.0
	var data := {"node": n, "core": core_mesh, "orbiters": orbiters, "body": body,
		"element": element, "charge": 0.0, "context": context, "remaining": 12.0, "tick": 0.0}
	structures.append(data)
	_credit(context)


func _tick_structures(delta: float) -> void:
	for i in range(structures.size() - 1, -1, -1):
		var structure: Dictionary = structures[i]
		structure["remaining"] = float(structure["remaining"]) - delta
		structure["tick"] = float(structure["tick"]) - delta
		var n: Node3D = structure["node"]
		var e: int = structure["element"]
		if e == Elements.Type.MAGIC_CRYSTAL:
			var charge: float = float(structure["charge"])
			var mi: MeshInstance3D = structure["core"]
			mi.material_override = Mats.altar_energy(Elements.color(Elements.Type.MAGIC_CRYSTAL), 2.5 if charge > 0 else 1.35)
			var speed := 3.6 if charge > 0 else 1.2
			var orbiters: Array = structure["orbiters"]
			for j in orbiters.size():
				var a := _clock * speed + j * TAU / float(orbiters.size())
				(orbiters[j] as Node3D).position = Vector3(cos(a) * 0.46, 0.55 + j * 0.18 + sin(_clock * 3.0 + j) * 0.08, sin(a) * 0.46)
		if float(structure["tick"]) <= 0:
			structure["tick"] = ZONE_TICK
			var extra := _extra_elements(structure["context"], e)
			if e == Elements.Type.WOOD and extra.has(Elements.Type.FIRE):
				# 「木＋火」保留木的燃燒關係；沒有按融合鍵，不可憑空變成熔岩。
				_zone(structure["context"], n.global_position, Elements.Type.FIRE)
				structure["remaining"] = 0.0
			var radius := 3.4 if e == Elements.Type.METAL and extra.has(Elements.Type.LIGHTNING) else 1.8
			for target in targets:
				if _within(n.global_position, target.global_position, radius) and target.combat_state.health > 0 \
						and _clear_to(n.global_position + Vector3.UP, target.global_position + Vector3.UP, target,
						[(structure["body"] as CollisionObject3D).get_rid(), player.get_rid()]):
					if e == Elements.Type.WOOD:
						target.combat_state.statuses["rooted"] = 1.5
						_line(n.global_position + Vector3.UP * 0.15, target.global_position + Vector3.UP * 0.2,
							Elements.color(Elements.Type.WOOD), 0.06, 0.45)
					if _apply_extra_payload(structure["context"], target, e):
						_spawn_beam_vfx(n.global_position + Vector3.UP * 0.9, target.global_position + Vector3.UP * 0.9, extra[0])
		if float(structure["remaining"]) <= 0:
			_remove_effect(structures, i)


func _magnet(context: Dictionary, at: Vector3) -> void:
	var repel: bool = (context["spell"]["elements"] as Array).has(Elements.Type.LIGHTNING)
	_ring(at, Elements.Type.MAGNETISM, 2.8)
	for target in targets:
		if target.is_metal and _within(at, target.global_position, 3.5):
			var direction := at.direction_to(target.global_position) if repel else target.global_position.direction_to(at)
			if _move_target(target, direction * 1.25):
				_credit(context)
		if _within(at, target.global_position, 3.5) and _clear_to(at + Vector3.UP * 0.9,
				target.global_position + Vector3.UP * 0.9, target, [player.get_rid()]):
			_apply_extra_payload(context, target, Elements.Type.MAGNETISM)
	for structure in structures:
		if int(structure["element"]) != Elements.Type.METAL:
			continue
		var n: Node3D = structure["node"]
		if not _within(at, n.global_position, 3.5):
			continue
		var movement := at.direction_to(n.global_position) if repel else n.global_position.direction_to(at)
		movement.y = 0
		var dest := n.global_position + movement * 1.25
		var body := structure["body"] as StaticBody3D
		if not _def.is_void(Vector2(dest.x, dest.z)) and not body.test_move(body.global_transform, movement * 1.25):
			n.global_position = dest
			_credit(context)
	feedback.emit("磁力排斥金屬" if repel else "磁力吸引金屬；加入雷可改成排斥")


func _move_target(target: TrainingTarget, offset: Vector3) -> bool:
	if target.combat_state.statuses.has("rooted") or target.combat_state.statuses.has("frozen"):
		return false
	offset.y = 0
	var dest := target.global_position + offset
	if _def.is_void(Vector2(dest.x, dest.z)):
		return false
	if target.test_move(target.global_transform, offset):
		return false
	target.global_position = dest
	return true


func _environment_reactions(context: Dictionary, start: Vector3, end: Vector3, width: float) -> void:
	var elements: Array = context["spell"]["elements"]
	for zone in zones:
		var p: Vector3 = (zone["node"] as Node3D).global_position
		if _segment_distance_xz(start, end, p) > float(zone["radius"]) + width:
			continue
		if not _clear_to(start, p + Vector3.UP * 0.5, null, [player.get_rid()]):
			continue
		if elements.has(Elements.Type.LIGHT) and int(zone["element"]) == Elements.Type.MIST:
			zone["remaining"] = 0.0
			_credit(context)
			feedback.emit("光束驅散霧，恢復視線")
		elif elements.has(Elements.Type.WATER) and int(zone["element"]) == Elements.Type.LAVA:
			zone["remaining"] = 0.0
			_structure(context, p, Elements.Type.EARTH)
			_credit(context)
			feedback.emit("熔岩遇水凝固為石障")
		elif elements.has(Elements.Type.WATER) and int(zone["element"]) == Elements.Type.FIRE:
			zone["remaining"] = 0.0
			_credit(context)
			feedback.emit("水熄滅燃燒區")


func _tick_turret(delta: float) -> void:
	if turret_mode < 0 or not is_instance_valid(_turret):
		return
	_turret_timer -= delta
	var origin := _turret.global_position + Vector3.UP * 1.3
	var aim := player.global_position + Vector3.UP * 0.9
	if origin.distance_to(aim) > TURRET_RANGE or player.combat_state.health <= 0:
		return
	if _mist_blocks(origin, aim) or not _clear_to(origin, aim, player, [_turret.get_rid()]):
		return
	if _turret_timer <= 0:
		_turret_timer = TURRET_INTERVAL
		var components: Array[int] = [turret_mode]
		var spell := SpellRules.resolve(components)
		spell["damage"] = 8.0
		spell["range"] = TURRET_RANGE
		var dir := origin.direction_to(aim)
		_projectile({"spell": spell, "credited": true}, origin + dir * 0.55, dir, true)
		turret_shots += 1


func _trace(start: Vector3, end: Vector3, excluded: Array[RID]) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(start, end, 1)
	query.exclude = _passthrough + excluded
	query.hit_from_inside = true
	return get_world_3d().direct_space_state.intersect_ray(query)


func _clear_to(start: Vector3, end: Vector3, target: Object, excluded: Array[RID]) -> bool:
	var hit := _trace(start, end, excluded)
	return hit.is_empty() or hit.get("collider") == target


func has_line_of_sight(start: Vector3, end: Vector3) -> bool:
	return not _mist_blocks(start, end) and _trace(start, end, [player.get_rid()]).is_empty()


func is_in_mist(at: Vector3) -> bool:
	for zone in zones:
		if int(zone["element"]) == Elements.Type.MIST and float(zone["remaining"]) > 0 \
				and _within((zone["node"] as Node3D).global_position, at, zone["radius"]):
			return true
	return false


func _mist_blocks(start: Vector3, end: Vector3) -> bool:
	for zone in zones:
		if int(zone["element"]) == Elements.Type.MIST and float(zone["remaining"]) > 0 \
				and _segment_distance_xz(start, end, (zone["node"] as Node3D).global_position) < float(zone["radius"]):
			return true
	return false


func _segment_distance_xz(start: Vector3, end: Vector3, point: Vector3) -> float:
	var a := Vector2(start.x, start.z)
	var b := Vector2(end.x, end.z)
	var p := Vector2(point.x, point.z)
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.00001), 0, 1)
	return p.distance_to(a + ab * t)


func _within(a: Vector3, b: Vector3, radius: float) -> bool:
	return Vector2(a.x, a.z).distance_squared_to(Vector2(b.x, b.z)) <= radius * radius


func _find_structure(collider: Object) -> Dictionary:
	for structure in structures:
		if structure["body"] == collider:
			return structure
	return {}


func _extra_elements(context: Dictionary, dominant: int) -> Array[int]:
	var extra: Array[int] = []
	for e: int in context["spell"]["elements"]:
		if e != dominant:
			extra.append(e)
	return extra


func _apply_mist_payload(context: Dictionary, state: CombatState, components: Array[int]) -> void:
	# 霧本體只遮蔽，水只潮濕；其他原子成分仍有自己的傷害／治療數值。
	if components.has(Elements.Type.WATER):
		state.apply([Elements.Type.WATER], 0.0)
	var payload: Array[int] = []
	for e in components:
		if e != Elements.Type.WATER:
			payload.append(e)
	if payload.is_empty():
		return
	var spell: Dictionary = context["spell"]
	var damage := float(spell["damage"]) / float((spell["elements"] as Array).size()) * payload.size() * 0.25
	state.apply(payload, damage)


## 構造、磁力與超導的附加成分只在實際作用到目標時結算，保留融合原子 ID。
func _apply_extra_payload(context: Dictionary, target: TrainingTarget, dominant: int) -> bool:
	var extra := _extra_elements(context, dominant)
	if extra.is_empty():
		return false
	var spell: Dictionary = context["spell"]
	var damage := float(spell["damage"]) / float((spell["elements"] as Array).size()) * extra.size() * 0.25
	var result := target.take_spell(extra, damage)
	if result.is_empty():
		return false
	_credit(context)
	return true


func _can_place(at: Vector3) -> bool:
	if _def.is_void(Vector2(at.x, at.z)) or absf(at.x) > _def.play_half.x - 0.6 or absf(at.z) > _def.play_half.y - 0.6:
		return false
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.1, 1.4, 1.1)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform.origin = at + Vector3.UP * 0.72
	query.margin = 0.0
	query.collision_mask = 1
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _credit(context: Dictionary) -> void:
	if not context["credited"]:
		context["credited"] = true
		knowledge.record_use(context["spell"]["id"])


func _line(start: Vector3, end: Vector3, color: Color, width: float, seconds: float) -> void:
	if start.distance_to(end) < 0.02:
		return
	if _flashes.size() >= MAX_FLASHES:
		_remove_effect(_flashes, 0)
	var mi := Build.box(self, Vector3(width, width, start.distance_to(end)), (start + end) * 0.5, Mats.altar_energy(color, 2.0))
	var up := Vector3.RIGHT if absf(start.direction_to(end).dot(Vector3.UP)) > 0.98 else Vector3.UP
	mi.look_at(end, up)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flashes.append({"node": mi, "remaining": seconds, "duration": seconds})


func _flash(at: Vector3, element: int) -> void:
	if _flashes.size() >= MAX_FLASHES:
		_remove_effect(_flashes, 0)
	var pal := _element_palette(element)
	var root := Node3D.new()
	root.name = "ImpactFlash"
	add_child(root)
	root.global_position = at
	var orb := Build.quad(root, Vector2(0.55, 0.55), Vector3.ZERO, Mats.spell_orb())
	orb.set_instance_shader_parameter("primary_color", pal[0])
	orb.set_instance_shader_parameter("accent_color", pal[1])
	orb.set_instance_shader_parameter("effect_time", _clock)
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var movers: Array[Dictionary] = []
	for i in 6:
		var a := float(i) * TAU / 6.0 + _clock
		var vel := Vector3(cos(a) * 2.4, 0.8 + float(i % 2) * 0.8, sin(a) * 2.4)
		var spark := Build.box(root, Vector3(0.055, 0.055, 0.055), Vector3.ZERO,
			Mats.altar_energy(pal[1] if i % 2 == 0 else pal[0], 2.5))
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		movers.append({"node": spark, "vel": vel})
	_flashes.append({"node": root, "remaining": 0.28, "duration": 0.28, "movers": movers})


func _ring(at: Vector3, element: int, radius: float) -> void:
	if _flashes.size() >= MAX_FLASHES:
		_remove_effect(_flashes, 0)
	var pal := _element_palette(element)
	var root := Node3D.new()
	root.name = "PulseRing"
	add_child(root)
	root.global_position = Vector3(at.x, 0.04, at.z)
	var disc := Build.quad(root, Vector2(radius * 2.1, radius * 2.1), Vector3.ZERO,
		Mats.spell_zone_pool(), Vector3(-90.0, 0.0, 0.0))
	disc.set_instance_shader_parameter("primary_color", pal[0])
	disc.set_instance_shader_parameter("accent_color", pal[1])
	disc.set_instance_shader_parameter("style_id", 3.0)
	disc.set_instance_shader_parameter("fade_alpha", 1.0)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var movers: Array[Dictionary] = []
	for i in 8:
		var a := float(i) * TAU / 8.0
		var mote := Build.box(root, Vector3(0.05, 0.12, 0.05),
			Vector3(cos(a) * radius * 0.68, 0.08, sin(a) * radius * 0.68),
			Mats.altar_energy(pal[1], 2.5))
		mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		movers.append({"node": mote, "vel": Vector3(cos(a) * 0.5, 1.5, sin(a) * 0.5)})
	_flashes.append({"node": root, "remaining": 0.52, "duration": 0.52, "pool": disc, "movers": movers})


func _tick_flashes(delta: float) -> void:
	for i in range(_flashes.size() - 1, -1, -1):
		var f: Dictionary = _flashes[i]
		f["remaining"] = float(f["remaining"]) - delta
		var rem: float = f["remaining"]
		var dur: float = maxf(float(f.get("duration", 0.25)), 0.01)
		if f.has("pool") and is_instance_valid(f["pool"]):
			var disc: MeshInstance3D = f["pool"]
			disc.set_instance_shader_parameter("effect_time", _clock)
			disc.set_instance_shader_parameter("fade_alpha", clampf(rem / dur, 0.0, 1.0))
		if f.has("movers"):
			for mover: Dictionary in f["movers"]:
				if is_instance_valid(mover["node"]):
					var mn: Node3D = mover["node"]
					mn.position += (mover["vel"] as Vector3) * delta
		if rem <= 0.0:
			_remove_effect(_flashes, i)


func _remove_effect(collection: Array[Dictionary], index: int) -> void:
	var node: Node = collection[index]["node"]
	collection.remove_at(index)
	if is_instance_valid(node):
		node.queue_free()


func target_summaries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for target in targets:
		result.append({"name": "金屬標的" if target.is_metal else "木樁", "health": target.combat_state.health,
			"statuses": target.combat_state.statuses.duplicate(), "concealed": target.combat_state.is_concealed})
	return result
