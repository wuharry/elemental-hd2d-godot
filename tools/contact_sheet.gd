extends SceneTree
## 風格一致性總表：把 tools/capture.sh 拍的「場景 × 時段」截圖排成一張圖，並印出每張的亮度數字。
## 先拍：for s in village forest snow dungeon; do tools/capture.sh --scene=$s --nohud --tag=$s; done
## 再跑：godot --headless --path . --script res://tools/contact_sheet.gd
## 輸出：test_output/contact_sheet.png（列 = Scenes.LIST 順序，欄 = 晨／日／昏／夜）
## 數字只是輔助：mean 是平均亮度、std 是亮度標準差（越低越霧、越平）、ratio 是 std 對同時段村莊的比例。
## 總表一定要打開來看；數字好看不代表畫面對。

const CELL := Vector2i(480, 270)
const SRC := "res://test_output/shot_%s_%s.png"


func _init() -> void:
	var sheet := Image.create(CELL.x * TimeOfDay.ORDER.size(), CELL.y * Scenes.LIST.size(), false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.1, 0.1, 0.12))
	var village_std := {}
	var missing := 0
	print("scene     time      mean   std    ratio")
	for row in Scenes.LIST.size():
		var scene_id: String = Scenes.LIST[row]
		for col in TimeOfDay.ORDER.size():
			var time_name: String = TimeOfDay.ORDER[col]
			var path := ProjectSettings.globalize_path(SRC % [time_name, scene_id])
			if not FileAccess.file_exists(path):
				printerr("missing ", path)
				missing += 1
				continue
			var img := Image.load_from_file(path)
			img.convert(Image.FORMAT_RGB8)
			var stats := _luma_stats(img)
			if scene_id == "village":
				village_std[time_name] = stats.y
			var ratio: float = stats.y / maxf(float(village_std.get(time_name, stats.y)), 0.0001)
			print("%-9s %-8s  %.3f  %.3f  %.2f" % [scene_id, time_name, stats.x, stats.y, ratio])
			img.resize(CELL.x, CELL.y, Image.INTERPOLATE_BILINEAR)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(col * CELL.x, row * CELL.y))
	var out := ProjectSettings.globalize_path("res://test_output/contact_sheet.png")
	sheet.save_png(out)
	print("saved ", out)
	quit(1 if missing > 0 else 0)


## 回傳 (平均亮度, 亮度標準差)，每 4 個像素取樣一次。
func _luma_stats(img: Image) -> Vector2:
	var sum := 0.0
	var sum2 := 0.0
	var n := 0
	for y in range(0, img.get_height(), 4):
		for x in range(0, img.get_width(), 4):
			var c := img.get_pixel(x, y)
			var l := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			sum += l
			sum2 += l * l
			n += 1
	var mean := sum / n
	return Vector2(mean, sqrt(maxf(sum2 / n - mean * mean, 0.0)))
