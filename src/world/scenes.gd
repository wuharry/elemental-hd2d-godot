class_name Scenes
extends RefCounted
## 場景清單。新增場景：在 src/world/scenes/ 加一個 <id>_scene.gd（繼承 SceneDef），再把 id 加進 LIST。
## 加完一定要跑 tests/style_test.gd，它會逐條檢查新場景有沒有守住美術硬規則。

const LIST := ["village", "forest", "snow", "dungeon"]


static func make(id: String) -> SceneDef:
	var script: Script = load("res://src/world/scenes/%s_scene.gd" % id)
	return script.new()


static func next_id(id: String) -> String:
	return LIST[(LIST.find(id) + 1) % LIST.size()]
