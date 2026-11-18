extends SceneTree
## 圖集及真實 CharacterBody3D 移動回歸；不以數學測試取代畫面驗收。
## godot --headless --path . --script res://tests/player_animation_test.gd

const MageArt := preload("res://tools/gen_character.gd")

## 黑髮紫袍法師的固定色盤；透明另計。
const APPROVED_COLORS := [
	"#211d29", "#231b2b", "#312137", "#352041", "#352d38", "#504452", "#51305e", "#571c3b",
	"#57313c", "#593241", "#734485", "#796876", "#8a2947", "#8f5144", "#9c629e", "#bc3f53",
	"#c8844e", "#db977f", "#ec6a67", "#ed812b", "#f4be6b", "#f5bca3", "#ffe2c6", "#fff2b7",
]

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
	var amber_pixels := 0
	for y in range(25, 41):
		for x in range(1, 14):
			if idle.get_pixel(x, y) == Color("#ed812b"):
				amber_pixels += 1
	_check(amber_pixels >= 5, "左側杖頭能辨識獨立的琥珀晶面")
	# 髮頂藏在帽子裡；由同一產生器關掉帽層量髮頂，頷和腳底直接量遊戲圖集。
	var unmasked := MageArt.draw_frame(0, 0, false)
	var scalp_y := unmasked.get_used_rect().position.y
	var sole_y := idle.get_used_rect().end.y - 1
	var cheek := 0
	var chin_y := -1
	for y in range(scalp_y, sole_y):
		var width := _skin_width(idle, y)
		if width >= 10:
			cheek = maxi(cheek, width)
			chin_y = y
		elif chin_y >= 0:
			break # 條帶縮為頸部的第一行
	var chin := _skin_width(idle, chin_y) if chin_y >= 0 else 0
	_check(cheek >= 12 and chin >= cheek * 0.70 and chin <= cheek * 0.85, "下巴保留約四分之三臉頰寬")
	_check(chin_y > scalp_y and absi((chin_y - scalp_y) - (sole_y - chin_y)) <= 1,
		"不含帽的二頭身：髮頂 %d、下巴 %d、鞋底 %d" % [scalp_y, chin_y, sole_y])
	var lowest_row := idle.get_region(Rect2i(0, sole_y, idle.get_width(), 1))
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
		for column in 6:
			var frame := atlas.get_region(Rect2i(column * 56, row * 48, 56, 48))
			var bytes := frame.get_data()
			if not unique_frames.has(bytes):
				unique_frames.append(bytes)
			for x in 56:
				unclipped = unclipped and frame.get_pixel(x, 0).a == 0.0 and frame.get_pixel(x, 47).a == 0.0
			for y in 48:
				unclipped = unclipped and frame.get_pixel(0, y).a == 0.0 and frame.get_pixel(55, y).a == 0.0
			var bounds := frame.get_used_rect()
			feet_aligned = feet_aligned and bounds.end.y == 47
		_check(unique_frames.size() == 6, "方向 %d 的六格姿勢各不相同" % row)
		_check(unclipped, "方向 %d 沒有裁掉帽尖、法杖或腳" % row)
		_check(feet_aligned, "方向 %d 的每格腳底對齊地面" % row)


func _skin_width(frame: Image, y: int) -> int:
	var skin := [Color("#db977f"), Color("#f5bca3"), Color("#ffe2c6")]
	var left := 46
	var right := 28
	# 排除耳朵，只在臉的範圍測左右兩側，像素中間可以是嘴與眼睛。
	for x in range(29, 46):
		if frame.get_pixel(x, y) in skin:
			left = mini(left, x)
			right = maxi(right, x)
	return maxi(0, right - left + 1)


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
	_check(player.sprite.pixel_size == 1.0 / 32.0 and player.sprite.shaded
		and player.sprite.alpha_cut == SpriteBase3D.ALPHA_CUT_DISCARD,
		"角色保留固定像素密度、場景光與深度裁切")
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
