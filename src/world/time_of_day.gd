class_name TimeOfDay
extends Node
## 四個時段的光影（BLUEPRINT A7）：所有跟「現在幾點」有關的數值都在 PRESETS。
## 切換時段會在 transition_time 秒內平滑過渡。

signal changed(time_name: String)

const ORDER := ["morning", "day", "dusk", "night"]
const LABELS := {"morning": "晨", "day": "日", "dusk": "昏", "night": "夜"}

## sun_yaw／sun_pitch：太陽（夜晚是月亮）的方向，單位度。yaw 135 = 從右後方照向鏡頭。
## win0／win1／win2：三種窗戶的發光強度。lamps：路燈與門燈的強度倍率。
const PRESETS := {
	"morning": {
		"sun_yaw": 128.0, "sun_pitch": -20.0, "sun_color": Color("#ffc890"), "sun_energy": 2.3,
		"ambient_color": Color("#93a6c9"), "ambient_energy": 0.55,
		"sky_top": Color("#6f93c4"), "sky_horizon": Color("#f2c9a4"),
		"fog_color": Color("#f0cfae"), "fog_density": 0.004, "vol_density": 0.014, "vol_albedo": Color("#ffe6c8"),
		"win0": 1.3, "win1": 0.0, "win2": 0.0, "lamps": 0.0, "night": 0.0,
		"exposure": 1.0, "glow": 0.8, "saturation": 1.12, "contrast": 1.06,
	},
	"day": {
		"sun_yaw": 152.0, "sun_pitch": -50.0, "sun_color": Color("#fff4e2"), "sun_energy": 2.5,
		"ambient_color": Color("#a9c2e6"), "ambient_energy": 0.85,
		"sky_top": Color("#4f8fd8"), "sky_horizon": Color("#cfe4f4"),
		"fog_color": Color("#d6e6f0"), "fog_density": 0.0015, "vol_density": 0.005, "vol_albedo": Color("#ffffff"),
		"win0": 0.0, "win1": 0.0, "win2": 0.0, "lamps": 0.0, "night": 0.0,
		"exposure": 1.0, "glow": 0.7, "saturation": 1.18, "contrast": 1.12,
	},
	"dusk": {
		"sun_yaw": -128.0, "sun_pitch": -19.0, "sun_color": Color("#ffb074"), "sun_energy": 1.9,
		"ambient_color": Color("#7c86c8"), "ambient_energy": 0.85,
		"sky_top": Color("#3d4a8a"), "sky_horizon": Color("#f0a878"),
		"fog_color": Color("#a99ab4"), "fog_density": 0.003, "vol_density": 0.007, "vol_albedo": Color("#ffe2d0"),
		"win0": 2.4, "win1": 1.6, "win2": 0.0, "lamps": 1.3, "night": 0.4,
		"exposure": 1.0, "glow": 0.85, "saturation": 1.12, "contrast": 1.08,
	},
	"night": {
		"sun_yaw": 160.0, "sun_pitch": -48.0, "sun_color": Color("#8fb2ff"), "sun_energy": 0.5,
		"ambient_color": Color("#2a3a66"), "ambient_energy": 0.8,
		"sky_top": Color("#0a1024"), "sky_horizon": Color("#1c2a4c"),
		"fog_color": Color("#1b2644"), "fog_density": 0.004, "vol_density": 0.016, "vol_albedo": Color("#b9c8ff"),
		"win0": 2.8, "win1": 2.3, "win2": 0.35, "lamps": 1.8, "night": 1.0,
		"exposure": 1.05, "glow": 0.8, "saturation": 1.1, "contrast": 1.06,
	},
	# 場景微調也集中在同一份 PRESETS；"*" 套所有時段，再套個別時段。
	"scene_overrides": {
		"forest": {
			"morning": {"vol_density": 0.022},
			"day": {"vol_density": 0.009, "ambient_energy": 0.75},
			"dusk": {"vol_density": 0.011},
		},
		"snow": {
			"*": {"saturation": 1.04},
			"morning": {"ambient_color": Color("#a9b8dc"), "fog_color": Color("#f2dcd0"), "vol_density": 0.012, "sun_energy": 1.9},
			"day": {"ambient_color": Color("#bcd0f0"), "ambient_energy": 0.8, "fog_color": Color("#e2ecf8"), "fog_density": 0.004, "sun_energy": 1.9, "vol_density": 0.007},
			"dusk": {"ambient_color": Color("#8a8fd0"), "sun_energy": 1.6},
			"night": {"ambient_color": Color("#34487e"), "ambient_energy": 0.95, "sun_energy": 0.7},
		},
		# 室內：四個時段只改天窗那道光，其餘固定。
		"dungeon": {
			"*": {
				"sun_yaw": 180.0, "sun_pitch": -62.0,
				"ambient_color": Color("#3a4272"), "ambient_energy": 0.85,
				"sky_top": Color("#04050a"), "sky_horizon": Color("#080a12"),
				"fog_color": Color("#141a2a"), "fog_density": 0.003,
				"vol_density": 0.01, "vol_albedo": Color("#c8d4ff"),
				"lamps": 1.2, "night": 0.0, "saturation": 1.12, "glow": 0.9,
			},
			"morning": {"sun_color": Color("#ffd2a0"), "sun_energy": 3.0},
			"day": {"sun_color": Color("#fff6e8"), "sun_energy": 3.6},
			"dusk": {"sun_color": Color("#ff9a5a"), "sun_energy": 2.6},
			"night": {"sun_color": Color("#9ab8ff"), "sun_energy": 1.4},
		},
	},
}

@export var transition_time := 2.5

var current := "day"
var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial

## 目前場景實際使用的數值 = 四時段基底 + PRESETS.scene_overrides。
var _presets: Dictionary = _base_presets()
var _from: Dictionary = {}
var _to: Dictionary = {}
var _now: Dictionary = {}
var _t := 1.0


func _ready() -> void:
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 90.0
	sun.directional_shadow_blend_splits = true
	sun.light_angular_distance = 1.2
	sun.shadow_blur = 1.2
	sun.light_volumetric_fog_energy = 1.0
	add_child(sun)

	env = Environment.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 2.4
	env.ssao_power = 1.6
	env.ssil_enabled = true
	env.ssil_radius = 4.0
	env.ssil_intensity = 1.0
	env.ssr_enabled = true
	env.glow_enabled = true
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.fog_enabled = true
	env.fog_sun_scatter = 0.25
	env.fog_aerial_perspective = 0.3
	env.volumetric_fog_enabled = true
	env.volumetric_fog_anisotropy = 0.7
	env.volumetric_fog_length = 90.0
	env.volumetric_fog_ambient_inject = 0.4
	env.volumetric_fog_temporal_reprojection_enabled = true
	env.adjustment_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	_now = PRESETS[current].duplicate()
	_apply(_now)


## 只複製四個時段，不把場景索引當成第五個時段。
static func _base_presets() -> Dictionary:
	var presets: Dictionary = {}
	for time_name in ORDER:
		presets[time_name] = PRESETS[time_name].duplicate(true)
	return presets


## 某個場景四個時段實際生效的數值 = 基底 + PRESETS.scene_overrides[scene_id]（先 "*" 再個別時段）。
## 只接受四時段基底已有的欄位；風格測試也用這個函式檢查每個場景的數值範圍。
static func resolve(scene_id: String) -> Dictionary:
	var presets := _base_presets()
	var overrides: Dictionary = PRESETS["scene_overrides"].get(scene_id, {})
	for time_name in ORDER:
		for scope in ["*", time_name]:
			var extra: Dictionary = overrides.get(scope, {})
			for key in extra:
				if presets[time_name].has(key):
					presets[time_name][key] = extra[key]
				else:
					push_error("scene_overrides 用了 PRESETS 沒有的欄位：%s" % key)
	return presets


## 換場景時依 id 查同一份 PRESETS。
func apply_scene(def: SceneDef) -> void:
	_presets = resolve(def.id)
	set_time(current, true)


func set_time(time_name: String, instant: bool = false) -> void:
	if not _presets.has(time_name):
		return
	current = time_name
	_from = _now.duplicate()
	_to = _presets[time_name]
	_t = 1.0 if instant else 0.0
	if instant:
		_now = _to.duplicate()
		_apply(_now)
	changed.emit(time_name)


func next_time() -> void:
	set_time(ORDER[(ORDER.find(current) + 1) % ORDER.size()])


func _process(delta: float) -> void:
	if _t >= 1.0:
		return
	_t = minf(_t + delta / transition_time, 1.0)
	var k := _t * _t * (3.0 - 2.0 * _t)
	for key in _to:
		var a: Variant = _from[key]
		var b: Variant = _to[key]
		if a is Color:
			_now[key] = (a as Color).lerp(b, k)
		elif key == "sun_yaw":
			_now[key] = rad_to_deg(lerp_angle(deg_to_rad(a), deg_to_rad(b), k))
		else:
			_now[key] = lerpf(a, b, k)
	_apply(_now)


func _apply(p: Dictionary) -> void:
	sun.rotation_degrees = Vector3(p["sun_pitch"], p["sun_yaw"], 0.0)
	sun.light_color = p["sun_color"]
	sun.light_energy = p["sun_energy"]
	env.ambient_light_color = p["ambient_color"]
	env.ambient_light_energy = p["ambient_energy"]
	sky_mat.sky_top_color = p["sky_top"]
	sky_mat.sky_horizon_color = p["sky_horizon"]
	sky_mat.ground_horizon_color = p["sky_horizon"]
	sky_mat.ground_bottom_color = (p["sky_top"] as Color).darkened(0.3)
	env.fog_light_color = p["fog_color"]
	env.fog_density = p["fog_density"]
	env.volumetric_fog_density = p["vol_density"]
	env.volumetric_fog_albedo = p["vol_albedo"]
	env.tonemap_exposure = p["exposure"]
	env.glow_intensity = p["glow"]
	env.adjustment_saturation = p["saturation"]
	env.adjustment_contrast = p["contrast"]

	var wins := [p["win0"], p["win1"], p["win2"]]
	for i in Mats.window_mats.size():
		Mats.window_mats[i].emission_energy_multiplier = wins[i]
	for m in Mats.glow_mats:
		m.emission_energy_multiplier = p["lamps"] * 5.0
	if is_inside_tree():
		for l in get_tree().get_nodes_in_group("warm_lights"):
			(l as Light3D).light_energy = float(l.get_meta("base_energy")) * p["lamps"]
			# 能量為零的燈仍可能提交陰影；只在完全熄滅時隱藏，過場亮起即恢復。
			(l as Light3D).visible = (l as Light3D).light_energy > 0.0
		for n in get_tree().get_nodes_in_group("night_only"):
			(n as GPUParticles3D).emitting = p["night"] > 0.3
