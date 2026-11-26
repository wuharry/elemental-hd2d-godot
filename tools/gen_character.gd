extends SceneTree
## 原創深紫法師。以可獨立移動的像素層繪圖；每格共用色盤，頭髮、袍袖與鞋各自轉面。
## godot --headless --path . --script res://tools/gen_character.gd

const OUT := "res://assets/characters/"
const W := 56
const H := 48
const CharacterAnimation := preload("res://src/player/character_animation.gd")
const COLUMNS := CharacterAnimation.COLUMNS
const ROWS := CharacterAnimation.ROWS

# 墨色、黑髮、紫布、酒紅帽帶、皮革與金屬、膚色、琥珀。
const PALETTE := {
	"k": Color("#231b2b"), "i": Color("#312137"), "h": Color("#211d29"),
	"j": Color("#352d38"), "u": Color("#504452"),
	"a": Color("#352041"), "v": Color("#51305e"), "p": Color("#734485"),
	"r": Color("#571c3b"), "s": Color("#8a2947"), "t": Color("#bc3f53"),
	"d": Color("#593241"), "b": Color("#8f5144"),
	"g": Color("#c8844e"), "y": Color("#f4be6b"),
	"e": Color("#57313c"), "x": Color("#db977f"), "f": Color("#f5bca3"),
	"n": Color("#ffe2c6"), "o": Color("#ed812b"), "m": Color("#fff2b7"),
}

# 輪廓取自 B 草稿，以約 25 個原稿像素對一格，收進主角原有色票。
# 臉與去帽頭形分開於帽簷，手指遮在杖柄前方，雙腳可交替抬起。
const HAT := [
	"........iiiii",
	".......pppppppi",
	"......ipvvvppppi",
	"......ivvvvvvppppi",
	".....ipvvvvvvvpppppi",
	".....ivvvvvivvvvppppi",
	"....ivviiiiivvvppvvvv",
	"....ivi..iivvvppvvvvvvi",
	"....ii....ivvvpvvvvvvvvi",
	"..........ivvvvvvvvvvvvvi",
	"..........ivvvvvmyvvkssssk",
	".........ivvvvvmyyytssssssk..iiiii",
	"........kkkvvvyyrkmysskhvvpppppppppppi",
	".......kttssksrykkyrhkvvvpppppiiiiiippi",
	"......ksssssssrsyyrvvvvvpppiiiiaaaaaaipi",
	"......kssrrkkbskkkvvvppppiiiiiaaaaaaaai",
	"......ksrrrskkvvvvvppp.....iiiaaaaaaaai",
	".......kkkssvvvvvppp........iaaaaaaaa",
	".....ktsssskvvvvpp...........aaaaaaai",
	".....stskssvvppp.............aaaaaai",
	".....ssksssppp................aaaai",
	".....skksss...................aaai",
	"..ippavkkks...................ai",
	".iipppi.......................i",
	".ipppi",
	"ipvvvi",
	"ivvvii",
	"iivvii",
	"..iii",
]

# 帽簷原本只畫前緣，頭與帽子分開延遲後，兩者之間會露出背景。
# 帽內襯先畫在頭髮後面；只補帽簷包圍的內側，不封住帽尖彎鉤的留白。
const HAT_LINING := [
	"....................aaaaaaaaaaa",
	"...................aaaaaaaaaaaa",
	"..................aaaaaaaaaaaaa",
	"................aaaaaaaaaaaaaaa",
	"..............aaaaaaaaaaaaaaaaa",
	"...........aaaaaaaaaaaaaaaaaaaa",
	"...........aaaaaaaaaaaaaaaaaaaa",
	".......aaaaaaaaaaaaaaaaaaaaaaaa",
]

const FRONT_HEAD := [
	"........hhhhjjjjjhjjh",
	".....hhhhjjjjhhhjjhjuh",
	"...hhhhhhhhhhhjjjuhjuuh",
	".hhhhhhhhhhhjhjjuuhjjuh",
	"hhhhhhhhhhhjhhujuuhhjuuh",
	"hhhhhhhhhhjjhhjjjjhhjjjh",
	"hhhhhhhjjjjjnhjhjjhhjjjh",
	"hhhhhhjjjjjnnjjhjjhnjhjh",
	"hhhjjhjjjhhhhhnjjhnnjhjh",
	"hjjjhhhjjhhkkknhnnnhhhjh",
	"hjhjnnhhjhnnrrnnnnrhhjh",
	"hjhjnxhhjhnnrrnnnnrhjjj",
	"hjhjhnhhjjnnssnnnnshjhj",
	".jhjhhhjhjxfnnnnnnxhjhj",
	".hhhjhhjjhhfnnnnnnxhjhh",
	"...hjjhhhjhhhhhhhhhjhh",
	".....h..hh.........h",
]

const BACK_HEAD := [
	"........hhhhhhhhhhhh",
	".....hhhhjjjjjjjuujjhh",
	"...hhhhjjjjjjjuuuujjjhh",
	"..hhhjjjjjjuuuuujuujjjh",
	".hhhjjuujuuuuujjjjujjjjh",
	"hhhjjjuuuuuujjjjjjujjjjh",
	"hhhjjuuujjjjjjjjhjuujjjh",
	"hhjjjuujjjjjjjjjjhjujjjh",
	"hhjjjujjjjjjjhjjjhjjjjjh",
	"hhjjjjjjjjjjjhjjjhhjjjjh",
	"hhjjjhjjjjjjhhjjjhhjjjjh",
	"hhjjjhjjjjjjhhjjjjhhjjjh",
	".hjjjhhjjjjjhhjjjjhhjjjh",
	".hhjjhhjjjjhhhhjjjhhhjjh",
	"..hhjjhhjjjhhhjjjjhhjhh",
	"...hhjjhhjhhhhjjjhhhhh",
	".....hhhhhh..hhh...hh",
]

const SIDE_HEAD := [
	"........hhhhhhhhhhhh",
	".....hhhhjjjjjjjuujjhh",
	"...hhhhjjjjjjjuuuujjjhh",
	"..hhhjjjjjjuuuuujjujjjh",
	".hhhjjjjjjuuujjjhjjujjjh",
	"hhhhjjjjjuuujjjjhjjjjujh",
	"hhhjjjjjuujjjjjhhjjjjjjh",
	"hhhjjuujjjjjjjhhjjjjnjhh",
	"hhhjjujjjjjhjjhhjjjnnhh",
	"hhjjjjjjhjjhhjhhjjnnnhh",
	"hhjjjjjhjjjhnnhhjnnhhrh",
	"hhjjjjhhjjjhnxhhjnnnrrn",
	".hjjjjhhjjjhhnhhjnfnrrnn",
	".hhjjjhhjjjjhhhhjnnnnnnh",
	"..hhjjhhhjjjhhhhjhfnnnx",
	"...hhjjhhjjhhhjhhhhhxh",
	".....hhh.hhhh..hh",
]

const FRONT_ROBE := [
	".....avvymha",
	"...vvvvvkykvva",
	"..vyyhssrssyya",
	"..pvhssrssavvh",
	"..pvvhsrshvvva",
	"..vvppavvvvaav",
	"..vvppvvyvvvvv",
	"hgyyyyyyyyyygh",
	".hhh..hhh..hh",
]

const BACK_ROBE := [
	".....ahvvva",
	"...avppvvvva",
	"..vvvppppvvvva",
	"..vppvvvvvppva",
	"..vvvaaaaavvva",
	"..vvvvavavvvva",
	"..vvvavvavvvva",
	".ayyyvvvavvyyya",
	"..hhyyyyyyyhhh",
]

const SIDE_ROBE := [
	"......avyya",
	"....vppvvygga",
	"...vvppavvhsv",
	"...vvvaavvvss",
	"...vvvaavvvvha",
	"...vvvavvvvyva",
	"..avvvaavvvyva",
	"..ayyvvvyyvyya",
	"...hyyyyyyyhh",
]

const STAFF := [
	"....d",
	"....myd",
	"...dmyyd",
	"...dym.d",
	"...ddmy",
	"....dmyy.d",
	"..y.ymoy..md",
	"..d.ymoo..yd",
	".dm.yoood..gd",
	".dy.yoood..gd",
	"dmy..oggg.yd",
	"dgyy..dd.yyd",
	"..dyygymmyd",
	"....dgoygd",
	".....dgyd",
	".......dyk",
	"......kyyk",
	".......kbk",
	"........yyk",
	"........kbk",
	".........bb",
	".........kbk",
	"..........bk",
	"..........bb",
	"..........kb",
	"...........bk",
	"...........bb",
	"...........kb",
	"............bk",
	"............bk",
	"............bb",
	"............kb",
	"............kbk",
	".............bk",
	".............bb",
	".............kb",
	".............kb",
	".............kb",
	"..............bk",
]

const GRIP := [
	"....hhvv",
	"knxkyvva",
	"knnkyav",
	"kfxkyvv",
	"...kyyv",
	"....hha",
]

const FAR_SLEEVE := [
	"avv",
	"vpva",
	"vpya",
	"hynn",
	".fn",
]

const BOOT := [
	".fn",
	"dgbd",
	"dbdd",
	"dddd",
]

const BACK_BOOT := [
	".dx",
	"dbdd",
	"dbdd",
	"dddd",
]

func _init() -> void:
	for directory: String in [OUT, "res://test_output"]:
		var result := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
		if result != OK:
			printerr("Cannot create ", directory, ": ", error_string(result))
			quit(1)
			return

	var atlas := Image.create_empty(W * COLUMNS, H * ROWS, false, Image.FORMAT_RGBA8)
	var atlas_n := Image.create_empty(W * COLUMNS, H * ROWS, false, Image.FORMAT_RGB8)
	var atlas_m := Image.create_empty(W * COLUMNS, H * ROWS, false, Image.FORMAT_RGBA8)
	var hands := Image.create_empty(W * COLUMNS, H * ROWS, false, Image.FORMAT_RGBA8)
	var hands_n := Image.create_empty(W * COLUMNS, H * ROWS, false, Image.FORMAT_RGB8)
	var hands_m := Image.create_empty(W * COLUMNS, H * ROWS, false, Image.FORMAT_RGBA8)
	var combined := Image.create_empty(W * COLUMNS, H * ROWS, false, Image.FORMAT_RGBA8)
	atlas_n.fill(Color(0.5, 0.5, 1.0))
	atlas_m.fill(Color(0.86, 0.0, 0.0, 0.0))
	hands_n.fill(Color(0.5, 0.5, 1.0))
	hands_m.fill(Color(0.86, 0.0, 0.0, 0.0))
	for facing in ROWS:
		for pose in COLUMNS:
			var region := Rect2i(0, 0, W, H)
			var origin := Vector2i(pose * W, facing * H)
			var body_layers := draw_body_maps(facing, pose)
			var hand_layers := draw_hand_maps(facing, pose)
			var frame := draw_frame(facing, pose)
			atlas.blit_rect(body_layers["albedo"], region, origin)
			atlas_n.blit_rect(body_layers["normal"], region, origin)
			atlas_m.blit_rect(_apply_rim_mask(body_layers["material"], frame, body_layers["face_mask"]), region, origin)
			hands.blit_rect(hand_layers["albedo"], region, origin)
			hands_n.blit_rect(hand_layers["normal"], region, origin)
			hands_m.blit_rect(_apply_rim_mask(hand_layers["material"], frame, {}), region, origin)
			combined.blit_rect(frame, region, origin)

	var weapon_maps := draw_weapon_maps()
	var weapon_m := _apply_rim_mask(weapon_maps["material"], weapon_maps["albedo"], {})
	var idle := combined.get_region(Rect2i(0, 0, W, H))
	var front: Image = idle.duplicate()
	front.resize(W * 10, H * 10, Image.INTERPOLATE_NEAREST)
	var preview: Image = combined.duplicate()
	preview.resize(W * COLUMNS * 4, H * ROWS * 4, Image.INTERPOLATE_NEAREST)
	var normal_preview: Image = atlas_n.duplicate()
	normal_preview.resize(W * COLUMNS * 2, H * ROWS * 2, Image.INTERPOLATE_NEAREST)
	var outputs := {
		OUT + "mage_idle.png": idle,
		OUT + "mage_atlas.png": atlas,
		OUT + "mage_atlas_n.png": atlas_n,
		OUT + "mage_atlas_m.png": atlas_m,
		OUT + "mage_hand_atlas.png": hands,
		OUT + "mage_hand_atlas_n.png": hands_n,
		OUT + "mage_hand_atlas_m.png": hands_m,
		OUT + "mage_staff.png": weapon_maps["albedo"],
		OUT + "mage_staff_n.png": weapon_maps["normal"],
		OUT + "mage_staff_m.png": weapon_m,
		"res://test_output/mage_front_preview.png": front,
		"res://test_output/mage_unhatted.png": draw_frame(0, 0, false),
		"res://test_output/mage_composed_atlas.png": combined,
		"res://test_output/mage_preview.png": preview,
		"res://test_output/mage_normal_preview.png": normal_preview,
	}
	for path: String in outputs:
		var output: Image = outputs[path]
		var result := output.save_png(path)
		if result != OK:
			printerr("Cannot save ", path, ": ", error_string(result))
			quit(1)
			return
	print("Character atlas: ", atlas.get_size(), " (", COLUMNS * ROWS, " frames + normal/material maps)")
	quit()


static func _pack_normal(n: Vector3) -> Color:
	var u := n.normalized()
	return Color(u.x * 0.5 + 0.5, u.y * 0.5 + 0.5, u.z * 0.5 + 0.5, 1.0)


static func _material_for(symbol: String, kind: String, local_y: int) -> Color:
	# R = roughness, G = metallic, B = extra interior rim weight, A = self-emission
	var rough := 0.86
	var metal := 0.0
	var rim_bias := 0.0
	var emission := 0.0
	match symbol:
		"y", "g":
			rough = 0.26
			metal = 0.68
			rim_bias = 0.15
		"m":
			if kind == "staff" and local_y <= 14:
				rough = 0.14
				metal = 0.12
				emission = 0.85
			else:
				rough = 0.22
				metal = 0.72
				rim_bias = 0.15
		"o":
			rough = 0.14
			metal = 0.05
			emission = 1.0 if kind == "staff" else 0.0
		"b", "d":
			rough = 0.62
		"h", "j", "u":
			rough = 0.66
		_:
			rough = 0.86
	if kind == "hat" and (symbol == "p" or symbol == "v") and local_y >= 10 and local_y <= 17:
		rim_bias = maxf(rim_bias, 0.22)
	if kind == "staff" and local_y <= 15 and symbol in ["y", "g"]:
		emission = maxf(emission, 0.16)
	return Color(rough, metal, rim_bias, emission)


static func _row_span(row: String) -> Vector2:
	var left := -1
	var right := -1
	for x in row.length():
		if row.substr(x, 1) != ".":
			if left < 0:
				left = x
			right = x
	if left < 0:
		return Vector2(0.0, 1.0)
	return Vector2((left + right) * 0.5, maxf(1.0, (right - left) * 0.5 + 0.5))


static func _part_normal(kind: String, symbol: String, x: int, y: int, rows: Array, facing: int) -> Vector3:
	var h := maxf(1.0, float(rows.size() - 1))
	var span := _row_span(rows[y])
	var u := clampf((float(x) - span.x) / span.y, -1.0, 1.0)
	var v := clampf(1.0 - 2.0 * float(y) / h, -1.0, 1.0)
	match kind:
		"hat_lining":
			return Vector3(u * 0.35, -0.58, 0.74)
		"hat":
			if y >= 14 and symbol == "a":
				return Vector3(u * 0.32, -0.52, 0.78)
			if y >= 12 and x >= 22:
				return Vector3(0.28 + u * 0.22, 0.58, 0.74)
			if y >= 12 and x <= 10:
				return Vector3(-0.38, 0.42, 0.82)
			if symbol in ["r", "s", "t", "y", "m"]:
				return Vector3(u * 0.55, 0.12, 0.86)
			return Vector3(u * 0.78, 0.28 + (1.0 - absf(u)) * 0.22, maxf(0.28, 1.0 - absf(u) * 0.55))
		"head":
			var cx := span.x
			if facing == 2:
				cx = span.x + 1.8
			var hu := clampf((float(x) - cx) / maxf(4.0, span.y), -1.0, 1.0)
			if facing != 1 and symbol in ["n", "f", "x", "e", "r", "s"] and y >= 7:
				# 臉部保持柔和微球面，避免卡通 Q 版臉出現生硬暗斑。
				return Vector3(hu * 0.36, v * 0.2, 0.91)
			var boost := 0.16 if symbol == "u" else 0.0
			return Vector3(hu * 0.74, v * 0.52 + boost, maxf(0.32, 1.0 - absf(hu) * 0.48))
		"robe":
			var ny := lerpf(0.38, -0.14, float(y) / h)
			return Vector3(u * 0.76, ny, maxf(0.36, 1.0 - absf(u) * 0.48))
		"sleeve":
			return Vector3(u * 0.68, v * 0.32, 0.68)
		"grip":
			return Vector3(u * 0.56, v * 0.44, 0.72)
		"boot":
			return Vector3(u * 0.62, 0.26, 0.74)
		"staff":
			if y <= 14:
				var cu := clampf((float(x) - 6.0) / 5.5, -1.0, 1.0)
				var cv := clampf((8.5 - float(y)) / 7.0, -1.0, 1.0)
				return Vector3(cu * 0.74, cv * 0.58, 0.55)
			return Vector3(u * 0.72, 0.15, 0.68)
		_:
			return Vector3(0.0, 0.0, 1.0)


static func _stamp_maps(albedo: Image, normal: Image, material: Image, rows: Array, origin: Vector2i,
		mirrored: bool, kind: String, facing: int, face_mask: Dictionary,
		tail_row := -1, tail_shift := Vector2i.ZERO) -> void:
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var symbol := row.substr(x, 1)
			if symbol == ".":
				continue
			var shift := tail_shift if tail_row >= 0 and y >= tail_row else Vector2i.ZERO
			var px := origin.x + x + shift.x
			var py := origin.y + y + shift.y
			if mirrored:
				px = W - 1 - px
			albedo.set_pixel(px, py, PALETTE[symbol])
			var n := _part_normal(kind, symbol, x, y, rows, facing)
			if mirrored:
				n.x = -n.x
			normal.set_pixel(px, py, _pack_normal(n))
			material.set_pixel(px, py, _material_for(symbol, kind, y))
			if kind == "head" and facing != 1 and symbol in ["n", "f", "x", "e", "r", "s"] and y >= 7:
				face_mask[Vector2i(px, py)] = true


## 依實際合成輪廓標記外緣 1–2 px 的輪廓光權重（B 通道），臉部刻意壓低避免洗掉五官。
static func _apply_rim_mask(material: Image, silhouette: Image, face_mask: Dictionary) -> Image:
	var out: Image = material.duplicate()
	var dirs4 := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	for y in H:
		for x in W:
			if silhouette.get_pixel(x, y).a < 0.5:
				continue
			var edge1 := false
			var edge2 := false
			for d: Vector2i in dirs4:
				var p1 := Vector2i(x, y) + d
				if not Rect2i(0, 0, W, H).has_point(p1) or silhouette.get_pixelv(p1).a < 0.5:
					edge1 = true
					break
			if not edge1:
				for dy in range(-2, 3):
					for dx in range(-2, 3):
						if absi(dx) + absi(dy) != 2:
							continue
						var p2 := Vector2i(x + dx, y + dy)
						if not Rect2i(0, 0, W, H).has_point(p2) or silhouette.get_pixelv(p2).a < 0.5:
							edge2 = true
							break
					if edge2:
						break
			var m := out.get_pixel(x, y)
			var rim := 1.0 if edge1 else (0.42 if edge2 else m.b)
			if face_mask.has(Vector2i(x, y)):
				rim = minf(rim, 0.14)
			out.set_pixel(x, y, Color(m.r, m.g, rim, m.a))
	return out


static func _stamp(img: Image, rows: Array, origin: Vector2i, mirrored: bool,
		tail_row := -1, tail_shift := Vector2i.ZERO) -> void:
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var symbol := row.substr(x, 1)
			if symbol == ".":
				continue
			var shift := tail_shift if tail_row >= 0 and y >= tail_row else Vector2i.ZERO
			var px := origin.x + x + shift.x
			if mirrored:
				px = W - 1 - px
			img.set_pixel(px, origin.y + y + shift.y, PALETTE[symbol])


static func draw_body_maps(facing: int, pose: int, wearing_hat := true) -> Dictionary:
	var img := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	var nrm := Image.create_empty(W, H, false, Image.FORMAT_RGB8)
	var mat := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	nrm.fill(Color(0.5, 0.5, 1.0))
	mat.fill(Color(0.86, 0.0, 0.0, 0.0))
	var face_mask := {}
	var back := facing == 1
	var side := facing == 2
	var walking := pose >= CharacterAnimation.WALK_START
	var step := pose - CharacterAnimation.WALK_START
	var body := Vector2i.ZERO
	var hat := Vector2i.ZERO
	var hem_sway := 0
	var hand_swing := 0
	var far_foot := Vector2i(27, 43)
	var near_foot := Vector2i(32, 43)
	if walking:
		body = Vector2i([0, 1, 1, 0, -1, -1][step], [0, -1, -2, 0, -1, -2][step])
		hat = Vector2i([-1, 0, 1, 1, 0, -1][step], [-2, 0, -1, -2, 0, -1][step])
		hem_sway = [1, 1, 0, -1, -1, 0][step]
		hand_swing = [1, 2, 1, -1, -2, -1][step]
		# 前後腳交替跨出衣襬，接地與騰空各有清楚的鞋底。
		far_foot += Vector2i([-2, -1, 0, 0, -1, -2][step], [0, -1, -3, -2, -2, -1][step])
		near_foot += Vector2i([0, 1, 2, 2, 1, 0][step], [-2, -2, -1, 0, -1, -3][step])
	else:
		body.y = [0, -1, 0, 0][pose]
		hat.y = [0, 0, -1, 0][pose]
	# 腿從袍內伸到靴口，不能只留下獨立浮動的鞋子。
	for foot: Vector2i in [far_foot, near_foot]:
		for y in range(40 + body.y, foot.y + 1):
			_stamp_maps(img, nrm, mat, ["ddd"], Vector2i(foot.x + 1, y), back, "boot", facing, face_mask)
	var boot: Array = BACK_BOOT if back else BOOT
	_stamp_maps(img, nrm, mat, boot, far_foot, back, "boot", facing, face_mask)
	_stamp_maps(img, nrm, mat, boot, near_foot, back, "boot", facing, face_mask)
	_stamp_maps(img, nrm, mat, FAR_SLEEVE, Vector2i(35 + hand_swing - int(side), 39) + body, back, "sleeve", facing, face_mask)
	# 近袖從肩到握手有實際布料重疊；手與武器的延遲不能把袖口拉斷。
	var grip_shift := CharacterAnimation.staff_offset(pose)
	var sleeve_origin := Vector2i(23, 36) + grip_shift
	_stamp_maps(img, nrm, mat, ["aavva", "avvva", "avvva", ".avva"], sleeve_origin, back, "sleeve", facing, face_mask)
	_stamp_maps(img, nrm, mat, ["avvva", "avvva", ".vvva"], Vector2i(25, 35) + body, back, "sleeve", facing, face_mask)
	# 髮尾移動時仍遮在肩部布料前，不讓髮束間隙穿過領口。
	_stamp_maps(img, nrm, mat, ["aaaa", "avva", "avva"], Vector2i(34, 34) + body, back, "robe", facing, face_mask)
	var robe: Array = [FRONT_ROBE, BACK_ROBE, SIDE_ROBE][facing]
	_stamp_maps(img, nrm, mat, robe, Vector2i(24, 35) + body, back, "robe", facing, face_mask, 6, Vector2i(hem_sway, 0))
	var head: Array = [FRONT_HEAD, BACK_HEAD, SIDE_HEAD][facing]
	var head_origin := Vector2i(20, 19) + body
	if back and pose == CharacterAnimation.BLINK_FRAME:
		head_origin.y += 1
	if wearing_hat:
		_stamp_maps(img, nrm, mat, HAT_LINING, Vector2i(14, 19) + hat, back, "hat_lining", facing, face_mask)
	_stamp_maps(img, nrm, mat, head, head_origin, back, "head", facing, face_mask, 15, Vector2i(-hem_sway, 0))
	if pose == CharacterAnimation.BLINK_FRAME and not back:
		# 眨眼只覆寫臉部顏色，保留底下平滑的頭部法線，避免眼皮處出現法線噪點。
		if side:
			_stamp(img, ["nnn", "err", "nnn"], Vector2i(39, 29) + body, back)
		else:
			_stamp(img, ["nn", "er", "nn"], Vector2i(32, 29) + body, back)
			_stamp(img, ["n", "r", "n"], Vector2i(38, 29) + body, back)
	if wearing_hat:
		_stamp_maps(img, nrm, mat, HAT, Vector2i(14, 3) + hat, back, "hat", facing, face_mask)
		if back:
			# 背面帽帶繞過帽冠，金扣只在正側面出現。
			_stamp_maps(img, nrm, mat, ["...v", "..vvs", ".svvss", "ssssss", "ssssss", ".rrr"],
				Vector2i(27, 13) + hat, true, "hat", facing, face_mask)
	return {"albedo": img, "normal": nrm, "material": mat, "face_mask": face_mask}


# 眼睫位在輪廓內，閉眼不改臉頰邊界。接地格的靴底仍在 y46。
static func draw_body_frame(facing: int, pose: int, wearing_hat := true) -> Image:
	return draw_body_maps(facing, pose, wearing_hat)["albedo"]


static func draw_hand_maps(facing: int, pose: int) -> Dictionary:
	var img := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	var nrm := Image.create_empty(W, H, false, Image.FORMAT_RGB8)
	var mat := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	nrm.fill(Color(0.5, 0.5, 1.0))
	mat.fill(Color(0.86, 0.0, 0.0, 0.0))
	_stamp_maps(img, nrm, mat, GRIP, Vector2i(19, 36) + CharacterAnimation.staff_offset(pose), facing == 1, "grip", facing, {})
	return {"albedo": img, "normal": nrm, "material": mat}


static func draw_hand_frame(facing: int, pose: int) -> Image:
	return draw_hand_maps(facing, pose)["albedo"]


static func draw_weapon_maps(facing := 0, pose := 0) -> Dictionary:
	var img := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	var nrm := Image.create_empty(W, H, false, Image.FORMAT_RGB8)
	var mat := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	nrm.fill(Color(0.5, 0.5, 1.0))
	mat.fill(Color(0.86, 0.0, 0.0, 0.0))
	_stamp_maps(img, nrm, mat, STAFF, Vector2i(8, 7) + CharacterAnimation.staff_offset(pose), facing == 1, "staff", facing, {})
	return {"albedo": img, "normal": nrm, "material": mat}


static func draw_weapon_frame(facing := 0, pose := 0) -> Image:
	return draw_weapon_maps(facing, pose)["albedo"]


# 合成只供靜態參考與預覽；遊戲使用身體、可替換武器、握手三個獨立圖層。
static func draw_frame(facing: int, pose: int, wearing_hat := true) -> Image:
	var img := draw_body_frame(facing, pose, wearing_hat)
	var region := Rect2i(0, 0, W, H)
	img.blend_rect(draw_weapon_frame(facing, pose), region, Vector2i.ZERO)
	img.blend_rect(draw_hand_frame(facing, pose), region, Vector2i.ZERO)
	return img
