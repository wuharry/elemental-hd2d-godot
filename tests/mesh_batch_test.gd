extends SceneTree
## Verify merge transforms, local texture coordinates, foliage origins, and excluded dynamic nodes.

const Batcher := preload("res://src/world/mesh_batcher.gd")
var _passed := 0
var _failed := 0


func _init() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		printerr("FAIL: ", message)


func _xyz(values: PackedFloat32Array, index: int) -> Vector3:
	return Vector3(values[index * 4], values[index * 4 + 1], values[index * 4 + 2])


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var pivot := Node3D.new()
	pivot.position = Vector3(2.3, 1.2, 3.4)
	pivot.rotation_degrees = Vector3(10, 36, 3)
	world.add_child(pivot)
	var a := Build.box(pivot, Vector3(1.2, 0.4, 2.3), Vector3(1, 2, 1), Mats.tri("roof", Color("#9d5839")), Vector3(30, 90, 0))
	var b := Build.box(pivot, Vector3(0.3, 1.4, 0.5), Vector3(2, 2, 2), Mats.tri("roof", Color("#567093")))
	var sources := [a, b]
	var expected_vertices := PackedVector3Array()
	var expected_locals := PackedVector3Array()
	var expected_normals := PackedVector3Array()
	for source: MeshInstance3D in sources:
		var arrays := source.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in vertices.size():
			expected_vertices.append(source.global_transform * vertices[i])
			expected_locals.append(vertices[i])
			expected_normals.append(source.global_basis * normals[i])
	var collider := Build.collider(pivot, Vector3.ONE, Vector3.ZERO)
	var collision_transform := collider.global_transform
	var spinning := Node3D.new()
	spinning.set_script(load("res://src/world/spin.gd"))
	world.add_child(spinning)
	var moving := Build.box(spinning, Vector3.ONE, Vector3.ZERO, Mats.tri("roof"))
	var unknown_material := ShaderMaterial.new()
	unknown_material.shader = load("res://shaders/water.gdshader")
	var unknown := Build.box(world, Vector3.ONE, Vector3.ZERO, unknown_material)
	var shadows := Build.box(world, Vector3.ONE, Vector3(5, 1, 1), Mats.tri("roof"))
	shadows.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	var stats := Batcher.batch(world, 24.0, true)
	_check(stats["sources"] == 2 and stats["batches"] == 1, "Only the two compatible static roof boxes merge, including different tints")
	_check(is_instance_valid(moving) and moving.get_parent() == spinning, "Animated subtree remains intact")
	_check(is_instance_valid(unknown), "Unknown shader remains intact")
	_check(is_instance_valid(shadows), "Different shadow modes never share one batch")
	_check(collider.global_transform.is_equal_approx(collision_transform), "Collision shape transform is unchanged")
	var merged := world.get_node("StaticBatch") as MeshInstance3D
	var data := merged.mesh.surface_get_arrays(0)
	var merged_vertices: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
	var merged_normals: PackedVector3Array = data[Mesh.ARRAY_NORMAL]
	var local_data: PackedFloat32Array = data[Mesh.ARRAY_CUSTOM1]
	var transform_ok := merged_vertices.size() == expected_vertices.size()
	var local_ok := true
	var normals_ok := true
	for i in merged_vertices.size():
		transform_ok = transform_ok and (merged.global_transform * merged_vertices[i]).distance_to(expected_vertices[i]) < 0.0001
		local_ok = local_ok and _xyz(local_data, i).distance_to(expected_locals[i]) < 0.0001
		normals_ok = normals_ok and merged_normals[i].distance_to(expected_normals[i]) < 0.001
	_check(transform_ok, "Centered cells and nested rotated boxes retain every world-space vertex")
	_check(local_ok, "Triplanar positions retain original local coordinates")
	_check(normals_ok, "Normals follow each source rotation")
	_check(absf(local_data[3] - Color("#9d5839").srgb_to_linear().r) < 0.000001, "Source tint retains linear float precision")
	_check((Batcher.batch(world)["sources"] as int) == 0, "Batching is idempotent")
	world.free()

	var trees := Node3D.new()
	root.add_child(trees)
	var leaf_a := Build.box(trees, Vector3.ONE, Vector3(2, 3, 4), Mats.foliage(Color("#a0c070"), 0.03))
	Build.box(trees, Vector3.ONE, Vector3(3, 4, 5), Mats.foliage(Color("#668842"), 0.06), Vector3(0, 45, 0))
	var leaf_center := leaf_a.position
	stats = Batcher.batch(trees, 24.0, true)
	_check(stats["sources"] == 2 and stats["batches"] == 1, "Foliage tint and sway variants share one batch")
	merged = trees.get_node("StaticBatch") as MeshInstance3D
	data = merged.mesh.surface_get_arrays(0)
	var center_data: PackedFloat32Array = data[Mesh.ARRAY_CUSTOM0]
	_check((_xyz(center_data, 0) + merged.position).is_equal_approx(leaf_center), "Wind uses the original block center")
	_check(is_equal_approx(center_data[3], 0.03) and is_equal_approx(center_data[24 * 4 + 3], 0.06), "Each block retains its own sway amplitude")
	_check((merged.material_override as ShaderMaterial).get_shader_parameter("batched") == true, "Batched foliage enables its vertex metadata path")
	_check(merged.extra_cull_margin >= 0.06, "Foliage bounds include maximum wind displacement")
	trees.free()
	Mats.reset()
	print("mesh batching: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed else 0)
