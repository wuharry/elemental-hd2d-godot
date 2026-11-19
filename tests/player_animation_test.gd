extends SceneTree
## 圖集及真實 CharacterBody3D 移動回歸；不以數學測試取代畫面驗收。
## godot --headless --path . --script res://tests/player_animation_test.gd

const MageArt := preload("res://tools/gen_character.gd")

## 上一版圖集實際用到的 21 色；透明另計。
const APPROVED_COLORS := [
	"#211d29", "#231b2b", "#312137", "#352041", "#352d38", "#504452", "#51305e", "#571c3b",
	"#57313c", "#593241", "#734485", "#8a2947", "#8f5144", "#bc3f53", "#c8844e",
	"#db977f", "#ed812b", "#f4be6b", "#f5bca3", "#ffe2c6", "#fff2b7",
]
const SKIN := [Color("#db977f"), Color("#f5bca3"), Color("#ffe2c6")]

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


func _ticks(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame


func _check_atlas() -> void:
	var texture := load("res://assets/characters/mage_atlas.png") as Texture2D
	var atlas := texture.get_image() if texture else null
	_check(atlas != null, "產生器有輸出角色圖集")
	if atlas == null:
		return
	_check(atlas.get_size() == Vector2i(560, 144), "三方向各四格待機與六格走路，格子固定 56×48 px")
	var crisp := true
	var approved := {}
	var used := {}
	var within_palette := true
	for hex: String in APPROVED_COLORS:
		approved[Color(hex).to_rgba32()] = true
	for y in atlas.get_height():
		for x in atlas.get_width():
			var pixel := atlas.get_pixel(x, y)
			var alpha := pixel.a
			crisp = crisp and (alpha == 0.0 or alpha == 1.0)
			if alpha > 0.0:
				var rgba := pixel.to_rgba32()
				used[rgba] = true
				within_palette = within_palette and approved.has(rgba)
	_check(crisp, "圖集沒有半透明像素")
	_check(within_palette and used.size() <= APPROVED_COLORS.size(), "圖集限定於紫袍法師色票，實際 %d 色" % used.size())
	var idle := _composite_frame(atlas, 0, 0)
	var amber := _color_bounds(idle, Rect2i(2, 4, 20, 19), [Color("#ed812b")])
	_check(amber.size.x >= 3 and amber.size.y >= 4, "左上方杖頭有獨立的琥珀晶面")
	# B 的下巴離帽頂約為整身的 71%，足以辨識帽、臉與短袍之間的比例。
	var bounds := idle.get_used_rect()
	var cheek_width := 0
	var chin_y := -1
	var chin_width := 0
	for y in range(26, 37):
		var face := _color_bounds(idle, Rect2i(28, y, 16, 1), SKIN)
		if face.size.x >= 5:
			cheek_width = maxi(cheek_width, face.size.x)
			chin_width = face.size.x
			chin_y = y
	_check(cheek_width >= 9 and absf(chin_width - 0.78 * cheek_width) <= 1.0,
		"短平下巴比眼頰窄，臉寬 %d、下巴寬 %d" % [cheek_width, chin_width])
	var chin_fraction := float(chin_y - bounds.position.y) / maxf(1.0, bounds.size.y - 1.0)
	_check(chin_fraction >= 0.66 and chin_fraction <= 0.76, "戴帽全身的下巴位置 %.2f" % chin_fraction)
	# 去帽視圖保留法杖，取頭部所在的直條才量得到髮頂。
	var bare_head := MageArt.draw_frame(0, 0, false).get_region(Rect2i(25, 0, 18, 48))
	var scalp_y := bare_head.get_used_rect().position.y
	var sole_y := bounds.end.y - 1
	_check(chin_y > scalp_y and absi((chin_y - scalp_y) - (sole_y - chin_y)) <= 1,
		"不含帽的二頭身：髮頂 %d、下巴 %d、靴底 %d" % [scalp_y, chin_y, sole_y])
	# 杖尾可能與靴底同高，只對雙腿範圍計算鞋底的可見段數。
	var lowest_row := idle.get_region(Rect2i(24, 46, 18, 1))
	var runs := 0
	var occupied := false
	for x in lowest_row.get_width():
		var solid := lowest_row.get_pixel(x, 0).a > 0.0
		if solid and not occupied:
			runs += 1
		occupied = solid
	_check(runs == 2, "站立可看見兩隻靴底與中間留白")
	for row in 3:
		var unique_frames: Array[PackedByteArray] = []
		var unclipped := true
		var feet_aligned := true
		var separate_boots := true
		var gripping_staff := true
		var no_baked_weapon := true
		for column in 10:
			var frame := _composite_frame(atlas, row, column)
			var body := atlas.get_region(Rect2i(column * 56, row * 48, 56, 48))
			if row == 1:
				body.flip_x()
			no_baked_weapon = no_baked_weapon and not body.get_region(Rect2i(8, 7, 9, 15)).get_used_rect().has_area()
			var bytes := frame.get_data()
			if not unique_frames.has(bytes):
				unique_frames.append(bytes)
			for x in 56:
				unclipped = unclipped and frame.get_pixel(x, 0).a == 0.0 and frame.get_pixel(x, 47).a == 0.0
			for y in 48:
				unclipped = unclipped and frame.get_pixel(0, y).a == 0.0 and frame.get_pixel(55, y).a == 0.0
			if row == 1:
				frame.flip_x() # 背面杖在右邊，翻正後用相同的部位檢查。
			var legs := frame.get_region(Rect2i(24, 42, 18, 5))
			var bottom := legs.get_used_rect().end.y + 41
			var contact := column < 4 or column == 4 or column == 7
			feet_aligned = feet_aligned and (bottom == 46 if contact else bottom < 46)
			# 靴子使用皮革色，袍襬金邊和法杖從此區域排除。
			var leather := [Color("#593241"), Color("#8f5144")]
			var far_boot := _color_bounds(frame, Rect2i(24, 42, 7, 5), leather)
			var near_boot := _color_bounds(frame, Rect2i(32, 42, 10, 5), leather)
			separate_boots = separate_boots and far_boot.has_area() and near_boot.has_area()
			for y in range(42, 47):
				separate_boots = separate_boots and not frame.get_pixel(31, y) in leather
			gripping_staff = gripping_staff and _has_grip(frame)
		_check(unique_frames.size() == 10, "方向 %d 的十格姿勢各不相同" % row)
		_check(unclipped, "方向 %d 沒有裁掉帽尖、法杖或腳" % row)
		_check(gripping_staff, "方向 %d 十格的掌心上下均連接杖柄" % row)
		_check(no_baked_weapon, "方向 %d 的角色本體沒有烘焙法杖晶石" % row)
		_check(feet_aligned, "方向 %d 保留接地幀與騰空幀的腳底高度" % row)
		_check(separate_boots, "方向 %d 的雙靴各自成形且維持間隙" % row)


func _color_bounds(frame: Image, region: Rect2i, colors: Array) -> Rect2i:
	var bounds := Rect2i()
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			if frame.get_pixel(x, y) in colors:
				var pixel := Rect2i(x, y, 1, 1)
				bounds = bounds.merge(pixel) if bounds.has_area() else pixel
	return bounds


## 用實際輸出的三層檔案組合，避免仍以已烘焙武器的舊圖集通過測試。
func _composite_frame(atlas: Image, row: int, column: int) -> Image:
	var rect := Rect2i(column * 56, row * 48, 56, 48)
	var frame := atlas.get_region(rect)
	var staff: Image = load("res://assets/characters/mage_staff.png").get_image().duplicate()
	var offset := Player.CharacterAnimation.staff_offset(column)
	if row == 1:
		staff.flip_x()
		offset.x = -offset.x
	frame.blend_rect(staff, Rect2i(0, 0, 56, 48), offset)
	var hand: Image = load("res://assets/characters/mage_hand_atlas.png").get_image().get_region(rect)
	frame.blend_rect(hand, Rect2i(0, 0, 56, 48), Vector2i.ZERO)
	return frame


func _has_grip(frame: Image) -> bool:
	var palm := _color_bounds(frame, Rect2i(15, 33, 10, 9), SKIN)
	if palm.size.x < 2 or palm.size.y < 2:
		return false
	var wood := [Color("#593241"), Color("#8f5144")]
	var above := Rect2i(palm.position.x, palm.position.y - 1, palm.size.x, 1)
	var below := Rect2i(palm.position.x, palm.end.y, palm.size.x, 1)
	return _color_bounds(frame, above, wood).has_area() and _color_bounds(frame, below, wood).has_area()


func _light_hits_crystal(player: Player) -> bool:
	var sprite: Sprite3D = player.weapon.sprite
	var frame: Image = sprite.texture.get_image().duplicate()
	var frame_size := frame.get_size()
	if sprite.flip_h:
		frame.flip_x()
	# 將光源轉回看板的水平／垂直像素座標，原點在角色腳下。
	var tip := (player.staff_light.global_position - player.weapon.global_position).rotated(
		Vector3.UP, -player.camera_yaw)
	tip = Vector3(tip.x / sprite.pixel_size, tip.y / (sprite.pixel_size * sprite.scale.y), 0.0)
	var x := floori(frame_size.x * 0.5 - sprite.offset.x + tip.x)
	var y := floori(frame_size.y * 0.5 + sprite.offset.y - tip.y)
	var region := Rect2i(x - 2, y - 2, 5, 5).intersection(Rect2i(Vector2i.ZERO, frame_size))
	return _color_bounds(frame, region, [Color("#ed812b")]).has_area()


func _check_equipment(player: Player) -> void:
	var appearance := Player.WeaponAppearance.new()
	var book := Image.create(16, 12, false, Image.FORMAT_RGBA8)
	book.fill(Color("#51305e"))
	appearance.texture = ImageTexture.create_from_image(book)
	appearance.grip_pixel = Vector2(2.5, 9.5)
	appearance.light_pixel = Vector2(12.5, 3.5)
	player.equip_weapon(appearance)
	_check(player.weapon.sprite.texture == appearance.texture and not player.staff_light.visible,
		"替換不同尺寸的魔導書外觀時，移除原法杖與琥珀光")
	var all_grips_match := true
	var all_layers_match := true
	var all_emitters_match := true
	var depth_order_matches := true
	for pitch: float in [0.0, 33.0, 55.0]:
		player.camera_pitch_deg = pitch
		for row in 3:
			for left: bool in [false, true]:
				for column in 10:
					var direction: Vector3 = [Vector3(0.3, 0, 1), Vector3(0.3, 0, -1), Vector3(1, 0, 0)][row]
					if left:
						direction.x = -direction.x
					player.aim_dir = direction.rotated(Vector3.UP, player.camera_yaw)
					player.set("_was_moving", column >= 4)
					var phase: float = [0.01, 0.21, 0.41, 3.21][column] if column < 4 else (column - 4 + 0.2) / player.walk_fps
					player.set("_animation_time", phase)
					player._refresh_sprite()
					var mirrored := left != (row == 1)
					var sign_x := -1.0 if mirrored else 1.0
					var offset := Player.CharacterAnimation.staff_offset(column)
					var expected := Player.GRIP + Vector2(offset) - Player.FEET
					expected = Vector2(expected.x * sign_x, -expected.y)
					var sprite: Sprite3D = player.weapon.sprite
					var point := appearance.grip_pixel - appearance.texture.get_size() * 0.5
					var actual := Vector2(point.x * sign_x, -point.y) + sprite.offset
					all_grips_match = all_grips_match and actual.is_equal_approx(expected)
					all_layers_match = all_layers_match and player.hand_sprite.frame_coords == Vector2i(column, row) \
						and player.hand_sprite.flip_h == left and sprite.flip_h == mirrored \
						and player.hand_sprite.offset.is_equal_approx(player.sprite.offset) \
						and player.hand_sprite.scale.is_equal_approx(player.sprite.scale) \
						and sprite.scale.is_equal_approx(player.sprite.scale)
					var expected_light := expected + Vector2(
						(appearance.light_pixel.x - appearance.grip_pixel.x) * sign_x,
						appearance.grip_pixel.y - appearance.light_pixel.y)
					var actual_light := (player.staff_light.global_position - player.global_position).rotated(
						Vector3.UP, -player.camera_yaw)
					actual_light /= Player.PIXEL
					actual_light.y /= player.sprite.scale.y
					all_emitters_match = all_emitters_match and Vector2(actual_light.x, actual_light.y).is_equal_approx(expected_light)
					var ray := Vector3(0.0, sin(deg_to_rad(pitch)), cos(deg_to_rad(pitch))).rotated(Vector3.UP, player.camera_yaw)
					depth_order_matches = depth_order_matches and player.weapon.position.dot(ray) > 0.0 \
						and player.hand_sprite.position.dot(ray) > player.weapon.position.dot(ray) \
						and player.weapon.position.cross(ray).length() < 0.000001 \
						and player.hand_sprite.position.cross(ray).length() < 0.000001
	_check(all_grips_match, "魔導書握點在三種俯角、30 格姿勢及左右面向均貼合掌心")
	_check(all_layers_match, "獨立武器與手部圖層的姿勢、鏡像和俯角一致")
	_check(all_emitters_match, "裝備光源位置由各自貼圖定義，換裝後不殘留琥珀杖位置")
	_check(depth_order_matches, "身體、武器、掌心沿鏡頭視線分層，避免共面閃爍與上下錯位")
	appearance.light_energy = 0.4
	player.equip_weapon(appearance)
	_check(player.staff_light.visible and is_equal_approx(player.staff_light.light_energy, 0.4),
		"發光魔導書可使用自己的光源強度")
	player.equip_weapon(null)
	_check(player.weapon.sprite.texture == null and not player.weapon.sprite.visible
		and not player.staff_light.visible and is_zero_approx(player.staff_light.light_energy),
		"卸下武器立即移除貼圖與光源")
	player._update_animation(0.1, Player.SPEED)
	_check(player.hand_sprite.visible, "空手時角色仍可正常播放動作")
	player.equip_weapon(Player.DEFAULT_WEAPON)
	_check(_light_hits_crystal(player), "重新裝備法杖後立即對齊原本握點與晶石光源")
	player.camera_pitch_deg = 33.0
	player.set("_was_moving", false)
	player.set("_animation_time", 0.0)
	player.set("_face_left", false)
	player.aim_dir = Vector3.BACK.rotated(Vector3.UP, player.camera_yaw)
	player._refresh_sprite()


func _check_projection(world: Node3D, player: Player) -> void:
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.fov = 25.0
	var pivot := player.global_position + Vector3.UP
	for pitch: float in [0.0, 33.0, 55.0]:
		player.camera_pitch_deg = pitch
		var angle := deg_to_rad(pitch)
		camera.global_position = pivot + Vector3(0.0, sin(angle), cos(angle)).rotated(
			Vector3.UP, player.camera_yaw) * 30.0
		camera.look_at(pivot, Vector3.UP)
		var pixel_x := Vector3.RIGHT.rotated(Vector3.UP, player.camera_yaw) * player.sprite.pixel_size
		var pixel_y := Vector3.UP * player.sprite.pixel_size * player.sprite.scale.y
		var screen_width := camera.unproject_position(pivot + pixel_x * 0.5).distance_to(
			camera.unproject_position(pivot - pixel_x * 0.5))
		var screen_height := camera.unproject_position(pivot + pixel_y * 0.5).distance_to(
			camera.unproject_position(pivot - pixel_y * 0.5))
		_check(absf(screen_height / screen_width - 1.0) < 0.01,
			"俯角 %.0f° 的透視鏡頭投影保留方形像素" % pitch)
		_check(is_equal_approx(player.sprite.pixel_size, 1.2 / 32.0),
			"俯角 %.0f° 保留已選定的人物寬度" % pitch)
		var foot_y := (24.0 - 47.0 + player.sprite.offset.y) * player.sprite.pixel_size * player.sprite.scale.y
		_check(is_zero_approx(foot_y) and player.sprite.rotation.is_zero_approx(),
			"俯角 %.0f° 補償以接地腳底為軸、紙片保持直立" % pitch)
		_check(_light_hits_crystal(player), "俯角 %.0f° 調整後杖光立即對齊晶石" % pitch)
	player.camera_pitch_deg = 90.0
	_check(is_finite(player.sprite.scale.y) and player.sprite.scale.y > 0.0,
		"極端俯角不會產生無限大或翻轉的紙片")
	player.camera_pitch_deg = NAN
	_check(is_equal_approx(player.camera_pitch_deg, 33.0), "無效俯角恢復預設值")
	camera.queue_free()


func _check_turns(player: Player) -> void:
	var headings := [
		Vector2(0.3, 0.8), Vector2(-0.15, 0.4), Vector2(-0.2, -0.4),
		Vector2(-0.8, -0.2), Vector2(0.02, 0.8), Vector2(-0.02, 0.8),
		Vector2(0.2, 0.4), Vector2(0.2, -0.4),
	]
	var rows := [0, 0, 1, 2, 0, 0, 0, 1]
	var left := [false, true, true, true, true, true, false, false]
	for i in headings.size():
		player.move_input = headings[i]
		await _ticks(3)
		_check(player.sprite.frame_coords.y == rows[i] and player.sprite.flip_h == left[i],
			"方向 %s 保持一致左右朝向與垂直附近的遲滯" % str(headings[i]))
		_check(_light_hits_crystal(player), "方向 %s 的鏡像杖光保持對齊" % str(headings[i]))
	player.move_input = Vector2.LEFT
	player.aim_input = Vector2(0.25, 0.4)
	await _ticks(3)
	_check(not player.sprite.flip_h and player.sprite.frame_coords.y == 0,
		"往左移動時仍能朝右下方瞄準")
	player.aim_input = Vector2.ZERO
	await _ticks(3)


func _run() -> void:
	_check_atlas()
	var world := Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(100, 0.2, 100)
	floor_shape.shape = floor_box
	floor_shape.position.y = -0.1
	floor_body.add_child(floor_shape)
	world.add_child(floor_body)
	var player := Player.new()
	player.camera_yaw = deg_to_rad(22.0)
	player.aim_dir = Vector3.BACK.rotated(Vector3.UP, player.camera_yaw)
	world.add_child(player)
	await _ticks(3)
	var idle_height_px := player.sprite.texture.get_image().get_region(
		Rect2i(0, 0, 56, 48)).get_used_rect().size.y
	_check(is_equal_approx(idle_height_px * player.sprite.pixel_size * player.sprite.scale.y
			* cos(deg_to_rad(33.0)), 1.65) and player.sprite.shaded
		and player.sprite.alpha_cut == SpriteBase3D.ALPHA_CUT_DISCARD,
		"B 版補償後投影等效高度為 1.65 公尺，保留場景光與深度裁切")
	_check_projection(world, player)
	_check_equipment(player)
	var directions := [Vector2.DOWN, Vector2.UP, Vector2.RIGHT, Vector2.LEFT]
	var expected_rows := [0, 1, 2, 2]
	for i in directions.size():
		var before := player.position
		player.move_input = directions[i]
		await _ticks(8)
		var displacement := (player.position - before).rotated(Vector3.UP, -player.camera_yaw)
		_check(Vector2(displacement.x, displacement.z).dot(directions[i]) > 0.3,
			"方向 %d 按鏡頭方向移動" % i)
		_check(player.sprite.frame_coords.y == expected_rows[i]
			and player.sprite.flip_h == (i == 3), "方向 %d 使用對應面向" % i)
		var mirrored := i == 1 or i == 3
		var wand_offset := (player.staff_light.global_position - player.global_position).rotated(
			Vector3.UP, -player.camera_yaw).x
		_check((player.sprite.offset.x > 0.0) == mirrored and (wand_offset > 0.0) == mirrored,
			"方向 %d 的腳底與杖光跟隨圖格鏡像" % i)
		_check(_light_hits_crystal(player), "方向 %d 的杖光位於琥珀晶面兩像素內" % i)
	await _check_turns(player)
	player.move_input = Vector2.LEFT * 0.15
	var slow_start := player.position
	var slow_phase: float = player.get("_animation_time")
	await _ticks(24)
	var slow_travel := Vector2(player.position.x - slow_start.x, player.position.z - slow_start.z).length()
	var phase_travel: float = (player.get("_animation_time") - slow_phase) * Player.SPEED
	_check(absf(slow_travel - phase_travel) < 0.01,
		"低速搖桿的步頻跟實際移動距離同步，沒有最低踏步速度")
	player.move_input = Vector2.LEFT
	var columns: Array[int] = []
	var light_tracks_stride := true
	for i in 40:
		await _ticks(1)
		var column := player.sprite.frame_coords.x
		if not columns.has(column):
			columns.append(column)
		light_tracks_stride = light_tracks_stride and _light_hits_crystal(player)
	_check(columns.size() == 6 and columns.min() == 4 and columns.max() == 9, "走路播放六個步伐")
	_check(light_tracks_stride, "杖光跟隨全部六格延遲擺動的晶石")
	_check(player.sprite.position.y == 0.0, "走路不再整張圖上下跳")
	var before_cast := player.sprite.frame_coords.x
	player.queue.add(Elements.Type.WATER)
	player.cast_queue(Vector3.FORWARD.rotated(Vector3.UP, player.camera_yaw))
	_check(player.sprite.frame_coords.x == before_cast and player.sprite.frame_coords.y == 1,
		"移動中施法只更新面向，不重置步伐")
	player.aim_input = Vector2.UP
	await _ticks(5)
	_check(player.sprite.frame_coords.y == 1
		and player.aim_dir.dot(Vector3.FORWARD.rotated(Vector3.UP, player.camera_yaw)) > 0.99,
		"邊走邊瞄準時，面向與施法方向跟隨右搖桿")
	player.move_input = Vector2.ZERO
	player.aim_input = Vector2.ZERO
	await _ticks(3)
	_check(player.sprite.frame_coords.y == 1 and player.sprite.frame_coords.x < 4, "停下後維持上次面向並回到站姿")
	var idle_columns: Array[int] = []
	for i in 220:
		await _ticks(1)
		var column := player.sprite.frame_coords.x
		if not idle_columns.has(column):
			idle_columns.append(column)
	_check(idle_columns.size() == 4 and idle_columns.max() == 3, "待機持續播放呼吸並穿插眨眼")
	# 推牆仍有輸入，但實際位移為零，應回到站姿。
	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(0.5, 3, 10)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	wall.position = Vector3(2, 1.5, 0)
	world.add_child(wall)
	player.position = Vector3(1, 0, 0)
	player.velocity = Vector3.ZERO
	player.camera_yaw = 0.0
	player.move_input = Vector2.RIGHT
	await _ticks(30)
	_check(player.position.x < 1.5 and player.sprite.frame_coords.x < 4, "推牆停止位移後不原地踏步")
	print("%d passed, %d failed" % [_passed, _failed])
	world.queue_free()
	await process_frame
	quit(1 if _failed > 0 else 0)
