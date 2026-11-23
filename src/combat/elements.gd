class_name Elements
extends RefCounted
## 元素定義與融合表。純資料，不碰任何節點（BLUEPRINT 第 4 節）。

enum Type { WATER, FIRE, LIGHTNING, ICE, STEAM, EARTH, ARCANE }

const INFO := {
	Type.WATER: {"name": "水", "color": Color("#3d9dff"), "base": true},
	Type.FIRE: {"name": "火", "color": Color("#ff5a2a"), "base": true},
	Type.LIGHTNING: {"name": "雷", "color": Color("#ffe14a"), "base": true},
	Type.ICE: {"name": "冰", "color": Color("#a8f0ff"), "base": true},
	Type.STEAM: {"name": "蒸", "color": Color("#e6ecf2"), "base": false},
	Type.EARTH: {"name": "土", "color": Color("#c9945c"), "base": true},
	Type.ARCANE: {"name": "奧術", "color": Color("#bd7aff"), "base": true},
}

const SELECTABLE := [Type.WATER, Type.EARTH, Type.ICE, Type.LIGHTNING, Type.FIRE, Type.ARCANE]
## 新玩家的四個預設按鍵順序。
const LOADOUT := [Type.WATER, Type.FIRE, Type.LIGHTNING, Type.ICE]
## 圖集欄位固定，與元素 ID 無關（融合產物沒有配裝圖示）。
const ICON_ORDER := [Type.WATER, Type.FIRE, Type.LIGHTNING, Type.ICE, Type.EARTH, Type.ARCANE]

## 融合表。規則文件只定了「水＋火＝蒸氣」，其餘配方尚未設計，不要自己補。
## key 是兩個元素由小到大排序後的 "a:b"，所以水＋火與火＋水是同一筆。
const FUSION := {
	"0:1": Type.STEAM,
}


static func display_name(e: int) -> String:
	return INFO[e]["name"]


static func color(e: int) -> Color:
	return INFO[e]["color"]


static func is_base(e: int) -> bool:
	return INFO[e]["base"]


## 兩個元素融合的結果；不能融合回傳 -1。
## DRAFT：複合元素不可再融合（Gemini 建議，Harvey 尚未拍板）。
static func fuse(a: int, b: int) -> int:
	if not is_base(a) or not is_base(b):
		return -1
	var key := "%d:%d" % [mini(a, b), maxi(a, b)]
	return FUSION.get(key, -1)
