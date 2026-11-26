extends SceneTree
## Godot 真實物理世界驗證：命中、遮擋、狀態、霧、元素場與生命週期。

var passed := 0
var failed := 0
var world: GameWorld
var player: Player
var lighting: TimeOfDay
var runtime: SpellRuntime
var knowledge := SpellKnowledge.new()


func _init() -> void:
	_run.call_deferred()


func check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		printerr("FAIL: ", label)


func frames(count: int = 2) -> void:
	for i in count:
		await physics_frame


func spell(elements: Array[int], named: String = "") -> Dictionary:
	return SpellRules.resolve(elements, named)


func cast_from(resolved: Dictionary, origin: Vector3, direction: Vector3) -> void:
	# Use the real Player muzzle contract; arbitrary test origins must move the caster too.
	player.position = origin - Vector3.UP * 0.9 - direction.normalized() * 0.5
	runtime.cast_spell(resolved, origin, direction)


func clear_effects() -> void:
	for collection: Array[Dictionary] in [runtime.projectiles, runtime.zones, runtime.structures, runtime._flashes]:
		for item in collection:
			(item["node"] as Node).free()
		collection.clear()


func reset_targets() -> void:
	for target in runtime.targets:
		target.reset_target()


func _run() -> void:
	var def := SceneDef.new()
	def.id = "combat_fixture"
	def.world_size = 20
	def.play_half = Vector2(8, 8)
	def.grass_count = 0
	def.flower_count = 0
	def.backdrop = {"kind": "none"}
	def.ambient = {}
	def.training_targets = [Vector2(2, 0), Vector2(4, 0), Vector2(6, 0)]
	def.training_turret = Vector2(6, 3)
	world = GameWorld.new(def)
	root.add_child(world)
	lighting = TimeOfDay.new()
	root.add_child(lighting)
	lighting.apply_scene(def)
	lighting.set_time("day", true)
	lighting.set_weather("clear", true)
	player = Player.new()
	player.accept_keyboard = false
	root.add_child(player)
	player.set_physics_process(false)
	runtime = SpellRuntime.new()
	world.add_child(runtime)
	runtime.setup(player, lighting, knowledge)
	runtime.set_physics_process(false)
	for target in runtime.targets:
		target.set_physics_process(false)
	await frames()
	var first := runtime.targets[0]
	var second := runtime.targets[1]
	var origin := Vector3(0, 0.9, 0)

	check(runtime.targets.size() == 3 and runtime.targets[2].is_metal, "三具實體標的含金屬，放在場景子樹")
	cast_from(spell([Elements.Type.WATER]), origin, Vector3.RIGHT)
	check(first.combat_state.has_status("wet") and first.combat_state.health < 100, "水錐經實際瞄準命中並潮濕")
	check(second.combat_state.health == 100, "前方實體木樁遮擋後方標的")
	cast_from(spell([Elements.Type.ICE]), origin, Vector3.RIGHT)
	check(first.combat_state.has_status("frozen"), "潮濕木樁被冰錐凍結")
	reset_targets()
	clear_effects()
	cast_from(spell([Elements.Type.FIRE]), origin, Vector3.RIGHT)
	for i in 4:
		runtime._physics_process(0.05)
	check(first.combat_state.health < 100 and first.combat_state.has_status("burning"), "火彈飛行碰撞後燃燒")
	check(runtime.projectiles.is_empty(), "命中後移除實體彈與視覺")

	reset_targets()
	clear_effects()
	var wall := Build.collider(world, Vector3(0.2, 2, 2), Vector3(1, 1, 0))
	await frames()
	cast_from(spell([Elements.Type.FIRE]), origin, Vector3.RIGHT)
	for i in 4:
		runtime._physics_process(0.05)
	check(first.combat_state.health == 100 and runtime.projectiles.is_empty(), "牆壁阻擋飛行物")
	cast_from(spell([Elements.Type.ARCANE]), origin, Vector3.RIGHT)
	check(first.combat_state.health == 100, "牆壁阻擋光束")
	wall.set_meta("spell_passthrough", true)
	runtime._collect_passthrough(wall)
	cast_from(spell([Elements.Type.ARCANE]), origin, Vector3.RIGHT)
	check(first.combat_state.health < 100, "標記的移動專用隱形牆不阻擋魔法")
	wall.free()
	await frames()
	clear_effects()
	reset_targets()
	# Exact Player muzzle entry: .35m capsule stays before the .05m wall, while .5m muzzle crosses it.
	player.position = Vector3(0, 0, -4)
	first.position = Vector3(2, 0, -4)
	wall = Build.collider(world, Vector3(0.05, 2, 2), Vector3(0.4, 1, -4))
	await frames()
	player.spell_cast.connect(runtime.cast_spell)
	player.queue.add(Elements.Type.FIRE)
	player.cast_queue(Vector3.RIGHT)
	for i in 4:
		runtime._physics_process(0.05)
	check(first.combat_state.health == 100 and runtime.projectiles.is_empty(), "真正Player出杖點跨過薄牆時仍不可穿牆射擊")
	player.queue.add(Elements.Type.METAL)
	player.cast_queue(Vector3.RIGHT)
	check(runtime.structures.is_empty(), "真正Player不可跨薄牆生成金屬障礙")
	player.spell_cast.disconnect(runtime.cast_spell)
	wall.free()
	reset_targets()
	await frames()

	reset_targets()
	clear_effects()
	first.combat_state.apply([Elements.Type.WATER], 0)
	second.combat_state.apply([Elements.Type.WATER], 0)
	cast_from(spell([Elements.Type.LIGHTNING]), origin, Vector3.RIGHT)
	check(first.combat_state.health < 100 and second.combat_state.health < 100, "濕目標引導紫雷連鎖到後方濕目標")
	check(runtime.targets[2].combat_state.health == 100, "連鎖有距離限制")

	clear_effects()
	reset_targets()
	player.position = Vector3(3, 0, 3)
	await frames()
	runtime.toggle_turret()
	runtime._turret_timer = 0
	runtime._physics_process(0.01)
	check(runtime.turret_shots == 1, "訓練砲台看見角色時實際射擊")
	clear_effects()
	player.combat_state.activate_shield(Elements.Type.FIRE)
	runtime._turret_timer = 0
	runtime._physics_process(0.01)
	for i in 8:
		runtime._physics_process(0.05)
	check(player.combat_state.health == 100 and not player.combat_state.has_status("burning"), "火盾實際擋住砲台火彈且不附加燃燒")
	check(runtime._shield.visible, "固定時間護盾有世界內外殼")
	clear_effects()
	var shots := runtime.turret_shots
	cast_from(spell([Elements.Type.MIST]), player.position + Vector3(0.5, 0.9, 0), Vector3.RIGHT)
	runtime._turret_timer = 0
	runtime._physics_process(0.1)
	check(runtime.turret_shots == shots, "霧實際阻擋砲台鎖定，不只是視覺面片")
	check(player.combat_state.is_concealed, "角色身處霧中有遮蔽狀態")
	cast_from(spell([Elements.Type.LIGHT]), player.position + Vector3(0.5, 0.9, 0), Vector3.RIGHT)
	runtime._physics_process(0.1)
	check(runtime.zones.is_empty(), "光穿過霧場後驅散霧")
	runtime.turret_mode = -1
	clear_effects()

	reset_targets()
	first.combat_state.apply([Elements.Type.FIRE], 1)
	knowledge.unlock_named("rain")
	var rain := spell([Elements.Type.MIST, Elements.Type.WATER, Elements.Type.WATER], "rain")
	cast_from(rain, origin, Vector3.RIGHT)
	check(lighting.weather == "rain", "具名降雨接進既有天氣系統")
	var rain_uses := knowledge.mastery_progress("rain")
	cast_from(rain, origin, Vector3.RIGHT)
	check(knowledge.mastery_progress("rain") == rain_uses, "已經下雨時反覆空放不累積熟練")
	lighting.set_weather("rain", true)
	runtime._physics_process(0.1)
	check(first.combat_state.has_status("wet") and not first.combat_state.has_status("burning"), "有效露天雨勢淋濕與滅火")
	def.outer_ground = false
	lighting.apply_scene(def)
	first.combat_state.statuses.clear()
	first.combat_state.apply([Elements.Type.FIRE], 1)
	runtime._physics_process(0.1)
	check(first.combat_state.has_status("burning") and not first.combat_state.has_status("wet"), "保留rain選擇的室內不淋雨、不滅火")
	def.outer_ground = true
	lighting.apply_scene(def)
	lighting.set_weather("clear", true)
	clear_effects()

	player.position = Vector3(-5, 0, -4)
	await frames()
	var field_origin := Vector3(2, 0.9, 2.8)
	cast_from(spell([Elements.Type.POISON]), field_origin, Vector3.FORWARD)
	runtime._physics_process(0.1)
	check(first.combat_state.has_status("poisoned"), "毒場保留地面並對圈內目標施毒")
	clear_effects()
	cast_from(spell([Elements.Type.LAVA]), field_origin, Vector3.FORWARD)
	await frames()
	cast_from(spell([Elements.Type.WATER]), Vector3(0, 0.9, 2.2), Vector3.RIGHT)
	runtime._physics_process(0.1)
	check(runtime.zones.is_empty() and runtime.structures.size() == 1, "水使熔岩區凝固成有碰撞石障")
	clear_effects()
	await frames()

	var metal_origin := Vector3(1, 0.9, -4)
	cast_from(spell([Elements.Type.METAL]), metal_origin, Vector3.RIGHT)
	await frames()
	check(runtime.structures.size() == 1, "金屬是獨立有碰撞構造")
	var metal_node := runtime.structures[0]["node"] as Node3D
	var before := metal_node.position
	cast_from(spell([Elements.Type.MAGNETISM]), Vector3(2, 0.9, -2), Vector3.RIGHT)
	check(not metal_node.position.is_equal_approx(before), "磁力移動實際金屬物件")
	clear_effects()
	await frames()
	cast_from(spell([Elements.Type.MAGIC_CRYSTAL]), metal_origin, Vector3.RIGHT)
	await frames()
	cast_from(spell([Elements.Type.ARCANE]), metal_origin, Vector3.RIGHT)
	check(float(runtime.structures[0]["charge"]) > 0, "魔晶儲存實際命中的秘法能量")
	first.position = (runtime.structures[0]["node"] as Node3D).position + Vector3.RIGHT * 2.0
	first.position.y = 0
	first.combat_state.reset()
	await frames()
	var light_id: String = spell([Elements.Type.LIGHT])["id"]
	var light_uses: int = knowledge.mastery_progress(light_id)["current"]
	cast_from(spell([Elements.Type.LIGHT]), metal_origin, Vector3.RIGHT)
	check(float(runtime.structures[0]["charge"]) == 0, "光束觸發魔晶釋放儲能")
	check(first.combat_state.health < 100, "儲能光束實際命中晶體後方木樁")
	check(int(knowledge.mastery_progress(light_id)["current"]) == light_uses + 1, "一次穿晶並命中只增加一次光法術熟練")
	clear_effects()
	await frames()

	# 45° 水晶實際把光轉向；將木樁放到反射路徑上，直線原方向沒有目標。
	cast_from(spell([Elements.Type.CRYSTAL]), metal_origin, Vector3.RIGHT)
	await frames()
	var crystal := runtime.structures[0]["node"] as Node3D
	var query_hit := runtime._trace(metal_origin, metal_origin + Vector3.RIGHT * 8, [player.get_rid()])
	var reflected := Vector3.RIGHT.bounce(query_hit["normal"])
	first.position = (query_hit["position"] as Vector3) + reflected * 2.0
	first.position.y = 0
	first.combat_state.reset()
	await frames()
	cast_from(spell([Elements.Type.LIGHT]), metal_origin, Vector3.RIGHT)
	check(first.combat_state.health < 100, "光被45度水晶改變方向後實際命中轉角目標")
	clear_effects()
	reset_targets()
	await frames()

	cast_from(spell([Elements.Type.WOOD]), Vector3(2, 0.9, 2.5), Vector3.FORWARD)
	await frames()
	runtime._physics_process(0.1)
	check(first.combat_state.has_status("rooted"), "木構造以實際範圍纏繞附近目標")
	var wooden := runtime.structures[0]["node"] as Node3D
	cast_from(spell([Elements.Type.FIRE]), wooden.position + Vector3(0, 0.9, 2), Vector3.FORWARD)
	for i in 5:
		runtime._physics_process(0.05)
	check(runtime.zones.size() == 1, "火彈點燃木構造產生燃燒區")
	check(int(runtime.zones[0]["element"]) == Elements.Type.FIRE, "燃燒木仍是火，不憑空質變熔岩")
	first.combat_state.reset()
	first.combat_state.activate_shield(Elements.Type.FIRE)
	runtime._physics_process(0.6)
	check(first.combat_state.health == 100, "火盾擋住燃燒木的火區")
	await frames()
	cast_from(spell([Elements.Type.WATER]), Vector3(0, 0.9, 2.2), Vector3.RIGHT)
	runtime._physics_process(0.1)
	check(runtime.zones.is_empty() and runtime.structures.is_empty(), "水只熄滅燃燒木，不像真正熔岩凝固石障")
	clear_effects()
	reset_targets()
	await frames()
	var before_push := first.position
	cast_from(spell([Elements.Type.STEAM]), origin, Vector3.RIGHT)
	check(first.position.x > before_push.x, "蒸汽以壓力實際推動目標")
	reset_targets()
	clear_effects()
	await frames()
	cast_from(spell([Elements.Type.SUPERCONDUCT]), field_origin, Vector3.FORWARD)
	runtime._physics_process(0.1)
	check(first.combat_state.has_status("conductive") and first.combat_state.has_status("vulnerable"), "超導區賦予導電與脆弱，與磁力搬運不同")
	clear_effects()
	reset_targets()
	await frames()
	cast_from(spell([Elements.Type.MIST, Elements.Type.WATER, Elements.Type.WATER]), field_origin, Vector3.FORWARD)
	runtime._physics_process(0.1)
	check(first.combat_state.has_status("wet") and lighting.weather == "clear", "普通霧水水只造成局部水霧，沒有偷換具名降雨")
	check(first.combat_state.health == 100, "純水霧零傷害，水只提供潮濕")
	check(not runtime.targets[2].combat_state.has_status("wet"), "普通水霧不會淋濕範圍外目標")
	clear_effects()
	reset_targets()
	await frames()
	cast_from(spell([Elements.Type.MIST, Elements.Type.ARCANE]), field_origin, Vector3.FORWARD)
	runtime._physics_process(0.1)
	check(first.combat_state.health < 100, "霧加秘法保留有效傷害，不吞掉純傷害附加成分")
	clear_effects()
	reset_targets()
	await frames()
	cast_from(spell([Elements.Type.MIST, Elements.Type.WATER, Elements.Type.LIGHTNING]), field_origin, Vector3.FORWARD)
	runtime._physics_process(0.1)
	check(first.combat_state.has_status("wet") and first.combat_state.health < 97, "水雷霧先潮濕再雷傷，產生濕雷反應")
	clear_effects()
	reset_targets()
	first.combat_state.health = 50
	player.combat_state.health = 50
	await frames()
	cast_from(spell([Elements.Type.MIST, Elements.Type.LIFE]), field_origin, Vector3.FORWARD)
	player.position = Vector3(2, 0, 1.9)
	await frames()
	runtime._physics_process(0.1)
	check(first.combat_state.health > 50 and player.combat_state.health > 50, "生命霧實際治療圈內標的與玩家")
	player.combat_state.reset()
	clear_effects()
	reset_targets()
	await frames()
	cast_from(spell([Elements.Type.SUPERCONDUCT, Elements.Type.WATER]), field_origin, Vector3.FORWARD)
	runtime._physics_process(0.1)
	check(first.combat_state.has_status("wet") and first.combat_state.has_status("conductive"), "超導加水同時保留導電與附加潮濕")
	clear_effects()
	reset_targets()
	await frames()
	cast_from(spell([Elements.Type.METAL, Elements.Type.LIGHTNING]), field_origin, Vector3.FORWARD)
	await frames()
	runtime._physics_process(0.1)
	check(first.combat_state.health < 100 and second.combat_state.health < 100, "金屬加雷構造放電命中附近多具目標")
	clear_effects()
	reset_targets()
	await frames()
	cast_from(spell([Elements.Type.WOOD, Elements.Type.FIRE]), field_origin, Vector3.FORWARD)
	await frames()
	runtime._physics_process(0.1)
	check(runtime.zones.size() == 1 and int(runtime.zones[0]["element"]) == Elements.Type.FIRE,
		"木加火普通融合組招直接燃燒，不吞掉火成分")
	clear_effects()
	reset_targets()
	await frames()
	cast_from(spell([Elements.Type.MAGIC_CRYSTAL, Elements.Type.FIRE]), field_origin, Vector3.FORWARD)
	await frames()
	runtime._physics_process(0.1)
	check(first.combat_state.has_status("burning"), "魔晶加火保留近場燃燒作用")
	clear_effects()
	reset_targets()
	await frames()
	cast_from(spell([Elements.Type.CRYSTAL, Elements.Type.WATER]), field_origin, Vector3.FORWARD)
	await frames()
	runtime._physics_process(0.1)
	check(first.combat_state.has_status("wet"), "水晶加水保留近場潮濕作用")
	clear_effects()
	reset_targets()
	await frames()
	cast_from(spell([Elements.Type.MAGNETISM, Elements.Type.WATER]), field_origin, Vector3.FORWARD)
	check(first.combat_state.has_status("wet"), "磁力加水保留脈衝範圍潮濕作用")
	clear_effects()

	for i in 12:
		cast_from(spell([Elements.Type.MIST]), Vector3(-3, 0.9, 3), Vector3.RIGHT)
	check(runtime.zones.size() == SpellRuntime.MAX_ZONES, "霧場有固定容量上限")
	runtime._physics_process(20)
	check(runtime.zones.is_empty(), "霧場到期實際移除，遮蔽不殘留")
	for i in 40:
		cast_from(spell([Elements.Type.FIRE]), Vector3(-3, 0.9, 3), Vector3.RIGHT)
	check(runtime.projectiles.size() == SpellRuntime.MAX_PROJECTILES, "飛行物有固定容量上限")
	var runtime_ref: WeakRef = weakref(runtime)
	world.free()
	await frames()
	check(runtime_ref.get_ref() == null and get_nodes_in_group("spell_runtime").is_empty(), "移除世界同步清理所有法術、標的與計時器")
	player.free()
	lighting.free()
	print("%d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)
