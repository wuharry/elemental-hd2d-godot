extends SceneTree
## godot --headless --path . --script res://tools/gen_element_icons.gd
## 每個字元是一格像素，空白用「.」。s 是暗面，b 是本色，h 與 w 是亮色。

const OUT := "res://assets/ui/element_icons.png"
const TILE := 19
const INK := Color("#242336")
const GLYPHS := {
	Elements.Type.WATER: [
		"..........h",
		".........hb",
		"........hhb",
		".......hhbbs",
		"......hhhbbs",
		".....hhhhhbb",
		"....hhwhhhbbs",
		"...hhwwhhhbbbs",
		"..hhwwhhhbbbbs",
		"..hwwhhhbbbbbbs",
		".bhwhhhbbbbbbbs",
		".bhwhhbbbbbbbbs",
		".sbhhbbbbbbbbss",
		"..sbbbbbbbbbss",
		"..ssbbbbbbbsss",
		"...sssbbbbbss",
		".....ssssss",
	],
	Elements.Type.FIRE: [
		".........h",
		"........bh",
		".......bhhs",
		"......bhhhs",
		"......bhhhs..h",
		"...h.bbhhhhs.h",
		"...hbbhhhhhsbh",
		"..bhbbhhwhhbhhs",
		"..bhhhhwwhhhhhs",
		".bbhhhhhwwhhhhs",
		".bhhhhhwwwhhhhbs",
		".shhhwwwwwhhhhbs",
		".sbhwwwwwwwhhbs",
		"..sbhwwwwwwhhbs",
		"..sbbhwwwwhhbs",
		"...ssbhwwhhbbs",
		".....ssbbbss",
	],
	Elements.Type.LIGHTNING: [
		".........hhwwww",
		"........hhwwwws",
		"........hwwwbs",
		".......hwwwbs",
		"......hwwwbs",
		".....hwwwbs",
		".....hwwbs",
		"....hwwbbhhhhhh",
		"...hwwbbbbhhhbs",
		"..hhbbbbbhhbbs",
		"..sssssshhbbs",
		".......hhbbs",
		"......hhbbs",
		"......hbbs",
		".....hbbs",
		"....hbs",
		"...hs",
	],
	Elements.Type.ICE: [
		"........w",
		"......w.w.h",
		"......hwwhh",
		"..w....hwh....w",
		"..w.....w.....h",
		"whhw....w....hhhw",
		"...whh.hwh.hhh",
		".....hhwwwhh",
		".......wwh",
		".....bhwwwhb",
		"...bhh.hwh.hhb",
		"bhhb....h....bhhb",
		"..h.....h.....b",
		"..b....bhb....b",
		"......bwhhb",
		"......b.h.b",
		"........b",
	],
}
const PALETTES := {
	Elements.Type.WATER: {"s": Color("#285a99"), "b": Elements.INFO[Elements.Type.WATER]["color"], "h": Color("#65d3ef"), "w": Color("#ddffff")},
	Elements.Type.FIRE: {"s": Color("#ba393c"), "b": Elements.INFO[Elements.Type.FIRE]["color"], "h": Color("#ff9f39"), "w": Color("#ffdf85")},
	Elements.Type.LIGHTNING: {"s": Color("#c28035"), "b": Color("#f8b638"), "h": Elements.INFO[Elements.Type.LIGHTNING]["color"], "w": Color("#fff5ac")},
	Elements.Type.ICE: {"b": Color("#62aaca"), "h": Elements.INFO[Elements.Type.ICE]["color"], "w": Color("#f0ffff")},
}


func _init() -> void:
	var atlas := Image.create_empty(TILE * GLYPHS.size(), TILE, false, Image.FORMAT_RGBA8)
	for element: int in GLYPHS:
		var rows: Array = GLYPHS[element]
		var tile := Image.create_empty(TILE, TILE, false, Image.FORMAT_RGBA8)
		for y in rows.size():
			var row: String = rows[y]
			for x in row.length():
				if row[x] == ".":
					continue
				var point := Vector2i(x + 1, y + 1)
				for offset: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
					var edge := point + offset
					if tile.get_pixelv(edge).a == 0.0:
						tile.set_pixelv(edge, INK)
				tile.set_pixelv(point, PALETTES[element][row[x]])
		atlas.blit_rect(tile, Rect2i(0, 0, TILE, TILE), Vector2i(element * TILE, 0))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	var err := atlas.save_png(OUT)
	if err != OK:
		printerr("無法寫入 ", OUT, "：", error_string(err))
	else:
		err = _save_mote()
	quit(0 if err == OK else 1)


## 中性色交給 Sprite3D 套用元素色。亮芯和暗邊在夜景、雪地都能分辨。
func _save_mote() -> Error:
	var rows := ["..s..", ".bhb.", "shwhs", ".bhb.", "..s.."]
	var shades := {"s": Color("#626271"), "b": Color("#b2b2bc"), "h": Color("#eeeeef"), "w": Color.WHITE}
	var mote := Image.create_empty(5, 5, false, Image.FORMAT_RGBA8)
	for y in rows.size():
		for x in rows[y].length():
			var shade: String = rows[y][x]
			if shade != ".":
				mote.set_pixel(x, y, shades[shade])
	var err := mote.save_png("res://assets/characters/orb.png")
	if err != OK:
		printerr("無法寫入元素光點：", error_string(err))
	return err
