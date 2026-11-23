extends SceneTree
## 操作路徑測試：載入真正的 main 場景，送出觸控事件，檢查佇列、施法與移動的結果。
## 用法：godot --headless --path . --script res://tests/hud_input_test.gd
## 只驗證「按了會發生對的事」；手感與畫面要實機看。

var _failed := 0
var _passed := 0
var _casts := 0


func _init() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		printerr("FAIL: ", what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## HUD 的座標是畫布座標；作業系統送進來的是視窗像素座標，引擎會自己換算。
## 測試要模擬作業系統，所以先把畫布座標換回視窗座標再送。
func _to_window(pos: Vector2) -> Vector2:
	return root.get_final_transform() * pos


func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = _to_window(pos)
	e.pressed = pressed
	Input.parse_input_event(e)


func _drag(index: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = _to_window(pos)
	Input.parse_input_event(e)


func _tap(pos: Vector2) -> void:
	_touch(0, pos, true)
	await _frames(2)
	_touch(0, pos, false)
	await _frames(2)


func _tap_portal(pos: Vector2, taps := 1) -> void:
	# 同一個遊戲更新內連點，驗證過場不會重入或誤開落點的祭壇。
	for i in taps:
		_touch(0, pos, true)
		_touch(0, pos, false)
		Input.flush_buffered_events()
	await create_timer(0.4).timeout
	await _frames(2)


func _tap_key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var key := InputEventKey.new()
		key.physical_keycode = code
		key.pressed = pressed
		Input.parse_input_event(key)
		await _frames(2)


func _stand_at(player: Player, point: Vector2) -> void:
	player.global_position = Vector3(point.x, 0, point.y)
	player.velocity = Vector3.ZERO
	await _frames(4)


## 全程推同一支虛擬搖桿，讓 Player 用真實碰撞走到每個轉彎處。
func _walk_road(player: Player, stick: Dictionary, turns: Array[Vector2]) -> bool:
	var center: Vector2 = stick["c"]
	var radius: float = stick["r"]
	_touch(0, center, true)
	for target in turns:
		var reached := false
		for tick in Engine.physics_ticks_per_second * 5:
			var pos := Vector2(player.position.x, player.position.z)
			if pos.distance_to(target) < 0.18:
				reached = true
				break
			var to_target := Vector3(target.x - pos.x, 0, target.y - pos.y)
			var direction := to_target.rotated(Vector3.UP, -player.camera_yaw).normalized()
			_drag(0, center + Vector2(direction.x, direction.z) * radius)
			Input.flush_buffered_events()
			await physics_frame
		if not reached:
			printerr("無法步行到 ", target, "，實際停在 ", player.position)
			_touch(0, center, false)
			return false
	var still_moving := player.move_input.length() > 0.8
	_touch(0, center, false)
	await _frames(2)
	return still_moving


func _widget(hud: Node, kind: String, nth: int = 0) -> Dictionary:
	var seen := 0
	for w in hud.get("_widgets"):
		if w["kind"] == kind:
			if seen == nth:
				return w
			seen += 1
	return {}


func _run() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _frames(5)
	var hud: Node = main.get("hud")
	var player: Player = main.get("player")
	player.cast.connect(func(_e: Array[int], _o: Vector3, _d: Vector3) -> void: _casts += 1)

	var water: Dictionary = _widget(hud, "element", 0)
	var fire: Dictionary = _widget(hud, "element", 1)
	var bolt: Dictionary = _widget(hud, "element", 2)
	var fuse: Dictionary = _widget(hud, "fuse")
	var aim: Dictionary = _widget(hud, "aim")
	var move: Dictionary = _widget(hud, "move")

	# 1. 輕點元素鍵加入佇列
	await _tap(water["c"])
	await _tap(fire["c"])
	_check(player.queue.slots == [Elements.Type.WATER, Elements.Type.FIRE], "輕點水、火 → 佇列 [水][火]，實際 %s" % [player.queue.slots])

	# 2. 融合鍵
	await _tap(fuse["c"])
	_check(player.queue.slots == [Elements.Type.STEAM], "按融合 → [蒸]，實際 %s" % [player.queue.slots])

	# 3. 右搖桿推到外圈放開 = 施放並清空佇列
	var ac: Vector2 = aim["c"]
	var ar: float = aim["r"]
	_touch(1, ac, true)
	await _frames(2)
	_drag(1, ac + Vector2(ar * 0.9, 0))
	await _frames(2)
	_touch(1, ac + Vector2(ar * 0.9, 0), false)
	await _frames(3)
	_check(_casts == 1, "外圈放開應施放一次，實際 %d 次" % _casts)
	_check(player.queue.is_empty(), "施放後佇列清空")
	_check(player.aim_dir.x > 0.5, "往螢幕右邊瞄準 → 世界方向偏 +X，實際 %s" % player.aim_dir)

	# 4. 推到外圈再拉回內圈放開 = 取消，佇列保留
	await _tap(bolt["c"])
	_touch(1, ac, true)
	await _frames(2)
	_drag(1, ac + Vector2(ar * 0.9, 0))
	await _frames(2)
	_drag(1, ac + Vector2(ar * 0.3, 0))
	await _frames(2)
	_touch(1, ac + Vector2(ar * 0.3, 0), false)
	await _frames(3)
	_check(_casts == 1, "拉回內圈放開不應施放")
	_check(player.queue.slots == [Elements.Type.LIGHTNING], "取消後佇列保留，實際 %s" % [player.queue.slots])
	var carried_motes := player.get_node("ElementOrbit").get_children().filter(
		func(dot: Sprite3D) -> bool: return dot.visible)
	_check(carried_motes.size() == 1 and carried_motes[0].modulate.is_equal_approx(Elements.color(Elements.Type.LIGHTNING)),
		"取消後雷光點仍繞在角色身旁")

	# 5. 佇列上限四格
	for i in 5:
		await _tap(bolt["c"])
	_check(player.queue.slots.size() == 4, "最多四格，實際 %d" % player.queue.slots.size())

	# 6. 長按元素鍵不會加入元素（那是護盾的操作）
	player.queue.clear()
	_touch(0, water["c"], true)
	await create_timer(0.5).timeout
	_touch(0, water["c"], false)
	await _frames(3)
	_check(player.queue.is_empty(), "長按是護盾操作，不應加入元素")

	# 7. 左搖桿移動；同時另一指點元素鍵（多指）
	var mc: Vector2 = move["c"]
	var start_x := player.global_position.x
	_touch(0, mc, true)
	await _frames(2)
	_drag(0, mc + Vector2(move["r"], 0))
	await _frames(2)
	_touch(1, fire["c"], true)
	await _frames(2)
	_touch(1, fire["c"], false)
	await create_timer(0.4).timeout
	_check(player.move_input.x > 0.8, "左搖桿推右 → move_input.x 接近 1，實際 %.2f" % player.move_input.x)
	_check(player.global_position.x > start_x + 0.5, "角色應往右移動，位移 %.2f" % (player.global_position.x - start_x))
	_check(player.queue.slots == [Elements.Type.FIRE], "移動中另一指仍可加入元素，實際 %s" % [player.queue.slots])
	# 左搖桿仍往右時，右搖桿往左：移動不能覆寫正在瞄準的方向。
	_touch(2, ac, true)
	_drag(2, ac - Vector2(ar * 0.9, 0))
	await create_timer(0.15).timeout
	_check(player.move_input.x > 0.8 and player.aim_dir.x < -0.5
		and player.sprite.frame_coords.y == 2 and player.sprite.flip_h,
		"移動與瞄準可反方向，面向以右搖桿為準")
	_drag(2, ac - Vector2(ar * 0.3, 0))
	_touch(2, ac - Vector2(ar * 0.3, 0), false)
	await create_timer(0.1).timeout
	_check(player.aim_input == Vector2.ZERO and player.aim_dir.x > 0.5
		and _casts == 1 and player.queue.slots == [Elements.Type.FIRE],
		"取消瞄準後恢復移動面向，佇列保留")
	_touch(0, mc + Vector2(move["r"], 0), false)
	await _frames(3)
	_check(player.move_input == Vector2.ZERO, "放開左搖桿後停止")

	# 尺寸改變會重建控件；舊觸控必須一起取消，避免角色繼續移動／瞄準。
	_touch(0, mc, true)
	_drag(0, mc + Vector2(move["r"], 0))
	_touch(1, ac, true)
	_drag(1, ac - Vector2(ar * 0.9, 0))
	await _frames(3)
	_check(player.move_input != Vector2.ZERO and player.aim_input != Vector2.ZERO,
		"尺寸更新前兩支搖桿均已按下")
	# headless 沒有作業系統視窗事件，從同一個 Viewport 訊號入口送出。
	root.size_changed.emit()
	await _frames(3)
	_check(player.move_input == Vector2.ZERO and player.aim_input == Vector2.ZERO,
		"視窗改變尺寸後釋放舊搖桿狀態")

	# 改用圖示後，四個觸控位置仍要對到各自的元素，包括冰。
	player.queue.clear()
	for i in Elements.LOADOUT.size():
		await _tap(_widget(hud, "element", i)["c"])
	_check(player.queue.slots == Elements.LOADOUT, "逐一點四顆圖示 → 依序排入水、火、雷、冰")

	# 從村莊傳送到森林祭壇；移動測試角色並送入正常操作事件。
	var spawn := Vector2(main.world.def.player_start.x, main.world.def.player_start.z)
	await _stand_at(player, spawn)
	await _tap_key(KEY_E)
	_check(not player.choosing_loadout and _widget(hud, "loadout_open").is_empty()
		and _widget(hud, "interact").is_empty() and main.world.def.id == "village",
		"村莊出生點按 E 不會傳送或配裝")

	var gate: Vector2 = main.world.def.interactions["to_altar"]
	var western_boundary: float = -main.world.def.play_half.x
	_check(gate.x - western_boundary >= 0.0 and gate.x - western_boundary <= 3.0,
		"村頭西門位於可行走地圖西界內三公尺")
	var village_road: Array[Vector2] = [Vector2(-2, -3), Vector2(-13, -1.6), Vector2(-24, 1.6), gate]
	var reached_gate := await _walk_road(player, move, village_road)
	_check(reached_gate, "角色持續推搖桿，從村莊出生點沿石板路走到西門中心")
	var portal := _widget(hud, "interact")
	_check(not portal.is_empty(), "村莊傳送門旁出現互動按鈕")
	if portal.is_empty():
		quit(1)
		return
	await _tap_portal(portal["c"], 2)
	_check(main.world.def.id == "forest" and not player.choosing_loadout,
		"連點傳送門後抵達森林祭壇，配裝由玩家另行觸發")
	var altar := _widget(hud, "interact")
	_check(main.world.def.interactions.has("equip") and not altar.is_empty(),
		"傳送落點可直接與祭壇互動")
	if altar.is_empty() or not main.world.def.interactions.has("equip"):
		quit(1)
		return

	# 按住祭壇互動時離開感應範圍，原手指放開不能開啟配裝。
	_touch(0, altar["c"], true)
	await _frames(2)
	await _stand_at(player, Vector2(3, 1))
	_touch(0, altar["c"], false)
	await _frames(2)
	_check(not player.choosing_loadout and _widget(hud, "interact").is_empty(),
		"離開祭壇後放開舊觸控不會遠端換裝")

	await _stand_at(player, main.world.def.interactions["equip"])
	await _tap_key(KEY_E)
	_check(player.choosing_loadout, "祭壇旁按 E 可裝備元素")
	if not player.choosing_loadout:
		quit(1)
		return
	_check(_widget(hud, "loadout_option", 5).get("element", -1) == Elements.Type.ARCANE
		and _widget(hud, "loadout_option", 6).is_empty(), "配裝顯示六種基礎元素")
	await _tap(_widget(hud, "loadout_option", 4)["c"])
	await _tap(_widget(hud, "loadout_apply")["c"])
	_check(player.choosing_loadout and player.loadout == Elements.LOADOUT, "少於四種時無法確定")
	await _tap(_widget(hud, "loadout_cancel")["c"])
	_check(not player.choosing_loadout and player.loadout == Elements.LOADOUT, "取消配裝保留原按鍵")

	await _tap(_widget(hud, "interact")["c"])
	await _tap(_widget(hud, "loadout_option", 1)["c"])
	await _tap(_widget(hud, "loadout_option", 4)["c"])
	await _tap(_widget(hud, "loadout_option", 3)["c"])
	await _tap(_widget(hud, "loadout_option", 1)["c"])
	await _tap(_widget(hud, "loadout_option", 5)["c"])
	await _tap(_widget(hud, "loadout_apply")["c"])
	_check(player.loadout == [Elements.Type.WATER, Elements.Type.ICE, Elements.Type.EARTH, Elements.Type.ARCANE],
		"確定後四個出戰按鍵對應新的元素順序")
	_check(player.queue.slots == Elements.LOADOUT, "換裝保留已排好的法術")
	await _stand_at(player, main.world.def.interactions["to_village"])
	await _tap_portal(_widget(hud, "interact")["c"])
	_check(main.world.def.id == "village" and not player.choosing_loadout, "回程傳送門返回村莊")
	var arrival := Vector2(player.position.x, player.position.z)
	var arrival_distance := arrival.distance_to(gate)
	_check(arrival.x > gate.x and arrival_distance >= 1.0 and arrival_distance <= 1.6,
		"回村落在西門朝村內的安全處，實際距門 %.2f m" % arrival_distance)
	await create_timer(0.45).timeout
	_check(main.world.def.id == "village", "在回村落點等候不會連鎖觸發傳送")
	var home_road: Array[Vector2] = [Vector2(-24, 1.6), Vector2(-13, -1.6), Vector2(-2, -3), spawn]
	var reached_spawn := await _walk_road(player, move, home_road)
	_check(reached_spawn and _widget(hud, "interact").is_empty(), "回村後可從門內側一路步行回到出生點")
	player.queue.clear()
	await _tap(_widget(hud, "element", 2)["c"])
	await _tap_key(KEY_4)
	_check(player.queue.slots == [Elements.Type.EARTH, Elements.Type.ARCANE], "返回村莊後觸控第三格與鍵盤 4 都能加入換上的元素")

	print("%d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
