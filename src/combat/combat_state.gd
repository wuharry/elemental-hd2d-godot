class_name CombatState
extends RefCounted
## 原型用的生命、狀態與元素盾。只收資料，不認識場景、佇列或呈現節點。

signal changed

## 尚非正式平衡；秒數、持續傷害與倍率集中在此，方便實玩後調整。
const PROTOTYPE_BALANCE := {
	"wet_seconds": 4.0,
	"burning_seconds": 4.0,
	"burning_dps": 3.0,
	"poisoned_seconds": 5.0,
	"poisoned_dps": 2.0,
	"frozen_seconds": 2.0,
	"wet_lightning_multiplier": 1.5,
}
## 原型解除表只移除列出的狀態，不清空其他狀態，也不接觸待發元素。
const PROTOTYPE_SHIELD_CLEANSES := {
	Elements.Type.WATER: ["burning"],
	Elements.Type.FIRE: ["frozen"],
	Elements.Type.LIGHTNING: ["wet"],
	Elements.Type.ICE: ["burning"],
	Elements.Type.EARTH: [],
	Elements.Type.ARCANE: [],
	Elements.Type.LIFE: ["poisoned"],
}

var max_health := 100.0
var health := 100.0
var statuses: Dictionary = {}
var shield_element := -1
var shield_remaining := 0.0
## 原型採觸發後固定秒數，與輸入端長按觸發時間分開。
var shield_duration := 5.0
var is_concealed := false:
	set(value):
		if is_concealed == value:
			return
		is_concealed = value
		changed.emit()

# 熔岩仍是獨立原子元素：不能因為它造成燃燒，就讓火盾抵銷其持續傷害。
var _burning_element: int = Elements.Type.FIRE


## 訓練場復原入口；正式死亡／復活規則尚未定案。
func reset() -> void:
	health = max_health
	statuses.clear()
	shield_element = -1
	shield_remaining = 0.0
	_burning_element = Elements.Type.FIRE
	is_concealed = false
	changed.emit()


func has_status(status: String) -> bool:
	return _status_seconds(status) > 0.0


func activate_shield(element: int) -> bool:
	if not Elements.INFO.has(element) or not Elements.is_base(element):
		return false
	if not is_finite(shield_duration) or shield_duration <= 0.0:
		return false
	var previous_statuses := statuses.duplicate(true)
	var previous_element := shield_element
	var previous_remaining := shield_remaining
	shield_element = element
	shield_remaining = shield_duration
	for status: String in PROTOTYPE_SHIELD_CLEANSES.get(element, []):
		statuses.erase(status)
	if previous_element != shield_element or previous_remaining != shield_remaining or previous_statuses != statuses:
		changed.emit()
	return true


func tick(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	var previous_statuses := statuses.duplicate(true)
	var previous_health := health
	var previous_element := shield_element
	var previous_remaining := shield_remaining
	if has_status("wet"):
		statuses.erase("burning")
	# 積分只計狀態仍有效的時間；大 delta 不會多算整幀的傷害。
	var burning_time := minf(delta, _status_seconds("burning"))
	if _shield_blocks(_burning_element):
		burning_time = maxf(0.0, burning_time - minf(delta, shield_remaining))
	var poison_time := minf(delta, _status_seconds("poisoned"))
	var dot_damage: float = burning_time * PROTOTYPE_BALANCE["burning_dps"] + poison_time * PROTOTYPE_BALANCE["poisoned_dps"]
	health = maxf(0.0, health - dot_damage)
	# 場上邏輯可加入 rooted 等限時狀態，統一走相同倒數路徑。
	for key: Variant in statuses.keys():
		var remaining := _status_seconds(key) - delta
		if remaining <= 0.0:
			statuses.erase(key)
		else:
			statuses[key] = remaining
	if is_finite(shield_remaining) and shield_remaining > 0.0:
		shield_remaining = maxf(0.0, shield_remaining - delta)
	else:
		shield_remaining = 0.0
	if shield_remaining == 0.0:
		shield_element = -1
	if previous_health != health or previous_statuses != statuses or previous_element != shield_element or previous_remaining != shield_remaining:
		changed.emit()


## 傷害依顆數分攤；一顆融合元素仍是一顆，不還原成兩份原料。
## damage 回傳實際扣血，healed 額外回傳實際補血；兩者皆為非負值。
func apply(elements: Array[int], damage: float) -> Dictionary:
	var result := {"damage": 0.0, "blocked": false, "reaction": "", "healed": 0.0}
	if elements.is_empty() or elements.size() > 4 or not is_finite(damage) or damage < 0.0:
		result["reaction"] = "invalid"
		return result
	for element: int in elements:
		if not Elements.INFO.has(element):
			result["reaction"] = "invalid"
			return result
	var active: Dictionary = {}
	var active_count := 0
	for element: int in elements:
		if _shield_blocks(element):
			result["blocked"] = true
			continue
		active[element] = int(active.get(element, 0)) + 1
		active_count += 1
	var reactions := PackedStringArray()
	if result["blocked"]:
		reactions.append("blocked")
	if active.is_empty():
		result["reaction"] = "+".join(reactions)
		return result
	var previous_statuses := statuses.duplicate(true)
	var previous_health := health
	var has_water := active.has(Elements.Type.WATER)
	var previous_burning_element := _burning_element
	var has_ice := active.has(Elements.Type.ICE)
	var has_heat := active.has(Elements.Type.FIRE) or active.has(Elements.Type.LAVA)
	# 先收完整成分，再按固定反應順序結算；交換輸入順序不改變結果。
	if has_water:
		statuses["wet"] = PROTOTYPE_BALANCE["wet_seconds"]
		reactions.append("wet")
	if has_water or has_ice:
		if statuses.erase("burning"):
			reactions.append("extinguished")
	if has_heat and statuses.erase("frozen"):
		statuses["wet"] = PROTOTYPE_BALANCE["wet_seconds"]
		reactions.append("melted")
	if has_ice and has_status("wet") and not has_heat:
		statuses["frozen"] = PROTOTYPE_BALANCE["frozen_seconds"]
		reactions.append("frozen")
	if has_heat and not has_water and not has_ice and not has_status("wet"):
		statuses["burning"] = PROTOTYPE_BALANCE["burning_seconds"]
		_burning_element = Elements.Type.LAVA if active.has(Elements.Type.LAVA) else Elements.Type.FIRE
		reactions.append("burning")
	if active.has(Elements.Type.POISON):
		statuses["poisoned"] = PROTOTYPE_BALANCE["poisoned_seconds"]
		reactions.append("poisoned")
	var portion := damage / float(elements.size())
	var life_count: int = active.get(Elements.Type.LIFE, 0)
	var raw_damage := portion * (active_count - life_count)
	if active.has(Elements.Type.LIGHTNING) and has_status("wet"):
		raw_damage += portion * int(active[Elements.Type.LIGHTNING]) * (float(PROTOTYPE_BALANCE["wet_lightning_multiplier"]) - 1.0)
		reactions.append("electrified")
	var actual_damage := minf(maxf(health, 0.0), raw_damage)
	health = maxf(0.0, health - actual_damage)
	# 原型固定先傷害後治療，與同一配方的輸入順序無關。
	var actual_healing := minf(maxf(0.0, max_health - health), portion * life_count)
	health += actual_healing
	if actual_healing > 0.0:
		reactions.append("healed")
	result["damage"] = actual_damage
	result["healed"] = actual_healing
	result["reaction"] = "+".join(reactions)
	if previous_health != health or previous_statuses != statuses or previous_burning_element != _burning_element:
		changed.emit()
	return result


## runtime 只在真正受有效雨量曝露時呼叫；室內與晴天不可呼叫。
func rain_exposure(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0 or _shield_blocks(Elements.Type.WATER):
		return
	var previous_statuses := statuses.duplicate(true)
	statuses["wet"] = PROTOTYPE_BALANCE["wet_seconds"]
	statuses.erase("burning")
	if previous_statuses != statuses:
		changed.emit()


func _shield_blocks(element: int) -> bool:
	return is_finite(shield_remaining) and shield_remaining > 0.0 and shield_element == element


func _status_seconds(status: Variant) -> float:
	var value: Variant = statuses.get(status, 0.0)
	if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
		return 0.0
	var seconds := float(value)
	return seconds if is_finite(seconds) and seconds > 0.0 else 0.0
