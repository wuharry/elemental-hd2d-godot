class_name Mats
extends RefCounted
## 材質唯一出口（BLUEPRINT A1、A2、A6）。場景裡不要自己 new 材質，一律從這裡拿。

const TEX_DIR := "res://assets/textures/"
## 64px 貼圖鋪 2 公尺 → 全場 32 px／公尺。
const TEXEL_SCALE := 0.5

static var _cache: Dictionary = {}
## 窗戶材質，分三種亮燈習慣；TimeOfDay 依時段調它們的發光強度。
static var window_mats: Array[StandardMaterial3D] = []
## 路燈燈罩這類「跟著人造光一起亮」的發光材質。
static var glow_mats: Array[StandardMaterial3D] = []


static func reset() -> void:
	_cache.clear()
	window_mats.clear()
	glow_mats.clear()


static func tex(name: String) -> Texture2D:
	return load(TEX_DIR + name + ".png") as Texture2D


## 有法線圖就用，沒有就給一張「完全平」的 1px 法線圖。
static func normal_or_flat(name: String) -> Texture2D:
	if ResourceLoader.exists(TEX_DIR + name + "_n.png"):
		return tex(name + "_n")
	if not _cache.has("flat_normal"):
		var img := Image.create(1, 1, false, Image.FORMAT_RGB8)
		img.set_pixel(0, 0, Color(0.5, 0.5, 1.0))
		_cache["flat_normal"] = ImageTexture.create_from_image(img)
	return _cache["flat_normal"]


## 金屬零件（齒輪、火盆）：同一套 triplanar 像素貼圖，只是帶金屬反光。
static func metal(tint: Color) -> StandardMaterial3D:
	var key := "metal:%s" % tint.to_html()
	if _cache.has(key):
		return _cache[key]
	var m: StandardMaterial3D = tri("stone_wall", tint, 0.42, 0.8).duplicate()
	m.metallic = 0.75
	_cache[key] = m
	return m


## 方塊用的 triplanar 材質：貼圖依 local 座標鋪，方塊多大像素都一樣大。
static func tri(name: String, tint: Color = Color.WHITE, roughness: float = 0.95, normal_scale: float = 1.0) -> StandardMaterial3D:
	var key := "tri:%s:%s:%.2f:%.2f" % [name, tint.to_html(), roughness, normal_scale]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex(name)
	m.albedo_color = tint
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * TEXEL_SCALE
	m.uv1_triplanar_sharpness = 60.0
	m.roughness = roughness
	m.set_meta("batch_kind", "triplanar")
	if ResourceLoader.exists(TEX_DIR + name + "_n.png"):
		m.normal_enabled = true
		m.normal_texture = tex(name + "_n")
		m.normal_scale = normal_scale
	_cache[key] = m
	return m


static func flat(color: Color, roughness: float = 0.9) -> StandardMaterial3D:
	var key := "flat:%s:%.2f" % [color.to_html(), roughness]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	_cache[key] = m
	return m


## 一般 UV 的貼圖面片（門、翅膀、落葉）。
static func quad(name: String, tint: Color = Color.WHITE, cutout: bool = false, two_sided: bool = false) -> StandardMaterial3D:
	var key := "quad:%s:%s:%s:%s" % [name, tint.to_html(), cutout, two_sided]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex(name)
	m.albedo_color = tint
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = 0.9
	if cutout:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
	if two_sided:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache[key] = m
	return m


## 窗戶：variant 0 傍晚就亮、1 入夜才亮、2 幾乎不亮。
static func window(variant: int) -> StandardMaterial3D:
	if window_mats.is_empty():
		for i in 3:
			var m := StandardMaterial3D.new()
			m.albedo_texture = tex("window")
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			m.roughness = 0.35
			m.emission_enabled = true
			m.emission_texture = tex("window_e")
			m.emission = Color("#ffa040")
			m.emission_energy_multiplier = 0.0
			window_mats.append(m)
	return window_mats[variant % 3]


## 人造光源的發光體（燈罩）。強度由 TimeOfDay 控制。
static func lamp_glow() -> StandardMaterial3D:
	if glow_mats.is_empty():
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("#f3d9a0")
		m.emission_enabled = true
		m.emission = Color("#ffb45e")
		m.emission_energy_multiplier = 0.0
		glow_mats.append(m)
	return glow_mats[0]


## 永遠發光的純色（火焰、螢火蟲、水晶）。
static func emissive(color: Color, energy: float) -> StandardMaterial3D:
	var key := "emi:%s:%.2f" % [color.to_html(), energy]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	_cache[key] = m
	return m


## 樹葉方塊：貼圖同 tri()，外加整塊隨風晃動。
static func foliage(tint: Color = Color.WHITE, sway: float = 0.05) -> ShaderMaterial:
	var key := "foliage:%s:%.3f" % [tint.to_html(), sway]
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/foliage_block.gdshader")
	m.set_shader_parameter("albedo_tex", tex("leaves"))
	m.set_shader_parameter("normal_tex", tex("leaves_n"))
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("texel_scale", TEXEL_SCALE)
	m.set_shader_parameter("sway", sway)
	m.set_meta("batch_kind", "foliage")
	_cache[key] = m
	return m


## 合併網格保留每個原始方塊的 local triplanar 座標；色調由頂點資料帶入。
## 只轉換 tri() 建立的簡單不透明材質，其他材質保留原物件供時段系統調整。
static func batched_tri(source: StandardMaterial3D) -> ShaderMaterial:
	var normal_id := source.normal_texture.get_instance_id() if source.normal_texture else 0
	var key := "batch_tri:%d:%d:%s:%s:%.4f:%.4f:%.4f:%.4f" % [
		source.albedo_texture.get_instance_id(), normal_id, source.uv1_scale, source.uv1_offset,
		source.uv1_triplanar_sharpness, source.roughness, source.normal_scale, source.metallic]
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/batched_triplanar.gdshader")
	m.set_shader_parameter("albedo_tex", source.albedo_texture)
	m.set_shader_parameter("normal_tex", source.normal_texture if source.normal_enabled else normal_or_flat("flat"))
	m.set_shader_parameter("texel_scale", source.uv1_scale)
	m.set_shader_parameter("texel_offset", source.uv1_offset)
	m.set_shader_parameter("blend_sharpness", source.uv1_triplanar_sharpness)
	m.set_shader_parameter("roughness", source.roughness)
	m.set_shader_parameter("normal_depth", source.normal_scale if source.normal_enabled else 0.0)
	m.set_shader_parameter("metallic", source.metallic)
	_cache[key] = m
	return m


## 方塊中心、搖擺幅度與色調已在頂點裡，因此不同樹可以共用同一材質。
static func batched_foliage() -> ShaderMaterial:
	const KEY := "batch_foliage"
	if _cache.has(KEY):
		return _cache[KEY]
	var m: ShaderMaterial = foliage().duplicate()
	m.set_shader_parameter("batched", true)
	_cache[KEY] = m
	return m
