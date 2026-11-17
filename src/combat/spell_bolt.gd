extends Node3D
## 暫時的法術表現：一顆帶動態光源的元素彈，沿瞄準方向飛一段就消失。
## PLACEHOLDER：各配方實際產生什麼法術（持續型／蓄力型、傷害、環境反應）規則都還沒定，
## 這支只用來確認「排元素 → 瞄準 → 放出去」這條操作路徑，以及法術光照在場景上的效果。

const SPEED := 13.0
const LIFE := 1.25
const FADE := 0.25

var _dir := Vector3.FORWARD
var _t := 0.0
var _light: OmniLight3D
var _energy := 4.0
var _orbs: Array[MeshInstance3D] = []


func launch(elements: Array[int], origin: Vector3, direction: Vector3) -> void:
	global_position = origin
	_dir = direction.normalized()
	var mixed := Color.BLACK
	for e in elements:
		mixed += Elements.color(e)
	mixed = mixed / float(elements.size())
	mixed.a = 1.0
	_energy = 3.0 + elements.size() * 1.2

	_light = OmniLight3D.new()
	_light.light_color = mixed
	_light.light_energy = _energy
	_light.omni_range = 6.5
	_light.omni_attenuation = 1.4
	_light.shadow_enabled = true
	_light.light_volumetric_fog_energy = 1.5
	add_child(_light)

	for i in elements.size():
		var orb := Build.box(self, Vector3(0.2, 0.2, 0.2), Vector3.ZERO, Mats.emissive(Elements.color(elements[i]), 5.0))
		orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_orbs.append(orb)

	var trail := GPUParticles3D.new()
	trail.amount = 40
	trail.lifetime = 0.5
	trail.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.spread = 180.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 1.2
	pm.gravity = Vector3(0, -1.5, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	trail.process_material = pm
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.09, 0.09, 0.09)
	mesh.material = Mats.emissive(mixed, 4.0)
	trail.draw_pass_1 = mesh
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(trail)


func _process(delta: float) -> void:
	_t += delta
	position += _dir * SPEED * delta
	for i in _orbs.size():
		var a := _t * 9.0 + TAU * i / _orbs.size()
		_orbs[i].position = Vector3(cos(a) * 0.22, sin(a * 1.3) * 0.12, sin(a) * 0.22)
		_orbs[i].rotation = Vector3(a, a * 0.7, 0)
	if _t > LIFE:
		var k := 1.0 - (_t - LIFE) / FADE
		_light.light_energy = _energy * maxf(k, 0.0)
		for orb in _orbs:
			orb.visible = false
		if k <= 0.0:
			queue_free()
