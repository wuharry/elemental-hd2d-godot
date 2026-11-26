extends Node3D
## 組裝根：把世界、光影、角色、鏡頭、HUD 接起來。這裡不放玩法或美術細節。
## 啟動參數（寫在 -- 後面）：
##   --capture   依序拍四個時段到 test_output/，拍完自動關閉
##   --nohud     不顯示 HUD（拍乾淨的場景圖用）
##   --time=dusk 指定開場時段（morning／day／dusk／night）
##   --pos=x,z   指定角色起點（檢查村莊其他角落用）
##   --shots=day,night  搭配 --capture，只拍指定時段；檔名加上 --tag=名稱 區分
##   --scene=forest  場景：village／forest／snow／dungeon；F5–F8 也能切換
##   --season=autumn 村莊季節：spring／summer／autumn／winter；G 循環、F9–F12 直切
##   --weather=rain  天氣：clear／rain；R 切換晴雨
##   --altar-preview  搭配 --capture，拍攝靠近土祭壇時的提示

const CAPTURE_WARMUP_FRAMES := 150
const CAPTURE_SAMPLE_FRAMES := 120
const CAPTURE_SETTLE_FRAMES := 70
const CAPTURE_RENDER_SETTLE_FRAMES := 48
const INTERACTION_RADIUS := 1.85
const ALTAR_RADIUS := 1.25
const GATE_CHARGE_SECONDS := 0.24

var world: GameWorld
var time_of_day: TimeOfDay
var player: Player
var rig: CameraRig
var hud: Node
var _options: Dictionary
var _nearby_action := ""
var _gate_charging := false
var current_season := "summer"
var spell_runtime: Node3D
var workshop: CanvasLayer
var _keyboard_holds: Dictionary = {}
var _input_altar := -1
var _save_timer: Timer
var _persist_profile := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_options = _read_options(args)
	if _options.is_empty():
		get_tree().quit(2)
		return

	var preview_altar: bool = args.has("--capture") and _options.has("altar_preview")
	current_season = _options["season"]
	var def := Scenes.make("forest" if preview_altar else _options["scene"], current_season)
	world = GameWorld.new(def)
	add_child(world)
	_batch_world()

	time_of_day = TimeOfDay.new()
	add_child(time_of_day)

	player = Player.new()
	player.position = def.player_start
	add_child(player)
	player.spell_cast.connect(_on_spell_cast)
	_persist_profile = not args.has("--capture") and not OS.get_cmdline_args().has("--script")
	if _persist_profile:
		_persist_profile = MageProfile.restore(player)
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.6
	_save_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_save_timer)
	_save_timer.timeout.connect(_save_profile)
	player.knowledge.changed.connect(_schedule_save)

	rig = CameraRig.new()
	rig.target = player
	rig.reveal_foliage = not args.has("--no-reveal")
	add_child(rig)
	rig.camera.cull_mask &= ~TimeOfDay.REFLECTION_SUN_LAYER
	player.camera_yaw = rig.yaw()
	player.camera_pitch_deg = rig.pitch_deg
	player.aim_dir = Vector3.BACK.rotated(Vector3.UP, player.camera_yaw)

	if not args.has("--nohud") and ResourceLoader.exists("res://src/ui/hud.gd"):
		hud = (load("res://src/ui/hud.gd") as Script).new()
		add_child(hud)
		hud.call("setup", player, rig, time_of_day)
		hud.interaction_requested.connect(interact)
		hud.element_replacement_requested.connect(_replace_at_altar)
		hud.season_requested.connect(set_season)
		hud.weather_toggled.connect(toggle_weather)
		hud.settings_requested.connect(_open_workshop.bind(true))
		if not _persist_profile and not args.has("--capture") and not OS.get_cmdline_args().has("--script"):
			player.notice.emit("存檔無法讀取，已保留原檔；本次不覆寫")

	workshop = preload("res://src/ui/mage_workshop.gd").new()
	add_child(workshop)
	workshop.settings_changed.connect(_schedule_save)
	workshop.closed.connect(_close_workshop)

	if preview_altar:
		_place_player(def.element_altars[Elements.Type.EARTH])
	elif _options.has("pos"):
		player.position = _options["pos"]
		rig.global_position = player.position + rig.look_offset
	_update_interaction()
	time_of_day.apply_scene(def)
	time_of_day.set_weather(_options["weather"], true)
	time_of_day.set_time(_options["time"], true)
	time_of_day.weather_changed.connect(_on_weather_changed)
	_setup_combat()
	_sync_hud_environment()
	_update_window_title()

	if args.has("--capture"):
		_lock_capture_input()
		_capture_all.call_deferred()


func _lock_capture_input() -> void:
	set_process_unhandled_key_input(false)
	player.accept_keyboard = false
	if hud != null:
		hud.set_process_input(false)


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
	_nearby_action = _nearest_interaction()
	var altar := _nearest_altar()
	if altar != _input_altar:
		_input_altar = altar
		_keyboard_holds.clear()
		player.cancel_element_holds()
	if hud:
		hud.set_interaction(_nearby_action, altar)


func _nearest_altar() -> int:
	var at := Vector2(player.position.x, player.position.z)
	var nearest := -1
	var distance_limit := ALTAR_RADIUS * ALTAR_RADIUS
	for element: int in world.def.element_altars:
		var distance := at.distance_squared_to(world.def.element_altars[element])
		if distance <= distance_limit:
			nearest = element
			distance_limit = distance
	return nearest


func _replace_at_altar(slot: int, element: int) -> void:
	# 放開按鍵時再確認位置，避免邊走邊按時換成已離開的祭壇元素。
	if not _gate_charging and _nearest_altar() == element:
		player.replace_element(slot, element)


func interact() -> void:
	if _gate_charging:
		return
	# 另一根手指可能仍在推搖桿；放開互動鍵時再核對位置。
	if _nearest_interaction() != _nearby_action:
		_update_interaction()
		return
	match _nearby_action:
		"to_altar", "to_village":
			_travel_through_gate(_nearby_action)
		"mage_workshop":
			_open_workshop()
		"rain_book":
			if player.knowledge.unlock_named("rain"):
				player.notice.emit("學會降雨 · [霧][水][水] · 工坊可切換普通施法")
			else:
				player.notice.emit("降雨已學會 · 水＋冰融合成霧，再加入水、水")
			spell_runtime.refresh_book()
		"training_turret":
			spell_runtime.toggle_turret()


func _travel_through_gate(action: String) -> void:
	_gate_charging = true
	get_tree().call_group("waygate_fx", "pulse")
	await get_tree().create_timer(GATE_CHARGE_SECONDS).timeout
	if action == "to_altar":
		switch_scene("forest")
		_place_player(world.def.element_altars[Elements.Type.EARTH])
	else:
		switch_scene("village")
		_place_at_interaction("to_altar", 1.3)
	_update_interaction()
	get_tree().call_group("waygate_fx", "pulse")
	_gate_charging = false


func _place_at_interaction(action: String, toward_spawn: float = 0.0) -> void:
	var point: Vector2 = world.def.interactions[action]
	var spawn := Vector2(world.def.player_start.x, world.def.player_start.z)
	_place_player(point + point.direction_to(spawn) * toward_spawn)


func _place_player(point: Vector2) -> void:
	player.position = Vector3(point.x, world.def.player_start.y, point.y)
	rig.global_position = player.position + rig.look_offset


func switch_scene(id: String) -> void:
	if not Scenes.LIST.has(id) or world.def.id == id:
		return
	_cancel_input()
	for bolt in get_tree().get_nodes_in_group("spell_previews"):
		bolt.free()
	world.free()
	var def := Scenes.make(id, current_season)
	world = GameWorld.new(def)
	add_child(world)
	_batch_world()
	player.position = def.player_start
	player.velocity = Vector3.ZERO
	rig.global_position = player.position + rig.look_offset
	time_of_day.apply_scene(def)
	_setup_combat()
	_update_interaction()
	_sync_hud_environment()
	_update_window_title()


func set_season(season_name: String) -> void:
	if not SceneDef.SEASONS.has(season_name) or season_name == current_season:
		return
	current_season = season_name
	if world.def.supports_seasons:
		_cancel_input()
		var scene_id := world.def.id
		var saved_pos := player.position
		var saved_aim := player.aim_dir
		world.free()
		var def := Scenes.make(scene_id, current_season)
		world = GameWorld.new(def)
		add_child(world)
		_batch_world()
		player.position = saved_pos
		player.aim_dir = saved_aim
		player.velocity = Vector3.ZERO
		rig.global_position = player.position + rig.look_offset
		time_of_day.apply_scene(def)
		_setup_combat()
		_update_interaction()
	_sync_hud_environment()
	_update_window_title()


func next_season() -> void:
	set_season(SceneDef.SEASONS[(SceneDef.SEASONS.find(current_season) + 1) % SceneDef.SEASONS.size()])


func toggle_weather() -> void:
	time_of_day.toggle_weather()
	_sync_hud_environment()
	_update_window_title()


func _sync_hud_environment() -> void:
	if hud != null:
		hud.call("set_environment_state", world.def.supports_seasons, current_season, world.def.outer_ground)


func _update_window_title() -> void:
	var suffix := world.def.title
	if world.def.supports_seasons:
		suffix += " · " + SceneDef.SEASON_LABELS[current_season]
	if world.def.outer_ground and time_of_day.weather == "rain":
		suffix += " · 雨"
	DisplayServer.window_set_title("elemental-hd2d-godot — " + suffix)


func _batch_world() -> void:
	if OS.get_cmdline_user_args().has("--no-batching"):
		return
	var counts := MeshBatcher.batch(world, 64.0, true)
	print("mesh batching: %d primitives -> %d batches" % [counts["sources"], counts["batches"]])


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or key.echo or _gate_charging:
		return
	if key.physical_keycode in [KEY_1, KEY_2, KEY_3, KEY_4]:
		var slot := int(key.physical_keycode - KEY_1)
		var source := "key_%d" % slot
		if key.pressed:
			if not _keyboard_holds.has(source):
				_keyboard_holds[source] = _nearest_altar()
				if _keyboard_holds[source] < 0:
					player.begin_element_hold(source, slot)
		else:
			if _keyboard_holds.has(source):
				var altar: int = _keyboard_holds[source]
				_keyboard_holds.erase(source)
				if altar >= 0 and _nearest_altar() == altar:
					_replace_at_altar(slot, altar)
				else:
					player.finish_element_hold(source, _nearest_altar() >= 0)
		return
	if not key.pressed:
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
		KEY_F9: set_season("spring")
		KEY_F10: set_season("summer")
		KEY_F11: set_season("autumn")
		KEY_F12: set_season("winter")
		KEY_T: time_of_day.next_time()
		KEY_G: next_season()
		KEY_R: toggle_weather()
		KEY_E: interact()
		KEY_Z: player.arm_shortcut(0)
		KEY_X: player.arm_shortcut(1)
		KEY_C: player.arm_shortcut(2)
		KEY_F: player.queue.fuse_last_two()
		KEY_SPACE: player.cast_queue(player.aim_dir)
		KEY_ESCAPE:
			_save_profile()
			get_tree().quit()


func _on_spell_cast(spell: Dictionary, origin: Vector3, direction: Vector3) -> void:
	spell_runtime.cast_spell(spell, origin, direction)


func _setup_combat() -> void:
	var training := not world.def.training_targets.is_empty()
	# 原型只有訓練傷害；離開訓練場恢復，避免未定案死亡流程鎖住探索。
	if player.training_mode and not training:
		player.combat_state.reset()
	player.training_mode = training
	spell_runtime = preload("res://src/world/spell_runtime.gd").new()
	world.add_child(spell_runtime)
	spell_runtime.setup(player, time_of_day, player.knowledge)
	spell_runtime.feedback.connect(player.notice.emit)


func _open_workshop(settings_only: bool = false) -> void:
	_cancel_input()
	if hud != null:
		hud.set_process_input(false)
	workshop.open(player, settings_only)


func _close_workshop() -> void:
	if hud != null:
		hud.set_process_input(true)
	_save_profile()


func _cancel_input() -> void:
	_keyboard_holds.clear()
	player.cancel_element_holds()
	player.move_input = Vector2.ZERO
	player.aim_input = Vector2.ZERO
	player.cancel_cast_selection()
	if hud != null:
		hud.cancel_input()


func _on_weather_changed(_weather: String) -> void:
	_sync_hud_environment()
	_update_window_title()


func _schedule_save() -> void:
	if _persist_profile:
		_save_timer.start()


func _save_profile() -> void:
	if _persist_profile and MageProfile.save(player) != OK:
		player.notice.emit("設定儲存失敗；本次遊戲仍可繼續使用")


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(player):
		_cancel_input()
		_save_profile()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST and is_instance_valid(player):
		_save_profile()


func _read_options(args: PackedStringArray) -> Dictionary:
	var options := {"scene": "village", "season": "summer", "weather": "clear", "time": "day", "shots": TimeOfDay.ORDER.duplicate(), "tag": ""}
	var safe_tag := RegEx.new()
	safe_tag.compile("^[A-Za-z0-9_-]+$")
	for arg in args:
		if arg in ["--altar-preview", "--loadout-menu"]:
			options["altar_preview"] = true
			continue
		if arg in ["--capture", "--nohud", "--no-batching", "--no-reveal"]:
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
			"--season":
				if not SceneDef.SEASONS.has(value):
					push_error("Unknown season: " + value)
					return {}
				options["season"] = value
			"--weather":
				if not TimeOfDay.WEATHERS.has(value):
					push_error("Unknown weather: " + value)
					return {}
				options["weather"] = value
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
	# 被遮住的 macOS 視窗仍跑 process，但不一定繪圖。主動完成反射六面與霧的歷史幀再讀回。
	for i in CAPTURE_RENDER_SETTLE_FRAMES:
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
	if _options.has("altar_preview") and _nearest_altar() != Elements.Type.EARTH:
		push_error("Altar capture did not reach the earth altar")
		get_tree().quit(1)
		return
	for time_name in shots:
		time_of_day.set_time(time_name, true)
		for i in CAPTURE_SETTLE_FRAMES:
			await get_tree().process_frame
		var path := "%s/shot_%s%s.png" % [dir, time_name, tag]
		if not _save_capture(path):
			return
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
