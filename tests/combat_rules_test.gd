extends SceneTree
## 純規則與存檔失敗路徑，不啟動世界或渲染。

var _passed := 0
var _failed := 0


func _init() -> void:
	_test_fusions()
	_test_identity()
	_test_knowledge()
	_test_persistence()
	_test_states()
	print("combat_rules: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("FAIL: ", label)


func _test_fusions() -> void:
	_check(Elements.Type.WATER == 0 and Elements.Type.STEAM == 4 and Elements.Type.LIFE == 7, "既有 enum ID 穩定")
	var recipes := [
		[Elements.Type.WATER, Elements.Type.FIRE, Elements.Type.STEAM],
		[Elements.Type.WATER, Elements.Type.ICE, Elements.Type.MIST],
		[Elements.Type.WATER, Elements.Type.EARTH, Elements.Type.WOOD],
		[Elements.Type.WATER, Elements.Type.ARCANE, Elements.Type.POISON],
		[Elements.Type.FIRE, Elements.Type.EARTH, Elements.Type.LAVA],
		[Elements.Type.FIRE, Elements.Type.LIGHTNING, Elements.Type.PLASMA],
		[Elements.Type.ICE, Elements.Type.EARTH, Elements.Type.CRYSTAL],
		[Elements.Type.ICE, Elements.Type.LIGHTNING, Elements.Type.SUPERCONDUCT],
		[Elements.Type.EARTH, Elements.Type.ARCANE, Elements.Type.METAL],
		[Elements.Type.FIRE, Elements.Type.ARCANE, Elements.Type.LIGHT],
		[Elements.Type.LIGHTNING, Elements.Type.ARCANE, Elements.Type.MAGNETISM],
		[Elements.Type.ICE, Elements.Type.ARCANE, Elements.Type.MAGIC_CRYSTAL],
	]
	for row: Array in recipes:
		_check(Elements.fuse(row[0], row[1]) == row[2] and Elements.fuse(row[1], row[0]) == row[2], "正反融合 %s" % [row])
		_check(not Elements.is_base(row[2]) and Elements.fuse(row[2], row[0]) == -1, "融合保持新原子 %s" % row[2])
	for pair: Array in [[0, 2], [5, 2], [1, 3], [7, 6], [7, 0], [7, 1], [7, 5], [7, 3], [7, 2]]:
		_check(Elements.fuse(pair[0], pair[1]) == -1, "相剋／生命待定配方不融合 %s" % [pair])
	_check(Elements.fuse(-1, 0) == -1 and Elements.fuse(0, 999) == -1, "未知 ID 安全拒絕")
	var queue := ElementQueue.new()
	queue.add(Elements.Type.WATER)
	queue.add(Elements.Type.ICE)
	_check(queue.slots == [Elements.Type.WATER, Elements.Type.ICE], "新增配方不自動融合")
	queue.fuse_last_two()
	_check(queue.slots == [Elements.Type.MIST], "主動融合只占一格")


func _test_identity() -> void:
	var ordinary := SpellRules.resolve([Elements.Type.WATER, Elements.Type.ICE])
	var fused := SpellRules.resolve([Elements.Type.MIST])
	_check(ordinary["id"] != fused["id"], "普通水冰與霧身分不同")
	_check(SpellRules.recipe_key([0, 0, 8]) != SpellRules.recipe_key([0, 8]), "配方保留重複數量")
	_check(SpellRules.resolve([0, 3]) == SpellRules.resolve([3, 0]), "普通配方順序無關")
	var mixed := SpellRules.resolve([Elements.Type.FIRE, Elements.Type.MIST, Elements.Type.FIRE])
	_check(mixed["dominant"] == Elements.Type.MIST, "融合元素主導型態")
	_check(SpellRules.resolve([8, 0, 0])["kind"] == "ordinary", "相同降雨配方未指定仍為普通法術")
	_check(SpellRules.resolve([8, 0, 0], "rain")["kind"] == "rain", "指定降雨命中具名配方")
	_check(SpellRules.resolve([0, 0, 0, 3], "rain").is_empty(), "未融合材料不可冒充霧")
	_check(SpellRules.resolve([8, 0], "rain").is_empty(), "少一份水不能降雨")
	_check(SpellRules.resolve([], "rain").is_empty() and SpellRules.resolve([999]).is_empty(), "空與未知配方拒絕")
	_check(SpellRules.resolve([0, 0, 0, 0, 0]).is_empty(), "超過四格拒絕")
	_check(SpellRules.elements_from_ordinary_id("ordinary:01").is_empty(), "非正規普通 ID 拒絕")
	_check(not SpellRules.hand_reachable([8, 8, 8, 8]) and SpellRules.hand_reachable([8, 8, 8, 0]), "快捷不繞過四格手排限制")


func _test_knowledge() -> void:
	var recipe: Array[int] = [Elements.Type.MIST, Elements.Type.WATER, Elements.Type.WATER]
	var catalog := SpellRules.NAMED.duplicate(true)
	catalog["test_rain_variant"] = catalog["rain"].duplicate(true)
	catalog["test_rain_variant"]["name"] = "測試同配方第二法術"
	var knowledge := SpellKnowledge.new(catalog)
	_check(not knowledge.set_manual(recipe, "rain") and not knowledge.record_use("rain"), "未解鎖具名不可綁定或練熟")
	_check(not knowledge.unlock_named("unknown"), "未知法術書拒絕")
	_check(knowledge.unlock_named("rain") and knowledge.manual_binding(recipe) == "rain", "首次解鎖預設綁定")
	_check(not knowledge.unlock_named("rain"), "重複解鎖不變更設定")
	_check(not knowledge.equip_shortcut(0, recipe, "rain"), "未熟練不能快捷")
	for i in SpellKnowledge.PROTOTYPE_MASTERY_USES:
		_check(knowledge.record_use("rain"), "有效使用累積 %d" % i)
	_check(knowledge.is_mastered("rain") and knowledge.equip_shortcut(0, recipe, "rain"), "熟練後可裝快捷")
	_check(knowledge.set_manual(recipe, "") and knowledge.manual_spell(recipe)["kind"] == "ordinary", "手動可改回普通")
	_check(knowledge.shortcut_spell(0)["id"] == "rain", "手動修改不影響快捷")
	_check(knowledge.unlock_named("test_rain_variant") and knowledge.manual_binding(recipe) == "", "第二同配方法術不覆蓋普通設定")
	_check(knowledge.set_manual(recipe, "test_rain_variant") and knowledge.shortcut_spell(0)["id"] == "rain", "同配方兩個具名獨立綁定")
	var ordinary_id: String = SpellRules.resolve(recipe)["id"]
	for _i in SpellKnowledge.PROTOTYPE_MASTERY_USES:
		knowledge.record_use(ordinary_id)
	_check(knowledge.equip_shortcut(1, recipe) and knowledge.shortcut_spell(1)["id"] == ordinary_id, "普通法術可獨立熟練快捷")
	_check(knowledge.manual_binding(recipe) == "test_rain_variant", "快捷修改不影響手動")
	_check(not knowledge.equip_shortcut(-1, recipe) and not knowledge.equip_shortcut(3, recipe), "快捷限制三格")
	_check(not knowledge.set_manual([8, 0], "rain"), "已解鎖也不能綁錯配方")
	_check(knowledge.available_spells().size() == 3, "書本與已發現普通法術可列出")
	_check(knowledge.clear_shortcut(1) and knowledge.shortcut_spell(1).is_empty(), "可清空快捷不影響其他槽")
	var manual_first := SpellKnowledge.new()
	manual_first.set_manual(recipe, "")
	manual_first.unlock_named("rain")
	_check(manual_first.manual_binding(recipe) == "", "先選普通再解鎖書本仍保留普通")


func _test_persistence() -> void:
	var recipe: Array[int] = [8, 0, 0]
	var source := SpellKnowledge.new()
	source.unlock_named("rain")
	for _i in SpellKnowledge.PROTOTYPE_MASTERY_USES:
		source.record_use("rain")
	source.equip_shortcut(0, recipe, "rain")
	source.set_manual(recipe, "")
	var data := source.export_data()
	var restored := SpellKnowledge.new()
	_check(restored.import_data(data) and restored.export_data() == data, "完整存檔往返含手動普通及快捷具名")
	var json_restored := SpellKnowledge.new()
	var json_data: Dictionary = JSON.parse_string(JSON.stringify(data))
	_check(json_restored.import_data(json_data) and json_restored.export_data() == data, "真正 JSON 序列化往返保持元素與熟練整數")
	var corruptions: Array[Dictionary] = []
	var bad := data.duplicate(true)
	bad["unlocked"] = []
	corruptions.append(bad)
	bad = data.duplicate(true)
	bad["uses"]["rain"] = 0
	corruptions.append(bad)
	bad = data.duplicate(true)
	bad["unlocked"].append("unknown")
	corruptions.append(bad)
	bad = data.duplicate(true)
	bad["uses"]["rain"] = -1
	corruptions.append(bad)
	bad = data.duplicate(true)
	bad["uses"]["rain"] = 3.5
	corruptions.append(bad)
	bad = data.duplicate(true)
	bad["manual"]["0:0:8"] = "unknown"
	corruptions.append(bad)
	bad = data.duplicate(true)
	bad["shortcuts"][0]["elements"] = [0, 0, 0]
	corruptions.append(bad)
	bad = data.duplicate(true)
	bad["uses"]["ordinary:8:8:8:8"] = 3
	corruptions.append(bad)
	bad = data.duplicate(true)
	bad["shortcuts"][0]["elements"] = ["0", 0, 8]
	corruptions.append(bad)
	for invalid: float in [NAN, INF, 1e30, 0.5]:
		bad = data.duplicate(true)
		bad["shortcuts"][0]["elements"] = [invalid, 0, 8]
		corruptions.append(bad)
		bad = data.duplicate(true)
		bad["uses"]["rain"] = invalid
		corruptions.append(bad)
	for i in corruptions.size():
		_check(not restored.import_data(corruptions[i]) and restored.export_data() == data, "毀損／越權匯入原子拒絕 %d" % i)
	var detached := source.export_data()
	detached["shortcuts"][0]["elements"].clear()
	_check(source.shortcut_spell(0)["id"] == "rain", "匯出資料不洩漏可變內部引用")


func _test_states() -> void:
	var state := CombatState.new()
	state.activate_shield(Elements.Type.FIRE)
	var hit := state.apply([Elements.Type.FIRE, Elements.Type.LIGHTNING], 20.0)
	_check(hit["blocked"] and is_equal_approx(hit["damage"], 10.0) and not state.has_status("burning"), "火盾只擋混合技火份額")
	_check(not state.activate_shield(Elements.Type.STEAM) and not state.activate_shield(999), "僅基礎元素能開盾")
	state = CombatState.new()
	state.apply([Elements.Type.WATER], 0.0)
	_check(is_equal_approx(state.apply([Elements.Type.LIGHTNING], 20.0)["damage"], 30.0), "潮濕導電放大雷份額")
	state.apply([Elements.Type.ICE], 0.0)
	_check(state.has_status("frozen"), "濕冰凍結")
	state.apply([Elements.Type.FIRE], 0.0)
	_check(not state.has_status("frozen") and state.has_status("wet") and not state.has_status("burning"), "火解凍保留融水")
	var a := CombatState.new()
	var b := CombatState.new()
	_check(a.apply([0, 1], 20.0) == b.apply([1, 0], 20.0) and a.statuses == b.statuses, "水火反應與順序無關")
	state = CombatState.new()
	state.apply([Elements.Type.FIRE], 0.0)
	state.tick(10.0)
	_check(is_equal_approx(state.health, 88.0) and state.statuses.is_empty(), "大 delta 燃燒只計有效四秒")
	state = CombatState.new()
	state.apply([Elements.Type.POISON], 0.0)
	state.tick(10.0)
	_check(is_equal_approx(state.health, 90.0) and state.statuses.is_empty(), "毒傷只計有效五秒")
	state = CombatState.new()
	state.statuses = {"frozen": 2.0, "poisoned": 5.0, "rooted": 6.0}
	state.activate_shield(Elements.Type.FIRE)
	_check(not state.has_status("frozen") and state.has_status("poisoned") and state.has_status("rooted"), "開盾僅淨化指定狀態")
	state.tick(6.0)
	_check(state.shield_element == -1 and state.statuses.is_empty(), "所有場上狀態與盾統一倒數")
	state = CombatState.new()
	state.activate_shield(Elements.Type.FIRE)
	hit = state.apply([Elements.Type.LAVA], 20.0)
	state.tick(4.0)
	_check(not hit["blocked"] and is_equal_approx(state.health, 68.0), "熔岩不因原料含火被火盾消除")
	state = CombatState.new()
	state.health = 60.0
	hit = state.apply([Elements.Type.LIFE], 25.0)
	_check(is_equal_approx(hit["healed"], 25.0) and is_equal_approx(state.health, 85.0), "生命治療且不算傷害")
	state.apply([Elements.Type.FIRE], 0.0)
	state.rain_exposure(0.1)
	_check(state.has_status("wet") and not state.has_status("burning"), "有效降雨淋濕滅火")
	var before := state.health
	state.apply([999], 20.0)
	state.apply([Elements.Type.FIRE], NAN)
	state.tick(INF)
	_check(state.health == before, "無效ID與非有限數值不改狀態")
	state = CombatState.new()
	state.activate_shield(Elements.Type.WATER)
	state.rain_exposure(0.1)
	_check(not state.has_status("wet"), "水盾可防雨淋濕")
	state.health = 0.0
	state.statuses["poisoned"] = 2.0
	state.is_concealed = true
	state.reset()
	_check(state.health == state.max_health and state.statuses.is_empty() and state.shield_element == -1 and not state.is_concealed, "訓練復原清空暫時狀態")
