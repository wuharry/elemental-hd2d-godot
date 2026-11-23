extends CanvasLayer
## 手機 HUD：左搖桿移動、右搖桿瞄準施放、四顆元素鍵、融合鍵、三個快捷槽。
## 全部用觸控事件（滑鼠會被模擬成觸控），所以可以多指同時按。
## 這裡只把操作轉成對 Player／ElementQueue 的呼叫，不放任何玩法規則。

signal interaction_requested

## DRAFT：內圈佔搖桿半徑的比例，需要實機測試後才定（規則文件第 5 節）。
const AIM_INNER_RATIO := 0.55
const LONG_PRESS_SEC := 0.35
const ELEMENT_ICONS: Texture2D = preload("res://assets/ui/element_icons.png")
const INTERACTION_LABELS := {
	"to_altar": "進入祭壇",
	"equip": "裝備元素",
	"to_village": "返回村莊",
}

var _player: Player
var _rig: CameraRig
var _tod: TimeOfDay
var _canvas: Control
var _font: Font

var _widgets: Array[Dictionary] = []
## touch index → widget
var _touches: Dictionary = {}
var _toast := ""
var _toast_time := 0.0
var _draft_loadout: Array = []
var _interaction := ""
var _interact_widget: Dictionary = {}


func setup(player: Player, rig: CameraRig, tod: TimeOfDay) -> void:
	_player = player
	_rig = rig
	_tod = tod
	_font = ThemeDB.fallback_font
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas.draw.connect(_draw_hud)
	add_child(_canvas)
	_player.queue.changed.connect(_canvas.queue_redraw.unbind(1))
	_tod.changed.connect(_canvas.queue_redraw.unbind(1))
	get_viewport().size_changed.connect(_layout)
	set_process(false)
	_layout()


func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	_widgets.clear()
	_touches.clear()
	_interact_widget = {}
	_player.move_input = Vector2.ZERO
	_player.aim_input = Vector2.ZERO
	if _player.choosing_loadout:
		var center := size * 0.5
		for i in Elements.SELECTABLE.size():
			var offset := Vector2((i % 3 - 1) * 178.0, -131.0 if i < 3 else 29.0)
			_widgets.append({"kind": "loadout_option", "c": center + offset, "r": 54.0, "element": Elements.SELECTABLE[i]})
		_widgets.append({"kind": "loadout_cancel", "c": center + Vector2(-126, 218), "extent": Vector2(104, 38)})
		_widgets.append({"kind": "loadout_apply", "c": center + Vector2(126, 218), "extent": Vector2(104, 38)})
		_canvas.queue_redraw()
		return
	var move_c := Vector2(230, size.y - 230)
	var aim_c := Vector2(size.x - 320, size.y - 270)
	var angles := [125.0, 160.0, 195.0, 230.0]
	for i in _player.loadout.size():
		var a := deg_to_rad(angles[i])
		var c := aim_c + Vector2(cos(a), -sin(a)) * 228.0
		_widgets.append({"kind": "element", "c": c, "r": 54.0, "element": _player.loadout[i]})
	var fa := deg_to_rad(58.0)
	_widgets.append({"kind": "fuse", "c": aim_c + Vector2(cos(fa), -sin(fa)) * 215.0, "r": 58.0})
	for i in 3:
		_widgets.append({"kind": "quick", "c": aim_c + Vector2((i - 1) * 118.0, -352.0 + absf(i - 1) * 22.0), "r": 40.0})
	# 驗收用：切換時段（正式版會拿掉）
	for i in TimeOfDay.ORDER.size():
		_widgets.append({"kind": "time", "c": Vector2(size.x - 60.0 - (3 - i) * 74.0, 58.0), "r": 30.0, "time": TimeOfDay.ORDER[i]})
	# 搖桿的擴大命中區要排在實際按鍵之後，避免吃掉融合鍵靠內側的點按。
	_widgets.append({"kind": "move", "c": move_c, "r": 135.0, "v": Vector2.ZERO})
	_widgets.append({"kind": "aim", "c": aim_c, "r": 125.0, "v": Vector2.ZERO})
	_update_interact_widget()
	_canvas.queue_redraw()


## 移動穿過互動邊界時，只撤換屬於舊地點的按鍵與觸控，讓搖桿持續跟著手指。
func set_interaction(action: String) -> void:
	if action == _interaction:
		return
	_interaction = action
	if not is_instance_valid(_canvas):
		return
	if _player.choosing_loadout and action != "equip":
		close_loadout()
	else:
		_update_interact_widget()
		_canvas.queue_redraw()


func _update_interact_widget() -> void:
	if not _interact_widget.is_empty():
		_widgets.erase(_interact_widget)
		for i: int in _touches.keys():
			if _touches[i] == _interact_widget:
				_touches.erase(i)
		_interact_widget = {}
	if _player.choosing_loadout or not INTERACTION_LABELS.has(_interaction):
		return
	var size := get_viewport().get_visible_rect().size
	_interact_widget = {"kind": "interact", "c": size - Vector2(165, 81), "extent": Vector2(119, 42)}
	_widgets.push_front(_interact_widget)


func _process(delta: float) -> void:
	_toast_time -= delta
	if _toast_time <= 0.4:
		_canvas.queue_redraw()
	if _toast_time <= 0.0:
		set_process(false)


func _input(event: InputEvent) -> void:
	if _player.choosing_loadout and event is InputEventKey:
		if event.pressed and event.physical_keycode == KEY_ESCAPE:
			close_loadout()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_press(touch.index, touch.position)
		elif touch.canceled:
			if _touches.has(touch.index):
				var widget: Dictionary = _touches[touch.index]
				_touches.erase(touch.index)
				if widget["kind"] in ["move", "aim"]:
					widget["v"] = Vector2.ZERO
					if widget["kind"] == "move":
						_player.move_input = Vector2.ZERO
					else:
						_player.aim_input = Vector2.ZERO
				_canvas.queue_redraw()
		else:
			_release(touch.index, touch.position)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_drag(drag.index, drag.position)


func _press(index: int, pos: Vector2) -> void:
	for w in _widgets:
		if _contains_point(w, pos) and not _touches.values().has(w):
			w["t0"] = Time.get_ticks_msec()
			w["moved"] = false
			_touches[index] = w
			_drag(index, pos)
			_canvas.queue_redraw()
			get_viewport().set_input_as_handled()
			return


func _contains_point(w: Dictionary, pos: Vector2) -> bool:
	var center: Vector2 = w["c"]
	if w.has("extent"):
		var extent: Vector2 = w["extent"]
		return Rect2(center - extent, extent * 2.0).has_point(pos)
	var reach: float = w["r"] * (1.35 if w["kind"] in ["move", "aim"] else 1.0)
	return pos.distance_to(center) <= reach


func _drag(index: int, pos: Vector2) -> void:
	if not _touches.has(index):
		return
	var w: Dictionary = _touches[index]
	if w["kind"] == "move" or w["kind"] == "aim":
		var v: Vector2 = (pos - w["c"]) / w["r"]
		if v.length() > 1.0:
			v = v.normalized()
		w["v"] = v
		_canvas.queue_redraw()
		if v.length() > 0.2:
			w["moved"] = true
		if w["kind"] == "move":
			_player.move_input = v if v.length() > 0.15 else Vector2.ZERO
		else:
			_player.aim_input = v if v.length() > 0.2 else Vector2.ZERO
			if v.length() > 0.2:
				_player.aim_dir = _to_world(v)


func _release(index: int, pos: Vector2) -> void:
	if not _touches.has(index):
		return
	var w: Dictionary = _touches[index]
	_touches.erase(index)
	_canvas.queue_redraw()
	if (w["kind"].begins_with("loadout_") or w["kind"] == "interact") and not _contains_point(w, pos):
		return
	var held := (Time.get_ticks_msec() - int(w["t0"])) / 1000.0
	match w["kind"]:
		"move":
			w["v"] = Vector2.ZERO
			_player.move_input = Vector2.ZERO
		"aim":
			var v: Vector2 = w["v"]
			w["v"] = Vector2.ZERO
			_player.aim_input = Vector2.ZERO
			if not w["moved"] and held < LONG_PRESS_SEC:
				_say("副手武器：規則待定，尚未實作")
			elif v.length() >= AIM_INNER_RATIO:
				# 在外圈放開 = 施放；拉回內圈再放開 = 取消並保留佇列
				if _player.queue.is_empty():
					_say("佇列是空的")
				else:
					_player.cast_queue(_to_world(v))
		"element":
			if held >= LONG_PRESS_SEC:
				_say("%s盾：規則待定，尚未實作" % Elements.display_name(w["element"]))
			elif not _player.queue.add(w["element"]):
				_say("佇列已滿（四格）")
		"fuse":
			if not _player.queue.fuse_last_two():
				_say("最後兩格不能融合")
		"quick":
			_say("快捷法術：累積擊殺後解鎖，尚未實作")
		"time":
			_tod.set_time(w["time"])
		"interact":
			interaction_requested.emit()
		"loadout_option":
			var element: int = w["element"]
			if _draft_loadout.has(element):
				_draft_loadout.erase(element)
			elif _draft_loadout.size() < Elements.LOADOUT.size():
				_draft_loadout.append(element)
		"loadout_cancel":
			close_loadout()
		"loadout_apply":
			if _draft_loadout.size() == Elements.LOADOUT.size():
				_player.loadout.assign(_draft_loadout)
				close_loadout()


func open_loadout() -> void:
	if _interaction != "equip" or _player.choosing_loadout:
		return
	_draft_loadout.assign(_player.loadout)
	_player.choosing_loadout = true
	_layout()


func close_loadout() -> void:
	_player.choosing_loadout = false
	_layout()


## 搖桿向量（螢幕方向）→ 世界水平方向。
func _to_world(v: Vector2) -> Vector3:
	return Vector3(v.x, 0, v.y).rotated(Vector3.UP, _rig.yaw()).normalized()


func _say(text: String) -> void:
	_toast = text
	_toast_time = 1.8
	set_process(true)
	_canvas.queue_redraw()


# ---------- 繪製 ----------

func _draw_hud() -> void:
	if _player.choosing_loadout:
		_draw_loadout()
		return
	for w in _widgets:
		match w["kind"]:
			"move":
				_draw_stick(w, 0.0)
			"aim":
				_draw_stick(w, AIM_INNER_RATIO)
			"element":
				_draw_element_button(w)
			"fuse":
				_draw_fusion(w)
			"quick":
				_draw_button_face(w, Color("#55524e"))
				_draw_action_icon("locked", w["c"], Color("#d2c7b4"))
			"time":
				var on: bool = _tod.current == w["time"]
				_draw_button(w, Color("#ffd27a") if on else Color("#4a4a52"), TimeOfDay.LABELS[w["time"]], 24)
			"interact":
				_draw_tablet(w, _interaction, INTERACTION_LABELS[_interaction], Color("#403749"), Color("#e5c58b"))
	if _toast_time > 0.0:
		var size := get_viewport().get_visible_rect().size
		var a := clampf(_toast_time / 0.4, 0.0, 1.0)
		var tw := _font.get_string_size(_toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		var pos := Vector2((size.x - tw) * 0.5, size.y - 90.0)
		_canvas.draw_rect(Rect2(pos + Vector2(-18, -36), Vector2(tw + 36, 50)), Color(0.08, 0.07, 0.1, 0.7 * a))
		_canvas.draw_string(_font, pos, _toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 1, 1, a))


func _draw_stick(w: Dictionary, inner_ratio: float) -> void:
	var c: Vector2 = w["c"]
	var r: float = w["r"]
	var v: Vector2 = w["v"]
	var armed := inner_ratio > 0.0 and v.length() >= inner_ratio
	_canvas.draw_circle(c, r, Color(0.06, 0.06, 0.09, 0.32))
	_canvas.draw_arc(c, r, 0, TAU, 48, Color(1.0, 0.75, 0.35, 0.95) if armed else Color(1, 1, 1, 0.5), 5.0 if armed else 3.0, true)
	if inner_ratio > 0.0:
		_canvas.draw_arc(c, r * inner_ratio, 0, TAU, 40, Color(1, 1, 1, 0.3), 2.0, true)
	_canvas.draw_circle(c + v * r, r * 0.36, Color(0.95, 0.93, 0.88, 0.75))
	_canvas.draw_arc(c + v * r, r * 0.36, 0, TAU, 32, Color(0.1, 0.1, 0.14, 0.7), 3.0, true)


func _draw_button_face(w: Dictionary, col: Color) -> void:
	var c: Vector2 = w["c"]
	var r: float = w["r"]
	var down := _touches.values().has(w)
	_canvas.draw_circle(c, r, Color(0.07, 0.07, 0.1, 0.62))
	_canvas.draw_circle(c, r - 7.0, col.darkened(0.25 if down else 0.45) * Color(1, 1, 1, 0.92))
	_canvas.draw_arc(c, r - 3.0, 0, TAU, 40, col.lightened(0.2), 4.0, true)


func _draw_fusion(w: Dictionary) -> void:
	var ready := _player.queue.can_fuse()
	_draw_button_face(w, Color("#ab79c7") if ready else Color("#615565"))
	var c: Vector2 = w["c"]
	var ring := PackedVector2Array([
		Vector2(-13, -11), Vector2(13, -11), Vector2(20, -8), Vector2(24, -3),
		Vector2(24, 3), Vector2(20, 8), Vector2(13, 11), Vector2(-13, 11),
		Vector2(-20, 8), Vector2(-24, 3), Vector2(-24, -3), Vector2(-20, -8), Vector2(-13, -11)
	])
	var ink := Color("#33273d")
	var front := Color("#fff0be") if ready else Color("#e1d7e7")
	var back := Color("#db9fff") if ready else Color("#af9ebd")
	var tilt := Transform2D(deg_to_rad(-38.0), c)
	var lower := tilt.translated_local(Vector2(-13, 5)) * ring
	var upper := tilt.translated_local(Vector2(13, -5)) * ring
	_canvas.draw_polyline(lower, ink, 11.0, true)
	_canvas.draw_polyline(lower, front, 6.0, true)
	_canvas.draw_polyline(upper, ink, 11.0, true)
	_canvas.draw_polyline(upper, back, 6.0, true)
	# 在第二處交叉把下方鏈環的弧端畫回前面，使兩枚鏈環看得出穿扣關係。
	var overpass := lower.slice(2, 6)
	_canvas.draw_polyline(overpass, ink, 11.0, true)
	_canvas.draw_polyline(overpass, front, 6.0, true)


func _draw_action_icon(kind: String, c: Vector2, tint: Color) -> void:
	_canvas.draw_set_transform(c)
	match kind:
		"to_altar", "to_village":
			var mirror := -1.0 if kind == "to_village" else 1.0
			_canvas.draw_set_transform(c, 0.0, Vector2(mirror, 1))
			_canvas.draw_polyline(PackedVector2Array([Vector2(-5, -9), Vector2(-5, -15), Vector2(1, -21),
				Vector2(16, -21), Vector2(21, -16), Vector2(21, 20), Vector2(-5, 20), Vector2(-5, 10)]), tint, 4)
			_canvas.draw_line(Vector2(-21, 0), Vector2(9, 0), tint, 5)
			_canvas.draw_polyline(PackedVector2Array([Vector2(1, -8), Vector2(9, 0), Vector2(1, 8)]), tint, 5)
		"equip":
			_canvas.draw_colored_polygon(PackedVector2Array([Vector2(0, -23), Vector2(11, -11),
				Vector2(0, 3), Vector2(-11, -11)]), tint)
			_canvas.draw_rect(Rect2(-16, 7, 32, 5), tint)
			_canvas.draw_rect(Rect2(-10, 12, 20, 5), tint)
			_canvas.draw_rect(Rect2(-21, 17, 42, 5), tint)
		"loadout_cancel":
			_canvas.draw_line(Vector2(-11, -11), Vector2(11, 11), tint, 5)
			_canvas.draw_line(Vector2(-11, 11), Vector2(11, -11), tint, 5)
		"loadout_apply":
			_canvas.draw_polyline(PackedVector2Array([Vector2(-15, 0), Vector2(-4, 11), Vector2(16, -12)]), tint, 6)
		"locked":
			_canvas.draw_polyline(PackedVector2Array([Vector2(-9, 0), Vector2(-9, -10), Vector2(-5, -15),
				Vector2(5, -15), Vector2(9, -10), Vector2(9, 0)]), tint, 4)
			_canvas.draw_rect(Rect2(-14, -1, 28, 19), tint)
			_canvas.draw_rect(Rect2(-2, 5, 4, 7), Color("#393238"))
	_canvas.draw_set_transform(Vector2.ZERO)


func _draw_tablet(w: Dictionary, icon: String, label: String, body: Color, rim: Color) -> void:
	var center: Vector2 = w["c"]
	var extent: Vector2 = w["extent"]
	var rect := Rect2(center - extent, extent * 2.0)
	_canvas.draw_rect(rect, body.lightened(0.15) if _touches.values().has(w) else body)
	_canvas.draw_rect(rect, rim, false, 3.0)
	var text_width := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 29).x
	_draw_action_icon(icon, center + Vector2(-text_width * 0.5 - 8, 0), rim)
	_draw_label(center + Vector2(28, 0), label, 29)


func _draw_loadout() -> void:
	var size := get_viewport().get_visible_rect().size
	var center := size * 0.5
	var panel := Rect2(center - Vector2(336, 282), Vector2(672, 564))
	_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.04, 0.08, 0.58))
	_canvas.draw_rect(panel, Color("#211c2a"))
	_canvas.draw_rect(panel, Color("#bc9e75"), false, 3.0)
	_canvas.draw_rect(panel.grow(-9.0), Color("#5d4d53"), false, 2.0)
	_draw_label(center + Vector2(-156, -238), "元素祭壇", 40)
	_draw_label(center + Vector2(169, -235), "出戰  %d／%d" % [_draft_loadout.size(), Elements.LOADOUT.size()], 30)
	var hint := "先取消一種，再換入其他元素" if _draft_loadout.size() == Elements.LOADOUT.size() else "選滿四種即可確定"
	_draw_label(center + Vector2(0, -199), hint, 24)
	for w in _widgets:
		match w["kind"]:
			"loadout_option":
				var element: int = w["element"]
				var position: Vector2 = w["c"]
				var slot := _draft_loadout.find(element)
				_draw_element_button(w, slot >= 0 or _draft_loadout.size() < Elements.LOADOUT.size())
				if slot >= 0:
					var badge := position + Vector2(40, -39)
					_canvas.draw_circle(badge, 19.0, Color("#342648"))
					_draw_label(badge, str(slot + 1), 24)
				_draw_label(position + Vector2(0, 76), Elements.display_name(element), 27)
			"loadout_cancel":
				_draw_tablet(w, "loadout_cancel", "取消", Color("#342e40"), Color("#ac9bae"))
			"loadout_apply":
				var ready := _draft_loadout.size() == Elements.LOADOUT.size()
				_draw_tablet(w, "loadout_apply", "裝備", Color("#574157") if ready else Color("#302b34"),
					Color("#e5c58b") if ready else Color("#595360"))


func _draw_element_button(w: Dictionary, active := true) -> void:
	var element: int = w["element"]
	var col := Elements.color(element)
	_draw_button_face(w, col if active else col.darkened(0.45))
	# 圖集一格對應一種基礎元素；以整數倍放大，貼齊畫布像素。
	var tile := Vector2.ONE * ELEMENT_ICONS.get_height()
	var size := tile * 4.0
	var center: Vector2 = w["c"]
	var dst := Rect2((center - size * 0.5).round(), size)
	var src := Rect2(Vector2(Elements.ICON_ORDER.find(element) * tile.x, 0), tile)
	_canvas.draw_texture_rect_region(ELEMENT_ICONS, dst, src)


func _draw_button(w: Dictionary, col: Color, label: String, font_size: int) -> void:
	_draw_button_face(w, col)
	_draw_label(w["c"], label, font_size)


func _draw_label(c: Vector2, label: String, font_size: int) -> void:
	var ts := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	_canvas.draw_string_outline(_font, c + Vector2(-ts.x * 0.5, ts.y * 0.32), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, Color(0.08, 0.06, 0.1, 0.9))
	_canvas.draw_string(_font, c + Vector2(-ts.x * 0.5, ts.y * 0.32), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
