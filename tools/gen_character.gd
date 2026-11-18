extends SceneTree
## 原創深紫法師。以可獨立移動的像素層繪圖；每格共用色盤，頭髮、袍袖與鞋各自轉面。
## godot --headless --path . --script res://tools/gen_character.gd

const OUT := "res://assets/characters/"
const W := 56
const H := 48
const COLUMNS := 6
const ROWS := 3

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
	"hjjjhhhjjhhnhhnhnnnhhhjh",
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
	"..vyyhkskshyya",
	"..pvhhtsvssavh",
	"..pvvvhtkhshvv",
	"..vvpaavyvvaav",
	"..vvpavyayavvv",
	"hyyyygggyggyyh",
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
	"..m.ymoo..ym",
	".dm.yooog..gy",
	".yy.yooog..gy",
	"dmy..oggg.yd",
	"dgyy..dd.yyd",
	"..dyygymmyy",
	"....dgoygd",
	".....dgyy",
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
	"bgy",
	"bdg",
	"dddb",
]

const BACK_BOOT := [
	".dx",
	"dbb",
	"dbd",
	"dddb",
]

func _init() -> void:
	for directory: String in [OUT, "res://test_output"]:
		var result := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
		if result != OK:
			printerr("Cannot create ", directory, ": ", error_string(result))
			quit(1)
			return

	var atlas := Image.create(W * COLUMNS, H * ROWS, false, Image.FORMAT_RGBA8)
	for facing in ROWS:
		for pose in COLUMNS:
			var frame := draw_frame(facing, pose)
			atlas.blit_rect(frame, Rect2i(0, 0, W, H), Vector2i(pose * W, facing * H))

	var idle := atlas.get_region(Rect2i(0, 0, W, H))
	var front: Image = idle.duplicate()
	front.resize(W * 10, H * 10, Image.INTERPOLATE_NEAREST)
	var preview: Image = atlas.duplicate()
	preview.resize(W * COLUMNS * 4, H * ROWS * 4, Image.INTERPOLATE_NEAREST)
	var outputs := {
		OUT + "mage_idle.png": idle,
		OUT + "mage_atlas.png": atlas,
		"res://test_output/mage_front_preview.png": front,
		"res://test_output/mage_unhatted.png": draw_frame(0, 0, false),
		"res://test_output/mage_preview.png": preview,
	}
	for path: String in outputs:
		var output: Image = outputs[path]
		var result := output.save_png(path)
		if result != OK:
			printerr("Cannot save ", path, ": ", error_string(result))
			quit(1)
			return
	print("Character atlas: ", atlas.get_size(), " (18 frames)")
	quit()


static func _stamp(img: Image, rows: Array, origin: Vector2i, mirrored: bool) -> void:
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var symbol := row.substr(x, 1)
			if symbol == ".":
				continue
			var px := origin.x + x
			if mirrored:
				px = W - 1 - px
			img.set_pixel(px, origin.y + y, PALETTE[symbol])


# 眼睫位在輪廓內，閉眼不改臉頰邊界。
static func draw_frame(facing: int, pose: int, wearing_hat := true) -> Image:
	var img := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	var back := facing == 1
	var side := facing == 2
	var bob: int = [0, 0, 0, -1, 0, -1][pose]
	var stride: int = [0, 0, -1, -1, 1, 1][pose]
	var far_foot := Vector2i(27 + stride, 43 - int(pose == 3))
	var near_foot := Vector2i(32 - stride, 43 - int(pose == 5))
	var boot: Array = BACK_BOOT if back else BOOT
	_stamp(img, boot, far_foot, back)
	_stamp(img, boot, near_foot, back)
	var swing: int = [0, 0, 1, 0, -1, 0][pose]
	_stamp(img, FAR_SLEEVE, Vector2i(35 + swing - int(side), 39 + bob), back)
	var robe: Array = [FRONT_ROBE, BACK_ROBE, SIDE_ROBE][facing]
	_stamp(img, robe, Vector2i(24, 35 + bob), back)
	var head: Array = [FRONT_HEAD, BACK_HEAD, SIDE_HEAD][facing]
	var head_y := 19 + bob + int(back and pose == 1)
	_stamp(img, head, Vector2i(20, head_y), back)
	if pose == 1 and not back:
		if side:
			_stamp(img, ["nnn", "err", "nnn"], Vector2i(39, 29 + bob), back)
		else:
			_stamp(img, ["nn", "er", "nn"], Vector2i(32, 29 + bob), back)
			_stamp(img, ["n", "r", "n"], Vector2i(38, 29 + bob), back)
	if wearing_hat:
		_stamp(img, HAT, Vector2i(14, 3 + bob), back)
		if back:
			# 背面帽帶繞過帽冠，金扣只在正側面出現。
			_stamp(img, ["...v", "..vvs", ".svvss", "ssssss", "ssssss", ".rrr"],
				Vector2i(27, 13 + bob), true)
	_stamp(img, STAFF, Vector2i(8, 7 + bob), back)
	_stamp(img, GRIP, Vector2i(19, 36 + bob), back)
	return img
