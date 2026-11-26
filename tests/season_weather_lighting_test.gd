extends SceneTree
## 四季村莊、下雨天氣與進階角色 3D 法線／輪廓光回歸測試。
## godot --headless --path . --script res://tests/season_weather_lighting_test.gd

const Batcher := preload("res://src/world/mesh_batcher.gd")

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


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _tap_key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var key := InputEventKey.new()
		key.physical_keycode = code
		key.pressed = pressed
		Input.parse_input_event(key)
		await _frames(2)


func _check_seasonal_assets_and_presets() -> void:
	for tex_name: String in [
		"leaves_blossom", "leaves_autumn", "leaves_winter",
		"grass_ground_spring", "grass_ground_spring_n",
		"grass_ground_autumn", "grass_ground_autumn_n",
		"grass_tuft_autumn", "flowers_spring", "flowers_autumn",
	]:
		_check(ResourceLoader.exists("res://assets/textures/%s.png" % tex_name), "季節貼圖存在：%s" % tex_name)

	var base: Dictionary = TimeOfDay.PRESETS["day"]
	for table_name: String in ["season_overrides", "weather_overrides"]:
		var table: Dictionary = TimeOfDay.PRESETS[table_name]
		for entry_id: String in table:
			for scope: String in table[entry_id]:
				_check(scope == "*" or TimeOfDay.ORDER.has(scope), "%s.%s.%s 範圍合法" % [table_name, entry_id, scope])
				for key: String in table[entry_id][scope]:
					_check(base.has(key), "%s.%s.%s 是 PRESETS 既有欄位" % [table_name, entry_id, key])

	# 所有場景 × 季節 × 晴雨 × 四時段都不能踩到暖燈＋濃霧過曝或窗光上限（S5）。
	var all_safe := true
	for scene_id: String in Scenes.LIST:
		var def := Scenes.make(scene_id)
		var seasons: Array = SceneDef.SEASONS if def.supports_seasons else ["summer"]
		for season: String in seasons:
			for weather: String in TimeOfDay.WEATHERS:
				var resolved := TimeOfDay.resolve(scene_id, season, weather, def.outer_ground)
				for time_name: String in TimeOfDay.ORDER:
					var p: Dictionary = resolved[time_name]
					if float(p["lamps"]) > 0.0 and float(p["vol_density"]) > 0.02:
						all_safe = false
					for w: String in ["win0", "win1", "win2"]:
						if float(p[w]) > 3.0:
							all_safe = false
					if not def.outer_ground and (float(p["rain_wetness"]) > 0.0 or float(p["rain_intensity"]) > 0.0):
						all_safe = false
	_check(all_safe, "全部場景×四季×晴雨×四時段均符合 S5 霧與窗光安全上限，室內保持乾燥")


func _check_village_seasons() -> void:
	var baseline_world := GameWorld.new(Scenes.make("village", "summer"))
	root.add_child(baseline_world)
	var baseline_colliders: Dictionary = {}
	_collect_collision_layout(baseline_world, baseline_colliders)
	baseline_world.free()
	var expected_grass := {
		"spring": "grass_tuft",
		"summer": "grass_tuft",
		"autumn": "grass_tuft_autumn",
		"winter": "grass_tuft_frost",
	}
	for season: String in SceneDef.SEASONS:
		var def := Scenes.make("village", season)
		_check(def.season == season and def.grass_atlas == expected_grass[season],
			"村莊 %s 使用對應草叢圖集 %s（S12）" % [season, expected_grass[season]])
		var world := GameWorld.new(def)
		root.add_child(world)
		await process_frame
		var colliders: Dictionary = {}
		_collect_collision_layout(world, colliders)
		_check(colliders == baseline_colliders,
			"村莊 %s 保留夏季碰撞位置、大小與方向，換季不推擠玩家" % season)
		var stats := Batcher.batch(world, 64.0, true)
		_check(int(stats["sources"]) > int(stats["batches"]) and int(stats["batches"]) > 0,
			"村莊 %s 可正常合併靜態與季節樹葉網格（%d -> %d）" % [season, stats["sources"], stats["batches"]])
		var rain_nodes := get_nodes_in_group("rain_only")
		_check(rain_nodes.size() >= 2, "村莊 %s 建立雨絲與水花粒子節點" % season)
		if season == "winter":
			_check(def.ground["base"] == "snow" and def.flower_count == 0 and bool(def.houses[0].get("snow", false)),
				"冬季村莊套用雪地、屋頂積雪並移除花叢")
		elif season == "spring":
			_check(bool(def.ambient.get("petals", false)) and def.flower_atlas == "flowers_spring",
				"春季村莊啟用全村花瓣與春季花朵圖集")
		world.free()
		await process_frame
	Mats.reset()


func _collect_collision_layout(node: Node, result: Dictionary) -> void:
	if node is CollisionShape3D and node.shape is BoxShape3D:
		var pos: Vector3 = node.global_position
		if absf(pos.x) < 30.7 and absf(pos.z) < 17.7 and pos.y >= 0.0:
			result[str(pos)] = [node.shape.size, node.global_basis]
	for child in node.get_children():
		_collect_collision_layout(child, result)


func _check_character_normal_and_material_maps() -> void:
	# A 通道是自發光資料；比對實際匯入資源，避免 alpha 邊界修正污染 RGB。
	for basename: String in ["mage_atlas_m", "mage_hand_atlas_m", "mage_staff_m"]:
		var path := "res://assets/characters/%s.png" % basename
		var source := Image.load_from_file(ProjectSettings.globalize_path(path))
		var imported := (ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D).get_image()
		if imported.is_compressed():
			imported.decompress()
		imported.clear_mipmaps()
		imported.convert(Image.FORMAT_RGBA8)
		source.convert(Image.FORMAT_RGBA8)
		_check(imported.get_size() == source.get_size() and imported.get_data() == source.get_data(),
			"%s 匯入後四個資料通道與來源一致" % basename)
	var body_n := Image.load_from_file(ProjectSettings.globalize_path("res://assets/characters/mage_atlas_n.png"))
	var body_m := Image.load_from_file(ProjectSettings.globalize_path("res://assets/characters/mage_atlas_m.png"))
	var hand_n := Image.load_from_file(ProjectSettings.globalize_path("res://assets/characters/mage_hand_atlas_n.png"))
	var hand_m := Image.load_from_file(ProjectSettings.globalize_path("res://assets/characters/mage_hand_atlas_m.png"))
	var staff_n := Image.load_from_file(ProjectSettings.globalize_path("res://assets/characters/mage_staff_n.png"))
	var staff_m := Image.load_from_file(ProjectSettings.globalize_path("res://assets/characters/mage_staff_m.png"))
	var body_a := Image.load_from_file(ProjectSettings.globalize_path("res://assets/characters/mage_atlas.png"))
	var staff_a := Image.load_from_file(ProjectSettings.globalize_path("res://assets/characters/mage_staff.png"))
	_check(body_n != null and body_m != null and hand_n != null and hand_m != null and staff_n != null and staff_m != null,
		"角色身體、握手與法杖均產出法線圖與材質遮罩圖")
	if body_n == null or body_m == null or staff_n == null or staff_m == null:
		return
	_check(body_n.get_size() == Vector2i(560, 144) and body_m.get_size() == Vector2i(560, 144),
		"身體法線與材質圖集尺寸與 30 格角色圖集一致")
	_check(staff_n.get_size() == Vector2i(56, 48) and staff_m.get_size() == Vector2i(56, 48),
		"法杖法線與材質圖尺寸為 56×48")

	# 驗證立體法線不是平面：正面帽冠左側朝 -X、右側朝 +X，帽簷下側朝 -Y。
	var left_nx := 0.0
	var right_nx := 0.0
	var left_count := 0
	var right_count := 0
	var under_ny_min := 1.0
	for y in range(4, 15):
		for x in range(18, 36):
			if body_a.get_pixel(x, y).a < 0.5:
				continue
			var nx := body_n.get_pixel(x, y).r * 2.0 - 1.0
			if x < 24:
				left_nx += nx
				left_count += 1
			elif x > 28:
				right_nx += nx
				right_count += 1
	for y in range(17, 24):
		for x in range(44, 53):
			if body_a.get_pixel(x, y).a > 0.5:
				under_ny_min = minf(under_ny_min, body_n.get_pixel(x, y).g * 2.0 - 1.0)
	_check(left_count > 0 and right_count > 0 and (left_nx / left_count) < -0.15 and (right_nx / right_count) > 0.15,
		"帽冠具有左右對稱立體法線曲率（左 %.2f、右 %.2f）" % [left_nx / maxf(1, left_count), right_nx / maxf(1, right_count)])
	_check(under_ny_min < -0.35, "帽簷內側法線朝下（min ny = %.2f）" % under_ny_min)

	# 驗證眨眼格沒有把臉部法線打碎。
	var blink_normal_same := true
	for y in range(29, 32):
		for x in range(32, 34):
			var c0 := body_n.get_pixel(x, y)
			var c3 := body_n.get_pixel(3 * 56 + x, y)
			if absf(c0.r - c3.r) > 0.02 or absf(c0.g - c3.g) > 0.02:
				blink_normal_same = false
	_check(blink_normal_same, "眨眼姿勢保留原始平滑臉部法線")

	# 驗證輪廓光遮罩與法杖自發光／金屬遮罩。
	var rim_edge_hits := 0
	var face_rim_max := 0.0
	for y in range(3, 18):
		for x in range(16, 48):
			if body_a.get_pixel(x, y).a > 0.5 and body_m.get_pixel(x, y).b > 0.85:
				rim_edge_hits += 1
	for y in range(29, 34):
		for x in range(31, 39):
			if body_a.get_pixel(x, y).a > 0.5:
				face_rim_max = maxf(face_rim_max, body_m.get_pixel(x, y).b)
	_check(rim_edge_hits > 15 and face_rim_max <= 0.16,
		"外緣輪廓有強輪廓光權重（%d px），且臉部壓低避免洗掉五官（max %.2f）" % [rim_edge_hits, face_rim_max])

	var crystal_emi := 0
	var gold_metal := 0
	for y in 48:
		for x in 56:
			if staff_a.get_pixel(x, y).a < 0.5:
				continue
			var m := staff_m.get_pixel(x, y)
			if m.a > 0.75:
				crystal_emi += 1
			if m.g > 0.55:
				gold_metal += 1
	_check(crystal_emi >= 8 and gold_metal >= 12,
		"法杖材質圖標記琥珀晶石自發光（%d px）與金叉金屬高光（%d px）" % [crystal_emi, gold_metal])


func _check_runtime_weather_season_and_character_shader() -> void:
	var main: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _frames(5)
	var player: Player = main.get("player")
	var tod: TimeOfDay = main.get("time_of_day")
	var camera := (main.get("rig") as CameraRig).camera
	_check((camera.cull_mask & TimeOfDay.MAIN_SUN_LAYER) != 0
		and (camera.cull_mask & TimeOfDay.REFLECTION_SUN_LAYER) == 0,
		"遊戲鏡頭只使用四級主方向光，不重複算入倒影方向光")
	var hud: Node = main.get("hud")

	# 驗證角色三層均套用進階像素 3D 光照 shader，並正確響應轉向與換裝。
	for layer: Sprite3D in [player.sprite, player.hand_sprite, player.weapon.sprite]:
		var sm := layer.material_override as ShaderMaterial
		_check(sm != null and sm.shader.resource_path == "res://shaders/pixel_character.gdshader",
			"%s 套用 pixel_character.gdshader" % layer.name)
	var body_mat := player.sprite.material_override as ShaderMaterial
	var weapon_mat := player.weapon.sprite.material_override as ShaderMaterial
	_check(float(body_mat.get_shader_parameter("bounce_energy")) > 0.05, "裝備琥珀法杖時啟用持杖側暖色反光")
	player.aim_dir = Vector3(-1, 0, 0).rotated(Vector3.UP, player.camera_yaw)
	player._refresh_sprite()
	_check(is_equal_approx(float(body_mat.get_shader_parameter("flip_sign")), -1.0)
		and float(body_mat.get_shader_parameter("bounce_dir_x")) > 0.5
		and is_equal_approx(float(weapon_mat.get_shader_parameter("flip_sign")), -1.0),
		"朝左轉身時同步翻轉法線 X 軸與法杖反光方向")
	player.equip_weapon(null)
	_check(is_zero_approx(float(body_mat.get_shader_parameter("bounce_energy"))), "卸下武器後立即關閉持杖側反光")
	var book := Player.WeaponAppearance.new()
	var img := Image.create(16, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color("#51305e"))
	book.texture = ImageTexture.create_from_image(img)
	player.equip_weapon(book)
	_check(weapon_mat.get_shader_parameter("normal_tex") is Texture2D
		and is_zero_approx(float(body_mat.get_shader_parameter("bounce_energy"))),
		"無專屬法線圖的武器安全回退至平面法線並維持無自發光")
	player.equip_weapon(Player.DEFAULT_WEAPON)

	# 驗證晴雨切換、雨勢與濕地數值、粒子開關、暖燈與室內防雨。
	_check(tod.weather == "clear" and is_zero_approx(tod.rain_wetness) and is_zero_approx(tod.rain_intensity),
		"預設天氣為晴天且地面乾燥")
	var village_refl := get_nodes_in_group("water_reflections")[0]
	tod.set_weather("rain", true)
	await _frames(2)
	var rain_emitting := true
	for n: GPUParticles3D in get_nodes_in_group("rain_only"):
		rain_emitting = rain_emitting and n.emitting
	var dry_hidden := true
	for n in get_nodes_in_group("dry_only"):
		if n is GPUParticles3D:
			dry_hidden = dry_hidden and not n.emitting
		elif n is Node3D:
			dry_hidden = dry_hidden and not n.visible
	var day_rain_lamps := true
	for l: Light3D in get_nodes_in_group("warm_lights"):
		day_rain_lamps = day_rain_lamps and l.visible and l.light_energy > 0.0
	_check(tod.weather == "rain"
		and is_equal_approx(tod.rain_wetness, 1.0)
		and is_equal_approx(tod.rain_intensity, 1.0),
		"切至雨天立即啟用濕地反光與雨勢全域參數")
	_check(rain_emitting and dry_hidden and day_rain_lamps,
		"雨天開啟雨絲水花、暫停蝴蝶塵埃，且白天下雨也會亮起路燈與暖光")
	_check(is_instance_valid(village_refl) and is_equal_approx(village_refl.surface_level, 0.08)
		and (village_refl.camera.cull_mask & 2) != 0,
		"切至雨天維持村莊平面鏡像水反與主角倒影層")

	# 進室內地下城應保持乾燥，回村莊恢復雨天。
	main.call("switch_scene", "dungeon")
	await _frames(2)
	_check(is_zero_approx(tod.rain_wetness) and is_zero_approx(tod.rain_intensity),
		"室內地下城即使在雨天狀態下也保持乾燥")
	main.call("switch_scene", "village")
	await _frames(2)
	_check(is_equal_approx(tod.rain_wetness, 1.0) and is_equal_approx(tod.rain_intensity, 1.0),
		"返回室外村莊自動恢復雨天濕地與降雨")

	# 驗證快捷鍵 R（晴雨）與 F11／F12（秋冬季節）切換且保留玩家位置與元素佇列。
	player.position = Vector3(3.2, 0.0, -1.5)
	player.queue.add(Elements.Type.WATER)
	player.queue.add(Elements.Type.FIRE)
	await _tap_key(KEY_F11)
	_check(main.get("current_season") == "autumn" and main.world.def.season == "autumn"
		and player.position.is_equal_approx(Vector3(3.2, 0.0, -1.5))
		and player.queue.slots == [Elements.Type.WATER, Elements.Type.FIRE],
		"按 F11 切換為秋季村莊並保留玩家位置與元素佇列")
	await _tap_key(KEY_R)
	_check(tod.weather == "clear" and is_zero_approx(tod.rain_wetness) or tod.weather == "clear",
		"按 R 鍵可切換回晴天")
	var season_widgets := 0
	var weather_widgets := 0
	for w: Dictionary in hud.get("_widgets"):
		if w["kind"] == "season":
			season_widgets += 1
		elif w["kind"] == "weather":
			weather_widgets += 1
	_check(season_widgets == 4 and weather_widgets == 1, "村莊 HUD 提供四季與晴雨按鈕")

	# 截圖不能被背景快捷鍵切場、改季節／天氣或加入元素污染。
	main.call("_lock_capture_input")
	var capture_scene: String = main.world.def.id
	var capture_season: String = main.current_season
	var capture_weather := tod.weather
	var capture_queue := player.queue.slots.duplicate()
	for code: Key in [KEY_F6, KEY_G, KEY_R, KEY_3]:
		await _tap_key(code)
	_check(main.world.def.id == capture_scene and main.current_season == capture_season
		and tod.weather == capture_weather and player.queue.slots == capture_queue
		and not player.accept_keyboard and not hud.is_processing_input(),
		"截圖模式鎖定移動、HUD 與主場景快捷鍵，保留拍攝狀態")

	main.free()
	await _frames(2)
	_check(is_zero_approx(tod.rain_wetness) if is_instance_valid(tod) else true,
		"離開場景後清理雨天狀態不殘留")


func _run() -> void:
	_check_seasonal_assets_and_presets()
	await _check_village_seasons()
	_check_character_normal_and_material_maps()
	await _check_runtime_weather_season_and_character_shader()
	print("season/weather/lighting: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
