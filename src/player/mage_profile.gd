class_name MageProfile
extends RefCounted
## 只儲存法術知識、工坊綁定與輸入設定；測試及截圖不使用玩家存檔。

const PATH := "user://mage_profile.json"
const MAX_BYTES := 131072


static func restore(player: Player, path: String = PATH) -> bool:
	if not FileAccess.file_exists(path):
		return true
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return false
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return false
	var data: Variant = parser.data
	if not data is Dictionary or data.get("version") != 1:
		return false
	var knowledge: Variant = data.get("knowledge", {})
	if not knowledge is Dictionary or not player.knowledge.import_data(knowledge):
		return false
	var hold: Variant = data.get("shield_hold_seconds", 1.5)
	if hold is float or hold is int:
		player.shield_hold_seconds = float(hold)
	return true


static func save(player: Player, path: String = PATH) -> Error:
	var data := {"version": 1, "shield_hold_seconds": player.shield_hold_seconds,
		"knowledge": player.knowledge.export_data()}
	var encoded := JSON.stringify(data, "\t")
	if encoded.to_utf8_buffer().size() > MAX_BYTES:
		return ERR_OUT_OF_MEMORY
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(encoded)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return error
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path))
