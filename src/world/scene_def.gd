class_name SceneDef
extends RefCounted
## 一個場景的定義：資料（路、屋、地面材質）+ populate() 擺放。
## 所有場景都繼承這個，並且只能用共用零件（Mats／Build／*Builder／AmbientLife）組出來，
## 這樣新場景自動沿用同一套像素密度、幾何語彙、光影與鏡頭（BLUEPRINT 第 2–4 節）。
## 座標：X 向右、Z 朝鏡頭（負 Z 是畫面深處）、單位公尺、可走的地面在 y = 0。

const ROOF_BROWN := Color("#6a5146")
const ROOF_DARK := Color("#54433c")
const ROOF_SLATE := Color("#56627a")
const ROOF_RED := Color("#93503c")
const ROOF_SNOW := Color("#e9eef8")

var id := ""
var title := ""
var world_size := 96.0
var player_start := Vector3.ZERO
## 玩家可站立並觸發互動的位置（XZ，公尺），也供場景擺件與傳送落點共用。
var interactions: Dictionary = {}
## 玩家可走的範圍（中心 0,0）。
var play_half := Vector2(30.0, 17.0)

## 路：每條是 {pts: 折線, width: 路寬}。
var paths: Array = []
## 裸土圓：{c: 中心, r: 半徑}
var dirt_spots: Array = []
## 房屋設定（HouseBuilder.build 的參數 + pos／rot）。GameWorld 會自動蓋。
var houses: Array = []
## 水池：Rect2(x, z, 寬, 深)。不長草、不能走。
var ponds: Array = []
## 架在空洞（河、裂谷、水道）上的橋面：Rect2。橋面範圍內可以走。
var bridges: Array = []

## 地面三層 + 側面的貼圖與色調。貼圖名稱對應 assets/textures/。
var ground := {
	"base": "grass_ground", "base_tint": Color.WHITE,
	"dirt": "dirt", "dirt_tint": Color.WHITE,
	"path": "cobble", "path_tint": Color.WHITE,
	"side": "stone_wall", "side_tint": Color("#a8a294"),
}
## 花草數量與草色（三個顏色之間依位置混合）。
var grass_count := 42000
var flower_count := 7000
var grass_tints := [Color("#9cc67c"), Color("#dcf0b4"), Color("#f0e69a")]
## 草叢圖集（assets/textures/ 裡 32x16、兩格的那種）。雪地用 grass_tuft_frost。
var grass_atlas := "grass_tuft"
## 外圍背景：terraces（台地 + 針葉林）、walls（室內牆）、none。
var backdrop := {"kind": "terraces", "cliff_tint": Color("#a8a294"), "top": "grass_ground", "tree_tint_a": Color("#9fc08a"), "tree_tint_b": Color("#6f9a72"), "snow": false}
## 核心區以外要不要鋪地（室內場景不鋪，外面就是一片黑）。
var outer_ground := true
## 會動的東西的開關與數量（BLUEPRINT A10：每個場景至少要有四種）。
var ambient := {"dust": true, "fireflies": true, "clouds": true, "birds": 5, "snow": false}
## 場景的光影微調以 id 對應 TimeOfDay.PRESETS.scene_overrides，不在這裡另放數值。


## 這個點是不是空洞（河、裂谷、水道、室外）。空洞不鋪地、不能走、不長草。
func is_void(_p: Vector2) -> bool:
	return false


## 擺放這個場景特有的東西。用 world 提供的 place／tree／scatter 等方法。
func populate(_world: GameWorld) -> void:
	pass


## 到最近一條路中心線的距離，以及那條路的寬度。回傳 Vector2(距離, 寬度)。
func path_info(p: Vector2) -> Vector2:
	var best := 1e9
	var best_w := 2.0
	for path in paths:
		var pts: Array = path["pts"]
		var w: float = path["width"]
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var ab := b - a
			var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			var d := p.distance_to(a + ab * t) - w * 0.5
			if d < best:
				best = d
				best_w = w
	return Vector2(best + best_w * 0.5, best_w)


## 路面覆蓋率 0..1（1 = 路中央）。
func path_at(p: Vector2) -> float:
	if paths.is_empty():
		return 0.0
	var info := path_info(p)
	return 1.0 - smoothstep(info.y * 0.5 - 0.5, info.y * 0.5 + 0.5, info.x)


## 裸土覆蓋率 0..1：路的兩側 + 裸土圓 + 每間屋子門口。
func dirt_at(p: Vector2) -> float:
	var v := 0.0
	if not paths.is_empty():
		var info := path_info(p)
		v = 1.0 - smoothstep(info.y * 0.5 + 0.2, info.y * 0.5 + 1.3, info.x)
	for spot in dirt_spots:
		var d: float = p.distance_to(spot["c"])
		v = maxf(v, 1.0 - smoothstep(spot["r"] - 0.8, spot["r"] + 0.4, d))
	for h in houses:
		if h.get("shed", false):
			continue
		var door: Vector2 = h["pos"] + Vector2(0, h["d"] * 0.5 + 0.9).rotated(-deg_to_rad(h["rot"]))
		v = maxf(v, 1.0 - smoothstep(0.5, 1.6, p.distance_to(door)))
	return v


func in_pond(p: Vector2, margin: float = 0.0) -> bool:
	for r in ponds:
		if (r as Rect2).grow(margin).has_point(p):
			return true
	return false


func in_house(p: Vector2, margin: float = 0.4) -> bool:
	for h in houses:
		var c: Vector2 = h["pos"]
		var half := Vector2(h["w"] * 0.5 + margin + 0.2, h["d"] * 0.5 + margin + 0.2)
		var local := (p - c).rotated(deg_to_rad(h["rot"]))
		if absf(local.x) < half.x and absf(local.y) < half.y:
			return true
	return false


func on_bridge(p: Vector2) -> bool:
	for r in bridges:
		if (r as Rect2).has_point(p):
			return true
	return false


## 空洞邊緣往外 margin 公尺內也算（花草不要長到懸在半空）。
func near_void(p: Vector2, margin: float) -> bool:
	return is_void(p) or is_void(p + Vector2(margin, 0)) or is_void(p - Vector2(margin, 0)) or is_void(p + Vector2(0, margin)) or is_void(p - Vector2(0, margin))


## 這個點能不能長花草。場景可以覆寫（例如地下城只在苔蘚區長）。
func can_grow(p: Vector2) -> bool:
	if dirt_at(p) > 0.45 or in_pond(p, 0.35) or in_house(p) or near_void(p, 0.3):
		return false
	return true


## 這個點的草有多密（0..1）。預設靠近路與裸土就稀疏；場景可以覆寫。
func grow_density(p: Vector2) -> float:
	return 1.0 - clampf(dirt_at(p) * 1.6, 0.0, 1.0)
