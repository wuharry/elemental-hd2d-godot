extends SceneTree
## 世界貼圖產生器（BLUEPRINT A4、A5）。
## 用法：godot --headless --path . --script res://tools/gen_textures.gd
## 貼圖只放固有色與法線圖，不畫光影；改色調改這裡再重跑，不手改 PNG。

const OUT := "res://assets/textures/"
const S := 64


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_grass_ground()
	_grass_ground_seasonal()
	_dirt()
	_cobble()
	_stone_wall()
	_log_wall()
	_planks()
	_roof()
	_leaves()
	_leaves_seasonal()
	_bark()
	_window()
	_door()
	_grass_tuft()
	_flowers()
	_small_shapes()
	_water_normal()
	_snow()
	_ice()
	_flagstone()
	_brick()
	print("textures written to ", OUT)
	quit()


# ---------- 共用工具 ----------

func _hash(x: int, y: int, s: int = 0) -> float:
	var n: int = (x * 374761393 + y * 668265263 + s * 982451653) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	n = n ^ (n >> 16)
	return float(n & 0xffff) / 65535.0


## 可無縫拼接的 value noise；period = 一張貼圖內有幾個格點。
func _vnoise(x: float, y: float, period: int, s: int = 0, size: int = S) -> float:
	var fx: float = x / float(size) * period
	var fy: float = y / float(size) * period
	var x0: int = int(floor(fx))
	var y0: int = int(floor(fy))
	var tx: float = fx - x0
	var ty: float = fy - y0
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var a: float = _hash(posmod(x0, period), posmod(y0, period), s)
	var b: float = _hash(posmod(x0 + 1, period), posmod(y0, period), s)
	var c: float = _hash(posmod(x0, period), posmod(y0 + 1, period), s)
	var d: float = _hash(posmod(x0 + 1, period), posmod(y0 + 1, period), s)
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)


func _pal(colors: Array, t: float) -> Color:
	var i: int = clampi(int(t * colors.size()), 0, colors.size() - 1)
	return colors[i]


func _hex(list: Array) -> Array:
	var out: Array = []
	for h in list:
		out.append(Color.html(h))
	return out


func _new(w: int = S, h: int = S) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


func _save(img: Image, name: String) -> void:
	var err := img.save_png(OUT + name + ".png")
	if err != OK:
		push_error("save failed: %s (%d)" % [name, err])


## 高度圖 → 法線圖（可拼接）。Godot 用 OpenGL 慣例：綠色朝上。
func _save_normal(height: PackedFloat32Array, w: int, h: int, strength: float, name: String) -> void:
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		for x in w:
			var l: float = height[y * w + posmod(x - 1, w)]
			var r: float = height[y * w + posmod(x + 1, w)]
			var u: float = height[posmod(y - 1, h) * w + x]
			var d: float = height[posmod(y + 1, h) * w + x]
			var n := Vector3(-(r - l) * strength, (d - u) * strength, 1.0).normalized()
			img.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5))
	_save(img, name)


## 可拼接的 Voronoi：回傳 [最近格點 id, 到邊界的距離]。
func _voronoi(x: int, y: int, cx: int, cy: int, s: int, sx: float = 1.0) -> Array:
	var cw: float = float(S) / cx
	var ch: float = float(S) / cy
	var gx: int = int(x / cw)
	var gy: int = int(y / ch)
	var d1: float = 1e9
	var d2: float = 1e9
	var id: int = 0
	for oy in range(-2, 3):
		for ox in range(-2, 3):
			var ix: int = gx + ox
			var iy: int = gy + oy
			var wx: int = posmod(ix, cx)
			var wy: int = posmod(iy, cy)
			var px: float = (ix + 0.2 + 0.6 * _hash(wx, wy, s)) * cw
			var py: float = (iy + 0.2 + 0.6 * _hash(wx, wy, s + 1)) * ch
			var dx: float = (px - x) * sx
			var dy: float = py - y
			var dd: float = sqrt(dx * dx + dy * dy)
			if dd < d1:
				d2 = d1
				d1 = dd
				id = wy * cx + wx
			elif dd < d2:
				d2 = dd
	return [id, d2 - d1]


# ---------- 地面 ----------

func _grass_ground() -> void:
	var img := _new()
	var pal := _hex(["#356b2c", "#3f7b32", "#4a8b37", "#56993d"])
	for y in S:
		for x in S:
			var t: float = _vnoise(x, y, 4, 11) * 0.55 + _vnoise(x, y, 16, 12) * 0.25 + _hash(x, y, 13) * 0.2
			var c: Color = _pal(pal, t)
			if _hash(x, y, 14) > 0.95:
				c = Color.html("#74bd4c")
			img.set_pixel(x, y, c)
	_save(img, "grass_ground")


func _dirt() -> void:
	var img := _new()
	var pal := _hex(["#614430", "#6e4f37", "#7c5b3f", "#8a6847"])
	var hgt := PackedFloat32Array()
	hgt.resize(S * S)
	for y in S:
		for x in S:
			var t: float = _vnoise(x, y, 4, 21) * 0.5 + _vnoise(x, y, 16, 22) * 0.3 + _hash(x, y, 23) * 0.2
			var c: Color = _pal(pal, t)
			if _hash(x, y, 24) > 0.965:
				c = Color.html("#a58a68")
			img.set_pixel(x, y, c)
			hgt[y * S + x] = t
	_save(img, "dirt")
	_save_normal(hgt, S, S, 1.2, "dirt_n")


func _cobble() -> void:
	var img := _new()
	var pal := _hex(["#7d756a", "#8b8376", "#989082", "#a59d8e", "#8f8272"])
	var mortar := Color.html("#463d36")
	var hgt := PackedFloat32Array()
	hgt.resize(S * S)
	for y in S:
		for x in S:
			var v: Array = _voronoi(x, y, 5, 5, 31)
			var edge: float = v[1]
			var c: Color
			if edge < 1.5:
				c = mortar.lightened(_hash(x, y, 33) * 0.08)
				hgt[y * S + x] = 0.0
			else:
				c = pal[int(_hash(v[0], 7, 32) * pal.size()) % pal.size()]
				c = c.darkened(_hash(x, y, 34) * 0.07)
				hgt[y * S + x] = clampf((edge - 1.0) / 4.0, 0.0, 1.0) * 0.8 + _hash(x, y, 35) * 0.2
			img.set_pixel(x, y, c)
	_save(img, "cobble")
	_save_normal(hgt, S, S, 2.4, "cobble_n")


# ---------- 牆與屋頂 ----------

func _stone_wall() -> void:
	var img := _new()
	var pal := _hex(["#8e8678", "#9c9485", "#aaa292", "#b6ae9d", "#a09482"])
	var mortar := Color.html("#5a5047")
	var hgt := PackedFloat32Array()
	hgt.resize(S * S)
	for y in S:
		for x in S:
			var v: Array = _voronoi(x, y, 4, 6, 41, 0.75)
			var edge: float = v[1]
			var c: Color
			if edge < 1.4:
				c = mortar.lightened(_hash(x, y, 43) * 0.08)
				hgt[y * S + x] = 0.0
			else:
				c = pal[int(_hash(v[0], 3, 42) * pal.size()) % pal.size()]
				c = c.darkened(_hash(x, y, 44) * 0.08)
				hgt[y * S + x] = clampf((edge - 1.0) / 3.5, 0.0, 1.0) * 0.75 + _hash(x, y, 45) * 0.25
			img.set_pixel(x, y, c)
	_save(img, "stone_wall")
	_save_normal(hgt, S, S, 2.8, "stone_wall_n")


func _log_wall() -> void:
	var img := _new()
	var pal := _hex(["#573623", "#633f29", "#70482f", "#7c5236"])
	var seam := Color.html("#2c1a12")
	var hgt := PackedFloat32Array()
	hgt.resize(S * S)
	for y in S:
		var band: int = y / 8
		var yy: int = y % 8
		for x in S:
			var grain: float = _vnoise(x, y * 6.0, 8, 51 + band) * 0.6 + _hash(x / 3, y, 52) * 0.4
			var c: Color = _pal(pal, grain * 0.75 + _hash(band, 0, 53) * 0.25)
			if yy == 7:
				c = seam
			# 偶爾出現的木節
			if _hash(x / 2, band, 54) > 0.985 and yy >= 2 and yy <= 4:
				c = Color.html("#3d2518")
			img.set_pixel(x, y, c)
			hgt[y * S + x] = 0.0 if yy == 7 else sin(PI * (yy + 0.5) / 7.5) * 0.9 + grain * 0.1
	_save(img, "log_wall")
	_save_normal(hgt, S, S, 2.6, "log_wall_n")


func _planks() -> void:
	var img := _new()
	var pal := _hex(["#7a5a3a", "#876542", "#94704a", "#a17c54"])
	var seam := Color.html("#3d2a1c")
	var hgt := PackedFloat32Array()
	hgt.resize(S * S)
	for y in S:
		for x in S:
			var col: int = x / 8
			var xx: int = x % 8
			var grain: float = _vnoise(x * 6.0, y, 8, 61 + col) * 0.6 + _hash(x, y / 3, 62) * 0.4
			var c: Color = _pal(pal, grain * 0.7 + _hash(col, 1, 63) * 0.3)
			if xx == 0:
				c = seam
			img.set_pixel(x, y, c)
			hgt[y * S + x] = 0.0 if xx == 0 else 0.8 + grain * 0.2
	_save(img, "planks")
	_save_normal(hgt, S, S, 1.8, "planks_n")


## 屋瓦做成接近中性的亮色，實際顏色由材質 tint 決定（一張貼圖出多種屋頂）。
func _roof() -> void:
	var img := _new()
	var hgt := PackedFloat32Array()
	hgt.resize(S * S)
	for y in S:
		var row: int = y / 8
		var yy: int = y % 8
		for x in S:
			var xo: int = posmod(x + (4 if row % 2 == 1 else 0), S)
			var tile: int = xo / 8
			var xx: int = xo % 8
			var v: float = 0.72 + _hash(tile, row, 71) * 0.24
			v -= _hash(x, y, 72) * 0.06
			if yy == 7:
				v = 0.34
			elif xx == 0:
				v *= 0.62
			img.set_pixel(x, y, Color(v, v * 0.97, v * 0.93))
			hgt[y * S + x] = 0.0 if yy == 7 else (0.25 + yy / 7.0 * 0.75) * (0.5 if xx == 0 else 1.0)
	_save(img, "roof")
	_save_normal(hgt, S, S, 2.2, "roof_n")


# ---------- 植物 ----------

func _leaves() -> void:
	var img := _new()
	# 2px 的小葉片成簇分布：亮部是受光的葉面，最暗的是葉縫
	var pal := _hex(["#2a5a26", "#3d7a2e", "#4f9436", "#66ad40", "#86c954"])
	var hgt := PackedFloat32Array()
	hgt.resize(S * S)
	for y in S:
		for x in S:
			var by: int = y / 2
			var bx: int = (x + (1 if by % 2 == 1 else 0)) / 2
			var t: float = _hash(bx, by, 81) * 0.55 + _vnoise(x, y, 8, 82) * 0.3 + _vnoise(x, y, 3, 83) * 0.15
			img.set_pixel(x, y, _pal(pal, clampf(t * 1.15 - 0.05, 0.0, 0.999)))
			hgt[y * S + x] = t
	_save(img, "leaves")
	_save_normal(hgt, S, S, 1.6, "leaves_n")


func _leaves_seasonal() -> void:
	_leaves_variant("leaves_blossom", _hex(["#b85c7b", "#d87d9c", "#ee9fb9", "#ffc6d8", "#ffebf2"]), 85)
	_leaves_variant("leaves_autumn", _hex(["#762418", "#a43820", "#cc5b24", "#e48a2c", "#f4c248"]), 86)
	_leaves_variant("leaves_winter", _hex(["#3e5462", "#526c7a", "#6e8a98", "#98b2c0", "#d4e4f0"]), 87)


func _leaves_variant(name: String, pal: Array, salt: int) -> void:
	var img := _new()
	for y in S:
		for x in S:
			var by: int = y / 2
			var bx: int = (x + (1 if by % 2 == 1 else 0)) / 2
			var t: float = _hash(bx, by, salt) * 0.55 + _vnoise(x, y, 8, salt + 1) * 0.3 + _vnoise(x, y, 3, salt + 2) * 0.15
			img.set_pixel(x, y, _pal(pal, clampf(t * 1.15 - 0.05, 0.0, 0.999)))
	_save(img, name)


func _grass_ground_seasonal() -> void:
	# 春草地：明亮嫩綠草坪＋零星掉落的粉白花瓣
	var spring := _new()
	var spring_pal := _hex(["#428634", "#549e3e", "#68b44a", "#7fc95a", "#96dc6c"])
	var hgt := PackedFloat32Array()
	hgt.resize(S * S)
	for y in S:
		for x in S:
			var t: float = _vnoise(x, y, 6, 31) * 0.5 + _vnoise(x, y, 16, 32) * 0.3 + _hash(x, y, 33) * 0.2
			var c: Color = _pal(spring_pal, t)
			if _hash(x, y, 34) > 0.975:
				c = Color.html("#ffd8e6") if _hash(x, y, 35) > 0.35 else Color.html("#fff4f8")
			spring.set_pixel(x, y, c)
			hgt[y * S + x] = t
	_save(spring, "grass_ground_spring")
	_save_normal(hgt, S, S, 1.4, "grass_ground_spring_n")
	# 秋草地：暖橄欖與枯金草坪＋零星楓紅落葉點
	var autumn := _new()
	var autumn_pal := _hex(["#665c2e", "#7a6934", "#8e7538", "#a48440", "#b6954a"])
	for y in S:
		for x in S:
			var t: float = _vnoise(x, y, 6, 41) * 0.5 + _vnoise(x, y, 16, 42) * 0.3 + _hash(x, y, 43) * 0.2
			var c: Color = _pal(autumn_pal, t)
			if _hash(x, y, 44) > 0.972:
				c = Color.html("#d4542c") if _hash(x, y, 45) > 0.45 else Color.html("#eba63c")
			autumn.set_pixel(x, y, c)
			hgt[y * S + x] = t
	_save(autumn, "grass_ground_autumn")
	_save_normal(hgt, S, S, 1.4, "grass_ground_autumn_n")


func _bark() -> void:
	var img := _new()
	var pal := _hex(["#3f2c20", "#4d3626", "#5b412d", "#6a4c35"])
	var hgt := PackedFloat32Array()
	hgt.resize(S * S)
	for y in S:
		for x in S:
			var t: float = _vnoise(x * 4.0, y, 16, 91) * 0.6 + _hash(x, y / 4, 92) * 0.4
			img.set_pixel(x, y, _pal(pal, t))
			hgt[y * S + x] = t
	_save(img, "bark")
	_save_normal(hgt, S, S, 2.0, "bark_n")


## 兩種草叢，各 16x16，並排成 32x16。
func _grass_tuft() -> void:
	_grass_tuft_named("grass_tuft", _hex(["#3a7a2c", "#4f9636", "#6cb444", "#93d05a"]))
	# 秋季用的金黃枯草（BLUEPRINT S12：獨立圖集，不硬染綠草）
	_grass_tuft_named("grass_tuft_autumn", _hex(["#765024", "#9e6e2e", "#c8943c", "#e6c05e"]))
	# 雪地用的霜枯草：同樣的草形，換成枯黃到霜白
	_grass_tuft_named("grass_tuft_frost", _hex(["#857756", "#a49672", "#cdc4a6", "#eef3f8"]))


func _grass_tuft_named(name: String, tones: Array) -> void:
	var img := _new(32, 16)
	for variant in 2:
		var blades: int = 7 if variant == 0 else 5
		for b in blades:
			var bx: float = 2.0 + _hash(b, variant, 101) * 12.0
			var bh: int = 7 + int(_hash(b, variant, 102) * 9.0)
			var lean: float = (_hash(b, variant, 103) - 0.5) * 0.7
			for i in bh:
				var px: int = int(round(bx + lean * i * i / float(bh)))
				var py: int = 15 - i
				if px < 0 or px > 15:
					continue
				var c: Color = tones[clampi(int(float(i) / bh * 4.0), 0, 3)]
				img.set_pixel(variant * 16 + px, py, c)
				if i < bh / 2 and px + 1 <= 15:
					img.set_pixel(variant * 16 + px + 1, py, tones[0])
	_save(img, name)


## 四種花，各 16x16，並排成 64x16。
func _flowers() -> void:
	_flowers_named("flowers", Color.html("#3f8a30"), Color.html("#5aa63c"),
		_hex(["#fbfbf2", "#ffd84a", "#ff7a3c", "#b98cff"]),
		_hex(["#f2c230", "#e98a1e", "#ffe27a", "#f6e6ff"]))
	_flowers_named("flowers_spring", Color.html("#469a38"), Color.html("#68bc48"),
		_hex(["#ffb8d0", "#fff4f8", "#ffe25c", "#a4d8ff"]),
		_hex(["#ffea90", "#ffb0c8", "#f0a028", "#eef8ff"]))
	_flowers_named("flowers_autumn", Color.html("#7c6230"), Color.html("#9c7c3a"),
		_hex(["#f2b838", "#e87830", "#d44c3c", "#f6e6c8"]),
		_hex(["#fff0a8", "#ffd468", "#f6b04c", "#d89038"]))


func _flowers_named(name: String, stem: Color, leaf: Color, petals: Array, cores: Array) -> void:
	var img := _new(64, 16)
	for v in 4:
		for f in 3:
			var fx: int = 3 + f * 5 + int(_hash(f, v, 111) * 2.0)
			var fh: int = 7 + int(_hash(f, v, 112) * 6.0)
			for i in fh:
				img.set_pixel(v * 16 + fx, 15 - i, stem)
			img.set_pixel(v * 16 + clampi(fx - 1, 0, 15), 15 - fh / 2, leaf)
			img.set_pixel(v * 16 + clampi(fx + 1, 0, 15), 15 - fh / 3, leaf)
			var ty: int = 15 - fh
			for o in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
				var qx: int = fx + o.x
				var qy: int = ty + o.y
				if qx >= 0 and qx <= 15 and qy >= 0 and qy <= 15:
					img.set_pixel(v * 16 + qx, qy, petals[v])
			img.set_pixel(v * 16 + fx, ty, cores[v])
	_save(img, name)


## 落葉、蝴蝶翅膀、光點：都是白底，顏色由粒子或材質決定。
func _small_shapes() -> void:
	var leaf := _new(8, 8)
	var rows := ["...##...", "..####..", ".######.", ".######.", "..####..", "..####..", "...##...", "...#...."]
	for y in 8:
		for x in 8:
			if rows[y][x] == "#":
				leaf.set_pixel(x, y, Color(1, 1, 1) if (x + y) % 5 != 0 else Color(0.8, 0.8, 0.8))
	_save(leaf, "leaf")

	var wing := _new(8, 8)
	var wrows := ["........", ".###....", "#####...", "######..", "######..", ".#####..", ".####...", "..##...."]
	for y in 8:
		for x in 8:
			if wrows[y][x] == "#":
				var edge: bool = x == 0 or y == 1 or wrows[y][mini(x + 1, 7)] == "." or wrows[mini(y + 1, 7)][x] == "."
				wing.set_pixel(x, y, Color(0.25, 0.2, 0.25) if edge else Color(1, 1, 1))
	_save(wing, "wing")

	var dot := _new(16, 16)
	for y in 16:
		for x in 16:
			var d: float = Vector2(x - 7.5, y - 7.5).length() / 7.5
			if d < 1.0:
				var a: float = 1.0 if d < 0.45 else (0.55 if d < 0.75 else 0.22)
				dot.set_pixel(x, y, Color(1, 1, 1, a))
	_save(dot, "dot")


# ---------- 門窗 ----------

func _window() -> void:
	var n := 24
	var img := _new(n, n)
	var emi := Image.create(n, n, false, Image.FORMAT_RGB8)
	emi.fill(Color.BLACK)
	var frame := Color.html("#c2a070")
	var frame_d := Color.html("#8f7048")
	var glass := Color.html("#27384a")
	var glass_l := Color.html("#3a5068")
	for y in n:
		for x in n:
			var border: bool = x < 2 or x > n - 3 or y < 2 or y > n - 3
			var muntin: bool = (x >= 11 and x <= 12) or (y >= 11 and y <= 12)
			if border or muntin:
				img.set_pixel(x, y, frame_d if (x == 0 or y == n - 1 or x == n - 1 or y == 0) else frame)
				# 窗框也留一點亮度，夜裡才看得出窗格
				emi.set_pixel(x, y, Color(0.05, 0.035, 0.02))
			else:
				img.set_pixel(x, y, glass_l if (x + y) % 9 == 0 or (x - y + n) % 11 == 0 else glass)
				# 發光遮罩：窗簾讓上緣與兩側暗一點
				var curtain: float = 1.0
				if y < 6 or x < 5 or x > n - 6:
					curtain = 0.5
				emi.set_pixel(x, y, Color(curtain, curtain * 0.9, curtain * 0.74))
	_save(img, "window")
	_save(emi, "window_e")


func _door() -> void:
	var img := _new(32, 48)
	var pal := _hex(["#5e4129", "#6b4b30", "#785537"])
	var iron := Color.html("#34343c")
	for y in 48:
		for x in 32:
			var c: Color = _pal(pal, _hash(x / 8, 0, 121) * 0.6 + _hash(x, y / 4, 122) * 0.4)
			if x % 8 == 0:
				c = Color.html("#33221a")
			if (y >= 8 and y <= 9) or (y >= 37 and y <= 38):
				c = iron
			if x >= 24 and x <= 26 and y >= 23 and y <= 26:
				c = Color.html("#d8b24a")
			if x < 2 or x > 29 or y < 2:
				c = Color.html("#3a281c")
			img.set_pixel(x, y, c)
	_save(img, "door")


# ---------- 水 ----------

func _water_normal() -> void:
	var hgt := PackedFloat32Array()
	hgt.resize(S * S)
	for y in S:
		for x in S:
			hgt[y * S + x] = _vnoise(x, y, 4, 131) * 0.6 + _vnoise(x, y, 8, 132) * 0.4
	_save_normal(hgt, S, S, 3.0, "water_n")


# ---------- 雪地與地下城 ----------

func _snow() -> void:
	var img := _new()
	var pal := _hex(["#dfe7f4", "#e9eff9", "#f3f7fd", "#ffffff"])
	var hgt := PackedFloat32Array()
	hgt.resize(S * S)
	for y in S:
		for x in S:
			var t: float = _vnoise(x, y, 4, 141) * 0.6 + _vnoise(x, y, 16, 142) * 0.25 + _hash(x, y, 143) * 0.15
			var c: Color = _pal(pal, t)
			if _hash(x, y, 144) > 0.985:
				c = Color.html("#cfdcf0")
			img.set_pixel(x, y, c)
			hgt[y * S + x] = _vnoise(x, y, 4, 141) * 0.7 + _vnoise(x, y, 8, 145) * 0.3
	_save(img, "snow")
	_save_normal(hgt, S, S, 1.6, "snow_n")


func _ice() -> void:
	var img := _new()
	var pal := _hex(["#9ccbe6", "#aed6ee", "#c0e1f4", "#d2ebf8"])
	var crack := Color.html("#eef9ff")
	var hgt := PackedFloat32Array()
	hgt.resize(S * S)
	for y in S:
		for x in S:
			var v: Array = _voronoi(x, y, 3, 3, 151)
			var t: float = _vnoise(x, y, 3, 152) * 0.7 + _hash(v[0], 1, 153) * 0.3
			var c: Color = _pal(pal, t)
			var edge: float = v[1]
			if edge < 0.7:
				c = crack
			img.set_pixel(x, y, c)
			hgt[y * S + x] = 0.0 if edge < 0.7 else 0.6 + t * 0.1
	_save(img, "ice")
	_save_normal(hgt, S, S, 1.0, "ice_n")


## 地下城的石板：錯縫的大小石板（不是規則方格），少數有短裂痕、缺角。
## 四列高度 16／12／20／16 = 64，每列寬度加起來剛好 64，所以上下左右都能無縫拼接。
func _flagstone() -> void:
	var img := _new()
	var pal := _hex(["#6a6876", "#74727f", "#7e7c8a", "#888694", "#787082"])
	var gap := Color.html("#34323e")
	var hgt := PackedFloat32Array()
	hgt.resize(S * S)
	var rows := [[0, 16], [16, 12], [28, 20], [48, 16]]
	var choices := [12, 16, 20, 24]
	var layout: Array = []   # 每列：[起點位移, [寬度...]]
	for r in rows.size():
		var widths: Array = []
		var total := 0
		var k := 0
		while total < S:
			var w: int = choices[int(_hash(r, k, 181) * choices.size()) % choices.size()]
			if S - total - w < 8 and S - total - w != 0:
				w = S - total
			widths.append(w)
			total += w
			k += 1
		layout.append([int(_hash(r, 0, 182) * S), widths])
	var cracks := {}   # 裂痕像素
	for r in rows.size():
		var widths: Array = layout[r][1]
		var start := 0
		for i in widths.size():
			var slab_id := r * 16 + i
			if _hash(slab_id, 3, 183) < 0.2:
				var cx: int = start + 3 + int(_hash(slab_id, 4, 184) * maxf(widths[i] - 6, 1))
				var cy: int = int(rows[r][0]) + 3 + int(_hash(slab_id, 5, 185) * maxf(int(rows[r][1]) - 6, 1))
				var dx := 1 if _hash(slab_id, 6, 186) > 0.5 else -1
				for step in 4 + int(_hash(slab_id, 7, 187) * 4.0):
					cracks[Vector2i(posmod(cx - int(layout[r][0]), S), cy)] = true
					cx += dx
					cy += 1 if _hash(slab_id, step, 188) > 0.45 else 0
			start += widths[i]
	for y in S:
		var r := 0
		while r < rows.size() - 1 and y >= int(rows[r + 1][0]):
			r += 1
		var yy: int = y - int(rows[r][0])
		var h: int = rows[r][1]
		var widths: Array = layout[r][1]
		for x in S:
			var xs: int = posmod(x + int(layout[r][0]), S)
			var i := 0
			var start := 0
			while xs >= start + int(widths[i]):
				start += widths[i]
				i += 1
			var xx: int = xs - start
			var w: int = widths[i]
			var slab_id := r * 16 + i
			var c: Color = _pal(pal, _hash(slab_id, 1, 189) * 0.75 + _hash(x, y, 190) * 0.25)
			var seam := xx == 0 or yy == 0
			# 缺角：讓石板邊角不那麼方正
			if not seam and _hash(slab_id, 2, 191) > 0.55 and xx <= 1 and yy <= 1:
				seam = true
			var crack: bool = cracks.has(Vector2i(x, y))
			if seam or crack:
				c = gap
			img.set_pixel(x, y, c)
			var v := 0.85 + _hash(x, y, 192) * 0.1
			if xx == 1 or yy == 1 or xx == w - 1 or yy == h - 1:
				v = 0.62
			if crack:
				v = 0.25
			hgt[y * S + x] = 0.0 if seam else v
	_save(img, "flagstone")
	_save_normal(hgt, S, S, 1.8, "flagstone_n")


## 地下城的磚牆：每塊 16x8，隔列錯開。
func _brick() -> void:
	var img := _new()
	var pal := _hex(["#5c5056", "#685a5e", "#746466", "#7f6e6e"])
	var mortar := Color.html("#2c2630")
	var hgt := PackedFloat32Array()
	hgt.resize(S * S)
	for y in S:
		var row: int = y / 8
		var yy: int = y % 8
		for x in S:
			var xo: int = posmod(x + (8 if row % 2 == 1 else 0), S)
			var bx: int = xo / 16
			var xx: int = xo % 16
			var c: Color = _pal(pal, _hash(bx, row, 171) * 0.75 + _hash(x, y, 172) * 0.25)
			var seam: bool = yy == 0 or xx == 0
			if seam:
				c = mortar
			img.set_pixel(x, y, c)
			hgt[y * S + x] = 0.0 if seam else 0.85 + _hash(x, y, 173) * 0.15
	_save(img, "brick")
	_save_normal(hgt, S, S, 2.4, "brick_n")
