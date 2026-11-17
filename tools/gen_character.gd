extends SceneTree
## 原創「星紋書騎士」像素角色；固定原生像素格，正／背／側各兩格待機與四格走路。
## 參考角色的視覺語彙：大頭、小身體、非對稱髮束、彩色描邊與誇張的裝備剪影。
## godot --headless --path . --script res://tools/gen_character.gd

const OUT := "res://assets/characters/"
const W := 56
const H := 48
const COLUMNS := 6
const ROWS := 3

const INK := Color("#302a43")
const HAIR_WHITE := Color("#fff9e8")
const HAIR_CREAM := Color("#e4e0dd")
const HAIR_LILAC := Color("#b7b5cf")
const HAIR_BLUE := Color("#8085ae")
const NAVY := Color("#353a63")
const BLUE := Color("#58698e")
const BLUE_LIGHT := Color("#819bad")
const IVORY := Color("#fbebc9")
const IVORY_FOLD := Color("#cebea3")
const GOLD := Color("#edb941")
const GOLD_LIGHT := Color("#ffeaa0")
const GOLD_EDGE := Color("#b97935")
const RUBY := Color("#d85d63")
const RUBY_DARK := Color("#913b55")
const SKIN := Color("#f8cfb2")
const SKIN_EDGE := Color("#e6a389")
const BLUSH := Color("#ef9b99")
const IRIS := Color("#5ba4b4")
const GEM := Color("#89dfe4")
const GEM_EDGE := Color("#468eac")
## 固定在已驗收的色票內；新露出的輪廓也不再自動衍生新顏色。
const OUTLINE_COLORS := [
	Color("#26243b"), Color("#2e2e44"), Color("#37354c"), Color("#394958"),
	Color("#3b2437"), Color("#433f53"), Color("#443230"), Color("#4a2c3b"),
	Color("#4f4033"), Color("#52454c"), Color("#524b52"), Color("#534b48"), Color("#534f59"),
]

var img: Image
var _pose := 0
var _facing := 0
var _offset := Vector2i.ZERO


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var atlas := Image.create(W * COLUMNS, H * ROWS, false, Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	for facing in ROWS:
		for pose in COLUMNS:
			_draw_frame(facing, pose)
			atlas.blit_rect(img, Rect2i(0, 0, W, H), Vector2i(pose * W, facing * H))
			if facing == 0 and pose == 0:
				img.save_png(OUT + "mage_idle.png")
				var front := img.duplicate()
				front.resize(W * 10, H * 10, Image.INTERPOLATE_NEAREST)
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test_output"))
				front.save_png("res://test_output/mage_front_preview.png")
	atlas.save_png(OUT + "mage_atlas.png")
	var preview := atlas.duplicate()
	preview.resize(W * COLUMNS * 4, H * ROWS * 4, Image.INTERPOLATE_NEAREST)
	preview.save_png("res://test_output/mage_preview.png")
	_orb()
	print("Character atlas: ", W * COLUMNS, " × ", H * ROWS, " (18 frames)")
	quit()


func _draw_frame(facing: int, pose: int) -> void:
	_facing = facing
	_pose = pose
	_offset = Vector2i.ZERO
	img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	_cape()
	_legs()
	_body()
	_hair_back()
	if facing == 0:
		_face()
		_bangs()
	elif facing == 1:
		_back_detail()
	else:
		_profile()
	_circlet()
	_offset = Vector2i(0, _swing())
	_grimoire()
	_offset = Vector2i.ZERO
	_outline()


func _swing() -> int:
	return [0, -1, 0, 1][_pose - 2] if _pose >= 2 else 0


func _px(x: int, y: int, color: Color) -> void:
	x += _offset.x
	y += _offset.y
	if x >= 0 and x < W and y >= 0 and y < H:
		img.set_pixel(x, y, color)


func _rect(x0: int, y0: int, x1: int, y1: int, color: Color) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			_px(x, y, color)


func _poly(coords: PackedInt32Array, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(0, coords.size(), 2):
		points.append(Vector2(coords[i], coords[i + 1]))
	for y in H:
		for x in W:
			if Geometry2D.is_point_in_polygon(Vector2(x, y), points):
				_px(x, y, color)


func _cape() -> void:
	# 肩部固定、布料末端反向擺動，兩條腿之間保留清楚的負空間。
	var sway := -_swing()
	_poly([15,29, 30,30, 34-sway,40, 28,39, 26,42, 19,40, 13,42, 14,38, 7+sway*2,39, 11+sway,34], RUBY_DARK)
	_poly([15,31, 20,32, 16,39, 10+sway*2,38], RUBY)
	_poly([28,32, 31,34, 33-sway,39, 28,38], RUBY)
	_rect(12+sway, 37, 16+sway, 37, GOLD)
	_px(11+sway, 38, GOLD_LIGHT)


func _legs() -> void:
	var phase := _pose - 2
	var lx := 0
	var ly := 0
	var ry := 0
	if phase >= 0:
		lx = [-1, 0, 1, 0][phase]
		ly = [0, 0, -2, -1][phase]
		ry = [-2, -1, 0, 0][phase]
	_rect(18+lx, 39, 20+lx, 43+ly, IVORY_FOLD)
	_rect(25-lx, 39, 27-lx, 43+ry, IVORY_FOLD)
	_rect(17+lx, 43+ly, 21+lx, 45+ly, NAVY)
	_rect(25-lx, 43+ry, 29-lx, 45+ry, NAVY)
	_rect(18+lx, 43+ly, 20+lx, 43+ly, GOLD)
	_rect(25-lx, 43+ry, 27-lx, 43+ry, GOLD)
	_px(17+lx, 44+ly, BLUE_LIGHT)
	_px(25-lx, 44+ry, BLUE_LIGHT)


func _body() -> void:
	_poly([18,30, 28,30, 30,39, 26,40, 24,38, 21,40, 16,39], NAVY)
	_poly([18,30, 23,31, 21,39, 18,38], IVORY)
	_poly([26,31, 28,31, 29,39, 25,40, 25,35], IVORY)
	_rect(18, 38, 20, 39, GOLD)
	_rect(26, 39, 28, 40, GOLD)
	_rect(20, 35, 27, 36, GOLD_EDGE)
	_rect(22, 35, 25, 36, GOLD)
	_px(23, 35, GOLD_LIGHT)
	_rect(21, 31, 25, 32, GOLD)
	_rect(22, 32, 24, 33, RUBY)
	_px(23, 32, GOLD_LIGHT)
	# 細小身體的肩甲與袖子只用幾個清楚色塊，不把全身塗成同一色。
	_poly([14,31, 18,30, 19,33, 16,35, 13,33], GOLD)
	_rect(14, 31, 17, 31, GOLD_LIGHT)
	_rect(14, 34-_swing(), 16, 37-_swing(), BLUE)
	_rect(14, 37-_swing(), 16, 39-_swing(), SKIN)
	_px(16, 39-_swing(), SKIN_EDGE)
	_poly([28,31, 32,32, 33,35, 29,35], GOLD)
	_rect(31, 35, 35, 37, BLUE)
	_rect(34, 35, 39, 36, SKIN)
	if _facing == 1:
		_rect(18, 32, 28, 39, NAVY)
		_poly([23,32, 26,35, 23,38, 20,35], GOLD)
		_px(23, 35, RUBY)
	if _pose == 1:
		_rect(21, 31, 25, 31, IVORY)
		_rect(22, 32, 24, 32, GOLD)


func _hair_back() -> void:
	_poly([11,12, 14,8, 19,6, 25,6, 31,9, 34,14, 35,23, 32,29, 34,32, 29,31, 30,34,
		25,32, 21,30, 17,34, 13,33, 11,35, 10,29, 7,30, 10,24, 8,19], HAIR_BLUE)
	_poly([11,14, 15,9, 23,7, 30,10, 33,16, 31,25, 28,29, 24,28, 18,31, 13,30, 12,25, 10,25], HAIR_LILAC)
	_poly([13,12, 19,8, 25,8, 30,11, 30,17, 25,21, 17,21, 12,25, 11,20], HAIR_CREAM)
	_poly([14,11, 20,7, 26,8, 28,11, 20,12, 16,15, 13,15], HAIR_WHITE)


func _face() -> void:
	_poly([16,16, 29,15, 32,20, 31,27, 28,30, 20,30, 16,28, 14,23], SKIN)
	_rect(20, 30, 27, 30, SKIN_EDGE)
	_rect(15, 24, 16, 26, SKIN_EDGE)
	for x in [18, 28]:
		if _pose == 1:
			_rect(x-1, 24, x+1, 24, INK)
		else:
			_rect(x, 21, x+1, 25, INK)
			_px(x-1, 21, INK)
			_px(x, 22, HAIR_WHITE)
			_rect(x, 24, x+1, 25, IRIS)
			_px(x, 24, GEM)
	_rect(16, 26, 18, 26, BLUSH)
	_rect(29, 26, 31, 26, BLUSH)
	_rect(22, 27, 25, 28, RUBY_DARK)
	_rect(23, 28, 25, 28, RUBY)
	_px(22, 27, HAIR_WHITE)


func _bangs() -> void:
	# 分叉、偏心的髮束；大色塊的交界就是髮型，不用平滑漸層。
	_poly([12,13, 15,9, 25,9, 31,12, 28,17, 24,20, 25,15, 21,20, 20,16, 16,19, 16,23, 12,26, 13,20, 10,21], HAIR_CREAM)
	_poly([14,12, 18,10, 24,10, 22,14, 18,17, 18,13, 14,17, 12,17], HAIR_WHITE)
	_poly([25,11, 30,12, 32,16, 34,19, 32,24, 30,27, 30,20, 27,19, 28,15, 24,18], HAIR_WHITE)
	_poly([12,23, 15,21, 14,29, 17,31, 12,31, 10,33], HAIR_LILAC)
	_px(21, 18, HAIR_LILAC)
	_px(24, 19, HAIR_BLUE)
	_px(31, 24, HAIR_CREAM)


func _back_detail() -> void:
	_poly([12,14, 17,10, 26,10, 31,13, 32,20, 28,24, 29,19, 25,23, 24,19, 20,25, 21,19, 16,24, 14,28, 11,28], HAIR_CREAM)
	_poly([14,13, 19,10, 26,11, 29,13, 24,14, 20,13, 16,16], HAIR_WHITE)
	_poly([14,25, 18,24, 18,30, 16,32, 12,32], HAIR_LILAC)
	_rect(18, 29, 26, 30, GOLD)
	_rect(21, 29, 23, 30, RUBY)
	_rect(20, 31, 22, 33, RUBY_DARK)


func _profile() -> void:
	_poly([22,17, 29,16, 31,20, 31,23, 34,24, 34,25, 31,26, 30,29, 24,30, 20,27], SKIN)
	_rect(25, 29, 29, 30, SKIN_EDGE)
	if _pose == 1:
		_rect(28, 24, 30, 24, INK)
	else:
		_rect(28, 21, 30, 21, INK)
		_rect(29, 22, 30, 25, INK)
		_px(29, 22, HAIR_WHITE)
		_rect(29, 24, 30, 25, IRIS)
	_rect(27, 26, 29, 26, BLUSH)
	_rect(31, 27, 32, 28, RUBY_DARK)
	_poly([12,12, 17,9, 25,9, 31,14, 29,18, 26,16, 24,20, 23,16, 20,22, 18,27, 16,31, 12,30, 11,25], HAIR_CREAM)
	_poly([13,13, 18,10, 25,10, 27,13, 22,14, 20,18, 18,15, 14,19], HAIR_WHITE)
	_poly([12,24, 16,23, 17,29, 20,30, 16,33, 12,31, 10,32], HAIR_LILAC)
	_rect(21, 26, 22, 28, GOLD)
	_px(21, 29, GEM)


func _circlet() -> void:
	# 斜戴的金屬額冠與一側羽飾，剪影和原本的大法師帽不同。
	_poly([10,11, 14,10, 20,11, 25,10, 31,12, 32,14, 25,13, 19,14, 12,13], NAVY)
	_rect(14, 11, 19, 11, GOLD)
	_rect(20, 12, 24, 12, GOLD)
	_poly([26,8, 29,10, 29,13, 26,15, 24,12, 24,10], GOLD)
	_rect(26, 10, 27, 12, RUBY_DARK)
	_px(26, 10, RUBY)
	_px(25, 9, GOLD_LIGHT)
	# 分段羽毛，暖白、灰紫與金座各有自己的塊面。
	_poly([12,12, 8,10, 5,7, 3,4, 7,5, 11,8, 10,4, 14,7, 16,10], HAIR_LILAC)
	_poly([4,4, 7,5, 9,7, 8,8, 5,6], HAIR_WHITE)
	_poly([10,4, 13,7, 13,9, 10,7], IVORY)
	_rect(11, 10, 14, 11, GOLD)
	_px(12, 10, GOLD_LIGHT)
	if _facing == 1:
		_rect(23, 11, 28, 12, GOLD_EDGE)
		_rect(26, 10, 27, 11, GOLD)


func _grimoire() -> void:
	# 超過半身高的厚書和懸浮水晶，是這位書騎士的辨識輪廓。
	_poly([38,16, 49,14, 52,16, 52,37, 41,40, 37,37], GOLD_EDGE)
	_poly([39,17, 49,16, 49,36, 40,38], IVORY)
	_rect(40, 19, 41, 35, IVORY_FOLD)
	_rect(40, 19, 40, 34, IVORY)
	_rect(42, 20, 48, 20, GOLD_LIGHT)
	_rect(42, 24, 48, 24, GOLD_LIGHT)
	_rect(42, 28, 48, 28, GOLD_LIGHT)
	_poly([42,16, 52,17, 52,37, 42,36], NAVY)
	_poly([43,18, 50,19, 50,34, 43,33], BLUE)
	_rect(42, 17, 43, 36, GOLD)
	_rect(51, 19, 52, 34, GOLD)
	_rect(44, 17, 50, 18, GOLD_LIGHT)
	_rect(44, 35, 51, 36, GOLD)
	_rect(40, 15, 43, 17, GOLD)
	_rect(50, 16, 53, 18, GOLD)
	_rect(40, 35, 43, 38, GOLD)
	_rect(50, 35, 53, 37, GOLD)
	_px(40, 15, GOLD_LIGHT)
	_px(52, 16, GOLD_LIGHT)
	_poly([47,22, 50,27, 47,32, 44,27], GOLD_LIGHT)
	_poly([47,25, 48,27, 47,29, 46,27], GEM_EDGE)
	_px(47, 26, GEM)
	# 水晶冠與懸浮的符文片。
	_poly([46,5, 50,10, 46,15, 42,10], GOLD_EDGE)
	_poly([46,6, 49,10, 46,13, 43,10], GEM)
	_poly([46,7, 46,12, 44,10], HAIR_WHITE)
	_px(48, 11, GEM_EDGE)
	_rect(43, 14, 49, 14, GOLD)
	_px(40, 9, GEM)
	_px(51, 6, GOLD_LIGHT)
	_rect(36, 34, 39, 36, SKIN)
	_px(38, 36, SKIN_EDGE)
	_rect(46, 38, 47, 41, RUBY_DARK)
	_px(47, 40, RUBY)


func _outline() -> void:
	var source: Image = img.duplicate()
	for y in H:
		for x in W:
			if source.get_pixel(x, y).a > 0.0:
				continue
			for offset in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
				var point: Vector2i = Vector2i(x, y) + offset
				if point.x < 0 or point.x >= W or point.y < 0 or point.y >= H:
					continue
				var neighbor := source.get_pixelv(point)
				if neighbor.a == 0.0:
					continue
				var desired := neighbor.darkened(0.5).lerp(INK, 0.55)
				var closest: Color = OUTLINE_COLORS[0]
				var best_distance := INF
				for candidate: Color in OUTLINE_COLORS:
					var difference := Vector3(desired.r - candidate.r, desired.g - candidate.g, desired.b - candidate.b)
					var distance := difference.length_squared()
					if distance < best_distance:
						closest = candidate
						best_distance = distance
				img.set_pixel(x, y, closest)
				break


func _orb() -> void:
	var orb := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	orb.fill(Color.TRANSPARENT)
	var rows := ["..####..", ".#bbaa#.", "#bbaaaa#", "#baaaaa#", "#aaaaac#", "#aaaacc#", ".#aacc#.", "..####.."]
	for y in 8:
		for x in 8:
			match rows[y][x]:
				"#": orb.set_pixel(x, y, Color(0.12, 0.1, 0.16))
				"a": orb.set_pixel(x, y, Color(0.86, 0.86, 0.86))
				"b": orb.set_pixel(x, y, Color.WHITE)
				"c": orb.set_pixel(x, y, Color(0.6, 0.6, 0.6))
	orb.save_png(OUT + "orb.png")
