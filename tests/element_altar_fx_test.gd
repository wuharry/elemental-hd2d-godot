extends SceneTree
## Runtime altar regression: animation survives batching without changing interaction geometry.
## Appearance still requires rendered day/night and motion captures.
## Run without --headless: the dummy rendering server does not retain MultiMesh transforms.

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


func _walk(node: Node) -> Array[Node]:
	var result: Array[Node] = [node]
	for child in node.get_children():
		result.append_array(_walk(child))
	return result


func _state(nodes: Array[Node]) -> Array:
	var result: Array = []
	for node in nodes:
		if node is Node3D:
			result.append(node.transform)
			result.append(node.visible)
		if node is MeshInstance3D:
			result.append(node.mesh.get_aabb())
		elif node is MultiMeshInstance3D:
			for index in node.multimesh.instance_count:
				result.append(node.multimesh.get_instance_transform(index))
	return result


func _resources(nodes: Array[Node]) -> Array:
	var result: Array = []
	for node in nodes:
		result.append(node.get_instance_id())
		if node is MeshInstance3D:
			result.append(node.mesh.get_instance_id())
			result.append(node.material_override.get_instance_id())
		elif node is MultiMeshInstance3D:
			result.append(node.multimesh.get_instance_id())
			result.append(node.multimesh.mesh.get_instance_id())
			result.append(node.material_override.get_instance_id())
	return result


func _connected_segments(node: MultiMeshInstance3D) -> bool:
	var mm := node.multimesh
	var half_height: float = mm.mesh.size.y * 0.5
	for i in range(mm.instance_count - 1):
		var a := mm.get_instance_transform(i) * Vector3(0, half_height, 0)
		var b := mm.get_instance_transform(i + 1) * Vector3(0, -half_height, 0)
		if a.distance_to(b) > 0.0001:
			return false
	return true


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("NOT RUN: altar FX transform checks require a rendered backend; remove --headless")
		quit(2)
		return
	for element: int in Elements.SELECTABLE:
		var altar := SetPieces.element_altar(element)
		root.add_child(altar)
		var label := Elements.display_name(element)
		var fx: Node3D
		var glyph: Sprite3D
		var collision: CollisionShape3D
		for node in _walk(altar):
			if node is Sprite3D:
				glyph = node
			if node is CollisionShape3D:
				collision = node
			var script: Script = node.get_script()
			if script != null and script.resource_path == "res://src/world/element_altar_fx.gd":
				fx = node
		_check(glyph != null and glyph.frame == Elements.ICON_ORDER.find(element)
			and glyph.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST,
			label + " keeps its matching readable plaque")
		_check(collision != null and collision.shape is BoxShape3D
			and collision.shape.size.is_equal_approx(Vector3(1.37, 1.03, 1.22))
			and collision.global_position.is_equal_approx(Vector3(0, 0.515, 0)),
			label + " preserves the pedestal collision and walk-up space")
		_check(fx != null, label + " has animated elemental content instead of a static recolored gem")
		if fx == null:
			altar.free()
			continue
		fx.set_process(false)
		var nodes := _walk(fx)
		var resources := _resources(nodes)
		var collision_transform := collision.global_transform
		MeshBatcher.batch(altar)
		_check(_resources(_walk(fx)) == resources, label + " retains all FX after static mesh batching")
		_check(collision.global_transform.is_equal_approx(collision_transform), label + " batching retains collision")
		var initial := _state(nodes)
		var moved := false
		var finite := true
		var unit_scale := true
		var connected := true
		var chain: MultiMeshInstance3D
		for node in nodes:
			if node is MultiMeshInstance3D and node.name in ["FlowingStream", "LightningCore"]:
				chain = node
		for tick in 96:
			fx.call("advance", 1.0 / 24.0)
			moved = moved or _state(nodes) != initial
			if chain != null:
				connected = connected and _connected_segments(chain)
			for node in nodes:
				if node is Node3D:
					finite = finite and node.transform.is_finite()
					unit_scale = unit_scale and node.basis.get_scale().is_equal_approx(Vector3.ONE)
				if node is MultiMeshInstance3D:
					for index in node.multimesh.instance_count:
						finite = finite and node.multimesh.get_instance_transform(index).is_finite()
		_check(moved, label + " changes visible geometry over four seconds")
		_check(finite and unit_scale, label + " animation keeps finite transforms and unscaled scene nodes")
		_check(_resources(_walk(fx)) == resources, label + " reuses its node/mesh/material pool across animation")
		if chain != null:
			_check(connected, label + " rotating flow/arc segments stay connected at their endpoints")
			# Reproduce the wrong global-axis scaling and prove the continuity check rejects it.
			var original := chain.multimesh.get_instance_transform(0)
			var broken := original
			broken.basis = original.basis.orthonormalized().scaled(original.basis.get_scale())
			chain.multimesh.set_instance_transform(0, broken)
			_check(not _connected_segments(chain), label + " continuity check detects global/local scale mixups")
			chain.multimesh.set_instance_transform(0, original)
			_check(_connected_segments(chain), label + " original connected geometry is restored")
		var safe_lights := true
		var light_count := 0
		for node in nodes:
			if node is Light3D:
				light_count += 1
				safe_lights = safe_lights and node.is_in_group("magic_lights") and not node.shadow_enabled \
					and is_zero_approx(node.light_volumetric_fog_energy) and node.light_energy > 0.0 \
					and node is OmniLight3D and node.omni_range <= 2.1
		_check(light_count == 1, label + " illuminates its pedestal with one local light")
		_check(safe_lights, label + " uses bounded local magic lighting without shadow/fog passes")
		altar.free()
	Mats.reset()
	print("altar FX: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed else 0)
