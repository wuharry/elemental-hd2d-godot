extends Node3D
## 武器獨立於角色圖集，位置由掌心決定。手掌圖層永遠蓋在武器前方。

const Visual := preload("res://src/player/weapon_visual.gd")
const CHAR_SHADER := preload("res://shaders/pixel_character.gdshader")

static var _flat_normal: ImageTexture
static var _default_material: ImageTexture

var sprite := Sprite3D.new()
var emitter := OmniLight3D.new()
var visual: Visual
var _shader_mat: ShaderMaterial


static func _get_flat_normal() -> ImageTexture:
	if _flat_normal == null:
		var img := Image.create(1, 1, false, Image.FORMAT_RGB8)
		img.set_pixel(0, 0, Color(0.5, 0.5, 1.0))
		_flat_normal = ImageTexture.create_from_image(img)
	return _flat_normal


static func _get_default_material() -> ImageTexture:
	if _default_material == null:
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.set_pixel(0, 0, Color(0.84, 0.0, 0.5, 0.0))
		_default_material = ImageTexture.create_from_image(img)
	return _default_material


func _init() -> void:
	name = "HeldWeapon"
	sprite.name = "WeaponSprite"
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.shaded = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.double_sided = true
	sprite.layers = 2
	_shader_mat = ShaderMaterial.new()
	_shader_mat.shader = CHAR_SHADER
	_shader_mat.set_shader_parameter("normal_tex", _get_flat_normal())
	_shader_mat.set_shader_parameter("material_tex", _get_default_material())
	_shader_mat.set_shader_parameter("rim_strength", 0.95)
	_shader_mat.set_shader_parameter("emission_strength", 1.2)
	sprite.material_override = _shader_mat
	add_child(sprite)
	emitter.name = "WeaponLight"
	emitter.light_cull_mask = 0xFFFFF & ~2
	emitter.omni_attenuation = 1.6
	add_child(emitter)
	equip(null)


func equip(value: Visual) -> void:
	visual = value
	sprite.texture = visual.texture if visual != null else null
	sprite.visible = sprite.texture != null
	emitter.visible = sprite.visible and visual.light_energy > 0.0
	emitter.light_energy = visual.light_energy if visual != null else 0.0
	if visual != null:
		emitter.light_color = visual.light_color
		emitter.omni_range = visual.light_range
		_shader_mat.set_shader_parameter("albedo_tex", visual.texture)
		_shader_mat.set_shader_parameter("normal_tex", visual.normal_texture if visual.normal_texture != null else _get_flat_normal())
		_shader_mat.set_shader_parameter("material_tex", visual.material_texture if visual.material_texture != null else _get_default_material())
	else:
		_shader_mat.set_shader_parameter("albedo_tex", null)


## grip 是腳底原點上的像素座標，x 向右、y 向上；尚未套鏡像與俯角。
func pose(grip: Vector2, mirrored: bool, pixel_size: float, stretch: float,
		yaw: float, camera_depth: Vector3, time: float) -> void:
	position = camera_depth
	if visual == null or sprite.texture == null:
		return
	var sign_x := -1.0 if mirrored else 1.0
	var half_size := sprite.texture.get_size() * 0.5
	sprite.flip_h = mirrored
	_shader_mat.set_shader_parameter("flip_sign", sign_x)
	sprite.pixel_size = pixel_size
	sprite.scale = Vector3(1.0, stretch, 1.0)
	sprite.offset = Vector2(
		(grip.x + half_size.x - visual.grip_pixel.x) * sign_x,
		grip.y + visual.grip_pixel.y - half_size.y)
	var tip_px := grip + Vector2(visual.light_pixel.x - visual.grip_pixel.x,
		visual.grip_pixel.y - visual.light_pixel.y)
	# 光屬於武器，但不帶為了圖層排序加入的微小深度偏移。
	emitter.position = Vector3(tip_px.x * sign_x, tip_px.y * stretch, 0.0).rotated(
		Vector3.UP, yaw) * pixel_size - position
	emitter.light_energy = maxf(0.0, visual.light_energy + sin(time * 3.0) * visual.light_pulse)
