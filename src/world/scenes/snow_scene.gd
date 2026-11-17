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
	grass_count = 6000
	flower_count = 0
	grass_tints = [Color("#b9c9b0"), Color("#dfe8d8"), Color("#cfc8a8")]
	backdrop = {"kind": "terraces", "cliff_tint": Color("#aeb8cc"), "top": "snow", "tree_tint_a": Color("#8fb09a"), "tree_tint_b": Color("#6a8f86"), "snow": true}
	ambient = {"dust": false, "fireflies": false, "clouds": true, "birds": 3, "snow": true}


## 裂谷：南北走向，中心線左右擺動。
func _chasm_x(z: float) -> float:
	return 9.0 + 2.0 * sin(z * 0.16) + 1.2 * sin(z * 0.41 + 1.0) - 1.2 * sin(1.0)


func is_void(p: Vector2) -> bool:
	return absf(p.x - _chasm_x(p.y)) < 3.6


func populate(w: GameWorld) -> void:
	# 裂谷底：一片深色，加上往下變暗的岩壁，看起來深不見底
	Build.box(w, Vector3(24.0, 0.2, 96.0), Vector3(9.0, -7.6, 0.0), Mats.flat(Color("#070a14"), 1.0))
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
