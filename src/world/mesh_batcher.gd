class_name MeshBatcher
extends RefCounted
## 只合併靜態 primitive 網格；碰撞、燈、粒子、帶腳本的動態子樹仍留在原處。
## 依材質與空間格分批，避免整張地圖共用一個無法有效裁切的大包圍盒。

const CUSTOM_FORMAT := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT)


## 回傳 {sources, batches}，便於截圖驗收記錄。重複呼叫不會再次合併 ArrayMesh。
static func batch(root: Node3D, cell_size: float = 24.0, centered: bool = false) -> Dictionary:
	assert(cell_size > 0.0)
	var groups: Dictionary = {}
	var grid_offset := Vector2.ONE * cell_size * 0.5 if centered else Vector2.ZERO
	_collect(root, Transform3D.IDENTITY, groups, cell_size, true, grid_offset)
	var result := {"sources": 0, "batches": 0}
	for group: Dictionary in groups.values():
		var sources: Array = group["sources"]
		if sources.size() < 2:
			continue
		var merged := _merge(group)
		root.add_child(merged)
		for source: Dictionary in sources:
			(source["node"] as MeshInstance3D).free()
		result["sources"] += sources.size()
		result["batches"] += 1
	root.set_meta("mesh_batch_stats", result)
	return result


static func _collect(node: Node3D, transform: Transform3D, groups: Dictionary, cell_size: float, is_root: bool = false, grid_offset: Vector2 = Vector2.ZERO) -> void:
	if not is_root:
		if node.get_script() != null or not node.visible or node.top_level:
			return
		transform *= node.transform
		# These assets intentionally avoid scale (A6). Unsupported transformed subtrees remain intact.
		if not transform.basis.get_scale().is_equal_approx(Vector3.ONE):
			return
	if node is MeshInstance3D:
		_collect_mesh(node as MeshInstance3D, transform, groups, cell_size, grid_offset)
	for child in node.get_children():
		if child is Node3D:
			_collect(child as Node3D, transform, groups, cell_size, false, grid_offset)


static func _collect_mesh(node: MeshInstance3D, transform: Transform3D, groups: Dictionary, cell_size: float, grid_offset: Vector2) -> void:
	if not (node.mesh is BoxMesh or node.mesh is PrismMesh or node.mesh is QuadMesh):
		return
	if node.get_child_count() > 0 or node.material_overlay != null or node.transparency != 0.0:
		return
	if node.visibility_range_begin != 0.0 or node.visibility_range_end != 0.0:
		return
	var source := node.get_active_material(0)
	if source == null or source.next_pass != null:
		return
	var kind: String = source.get_meta("batch_kind", "plain")
	var material: Material = source
	if source is ShaderMaterial:
		if kind != "foliage":
			return
		material = Mats.batched_foliage(String(source.get_meta("foliage_tex", "leaves")))
	elif source is StandardMaterial3D:
		var standard := source as StandardMaterial3D
		if standard.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or standard.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED or standard.grow:
			return
		if standard.uv1_triplanar:
			if kind != "triplanar" or standard.emission_enabled or standard.uv1_world_triplanar:
				return
			material = Mats.batched_tri(standard)
	else:
		return
	var cell := Vector2i(floori((transform.origin.x + grid_offset.x) / cell_size), floori((transform.origin.z + grid_offset.y) / cell_size))
	var key := "%d:%s:%d:%d:%d" % [material.get_instance_id(), cell, node.layers, node.cast_shadow, node.gi_mode]
	if not groups.has(key):
		groups[key] = {"material": material, "kind": kind, "sources": [], "origin": Vector3(cell.x * cell_size - grid_offset.x, 0.0, cell.y * cell_size - grid_offset.y)}
	(groups[key]["sources"] as Array).append({"node": node, "transform": transform, "material": source})


static func _merge(group: Dictionary) -> MeshInstance3D:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var centers := PackedFloat32Array()
	var local_positions := PackedFloat32Array()
	var local_normals := PackedFloat32Array()
	var binormals := PackedFloat32Array()
	var origin: Vector3 = group["origin"]
	var kind: String = group["kind"]
	for item: Dictionary in group["sources"]:
		var node: MeshInstance3D = item["node"]
		var transform: Transform3D = item["transform"]
		transform.origin -= origin
		var source: Material = item["material"]
		var src := node.mesh.surface_get_arrays(0)
		var src_v: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
		var src_n: PackedVector3Array = src[Mesh.ARRAY_NORMAL]
		var src_t: PackedFloat32Array = src[Mesh.ARRAY_TANGENT]
		var src_uv: PackedVector2Array = src[Mesh.ARRAY_TEX_UV]
		var src_i: PackedInt32Array = src[Mesh.ARRAY_INDEX]
		var color := Color.WHITE
		var sway := 0.0
		if kind == "triplanar":
			color = (source as StandardMaterial3D).albedo_color.srgb_to_linear()
		elif kind == "foliage":
			color = (source as ShaderMaterial).get_shader_parameter("tint")
			color = color.srgb_to_linear()
			sway = float((source as ShaderMaterial).get_shader_parameter("sway"))
		var base := vertices.size()
		for i in src_v.size():
			var normal := src_n[i]
			var tangent := Vector3(src_t[i * 4], src_t[i * 4 + 1], src_t[i * 4 + 2])
			var sign_w := src_t[i * 4 + 3]
			var binormal := normal.cross(tangent) * sign_w
			if kind == "triplanar":
				var n := normal.abs()
				tangent = Vector3(n.y + n.z, 0.0, -n.x).normalized()
				binormal = Vector3(0.0, n.x + n.z, -n.y).normalized()
			tangent = (transform.basis * tangent).normalized()
			binormal = (transform.basis * binormal).normalized()
			vertices.append(transform * src_v[i])
			normals.append((transform.basis * normal).normalized())
			tangents.append_array(PackedFloat32Array([tangent.x, tangent.y, tangent.z, sign_w]))
			uvs.append(src_uv[i])
			centers.append_array(PackedFloat32Array([transform.origin.x, transform.origin.y, transform.origin.z, sway]))
			local_positions.append_array(PackedFloat32Array([src_v[i].x, src_v[i].y, src_v[i].z, color.r]))
			local_normals.append_array(PackedFloat32Array([normal.x, normal.y, normal.z, color.g]))
			binormals.append_array(PackedFloat32Array([binormal.x, binormal.y, binormal.z, color.b]))
		for index in src_i:
			indices.append(base + index)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var custom := kind in ["triplanar", "foliage"]
	if custom:
		arrays[Mesh.ARRAY_CUSTOM0] = centers
		arrays[Mesh.ARRAY_CUSTOM1] = local_positions
		arrays[Mesh.ARRAY_CUSTOM2] = local_normals
		arrays[Mesh.ARRAY_CUSTOM3] = binormals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, CUSTOM_FORMAT if custom else 0)
	var merged := MeshInstance3D.new()
	merged.name = "StaticBatch"
	merged.mesh = mesh
	merged.material_override = group["material"]
	merged.position = origin
	var first: MeshInstance3D = group["sources"][0]["node"]
	merged.layers = first.layers
	merged.cast_shadow = first.cast_shadow
	merged.gi_mode = first.gi_mode
	# Wind moves vertices outside the authored bounds by at most 0.06m.
	merged.extra_cull_margin = 0.1 if kind == "foliage" else first.extra_cull_margin
	return merged
