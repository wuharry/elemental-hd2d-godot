extends CanvasLayer
## 手機 HUD：左搖桿移動、右搖桿瞄準施放、四顆元素鍵、融合鍵、三個快捷槽。
## 全部用觸控事件（滑鼠會被模擬成觸控），所以可以多指同時按。
## 這裡只把操作轉成對 Player／ElementQueue 的呼叫，不放任何玩法規則。

signal interaction_requested
signal element_replacement_requested(slot: int, element: int)
signal season_requested(season_name: String)
signal weather_toggled

## DRAFT：內圈佔搖桿半徑的比例，需要實機測試後才定（規則文件第 5 節）。
const AIM_INNER_RATIO := 0.55
const LONG_PRESS_SEC := 0.35
const ELEMENT_ICONS: Texture2D = preload("res://assets/ui/element_icons.png")
const INTERACTION_LABELS := {
	"to_altar": "進入祭壇",
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
var _interaction := ""
var _altar_element := -1
var _interact_widget: Dictionary = {}
var _supports_seasons := true
var _season := "summer"
var _outdoor := true

const SEASON_COLORS := {
	"spring": Color("#f2a6c4"),
	"summer": Color("#7ac46a"),
	"autumn": Color("#e89a44"),
	"winter": Color("#9ec8f0"),
}


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
	_player.loadout_changed.connect(_canvas.queue_redraw)
	_tod.changed.connect(_canvas.queue_redraw.unbind(1))
	_tod.weather_changed.connect(_canvas.queue_redraw.unbind(1))
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
	var move_c := Vector2(230, size.y - 230)
	var aim_c := Vector2(size.x - 320, size.y - 270)
	var angles := [125.0, 160.0, 195.0, 230.0]
	for i in _player.loadout.size():
		var a := deg_to_rad(angles[i])
		var c := aim_c + Vector2(cos(a), -sin(a)) * 228.0
		_widgets.append({"kind": "element", "c": c, "r": 54.0, "slot": i})
	var fa := deg_to_rad(58.0)
	_widgets.append({"kind": "fuse", "c": aim_c + Vector2(cos(fa), -sin(fa)) * 215.0, "r": 58.0})
	for i in 3:
		_widgets.append({"kind": "quick", "c": aim_c + Vector2((i - 1) * 118.0, -352.0 + absf(i - 1) * 22.0), "r": 40.0})
	# 驗收用：切換時段（正式版會拿掉）
	for i in TimeOfDay.ORDER.size():
		_widgets.append({"kind": "time", "c": Vector2(size.x - 60.0 - (3 - i) * 74.0, 58.0), "r": 30.0, "time": TimeOfDay.ORDER[i]})
	# 驗收用：季節與下雨切換（排在時段鍵下方，遠離快捷槽）
	if _outdoor:
		_widgets.append({"kind": "weather", "c": Vector2(size.x - 60.0, 126.0), "r": 25.0})
	if _supports_seasons:
		for i in SceneDef.SEASONS.size():
			_widgets.append({"kind": "season", "c": Vector2(size.x - 124.0 - (3 - i) * 62.0, 126.0), "r": 25.0, "season": SceneDef.SEASONS[i]})
	# 搖桿的擴大命中區要排在實際按鍵之後，避免吃掉融合鍵靠內側的點按。
	_widgets.append({"kind": "move", "c": move_c, "r": 135.0, "v": Vector2.ZERO})
	_widgets.append({"kind": "aim", "c": aim_c, "r": 125.0, "v": Vector2.ZERO})
	_update_interact_widget()
	_canvas.queue_redraw()


func set_environment_state(supports_seasons: bool, season_name: String, outdoor: bool) -> void:
	var layout_changed := supports_seasons != _supports_seasons or outdoor != _outdoor
	_supports_seasons = supports_seasons
	_season = season_name
	_outdoor = outdoor
	if layout_changed:
		_layout()
	else:
		_canvas.queue_redraw()


## 移動穿過互動邊界時，只撤換屬於舊地點的按鍵與觸控，讓搖桿持續跟著手指。
func set_interaction(action: String, altar_element: int) -> void:
	if action != _interaction:
		_interaction = action
		_update_interact_widget()
		_canvas.queue_redraw()
	if altar_element != _altar_element:
		_altar_element = altar_element
		# 取消舊祭壇上的點按，保留正在推動的搖桿。
		for i: int in _touches.keys():
			if _touches[i]["kind"] == "element":
				_touches.erase(i)
		_canvas.queue_redraw()


func _update_interact_widget() -> void:
	if not _interact_widget.is_empty():
		_widgets.erase(_interact_widget)
		for i: int in _touches.keys():
			if _touches[i] == _interact_widget:
				_touches.erase(i)
		_interact_widget = {}
	if not INTERACTION_LABELS.has(_interaction):
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
	if event is InputEventScreenTouch:
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
	if w["kind"] == "interact" and not _contains_point(w, pos):
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
			var slot: int = w["slot"]
			var element: int = _player.loadout[slot]
			if _altar_element >= 0:
				if _contains_point(w, pos):
					element_replacement_requested.emit(slot, _altar_element)
			elif held >= LONG_PRESS_SEC:
				_say("%s盾：規則待定，尚未實作" % Elements.display_name(element))
			elif not _player.queue.add(element):
				_say("佇列已滿（四格）")
		"fuse":
			if not _player.queue.fuse_last_two():
				_say("最後兩格不能融合")
		"quick":
			_say("快捷法術：累積擊殺後解鎖，尚未實作")
		"time":
			_tod.set_time(w["time"])
		"season":
			season_requested.emit(w["season"])
		"weather":
			weather_toggled.emit()
		"interact":
			interaction_requested.emit()


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
	var equipped_slot := _player.loadout.find(_altar_element)
	if _altar_element >= 0:
		_draw_altar_hint(equipped_slot)
	for w in _widgets:
		match w["kind"]:
			"move":
				_draw_stick(w, 0.0)
			"aim":
				_draw_stick(w, AIM_INNER_RATIO)
			"element":
				_draw_element_button(w, _altar_element >= 0 and (equipped_slot < 0 or equipped_slot == w["slot"]))
			"fuse":
				_draw_fusion(w)
			"quick":
				_draw_button_face(w, Color("#55524e"))
				_draw_action_icon("locked", w["c"], Color("#d2c7b4"))
			"time":
				var on: bool = _tod.current == w["time"]
				_draw_button(w, Color("#ffd27a") if on else Color("#4a4a52"), TimeOfDay.LABELS[w["time"]], 24)
			"season":
				var s: String = w["season"]
				var on: bool = _season == s
				_draw_button(w, SEASON_COLORS[s] if on else Color("#464650"), SceneDef.SEASON_LABELS[s], 22)
			"weather":
				var rain_on: bool = _tod.weather == "rain"
				_draw_button(w, Color("#6eaef0") if rain_on else Color("#464650"), TimeOfDay.WEATHER_LABELS[_tod.weather], 22)
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


func _draw_altar_hint(equipped_slot: int) -> void:
	var center := get_viewport().get_visible_rect().size - Vector2(765, 143)
	var rect := Rect2(center - Vector2(155, 48), Vector2(310, 96))
	var rim := Elements.color(_altar_element).lightened(0.32)
	_canvas.draw_rect(rect, Color("#211c2a"))
	_canvas.draw_rect(rect, rim, false, 3.0)
	_draw_element_icon(_altar_element, center + Vector2(-104, 0), 3.0)
	_draw_label(center + Vector2(33, -17), "%s祭壇" % Elements.display_name(_altar_element), 29)
	var hint := "點亮起的格子替換" if equipped_slot < 0 else "已裝備"
	_draw_label(center + Vector2(33, 19), hint, 25)


func _draw_element_button(w: Dictionary, highlighted: bool) -> void:
	var element: int = _player.loadout[w["slot"]]
	var center: Vector2 = w["c"]
	_draw_button_face(w, Elements.color(element))
	if highlighted:
		var rim := Elements.color(_altar_element).lightened(0.48)
		_canvas.draw_arc(center, w["r"] + 5.0, 0, TAU, 48, rim, 4.0, true)
	_draw_element_icon(element, center, 4.0)


func _draw_element_icon(element: int, center: Vector2, magnification: float) -> void:
	# 圖集一格對應一種基礎元素；以整數倍放大，貼齊畫布像素。
	var tile := Vector2.ONE * ELEMENT_ICONS.get_height()
	var size := tile * magnification
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
