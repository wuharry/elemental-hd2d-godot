extends SceneTree
## 場景風格回歸（BLUEPRINT 第 2 節硬規則 + 第 8 節場景守則）。
## 1. 四場景真實組裝：啟動、切場、光影重設、必要素材與角色像素規格。
## 2. 逐場景硬規則：每個登錄在 Scenes.LIST 的場景都在「未合併網格」狀態下建出來逐條檢查。
##    新場景加進 LIST 就會自動被檢查，不用改這支測試。
## 3. 靜態掃描：場景檔只放資料與擺放、shader 取樣一律 nearest。
## 圖像風格、shader 畫面與效能仍須以 tools/capture.sh 開視窗驗收；這支只抓「規則被破壞」。

const PX_PER_M := 32.0
## 這些 sampler 是資料查表，不是像素貼圖：遮罩先對齊像素格再取樣，所以允許線性過濾。
const LINEAR_SAMPLER_EXEMPT := ["ground.gdshader:mask_tex"]
## 場景檔（src/world/scenes/*.gd）不准自己建這些東西：材質走 Mats、幾何走 Build／Builder、光影走 TimeOfDay。
const SCENE_FORBIDDEN := [
	"StandardMaterial3D.new", "ShaderMaterial.new", "BoxMesh.new", "PrismMesh.new", "QuadMesh.new",
	"PlaneMesh.new", "CylinderMesh.new", "SphereMesh.new", "CapsuleMesh.new", "ArrayMesh.new",
	"OmniLight3D.new", "SpotLight3D.new", "DirectionalLight3D.new", "WorldEnvironment", "Environment.new",
	"ParticleProcessMaterial.new", "GPUParticles3D.new", "light_energy", ".scale =", "load(\"res://assets",
]
const ALLOWED_GEOMETRY := ["MeshInstance3D", "MultiMeshInstance3D", "GPUParticles3D", "Sprite3D"]
const ALLOWED_MESHES := ["BoxMesh", "PrismMesh", "QuadMesh"]
## 開場畫面要看得到暖色光源（BLUEPRINT A8、第 8 節）：出生點這個半徑內至少一盞暖光。
const WARM_LIGHT_NEAR_SPAWN_M := 12.0
## 暖色點光源 + 體積霧會整片過曝（HANDOFF 踩坑）：亮燈時段的上限。
const MAX_VOL_DENSITY_WITH_LAMPS := 0.02
const MAX_LIGHT_FOG_ENERGY := 0.5
const MAX_WINDOW_EMISSION := 3.0
const MIN_AMBIENT_KINDS := 4

var _passed := 0
var _failed := 0


func _init() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		printerr("FAIL: ", label)


func _run() -> void:
	await _assembly_checks()
	_static_scene_file_checks()
	_static_shader_checks()
	_lighting_table_checks()
	for id in Scenes.LIST:
		await _scene_rule_checks(id)
	print("%d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed else 0)


# ---------- 1. 組裝與切場（原有回歸） ----------

func _assembly_checks() -> void:
	for name in ["snow", "ice", "flagstone", "brick"]:
		_check(ResourceLoader.exists("res://assets/textures/%s.png" % name), name + " texture exists")
		_check(ResourceLoader.exists("res://assets/textures/%s_n.png" % name), name + " normal exists")
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 3:
		await physics_frame
	var player: Player = main.get("player")
	_check(is_equal_approx(player.sprite.pixel_size, 1.0 / 32.0), "character uses 32px/m")
	_check(player.sprite.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST, "character nearest filter")
	_check(player.sprite.alpha_cut == SpriteBase3D.ALPHA_CUT_DISCARD, "character writes cutout depth")
	_check(player.sprite.shaded, "character receives scene lighting")
	var tod: TimeOfDay = main.get("time_of_day")
	tod.set_time("night", true)
	for id in ["forest", "snow", "dungeon", "village"]:
		player.queue.add(Elements.Type.FIRE)
		player.cast_queue(Vector3.RIGHT)
		main.call("switch_scene", id)
		var world: GameWorld = main.get("world")
		_check(world.def.id == id, id + " is active")
		_check(player.position.is_equal_approx(world.def.player_start), id + " starts at its spawn")
		_check(get_nodes_in_group("spell_previews").is_empty(), id + " clears previous spell previews")
		_check(tod.current == "night", id + " preserves selected time")
		var worlds := 0
		for child in main.get_children():
			if child is GameWorld:
				worlds += 1
		_check(worlds == 1, id + " frees the previous world")
		var stats: Dictionary = world.get_meta("mesh_batch_stats", {})
		_check(int(stats.get("sources", 0)) > int(stats.get("batches", 0)), id + " batches static geometry")
		for i in 2:
			await process_frame
	_check(tod.env.ambient_light_color.is_equal_approx(TimeOfDay.PRESETS["night"]["ambient_color"]), "village clears dungeon lighting override")
	_check(tod.sun.light_energy == TimeOfDay.PRESETS["night"]["sun_energy"], "village restores night sun")
	tod.set_time("day", true)
	var lights_off := true
	for light in get_nodes_in_group("warm_lights"):
		lights_off = lights_off and not light.visible and light.light_energy == 0.0
	_check(lights_off, "day disables zero-energy lamp shadow submissions")
	tod.set_time("dusk")
	tod._process(0.1)
	var lights_on := true
	for light in get_nodes_in_group("warm_lights"):
		lights_on = lights_on and light.visible and light.light_energy > 0.0
	_check(lights_on, "dusk transition immediately restores active lamps")
	main.free()


# ---------- 2. 靜態檢查 ----------

func _static_scene_file_checks() -> void:
	var dir := DirAccess.open("res://src/world/scenes")
	var files: Array[String] = []
	for f in dir.get_files():
		if f.ends_with("_scene.gd"):
			files.append(f)
	for f in files:
		var id := f.trim_suffix("_scene.gd")
		_check(Scenes.LIST.has(id), "%s 有登錄在 Scenes.LIST" % f)
		var text := FileAccess.get_file_as_string("res://src/world/scenes/" + f)
		for bad in SCENE_FORBIDDEN:
			_check(not text.contains(bad), "%s 不自己建 %s（材質走 Mats、幾何走 Build、光影走 TimeOfDay）" % [f, bad])
	for id in Scenes.LIST:
		_check(files.has(id + "_scene.gd"), "Scenes.LIST 的 %s 有對應場景檔" % id)
		_check(Scenes.make(id).id == id, "%s 場景檔的 id 與檔名一致" % id)


func _static_shader_checks() -> void:
	var dir := DirAccess.open("res://shaders")
	for f in dir.get_files():
		if not (f.ends_with(".gdshader") or f.ends_with(".gdshaderinc")):
			continue
		var text := FileAccess.get_file_as_string("res://shaders/" + f)
		for line in text.split("\n"):
			if not line.strip_edges().begins_with("uniform sampler2D"):
				continue
			var name := line.strip_edges().trim_prefix("uniform sampler2D").strip_edges().get_slice(":", 0).strip_edges()
			var nearest := line.contains("filter_nearest")
			_check(nearest or LINEAR_SAMPLER_EXEMPT.has(f + ":" + name), "A2 %s:%s 用 nearest 取樣" % [f, name])


## 光影表：場景微調只能用基底已有的欄位，數值不能踩到已知會壞畫面的範圍。
func _lighting_table_checks() -> void:
	var overrides: Dictionary = TimeOfDay.PRESETS["scene_overrides"]
	var base: Dictionary = TimeOfDay.PRESETS["day"]
	for scene_id in overrides:
		_check(Scenes.LIST.has(scene_id), "A7 scene_overrides 的 %s 是已登錄場景" % scene_id)
		for scope in overrides[scene_id]:
			_check(scope == "*" or TimeOfDay.ORDER.has(scope), "A7 %s 的覆寫範圍 %s 是 * 或四時段之一" % [scene_id, scope])
			for key in overrides[scene_id][scope]:
				_check(base.has(key), "A7 %s.%s.%s 是 PRESETS 已有欄位" % [scene_id, scope, key])
	for scene_id in Scenes.LIST:
		var resolved := TimeOfDay.resolve(scene_id)
		for time_name in TimeOfDay.ORDER:
			var p: Dictionary = resolved[time_name]
			var label := "%s/%s" % [scene_id, time_name]
			if float(p["lamps"]) > 0.0:
				_check(float(p["vol_density"]) <= MAX_VOL_DENSITY_WITH_LAMPS,
					"霧 %s 亮燈時 vol_density %.3f ≤ %.2f（暖燈＋濃霧會整片過曝）" % [label, p["vol_density"], MAX_VOL_DENSITY_WITH_LAMPS])
			for w in ["win0", "win1", "win2"]:
				_check(float(p[w]) <= MAX_WINDOW_EMISSION, "窗光 %s %s %.1f ≤ %.1f（太亮會糊掉窗格）" % [label, w, p[w], MAX_WINDOW_EMISSION])


# ---------- 3. 逐場景硬規則 ----------

func _walk(n: Node, out: Array[Node]) -> void:
	out.append(n)
	for c in n.get_children():
		_walk(c, out)


func _scene_rule_checks(id: String) -> void:
	var world := GameWorld.new(Scenes.make(id))
	root.add_child(world)
	await process_frame
	var nodes: Array[Node] = []
	_walk(world, nodes)
	var def := world.def
	var errors := {}   # 規則 → 第一個違規的例子（每條規則只報一次，避免洗版）
	var ambient := {}
	var warm_near_spawn := 0
	var spawn := Vector2(def.player_start.x, def.player_start.z)

	for n in nodes:
		if n is Node3D and not (n as Node3D).basis.get_scale().is_equal_approx(Vector3.ONE):
			_note(errors, "A6 節點縮放必須是 1（尺寸寫進 mesh.size）", n)
		if n is DirectionalLight3D or n is WorldEnvironment:
			_note(errors, "A7 場景裡不放太陽或環境（只在 TimeOfDay）", n)
		if n is GeometryInstance3D and not ALLOWED_GEOMETRY.has(n.get_class()):
			_note(errors, "A3 只用方塊類幾何節點", n)
		if n.has_meta("ambient_kind"):
			ambient[n.get_meta("ambient_kind")] = true
		if n is MeshInstance3D:
			_mesh_rules(n as MeshInstance3D, errors)
		elif n is MultiMeshInstance3D:
			var mm := (n as MultiMeshInstance3D).multimesh.mesh
			if not (mm is ArrayMesh and mm.get_faces().size() == 12):
				_note(errors, "A3 MultiMesh 只能是交叉面片（兩片四邊形）", n)
			_material_rules((n as MultiMeshInstance3D).material_override, errors, n)
		elif n is GPUParticles3D:
			var dp := (n as GPUParticles3D).draw_pass_1
			if not (dp is BoxMesh or dp is QuadMesh):
				_note(errors, "A3 粒子只用方塊或面片", n)
			elif dp.surface_get_material(0):
				_material_rules(dp.surface_get_material(0), errors, n)
		elif n is Sprite3D:
			if not is_equal_approx((n as Sprite3D).pixel_size, 1.0 / PX_PER_M):
				_note(errors, "A1 像素圖 pixel_size = 1/32", n)
		if n is Light3D:
			var l := n as Light3D
			var warm := _is_warm(l.light_color)
			if not l.is_in_group("magic_lights") and not warm:
				_note(errors, "A8 人造光一律暖色（冷色魔法光要登記 magic_lights）", n)
			if warm and l.light_volumetric_fog_energy > MAX_LIGHT_FOG_ENERGY + 0.001:
				_note(errors, "霧 暖燈 light_volumetric_fog_energy ≤ %.1f" % MAX_LIGHT_FOG_ENERGY, n)
			var lp := (n as Node3D).global_position
			if warm and Vector2(lp.x, lp.z).distance_to(spawn) <= WARM_LIGHT_NEAR_SPAWN_M:
				warm_near_spawn += 1

	for rule in errors:
		_check(false, "%s %s：例 %s" % [id, rule, errors[rule]])
	_check(errors.is_empty(), "%s 通過逐節點硬規則（%d 個節點）" % [id, nodes.size()])
	_check(ambient.size() >= MIN_AMBIENT_KINDS, "A10 %s 會動的東西至少 %d 種，實際 %d：%s" % [id, MIN_AMBIENT_KINDS, ambient.size(), ambient.keys()])
	_check(warm_near_spawn > 0, "A8 %s 出生點 %.0f 公尺內有暖色光源（開場畫面要有暖冷對比）" % [id, WARM_LIGHT_NEAR_SPAWN_M])
	for h in def.houses:
		if h.get("shed", false):
			continue
		var per_floor: float = float(h["wall_h"]) / maxf(float(h["floors"]), 1.0)
		_check(float(h["base_h"]) >= 1.6 and float(h["base_h"]) <= 1.9 and per_floor >= 1.5 and per_floor <= 1.75,
			"A11 %s 房屋 seed %d 是 Q 版比例（底層 1.6–1.9、每層 1.5–1.75 公尺）" % [id, h["seed"]])
	world.free()


func _mesh_rules(mi: MeshInstance3D, errors: Dictionary) -> void:
	var mesh := mi.mesh
	if mesh == null:
		return
	if not ALLOWED_MESHES.has(mesh.get_class()):
		_note(errors, "A3 只用 BoxMesh／PrismMesh／QuadMesh（合併前）", mi)
	var mat := mi.material_override
	_material_rules(mat, errors, mi)
	# 有貼圖的面片：貼圖像素 ÷ 面片公尺數 = 32（窗、門、翅膀）
	if mesh is QuadMesh and mat is StandardMaterial3D:
		var sm := mat as StandardMaterial3D
		if sm.albedo_texture and not sm.uv1_triplanar and sm.billboard_mode == BaseMaterial3D.BILLBOARD_DISABLED:
			var size := (mesh as QuadMesh).size
			var tex := sm.albedo_texture
			var density := Vector2(tex.get_width() / size.x, tex.get_height() / size.y)
			if absf(density.x - PX_PER_M) > 1.0 or absf(density.y - PX_PER_M) > 1.0:
				_note(errors, "A1 面片貼圖密度 32 px／公尺", mi, " (%.1f×%.1f)" % [density.x, density.y])


func _material_rules(mat: Material, errors: Dictionary, n: Node) -> void:
	if mat is StandardMaterial3D:
		var sm := mat as StandardMaterial3D
		var textured := sm.albedo_texture != null or sm.normal_texture != null or sm.emission_texture != null
		if textured and not [BaseMaterial3D.TEXTURE_FILTER_NEAREST, BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS].has(sm.texture_filter):
			_note(errors, "A2 貼圖一律 nearest", n)
		if sm.uv1_triplanar:
			if not sm.uv1_scale.is_equal_approx(Vector3.ONE * Mats.TEXEL_SCALE):
				_note(errors, "A1 triplanar 鋪貼比例 = Mats.TEXEL_SCALE", n)
			if sm.albedo_texture and (sm.albedo_texture.get_width() != 64 or sm.albedo_texture.get_height() != 64):
				_note(errors, "A1 鋪貼貼圖是 64×64（64px 鋪 2 公尺）", n)
	elif mat is ShaderMaterial:
		var scale: Variant = (mat as ShaderMaterial).get_shader_parameter("texel_scale")
		if scale != null and not is_equal_approx(float(scale), Mats.TEXEL_SCALE):
			_note(errors, "A1 shader 鋪貼比例 = Mats.TEXEL_SCALE", n)


func _is_warm(c: Color) -> bool:
	return c.s >= 0.3 and (c.h <= 0.14 or c.h >= 0.95)


## 違規例子印成「類別 @ 世界座標」：場景是程式組的，節點沒有好認的名字，座標最好找。
func _note(errors: Dictionary, rule: String, n: Node, extra: String = "") -> void:
	if errors.has(rule):
		return
	var where := ""
	if n is Node3D and (n as Node3D).is_inside_tree():
		var g := (n as Node3D).global_position
		where = " @ (%.1f, %.1f, %.1f)" % [g.x, g.y, g.z]
	errors[rule] = n.get_class() + where + extra
