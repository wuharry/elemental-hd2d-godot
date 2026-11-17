extends SceneTree
## 四場景真實組裝回歸：啟動、切場、光影重設、必要素材與角色像素規格。
## 圖像風格、shader 畫面與效能仍須以 tools/capture.sh 開視窗驗收。

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


func _run() -> void:
	for name in ["snow", "ice", "flagstone", "brick"]:
		_check(ResourceLoader.exists("res://assets/textures/%s.png" % name), name + " texture exists")
		_check(ResourceLoader.exists("res://assets/textures/%s_n.png" % name), name + " normal exists")
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 3:
		await physics_frame
	var player: Player = main.get("player")
	_check(is_equal_approx(player.sprite.pixel_size, 1.0 / 32.0), "character uses 32px/m")
	_check(player.sprite.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST, "character nearest filter")
	_check(player.sprite.alpha_cut == SpriteBase3D.ALPHA_CUT_DISCARD, "character writes cutout depth")
	_check(player.sprite.shaded, "character receives scene lighting")
	var tod: TimeOfDay = main.get("time_of_day")
	tod.set_time("night", true)
	for id in ["forest", "snow", "dungeon", "village"]:
		player.queue.add(Elements.Type.FIRE)
		player.cast_queue(Vector3.RIGHT)
		main.call("switch_scene", id)
		var world: GameWorld = main.get("world")
		_check(world.def.id == id, id + " is active")
		_check(player.position.is_equal_approx(world.def.player_start), id + " starts at its spawn")
		_check(get_nodes_in_group("spell_previews").is_empty(), id + " clears previous spell previews")
		_check(tod.current == "night", id + " preserves selected time")
		var worlds := 0
		for child in main.get_children():
			if child is GameWorld:
				worlds += 1
		_check(worlds == 1, id + " frees the previous world")
		var stats: Dictionary = world.get_meta("mesh_batch_stats", {})
		_check(int(stats.get("sources", 0)) > int(stats.get("batches", 0)), id + " batches static geometry")
		for i in 2:
			await process_frame
	_check(tod.env.ambient_light_color.is_equal_approx(TimeOfDay.PRESETS["night"]["ambient_color"]), "village clears dungeon lighting override")
	_check(tod.sun.light_energy == TimeOfDay.PRESETS["night"]["sun_energy"], "village restores night sun")
	tod.set_time("day", true)
	var lights_off := true
	for light in get_nodes_in_group("warm_lights"):
		lights_off = lights_off and not light.visible and light.light_energy == 0.0
	_check(lights_off, "day disables zero-energy lamp shadow submissions")
	tod.set_time("dusk")
	tod._process(0.1)
	var lights_on := true
	for light in get_nodes_in_group("warm_lights"):
		lights_on = lights_on and light.visible and light.light_energy > 0.0
	_check(lights_on, "dusk transition immediately restores active lamps")
	main.free()
	print("%d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed else 0)
