extends SceneTree
## 一次性工具：用引擎 API 刪掉已被取代的腳本與它們的 .uid（.uid 不可用 shell 動，見 godot 政策）。

func _init() -> void:
	for path in ["res://src/world/layout.gd", "res://src/world/village_world.gd"]:
		for f in [path, path + ".uid"]:
			if FileAccess.file_exists(f):
				print("remove ", f, " -> ", DirAccess.remove_absolute(ProjectSettings.globalize_path(f)))
	quit()
