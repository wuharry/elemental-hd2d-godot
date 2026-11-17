extends SceneDef
## 雪原吊橋：被裂谷切開的雪原，一座吊橋連接兩岸；結冰的湖、積雪的針葉林、小木屋。
## 玩法上預留的互動：冰面（火融化、滑行）、吊橋（可燃／可斷）、裂谷（擊落）、積雪。


func _init() -> void:
	id = "snow"
	title = "雪原吊橋"
	player_start = Vector3(-1.0, 0.0, 1.0)
	paths = [
		{"pts": [Vector2(-40, 1.5), Vector2(-20, 0.5), Vector2(-6, 0), Vector2(4, 0)], "width": 2.4},
		{"pts": [Vector2(14, 0), Vector2(24, -1.5), Vector2(40, -1)], "width": 2.4},
		{"pts": [Vector2(-6, 0), Vector2(-8.5, -3.5), Vector2(-9.3, -5.2)], "width": 1.6},
	]
	dirt_spots = [{"c": Vector2(-2.5, 4.2), "r": 2.2}]
	bridges = [Rect2(4.0, -1.25, 10.0, 2.5)]
	houses = [
		{"pos": Vector2(-9.5, -8.0), "rot": 5.0, "w": 4.8, "d": 4.0, "base_h": 1.8, "wall_h": 1.7, "roof_h": 2.3, "gable_front": true, "cols": 2, "floors": 1, "roof_tint": ROOF_SNOW, "seed": 21},
		{"pos": Vector2(19.5, -7.5), "rot": -8.0, "w": 4.4, "d": 3.8, "base_h": 1.7, "wall_h": 1.6, "roof_h": 1.9, "gable_front": false, "cols": 2, "floors": 1, "roof_tint": ROOF_SNOW, "seed": 22},
		{"pos": Vector2(-18.0, 2.5), "rot": -10.0, "w": 2.4, "d": 1.8, "base_h": 0.25, "wall_h": 1.35, "roof_h": 0.8, "gable_front": true, "cols": 0, "floors": 0, "roof_tint": ROOF_SNOW, "shed": true, "seed": 23},
	]
	# 結冰的湖（不長草；可以走上去）
	ponds = [Rect2(-17.0, 6.0, 9.0, 5.0), Rect2(-15.5, 5.0, 6.0, 7.0)]
	ground = {
		"base": "snow", "base_tint": Color.WHITE,
		"dirt": "snow", "dirt_tint": Color("#c4d2e8"),
		"path": "cobble", "path_tint": Color("#c9d3e4"),
		"side": "stone_wall", "side_tint": Color("#8e9ab4"),
		"base_roughness": 0.8,
	}
	grass_count = 9000
	flower_count = 0
	# 霜枯草圖集本身已經是枯黃到霜白，色調只做很輕的變化
	grass_atlas = "grass_tuft_frost"
	grass_tints = [Color("#f2efe6"), Color("#ffffff"), Color("#f6eed8")]
	backdrop = {"kind": "terraces", "cliff_tint": Color("#aeb8cc"), "top": "snow", "tree_tint_a": Color("#8fb09a"), "tree_tint_b": Color("#6a8f86"), "snow": true}
	ambient = {"dust": false, "fireflies": false, "clouds": true, "birds": 3, "snow": true}


## 裂谷：南北走向，中心線左右擺動。
func _chasm_x(z: float) -> float:
	return 9.0 + 2.0 * sin(z * 0.16) + 1.2 * sin(z * 0.41 + 1.0) - 1.2 * sin(1.0)


func is_void(p: Vector2) -> bool:
	return absf(p.x - _chasm_x(p.y)) < 3.6


## 雪地上的枯草成叢長在雪堆、石頭附近的感覺：用低頻雜訊決定哪幾片有草。
func grow_density(p: Vector2) -> float:
	return smoothstep(0.52, 0.68, FoliageField.patch(p, 0.14, 4.1))


func populate(w: GameWorld) -> void:
	_chasm(w)
	w.place(SetPieces.rope_bridge(9.6, 2.5), Vector2(9.0, 0.0))

	var ice := Mats.tri("ice", Color.WHITE, 0.08, 0.5)
	for r in ponds:
		var rect: Rect2 = r
		var c := rect.get_center()
		Build.box(w, Vector3(rect.size.x, 0.08, rect.size.y), Vector3(c.x, 0.03, c.y), ice)
	for p in [Vector2(-17.6, 7.5), Vector2(-12.0, 4.6), Vector2(-7.6, 9.0), Vector2(-13.5, 12.4), Vector2(-16.0, 11.4)]:
		w.place(SetPieces.snow_mound(int(p.x * 3.0 + p.y * 11.0) + 50), p, w.rng.randf() * 90.0)

	# 積雪的針葉樹
	var spots: Array[Vector2] = []
	var tries := 0
	while spots.size() < 24 and tries < 4000:
		tries += 1
		var p := Vector2(w.rng.randf_range(-33, 33), w.rng.randf_range(-21, 21))
		if not can_grow(p) or path_info(p).x < 3.6 or near_void(p, 2.0):
			continue
		if p.y > 2.5 and absf(p.x + 1.0) < 9.0:
			continue
		var ok := true
		for q in spots:
			if p.distance_to(q) < 4.0:
				ok = false
		if not ok:
			continue
		spots.append(p)
		w.conifer(p, w.rng.randf_range(1.0, 1.7), Color("#9fc0a4").lerp(Color("#7aa090"), w.rng.randf()), true)
	w.scatter(16, Rect2(-34, -21, 68, 42), func(rng: RandomNumberGenerator, _p: Vector2) -> Node3D:
		return SetPieces.snow_mound(rng.randi(), rng.randf_range(0.7, 1.3)))
	w.scatter(12, Rect2(-34, -21, 68, 42), func(rng: RandomNumberGenerator, _p: Vector2) -> Node3D:
		return PropBuilder.rock(rng.randi(), rng.randf_range(0.8, 1.5)))
	w.scatter(5, Rect2(-30, -19, 60, 38), func(rng: RandomNumberGenerator, _p: Vector2) -> Node3D:
		return SetPieces.cairn(rng.randi()))

	# 裂谷邊的冰錐與發光冰晶
	for p in [Vector2(3.6, -6.0), Vector2(15.4, 7.0), Vector2(3.0, 9.0), Vector2(15.8, -9.5), Vector2(-9.5, 5.2), Vector2(-18.4, 9.5)]:
		w.place(SetPieces.ice_spikes(int(p.x * 5.0 + p.y * 9.0) + 30, 1.1), p)
	w.place(SetPieces.crystals(71, Color("#8fe8ff"), 1.1), Vector2(3.8, 5.6))
	w.place(SetPieces.crystals(72, Color("#8fe8ff"), 0.9), Vector2(15.0, -5.0))
	w.place(SetPieces.crystals(73, Color("#b8a8ff"), 1.0), Vector2(-20.5, -3.5))

	w.place(PropBuilder.campfire(), Vector2(-2.5, 4.2))
	w.place(PropBuilder.lamp_post(true), Vector2(-5.0, 1.7), 150.0)
	w.place(PropBuilder.lamp_post(false), Vector2(18.0, 1.5), 40.0)
	w.place(PropBuilder.lamp_post(false), Vector2(-20.0, -1.0), 0.0)
	w.place(PropBuilder.crate(0.7), Vector2(-6.6, -5.0), 12.0)
	w.place(PropBuilder.barrel(), Vector2(-12.4, -5.4))
	w.place(PropBuilder.log_pile(), Vector2(-13.8, -8.0), 86.0)
	w.place(PropBuilder.fence(5.0), Vector2(3.4, 5.0), 88.0)
	w.place(PropBuilder.fence(4.5), Vector2(3.6, -5.5), 84.0)
	w.place(PropBuilder.fence(5.0), Vector2(15.2, 4.5), 95.0)



## 裂谷：兩側岩壁錯落的岩架（上層積雪），谷底是結冰的溪流、雪堆和石頭。
## 谷底抬到 5.5 公尺深：太深只會被霧吃成一片灰，讀不出是裂谷。
const CHASM_FLOOR := -5.5


func _chasm(w: GameWorld) -> void:
	var rock := Mats.tri("stone_wall", Color("#9aa6be"), 0.95, 1.5)
	var rock_dark := Mats.tri("stone_wall", Color("#6e7a94"), 0.95, 1.5)
	var snow := Mats.tri("snow")
	var ice := Mats.tri("ice", Color.WHITE, 0.08, 0.5)
	Build.box(w, Vector3(14.0, 0.3, 96.0), Vector3(9.0, CHASM_FLOOR - 0.15, 0.0), snow)
	for zi in range(-48, 48):
		var z := zi + 0.5
		Build.box(w, Vector3(1.8, 0.06, 1.02), Vector3(_chasm_x(z), CHASM_FLOOR + 0.03, z), ice)
	for zi in range(-30, 30):
		# 這一列的空洞範圍（1 公尺一格），岩壁就在它的兩側
		var min_x := 99
		var max_x := -99
		for xi in range(0, 20):
			if is_void(Vector2(xi + 0.5, zi + 0.5)):
				min_x = mini(min_x, xi)
				max_x = maxi(max_x, xi)
		if min_x > max_x:
			continue
		for side: int in [-1, 1]:
			var face: float = float(min_x) if side < 0 else float(max_x + 1)
			var depth := w.rng.randf_range(0.7, 1.5)
			for tier in 2:
				if w.rng.randf() < 0.3:
					depth += w.rng.randf_range(1.4, 2.2)
					continue
				var out := snappedf(w.rng.randf_range(0.375, 0.875), 0.125)
				var cx: float = face - side * out * 0.5
				Build.box(w, Vector3(out, 0.5, 1.0), Vector3(cx, -depth - 0.25, zi + 0.5), rock if tier == 0 else rock_dark)
				if tier == 0:
					Build.box(w, Vector3(out, 0.08, 1.0), Vector3(cx, -depth + 0.04, zi + 0.5), snow)
				depth += w.rng.randf_range(1.4, 2.2)
	# 谷底的雪堆與石頭
	for i in 22:
		var z := w.rng.randf_range(-28.0, 28.0)
		var x := _chasm_x(z) + w.rng.randf_range(-2.6, 2.6)
		if absf(x - _chasm_x(z)) < 1.2:
			continue
		if i % 2 == 0:
			w.place(SetPieces.snow_mound(300 + i, w.rng.randf_range(0.5, 0.9)), Vector2(x, z), w.rng.randf() * 90.0, CHASM_FLOOR)
		else:
			w.place(PropBuilder.rock(400 + i, w.rng.randf_range(0.7, 1.3)), Vector2(x, z), w.rng.randf() * 360.0, CHASM_FLOOR)
