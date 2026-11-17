extends SceneDef
## 地下城大廳：石板大廳、兩條水道、石板橋、轉動的齒輪、火盆、天窗灑下的一道光。
## 室內場景：沒有外圍地面，鏡頭那一側不蓋牆，像切開的模型。
## 玩法上預留的互動：水道（導電／結冰成橋）、火盆（點燃／熄滅）、齒輪機關、狹窄走道。

const HALL := Vector2(21.0, 13.0)
const MOSS := [
	{"c": Vector2(-15.0, 8.5), "r": 2.6}, {"c": Vector2(15.5, -9.0), "r": 2.2},
	{"c": Vector2(-14.5, -9.5), "r": 2.0}, {"c": Vector2(16.5, 9.5), "r": 2.4}, {"c": Vector2(6.0, 9.0), "r": 1.6},
]


func _init() -> void:
	id = "dungeon"
	title = "地下城大廳"
	player_start = Vector3(0.0, 0.0, 8.5)
	play_half = Vector2(20.0, 12.0)
	paths = [
		{"pts": [Vector2(0, 13), Vector2(0, -9)], "width": 3.2},
		{"pts": [Vector2(-21, -1), Vector2(21, -1)], "width": 2.2},
	]
	dirt_spots = MOSS
	bridges = [Rect2(-1.5, 2.5, 3.0, 3.0), Rect2(11.0, 2.5, 3.0, 3.0), Rect2(-9.5, -6.0, 3.0, 2.0)]
	ground = {
		"base": "flagstone", "base_tint": Color.WHITE,
		"dirt": "flagstone", "dirt_tint": Color("#9fb08e"),
		"path": "brick", "path_tint": Color("#c8a8a0"),
		"side": "brick", "side_tint": Color("#9a8e98"),
		"path_roughness": 0.85, "base_roughness": 0.8,
	}
	grass_count = 2600
	flower_count = 60
	grass_tints = [Color("#6f9a6a"), Color("#8fb480"), Color("#a8b070")]
	outer_ground = false
	backdrop = {"kind": "walls", "wall": "brick", "wall_tint": Color("#a89ca4"), "height": 9.0, "skylight": Rect2(-3.0, -13.0, 6.0, 5.0)}
	ambient = {"dust": true, "fireflies": false, "clouds": false, "birds": 4, "bird_height": Vector2(3.5, 5.5), "bird_tint": Color("#2a2430"), "snow": false}


func is_void(p: Vector2) -> bool:
	if absf(p.x) > HALL.x or absf(p.y) > HALL.y:
		return true
	if p.y > 3.0 and p.y < 5.0:
		return true
	if p.x > -9.0 and p.x < -7.0 and p.y < 3.0:
		return true
	return false


func _in_moss(p: Vector2) -> bool:
	for m in MOSS:
		if p.distance_to(m["c"]) < m["r"]:
			return true
	return false


## 地下城只有苔蘚區長草。
func can_grow(p: Vector2) -> bool:
	return _in_moss(p) and not near_void(p, 0.3) and path_at(p) < 0.2


func grow_density(_p: Vector2) -> float:
	return 1.0


func populate(w: GameWorld) -> void:
	var deep := Color("#0c2630")
	var shallow := Color("#1f5a66")
	w.add_child(SetPieces.water_fill(Rect2(-21, 3, 42, 2), -0.5, Vector2(0.5, 0.0), deep, shallow))
	w.add_child(SetPieces.water_fill(Rect2(-9, -13, 2, 16), -0.5, Vector2(0.0, 0.5), deep, shallow))
	w.place(SetPieces.stone_bridge(2.6, 3.0), Vector2(0.0, 4.0), 90.0)
	w.place(SetPieces.stone_bridge(2.6, 3.0), Vector2(12.5, 4.0), 90.0)
	w.place(SetPieces.stone_bridge(2.6, 2.0), Vector2(-8.0, -5.0))

	# 後排是完整的石柱，前排（靠鏡頭）只放斷柱，才不會擋住畫面
	for x in [-13.0, -4.5, 4.5, 13.0]:
		w.place(SetPieces.pillar(7.0), Vector2(x, -9.0))
	w.place(SetPieces.broken_pillar(1), Vector2(-13.0, 9.0), 20.0)
	w.place(SetPieces.broken_pillar(2), Vector2(4.5, 9.5), 200.0)
	w.place(SetPieces.broken_pillar(3), Vector2(13.5, 8.5), 110.0)

	# 天光落下的祭壇，上面一叢水晶
	w.place(SetPieces.dais(4.4), Vector2(0.0, -5.2))
	w.place(SetPieces.crystals(81, Color("#9fe8ff"), 1.3), Vector2(0.0, -5.2), 0.0, 1.54)
	w.place(SetPieces.brazier(), Vector2(-3.6, -2.4))
	w.place(SetPieces.brazier(), Vector2(3.6, -2.4))
	w.place(SetPieces.brazier(), Vector2(-12.0, 7.0))
	w.place(SetPieces.brazier(), Vector2(9.0, 8.0))
	for x in [-15.0, -3.0, 3.0, 15.0]:
		w.place(SetPieces.wall_torch(), Vector2(x, -HALL.y), 0.0, 3.2)
	w.place(SetPieces.banner(Color("#8a2a38"), 3.2), Vector2(-9.0, -HALL.y), 0.0, 7.4)
	w.place(SetPieces.banner(Color("#2a6a78"), 3.2), Vector2(9.0, -HALL.y), 0.0, 7.4)

	# 齒輪機關：地上一大一小互相咬合，牆上再掛一個
	var bronze := Color("#b8863c")
	w.place(SetPieces.gear(2.4, 0.3, bronze, 0.25), Vector2(11.0, -5.5), 0.0, 0.16)
	w.place(SetPieces.gear(1.3, 0.3, Color("#8a909c"), -0.46), Vector2(14.7, -3.6), 0.0, 0.2)
	Build.collider(w, Vector3(4.6, 2.0, 4.6), Vector3(11.0, 1.0, -5.5))
	var wall_gear := w.place(SetPieces.gear(2.0, 0.3, bronze, 0.3), Vector2(-15.0, -HALL.y + 0.25), 0.0, 5.2)
	wall_gear.rotation_degrees.x = 90.0

	w.place(SetPieces.crystals(82, Color("#b48cff"), 1.1), Vector2(-18.5, -10.5))
	w.place(SetPieces.crystals(83, Color("#7fe6ff"), 1.0), Vector2(18.5, 10.0))
	w.place(SetPieces.crystals(84, Color("#7fe6ff"), 0.9), Vector2(-18.5, 10.5))
	w.place(SetPieces.crystals(85, Color("#b48cff"), 0.9), Vector2(17.5, -3.0))

	w.place(PropBuilder.crate(0.8), Vector2(17.6, 6.6), 12.0)
	w.place(PropBuilder.crate(0.6), Vector2(18.4, 7.5), 40.0)
	w.place(PropBuilder.barrel(), Vector2(16.6, 7.6))
	w.place(PropBuilder.barrel(), Vector2(-17.5, -3.5))
	w.place(PropBuilder.crate(0.7), Vector2(-18.3, -4.4), 25.0)

	# 碎石：散在走道以外的地板上
	var placed := 0
	var tries := 0
	while placed < 16 and tries < 800:
		tries += 1
		var p := Vector2(w.rng.randf_range(-19, 19), w.rng.randf_range(-11, 11))
		if near_void(p, 1.0) or path_at(p) > 0.1 or p.distance_to(Vector2(0, -5.2)) < 4.0:
			continue
		w.place(PropBuilder.rock(w.rng.randi(), w.rng.randf_range(0.5, 1.0)), p, w.rng.randf() * 360.0)
		placed += 1
	for m in MOSS:
		w.place(SetPieces.mushrooms(int(m["c"].x * 3.0) + 200, true), m["c"] + Vector2(0.6, -0.4))
		w.place(SetPieces.mushrooms(int(m["c"].y * 5.0) + 300, true), m["c"] + Vector2(-0.9, 0.7))
	w.add_child(AmbientLife.drips(Vector3(0, 8.0, 0), Vector3(18.0, 0.2, 11.0)))
