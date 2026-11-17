class_name Build
extends RefCounted
## 組裝小工具。尺寸一律寫進 mesh.size，不用 node scale（BLUEPRINT A6）。


static func box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


static func quad(parent: Node3D, size: Vector2, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


static func prism(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := PrismMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


## 方塊碰撞體（玩家撞牆用）。
static func collider(parent: Node3D, size: Vector3, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	body.position = pos
	parent.add_child(body)
	return body


## 暖色點光源。加入 "warm_lights" 群組，TimeOfDay 依時段乘上強度。
static func warm_light(parent: Node3D, pos: Vector3, energy: float, light_range: float, shadow: bool = false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = Color("#ffb060")
	l.omni_range = light_range
	l.omni_attenuation = 1.3
	l.shadow_enabled = shadow
	l.shadow_blur = 2.0
	l.light_volumetric_fog_energy = 0.4
	l.light_energy = 0.0
	l.set_meta("base_energy", energy)
	l.add_to_group("warm_lights")
	parent.add_child(l)
	return l
