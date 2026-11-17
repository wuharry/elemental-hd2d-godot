extends SceneTree
## 純邏輯測試（不需要畫面）。
## 用法：godot --headless --path . --script res://tests/run_tests.gd
## 失敗時以非零碼結束。

var _failed := 0
var _passed := 0


func _init() -> void:
	_test_capacity_counts_occupied_slots()
	_test_duplicates_allowed()
	_test_fusion_is_order_independent()
	_test_fusion_frees_a_slot()
	_test_fusion_only_uses_last_two()
	_test_no_automatic_fusion()
	_test_compound_cannot_fuse_again()
	_test_unknown_recipe_keeps_queue()
	_test_take_all_clears()
	_test_changed_signal()
	print("%d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		printerr("FAIL: ", what)


func _queue(elements: Array) -> ElementQueue:
	var q := ElementQueue.new()
	for e in elements:
		q.add(e)
	return q


func _test_capacity_counts_occupied_slots() -> void:
	var q := _queue([Elements.Type.WATER, Elements.Type.FIRE, Elements.Type.LIGHTNING, Elements.Type.LIGHTNING])
	_check(q.is_full(), "四格後應該是滿的")
	_check(not q.add(Elements.Type.ICE), "滿了不能再加第五格")
	_check(q.slots.size() == 4, "被拒絕的加入不應改變佇列")


func _test_duplicates_allowed() -> void:
	var q := _queue([Elements.Type.LIGHTNING, Elements.Type.LIGHTNING])
	_check(q.slots == [Elements.Type.LIGHTNING, Elements.Type.LIGHTNING], "同一種元素可以重複加入")


func _test_fusion_is_order_independent() -> void:
	var a := _queue([Elements.Type.WATER, Elements.Type.FIRE])
	var b := _queue([Elements.Type.FIRE, Elements.Type.WATER])
	_check(a.fuse_last_two() and a.slots == [Elements.Type.STEAM], "水＋火 → 蒸氣")
	_check(b.fuse_last_two() and b.slots == [Elements.Type.STEAM], "火＋水 → 蒸氣")


## 規則文件的例子：[水][火][雷][雷] 滿了；改成先融合水火，就能再補一格。
func _test_fusion_frees_a_slot() -> void:
	var q := _queue([Elements.Type.WATER, Elements.Type.FIRE])
	q.fuse_last_two()
	_check(q.add(Elements.Type.LIGHTNING) and q.add(Elements.Type.LIGHTNING), "融合後可繼續加入")
	_check(not q.is_full(), "[蒸][雷][雷] 還剩一格")
	_check(q.add(Elements.Type.ICE), "可以補上第四格")
	_check(q.slots == [Elements.Type.STEAM, Elements.Type.LIGHTNING, Elements.Type.LIGHTNING, Elements.Type.ICE], "[蒸][雷][雷][冰]")


## DRAFT 規則：只融合最後兩格，所以 [水][火][雷][雷] 排好後不能回頭融合前面的水火。
func _test_fusion_only_uses_last_two() -> void:
	var q := _queue([Elements.Type.WATER, Elements.Type.FIRE, Elements.Type.LIGHTNING, Elements.Type.LIGHTNING])
	_check(not q.can_fuse(), "最後兩格是雷雷，不能融合")
	_check(not q.fuse_last_two() and q.slots.size() == 4, "融合失敗不應改變佇列")


func _test_no_automatic_fusion() -> void:
	var q := _queue([Elements.Type.WATER, Elements.Type.FIRE])
	_check(q.slots == [Elements.Type.WATER, Elements.Type.FIRE], "水＋火不會自動融合，玩家可保留普通組合")


func _test_compound_cannot_fuse_again() -> void:
	var q := _queue([Elements.Type.WATER, Elements.Type.FIRE])
	q.fuse_last_two()
	q.add(Elements.Type.FIRE)
	_check(not q.can_fuse(), "複合元素不可再融合（DRAFT）")


func _test_unknown_recipe_keeps_queue() -> void:
	var q := _queue([Elements.Type.ICE, Elements.Type.LIGHTNING])
	_check(not q.fuse_last_two(), "沒有配方的組合不能融合")
	_check(q.slots == [Elements.Type.ICE, Elements.Type.LIGHTNING], "佇列保持原樣")


func _test_take_all_clears() -> void:
	var q := _queue([Elements.Type.FIRE, Elements.Type.ICE])
	var taken := q.take_all()
	_check(taken == [Elements.Type.FIRE, Elements.Type.ICE], "取走的內容與順序正確")
	_check(q.is_empty(), "施法後佇列清空")


func _test_changed_signal() -> void:
	var q := ElementQueue.new()
	var count := [0]
	q.changed.connect(func(_slots: Array[int]) -> void: count[0] += 1)
	q.add(Elements.Type.WATER)
	q.add(Elements.Type.FIRE)
	q.fuse_last_two()
	q.take_all()
	_check(count[0] == 4, "加入、融合、取走各發一次 changed（實際 %d 次）" % count[0])
