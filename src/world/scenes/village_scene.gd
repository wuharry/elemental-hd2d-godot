extends SceneDef
## 村莊：石板路、木屋、花草地、池塘、井、營火。第一個做出來的場景，其他場景的風格以它為準。


var lamps := [
	Vector2(-6.5, -0.4), Vector2(4.3, -0.6), Vector2(11.6, -0.8),
	Vector2(-16.0, 1.2), Vector2(3.9, 6.6), Vector2(21.0, 1.0),
]
var trees := [
	{"p": Vector2(-20.0, -4.5), "s": 1.35, "tint": Color("#ffffff")},
	{"p": Vector2(21.5, -5.5), "s": 1.25, "tint": Color("#e8f0b0")},
	{"p": Vector2(-11.5, 6.5), "s": 1.15, "tint": Color("#f4e89a")},
	{"p": Vector2(-24.0, 11.0), "s": 1.2, "tint": Color("#ffffff")},
	{"p": Vector2(10.5, 6.5), "s": 1.0, "tint": Color("#e2f0a8")},
	{"p": Vector2(18.0, 11.5), "s": 1.2, "tint": Color("#ffffff")},
	{"p": Vector2(-14.5, -14.0), "s": 1.1, "tint": Color("#dfeeb0")},
	{"p": Vector2(-2.0, -15.5), "s": 1.0, "tint": Color("#ffffff")},
	{"p": Vector2(9.0, -14.5), "s": 1.15, "tint": Color("#f0e090")},
	{"p": Vector2(20.5, -13.0), "s": 1.0, "tint": Color("#ffffff")},
	{"p": Vector2(28.0, 4.0), "s": 1.3, "tint": Color("#e8f0b0")},
	{"p": Vector2(-30.0, -2.0), "s": 1.3, "tint": Color("#ffffff")},
	{"p": Vector2(-12.0, 13.5), "s": 0.9, "tint": Color("#ffd98a")},
	{"p": Vector2(12.5, 16.0), "s": 1.0, "tint": Color("#ffffff")},
]


func _init() -> void:
	id = "village"
	title = "村莊"
	player_start = Vector3(0.6, 0.0, -1.2)
	paths = [
		{"pts": [Vector2(-40, 3.5), Vector2(-24, 1.6), Vector2(-13, -1.6), Vector2(-2, -3.0), Vector2(7, -2.5), Vector2(15, -3.0), Vector2(24, 0.0), Vector2(40, 2.0)], "width": 2.8},
		{"pts": [Vector2(1.0, -2.8), Vector2(3.0, 2.0), Vector2(1.6, 8.0), Vector2(5.0, 14.0), Vector2(4.0, 26.0)], "width": 2.0},
	]
	dirt_spots = [
		{"c": Vector2(6.2, 1.3), "r": 2.0},
		{"c": Vector2(-8.0, 3.2), "r": 1.6},
		{"c": Vector2(10.8, 3.4), "r": 1.5},
	]
	houses = [
		# Q 版建築每層約 1.6 公尺，門高 1.5 公尺。
		{"pos": Vector2(-10.5, -7.2), "rot": 6.0, "w": 4.6, "d": 3.8, "base_h": 1.7, "wall_h": 1.6, "roof_h": 1.9, "gable_front": false, "cols": 2, "floors": 1, "roof_tint": ROOF_BROWN, "seed": 1},
		{"pos": Vector2(-3.0, -7.8), "rot": 0.0, "w": 5.4, "d": 4.6, "base_h": 1.8, "wall_h": 3.2, "roof_h": 2.6, "gable_front": true, "cols": 3, "floors": 2, "roof_tint": ROOF_DARK, "seed": 2},
		{"pos": Vector2(4.6, -7.4), "rot": -4.0, "w": 4.8, "d": 4.0, "base_h": 1.8, "wall_h": 1.7, "roof_h": 2.3, "gable_front": true, "cols": 2, "floors": 1, "roof_tint": ROOF_SLATE, "seed": 3},
		{"pos": Vector2(11.8, -8.0), "rot": -9.0, "w": 4.4, "d": 3.8, "base_h": 1.7, "wall_h": 1.6, "roof_h": 1.9, "gable_front": false, "cols": 2, "floors": 1, "roof_tint": ROOF_RED, "seed": 4},
		{"pos": Vector2(19.0, -7.0), "rot": -16.0, "w": 4.6, "d": 3.8, "base_h": 1.7, "wall_h": 3.2, "roof_h": 2.2, "gable_front": true, "cols": 2, "floors": 2, "roof_tint": ROOF_BROWN, "seed": 12},
		{"pos": Vector2(-18.5, -6.0), "rot": 12.0, "w": 4.4, "d": 3.8, "base_h": 1.7, "wall_h": 1.6, "roof_h": 2.1, "gable_front": true, "cols": 2, "floors": 1, "roof_tint": ROOF_SLATE, "seed": 13},
		# 後排，主要是填景深
		{"pos": Vector2(-15.5, -14.5), "rot": 8.0, "w": 4.6, "d": 3.8, "base_h": 1.7, "wall_h": 1.7, "roof_h": 2.1, "gable_front": true, "cols": 2, "floors": 1, "roof_tint": ROOF_RED, "seed": 5},
		{"pos": Vector2(-7.5, -15.5), "rot": 0.0, "w": 5.2, "d": 4.2, "base_h": 1.8, "wall_h": 3.2, "roof_h": 2.4, "gable_front": false, "cols": 3, "floors": 2, "roof_tint": ROOF_BROWN, "seed": 6},
		{"pos": Vector2(1.0, -15.0), "rot": -3.0, "w": 4.6, "d": 3.8, "base_h": 1.7, "wall_h": 1.7, "roof_h": 2.1, "gable_front": true, "cols": 2, "floors": 1, "roof_tint": ROOF_RED, "seed": 7},
		{"pos": Vector2(8.5, -15.5), "rot": -6.0, "w": 5.0, "d": 4.2, "base_h": 1.8, "wall_h": 3.2, "roof_h": 2.4, "gable_front": true, "cols": 2, "floors": 2, "roof_tint": ROOF_DARK, "seed": 8},
		{"pos": Vector2(16.5, -15.0), "rot": -12.0, "w": 4.4, "d": 3.8, "base_h": 1.7, "wall_h": 1.6, "roof_h": 1.9, "gable_front": false, "cols": 2, "floors": 1, "roof_tint": ROOF_SLATE, "seed": 9},
		# 小棚子
		{"pos": Vector2(8.6, 5.2), "rot": 12.0, "w": 2.2, "d": 1.8, "base_h": 0.25, "wall_h": 1.35, "roof_h": 0.8, "gable_front": false, "cols": 0, "floors": 0, "roof_tint": ROOF_BROWN, "shed": true, "seed": 10},
		{"pos": Vector2(-18.5, 4.0), "rot": -10.0, "w": 2.4, "d": 1.8, "base_h": 0.25, "wall_h": 1.35, "roof_h": 0.8, "gable_front": true, "cols": 0, "floors": 0, "roof_tint": ROOF_DARK, "shed": true, "seed": 11},
	]
	ponds = [
		Rect2(-8.5, 6.0, 5.5, 3.5),
		Rect2(-7.5, 5.25, 3.5, 5.0),
		Rect2(-9.25, 7.0, 1.5, 1.75),
	]


func populate(w: GameWorld) -> void:
	for t in trees:
		w.tree(t["p"], t["s"], t["tint"])
	w.scatter(46, Rect2(-34, -21, 68, 43), _small_thing)
	for i in lamps.size():
		w.place(PropBuilder.lamp_post(i < 3), lamps[i], w.rng.randf() * 360.0)
	w.add_child(PropBuilder.pond(ponds))
	w.place(PropBuilder.well(), Vector2(-8.0, 3.2), 12.0)
	w.place(PropBuilder.log_pile(), Vector2(10.8, 3.4), 70.0)
	w.place(PropBuilder.campfire(), Vector2(6.2, 1.3))
	w.place(PropBuilder.crate(0.8), Vector2(10.6, -5.2), 8.0)
	w.place(PropBuilder.crate(0.6), Vector2(11.3, -4.7), 30.0)
	w.place(PropBuilder.barrel(), Vector2(3.0, -5.6))
	w.place(PropBuilder.barrel(), Vector2(-7.4, -4.9), 20.0)
	w.place(PropBuilder.crate(0.7), Vector2(-15.2, -5.0), 15.0)
	w.place(PropBuilder.fence(6.0), Vector2(-15.5, 8.6), 82.0)
	w.place(PropBuilder.fence(7.5), Vector2(13.5, 7.6), 8.0)
	w.place(PropBuilder.fence(6.0), Vector2(22.5, -2.8), -22.0)
	w.place(PropBuilder.fence(4.5), Vector2(-5.5, 12.6), -6.0)
	for h in [Vector2(-3.5, 2.5), Vector2(6.0, 1.5), Vector2(-9.5, -0.5), Vector2(8.5, 9.0), Vector2(-1.0, 11.0), Vector2(14.0, 1.5), Vector2(-15.0, 11.5), Vector2(0.5, 5.5), Vector2(17.0, -1.5), Vector2(-20.0, 1.0)]:
		w.butterfly_homes.append(w.v3(h))


## 灌木、石頭、零星的針葉樹。
func _small_thing(rng: RandomNumberGenerator, p: Vector2) -> Node3D:
	var roll := rng.randf()
	if roll < 0.55:
		return TreeBuilder.bush(rng.randi(), rng.randf_range(0.8, 1.3), Color("#e6f0c0").lerp(Color("#ffffff"), rng.randf()))
	if roll < 0.8:
		return PropBuilder.rock(rng.randi(), rng.randf_range(0.7, 1.3))
	# 針葉樹只放在外圍，不擋住村子中央
	if absf(p.x) < 16.0 and p.y > -12.0 and p.y < 14.0:
		return null
	return TreeBuilder.conifer(rng.randi(), rng.randf_range(1.0, 1.5), Color("#a9c890"))
