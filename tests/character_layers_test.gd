extends SceneTree
## 檢查實際 PNG 的接縫、部位連接與拆件，不以產生器回傳值代替輸出驗證。
## godot --headless --path . --script res://tests/character_layers_test.gd

const SIZE := Vector2i(56, 48)
const NEIGHBORS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
var _passed := 0
var _failed := 0


func _init() -> void:
	var body := Image.load_from_file(ProjectSettings.globalize_path("res://assets/characters/mage_atlas.png"))
	var hands := Image.load_from_file(ProjectSettings.globalize_path("res://assets/characters/mage_hand_atlas.png"))
	var staff := Image.load_from_file(ProjectSettings.globalize_path("res://assets/characters/mage_staff.png"))
	_check(body != null and hands != null and staff != null, "身體、握手、武器都有獨立輸出")
	if body == null or hands == null or staff == null:
		quit(1)
		return
	_check(body.get_size() == Vector2i(560, 144) and hands.get_size() == body.get_size(),
		"身體與握手使用相同30格索引")
	_check(staff.get_size() == SIZE, "法杖只輸出一份基準素材，不複製30份")
	_check(not _has_color(body, Color("#ed812b")) and not _has_color(hands, Color("#ed812b")),
		"琥珀晶石沒有烘焙在身體或握手圖集")
	_check(not _has_color(staff, Color("#ffe2c6")) and not _has_color(staff, Color("#f5bca3")),
		"獨立法杖沒有殘留手指")
	var palette := {}
	var crisp := true
	for layer: Image in [body, hands, staff]:
		for y in layer.get_height():
			for x in layer.get_width():
				var pixel := layer.get_pixel(x, y)
				crisp = crisp and (pixel.a == 0.0 or pixel.a == 1.0)
				if pixel.a > 0.0:
					palette[pixel.to_rgba32()] = true
	_check(crisp and palette.size() <= 21, "拆件維持硬邊與既有21色色數上限")
	for row in 3:
		for column in 10:
			var region := Rect2i(Vector2i(column * 56, row * 48), SIZE)
			var frame := body.get_region(region)
			var hand := hands.get_region(region)
			if row == 1:
				frame.flip_x()
				hand.flip_x()
			var label := "方向%d／姿勢%d" % [row, column]
			# 帽與頭重疊帶：包含原來跑步與呼吸會穿空的96個像素。
			_check(_solid(frame, Rect2i(34, 17, 7, 6)), label + " 帽內襯到髮頂沒有穿空")
			_check(_enclosed_holes(frame) == 0, label + " 領口、髮尾、衣襬沒有封閉破洞")
			_check(_component_count(frame) == 1, label + " 身體、帽子與雙靴沒有分離")
			frame.blend_rect(hand, Rect2i(Vector2i.ZERO, SIZE), Vector2i.ZERO)
			_check(_component_count(frame) == 1, label + " 延遲握手仍接在袖口")
	print("Character layers: %d PASS, %d FAIL" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("FAIL: ", label)


func _has_color(img: Image, color: Color) -> bool:
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y) == color:
				return true
	return false


func _solid(img: Image, region: Rect2i) -> bool:
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			if img.get_pixel(x, y).a == 0.0:
				return false
	return true


# 只檢查不含武器的身體：帽尖彎鉤、兩腿與手臂外側留白都連到外部。
func _enclosed_holes(img: Image) -> int:
	var visited := {}
	var pending: Array[Vector2i] = []
	var transparent := 0
	for y in SIZE.y:
		for x in SIZE.x:
			if img.get_pixel(x, y).a > 0.0:
				continue
			transparent += 1
			if x == 0 or x == SIZE.x - 1 or y == 0 or y == SIZE.y - 1:
				var point := Vector2i(x, y)
				visited[point] = true
				pending.append(point)
	while not pending.is_empty():
		var point: Vector2i = pending.pop_back()
		for direction: Vector2i in NEIGHBORS:
			var next := point + direction
			if Rect2i(Vector2i.ZERO, SIZE).has_point(next) and not visited.has(next) \
					and img.get_pixelv(next).a == 0.0:
				visited[next] = true
				pending.append(next)
	return transparent - visited.size()


func _component_count(img: Image) -> int:
	var remaining := {}
	for y in SIZE.y:
		for x in SIZE.x:
			if img.get_pixel(x, y).a > 0.0:
				remaining[Vector2i(x, y)] = true
	var count := 0
	while not remaining.is_empty():
		count += 1
		var seed: Vector2i = remaining.keys()[0]
		remaining.erase(seed)
		var pending: Array[Vector2i] = [seed]
		while not pending.is_empty():
			var point: Vector2i = pending.pop_back()
			for y in range(-1, 2):
				for x in range(-1, 2):
					var next := point + Vector2i(x, y)
					if remaining.has(next):
						remaining.erase(next)
						pending.append(next)
	return count
