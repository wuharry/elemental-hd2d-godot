class_name CameraRig
extends Node3D
## 斜俯視鏡頭：窄視角拉遠拍 + 近、遠兩段景深，做出微縮模型的感覺。
## 對焦永遠在跟隨目標（角色）身上。

@export var target: Node3D
@export var yaw_deg := 22.0
@export var pitch_deg := 33.0
@export var distance := 30.0
@export var fov := 25.0
## 鏡頭看的點相對角色的偏移：往畫面深處看一點，讓房子完整入鏡。
@export var look_offset := Vector3(0.0, 1.0, -2.2)
@export var follow_speed := 5.0
## 對焦點前後各多少公尺內是清楚的。
@export var focus_near := 3.5
@export var focus_far := 4.5
@export var blur_amount := 0.16
@export var reveal_foliage := true

var camera: Camera3D
var attrs: CameraAttributesPractical


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = fov
	camera.near = 1.0
	camera.far = 260.0
	add_child(camera)
	attrs = CameraAttributesPractical.new()
	attrs.dof_blur_far_enabled = true
	attrs.dof_blur_near_enabled = true
	attrs.dof_blur_amount = blur_amount
	camera.attributes = attrs
	_update_offsets()
	if target:
		global_position = target.global_position + look_offset
	camera.make_current()


func _update_offsets() -> void:
	rotation_degrees = Vector3(0, yaw_deg, 0)
	var p := deg_to_rad(pitch_deg)
	camera.position = Vector3(0, sin(p), cos(p)) * distance
	camera.rotation_degrees = Vector3(-pitch_deg, 0, 0)
	camera.fov = fov
	attrs.dof_blur_amount = blur_amount
	attrs.dof_blur_near_distance = distance - focus_near
	attrs.dof_blur_near_transition = 4.0
	attrs.dof_blur_far_distance = distance + focus_far
	attrs.dof_blur_far_transition = 9.0


func _process(delta: float) -> void:
	if target:
		var goal := target.global_position + look_offset
		global_position = global_position.lerp(goal, 1.0 - exp(-follow_speed * delta))
	_update_offsets()
	if target:
		RenderingServer.global_shader_parameter_set("foliage_focus", target.global_position + Vector3(0, 0.85, 0))
		RenderingServer.global_shader_parameter_set("foliage_eye", camera.global_position)
		RenderingServer.global_shader_parameter_set("foliage_reveal", 1.0 if reveal_foliage else 0.0)


func _exit_tree() -> void:
	RenderingServer.global_shader_parameter_set("foliage_reveal", 0.0)


## 鏡頭水平朝向（弧度），給角色把搖桿方向轉成世界方向用。
func yaw() -> float:
	return deg_to_rad(yaw_deg)
