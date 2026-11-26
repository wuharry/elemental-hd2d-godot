class_name WaterReflection
extends Node
## 即時平面鏡像水反（Planar Reflection）：以半解析度鏡像鏡頭即時渲染水面以上的天空、
## 建築、暖窗、路燈、樹木、傳送門、祭壇與主角，再由 water.gdshader 以像素波紋扭曲合成。

const GROUP := "water_reflections"
const RESOLUTION_SCALE := 0.5
const MIN_SIZE := Vector2i(320, 180)
const MAX_SIZE := Vector2i(960, 540)
const CULL_MASK := 1 | 2 | TimeOfDay.REFLECTION_SUN_LAYER

var surface_level := 0.0
var primary_area := 0.0
var viewport: SubViewport
var camera: Camera3D
var _bound_mats: Dictionary = {}
var _active := false


## 計算跨水平面 y = plane_y 的右手系鏡像變換（不翻轉背面剔除，UV 對應 (u, 1 - v)）。
static func mirror_transform(src: Transform3D, plane_y: float) -> Transform3D:
	var rx := Vector3(src.basis.x.x, -src.basis.x.y, src.basis.x.z).normalized()
	var rz := Vector3(src.basis.z.x, -src.basis.z.y, src.basis.z.z).normalized()
	var ry := rz.cross(rx).normalized()
	var origin := Vector3(src.origin.x, 2.0 * plane_y - src.origin.y, src.origin.z)
	return Transform3D(Basis(rx, ry, rz), origin)


func _ready() -> void:
	# 排在 CameraRig._process 之後，確保同一幀就跟上主鏡頭最新位置。
	process_priority = 100
	add_to_group(GROUP)
	viewport = SubViewport.new()
	viewport.name = "PlanarReflectionViewport"
	viewport.transparent_bg = false
	viewport.own_world_3d = false
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.use_taa = false
	# 反射畫面仍保留點光源照明與方向光陰影，但不重複繪製每盞路燈／火盆的雙拋物面陰影圖，省下數百次 draw call。
	viewport.positional_shadow_atlas_size = 0
	viewport.size = Vector2i(640, 360)
	_active = DisplayServer.get_name() != "headless"
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if _active else SubViewport.UPDATE_DISABLED
	add_child(viewport)

	camera = Camera3D.new()
	camera.name = "PlanarReflectionCamera"
	camera.cull_mask = CULL_MASK
	camera.current = true
	var parent_world := get_parent() as GameWorld
	if parent_world != null and not parent_world.def.outer_ground:
		# 室內地城沒有天花板網格；鏡像鏡頭改用深色穹頂背景，避免水渠倒映出室外天空。
		var indoor_env := Environment.new()
		indoor_env.background_mode = Environment.BG_COLOR
		indoor_env.background_color = Color("#060812")
		indoor_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		indoor_env.ambient_light_color = Color("#3a4272")
		indoor_env.ambient_light_energy = 0.72
		indoor_env.tonemap_mode = Environment.TONE_MAPPER_ACES
		indoor_env.tonemap_white = 6.0
		camera.environment = indoor_env
	viewport.add_child(camera)

	_apply_clip_plane()
	_bind_water_materials.call_deferred()


func register_surface(level: float, area: float) -> void:
	if area >= primary_area or primary_area <= 0.0:
		primary_area = area
		surface_level = level
		_apply_clip_plane()


func _apply_clip_plane() -> void:
	if is_inside_tree():
		RenderingServer.global_shader_parameter_set("water_reflection_y", surface_level)


func _process(_delta: float) -> void:
	var main_vp := get_viewport()
	if main_vp == null:
		return
	var main_cam := main_vp.get_camera_3d()
	if main_cam != null and main_cam != camera:
		sync_to_camera(main_cam, main_vp.get_visible_rect().size)
	_bind_water_materials()


func sync_to_camera(main_cam: Camera3D, main_size: Vector2 = Vector2(1280, 720)) -> void:
	if camera == null or viewport == null or main_cam == null:
		return
	var target_w := clampi(int(round(main_size.x * RESOLUTION_SCALE)), MIN_SIZE.x, MAX_SIZE.x)
	var target_h := clampi(int(round(main_size.y * RESOLUTION_SCALE)), MIN_SIZE.y, MAX_SIZE.y)
	var target_size := Vector2i(target_w, target_h)
	if viewport.size != target_size:
		viewport.size = target_size
	camera.projection = main_cam.projection
	camera.fov = main_cam.fov
	camera.size = main_cam.size
	camera.near = main_cam.near
	camera.far = minf(main_cam.far, 72.0)
	camera.global_transform = mirror_transform(main_cam.global_transform, surface_level)
	_apply_clip_plane()


func _bind_water_materials() -> void:
	if not is_inside_tree() or viewport == null:
		return
	var tex := viewport.get_texture()
	var enable := 1.0 if _active and tex != null else 0.0
	for node in get_tree().get_nodes_in_group("water_surfaces"):
		var mesh := node as MeshInstance3D
		if mesh == null:
			continue
		var mat := mesh.material_override as ShaderMaterial
		if mat == null:
			continue
		var id := mat.get_instance_id()
		if _bound_mats.get(id, 0.0) != enable or mat.get_shader_parameter("reflection_tex") != tex:
			mat.set_shader_parameter("reflection_tex", tex)
			mat.set_shader_parameter("has_reflection", enable)
			_bound_mats[id] = enable


## 與 TimeOfDay 介面相容：平面鏡像每幀即時更新，切時段時只需確保材質與裁切面同步。
func refresh(_lighting: Dictionary = {}) -> void:
	_apply_clip_plane()
	_bind_water_materials()


func _exit_tree() -> void:
	if viewport != null:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_bound_mats.clear()
	RenderingServer.global_shader_parameter_set("water_reflection_y", -1000.0)
