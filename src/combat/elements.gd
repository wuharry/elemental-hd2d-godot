class_name Elements
extends RefCounted
## 元素定義與融合表。純資料，不碰任何節點（BLUEPRINT 第 4 節）。

enum Type {
	WATER, FIRE, LIGHTNING, ICE, STEAM, EARTH, ARCANE, LIFE,
	MIST, WOOD, POISON, LAVA, PLASMA, CRYSTAL, SUPERCONDUCT,
	METAL, LIGHT, MAGNETISM, MAGIC_CRYSTAL,
}

const INFO := {
	Type.WATER: {"name": "水", "color": Color("#3d9dff"), "base": true},
	Type.FIRE: {"name": "火", "color": Color("#ff5a2a"), "base": true},
	Type.LIGHTNING: {"name": "雷", "color": Color("#9d65ff"), "base": true},
	Type.ICE: {"name": "冰", "color": Color("#a8f0ff"), "base": true},
	Type.STEAM: {"name": "蒸汽", "color": Color("#e6ecf2"), "base": false, "ingredients": [Type.WATER, Type.FIRE]},
	Type.EARTH: {"name": "土", "color": Color("#c9945c"), "base": true},
	Type.ARCANE: {"name": "奧術", "color": Color("#b35ae2"), "accent": Color("#ef4057"), "base": true},
	Type.LIFE: {"name": "生命", "color": Color("#65df8f"), "base": true},
	Type.MIST: {"name": "霧", "color": Color("#b9d6ed"), "base": false, "ingredients": [Type.WATER, Type.ICE]},
	Type.WOOD: {"name": "木", "color": Color("#76b85b"), "base": false, "ingredients": [Type.WATER, Type.EARTH]},
	Type.POISON: {"name": "毒", "color": Color("#a4d849"), "base": false, "ingredients": [Type.WATER, Type.ARCANE]},
	Type.LAVA: {"name": "熔岩", "color": Color("#f47b35"), "base": false, "ingredients": [Type.FIRE, Type.EARTH]},
	Type.PLASMA: {"name": "電漿", "color": Color("#ef80df"), "base": false, "ingredients": [Type.FIRE, Type.LIGHTNING]},
	Type.CRYSTAL: {"name": "水晶", "color": Color("#86d9dc"), "base": false, "ingredients": [Type.ICE, Type.EARTH]},
	Type.SUPERCONDUCT: {"name": "超導", "color": Color("#9dbaff"), "base": false, "ingredients": [Type.LIGHTNING, Type.ICE]},
	Type.METAL: {"name": "金屬", "color": Color("#a7b6ca"), "base": false, "ingredients": [Type.EARTH, Type.ARCANE]},
	Type.LIGHT: {"name": "光", "color": Color("#ffedac"), "base": false, "ingredients": [Type.FIRE, Type.ARCANE]},
	Type.MAGNETISM: {"name": "磁力", "color": Color("#df689f"), "base": false, "ingredients": [Type.LIGHTNING, Type.ARCANE]},
	Type.MAGIC_CRYSTAL: {"name": "魔晶", "color": Color("#d3a5f2"), "base": false, "ingredients": [Type.ICE, Type.ARCANE]},
}

const SELECTABLE := [Type.WATER, Type.EARTH, Type.ICE, Type.LIGHTNING, Type.FIRE, Type.ARCANE, Type.LIFE]
## 新玩家的四個預設按鍵順序。
const LOADOUT := [Type.WATER, Type.FIRE, Type.LIGHTNING, Type.ICE]
## 圖集欄位固定，與元素 ID 無關（融合產物沒有配裝圖示）。
const ICON_ORDER := [Type.WATER, Type.FIRE, Type.LIGHTNING, Type.ICE, Type.EARTH, Type.ARCANE, Type.LIFE]

## 已確認的融合表。生命元素的融合尚未定案，不替它補配方。
## key 是兩個元素由小到大排序後的 "a:b"，所以水＋火與火＋水是同一筆。
const FUSION := {
	"0:1": Type.STEAM,
	"0:3": Type.MIST,
	"0:5": Type.WOOD,
	"0:6": Type.POISON,
	"1:5": Type.LAVA,
	"1:2": Type.PLASMA,
	"3:5": Type.CRYSTAL,
	"2:3": Type.SUPERCONDUCT,
	"5:6": Type.METAL,
	"1:6": Type.LIGHT,
	"2:6": Type.MAGNETISM,
	"3:6": Type.MAGIC_CRYSTAL,
}


static func display_name(e: int) -> String:
	return INFO[e]["name"]


static func color(e: int) -> Color:
	return INFO[e]["color"]


## 有漸層的元素共用兩端色，祭壇、圖示與光點不各自維護一套配色。
static func gradient_color(e: int, amount: float) -> Color:
	return color(e).lerp(INFO[e].get("accent", color(e)), clampf(amount, 0.0, 1.0))


static func is_base(e: int) -> bool:
	return INFO.has(e) and INFO[e]["base"]


## 兩個元素融合的結果；不能融合回傳 -1。
## DRAFT：複合元素不可再融合（Gemini 建議，Harvey 尚未拍板）。
static func fuse(a: int, b: int) -> int:
	if not is_base(a) or not is_base(b):
		return -1
	var key := "%d:%d" % [mini(a, b), maxi(a, b)]
	return FUSION.get(key, -1)
