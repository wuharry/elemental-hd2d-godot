class_name TimeOfDay
extends Node
## 四個時段的光影（BLUEPRINT A7）：所有跟「現在幾點」有關的數值都在 PRESETS。
## 切換時段會在 transition_time 秒內平滑過渡。

signal changed(time_name: String)
signal weather_changed(weather_name: String)

const ORDER := ["morning", "day", "dusk", "night"]
const LABELS := {"morning": "晨", "day": "日", "dusk": "昏", "night": "夜"}
const WEATHERS := ["clear", "rain"]
const WEATHER_LABELS := {"clear": "晴", "rain": "雨"}
const REFLECTION_SUN_LAYER := 1 << 3
const MAIN_SUN_LAYER := 1 << 4
const REFLECTION_CAPTURE_DISTANCE := 40.0

## sun_yaw／sun_pitch：太陽（夜晚是月亮）的方向，單位度。yaw 135 = 從右後方照向鏡頭。
## win0／win1／win2：三種窗戶的發光強度。lamps：路燈與門燈的強度倍率。
const PRESETS := {
	"morning": {
		"sun_yaw": 128.0, "sun_pitch": -20.0, "sun_color": Color("#ffc890"), "sun_energy": 2.3,
		"ambient_color": Color("#93a6c9"), "ambient_energy": 0.55,
		"sky_top": Color("#6f93c4"), "sky_horizon": Color("#f2c9a4"),
		"fog_color": Color("#f0cfae"), "fog_density": 0.004, "vol_density": 0.014, "vol_albedo": Color("#ffe6c8"),
		"win0": 1.3, "win1": 0.0, "win2": 0.0, "lamps": 0.0, "night": 0.0,
		"rain_wetness": 0.0, "rain_intensity": 0.0,
		"exposure": 1.0, "glow": 0.8, "saturation": 1.12, "contrast": 1.06,
	},
	"day": {
		"sun_yaw": 152.0, "sun_pitch": -50.0, "sun_color": Color("#fff4e2"), "sun_energy": 2.5,
		"ambient_color": Color("#a9c2e6"), "ambient_energy": 0.85,
		"sky_top": Color("#4f8fd8"), "sky_horizon": Color("#cfe4f4"),
		"fog_color": Color("#d6e6f0"), "fog_density": 0.0015, "vol_density": 0.005, "vol_albedo": Color("#ffffff"),
		"win0": 0.0, "win1": 0.0, "win2": 0.0, "lamps": 0.0, "night": 0.0,
		"rain_wetness": 0.0, "rain_intensity": 0.0,
		"exposure": 1.0, "glow": 0.7, "saturation": 1.18, "contrast": 1.12,
	},
	"dusk": {
		"sun_yaw": -128.0, "sun_pitch": -19.0, "sun_color": Color("#ffb074"), "sun_energy": 1.9,
		"ambient_color": Color("#7c86c8"), "ambient_energy": 0.85,
		"sky_top": Color("#3d4a8a"), "sky_horizon": Color("#f0a878"),
		"fog_color": Color("#a99ab4"), "fog_density": 0.003, "vol_density": 0.007, "vol_albedo": Color("#ffe2d0"),
		"win0": 2.4, "win1": 1.6, "win2": 0.0, "lamps": 1.3, "night": 0.4,
		"rain_wetness": 0.0, "rain_intensity": 0.0,
		"exposure": 1.0, "glow": 0.85, "saturation": 1.12, "contrast": 1.08,
	},
	"night": {
		"sun_yaw": 160.0, "sun_pitch": -48.0, "sun_color": Color("#8fb2ff"), "sun_energy": 0.5,
		"ambient_color": Color("#2a3a66"), "ambient_energy": 0.8,
		"sky_top": Color("#0a1024"), "sky_horizon": Color("#1c2a4c"),
		"fog_color": Color("#1b2644"), "fog_density": 0.004, "vol_density": 0.016, "vol_albedo": Color("#b9c8ff"),
		"win0": 2.8, "win1": 2.3, "win2": 0.35, "lamps": 1.8, "night": 1.0,
		"rain_wetness": 0.0, "rain_intensity": 0.0,
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
	# 季節光影覆寫（套用於支援四季的村莊；夏維持基準值）。
	"season_overrides": {
		"spring": {
			"morning": {"sun_color": Color("#ffd6b6"), "fog_color": Color("#f5d9cc"), "sky_horizon": Color("#f8d6cc"), "saturation": 1.16},
			"day": {"sun_color": Color("#fff7ea"), "sky_top": Color("#5aa0e4"), "sky_horizon": Color("#dceefb"), "ambient_color": Color("#b2cce8"), "saturation": 1.2},
			"dusk": {"sun_color": Color("#ffb68c"), "fog_color": Color("#bfa4be")},
		},
		"autumn": {
			"morning": {"sun_color": Color("#ffbe78"), "fog_color": Color("#efd0a4"), "vol_density": 0.016, "saturation": 1.16},
			"day": {"sun_pitch": -40.0, "sun_color": Color("#ffe4be"), "sun_energy": 2.35, "ambient_color": Color("#9eb2d8"), "sky_top": Color("#467ec4"), "sky_horizon": Color("#e4d8c4"), "fog_color": Color("#e4d6c0"), "saturation": 1.22, "contrast": 1.14},
			"dusk": {"sun_color": Color("#ff9854"), "sun_energy": 2.05, "sky_horizon": Color("#f49a60"), "fog_color": Color("#b88e8c"), "saturation": 1.18},
			"night": {"ambient_color": Color("#28345e"), "fog_color": Color("#1b223e")},
		},
		"winter": {
			"*": {"saturation": 1.04},
			"morning": {"ambient_color": Color("#a8b8dc"), "fog_color": Color("#efdce0"), "vol_density": 0.012, "sun_energy": 1.95},
			"day": {"sun_pitch": -38.0, "sun_color": Color("#f4f7ff"), "sun_energy": 1.95, "ambient_color": Color("#bcd0f0"), "ambient_energy": 0.82, "sky_top": Color("#5a8cc4"), "sky_horizon": Color("#dce8f6"), "fog_color": Color("#e2ecf8"), "fog_density": 0.0035, "vol_density": 0.007},
			"dusk": {"ambient_color": Color("#888fd0"), "sun_energy": 1.65, "win0": 2.6, "win1": 1.8, "lamps": 1.45},
			"night": {"ambient_color": Color("#34487e"), "ambient_energy": 0.92, "sun_energy": 0.65, "win0": 2.9, "win1": 2.4, "lamps": 1.95},
		},
	},
	# 天氣光影覆寫（僅套於室外場景；暖燈開啟時維持 vol_density <= 0.02 避免過曝）。
	"weather_overrides": {
		"rain": {
			"*": {"rain_wetness": 1.0, "rain_intensity": 1.0},
			"morning": {
				"sun_color": Color("#c0d2ea"), "sun_energy": 0.78,
				"ambient_color": Color("#768eb8"), "ambient_energy": 0.68,
				"sky_top": Color("#465a7a"), "sky_horizon": Color("#8ea2bc"),
				"fog_color": Color("#8296b0"), "fog_density": 0.0055, "vol_density": 0.015, "vol_albedo": Color("#b8cae2"),
				"win0": 1.9, "win1": 1.0, "lamps": 0.85, "glow": 0.85, "saturation": 1.04, "contrast": 1.08,
			},
			"day": {
				"sun_color": Color("#d2e0f2"), "sun_energy": 0.88,
				"ambient_color": Color("#7a94be"), "ambient_energy": 0.78,
				"sky_top": Color("#4a6486"), "sky_horizon": Color("#9ab0c8"),
				"fog_color": Color("#92a8be"), "fog_density": 0.0045, "vol_density": 0.014, "vol_albedo": Color("#c2d4e8"),
				"win0": 1.7, "win1": 0.8, "lamps": 0.75, "glow": 0.8, "saturation": 1.06, "contrast": 1.1,
			},
			"dusk": {
				"sun_color": Color("#e4a688"), "sun_energy": 0.65,
				"ambient_color": Color("#5a6ca6"), "ambient_energy": 0.74,
				"sky_top": Color("#263464"), "sky_horizon": Color("#7c7498"),
				"fog_color": Color("#6a7294"), "fog_density": 0.0055, "vol_density": 0.014, "vol_albedo": Color("#c2cae4"),
				"win0": 2.6, "win1": 1.9, "win2": 0.25, "lamps": 1.5, "glow": 0.9, "saturation": 1.08, "contrast": 1.1,
			},
			"night": {
				"sun_color": Color("#7ca4f4"), "sun_energy": 0.3,
				"ambient_color": Color("#1e2e58"), "ambient_energy": 0.72,
				"sky_top": Color("#070d1e"), "sky_horizon": Color("#152240"),
				"fog_color": Color("#15203a"), "fog_density": 0.005, "vol_density": 0.016, "vol_albedo": Color("#9ab4ee"),
				"win0": 2.9, "win1": 2.4, "win2": 0.45, "lamps": 2.0, "glow": 0.92, "saturation": 1.08, "contrast": 1.08,
			},
		},
	},
}

@export var transition_time := 2.5

var current := "day"
var weather := "clear"
var rain_wetness := 0.0
var rain_intensity := 0.0
var _scene_id := "village"
var _season := "summer"
var _outdoor := true
var sun: DirectionalLight3D
var reflection_sun: DirectionalLight3D
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
	sun.layers = MAIN_SUN_LAYER
	add_child(sun)
	# 反射探針一次畫六面。近景倒影用單張方向光陰影，遊戲鏡頭仍用四級陰影。
	reflection_sun = sun.duplicate() as DirectionalLight3D
	reflection_sun.layers = REFLECTION_SUN_LAYER
	reflection_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	reflection_sun.directional_shadow_max_distance = REFLECTION_CAPTURE_DISTANCE
	add_child(reflection_sun)

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
	env.ssr_max_steps = 96
	env.ssr_fade_in = 0.08
	env.ssr_fade_out = 1.6
	env.ssr_depth_tolerance = 0.25
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


static func _apply_override_layer(presets: Dictionary, overrides: Dictionary, source_name: String) -> void:
	for time_name in ORDER:
		for scope in ["*", time_name]:
			var extra: Dictionary = overrides.get(scope, {})
			for key in extra:
				if presets[time_name].has(key):
					presets[time_name][key] = extra[key]
				else:
					push_error("%s 用了 PRESETS 沒有的欄位：%s" % [source_name, key])


## 某個場景四個時段實際生效的數值 = 基底 + scene_overrides + season_overrides + weather_overrides。
## 只接受四時段基底已有的欄位；風格測試也用這個函式檢查每個場景的數值範圍。
static func resolve(scene_id: String, season: String = "summer", weather_name: String = "clear", outdoor: bool = true) -> Dictionary:
	var presets := _base_presets()
	_apply_override_layer(presets, PRESETS["scene_overrides"].get(scene_id, {}), "scene_overrides")
	if outdoor and season != "summer":
		_apply_override_layer(presets, PRESETS["season_overrides"].get(season, {}), "season_overrides")
	if outdoor and weather_name != "clear":
		_apply_override_layer(presets, PRESETS["weather_overrides"].get(weather_name, {}), "weather_overrides")
	return presets


## 換場景或換季節時依 id 與季節查同一份 PRESETS。
func apply_scene(def: SceneDef) -> void:
	_scene_id = def.id
	_season = def.season if def.supports_seasons else "summer"
	_outdoor = def.outer_ground
	_presets = resolve(_scene_id, _season, weather, _outdoor)
	set_time(current, true)


func set_weather(weather_name: String, instant: bool = false) -> void:
	if not WEATHERS.has(weather_name):
		return
	weather = weather_name
	_presets = resolve(_scene_id, _season, weather, _outdoor)
	set_time(current, instant)
	weather_changed.emit(weather)


func toggle_weather(instant: bool = false) -> void:
	set_weather("rain" if weather == "clear" else "clear", instant)


func _exit_tree() -> void:
	rain_wetness = 0.0
	rain_intensity = 0.0
	RenderingServer.global_shader_parameter_set("rain_wetness", 0.0)
	RenderingServer.global_shader_parameter_set("rain_intensity", 0.0)


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
		_refresh_water_reflections()
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
	if _t >= 1.0:
		_refresh_water_reflections()


func _refresh_water_reflections() -> void:
	if is_inside_tree():
		get_tree().call_group("water_reflections", "refresh", _to)


func _apply(p: Dictionary) -> void:
	sun.rotation_degrees = Vector3(p["sun_pitch"], p["sun_yaw"], 0.0)
	sun.light_color = p["sun_color"]
	sun.light_energy = p["sun_energy"]
	reflection_sun.rotation = sun.rotation
	reflection_sun.light_color = sun.light_color
	reflection_sun.light_energy = sun.light_energy
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
	rain_wetness = float(p["rain_wetness"]) if _outdoor else 0.0
	rain_intensity = float(p["rain_intensity"]) if _outdoor else 0.0
	RenderingServer.global_shader_parameter_set("rain_wetness", rain_wetness)
	RenderingServer.global_shader_parameter_set("rain_intensity", rain_intensity)
	var raining := rain_intensity > 0.15
	if is_inside_tree():
		for l in get_tree().get_nodes_in_group("warm_lights"):
			(l as Light3D).light_energy = float(l.get_meta("base_energy")) * p["lamps"]
			# 能量為零的燈仍可能提交陰影；只在完全熄滅時隱藏，過場亮起即恢復。
			(l as Light3D).visible = (l as Light3D).light_energy > 0.0
		for n in get_tree().get_nodes_in_group("night_only"):
			(n as GPUParticles3D).emitting = p["night"] > 0.3 and not raining
		for n in get_tree().get_nodes_in_group("rain_only"):
			(n as GPUParticles3D).emitting = raining
		for n in get_tree().get_nodes_in_group("dry_only"):
			if n is GPUParticles3D:
				(n as GPUParticles3D).emitting = not raining
			elif n is Node3D:
				(n as Node3D).visible = not raining
