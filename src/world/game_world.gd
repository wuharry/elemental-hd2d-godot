class_name GameWorld
extends Node3D
## 依 SceneDef 把一個場景蓋出來。每個場景都走同一條流程：
## 地面 → 房屋 → 場景自己的擺放（populate）→ 花草 → 會動的東西。
## 場景檔只透過這裡的 place／tree／scatter 等方法放東西，不直接碰算繪設定。

var def: SceneDef
var rng := RandomNumberGenerator.new()
## 以下清單由 populate 過程累積，最後一次處理。
var flower_spots: Array[Vector3] = []
var chimneys: Array[Vector3] = []
var leaf_emitters: Array[Vector3] = []
var butterfly_homes: Array[Vector3] = []
var fires: Array[Vector3] = []
var _tree_seed := 1


func _init(scene_def: SceneDef = null) -> void:
	def = scene_def


func _ready() -> void:
	Mats.reset()
	rng.seed = hash(def.id)
	add_child(GroundBuilder.build(def))
	for cfg in def.houses:
		_house(cfg)
	def.populate(self)
	add_child(FoliageField.build(def, flower_spots))
	_ambient()


func v3(p: Vector2, y: float = 0.0) -> Vector3:
	return Vector3(p.x, y, p.y)


## 把一個零件放到場景裡。回傳同一個節點，方便接著讀 meta。
func place(node: Node3D, p: Vector2, yaw_deg: float = 0.0, y: float = 0.0) -> Node3D:
	node.position = v3(p, y)
	node.rotation_degrees.y = yaw_deg
	add_child(node)
	if node.has_meta("fire"):
		fires.append(node.position + (node.get_meta("fire") as Vector3))
	return node


func tree(p: Vector2, s: float, tint: Color, y: float = 0.0, tex_name: String = "leaves", snow: bool = false) -> Node3D:
	_tree_seed += 1
	var t := TreeBuilder.broadleaf(_tree_seed, s, tint, tex_name, snow)
	t.position = v3(p, y)
	add_child(t)
	if not snow:
		leaf_emitters.append(t.position + Vector3(0, 3.6 * s, 0))
	return t


func conifer(p: Vector2, s: float, tint: Color, snow: bool = false, y: float = 0.0) -> Node3D:
	_tree_seed += 1
	var t := TreeBuilder.conifer(_tree_seed, s, tint, snow)
	t.position = v3(p, y)
	add_child(t)
	return t


## 在 area 裡隨機撒 count 個東西。maker 收到 rng，回傳要放的節點（回傳 null 表示這次不放）。
## 只會放在能長草、離路夠遠的地方。
func scatter(count: int, area: Rect2, maker: Callable, max_dirt: float = 0.05) -> void:
	var placed := 0
	var tries := 0
	while placed < count and tries < count * 40:
		tries += 1
		var p := area.position + Vector2(rng.randf(), rng.randf()) * area.size
		if not def.can_grow(p) or def.dirt_at(p) > max_dirt:
			continue
		var node: Node3D = maker.call(rng, p)
		if node == null:
			continue
		node.position = v3(p)
		if is_zero_approx(node.rotation.y):
			node.rotation.y = rng.randf() * TAU
		add_child(node)
		placed += 1


func _house(cfg: Dictionary) -> void:
	var house := HouseBuilder.build(cfg)
	house.position = v3(cfg["pos"])
	house.rotation_degrees.y = cfg["rot"]
	add_child(house)
	for s in house.get_meta("flower_spots"):
		flower_spots.append(house.transform * (s as Vector3))
	if house.has_meta("chimney"):
		chimneys.append(house.transform * (house.get_meta("chimney") as Vector3))


func _ambient() -> void:
	var a: Dictionary = def.ambient
	if a.get("dust", false):
		add_child(AmbientLife.dust())
	if a.get("fireflies", false):
		add_child(AmbientLife.fireflies())
	if a.get("clouds", false):
		add_child(AmbientLife.clouds())
	if int(a.get("birds", 0)) > 0:
		add_child(AmbientLife.birds(int(a["birds"]), a.get("bird_height", Vector2(6.5, 9.5)), a.get("bird_tint", Color("#3a3440")), a.get("bird_orbit", 1.0)))
	if a.get("snow", false):
		add_child(AmbientLife.snowfall())
	if a.get("petals", false):
		add_child(AmbientLife.petals())
	if def.outer_ground:
		add_child(AmbientLife.rain())
		add_child(AmbientLife.rain_splashes())
	var leaf_ramp: Array = a.get("leaf_ramp", [])
	var leaf_amount: int = int(a.get("leaf_amount", 14))
	for p in leaf_emitters:
		add_child(AmbientLife.leaves(p, 1.8, a.get("leaf_tint", Color.WHITE), leaf_ramp, leaf_amount))
	for c in chimneys:
		add_child(AmbientLife.smoke(c))
	for f in fires:
		add_child(AmbientLife.fire(f))
	if not butterfly_homes.is_empty():
		add_child(AmbientLife.butterflies(butterfly_homes))
