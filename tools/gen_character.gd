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
	"j": Color("#352d38"), "u": Color("#504452"), "w": Color("#796876"),
	"a": Color("#352041"), "v": Color("#51305e"), "p": Color("#734485"),
	"l": Color("#9c629e"),
	"r": Color("#571c3b"), "s": Color("#8a2947"), "t": Color("#bc3f53"),
	"c": Color("#ec6a67"), "d": Color("#593241"), "b": Color("#8f5144"),
	"g": Color("#c8844e"), "y": Color("#f4be6b"),
	"e": Color("#57313c"), "x": Color("#db977f"), "f": Color("#f5bca3"),
	"n": Color("#ffe2c6"), "o": Color("#ed812b"), "m": Color("#fff2b7"),
}

const HAT := [
	".................iiii",
	"...............ivpppva",
	".............iivvvvpppai",
	"...........iavvvappavpppai",
	"..........ivvvviavppaavvppai",
	".........ivaaiivppvaaaavvvvpai",
	"........iaai..ivpvaaaaaavvvvvai",
	"........iii..iivvvaaaaaavvvvvvvi",
	"........ssrr..iivvattttsssgygbrrrva.........i",
	"........rsssrriavttttssrrbgmogrrrrrai.....ipi",
	".........rssssrttttsrrrrrrbossrrrrraai..iappi",
	"...........stttrrsrrraaaaaarbrrrrrraaiiapppi",
	"..........ttttrrrraaavvpvvvvaarrraaaaipppuui",
	"........rttttrrrraavvpppppvvvvaaaaaiiaaauui",
	".......rrrrrrrrraaaiiaaaaivvvvviiiiaauuui",
	"..........irrraaiippaavvvviiiiiaaauuuii",
	".........viraaiippaavvvv..iiiaaaiiiii",
	"........viiiiippaavvvv......ii",
	".......vviiipppavvvv",
	"....ipppvvpppavvvv",
	"iipppppppppavvvv",
	".ivvppppavvvvv",
	".iivvvvvvvvv",
	"..iiiiiiii",
]

const FACE := [
	"................hhhh",
	".........hhhhhhhhhhhjjjjhh",
	"......hhhhhhjjhjjhhjjuujjjhh",
	"....hhhhhhjjjjhhuuuhuujjjjjjh",
	"....hhhhjjjjuuuuuuhuujjjjjjjj",
	"...hhhhjujjuuuuuhhjjjxjjjjjjjh",
	"...hhhjuujuuujhhhjjjxfnhjjjjjj",
	"..hhhjuujuuuhhhhjjjxnnjjjjjjjj",
	"..hhjjuujjuhhhhjjjxnnhjjjujjjjh",
	".hhjjuuujhhhhhjxfjjjxhjjjjfxjjh",
	".hhjuuuxhhhhhnkeeefnfnnnkefjhjj",
	"hhjjjjjxxnhhhfnkesfnnnfksnfjhjj",
	".hjjjjjxfnhhhxftssfnnnftsffujjj",
	".jjjjjjuffujhxxfnnnnnfxnnnxjjjh",
	".hhjuujjxjjujhfnnnnrssfnnfjjhjh",
	"hhhjhjjhujhjjhxfnnnnnnnfnfjhjh",
	"hh.hhjhuuuuhjhjxxfffffffxxjjh",
	"..hhhhhjjuuhhhhhhhh....hhhh",
	"..hhh.hjjhhhhhh",
	"......hh...hh",
]

const BACK_HAIR := [
	"...............hhhh",
	"...........hhhjjjjhhhh",
	"........hhhhjjjuujjjjhh",
	"......hhhhjjuuuuuujjjjhhh",
	".....hhhjjuuuuuuujjjjjujjh",
	"...hhhhjjuuuuuujjjjjuuuujjh",
	"..hhhhjjuuuuujjjjjjjuuuujjh",
	"..hhjjuuuuuujjjjjjjjuuujjjj",
	".hhjjuuuuuuujjjjjjjjuujjjjjh",
	".hhjuuujuuujjjjjjjjjuuhjjjjh",
	"hhjjjjjuuujjjjjjjjjjuhhjjjjh",
	"hhjjjjjujjjjjjjjjjjjhhhjjjjh",
	".jjjjjjjjjjjjjhjjjjjhhjjjjhh",
	".jjhhjjjjjjjjhhjjjjhhhjjjjhh",
	".hhhhjjhhjjjjhhjjjjhhjjjjhh",
	".hhhhhhhjjjjhhhjjjhhhjjjhhh",
	"hh.hhhhhjjhhhhjjjhhhhhjhhh",
	"...hh.hhh.hhhhjjhhhhhhh",
	".......h..hh....hh..hh",
]

const PROFILE := [
	".................hhh",
	"...............hhhh",
	"...........hhhjjjjhhhh",
	"........hhhhjjjuujjjjjh",
	"......hhhhjjuuuuuujjjjjjj",
	".....hhhjjuuuuuujjjjjjjjjj",
	"...hhhhjjuuuuujjjjjjjjjjjjj",
	"..hhhhjjuuuuujjjjjhhjjjjjjjj",
	"..hhjjuuuuuujjjjhhhhjxfxxjjj",
	".hhjjuuuuuuujjjjhhhjfnnffjjj",
	".hhjuuujuuujjjxhhhjnnnnnnfjj",
	"hhjjjjjuuujjjxfhhhjnnkkeefjh",
	"hhjjjjjujjjjjxhhhjxnnksffnjh",
	".jjjjjjjjjjjjjhhhxnnfsnnnfxh",
	".jjhhjjjjjjjjhhhhjfnnnnsstth",
	".hhhhjjhhjjjjhhhhhjffnnnnfx",
	".hhhhhhhjjjjhhhhhjjjxfffffh",
	"hh.hhhhhjjhhhhjjjjjjjjjhhh",
	"...hh.hhh.hhhhjjhhhhhhh",
	".......h..hh....hh..hh",
]

const ROBE_FRONT := [
	"...............dxxd",
	"..............rdnnxb",
	"...........avppryyyra",
	".........avvpppvrgsvvva",
	".........avppvabgvsvppva",
	"..........avvaavsfrvvva",
	"...........abgbbgymygb",
	"............avvgbdgava",
	"...........avpvva.rvpva",
	"........rsavppvaia.vvpa",
	"......rstvvppvbgaarvvpg",
	"....rsttpgyyggb..abgyyb",
	"..rsttsrr",
	"rrssttr",
	"..rrr",
]

const ROBE_BACK := [
	".........ivppaa",
	"........apppppva",
	"......avppppppvvva",
	".....avppppvvaavvva",
	"......vppvvavvaavva",
	".......avaavvaavvva",
	".......abgggggbbba",
	"........avapavvaa",
	".......avppvavvvva",
	"......avppvaivappva",
	".....avppvvaaiavpvvr",
	"....abgyggba.ibgygbrss",
	"...................rsstr",
	".....................rssr",
]

const ROBE_SIDE := [
	".............ddxff",
	"............ipgfnxb",
	"..........avpppryga",
	".........avpppvvvrba",
	".........avppvaaavsa",
	".........avpvvvrrvva",
	"..........bgggyygbb",
	"...........avaaabva",
	"..........avppairava",
	"........avppviavrvva",
	".....rsavppvvviavrva",
	"..rstspgygba..vvgygb",
	"rrssrr",
	"..rr",
]

const HAND := [
	".....vpp",
	"....avppv",
	"..xbgppvv",
	".xnfgyvva",
	"..xffbbv",
	".....bba",
]

const FAR_HAND := [
	"..avv",
	"..vpva",
	".avpva",
	".avppg",
	"..agbf",
	"..bxff",
	"...xx",
]

const BOOT := [
	".xf",
	".xf",
	".bg",
	"bgd",
	"bdd",
	"ddd",
]

const STAFF := [
	".d",
	".gg",
	".gmy",
	".gmyy",
	".byyoo",
	".booyoo",
	".dyoooyg",
	"gybooooyb",
	".ggbtooorb...g",
	".byggbssrbd..yg",
	"..gyygdrrddbgyb",
	"...bgyggbbgyygbbb",
	".....bgyyygbbbygbggbbb",
	".....idbgbybogdbb..bbbggbgggbbb",
	"....irb...bbgb......bbgb..bbb",
	"...irs.....bb",
	"..irs",
	"..ir",
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


# Dark paint already forms the contour of the bob and the hat's underside.
# Rim the exposed bright clusters on skin, cloth, leather, and the crystal.
static func _rim(img: Image) -> void:
	var outlines := [PALETTE.i, PALETTE.a, PALETTE.d, PALETTE.b]
	var source: Image = img.duplicate()
	for y in range(1, H - 1):
		for x in range(1, W - 1):
			if source.get_pixel(x, y).a > 0:
				continue
			for step: Vector2i in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
				var col := source.get_pixelv(Vector2i(x, y) + step)
				if col.a == 0 or col.v < 0.34:
					continue
				var target: Color = col.darkened(0.42).lerp(PALETTE.i, 0.4)
				var closest: Color = outlines[0]
				var best := INF
				for candidate: Color in outlines:
					var rgb := Vector3(target.r - candidate.r, target.g - candidate.g, target.b - candidate.b)
					if rgb.length_squared() < best:
						best = rgb.length_squared()
						closest = candidate
				img.set_pixel(x, y, closest)
				break


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


## 去掉帽子的視圖沿用同一個人物，用來量髮頂、下巴、腳底。
static func draw_frame(facing: int, pose: int, wearing_hat := true) -> Image:
	var img := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	var back := facing == 1
	var stride: int = [0, 0, -2, -1, 2, 1][pose]
	var bob: int = [0, 0, 0, -1, 0, -1][pose]
	var swing: int = [0, 0, 1, 1, -1, -1][pose]
	_stamp(img, BOOT, Vector2i(31 + stride, 39 if pose == 3 else 41), back)
	_stamp(img, BOOT, Vector2i(38 - stride, 39 if pose == 5 else 41), back)
	var robe: Array = [ROBE_FRONT, ROBE_BACK, ROBE_SIDE][facing]
	var hem_x: int = [20, 25, 21][facing]
	_stamp(img, robe, Vector2i(hem_x + (1 if pose == 4 else 0), 30 + bob), back)
	_stamp(img, FAR_HAND, Vector2i(38 + swing, 32 + bob), back)
	_stamp(img, STAFF, Vector2i(1, 22 + swing + bob), back)
	_stamp(img, HAND, Vector2i(27, 32 + swing + bob), back)
	var head: Array = [FACE, BACK_HAIR, PROFILE][facing]
	var head_x: int = [17, 18, 18][facing]
	_stamp(img, head, Vector2i(head_x, 14 + bob + (1 if back and pose == 1 else 0)), back)
	if pose == 1 and facing == 0:
		_stamp(img, ["ffff", "eeee", "fxff"], Vector2i(31, 24), back)
		_stamp(img, ["ff", "ee", "fx"], Vector2i(41, 24), back)
	elif pose == 1 and facing == 2:
		_stamp(img, ["fff", "eee", "ffx"], Vector2i(39, 25), back)
	if wearing_hat:
		_stamp(img, HAT, Vector2i(9, 3 + bob), back)
	_rim(img)
	return img
