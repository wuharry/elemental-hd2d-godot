extends Node3D
## 武器獨立於角色圖集，位置由掌心決定。手掌圖層永遠蓋在武器前方。

const Visual := preload("res://src/player/weapon_visual.gd")

var sprite := Sprite3D.new()
var emitter := OmniLight3D.new()
var visual: Visual


func _init() -> void:
	name = "HeldWeapon"
	sprite.name = "WeaponSprite"
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.shaded = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.double_sided = true
	sprite.layers = 2
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


## grip 是腳底原點上的像素座標，x 向右、y 向上；尚未套鏡像與俯角。
func pose(grip: Vector2, mirrored: bool, pixel_size: float, stretch: float,
		yaw: float, camera_depth: Vector3, time: float) -> void:
	position = camera_depth
	if visual == null or sprite.texture == null:
		return
	var sign_x := -1.0 if mirrored else 1.0
	var half_size := sprite.texture.get_size() * 0.5
	sprite.flip_h = mirrored
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
