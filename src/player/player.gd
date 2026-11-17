class_name Player
extends CharacterBody3D
## 玩家：2 頭身像素角色（BLUEPRINT A9）+ 移動 + 元素佇列。
## 移動方向由外部塞進 move_input（HUD 搖桿或鍵盤），這裡不直接讀觸控。

signal cast(elements: Array[int], origin: Vector3, direction: Vector3)

const SPEED := 5.2
const PIXEL := 1.0 / 32.0
const FRAME_SIZE := Vector2i(56, 48)
const BODY_OFFSET_X := 4.5
const ATLAS_COLUMNS := 6
const ATLAS_ROWS := 3
enum Facing { FRONT, BACK, SIDE }

@export_range(1.0, 16.0, 0.5) var walk_fps := 8.0
@export_range(1.0, 6.0, 0.1) var idle_period := 2.6

var queue := ElementQueue.new()
## 搖桿輸入，x 右、y 下（螢幕方向），長度 0..1。
var move_input := Vector2.ZERO
## 右搖桿的螢幕方向；非零時瞄準優先於移動面向。
var aim_input := Vector2.ZERO
## 鏡頭水平朝向（弧度），由 main 每幀更新。
var camera_yaw := 0.0
## 目前面向／瞄準的世界方向（水平）。
var aim_dir := Vector3(0, 0, 1)

var sprite: Sprite3D
var staff_light: OmniLight3D
var _t := 0.0
var _animation_time := 0.0
var _was_moving := false


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.3
	shape.shape = capsule
	shape.position.y = 0.65
	add_child(shape)

	sprite = Sprite3D.new()
	sprite.texture = load("res://assets/characters/mage_atlas.png")
	sprite.hframes = ATLAS_COLUMNS
	sprite.vframes = ATLAS_ROWS
	sprite.pixel_size = PIXEL
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.shaded = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.double_sided = true
	sprite.centered = true
	# 腳底對齊原點；寬圖格右側保留給誇張的武器，原點仍在身體中央。
	sprite.offset = Vector2(BODY_OFFSET_X, FRAME_SIZE.y * 0.5 - 1.0)
	# 角色放在第 2 層：法杖的光只照場景、不照角色自己，否則整張圖會被洗成青色
	sprite.layers = 2
	add_child(sprite)

	# 魔導書水晶的微光：讓角色在夜裡也有一圈自己的光
	staff_light = OmniLight3D.new()
	staff_light.light_color = Color("#7ff3ff")
	staff_light.light_energy = 0.9
	staff_light.light_cull_mask = 0xFFFFF & ~2
	staff_light.omni_range = 3.2
	staff_light.omni_attenuation = 1.6
	staff_light.position = Vector3(0.3, 1.15, 0.25)
	add_child(staff_light)

	# 只照角色的補光（第 2 層）：不管哪個時段，角色都要看得清楚
	var fill := OmniLight3D.new()
	fill.light_color = Color("#fff1e0")
	fill.light_energy = 0.55
	fill.light_cull_mask = 2
	fill.omni_range = 4.0
	fill.omni_attenuation = 0.6
	fill.light_specular = 0.0
	fill.position = Vector3(0.6, 1.6, 2.0)
	add_child(fill)


func _physics_process(delta: float) -> void:
	_t += delta
	var input := move_input
	var kb := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	if kb != Vector2.ZERO:
		input = kb.normalized()
	var dir := Vector3(input.x, 0, input.y).rotated(Vector3.UP, camera_yaw)
	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED
	velocity.y = 0.0 if is_on_floor() else velocity.y - 20.0 * delta
	move_and_slide()

	if aim_input.length() > 0.2:
		aim_dir = Vector3(aim_input.x, 0, aim_input.y).rotated(Vector3.UP, camera_yaw).normalized()
	elif input.length() > 0.1:
		aim_dir = dir.normalized()
	# 用實際位移決定踏步，推著牆時不會繼續原地走。
	var actual := get_position_delta()
	var horizontal_speed := Vector2(actual.x, actual.z).length() / maxf(delta, 0.0001)
	_update_animation(delta, horizontal_speed)
	staff_light.light_energy = 0.9 + sin(_t * 3.0) * 0.15


func _update_animation(delta: float, horizontal_speed: float) -> void:
	var moving := horizontal_speed > 0.1
	if moving != _was_moving:
		_animation_time = 0.0
		_was_moving = moving
	_animation_time += delta * (clampf(horizontal_speed / SPEED, 0.25, 1.0) if moving else 1.0)
	_refresh_sprite()


func _refresh_sprite() -> void:
	var screen_dir := aim_dir.rotated(Vector3.UP, -camera_yaw)
	var facing := Facing.FRONT
	if absf(screen_dir.x) > absf(screen_dir.z):
		facing = Facing.SIDE
	elif screen_dir.z < 0.0:
		facing = Facing.BACK
	sprite.flip_h = facing == Facing.SIDE and screen_dir.x < 0.0
	sprite.offset.x = -BODY_OFFSET_X if sprite.flip_h else BODY_OFFSET_X
	staff_light.position = Vector3(-0.7 if sprite.flip_h else 0.7, 1.15, 0.0).rotated(Vector3.UP, camera_yaw)
	# 待機短暫眨眼；走路使用四張不同的手腳與衣襬姿勢。
	var column := 1 if fmod(_animation_time, idle_period) > idle_period - 0.16 else 0
	if _was_moving:
		column = 2 + int(_animation_time * walk_fps) % 4
	sprite.frame_coords = Vector2i(column, facing)


## 把目前佇列放出去（清空佇列）。direction 是水平世界方向。
func cast_queue(direction: Vector3) -> void:
	if queue.is_empty():
		return
	if direction.length() > 0.01:
		aim_dir = direction.normalized()
	_refresh_sprite()
	var elements := queue.take_all()
	cast.emit(elements, global_position + Vector3(0, 0.9, 0) + aim_dir * 0.5, aim_dir)
