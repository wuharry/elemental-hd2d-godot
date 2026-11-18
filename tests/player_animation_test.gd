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
	_check(atlas.get_size() == Vector2i(336, 144), "三方向各六格，格子固定 56×48 px")
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
	var idle := atlas.get_region(Rect2i(0, 0, 56, 48))
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
		var gripping_staff := true
		for column in 6:
			var frame := atlas.get_region(Rect2i(column * 56, row * 48, 56, 48))
			var bytes := frame.get_data()
			if not unique_frames.has(bytes):
				unique_frames.append(bytes)
			for x in 56:
				unclipped = unclipped and frame.get_pixel(x, 0).a == 0.0 and frame.get_pixel(x, 47).a == 0.0
			for y in 48:
				unclipped = unclipped and frame.get_pixel(0, y).a == 0.0 and frame.get_pixel(55, y).a == 0.0
			if row == 1:
				frame.flip_x() # 背面杖在右邊，翻正後用相同的部位檢查。
			feet_aligned = feet_aligned and not frame.get_region(Rect2i(24, 46, 18, 1)).is_invisible()
			gripping_staff = gripping_staff and _has_grip(frame)
		_check(unique_frames.size() == 6, "方向 %d 的六格姿勢各不相同" % row)
		_check(unclipped, "方向 %d 沒有裁掉帽尖、法杖或腳" % row)
		_check(gripping_staff, "方向 %d 六格的掌心上下均連接杖柄" % row)
		_check(feet_aligned, "方向 %d 的每格腳底對齊地面" % row)


func _color_bounds(frame: Image, region: Rect2i, colors: Array) -> Rect2i:
	var bounds := Rect2i()
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			if frame.get_pixel(x, y) in colors:
				var pixel := Rect2i(x, y, 1, 1)
				bounds = bounds.merge(pixel) if bounds.has_area() else pixel
	return bounds


func _has_grip(frame: Image) -> bool:
	var palm := _color_bounds(frame, Rect2i(15, 33, 10, 9), SKIN)
	if palm.size.x < 2 or palm.size.y < 2:
		return false
	var wood := [Color("#593241"), Color("#8f5144")]
	var above := Rect2i(palm.position.x, palm.position.y - 1, palm.size.x, 1)
	var below := Rect2i(palm.position.x, palm.end.y, palm.size.x, 1)
	return _color_bounds(frame, above, wood).has_area() and _color_bounds(frame, below, wood).has_area()


func _light_hits_crystal(player: Player) -> bool:
	var sprite := player.sprite
	var frame_size := Vector2i(56, 48)
	var frame := sprite.texture.get_image().get_region(Rect2i(sprite.frame_coords * frame_size, frame_size))
	if sprite.flip_h:
		frame.flip_x()
	# 將光源轉回看板的水平／垂直像素座標，原點在角色腳下。
	var tip := player.staff_light.position.rotated(Vector3.UP, -player.camera_yaw) / sprite.pixel_size
	var x := floori(frame_size.x * 0.5 - sprite.offset.x + tip.x)
	var y := floori(frame_size.y * 0.5 + sprite.offset.y - tip.y)
	var region := Rect2i(x - 2, y - 2, 5, 5).intersection(Rect2i(Vector2i.ZERO, frame_size))
	return _color_bounds(frame, region, [Color("#ed812b")]).has_area()


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
	world.add_child(player)
	await _ticks(3)
	var idle_height_px := player.sprite.texture.get_image().get_region(
		Rect2i(0, 0, 56, 48)).get_used_rect().size.y
	_check(is_equal_approx(idle_height_px * player.sprite.pixel_size, 1.65) and player.sprite.shaded
		and player.sprite.alpha_cut == SpriteBase3D.ALPHA_CUT_DISCARD,
		"B 版從帽頂到靴底顯示為 1.65 公尺，保留場景光與深度裁切")
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
		var wand_offset := player.staff_light.position.rotated(Vector3.UP, -player.camera_yaw).x
		_check((player.sprite.offset.x > 0.0) == mirrored and (wand_offset > 0.0) == mirrored,
			"方向 %d 的腳底與杖光跟隨圖格鏡像" % i)
		_check(_light_hits_crystal(player), "方向 %d 的杖光位於琥珀晶面兩像素內" % i)
	var columns: Array[int] = []
	for i in 40:
		await _ticks(1)
		var column := player.sprite.frame_coords.x
		if not columns.has(column):
			columns.append(column)
	_check(columns.size() == 4 and not columns.has(0) and not columns.has(1), "走路真的播放四個步伐")
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
	_check(player.sprite.frame_coords.y == 1 and player.sprite.frame_coords.x < 2, "停下後維持上次面向並回到站姿")
	var idle_columns: Array[int] = []
	for i in 165:
		await _ticks(1)
		var column := player.sprite.frame_coords.x
		if not idle_columns.has(column):
			idle_columns.append(column)
	_check(idle_columns.has(0) and idle_columns.has(1) and idle_columns.size() == 2, "待機播放呼吸／眨眼兩格")
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
	_check(player.position.x < 1.5 and player.sprite.frame_coords.x < 2, "推牆停止位移後不原地踏步")
	print("%d passed, %d failed" % [_passed, _failed])
	world.queue_free()
	await process_frame
	quit(1 if _failed > 0 else 0)
