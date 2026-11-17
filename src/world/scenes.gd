class_name Scenes
extends RefCounted
## 場景清單。新增場景：在 src/world/scenes/ 加一個 <id>_scene.gd（繼承 SceneDef），再把 id 加進 LIST。
## 加完照 BLUEPRINT 第 8 節做，並跑 tests/style_test.gd：它會把 LIST 裡每個場景建出來，逐條檢查美術硬規則。

const LIST := ["village", "forest", "snow", "dungeon"]


static func make(id: String) -> SceneDef:
	var script: Script = load("res://src/world/scenes/%s_scene.gd" % id)
	return script.new()


static func next_id(id: String) -> String:
	return LIST[(LIST.find(id) + 1) % LIST.size()]
