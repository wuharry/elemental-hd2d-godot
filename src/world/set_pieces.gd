class_name SetPieces
extends RefCounted
## 各場景共用的大型零件：河、瀑布、橋、石柱、火盆、齒輪、水晶、蘑菇、帳篷、遺跡。
## 規則同 PropBuilder：只用方塊與三角柱、材質只從 Mats 拿、尺寸寫進 mesh.size（BLUEPRINT A3、A6）。

const IRON := Color("#26262c")


static func water_mat(flow: Vector2 = Vector2.ZERO, deep: Color = Color("#123038"), shallow: Color = Color("#2a5c60")) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/water.gdshader")
	m.set_shader_parameter("normal_tex", Mats.tex("water_n"))
	m.set_shader_parameter("flow", flow)
	m.set_shader_parameter("deep", deep)
	m.set_shader_parameter("shallow", shallow)
	return m


## 填滿空洞的水：在空洞範圍底下鋪一大片水面與河床。rect 要蓋住整條河（空洞以外的部分會被地面擋住）。
static func water_fill(rect: Rect2, level: float, flow: Vector2, deep: Color = Color("#123038"), shallow: Color = Color("#2a5c60")) -> Node3D:
	var root := Node3D.new()
	var c := rect.get_center()
	var water := Build.box(root, Vector3(rect.size.x, 0.1, rect.size.y), Vector3(c.x, level - 0.05, c.y), water_mat(flow, deep, shallow))
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Build.box(root, Vector3(rect.size.x, 0.4, rect.size.y), Vector3(c.x, level - 1.0, c.y), Mats.tri("dirt", Color("#6a6258")))
	return root


## 瀑布：原點在底部中央，面朝 +Z。meta "splash" 是水花位置（local）。
static func waterfall(width: float, height: float) -> Node3D:
	var root := Node3D.new()
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/waterfall.gdshader")
	var fall := Build.box(root, Vector3(width, height, 0.3), Vector3(0, height * 0.5, 0), m)
	fall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 瀑布頂與兩側的岩石，後面墊一整塊崖壁
	var rock := Mats.tri("stone_wall", Color("#9a968c"), 0.95, 1.5)
	Build.box(root, Vector3(width + 4.0, height, 3.0), Vector3(0, height * 0.5, -1.7), rock)
	Build.box(root, Vector3(width + 4.2, 0.3, 3.2), Vector3(0, height + 0.1, -1.7), Mats.tri("grass_ground"))
	Build.box(root, Vector3(1.2, height + 0.6, 1.4), Vector3(-width * 0.5 - 0.5, (height + 0.6) * 0.5, -0.4), rock)
	Build.box(root, Vector3(1.4, height + 0.2, 1.4), Vector3(width * 0.5 + 0.6, (height + 0.2) * 0.5, -0.4), rock)
	Build.box(root, Vector3(0.8, 0.5, 0.8), Vector3(-width * 0.2, height + 0.1, -0.3), rock)
	root.set_meta("splash", Vector3(0, 0.1, 0.3))
	return root


## 木板橋：沿 local X 方向。橋面略高於地面，兩側有欄杆。
static func plank_bridge(length: float, width: float) -> Node3D:
	var root := Node3D.new()
	var wood := Mats.tri("planks", Color("#9a7650"))
	var dark := Mats.tri("planks", Color("#6b4a2e"))
	var n := int(length / 0.42)
	for i in n:
		var x := -length * 0.5 + (i + 0.5) * (length / n)
		Build.box(root, Vector3(length / n - 0.04, 0.12, width), Vector3(x, 0.03, 0), wood if i % 3 != 0 else dark)
	for side in [-1.0, 1.0]:
		Build.box(root, Vector3(length, 0.2, 0.2), Vector3(0, -0.12, side * (width * 0.5 - 0.1)), dark)
		Build.box(root, Vector3(length, 0.1, 0.08), Vector3(0, 0.85, side * (width * 0.5 - 0.05)), dark)
		var posts := int(length / 1.6) + 1
		for i in posts:
			var x := -length * 0.5 + i * (length / maxf(posts - 1, 1))
			Build.box(root, Vector3(0.14, 1.0, 0.14), Vector3(x, 0.45, side * (width * 0.5 - 0.05)), dark)
		Build.collider(root, Vector3(length, 1.6, 0.3), Vector3(0, 0.8, side * (width * 0.5 + 0.1)))
	return root


## 吊橋：木板之間有縫，兩側是下垂的繩子，兩端各有一對掛燈的柱子。沿 local X 方向。
static func rope_bridge(length: float, width: float) -> Node3D:
	var root := Node3D.new()
	var wood := Mats.tri("planks", Color("#8f6c48"))
	var dark := Mats.tri("planks", Color("#5e4129"))
	var rope := Mats.flat(Color("#b89a6a"))
	var n := int(length / 0.5)
	for i in n:
		var x := -length * 0.5 + (i + 0.5) * (length / n)
		Build.box(root, Vector3(length / n - 0.1, 0.1, width - 0.2), Vector3(x, 0.02, 0), wood if i % 4 != 1 else dark)
	for side in [-1.0, 1.0]:
		var z: float = side * (width * 0.5 - 0.05)
		Build.box(root, Vector3(length, 0.08, 0.08), Vector3(0, -0.06, side * (width * 0.5 - 0.2)), rope)
		# 扶手繩：分成小段排成下垂的弧線
		var segs := int(length / 0.6)
		for i in segs:
			var t := (i + 0.5) / segs
			var sag := 0.55 * (1.0 - pow(2.0 * t - 1.0, 2.0))
			var x := -length * 0.5 + t * length
			Build.box(root, Vector3(length / segs + 0.02, 0.07, 0.07), Vector3(x, 1.15 - sag, z), rope)
			if i % 2 == 0:
				Build.box(root, Vector3(0.04, 1.1 - sag, 0.04), Vector3(x, (1.1 - sag) * 0.5, z), rope)
		for end in [-1.0, 1.0]:
			var px: float = end * (length * 0.5 + 0.2)
			Build.box(root, Vector3(0.26, 1.7, 0.26), Vector3(px, 0.85, z), dark)
			Build.box(root, Vector3(0.36, 0.1, 0.36), Vector3(px, 1.72, z), dark)
		Build.collider(root, Vector3(length, 1.6, 0.3), Vector3(0, 0.8, side * (width * 0.5 + 0.1)))
	# 兩端各一盞掛燈
	for end in [-1.0, 1.0]:
		var lx: float = end * (length * 0.5 + 0.2)
		Build.box(root, Vector3(0.2, 0.26, 0.2), Vector3(lx, 1.95, width * 0.5 - 0.05), Mats.lamp_glow())
		Build.box(root, Vector3(0.28, 0.05, 0.28), Vector3(lx, 2.1, width * 0.5 - 0.05), Mats.flat(IRON))
		Build.warm_light(root, Vector3(lx, 1.9, width * 0.5 + 0.2), 2.6, 8.0)
	return root


## 石板橋：一整塊石板加矮護欄。沿 local X 方向。
static func stone_bridge(length: float, width: float) -> Node3D:
	var root := Node3D.new()
	var stone := Mats.tri("flagstone", Color("#b0acb8"), 0.9, 1.3)
	var trim := Mats.tri("stone_wall", Color("#8a8690"), 0.95, 1.4)
	Build.box(root, Vector3(length, 0.3, width), Vector3(0, -0.07, 0), stone)
	for side in [-1.0, 1.0]:
		Build.box(root, Vector3(length, 0.3, 0.24), Vector3(0, 0.2, side * (width * 0.5 - 0.12)), trim)
		Build.collider(root, Vector3(length, 1.6, 0.3), Vector3(0, 0.8, side * (width * 0.5 + 0.1)))
	return root


static func pillar(height: float) -> Node3D:
	var root := Node3D.new()
	var stone := Mats.tri("stone_wall", Color("#9d99a6"), 0.95, 1.4)
	var brick := Mats.tri("brick", Color("#b4a8ac"), 0.95, 1.3)
	Build.box(root, Vector3(1.5, 0.4, 1.5), Vector3(0, 0.2, 0), stone)
	Build.box(root, Vector3(1.2, 0.3, 1.2), Vector3(0, 0.55, 0), stone)
	Build.box(root, Vector3(0.9, height - 1.4, 0.9), Vector3(0, 0.7 + (height - 1.4) * 0.5, 0), brick)
	Build.box(root, Vector3(1.2, 0.3, 1.2), Vector3(0, height - 0.55, 0), stone)
	Build.box(root, Vector3(1.5, 0.4, 1.5), Vector3(0, height - 0.2, 0), stone)
	Build.collider(root, Vector3(1.4, 4.0, 1.4), Vector3(0, 2.0, 0))
	return root


## 斷掉的石柱。
static func broken_pillar(pillar_seed: int) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = pillar_seed * 7907
	var root := Node3D.new()
	var stone := Mats.tri("stone_wall", Color("#9d99a6"), 0.95, 1.4)
	var brick := Mats.tri("brick", Color("#b4a8ac"), 0.95, 1.3)
	var h := rng.randf_range(0.8, 1.8)
	Build.box(root, Vector3(1.4, 0.4, 1.4), Vector3(0, 0.2, 0), stone)
	Build.box(root, Vector3(0.9, h, 0.9), Vector3(0, 0.4 + h * 0.5, 0), brick)
	Build.box(root, Vector3(0.9, 0.8, 0.9), Vector3(rng.randf_range(1.0, 1.6), 0.4, rng.randf_range(-0.6, 0.6)), brick, Vector3(0, rng.randf() * 60.0, 78))
	Build.box(root, Vector3(0.4, 0.3, 0.4), Vector3(-0.9, 0.15, 0.7), stone, Vector3(0, 30, 0))
	Build.collider(root, Vector3(1.3, 3.0, 1.3), Vector3(0, 1.5, 0))
	return root


## 火盆：石座 + 鐵盆 + 會閃的火光。meta "fire" 讓 GameWorld 加上火焰粒子。
static func brazier() -> Node3D:
	var root := Node3D.new()
	var stone := Mats.tri("stone_wall", Color("#9d99a6"))
	Build.box(root, Vector3(0.7, 0.3, 0.7), Vector3(0, 0.15, 0), stone)
	Build.box(root, Vector3(0.36, 0.7, 0.36), Vector3(0, 0.65, 0), stone)
	var iron := Mats.metal(Color("#4a4650"))
	Build.box(root, Vector3(0.9, 0.24, 0.9), Vector3(0, 1.12, 0), iron)
	Build.box(root, Vector3(1.06, 0.08, 1.06), Vector3(0, 1.26, 0), iron)
	Build.box(root, Vector3(0.7, 0.1, 0.7), Vector3(0, 1.27, 0), Mats.emissive(Color("#ff7a1e"), 3.5))
	var light := OmniLight3D.new()
	light.position = Vector3(0, 1.8, 0)
	light.light_color = Color("#ff9440")
	light.omni_range = 11.0
	light.omni_attenuation = 1.3
	light.shadow_enabled = true
	light.shadow_blur = 2.5
	# 雙拋物面陰影只畫 2 面（立方體要畫 6 面）；方塊幾何看不出差別，地下城 draw call 少很多
	light.omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID
	light.light_volumetric_fog_energy = 0.5
	light.set_script(load("res://src/world/flicker_light.gd"))
	light.set("base_energy", 4.2)
	root.add_child(light)
	root.set_meta("fire", Vector3(0, 1.35, 0))
	Build.collider(root, Vector3(0.9, 2.0, 0.9), Vector3(0, 1.0, 0))
	return root


## 壁掛火把：原點貼牆，朝 +Z 伸出。
static func wall_torch() -> Node3D:
	var root := Node3D.new()
	var iron := Mats.flat(IRON, 0.5)
	Build.box(root, Vector3(0.1, 0.1, 0.5), Vector3(0, 0, 0.25), iron)
	Build.box(root, Vector3(0.14, 0.5, 0.14), Vector3(0, 0.15, 0.5), Mats.tri("planks", Color("#6b4a2e")))
	Build.box(root, Vector3(0.2, 0.22, 0.2), Vector3(0, 0.5, 0.5), Mats.emissive(Color("#ffb040"), 4.0))
	var light := OmniLight3D.new()
	light.position = Vector3(0, 0.6, 0.9)
	light.light_color = Color("#ffa050")
	light.omni_range = 8.0
	light.omni_attenuation = 1.4
	light.light_volumetric_fog_energy = 0.5
	light.set_script(load("res://src/world/flicker_light.gd"))
	light.set("base_energy", 2.6)
	light.set("flicker", 0.18)
	root.add_child(light)
	root.set_meta("fire", Vector3(0, 0.6, 0.5))
	return root


## 齒輪：平躺在 local XZ 平面，繞 local Y 軸轉。要掛牆上就把整個節點繞 X 轉 90 度。
static func gear(radius: float, thick: float, tint: Color, speed: float) -> Node3D:
	var root := Node3D.new()
	root.set_script(load("res://src/world/spin.gd"))
	root.set("speed", speed)
	var metal := Mats.metal(tint)
	var dark := Mats.metal(tint.darkened(0.35))
	# 兩片正方形錯開 45 度疊成八角盤
	var side := radius * 1.5
	Build.box(root, Vector3(side, thick, side), Vector3.ZERO, metal)
	Build.box(root, Vector3(side, thick, side), Vector3.ZERO, metal, Vector3(0, 45, 0))
	Build.box(root, Vector3(radius * 0.5, thick + 0.16, radius * 0.5), Vector3.ZERO, dark)
	Build.box(root, Vector3(radius * 1.7, thick + 0.06, radius * 0.16), Vector3.ZERO, dark)
	Build.box(root, Vector3(radius * 0.16, thick + 0.06, radius * 1.7), Vector3.ZERO, dark)
	var teeth := maxi(8, int(radius * 5.0))
	for i in teeth:
		var a := TAU * i / teeth
		Build.box(root, Vector3(radius * 0.3, thick, radius * 0.24), Vector3(cos(a) * radius, 0, sin(a) * radius), metal, Vector3(0, -rad_to_deg(a), 0))
	return root


## 發光水晶叢。這是自然／魔法光，可以是冷色（BLUEPRINT A8 只規定人造火光要暖色）。
static func crystals(crystal_seed: int, color: Color, s: float = 1.0) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = crystal_seed * 6007
	var root := Node3D.new()
	var mat := Mats.emissive(color, 2.2)
	for i in 3 + rng.randi() % 3:
		var h := rng.randf_range(0.5, 1.4) * s
		var w := rng.randf_range(0.14, 0.3) * s
		Build.box(root, Vector3(w, h, w), Vector3(rng.randf_range(-0.4, 0.4) * s, h * 0.42, rng.randf_range(-0.4, 0.4) * s), mat, Vector3(rng.randf_range(-22, 22), rng.randf() * 90.0, rng.randf_range(-22, 22)))
	Build.box(root, Vector3(0.9 * s, 0.24, 0.8 * s), Vector3(0, 0.1, 0), Mats.tri("stone_wall", Color("#8a8690")), Vector3(0, rng.randf() * 90.0, 0))
	var light := OmniLight3D.new()
	light.position = Vector3(0, 0.9 * s, 0)
	light.light_color = color
	# 自然／魔法光可以是冷色，但必須登記在 magic_lights，風格測試才會放行（BLUEPRINT A8）
	light.add_to_group("magic_lights")
	light.light_energy = 1.6
	light.omni_range = 5.5 * s
	light.omni_attenuation = 1.5
	light.light_volumetric_fog_energy = 0.4
	root.add_child(light)
	return root


## 蘑菇叢。glow = true 時菇傘會發微光。
static func mushrooms(mush_seed: int, glow: bool) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = mush_seed * 5003
	var root := Node3D.new()
	var stem := Mats.flat(Color("#efe6d0"))
	var cap: Material = Mats.emissive(Color("#62e6d2"), 1.4) if glow else Mats.flat(Color("#c8403a"))
	var dot := Mats.flat(Color("#fff6e6"))
	for i in 3 + rng.randi() % 3:
		var h := snappedf(rng.randf_range(0.16, 0.42), 0.03125)
		var w := snappedf(rng.randf_range(0.2, 0.44), 0.03125)
		var p := Vector3(rng.randf_range(-0.45, 0.45), 0, rng.randf_range(-0.45, 0.45))
		Build.box(root, Vector3(0.09, h, 0.09), p + Vector3(0, h * 0.5, 0), stem)
		Build.box(root, Vector3(w, 0.12, w), p + Vector3(0, h + 0.05, 0), cap)
		Build.box(root, Vector3(w * 0.6, 0.07, w * 0.6), p + Vector3(0, h + 0.14, 0), cap)
		if not glow:
			Build.box(root, Vector3(0.06, 0.03, 0.06), p + Vector3(w * 0.2, h + 0.12, w * 0.15), dot)
	return root


static func tent(tint: Color) -> Node3D:
	var root := Node3D.new()
	var cloth := Mats.flat(tint, 0.95)
	Build.prism(root, Vector3(2.6, 1.7, 3.0), Vector3(0, 0.85, 0), cloth)
	Build.prism(root, Vector3(1.0, 1.1, 0.06), Vector3(0, 0.55, 1.52), Mats.flat(Color("#2a2420")))
	var pole := Mats.tri("planks", Color("#6b4a2e"))
	Build.box(root, Vector3(0.1, 1.9, 0.1), Vector3(0, 0.95, 1.5), pole)
	Build.box(root, Vector3(0.1, 1.9, 0.1), Vector3(0, 0.95, -1.5), pole)
	Build.box(root, Vector3(2.9, 0.06, 0.2), Vector3(0, 0.03, 1.4), cloth)
	Build.collider(root, Vector3(2.4, 2.0, 2.8), Vector3(0, 1.0, 0))
	return root


## 殘破的石拱門 + 一盞小神龕燈。
static func ruin_arch() -> Node3D:
	var root := Node3D.new()
	var stone := Mats.tri("stone_wall", Color("#b0ab9c"), 0.95, 1.5)
	var moss := Mats.foliage(Color("#d8e8b0"), 0.0)
	Build.box(root, Vector3(0.9, 3.0, 0.9), Vector3(-1.6, 1.5, 0), stone)
	Build.box(root, Vector3(0.9, 2.2, 0.9), Vector3(1.6, 1.1, 0), stone)
	Build.box(root, Vector3(2.8, 0.7, 0.9), Vector3(-0.7, 3.3, 0), stone)
	Build.box(root, Vector3(1.0, 0.6, 0.8), Vector3(2.3, 0.3, 0.9), stone, Vector3(0, 24, 12))
	Build.box(root, Vector3(0.6, 0.4, 0.6), Vector3(1.2, 0.2, 1.3), stone, Vector3(0, 50, 0))
	Build.box(root, Vector3(1.0, 0.16, 1.0), Vector3(-1.6, 3.04, 0), moss)
	Build.box(root, Vector3(1.4, 0.14, 1.0), Vector3(-0.2, 3.7, 0), moss)
	Build.box(root, Vector3(1.0, 0.14, 1.0), Vector3(1.6, 2.24, 0), moss)
	# 神龕
	Build.box(root, Vector3(0.7, 0.8, 0.6), Vector3(0, 0.4, -0.2), stone)
	Build.box(root, Vector3(0.9, 0.12, 0.8), Vector3(0, 0.86, -0.2), stone)
	Build.box(root, Vector3(0.22, 0.28, 0.22), Vector3(0, 1.06, -0.2), Mats.lamp_glow())
	Build.warm_light(root, Vector3(0, 1.3, 0.3), 2.4, 7.0)
	Build.collider(root, Vector3(0.9, 3.0, 0.9), Vector3(-1.6, 1.5, 0))
	Build.collider(root, Vector3(0.9, 3.0, 0.9), Vector3(1.6, 1.5, 0))
	return root


## 一對石門借同一個紫色門環識別。門框有碰撞，中央與嵌在地上的踏石可穿行。
static func waygate() -> Node3D:
	var root := Node3D.new()
	root.name = "Waygate"
	var basalt := Mats.tri("brick", Color("#6d637b"))
	var rim := Mats.tri("flagstone", Color("#afa6b2"))
	var bronze := Mats.metal(Color("#b18750"))
	var rune := Mats.emissive(Color("#a783fa"), 1.45)
	for side: int in [-1, 1]:
		var x := side * 1.27
		Build.box(root, Vector3(0.76, 0.25, 0.88), Vector3(x, 0.125, 0), basalt)
		Build.box(root, Vector3(0.48, 1.83, 0.58), Vector3(x, 1.16, 0), basalt)
		Build.box(root, Vector3(0.54, 0.1, 0.66), Vector3(x, 0.59, 0), bronze)
		Build.box(root, Vector3(0.1, 0.79, 0.04), Vector3(x, 1.25, 0.30), rune)
		Build.box(root, Vector3(0.68, 0.22, 0.76), Vector3(x, 2.10, 0), rim)
		Build.box(root, Vector3(0.53, 0.86, 0.63), Vector3(side * 1.02, 2.43, 0), basalt, Vector3(0, 0, side * 40))
		Build.collider(root, Vector3(0.66, 2.2, 0.76), Vector3(x, 1.1, 0))
	Build.box(root, Vector3(1.70, 0.35, 0.66), Vector3(0, 2.73, 0), rim)
	Build.box(root, Vector3(0.32, 0.32, 0.72), Vector3(0, 2.72, 0), bronze, Vector3(0, 0, 45))

	# 稜角門環保留中空輪廓。每段連接橢圓上的相鄰兩個頂點。
	for i in 12:
		var a := Vector2.from_angle(TAU * i / 12.0) * Vector2(0.98, 1.22)
		var b := Vector2.from_angle(TAU * (i + 1) / 12.0) * Vector2(0.98, 1.22)
		var mid := (a + b) * 0.5
		Build.box(root, Vector3(a.distance_to(b) * 0.92, 0.07, 0.10), Vector3(mid.x, 1.35 + mid.y, 0.20),
			rune, Vector3(0, 0, rad_to_deg((b - a).angle())))
	for i in 3:
		Build.box(root, Vector3(0.90 - i * 0.14, 0.048, 0.16), Vector3(0, 0.024, 0.35 + i * 0.34), rim)
	var fx := preload("res://src/world/waygate_fx.gd").new()
	fx.name = "PortalFX"
	fx.position = Vector3(0, 1.35, 0)
	root.add_child(fx)
	return root


## 六座祭壇共用的連續石座。
static func element_altar_base(width: float) -> Node3D:
	var root := Node3D.new()
	root.name = "ElementAltarBase"
	var stone := Mats.tri("flagstone", Color("#918b9b"))
	Build.box(root, Vector3(width, 0.12, 1.65), Vector3(0, 0.06, 0), stone)
	Build.box(root, Vector3(width - 0.12, 0.10, 1.38), Vector3(0, 0.17, 0), stone)
	Build.collider(root, Vector3(width, 0.20, 1.63), Vector3(0, 0.10, 0))
	return root


static func element_altar(element: int) -> Node3D:
	var root := Node3D.new()
	root.name = "ElementAltar_%d" % element
	var color := Elements.color(element)
	var stone := Mats.tri("flagstone", Color("#918b9b"))
	var trim := Mats.metal(Color("#be995e"))
	Build.box(root, Vector3(1.39, 0.10, 1.22), Vector3(0, 0.27, 0), stone)
	Build.box(root, Vector3(1.21, 0.58, 1.06), Vector3(0, 0.61, 0), Mats.tri("brick", Color("#716882")))
	Build.box(root, Vector3(1.37, 0.05, 1.17), Vector3(0, 0.92, 0), trim)
	Build.box(root, Vector3(1.49, 0.10, 1.26), Vector3(0, 0.98, 0), stone)
	Build.collider(root, Vector3(1.37, 1.03, 1.22), Vector3(0, 0.515, 0))
	Build.box(root, Vector3(0.66, 0.59, 0.06), Vector3(0, 0.61, 0.55), trim)
	Build.box(root, Vector3(0.59, 0.53, 0.02), Vector3(0, 0.61, 0.585), Mats.flat(Color("#292338")))
	# 碑面沿用 HUD 元素圖示，近看也能以輪廓辨識。
	var glyph := Sprite3D.new()
	glyph.texture = preload("res://assets/ui/element_icons.png")
	glyph.hframes = Elements.ICON_ORDER.size()
	glyph.frame = Elements.ICON_ORDER.find(element)
	glyph.pixel_size = 1.0 / 32.0
	glyph.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	glyph.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	glyph.position = Vector3(0, 0.61, 0.60)
	root.add_child(glyph)
	Build.box(root, Vector3(0.54, 0.09, 0.54), Vector3(0, 1.08, 0), trim, Vector3(0, 45, 0))
	var gem := Mats.emissive(color, 0.82)
	Build.prism(root, Vector3(0.49, 0.42, 0.39), Vector3(0, 1.53, 0), gem, Vector3(0, 28, 0))
	Build.prism(root, Vector3(0.49, 0.39, 0.39), Vector3(0, 1.125, 0), gem, Vector3(0, 28, 180))
	return root


static func fallen_log(length: float) -> Node3D:
	var root := Node3D.new()
	var bark := Mats.tri("bark")
	Build.box(root, Vector3(length, 0.6, 0.6), Vector3(0, 0.3, 0), bark)
	Build.box(root, Vector3(0.06, 0.44, 0.44), Vector3(length * 0.5, 0.3, 0), Mats.flat(Color("#c9a26b")))
	Build.box(root, Vector3(length * 0.5, 0.1, 0.5), Vector3(-length * 0.15, 0.62, 0), Mats.foliage(Color("#d8e8b0"), 0.0))
	Build.box(root, Vector3(0.2, 0.2, 0.7), Vector3(length * 0.2, 0.45, 0.3), bark, Vector3(20, 0, 0))
	Build.collider(root, Vector3(length, 1.2, 0.6), Vector3(0, 0.6, 0))
	return root


## 疊石堆（路標）。
static func cairn(cairn_seed: int) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = cairn_seed * 4001
	var root := Node3D.new()
	var stone := Mats.tri("stone_wall", Color("#b4bac8"), 0.95, 1.4)
	var y := 0.0
	var w := 0.7
	for i in 4:
		var h := rng.randf_range(0.2, 0.32)
		Build.box(root, Vector3(w, h, w * rng.randf_range(0.8, 1.0)), Vector3(rng.randf_range(-0.05, 0.05), y + h * 0.5, 0), stone, Vector3(0, rng.randf() * 90.0, 0))
		y += h
		w *= 0.74
	Build.box(root, Vector3(0.5, 0.08, 0.5), Vector3(0, y + 0.03, 0), Mats.tri("snow"))
	return root


## 冰錐叢：半透亮的冰柱，會反光。
static func ice_spikes(spike_seed: int, s: float = 1.0) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = spike_seed * 3001
	var root := Node3D.new()
	var ice: StandardMaterial3D = Mats.tri("ice", Color.WHITE, 0.12, 0.6)
	for i in 4 + rng.randi() % 3:
		var h := rng.randf_range(0.6, 2.2) * s
		var w := rng.randf_range(0.2, 0.5) * s
		Build.box(root, Vector3(w, h, w), Vector3(rng.randf_range(-0.7, 0.7) * s, h * 0.42, rng.randf_range(-0.6, 0.6) * s), ice, Vector3(rng.randf_range(-16, 16), rng.randf() * 90.0, rng.randf_range(-16, 16)))
	return root


## 雪堆：幾塊低矮、互相錯位的雪方塊疊成一座雪丘（置中疊高會像白色階梯金字塔）。
static func snow_mound(mound_seed: int, s: float = 1.0) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = mound_seed * 2003
	var root := Node3D.new()
	var snow := Mats.tri("snow")
	var w := rng.randf_range(1.4, 2.4) * s
	var d := rng.randf_range(1.0, 1.8) * s
	Build.box(root, Vector3(w, 0.18, d), Vector3(0, 0.07, 0), snow)
	for i in 3 + rng.randi() % 3:
		var bw := snappedf(rng.randf_range(0.35, 0.7) * w, 0.125)
		var bd := snappedf(rng.randf_range(0.35, 0.7) * d, 0.125)
		var bh := snappedf(rng.randf_range(0.12, 0.3) * s, 0.0625)
		var off := Vector3(rng.randf_range(-0.3, 0.3) * w, 0.14 + bh * 0.5 + (0.12 if i > 2 else 0.0), rng.randf_range(-0.3, 0.3) * d)
		Build.box(root, Vector3(bw, bh, bd), off, snow, Vector3(0, rng.randf_range(-20, 20), 0))
	return root


## 掛在牆上的旗幟：原點貼牆，面朝 +Z。
static func banner(color: Color, height: float = 3.0) -> Node3D:
	var root := Node3D.new()
	Build.box(root, Vector3(1.5, 0.12, 0.12), Vector3(0, 0, 0.12), Mats.tri("planks", Color("#6b4a2e")))
	Build.box(root, Vector3(1.2, height, 0.05), Vector3(0, -height * 0.5, 0.1), Mats.flat(color, 0.95))
	Build.box(root, Vector3(1.2, 0.16, 0.06), Vector3(0, -height + 0.3, 0.11), Mats.flat(Color("#e8bd4c"), 0.6))
	Build.box(root, Vector3(0.4, 0.4, 0.06), Vector3(0, -height * 0.45, 0.11), Mats.flat(Color("#e8bd4c"), 0.6), Vector3(0, 0, 45))
	return root


## 階梯狀石台（祭壇）。
static func dais(size: float) -> Node3D:
	var root := Node3D.new()
	var stone := Mats.tri("flagstone", Color("#c0bcc8"), 0.9, 1.3)
	var trim := Mats.tri("stone_wall", Color("#9d99a6"), 0.95, 1.4)
	Build.box(root, Vector3(size, 0.25, size), Vector3(0, 0.125, 0), trim)
	Build.box(root, Vector3(size - 1.0, 0.25, size - 1.0), Vector3(0, 0.375, 0), stone)
	Build.box(root, Vector3(1.2, 0.9, 1.2), Vector3(0, 0.95, 0), trim)
	Build.box(root, Vector3(1.5, 0.16, 1.5), Vector3(0, 1.46, 0), stone)
	Build.collider(root, Vector3(size - 0.6, 2.0, size - 0.6), Vector3(0, 1.0, 0))
	return root



## 正門：石框 + 鐵柵 + 門後一片黑。原點貼牆、面朝 +Z。
static func portcullis_gate(width: float, height: float) -> Node3D:
	var root := Node3D.new()
	var stone := Mats.tri("stone_wall", Color("#9d99a6"), 0.95, 1.4)
	var iron := Mats.metal(Color("#4a4650"))
	Build.box(root, Vector3(width + 0.4, height + 0.2, 0.3), Vector3(0, (height + 0.2) * 0.5, 0.0), Mats.flat(Color("#050507"), 1.0))
	Build.box(root, Vector3(0.8, height + 0.6, 0.9), Vector3(-width * 0.5 - 0.4, (height + 0.6) * 0.5, 0.3), stone)
	Build.box(root, Vector3(0.8, height + 0.6, 0.9), Vector3(width * 0.5 + 0.4, (height + 0.6) * 0.5, 0.3), stone)
	Build.box(root, Vector3(width + 1.6, 0.9, 0.9), Vector3(0, height + 0.45, 0.3), stone)
	Build.box(root, Vector3(1.0, 0.7, 1.0), Vector3(0, height + 0.5, 0.38), Mats.tri("brick", Color("#c0b0b4"), 0.95, 1.3))
	var bars := int(width / 0.45)
	for i in bars:
		var x := -width * 0.5 + (i + 0.5) * (width / bars)
		Build.box(root, Vector3(0.1, height, 0.1), Vector3(x, height * 0.5, 0.35), iron)
	for y in [height * 0.3, height * 0.7]:
		Build.box(root, Vector3(width, 0.12, 0.12), Vector3(0, y, 0.38), iron)
	for x in [-width * 0.5 - 0.4, width * 0.5 + 0.4]:
		Build.box(root, Vector3(0.9, 0.3, 1.1), Vector3(x, 0.15, 0.4), stone)
	Build.collider(root, Vector3(width + 1.6, 4.0, 1.0), Vector3(0, 2.0, 0.3))
	return root


## 一叢蠟燭：放在地上或石台上。暖光，跟路燈一樣由 TimeOfDay 的 lamps 控制亮度。
static func candles(candle_seed: int) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = candle_seed * 9001
	var root := Node3D.new()
	var wax := Mats.flat(Color("#efe4c8"))
	var flame := Mats.emissive(Color("#ffc060"), 4.0)
	for i in 3 + rng.randi() % 3:
		var h := snappedf(rng.randf_range(0.12, 0.38), 0.03125)
		var p := Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.25, 0.25))
		Build.box(root, Vector3(0.09, h, 0.09), p + Vector3(0, h * 0.5, 0), wax)
		Build.box(root, Vector3(0.05, 0.07, 0.05), p + Vector3(0, h + 0.04, 0), flame)
	Build.box(root, Vector3(0.8, 0.04, 0.6), Vector3(0, 0.02, 0), Mats.flat(Color("#d8ccb0")))
	Build.warm_light(root, Vector3(0, 0.6, 0.2), 1.6, 4.5)
	return root


## 從天花板垂下的鐵鏈：原點在頂端，往下 length 公尺，最下面掛一個鉤子。
static func chain(length: float) -> Node3D:
	var root := Node3D.new()
	var iron := Mats.metal(Color("#3e3b44"))
	var links := int(length / 0.22)
	for i in links:
		var y := -0.11 - i * 0.22
		if i % 2 == 0:
			Build.box(root, Vector3(0.12, 0.2, 0.04), Vector3(0, y, 0), iron)
		else:
			Build.box(root, Vector3(0.04, 0.2, 0.12), Vector3(0, y, 0), iron)
	var bottom := -links * 0.22
	Build.box(root, Vector3(0.06, 0.24, 0.06), Vector3(0.0, bottom - 0.1, 0), iron)
	Build.box(root, Vector3(0.2, 0.06, 0.06), Vector3(0.07, bottom - 0.22, 0), iron)
	return root


## 石棺：棺身 + 錯開一點的棺蓋 + 蓋上的浮雕條。
static func sarcophagus(lid_offset: float) -> Node3D:
	var root := Node3D.new()
	var stone := Mats.tri("stone_wall", Color("#a8a4b0"), 0.95, 1.4)
	var lid := Mats.tri("flagstone", Color("#bcb8c4"), 0.9, 1.3)
	Build.box(root, Vector3(1.1, 0.7, 2.2), Vector3(0, 0.35, 0), stone)
	Build.box(root, Vector3(1.24, 0.14, 2.36), Vector3(0.0, 0.07, 0), stone)
	Build.box(root, Vector3(1.2, 0.2, 2.3), Vector3(lid_offset, 0.8, lid_offset * 0.6), lid, Vector3(0, lid_offset * 14.0, 0))
	Build.box(root, Vector3(0.3, 0.08, 1.4), Vector3(lid_offset, 0.94, lid_offset * 0.6), Mats.flat(Color("#e8bd4c"), 0.6), Vector3(0, lid_offset * 14.0, 0))
	Build.collider(root, Vector3(1.2, 1.4, 2.3), Vector3(0, 0.7, 0))
	return root


## 地上的水窪：薄薄一層反光水面。
static func puddle(size: Vector2) -> Node3D:
	var root := Node3D.new()
	var water := Build.box(root, Vector3(size.x, 0.02, size.y), Vector3(0, 0.012, 0), water_mat(Vector2.ZERO, Color("#151a26"), Color("#2c3646")))
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var half := size * 0.5
	Build.box(root, Vector3(size.x * 0.5, 0.02, size.y * 0.4), Vector3(half.x * 0.6, 0.012, -half.y * 0.5), water.material_override)
	return root


## 牆上的苔蘚：貼在牆面（面朝 +Z）的幾塊葉子方塊，不隨風晃。
static func wall_moss(moss_seed: int, width: float) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = moss_seed * 7001
	var root := Node3D.new()
	var mats := [Mats.foliage(Color("#b8d090"), 0.0), Mats.foliage(Color("#90b078"), 0.0)]
	var x := -width * 0.5
	while x < width * 0.5:
		var w := snappedf(rng.randf_range(0.375, 0.875), 0.125)
		var h := snappedf(rng.randf_range(0.25, 1.5), 0.125)
		Build.box(root, Vector3(w, h, 0.125), Vector3(x + w * 0.5, h * 0.5, 0.06), mats[rng.randi() % 2])
		x += w
	return root
