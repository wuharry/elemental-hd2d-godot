class_name Build
extends RefCounted
## 組裝小工具。尺寸一律寫進 mesh.size，不用 node scale（BLUEPRINT A6）。


## 保留矩形扣掉所有洞口後的區域；不量化座標，輸出互不重疊的矩形。
static func subtract_rects(area: Rect2, holes: Array) -> Array[Rect2]:
	var pieces: Array[Rect2] = []
	if not area.has_area():
		return pieces
	pieces.append(area)
	for hole: Rect2 in holes:
		var remaining: Array[Rect2] = []
		for piece: Rect2 in pieces:
			var cut := piece.intersection(hole)
			if not cut.has_area():
				remaining.append(piece)
				continue
			var strips := [
				Rect2(piece.position.x, piece.position.y, piece.size.x, cut.position.y - piece.position.y),
				Rect2(piece.position.x, cut.end.y, piece.size.x, piece.end.y - cut.end.y),
				Rect2(piece.position.x, cut.position.y, cut.position.x - piece.position.x, cut.size.y),
				Rect2(cut.end.x, cut.position.y, piece.end.x - cut.end.x, cut.size.y),
			]
			for strip: Rect2 in strips:
				if strip.has_area():
					remaining.append(strip)
		pieces = remaining
	return pieces


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
	# 雙拋物面陰影只畫 2 面（立方體 6 面）；方塊幾何看不出差別，夜晚 draw call 少很多
	l.omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID
	l.shadow_blur = 2.0
	l.light_volumetric_fog_energy = 0.4
	l.light_energy = 0.0
	l.set_meta("base_energy", energy)
	l.add_to_group("warm_lights")
	parent.add_child(l)
	return l
