extends SceneTree
## 圖集及真實 CharacterBody3D 移動回歸；不以數學測試取代畫面驗收。
## godot --headless --path . --script res://tests/player_animation_test.gd

## 2026-11-17 Harvey 接受的書騎士圖集：34 色（透明另計）。細修不可新增色彩。
const APPROVED_COLORS := [
	"#26243b", "#2e2e44", "#302a43", "#353a63", "#37354c", "#394958", "#3b2437", "#433f53",
	"#443230", "#468eac", "#4a2c3b", "#4f4033", "#52454c", "#524b52", "#534b48", "#534f59",
	"#58698e", "#5ba4b4", "#8085ae", "#819bad", "#89dfe4", "#913b55", "#b7b5cf", "#b97935",
	"#cebea3", "#d85d63", "#e4e0dd", "#e6a389", "#edb941", "#ef9b99", "#f8cfb2", "#fbebc9",
	"#ffeaa0", "#fff9e8",
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
	_check(within_palette, "只使用已驗收的34色色票，實際%d色" % used.size())
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
		_check(unclipped, "方向 %d 沒有裁掉羽飾、魔導書或腳" % row)
		_check(feet_aligned, "方向 %d 的每格腳底對齊地面" % row)


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
