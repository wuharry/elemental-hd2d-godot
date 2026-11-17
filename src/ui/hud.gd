extends CanvasLayer
## 手機 HUD：左搖桿移動、右搖桿瞄準施放、四顆元素鍵、融合鍵、三個快捷槽、頭頂佇列。
## 全部用觸控事件（滑鼠會被模擬成觸控），所以可以多指同時按。
## 這裡只把操作轉成對 Player／ElementQueue 的呼叫，不放任何玩法規則。

## DRAFT：內圈佔搖桿半徑的比例，需要實機測試後才定（規則文件第 5 節）。
const AIM_INNER_RATIO := 0.55
const LONG_PRESS_SEC := 0.35

var _player: Player
var _rig: CameraRig
var _tod: TimeOfDay
var _canvas: Control
var _font: Font
var _orb: Texture2D

var _widgets: Array[Dictionary] = []
## touch index → widget
var _touches: Dictionary = {}
var _toast := ""
var _toast_time := 0.0


func setup(player: Player, rig: CameraRig, tod: TimeOfDay) -> void:
	_player = player
	_rig = rig
	_tod = tod
	_font = ThemeDB.fallback_font
	_orb = load("res://assets/characters/orb.png")
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas.draw.connect(_draw_hud)
	add_child(_canvas)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	_widgets.clear()
	_touches.clear()
	_player.move_input = Vector2.ZERO
	_player.aim_input = Vector2.ZERO
	var move_c := Vector2(230, size.y - 230)
	var aim_c := Vector2(size.x - 320, size.y - 270)
	_widgets.append({"kind": "move", "c": move_c, "r": 135.0, "v": Vector2.ZERO})
	_widgets.append({"kind": "aim", "c": aim_c, "r": 125.0, "v": Vector2.ZERO})
	var angles := [125.0, 160.0, 195.0, 230.0]
	for i in 4:
		var a := deg_to_rad(angles[i])
		var c := aim_c + Vector2(cos(a), -sin(a)) * 228.0
		_widgets.append({"kind": "element", "c": c, "r": 54.0, "element": Elements.LOADOUT[i]})
	var fa := deg_to_rad(58.0)
	_widgets.append({"kind": "fuse", "c": aim_c + Vector2(cos(fa), -sin(fa)) * 215.0, "r": 58.0})
	for i in 3:
		_widgets.append({"kind": "quick", "c": aim_c + Vector2((i - 1) * 118.0, -352.0 + absf(i - 1) * 22.0), "r": 40.0})
	# 驗收用：切換時段（正式版會拿掉）
	for i in TimeOfDay.ORDER.size():
		_widgets.append({"kind": "time", "c": Vector2(size.x - 60.0 - (3 - i) * 74.0, 58.0), "r": 30.0, "time": TimeOfDay.ORDER[i]})


func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time -= delta
	_canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_press(touch.index, touch.position)
		else:
			_release(touch.index, touch.position)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_drag(drag.index, drag.position)


func _press(index: int, pos: Vector2) -> void:
	for w in _widgets:
		var reach: float = w["r"] * (1.35 if w["kind"] in ["move", "aim"] else 1.0)
		if pos.distance_to(w["c"]) <= reach and not _touches.values().has(w):
			w["t0"] = Time.get_ticks_msec()
			w["moved"] = false
			_touches[index] = w
			_drag(index, pos)
			get_viewport().set_input_as_handled()
			return


func _drag(index: int, pos: Vector2) -> void:
	if not _touches.has(index):
		return
	var w: Dictionary = _touches[index]
	if w["kind"] == "move" or w["kind"] == "aim":
		var v: Vector2 = (pos - w["c"]) / w["r"]
		if v.length() > 1.0:
			v = v.normalized()
		w["v"] = v
		if v.length() > 0.2:
			w["moved"] = true
		if w["kind"] == "move":
			_player.move_input = v if v.length() > 0.15 else Vector2.ZERO
		else:
			_player.aim_input = v if v.length() > 0.2 else Vector2.ZERO
			if v.length() > 0.2:
				_player.aim_dir = _to_world(v)


func _release(index: int, _pos: Vector2) -> void:
	if not _touches.has(index):
		return
	var w: Dictionary = _touches[index]
	_touches.erase(index)
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


## 搖桿向量（螢幕方向）→ 世界水平方向。
func _to_world(v: Vector2) -> Vector3:
	return Vector3(v.x, 0, v.y).rotated(Vector3.UP, _rig.yaw()).normalized()


func _say(text: String) -> void:
	_toast = text
	_toast_time = 1.8


# ---------- 繪製 ----------

func _draw_hud() -> void:
	for w in _widgets:
		match w["kind"]:
			"move":
				_draw_stick(w, 0.0)
			"aim":
				_draw_stick(w, AIM_INNER_RATIO)
			"element":
				var col: Color = Elements.color(w["element"])
				_draw_button(w, col, Elements.display_name(w["element"]), 38)
			"fuse":
				var ready := _player.queue.can_fuse()
				_draw_button(w, Color("#c9a0ff") if ready else Color("#6a6078"), "融合", 30)
			"quick":
				_draw_button(w, Color("#55524e"), "鎖", 22)
			"time":
				var on: bool = _tod.current == w["time"]
				_draw_button(w, Color("#ffd27a") if on else Color("#4a4a52"), TimeOfDay.LABELS[w["time"]], 24)
	_draw_queue()
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


func _draw_button(w: Dictionary, col: Color, label: String, font_size: int) -> void:
	var c: Vector2 = w["c"]
	var r: float = w["r"]
	var down := _touches.values().has(w)
	_canvas.draw_circle(c, r, Color(0.07, 0.07, 0.1, 0.62))
	_canvas.draw_circle(c, r - 7.0, col.darkened(0.25 if down else 0.45) * Color(1, 1, 1, 0.92))
	_canvas.draw_arc(c, r - 3.0, 0, TAU, 40, col.lightened(0.2), 4.0, true)
	var ts := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	_canvas.draw_string_outline(_font, c + Vector2(-ts.x * 0.5, ts.y * 0.32), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, Color(0.08, 0.06, 0.1, 0.9))
	_canvas.draw_string(_font, c + Vector2(-ts.x * 0.5, ts.y * 0.32), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


## 四格佇列畫在角色頭頂（跟著角色走），每格是放大 4 倍的像素光球。
func _draw_queue() -> void:
	var cam := _rig.camera
	var head := _player.global_position + Vector3(0, 1.75, 0)
	if cam.is_position_behind(head):
		return
	# unproject_position 回傳的已經是畫布座標（跟 HUD 同一套），不用再換算
	var anchor := cam.unproject_position(head)
	var slot := 36.0
	var gap := 4.0
	var total := ElementQueue.CAPACITY * slot + (ElementQueue.CAPACITY - 1) * gap
	var origin := (anchor - Vector2(total * 0.5, slot + 6.0)).round()
	for i in ElementQueue.CAPACITY:
		var rect := Rect2(origin + Vector2(i * (slot + gap), 0), Vector2(slot, slot))
		_canvas.draw_rect(rect, Color(0.09, 0.08, 0.12, 0.78))
		_canvas.draw_rect(rect, Color(0.93, 0.86, 0.66, 0.9), false, 2.0)
		if i < _player.queue.slots.size():
			var e: int = _player.queue.slots[i]
			_canvas.draw_texture_rect(_orb, rect.grow(-2.0), false, Elements.color(e))
