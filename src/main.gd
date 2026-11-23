extends Node3D
## 組裝根：把世界、光影、角色、鏡頭、HUD 接起來。這裡不放玩法或美術細節。
## 啟動參數（寫在 -- 後面）：
##   --capture   依序拍四個時段到 test_output/，拍完自動關閉
##   --nohud     不顯示 HUD（拍乾淨的場景圖用）
##   --time=dusk 指定開場時段（morning／day／dusk／night）
##   --pos=x,z   指定角色起點（檢查村莊其他角落用）
##   --shots=day,night  搭配 --capture，只拍指定時段；檔名加上 --tag=名稱 區分
##   --scene=forest  場景：village／forest／snow／dungeon；F5–F8 也能切換

const CAPTURE_WARMUP_FRAMES := 150
const CAPTURE_SAMPLE_FRAMES := 120
const CAPTURE_SETTLE_FRAMES := 70
const INTERACTION_RADIUS := 1.85
const GATE_CHARGE_SECONDS := 0.24

var world: GameWorld
var time_of_day: TimeOfDay
var player: Player
var rig: CameraRig
var hud: Node
var _options: Dictionary
var _nearby_action := ""
var _gate_charging := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_options = _read_options(args)
	if _options.is_empty():
		get_tree().quit(2)
		return

	var preview_altar := args.has("--capture") and args.has("--loadout-menu")
	var def := Scenes.make("forest" if preview_altar else _options["scene"])
	world = GameWorld.new(def)
	add_child(world)
	_batch_world()

	time_of_day = TimeOfDay.new()
	add_child(time_of_day)

	player = Player.new()
	player.position = def.player_start
	add_child(player)
	player.cast.connect(_on_cast)

	rig = CameraRig.new()
	rig.target = player
	rig.reveal_foliage = not args.has("--no-reveal")
	add_child(rig)
	player.camera_yaw = rig.yaw()
	player.camera_pitch_deg = rig.pitch_deg
	player.aim_dir = Vector3.BACK.rotated(Vector3.UP, player.camera_yaw)

	if not args.has("--nohud") and ResourceLoader.exists("res://src/ui/hud.gd"):
		hud = (load("res://src/ui/hud.gd") as Script).new()
		add_child(hud)
		hud.call("setup", player, rig, time_of_day)
		hud.interaction_requested.connect(interact)

	if preview_altar:
		_place_at_interaction("equip")
	elif _options.has("pos"):
		player.position = _options["pos"]
		rig.global_position = player.position + rig.look_offset
	_update_interaction()
	time_of_day.apply_scene(def)
	time_of_day.set_time(_options["time"], true)
	DisplayServer.window_set_title("elemental-hd2d-godot — " + def.title)

	if args.has("--capture"):
		_capture_all.call_deferred()


func _process(_delta: float) -> void:
	if is_instance_valid(player) and is_instance_valid(rig):
		player.camera_yaw = rig.yaw()
		player.camera_pitch_deg = rig.pitch_deg
		_update_interaction()


func _nearest_interaction() -> String:
	var at := Vector2(player.position.x, player.position.z)
	var nearest := ""
	var distance_limit := INTERACTION_RADIUS * INTERACTION_RADIUS
	for action: String in world.def.interactions:
		var distance := at.distance_squared_to(world.def.interactions[action])
		if distance <= distance_limit:
			nearest = action
			distance_limit = distance
	return nearest


func _update_interaction() -> void:
	var action := _nearest_interaction()
	if action != _nearby_action:
		_nearby_action = action
		if hud:
			hud.set_interaction(action)


func interact() -> void:
	if player.choosing_loadout or _gate_charging:
		return
	# 另一根手指可能仍在推搖桿；放開互動鍵時再核對位置。
	if _nearest_interaction() != _nearby_action:
		_update_interaction()
		return
	match _nearby_action:
		"to_altar", "to_village":
			_travel_through_gate(_nearby_action)
		"equip":
			if hud:
				hud.open_loadout()


func _travel_through_gate(action: String) -> void:
	_gate_charging = true
	get_tree().call_group("waygate_fx", "pulse")
	await get_tree().create_timer(GATE_CHARGE_SECONDS).timeout
	if action == "to_altar":
		switch_scene("forest")
		_place_at_interaction("equip")
	else:
		switch_scene("village")
		_place_at_interaction("to_altar", 1.3)
	_update_interaction()
	get_tree().call_group("waygate_fx", "pulse")
	_gate_charging = false


func _place_at_interaction(action: String, toward_spawn: float = 0.0) -> void:
	var point: Vector2 = world.def.interactions[action]
	var spawn := Vector2(world.def.player_start.x, world.def.player_start.z)
	point += point.direction_to(spawn) * toward_spawn
	player.position = Vector3(point.x, world.def.player_start.y, point.y)
	rig.global_position = player.position + rig.look_offset


func switch_scene(id: String) -> void:
	if not Scenes.LIST.has(id) or world.def.id == id:
		return
	for bolt in get_tree().get_nodes_in_group("spell_previews"):
		bolt.free()
	world.free()
	var def := Scenes.make(id)
	world = GameWorld.new(def)
	add_child(world)
	_batch_world()
	player.position = def.player_start
	player.velocity = Vector3.ZERO
	rig.global_position = player.position + rig.look_offset
	time_of_day.apply_scene(def)
	_update_interaction()
	DisplayServer.window_set_title("elemental-hd2d-godot — " + def.title)


func _batch_world() -> void:
	if OS.get_cmdline_user_args().has("--no-batching"):
		return
	var counts := MeshBatcher.batch(world, 64.0, true)
	print("mesh batching: %d primitives -> %d batches" % [counts["sources"], counts["batches"]])


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or player.choosing_loadout or _gate_charging:
		return
	match key.physical_keycode:
		KEY_F1: time_of_day.set_time("morning")
		KEY_F2: time_of_day.set_time("day")
		KEY_F3: time_of_day.set_time("dusk")
		KEY_F4: time_of_day.set_time("night")
		KEY_F5: switch_scene("village")
		KEY_F6: switch_scene("forest")
		KEY_F7: switch_scene("snow")
		KEY_F8: switch_scene("dungeon")
		KEY_T: time_of_day.next_time()
		KEY_E: interact()
		KEY_1: player.queue.add(player.loadout[0])
		KEY_2: player.queue.add(player.loadout[1])
		KEY_3: player.queue.add(player.loadout[2])
		KEY_4: player.queue.add(player.loadout[3])
		KEY_F: player.queue.fuse_last_two()
		KEY_SPACE: player.cast_queue(player.aim_dir)
		KEY_ESCAPE: get_tree().quit()


func _on_cast(elements: Array[int], origin: Vector3, direction: Vector3) -> void:
	if not ResourceLoader.exists("res://src/combat/spell_bolt.gd"):
		return
	var bolt := Node3D.new()
	bolt.add_to_group("spell_previews")
	bolt.set_script(load("res://src/combat/spell_bolt.gd"))
	add_child(bolt)
	bolt.call("launch", elements, origin, direction)


func _read_options(args: PackedStringArray) -> Dictionary:
	var options := {"scene": "village", "time": "day", "shots": TimeOfDay.ORDER.duplicate(), "tag": ""}
	var safe_tag := RegEx.new()
	safe_tag.compile("^[A-Za-z0-9_-]+$")
	for arg in args:
		if arg in ["--capture", "--nohud", "--no-batching", "--no-reveal", "--loadout-menu"]:
			continue
		var pair := arg.split("=", true, 1)
		if pair.size() != 2:
			push_error("Unknown option: " + arg)
			return {}
		var value := pair[1]
		match pair[0]:
			"--scene":
				if not Scenes.LIST.has(value):
					push_error("Unknown scene: " + value)
					return {}
				options["scene"] = value
			"--time", "--shots":
				var names := value.split(",") if pair[0] == "--shots" else PackedStringArray([value])
				for time_name in names:
					if not TimeOfDay.ORDER.has(time_name):
						push_error("Unknown time: " + time_name)
						return {}
				options["shots" if pair[0] == "--shots" else "time"] = Array(names) if pair[0] == "--shots" else value
			"--tag":
				if safe_tag.search(value) == null:
					push_error("Capture tag must contain only letters, numbers, underscores or hyphens")
					return {}
				options["tag"] = value
			"--pos":
				var coords := value.split(",")
				if coords.size() != 2 or not coords[0].is_valid_float() or not coords[1].is_valid_float():
					push_error("Position must be --pos=x,z")
					return {}
				var pos := Vector3(float(coords[0]), 0.0, float(coords[1]))
				if not pos.is_finite():
					push_error("Position must be finite")
					return {}
				options["pos"] = pos
			_:
				push_error("Unknown option: " + arg)
				return {}
	return options


func _save_capture(path: String) -> bool:
	# macOS 視窗被遮住時不一定送出 frame_post_draw；主動畫一幀再讀回，避免永遠等待。
	RenderingServer.force_sync()
	RenderingServer.force_draw(false)
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty() or img.save_png(path) != OK:
		push_error("Could not save capture: " + path)
		get_tree().quit(1)
		return false
	print("captured ", path)
	print("rendered draw calls: ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	return true


## 視覺驗收用：四個時段各拍一張。必須開視窗跑，--headless 沒有畫面。
func _capture_all() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Capture requires a rendered window; remove --headless")
		get_tree().quit(2)
		return
	var dir := ProjectSettings.globalize_path("res://test_output")
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		push_error("Could not create capture directory: " + dir)
		get_tree().quit(1)
		return
	var t0 := Time.get_ticks_msec()
	for i in CAPTURE_WARMUP_FRAMES:
		await get_tree().process_frame
	var ms := float(Time.get_ticks_msec() - t0) / CAPTURE_WARMUP_FRAMES
	print("warmup: %.1f ms/process frame, draw calls %d, objects %d" % [ms,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)])
	# 暖機之後另量固定幀數，避免把首次 shader 編譯當成穩態效能。
	t0 = Time.get_ticks_usec()
	var total_draw_calls := 0
	for i in CAPTURE_SAMPLE_FRAMES:
		await get_tree().process_frame
		total_draw_calls += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	ms = float(Time.get_ticks_usec() - t0) / (CAPTURE_SAMPLE_FRAMES * 1000.0)
	print("steady process cadence: %.1f ms/frame, observed draw calls %.0f (%d frames; not a GPU FPS benchmark)" % [
		ms, float(total_draw_calls) / CAPTURE_SAMPLE_FRAMES, CAPTURE_SAMPLE_FRAMES])
	var shots: Array = _options["shots"]
	var tag: String = "_" + _options["tag"] if not _options["tag"].is_empty() else ""
	var show_loadout := hud != null and OS.get_cmdline_user_args().has("--loadout-menu")
	if show_loadout:
		interact()
		if not player.choosing_loadout:
			push_error("Loadout capture could not open the elemental altar")
			get_tree().quit(1)
			return
	for time_name in shots:
		time_of_day.set_time(time_name, true)
		for i in CAPTURE_SETTLE_FRAMES:
			await get_tree().process_frame
		var path := "%s/shot_%s%s.png" % [dir, time_name, tag]
		if not _save_capture(path):
			return
	if show_loadout:
		hud.close_loadout()
	if not tag.is_empty():
		get_tree().quit()
		return
	# 用實際佇列拍滿四元素的村景，方便在遊戲尺寸核對按鍵與環繞光點。
	time_of_day.set_time("day", true)
	for element in player.loadout:
		player.queue.add(element)
	for i in CAPTURE_SETTLE_FRAMES:
		await get_tree().process_frame
	if not _save_capture("%s/shot_day_elements.png" % dir):
		return
	player.queue.clear()
	# 最後多拍一張「夜晚施法中」：確認排元素 → 融合 → 施放這條路走得通，也看法術光照在場景上的樣子
	time_of_day.set_time("night", true)
	for i in CAPTURE_SETTLE_FRAMES:
		await get_tree().process_frame
	player.queue.add(Elements.Type.WATER)
	player.queue.add(Elements.Type.FIRE)
	player.queue.fuse_last_two()
	player.queue.add(Elements.Type.LIGHTNING)
	player.cast_queue(Vector3(1, 0, 0.25))
	player.queue.add(Elements.Type.FIRE)
	player.queue.add(Elements.Type.FIRE)
	player.queue.add(Elements.Type.LIGHTNING)
	for i in 22:
		await get_tree().process_frame
	if not _save_capture("%s/shot_night_cast.png" % dir):
		return
	get_tree().quit()
