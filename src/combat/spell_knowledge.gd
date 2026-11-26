class_name SpellKnowledge
extends RefCounted
## 手動配方綁定與三格快捷分開保存；此層不讀寫檔案、不接觸場景。

signal changed

const SHORTCUT_COUNT := 3
## 第一輪實玩以成功生效次數代替完整的擊殺熟練系統，未定案平衡。
const PROTOTYPE_MASTERY_USES := 3
const SAVE_VERSION := 1

var catalog: Dictionary:
	get:
		return _catalog.duplicate(true)
var _catalog: Dictionary
var _unlocked: Dictionary = {}
var _uses: Dictionary = {}
var _manual: Dictionary = {}
var _shortcuts: Array[Dictionary] = [{}, {}, {}]


func _init(named_catalog: Dictionary = SpellRules.NAMED) -> void:
	_catalog = named_catalog.duplicate(true)


func is_unlocked(id: String) -> bool:
	return _unlocked.has(id)


func unlock_named(id: String) -> bool:
	var spell := _named_spell(id)
	if spell.is_empty() or _unlocked.has(id):
		return false
	_unlocked[id] = true
	var key := SpellRules.recipe_key(spell["elements"])
	if not _manual.has(key):
		_manual[key] = id
	changed.emit()
	return true


func set_manual(elements: Array[int], id: String) -> bool:
	var spell := _resolve_allowed(elements, id)
	if spell.is_empty():
		return false
	_manual[SpellRules.recipe_key(elements)] = id
	changed.emit()
	return true


func manual_binding(elements: Array[int]) -> String:
	return _manual.get(SpellRules.recipe_key(elements), "")


func manual_spell(elements: Array[int]) -> Dictionary:
	return _resolve_allowed(elements, manual_binding(elements))


func equip_shortcut(slot: int, elements: Array[int], named_id: String = "") -> bool:
	if slot < 0 or slot >= SHORTCUT_COUNT or not SpellRules.hand_reachable(elements):
		return false
	var spell := _resolve_allowed(elements, named_id)
	if spell.is_empty() or not is_mastered(spell["id"]):
		return false
	_shortcuts[slot] = {"elements": spell["elements"].duplicate(), "named_id": named_id}
	changed.emit()
	return true


func clear_shortcut(slot: int) -> bool:
	if slot < 0 or slot >= SHORTCUT_COUNT or _shortcuts[slot].is_empty():
		return false
	_shortcuts[slot] = {}
	changed.emit()
	return true


func shortcut_spell(slot: int) -> Dictionary:
	if slot < 0 or slot >= SHORTCUT_COUNT or _shortcuts[slot].is_empty():
		return {}
	var binding: Dictionary = _shortcuts[slot]
	return _resolve_allowed(binding["elements"], binding["named_id"])


## 僅由實際命中、回復或有效降雨的呼叫點記錄，不在按下施法時累積。
func record_use(spell_id: String) -> bool:
	var spell := _spell_from_id(spell_id)
	if spell.is_empty() or not SpellRules.hand_reachable(spell["elements"]):
		return false
	_uses[spell_id] = mini(int(_uses.get(spell_id, 0)) + 1, 1000000)
	changed.emit()
	return true


func is_mastered(spell_id: String) -> bool:
	return not _spell_from_id(spell_id).is_empty() and int(_uses.get(spell_id, 0)) >= PROTOTYPE_MASTERY_USES


func mastery_progress(spell_id: String) -> Dictionary:
	return {"current": int(_uses.get(spell_id, 0)), "required": PROTOTYPE_MASTERY_USES}


func available_spells() -> Array[Dictionary]:
	var ids: Array = _uses.keys()
	for id: String in _unlocked:
		if not ids.has(id):
			ids.append(id)
	ids.sort()
	var result: Array[Dictionary] = []
	for id: String in ids:
		var spell := _spell_from_id(id)
		if not spell.is_empty():
			result.append(spell)
	return result


func _named_spell(id: String) -> Dictionary:
	if not _catalog.has(id) or not _catalog[id] is Dictionary:
		return {}
	return SpellRules.resolve(SpellRules.read_elements(_catalog[id].get("recipe")), id, _catalog)


func _resolve_allowed(elements: Array[int], id: String) -> Dictionary:
	if not id.is_empty() and not is_unlocked(id):
		return {}
	return SpellRules.resolve(elements, id, _catalog)


func _spell_from_id(id: String) -> Dictionary:
	if id.begins_with(SpellRules.ORDINARY_PREFIX):
		return SpellRules.resolve(SpellRules.elements_from_ordinary_id(id))
	if not is_unlocked(id):
		return {}
	return _named_spell(id)


func export_data() -> Dictionary:
	return {"version": SAVE_VERSION, "unlocked": _unlocked.keys(), "uses": _uses.duplicate(true),
		"manual": _manual.duplicate(true), "shortcuts": _shortcuts.duplicate(true)}


## 全部驗證後才替換狀態；毀損存檔不清空現有綁定，也不偷偷修成越權資料。
func import_data(data: Dictionary) -> bool:
	if SpellRules.read_nonnegative_integer(data.get("version"), SAVE_VERSION) != SAVE_VERSION or not data.get("unlocked") is Array \
		or not data.get("uses") is Dictionary or not data.get("manual") is Dictionary \
		or not data.get("shortcuts") is Array or data["shortcuts"].size() != SHORTCUT_COUNT:
		return false
	var candidate := SpellKnowledge.new(_catalog)
	for id: Variant in data["unlocked"]:
		if not id is String or not candidate.unlock_named(id):
			return false
	for id: Variant in data["uses"]:
		var count := SpellRules.read_nonnegative_integer(data["uses"][id], 1000000)
		if not id is String or count < 0:
			return false
		var spell := candidate._spell_from_id(id)
		if spell.is_empty() or not SpellRules.hand_reachable(spell["elements"]):
			return false
		candidate._uses[id] = count
	# Explicit ordinary bindings (empty IDs) must survive default-on-unlock bindings.
	candidate._manual.clear()
	for key: Variant in data["manual"]:
		var id: Variant = data["manual"][key]
		if not key is String or not id is String:
			return false
		var elements := SpellRules.elements_from_ordinary_id(SpellRules.ORDINARY_PREFIX + key)
		if not candidate.set_manual(elements, id):
			return false
	for slot in SHORTCUT_COUNT:
		var binding: Variant = data["shortcuts"][slot]
		if not binding is Dictionary:
			return false
		if binding.is_empty():
			continue
		if not binding.get("named_id") is String:
			return false
		var elements := SpellRules.read_elements(binding.get("elements"))
		if not candidate.equip_shortcut(slot, elements, binding["named_id"]):
			return false
	_unlocked = candidate._unlocked.duplicate(true)
	_uses = candidate._uses.duplicate(true)
	_manual = candidate._manual.duplicate(true)
	_shortcuts = candidate._shortcuts.duplicate(true)
	changed.emit()
	return true
