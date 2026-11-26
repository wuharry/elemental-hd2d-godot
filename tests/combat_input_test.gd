extends SceneTree
## 真正 main/HUD/工坊入口；涵蓋長按、取消、秘術書與獨立快捷綁定。

var passed := 0
var failed := 0
var cast_spells: Array[Dictionary] = []


func _init() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		printerr("FAIL: " + message)


func frames(count: int = 3) -> void:
	for i in count:
		await process_frame


func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func touch(index: int, position: Vector2, down: bool, cancel: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = root.get_final_transform() * position
	event.pressed = down
	event.canceled = cancel
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func widget(hud: Node, kind: String, slot: int = 0) -> Dictionary:
	for item: Dictionary in hud._widgets:
		if item.kind == kind and item.get("slot", 0) == slot:
			return item
	return {}


func _run() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await frames(6)
	var player: Player = main.player
	var hud: Node = main.hud
	player.spell_cast.connect(func(spell: Dictionary, _origin: Vector3, _direction: Vector3) -> void: cast_spells.append(spell))
	check(not main._persist_profile, "測試入口不讀寫正式存檔")
	check(is_equal_approx(player.shield_hold_seconds, 1.5), "預設長按1.5秒")
	key(KEY_1, true)
	await create_timer(0.15).timeout
	key(KEY_1, false)
	await frames()
	check(player.queue.slots == [Elements.Type.WATER], "鍵盤短按加入一格")
	key(KEY_2, true)
	await create_timer(1.62).timeout
	check(player.combat_state.shield_element == Elements.Type.FIRE, "鍵盤未放開已啟動火盾")
	var remaining := player.combat_state.shield_remaining
	await create_timer(0.2).timeout
	check(player.combat_state.shield_remaining < remaining, "持續按住不反覆刷新盾")
	key(KEY_2, false)
	await frames()
	check(player.queue.slots == [Elements.Type.WATER], "開盾與放開都保留原佇列")
	key(KEY_3, true)
	key(KEY_3, false)
	await frames()
	check(player.queue.slots == [Elements.Type.WATER, Elements.Type.LIGHTNING] and player.combat_state.shield_remaining > 0, "維持護盾可繼續組招")
	player.combat_state.reset()
	var fire := widget(hud, "element", 1)
	touch(8, fire.c, true)
	await create_timer(0.2).timeout
	touch(8, fire.c, false, true)
	await create_timer(1.5).timeout
	check(player.combat_state.shield_remaining == 0 and player.queue.slots.size() == 2, "取消觸控不開盾亦不加元素")
	key(KEY_1, true)
	main._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	key(KEY_1, false)
	await frames()
	check(player.queue.slots.size() == 2 and player._element_holds.is_empty(), "失去焦點取消鍵盤長按")
	main._open_workshop(true)
	await frames()
	check(paused and main.workshop.is_open() and not player.accept_keyboard, "設定開啟時暫停戰鬥並清理輸入")
	var slider: HSlider = main.workshop.find_child("ShieldHoldSeconds", true, false)
	slider.value = 2.3
	check(is_equal_approx(player.shield_hold_seconds, 2.3), "設定滑桿改變真正長按門檻")
	key(KEY_ESCAPE, true)
	key(KEY_ESCAPE, false)
	await frames()
	check(not paused and not main.workshop.is_open() and player.accept_keyboard, "Escape只關閉設定並恢復操作")
	main.switch_scene("forest")
	await frames(5)
	var altar: Vector2 = main.world.def.element_altars[Elements.Type.EARTH]
	player.position = Vector3(altar.x, 0, altar.y)
	await frames()
	key(KEY_3, true)
	player.position.z += 3.0
	await frames()
	player.position = Vector3(altar.x, 0, altar.y)
	await frames()
	key(KEY_3, false)
	await frames()
	check(player.loadout[2] == Elements.Type.LIGHTNING, "按住鍵盤離開祭壇再回來放開，不執行舊換裝")
	var point: Vector2 = main.world.def.interactions.rain_book
	player.position = Vector3(point.x, 0, point.y)
	await frames()
	key(KEY_E, true)
	key(KEY_E, false)
	await frames()
	check(player.knowledge.is_unlocked("rain"), "在真正書本互動點按E解鎖降雨")
	var recipe: Array[int] = [Elements.Type.MIST, Elements.Type.WATER, Elements.Type.WATER]
	check(player.knowledge.manual_spell(recipe).id == "rain", "學會後相同配方預設具名秘術")
	for i in SpellKnowledge.PROTOTYPE_MASTERY_USES:
		player.knowledge.record_use("rain")
	point = main.world.def.interactions.mage_workshop
	player.position = Vector3(point.x, 0, point.y)
	await frames()
	key(KEY_E, true)
	key(KEY_E, false)
	await frames()
	check(main.workshop.is_open(), "靠近實際工坊透過E開啟")
	var manual: OptionButton = main.workshop.find_child("ManualSpell", true, false)
	manual.select(0)
	manual.item_selected.emit(0)
	var quick: OptionButton = main.workshop.find_child("Shortcut0", true, false)
	var rain_index := -1
	for i in quick.item_count:
		var data: Dictionary = quick.get_item_metadata(i)
		if data.get("id") == "rain":
			rain_index = i
	check(rain_index >= 0, "工坊列出已學會降雨")
	if rain_index >= 0:
		quick.select(rain_index)
		quick.item_selected.emit(rain_index)
	check(player.knowledge.manual_spell(recipe).kind == "ordinary" and player.knowledge.shortcut_spell(0).id == "rain", "工坊能手動霧水水＋快捷降雨，互不覆蓋")
	main.workshop.close()
	await frames()
	player.queue.clear()
	player.queue.add(Elements.Type.FIRE)
	var q := widget(hud, "quick", 0)
	touch(9, q.c, true)
	touch(9, q.c, false)
	await frames()
	check(player.armed_shortcut == 0, "觸控快捷槽選取法術")
	var aim := widget(hud, "aim")
	var outer: Vector2 = aim.c + Vector2(aim.r * 0.9, 0)
	touch(9, outer, true)
	touch(9, outer, false, true)
	await frames()
	check(player.armed_shortcut == -1 and player.queue.slots == [Elements.Type.FIRE], "系統取消瞄準觸控會撤掉快捷選取，保留手動佇列")
	touch(9, q.c, true)
	touch(9, q.c, false)
	await frames()
	touch(9, outer, true)
	touch(9, outer, false)
	await frames()
	check(not cast_spells.is_empty() and cast_spells.back().id == "rain" and player.queue.slots == [Elements.Type.FIRE], "右搖桿施放快捷降雨，保留手動火元素")
	check(main.time_of_day.weather == "rain", "具名施放接到真實天氣")
	player.combat_state.health = 0
	player.combat_state.statuses["burning"] = 3.0
	main.switch_scene("village")
	await frames()
	check(player.combat_state.health == player.combat_state.max_health and not player.combat_state.has_status("burning"), "離開訓練場不會留下未完成死亡狀態鎖住探索（雨天仍可潮濕）")
	var path := "user://combat_profile_test_%d.json" % OS.get_process_id()
	check(MageProfile.save(player, path) == OK, "隔離存檔寫入成功")
	var restored := Player.new()
	check(MageProfile.restore(restored, path) and restored.knowledge.shortcut_spell(0).get("id") == "rain"
		and is_equal_approx(restored.shield_hold_seconds, 2.3), "實際JSON檔讀回熟練、綁定與長按設定")
	restored.free()
	var bad := FileAccess.open(path, FileAccess.WRITE)
	bad.store_string("{broken save}")
	bad.close()
	main._persist_profile = MageProfile.restore(player, path)
	main._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	main._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	check(not main._persist_profile and FileAccess.get_file_as_string(path) == "{broken save}", "拒絕的存檔不因失焦／退出被覆寫")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	main.free()
	await frames(2)
	print("Combat input: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)
