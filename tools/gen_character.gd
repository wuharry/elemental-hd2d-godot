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
	var hands := Image.create_empty(W * COLUMNS, H * ROWS, false, Image.FORMAT_RGBA8)
	var combined := Image.create_empty(W * COLUMNS, H * ROWS, false, Image.FORMAT_RGBA8)
	for facing in ROWS:
		for pose in COLUMNS:
			var region := Rect2i(0, 0, W, H)
			var origin := Vector2i(pose * W, facing * H)
			atlas.blit_rect(draw_body_frame(facing, pose), region, origin)
			hands.blit_rect(draw_hand_frame(facing, pose), region, origin)
			combined.blit_rect(draw_frame(facing, pose), region, origin)

	var idle := combined.get_region(Rect2i(0, 0, W, H))
	var front: Image = idle.duplicate()
	front.resize(W * 10, H * 10, Image.INTERPOLATE_NEAREST)
	var preview: Image = combined.duplicate()
	preview.resize(W * COLUMNS * 4, H * ROWS * 4, Image.INTERPOLATE_NEAREST)
	var outputs := {
		OUT + "mage_idle.png": idle,
		OUT + "mage_atlas.png": atlas,
		OUT + "mage_hand_atlas.png": hands,
		OUT + "mage_staff.png": draw_weapon_frame(),
		"res://test_output/mage_front_preview.png": front,
		"res://test_output/mage_unhatted.png": draw_frame(0, 0, false),
		"res://test_output/mage_composed_atlas.png": combined,
		"res://test_output/mage_preview.png": preview,
	}
	for path: String in outputs:
		var output: Image = outputs[path]
		var result := output.save_png(path)
		if result != OK:
			printerr("Cannot save ", path, ": ", error_string(result))
			quit(1)
			return
	print("Character atlas: ", atlas.get_size(), " (", COLUMNS * ROWS, " frames)")
	quit()


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


# 眼睫位在輪廓內，閉眼不改臉頰邊界。接地格的靴底仍在 y46。
static func draw_body_frame(facing: int, pose: int, wearing_hat := true) -> Image:
	var img := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
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
			_stamp(img, ["ddd"], Vector2i(foot.x + 1, y), back)
	var boot: Array = BACK_BOOT if back else BOOT
	_stamp(img, boot, far_foot, back)
	_stamp(img, boot, near_foot, back)
	_stamp(img, FAR_SLEEVE, Vector2i(35 + hand_swing - int(side), 39) + body, back)
	# 近袖從肩到握手有實際布料重疊；手與武器的延遲不能把袖口拉斷。
	var grip_shift := CharacterAnimation.staff_offset(pose)
	var sleeve_origin := Vector2i(23, 36) + grip_shift
	_stamp(img, ["aavva", "avvva", "avvva", ".avva"], sleeve_origin, back)
	_stamp(img, ["avvva", "avvva", ".vvva"], Vector2i(25, 35) + body, back)
	# 髮尾移動時仍遮在肩部布料前，不讓髮束間隙穿過領口。
	_stamp(img, ["aaaa", "avva", "avva"], Vector2i(34, 34) + body, back)
	var robe: Array = [FRONT_ROBE, BACK_ROBE, SIDE_ROBE][facing]
	_stamp(img, robe, Vector2i(24, 35) + body, back, 6, Vector2i(hem_sway, 0))
	var head: Array = [FRONT_HEAD, BACK_HEAD, SIDE_HEAD][facing]
	var head_origin := Vector2i(20, 19) + body
	if back and pose == CharacterAnimation.BLINK_FRAME:
		head_origin.y += 1
	if wearing_hat:
		_stamp(img, HAT_LINING, Vector2i(14, 19) + hat, back)
	_stamp(img, head, head_origin, back, 15, Vector2i(-hem_sway, 0))
	if pose == CharacterAnimation.BLINK_FRAME and not back:
		if side:
			_stamp(img, ["nnn", "err", "nnn"], Vector2i(39, 29) + body, back)
		else:
			_stamp(img, ["nn", "er", "nn"], Vector2i(32, 29) + body, back)
			_stamp(img, ["n", "r", "n"], Vector2i(38, 29) + body, back)
	if wearing_hat:
		_stamp(img, HAT, Vector2i(14, 3) + hat, back)
		if back:
			# 背面帽帶繞過帽冠，金扣只在正側面出現。
			_stamp(img, ["...v", "..vvs", ".svvss", "ssssss", "ssssss", ".rrr"],
				Vector2i(27, 13) + hat, true)
	return img


static func draw_hand_frame(facing: int, pose: int) -> Image:
	var img := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	_stamp(img, GRIP, Vector2i(19, 36) + CharacterAnimation.staff_offset(pose), facing == 1)
	return img


static func draw_weapon_frame(facing := 0, pose := 0) -> Image:
	var img := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	_stamp(img, STAFF, Vector2i(8, 7) + CharacterAnimation.staff_offset(pose), facing == 1)
	return img


# 合成只供靜態參考與預覽；遊戲使用身體、可替換武器、握手三個獨立圖層。
static func draw_frame(facing: int, pose: int, wearing_hat := true) -> Image:
	var img := draw_body_frame(facing, pose, wearing_hat)
	var region := Rect2i(0, 0, W, H)
	img.blend_rect(draw_weapon_frame(facing, pose), region, Vector2i.ZERO)
	img.blend_rect(draw_hand_frame(facing, pose), region, Vector2i.ZERO)
	return img
