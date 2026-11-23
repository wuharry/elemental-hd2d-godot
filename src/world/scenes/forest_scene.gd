extends SceneDef
## 森林河谷：一條河穿過森林，木板橋、瀑布、遺跡拱門、河邊營地。
## 玩法上預留的互動：水（潮濕／導電／結冰）、木橋與落木（可燃）、河岸高低差。

const RIVER := [Vector2(-10, -48), Vector2(-10, -22), Vector2(-6, -12), Vector2(-2, -6), Vector2(-2, 6), Vector2(2, 12), Vector2(6, 20), Vector2(6, 48)]
const RIVER_HALF := 2.3
const CAMP := Vector2(8.0, 5.5)
const SHRINE := Vector2(9.5, -11.0)


func _init() -> void:
	id = "forest"
	title = "森林河谷"
	player_start = Vector3(4.0, 0.0, 1.2)
	interactions = {"equip": SHRINE + Vector2(0, 2.2), "to_village": Vector2(5.4, -8.7)}
	play_half = Vector2(30.0, 19.0)
	paths = [
		{"pts": [Vector2(-40, 2), Vector2(-16, 1), Vector2(-5, 0), Vector2(1, 0), Vector2(10, -1.5), Vector2(22, -3), Vector2(40, -2)], "width": 2.2},
		{"pts": [Vector2(10, -1.5), Vector2(11, -6), Vector2(9.5, -9.5)], "width": 1.6},
		{"pts": [interactions["to_village"], interactions["equip"]], "width": 1.8},
	]
	dirt_spots = [{"c": CAMP, "r": 2.6}, {"c": SHRINE, "r": 2.8}, {"c": interactions["to_village"], "r": 2.2}]
	bridges = [Rect2(-5.0, -1.25, 6.0, 2.5)]
	ground = {
		"base": "grass_ground", "base_tint": Color("#cfe0b4"),
		"dirt": "dirt", "dirt_tint": Color("#e6d8c4"),
		"path": "dirt", "path_tint": Color("#f0dcb8"),
		"side": "stone_wall", "side_tint": Color("#8f8068"),
		"path_roughness": 1.0,
	}
	grass_count = 46000
	flower_count = 5200
	grass_tints = [Color("#86b46c"), Color("#c8e6a0"), Color("#e6de8c")]
	backdrop = {"kind": "terraces", "cliff_tint": Color("#9a9484"), "top": "grass_ground", "tree_tint_a": Color("#8fb47a"), "tree_tint_b": Color("#5f8a62"), "snow": false}
	ambient = {"dust": true, "fireflies": true, "clouds": true, "birds": 4, "snow": false}


func is_void(p: Vector2) -> bool:
	for i in RIVER.size() - 1:
		var a: Vector2 = RIVER[i]
		var b: Vector2 = RIVER[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		if p.distance_to(a + ab * t) < RIVER_HALF:
			return true
	return false


func populate(w: GameWorld) -> void:
	w.add_child(SetPieces.water_fill(Rect2(-16, -48, 28, 96), -0.4, Vector2(0.15, 0.9)))
	w.place(SetPieces.plank_bridge(6.4, 2.5), Vector2(-2.0, 0.0))
	var fall := w.place(SetPieces.waterfall(4.6, 3.4), Vector2(-10.0, -23.5))
	w.add_child(AmbientLife.splash(fall.position + (fall.get_meta("splash") as Vector3) + Vector3(0, -0.3, 0), 4.6))
	# 河裡露出水面的石頭
	for p in [Vector2(-2.6, -3.5), Vector2(-1.2, 4.0), Vector2(1.6, 11.0), Vector2(-9.4, -18.0), Vector2(-5.5, -10.5)]:
		w.place(PropBuilder.rock(int(p.x * 7.0 + p.y * 13.0) + 99, 1.2), p, 0.0, -0.5)

	# 樹：避開路、河、營地、遺跡，並在開場鏡頭前留一塊空地
	var spots: Array[Vector2] = []
	var tries := 0
	var tints := [Color("#ffffff"), Color("#e0f0b0"), Color("#f0e69a"), Color("#cfe8c0")]
	while spots.size() < 22 and tries < 4000:
		tries += 1
		var p := Vector2(w.rng.randf_range(-33, 33), w.rng.randf_range(-21, 21))
		if not can_grow(p) or path_info(p).x < 4.2 or near_void(p, 2.5):
			continue
		if p.y > 2.5 and absf(p.x - 4.0) < 12.0:
			continue
		if p.distance_to(CAMP) < 5.5 or p.distance_to(SHRINE) < 5.0:
			continue
		var ok := true
		for q in spots:
			if p.distance_to(q) < 5.0:
				ok = false
		if not ok:
			continue
		spots.append(p)
		w.tree(p, w.rng.randf_range(0.95, 1.4), tints[spots.size() % tints.size()])
	w.scatter(10, Rect2(-34, -21, 68, 42), func(rng: RandomNumberGenerator, p: Vector2) -> Node3D:
		if absf(p.x) < 18.0 and p.y > -14.0:
			return null
		return TreeBuilder.conifer(rng.randi(), rng.randf_range(1.1, 1.6), Color("#a0c088")))
	w.scatter(44, Rect2(-34, -21, 68, 42), func(rng: RandomNumberGenerator, _p: Vector2) -> Node3D:
		return TreeBuilder.bush(rng.randi(), rng.randf_range(0.8, 1.4), Color("#d8ecb0").lerp(Color("#ffffff"), rng.randf())))
	w.scatter(18, Rect2(-34, -21, 68, 42), func(rng: RandomNumberGenerator, _p: Vector2) -> Node3D:
		return PropBuilder.rock(rng.randi(), rng.randf_range(0.8, 1.6)))
	w.scatter(20, Rect2(-30, -19, 60, 38), func(rng: RandomNumberGenerator, _p: Vector2) -> Node3D:
		return SetPieces.mushrooms(rng.randi(), rng.randf() < 0.35))

	w.place(SetPieces.fallen_log(3.2), Vector2(6.5, -4.5), 28.0)
	w.place(SetPieces.fallen_log(2.6), Vector2(-9.5, 5.0), -40.0)
	w.place(SetPieces.fallen_log(3.6), Vector2(16.5, 4.0), 75.0)
	w.place(SetPieces.ruin_arch(), SHRINE + Vector2(0, -1.0), -8.0)
	w.place(SetPieces.element_altar(), SHRINE + Vector2(0, 0.6))
	w.place(SetPieces.waygate(), interactions["to_village"], 48.0)
	w.place(SetPieces.tent(Color("#c9b48a")), CAMP + Vector2(2.4, 1.2), -28.0)
	w.place(PropBuilder.campfire(), CAMP + Vector2(-1.0, -0.6))
	w.place(PropBuilder.crate(0.7), CAMP + Vector2(1.0, -2.4), 20.0)
	w.place(PropBuilder.barrel(), CAMP + Vector2(1.9, -2.0))
	w.place(PropBuilder.lamp_post(true), Vector2(1.9, 1.7), 200.0)
	w.place(PropBuilder.lamp_post(true), Vector2(-5.9, -1.7), 20.0)
	w.place(PropBuilder.fence(4.0), Vector2(3.4, 5.0), 78.0)
	for h in [Vector2(5.0, -3.0), Vector2(-8.0, 3.0), Vector2(12.0, 2.0), Vector2(2.0, 8.0), Vector2(-14.0, -4.0), Vector2(16.0, -7.0), Vector2(-4.5, -8.5), Vector2(20.0, 3.0)]:
		w.butterfly_homes.append(w.v3(h))
