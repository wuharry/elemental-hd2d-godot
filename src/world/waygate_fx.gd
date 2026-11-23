extends Node3D
## 門幕在後，實體光屑繞著有深度的螺線進入門心；地面的紫光來自一盞局部點光。

const MOTE_COUNT := 12
const FLASH_SECONDS := 0.55

var _motes: Array[MeshInstance3D] = []
var _veil: MeshInstance3D
var _light: OmniLight3D
var _turn := 0.0
var _flash := 0.0


func _ready() -> void:
	add_to_group("waygate_fx")
	_veil = Build.box(self, Vector3(2, 2.48, 0.035), Vector3(0, 0, -0.28), Mats.waygate_veil())
	_veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ice := Mats.emissive(Color("#bde5ff"), 2.1)
	var violet := Mats.emissive(Color("#d496ff"), 1.65)
	for i in MOTE_COUNT:
		var shard_size := Vector3(0.05, 0.12, 0.06) if i % 3 != 0 else Vector3(0.085, 0.16, 0.08)
		var shard := Build.box(self, shard_size, Vector3.ZERO, ice if i % 2 == 0 else violet)
		shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_motes.append(shard)
	_light = OmniLight3D.new()
	_light.position = Vector3(0.18, -0.20, 0.80)
	_light.light_color = Color("#a88cff")
	_light.shadow_enabled = true
	_light.omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID
	_light.shadow_blur = 1.45
	_light.omni_attenuation = 1.4
	_light.light_volumetric_fog_energy = 0.20
	_light.add_to_group("magic_lights")
	add_child(_light)
	_update_field()


func pulse() -> void:
	_flash = 1.0
	_update_field()


func _process(delta: float) -> void:
	_flash = move_toward(_flash, 0.0, delta / FLASH_SECONDS)
	_turn = fposmod(_turn + delta * (0.31 + _flash * 0.52), 1.0)
	_update_field()


func _update_field() -> void:
	_veil.set_instance_shader_parameter("transit_pulse", _flash)
	_light.light_energy = 2.05 + 0.18 * sin(_turn * TAU * 2.0) + 3.4 * _flash
	_light.omni_range = 4.6 + 1.15 * _flash
	for i in _motes.size():
		var t := fposmod(_turn + float(i) / MOTE_COUNT, 1.0)
		var angle := t * TAU + 2.40 * i
		var radius := lerpf(1.16 + 0.16 * _flash, 0.18, t)
		var mote := _motes[i]
		mote.position = Vector3(cos(angle) * radius, sin(angle) * radius * 1.06, lerpf(0.66, -0.49, t))
		mote.rotation = Vector3(0.3, angle * 0.5, angle)
