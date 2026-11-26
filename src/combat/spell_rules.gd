class_name SpellRules
extends RefCounted
## 法術身分以原子元素及數量決定；融合產物永不在此展開成材料。

const CAPACITY := 4
const ORDINARY_PREFIX := "ordinary:"
## 原型數值，集中於此供實玩調整，不代表最終平衡。
const PROTOTYPE := {"damage_per_token": 12.0, "range": 10.0, "radius": 0.55, "duration": 4.0}
const NAMED := {
	"rain": {"name": "降雨", "recipe": [Elements.Type.MIST, Elements.Type.WATER, Elements.Type.WATER],
		"kind": "rain", "damage": 0.0, "range": 10.0, "radius": 10.0, "duration": 10.0},
}


static func recipe_key(elements: Array[int]) -> String:
	if elements.is_empty() or elements.size() > CAPACITY:
		return ""
	var sorted := elements.duplicate()
	sorted.sort()
	var parts := PackedStringArray()
	for element in sorted:
		if not Elements.INFO.has(element):
			return ""
		parts.append(str(element))
	return ":".join(parts)


## 可選 catalog 供不同法術書清單／測試注入；同配方可有多個具名 ID。
static func resolve(elements: Array[int], named_id: String = "", catalog: Dictionary = NAMED) -> Dictionary:
	var key := recipe_key(elements)
	if key.is_empty():
		return {}
	var sorted := elements.duplicate()
	sorted.sort()
	var dominant := _dominant(sorted)
	if not named_id.is_empty():
		if not catalog.has(named_id) or not catalog[named_id] is Dictionary:
			return {}
		var entry: Dictionary = catalog[named_id]
		var recipe := read_elements(entry.get("recipe"))
		if recipe_key(recipe) != key or not entry.get("name") is String or not entry.get("kind") is String:
			return {}
		for field: String in ["damage", "range", "radius", "duration"]:
			var value: Variant = entry.get(field)
			if not (value is float or value is int) or not is_finite(float(value)) or float(value) < 0.0:
				return {}
		return {"id": named_id, "name": entry["name"], "kind": entry["kind"],
			"elements": sorted, "dominant": dominant, "damage": float(entry["damage"]),
			"range": float(entry["range"]), "radius": float(entry["radius"]), "duration": float(entry["duration"])}
	var labels := PackedStringArray()
	for element in sorted:
		labels.append(Elements.display_name(element))
	return {"id": ORDINARY_PREFIX + key, "name": "＋".join(labels), "kind": "ordinary",
		"elements": sorted, "dominant": dominant,
		"damage": PROTOTYPE["damage_per_token"] * sorted.size(), "range": PROTOTYPE["range"],
		"radius": 2.4 if dominant == Elements.Type.MIST else PROTOTYPE["radius"],
		"duration": 6.0 if dominant == Elements.Type.MIST else PROTOTYPE["duration"]}


## 融合型態優先，其次數量；同權重使用穩定 ID，輸入順序不決定結果。
static func _dominant(elements: Array[int]) -> int:
	var counts: Dictionary = {}
	for element in elements:
		counts[element] = int(counts.get(element, 0)) + 1
	var best := elements[0]
	var score := -1
	for element: int in counts:
		var candidate: int = counts[element] + (0 if Elements.is_base(element) else CAPACITY)
		if candidate > score or (candidate == score and element < best):
			best = element
			score = candidate
	return best


## JSON 讀回的整數是 float；僅接受有限、精確整數，不截斷小數或轉換字串。
static func read_elements(value: Variant) -> Array[int]:
	var result: Array[int] = []
	if not value is Array or value.is_empty() or value.size() > CAPACITY:
		return result
	for item: Variant in value:
		var element := read_nonnegative_integer(item, 2147483647)
		if not Elements.INFO.has(element):
			return []
		result.append(element)
	return result


static func read_nonnegative_integer(value: Variant, maximum: int) -> int:
	if value is int:
		return value if value >= 0 and value <= maximum else -1
	if value is float and is_finite(value) and value >= 0.0 and value <= float(maximum) and value == floorf(value):
		return int(value)
	return -1


static func elements_from_ordinary_id(id: String) -> Array[int]:
	var result: Array[int] = []
	if not id.begins_with(ORDINARY_PREFIX):
		return result
	var key := id.trim_prefix(ORDINARY_PREFIX)
	for token in key.split(":"):
		if not token.is_valid_int():
			return []
		result.append(token.to_int())
	if recipe_key(result) != key:
		return []
	return result


## 三個完成品加兩份材料需要第五格，因此四個融合元素不能靠手排取得。
static func hand_reachable(elements: Array[int]) -> bool:
	if recipe_key(elements).is_empty():
		return false
	var fused := 0
	for element in elements:
		if not Elements.is_base(element):
			fused += 1
	return fused < CAPACITY
