extends SceneTree
## godot --headless --path . --script res://tests/element_orbit_test.gd

var _passed := 0
var _failed := 0


func _init() -> void:
	_run.call_deferred()


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("FAIL: ", label)


func _visible_motes(orbit: Node3D) -> Array[Sprite3D]:
	var visible_motes: Array[Sprite3D] = []
	for dot: Sprite3D in orbit.get_children():
		if dot.visible:
			visible_motes.append(dot)
	return visible_motes


func _matches(orbit: Node3D, elements: Array) -> bool:
	var dots := _visible_motes(orbit)
	if dots.size() != elements.size():
		return false
	for i in dots.size():
		if not dots[i].modulate.is_equal_approx(Elements.color(elements[i])):
			return false
	return true


func _evenly_spaced(dots: Array[Sprite3D]) -> bool:
	for i in dots.size():
		var p := dots[i].position
		var next := dots[(i + 1) % dots.size()].position
		var radial := Vector2(p.x, p.z)
		var next_radial := Vector2(next.x, next.z)
		var gap := fposmod(radial.angle_to(next_radial), TAU)
		if radial.length() < 0.5 or not is_equal_approx(gap, TAU / dots.size()):
			return false
	return true


func _run() -> void:
	var player := Player.new()
	player.queue.add(Elements.Type.WATER)
	root.add_child(player)
	var orbit := player.get_node("ElementOrbit") as Node3D
	_check(_matches(orbit, [Elements.Type.WATER]), "掛上角色時同步已有的元素")
	player.queue.add(Elements.Type.FIRE)
	_check(_matches(orbit, [Elements.Type.WATER, Elements.Type.FIRE]), "加入火後立刻顯示水與火")
	_check(_evenly_spaced(_visible_motes(orbit)), "兩顆光點分居兩側")
	player.queue.fuse_last_two()
	_check(_matches(orbit, [Elements.Type.STEAM]), "融合後只有一顆蒸氣色光點")
	player.queue.add(Elements.Type.LIGHTNING)
	player.queue.add(Elements.Type.ICE)
	_check(_evenly_spaced(_visible_motes(orbit)), "三顆光點均分軌道")
	player.queue.add(Elements.Type.ICE)
	player.queue.add(Elements.Type.FIRE)
	_check(_matches(orbit, [Elements.Type.STEAM, Elements.Type.LIGHTNING, Elements.Type.ICE, Elements.Type.ICE]),
			"重複冰各有一顆，超過四格不再增加")
	var dots := _visible_motes(orbit)
	_check(_evenly_spaced(dots), "四顆光點均分軌道")
	var relative := player.to_local(dots[0].global_position)
	_check(is_equal_approx(Vector2(relative.x, relative.z).length(), 0.94 * 1.2)
		and is_equal_approx(relative.y, 0.72 * 1.2), "光點環繞放大後的角色，軌道半徑與高度同步")
	var before := dots[0].position
	orbit.call("_process", 0.1)
	_check(not dots[0].position.is_equal_approx(before), "元素會沿軌道移動")
	var old_world_pos := dots[0].global_position
	player.position += Vector3(10.0, 1.0, 4.0)
	_check((dots[0].global_position - old_world_pos).is_equal_approx(Vector3(10.0, 1.0, 4.0)),
			"玩家換位置時光點同步跟隨")
	player.cast_queue(Vector3.RIGHT)
	_check(_matches(orbit, []) and not orbit.is_processing(), "施法後立刻隱藏所有光點並停止更新")
	player.queue.add(Elements.Type.FIRE)
	_check(orbit.is_processing(), "再次填入佇列即恢復環繞")
	player.queue.clear()
	_check(_matches(orbit, []) and not orbit.is_processing(), "手動清空也移除光點")
	player.free()
	print("%d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
