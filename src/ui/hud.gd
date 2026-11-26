extends CanvasLayer
## 手機 HUD（HD-2D 古典奇幻立體徽章風格）：左搖桿移動、右搖桿瞄準施放、四顆元素鍵、融合鍵、三個快捷槽。
## 全部用觸控事件（滑鼠會被模擬成觸控），所以可以多指同時按。
## 這裡只把操作轉成對 Player／ElementQueue 的呼叫，不放任何玩法規則。

signal interaction_requested
signal element_replacement_requested(slot: int, element: int)
signal season_requested(season_name: String)
signal weather_toggled
signal settings_requested

## DRAFT：內圈佔搖桿半徑的比例，需要實機測試後才定（規則文件第 5 節）。
const AIM_INNER_RATIO := 0.55
const TAP_SECONDS := 0.35
const ELEMENT_ICONS: Texture2D = preload("res://assets/ui/element_icons.png")
const INTERACTION_LABELS := {
	"to_altar": "進入祭壇",
	"to_village": "返回村莊",
	"mage_workshop": "魔術師工坊",
	"rain_book": "閱讀法術書",
	"training_turret": "切換試煉",
}
const STATUS_META := {
	"wet": {"label": "潮濕", "color": Color("#55b8ff")},
	"burning": {"label": "燃燒", "color": Color("#ff6f3c")},
	"frozen": {"label": "冰凍", "color": Color("#8ceeff")},
	"poisoned": {"label": "中毒", "color": Color("#a8e050")},
	"rooted": {"label": "纏繞", "color": Color("#6fd478")},
}
const COL_PLAQUE := Color("#231830")
const COL_PLAQUE_HI := Color("#39284d")
const COL_GOLD := Color("#dfb15b")
const COL_GOLD_BRIGHT := Color("#fce49c")
const COL_GOLD_DARK := Color("#7d5422")
const COL_CRIMSON := Color("#8a233d")

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
var _anim_t := 0.0

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
	_player.notice.connect(_say)
	_player.casting_changed.connect(_canvas.queue_redraw)
	_player.knowledge.changed.connect(_canvas.queue_redraw)
	_tod.changed.connect(_canvas.queue_redraw.unbind(1))
	_tod.weather_changed.connect(_canvas.queue_redraw.unbind(1))
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	_widgets.clear()
	_touches.clear()
	_player.cancel_element_holds()
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
		_widgets.append({"kind": "quick", "c": aim_c + Vector2((i - 1) * 118.0, -352.0 + absf(i - 1) * 22.0), "r": 40.0, "slot": i})
	_widgets.append({"kind": "settings", "c": Vector2(58, 58), "r": 28.0})
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
		_player.cancel_element_holds()
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
	_anim_t += delta
	_toast_time = maxf(0.0, _toast_time - delta)
	_canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_press(touch.index, touch.position)
		elif touch.canceled:
			if _touches.has(touch.index):
				_player.finish_element_hold("touch_%d" % touch.index, true)
				var widget: Dictionary = _touches[touch.index]
				_touches.erase(touch.index)
				if widget["kind"] in ["move", "aim"]:
					widget["v"] = Vector2.ZERO
					if widget["kind"] == "move":
						_player.move_input = Vector2.ZERO
					else:
						_player.aim_input = Vector2.ZERO
						_player.cancel_cast_selection()
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
			if w["kind"] == "element" and _altar_element < 0:
				_player.begin_element_hold("touch_%d" % index, w["slot"])
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
	if w["kind"] == "element" and not _contains_point(w, pos):
		_player.finish_element_hold("touch_%d" % index, true)
		_touches.erase(index)
		return
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
	if w["kind"] not in ["move", "aim"] and not _contains_point(w, pos):
		_player.finish_element_hold("touch_%d" % index, true)
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
			if not w["moved"] and held < TAP_SECONDS:
				_say("副手武器：規則待定，尚未實作")
			elif v.length() >= AIM_INNER_RATIO:
				# 在外圈放開 = 施放；拉回內圈再放開 = 取消並保留佇列
				if not _player.has_prepared_spell():
					_say("佇列是空的")
				else:
					_player.cast_queue(_to_world(v))
			else:
				_player.cancel_cast_selection()
		"element":
			var slot: int = w["slot"]
			if _altar_element >= 0:
				if _contains_point(w, pos):
					element_replacement_requested.emit(slot, _altar_element)
			else:
				_player.finish_element_hold("touch_%d" % index)
		"fuse":
			if not _player.queue.fuse_last_two():
				_say("最後兩格不能融合")
		"quick":
			_player.arm_shortcut(w["slot"])
		"settings":
			settings_requested.emit()
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


# ---------- HD-2D 奇幻遊戲 HUD 繪製 ----------

func _draw_hud() -> void:
	_draw_combat_status()
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
				_draw_quick_slot(w)
			"settings":
				_draw_settings_button(w)
			"time":
				var on: bool = _tod.current == w["time"]
				_draw_button(w, Color("#e8b95c") if on else Color("#4b4059"), TimeOfDay.LABELS[w["time"]], 22, on)
			"season":
				var s: String = w["season"]
				var on: bool = _season == s
				_draw_button(w, SEASON_COLORS[s] if on else Color("#453d54"), SceneDef.SEASON_LABELS[s], 20, on)
			"weather":
				var rain_on: bool = _tod.weather == "rain"
				_draw_button(w, Color("#5fb0f6") if rain_on else Color("#453d54"), TimeOfDay.WEATHER_LABELS[_tod.weather], 20, rain_on)
			"interact":
				_draw_tablet(w, _interaction, INTERACTION_LABELS[_interaction])
	if _toast_time > 0.0:
		_draw_toast()


func _draw_toast() -> void:
	var size := get_viewport().get_visible_rect().size
	var a := clampf(_toast_time / 0.35, 0.0, 1.0)
	var tw := _font.get_string_size(_toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 23).x
	var rect := Rect2((size.x - tw - 54.0) * 0.5, size.y - 102.0, tw + 54.0, 44.0)
	_draw_banner_plaque(rect, Color(COL_PLAQUE.r, COL_PLAQUE.g, COL_PLAQUE.b, 0.92 * a), Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, a), false)
	_draw_label(rect.get_center(), _toast, 23, Color(1, 0.95, 0.84, a))


## 實體鍛金奇幻牌匾（外暗影＋深紫本體＋上亮斜邊＋雙金線＋四角黃銅鉚扣）
func _draw_banner_plaque(rect: Rect2, fill: Color, rim: Color, ornate: bool = true) -> void:
	_canvas.draw_rect(Rect2(rect.position + Vector2(3, 4), rect.size), Color(0.03, 0.015, 0.05, fill.a * 0.6))
	_canvas.draw_rect(rect, fill)
	_canvas.draw_rect(Rect2(rect.position + Vector2(2, 2), Vector2(rect.size.x - 4, 4)), Color(1, 0.94, 0.80, 0.12 * fill.a))
	_canvas.draw_rect(Rect2(rect.position + Vector2(2, rect.size.y - 5), Vector2(rect.size.x - 4, 3)), Color(0.04, 0.02, 0.06, 0.45 * fill.a))
	_canvas.draw_rect(rect, rim, false, 2.5)
	if ornate:
		_canvas.draw_rect(rect.grow(-5.0), Color(rim.r, rim.g, rim.b, 0.42), false, 1.0)
		for corner: Vector2 in [rect.position + Vector2(5, 5), Vector2(rect.end.x - 5, rect.position.y + 5),
				Vector2(rect.position.x + 5, rect.end.y - 5), rect.end - Vector2(5, 5)]:
			var poly := PackedVector2Array([corner + Vector2(0, -4), corner + Vector2(4, 0), corner + Vector2(0, 4), corner + Vector2(-4, 0)])
			_canvas.draw_colored_polygon(poly, COL_GOLD_BRIGHT)


func _draw_stick(w: Dictionary, inner_ratio: float) -> void:
	var c: Vector2 = w["c"]
	var r: float = w["r"]
	var v: Vector2 = w["v"]
	var armed := inner_ratio > 0.0 and v.length() >= inner_ratio
	var accent := COL_GOLD_BRIGHT
	if inner_ratio > 0.0 and _player.has_prepared_spell():
		var spell := _prepared_spell()
		if not spell.is_empty():
			accent = Elements.color(spell["dominant"]).lightened(0.28)
	# 奇幻星盤底盤與四方菱形羅盤刻度
	_canvas.draw_circle(c, r, Color(0.08, 0.055, 0.13, 0.36))
	_canvas.draw_arc(c, r - 2.0, 0, TAU, 56, accent if armed else Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.52), 4.0 if armed else 2.5, true)
	for i in 4:
		var a := i * PI * 0.5
		var p := c + Vector2(cos(a), sin(a)) * (r - 2.0)
		var d := PackedVector2Array([p + Vector2(0, -4), p + Vector2(4, 0), p + Vector2(0, 4), p + Vector2(-4, 0)])
		_canvas.draw_colored_polygon(d, accent if armed else Color(COL_GOLD_BRIGHT.r, COL_GOLD_BRIGHT.g, COL_GOLD_BRIGHT.b, 0.65))
	if inner_ratio > 0.0:
		for seg in 16:
			var a0 := seg * TAU / 16.0
			var a1 := a0 + TAU / 28.0
			_canvas.draw_arc(c, r * inner_ratio, a0, a1, 4, Color(1, 0.94, 0.84, 0.38), 2.0, true)
		if armed:
			var dir_a := v.angle()
			_canvas.draw_arc(c, r + 5.0, dir_a - 0.45, dir_a + 0.45, 16, accent, 5.5, true)
	# 雕琢晶球搖桿頭
	var knob := c + v * r
	var kr := r * 0.34
	_canvas.draw_circle(knob + Vector2(0, 4), kr, Color(0.04, 0.02, 0.06, 0.5))
	_canvas.draw_circle(knob, kr, COL_GOLD_DARK)
	_canvas.draw_circle(knob, kr - 3.5, accent.lerp(Color("#f4ebd8"), 0.45 if armed else 0.88) * Color(1, 1, 1, 0.88))
	_canvas.draw_arc(knob, kr - 6.0, -2.5, -0.7, 12, Color(1, 1, 1, 0.55), 3.0, true)
	_canvas.draw_arc(knob, kr - 1.5, 0, TAU, 32, COL_GOLD_BRIGHT if armed else COL_GOLD, 2.5, true)


## 遊戲風格立體鍛金寶石按鍵底盤（雙金屬圈＋凹槽寶石井＋頂部反光＋四方小鉚釘）
func _draw_medallion_face(w: Dictionary, col: Color, glowing: bool = false, brass_rim: bool = true) -> void:
	var c: Vector2 = w["c"]
	var r: float = w["r"]
	var down := _touches.values().has(w)
	var dy := 2.0 if down else 0.0
	var center := c + Vector2(0, dy)
	_canvas.draw_circle(c + Vector2(0, 4), r + 1.5, Color(0.02, 0.01, 0.04, 0.58))
	_canvas.draw_circle(center, r, COL_GOLD_DARK if brass_rim else col.darkened(0.65))
	_canvas.draw_circle(center, r - 3.5, Color(0.09, 0.065, 0.15, 0.94))
	var well := col.darkened(0.18 if down else (0.28 if glowing else 0.46))
	_canvas.draw_circle(center, r - 7.0, Color(well.r, well.g, well.b, 0.94))
	# 上半立體寶石高光弧
	_canvas.draw_arc(center, r - 10.5, -PI * 0.82, -PI * 0.18, 16, Color(1, 1, 1, 0.24 if not down else 0.10), 3.2, true)
	var rim := COL_GOLD_BRIGHT if (glowing and brass_rim) else (COL_GOLD if brass_rim else col.lightened(0.28))
	_canvas.draw_arc(center, r - 2.0, 0, TAU, 44, rim, 3.2 if glowing else 2.5, true)
	# 大鍵四向鍛金小鉚扣
	if r >= 40.0 and brass_rim:
		for i in 4:
			var a := i * PI * 0.5
			var stud := center + Vector2(cos(a), sin(a)) * (r - 2.0)
			_canvas.draw_circle(stud, 2.6, COL_GOLD_BRIGHT if glowing else COL_GOLD)


func _draw_fusion(w: Dictionary) -> void:
	var ready := _player.queue.can_fuse()
	var pulse := 0.5 + 0.5 * sin(_anim_t * 5.0)
	var c: Vector2 = w["c"]
	var r: float = w["r"]
	if ready:
		_canvas.draw_arc(c, r + 5.0 + pulse * 3.0, 0, TAU, 48, Color(0.95, 0.78, 1.0, 0.40 + pulse * 0.35), 4.5, true)
	_draw_medallion_face(w, Color("#a962db") if ready else Color("#564869"), ready, true)
	var ring := PackedVector2Array([
		Vector2(-13, -11), Vector2(13, -11), Vector2(20, -8), Vector2(24, -3),
		Vector2(24, 3), Vector2(20, 8), Vector2(13, 11), Vector2(-13, 11),
		Vector2(-20, 8), Vector2(-24, 3), Vector2(-24, -3), Vector2(-20, -8), Vector2(-13, -11)
	])
	var ink := Color("#261933")
	var front := Color("#fff2be") if ready else Color("#dfd4e8")
	var back := Color("#e4abff") if ready else Color("#9e8fae")
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


func _draw_quick_slot(w: Dictionary) -> void:
	var slot: int = w["slot"]
	var c: Vector2 = w["c"]
	var r: float = w["r"]
	var spell := _player.knowledge.shortcut_spell(slot)
	var armed := _player.armed_shortcut == slot
	var has_spell := not spell.is_empty()
	var face_col := COL_GOLD if armed else (Elements.color(spell["dominant"]) if has_spell else Color("#524564"))
	if armed:
		_canvas.draw_arc(c, r + 5.5, 0, TAU, 40, COL_GOLD_BRIGHT, 3.8, true)
	_draw_medallion_face(w, face_col, armed or has_spell, true)
	if not has_spell:
		_draw_action_icon("locked", c, Color("#c5b49f"))
	else:
		if spell.get("kind") == "rain":
			_draw_rain_glyph(c)
		elif Elements.is_base(spell["dominant"]):
			_draw_element_icon(spell["dominant"], c, 2.5)
		else:
			_draw_action_icon("spell", c, Elements.color(spell["dominant"]).lightened(0.3))
		var name_text: String = spell["name"]
		var tw := _font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var pill := Rect2(c.x - tw * 0.5 - 10.0, c.y + r + 5.0, tw + 20.0, 23.0)
		_draw_banner_plaque(pill, Color(COL_PLAQUE.r, COL_PLAQUE.g, COL_PLAQUE.b, 0.90), COL_GOLD_BRIGHT if armed else COL_GOLD, false)
		_draw_label(pill.get_center(), name_text, 16, COL_GOLD_BRIGHT if armed else Color.WHITE)


func _draw_rain_glyph(c: Vector2) -> void:
	var cloud := Color("#e4f6ff")
	_canvas.draw_circle(c + Vector2(-8, -5), 8.5, cloud)
	_canvas.draw_circle(c + Vector2(3, -8), 10.0, cloud)
	_canvas.draw_circle(c + Vector2(11, -3), 7.0, cloud)
	_canvas.draw_rect(Rect2(c + Vector2(-11, -5), Vector2(24, 9)), cloud)
	for dx: float in [-8.0, 0.0, 8.0]:
		_canvas.draw_line(c + Vector2(dx, 7), c + Vector2(dx - 3.5, 16), Color("#6fd4ff"), 3.0, true)


func _draw_settings_button(w: Dictionary) -> void:
	_draw_medallion_face(w, Color("#56416c"), false, true)
	var c: Vector2 = w["c"]
	var gear_col := COL_GOLD_BRIGHT
	for i in 8:
		var a := float(i) * TAU / 8.0
		var p0 := c + Vector2(cos(a), sin(a)) * 8.0
		var p1 := c + Vector2(cos(a), sin(a)) * 13.5
		_canvas.draw_line(p0, p1, gear_col, 4.0, true)
	_canvas.draw_circle(c, 9.2, gear_col)
	_canvas.draw_circle(c, 4.5, COL_PLAQUE)


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
			_canvas.draw_polyline(PackedVector2Array([Vector2(-8, 0), Vector2(-8, -9), Vector2(-4, -13),
				Vector2(4, -13), Vector2(8, -9), Vector2(8, 0)]), tint, 3.5, true)
			_canvas.draw_rect(Rect2(-12, -1, 24, 17), tint)
			_canvas.draw_rect(Rect2(-2, 4, 4, 7), COL_PLAQUE)
		"rain_book", "mage_workshop":
			_canvas.draw_rect(Rect2(-20, -15, 40, 30), tint, false, 3.0)
			_canvas.draw_line(Vector2(0, -15), Vector2(0, 15), tint, 2.5)
			for y in [-8, 0, 8]:
				_canvas.draw_line(Vector2(5, y), Vector2(14, y), tint, 2.0)
				_canvas.draw_line(Vector2(-14, y), Vector2(-5, y), tint, 2.0)
		"spell", "training_turret":
			_canvas.draw_polyline(PackedVector2Array([Vector2(0, -19), Vector2(14, 0), Vector2(0, 19), Vector2(-14, 0), Vector2(0, -19)]), tint, 3.5, true)
			_canvas.draw_circle(Vector2.ZERO, 4.5, tint)
	_canvas.draw_set_transform(Vector2.ZERO)


func _draw_tablet(w: Dictionary, icon: String, label: String) -> void:
	var center: Vector2 = w["c"]
	var extent: Vector2 = w["extent"]
	var rect := Rect2(center - extent, extent * 2.0)
	var down := _touches.values().has(w)
	_draw_banner_plaque(rect, COL_PLAQUE_HI if down else COL_PLAQUE, COL_GOLD_BRIGHT if down else COL_GOLD, true)
	var text_width := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 25).x
	_draw_action_icon(icon, center + Vector2(-text_width * 0.5 - 12, 0), COL_GOLD_BRIGHT)
	_draw_label(center + Vector2(22, 0), label, 25, COL_GOLD_BRIGHT)


func _draw_altar_hint(equipped_slot: int) -> void:
	var center := get_viewport().get_visible_rect().size - Vector2(765, 143)
	var rect := Rect2(center - Vector2(166, 48), Vector2(332, 96))
	var rim := Elements.color(_altar_element).lightened(0.32)
	_draw_banner_plaque(rect, Color(COL_PLAQUE.r, COL_PLAQUE.g, COL_PLAQUE.b, 0.94), COL_GOLD, true)
	var icon_c := center + Vector2(-108, 0)
	_canvas.draw_circle(icon_c, 32.0, COL_GOLD_DARK)
	_canvas.draw_circle(icon_c, 29.0, Color("#150e20"))
	_canvas.draw_arc(icon_c, 30.0, 0, TAU, 32, rim, 2.5, true)
	_draw_element_icon(_altar_element, icon_c, 2.8)
	_draw_label(center + Vector2(26, -15), "%s祭壇" % Elements.display_name(_altar_element), 25, COL_GOLD_BRIGHT)
	var hint := "點亮起的格子替換" if equipped_slot < 0 else "已裝備於出戰格"
	_draw_label(center + Vector2(26, 18), hint, 19, Color("#ece2d0"))


func _draw_element_button(w: Dictionary, highlighted: bool) -> void:
	var element: int = _player.loadout[w["slot"]]
	var center: Vector2 = w["c"]
	var r: float = w["r"]
	_draw_medallion_face(w, Elements.color(element), highlighted, false)
	# 外圍細古金飾圈，讓四顆元素寶石更有 RPG 裝備質感
	_canvas.draw_arc(center, r - 0.5, 0, TAU, 48, Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.58), 1.8, true)
	if highlighted:
		var pulse := 0.5 + 0.5 * sin(_anim_t * 5.0)
		var rim := Elements.color(_altar_element).lightened(0.42)
		_canvas.draw_arc(center, r + 5.0 + pulse * 2.0, 0, TAU, 48, rim, 4.0, true)
	_draw_element_icon(element, center, 4.0)
	var progress := _player.hold_progress(w["slot"])
	if progress > 0.0:
		var start_a := -PI * 0.5
		var end_a := start_a + TAU * progress
		var col := Elements.color(element).lightened(0.35)
		_canvas.draw_arc(center, r + 7.5, 0, TAU, 48, Color(0.08, 0.06, 0.14, 0.72), 8.0, true)
		_canvas.draw_arc(center, r + 7.5, start_a, end_a, 48, col, 6.0, true)
		_canvas.draw_arc(center, r + 7.5, start_a, end_a, 48, Color("#fff3c4"), 2.4, true)
		var tip := center + Vector2(cos(end_a), sin(end_a)) * (r + 7.5)
		_canvas.draw_circle(tip, 5.0, Color("#fff7d6"))


func _draw_element_icon(element: int, center: Vector2, magnification: float) -> void:
	# 圖集一格對應一種基礎元素；以整數倍放大，貼齊畫布像素。
	var tile := Vector2.ONE * ELEMENT_ICONS.get_height()
	var size := tile * magnification
	var dst := Rect2((center - size * 0.5).round(), size)
	var src := Rect2(Vector2(Elements.ICON_ORDER.find(element) * tile.x, 0), tile)
	_canvas.draw_texture_rect_region(ELEMENT_ICONS, dst, src)


func _draw_button(w: Dictionary, col: Color, label: String, font_size: int, active: bool = false) -> void:
	_draw_medallion_face(w, col, active, true)
	_draw_label(w["c"], label, font_size, COL_GOLD_BRIGHT if active else Color("#ece5f4"))


func _draw_label(c: Vector2, label: String, font_size: int, color: Color = Color.WHITE) -> void:
	var ts := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	_canvas.draw_string_outline(_font, c + Vector2(-ts.x * 0.5, ts.y * 0.32), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color(0.06, 0.04, 0.10, 0.92))
	_canvas.draw_string(_font, c + Vector2(-ts.x * 0.5, ts.y * 0.32), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func cancel_input() -> void:
	_layout()
	_player.cancel_cast_selection()


func _prepared_spell() -> Dictionary:
	if _player.armed_shortcut >= 0:
		return _player.knowledge.shortcut_spell(_player.armed_shortcut)
	return _player.knowledge.manual_spell(_player.queue.slots)


func _draw_combat_status() -> void:
	var state := _player.combat_state
	var hp_ratio := clampf(state.health / maxf(state.max_health, 1.0), 0.0, 1.0)

	# 左上角 RPG 紅寶石生命量表（鑲金框＋左側心鑽徽章＋立體血條）
	var bar_rect := Rect2(114, 34, 242, 28)
	_draw_banner_plaque(bar_rect, Color(COL_PLAQUE.r, COL_PLAQUE.g, COL_PLAQUE.b, 0.92), COL_GOLD, false)
	var inner := bar_rect.grow(-5.0)
	_canvas.draw_rect(inner, Color("#170f21"))
	if hp_ratio > 0.0:
		var fill_w := inner.size.x * hp_ratio
		_canvas.draw_rect(Rect2(inner.position, Vector2(fill_w, inner.size.y)), Color("#c93c52"))
		_canvas.draw_rect(Rect2(inner.position, Vector2(fill_w, 5.0)), Color("#f58d98"))
		_canvas.draw_rect(Rect2(inner.position + Vector2(0, inner.size.y - 4.0), Vector2(fill_w, 4.0)), Color("#781a2d"))
	for tick: float in [0.25, 0.5, 0.75]:
		var tx := inner.position.x + inner.size.x * tick
		_canvas.draw_line(Vector2(tx, inner.position.y), Vector2(tx, inner.end.y), Color(0.08, 0.04, 0.10, 0.55), 1.5)
	_draw_label(bar_rect.get_center() + Vector2(6, 0), "%d / %d" % [int(ceilf(state.health)), int(state.max_health)], 18, Color("#fff5e6"))
	# 生命紅寶石端扣
	var gem_c := Vector2(114, 48)
	var gem_outer := PackedVector2Array([gem_c + Vector2(0, -16), gem_c + Vector2(14, 0), gem_c + Vector2(0, 16), gem_c + Vector2(-14, 0)])
	var gem_inner := PackedVector2Array([gem_c + Vector2(0, -10), gem_c + Vector2(8, 0), gem_c + Vector2(0, 10), gem_c + Vector2(-8, 0)])
	_canvas.draw_colored_polygon(gem_outer, COL_GOLD_DARK)
	_canvas.draw_colored_polygon(gem_inner, Color("#e33b56"))
	_canvas.draw_polyline(gem_outer + PackedVector2Array([gem_outer[0]]), COL_GOLD_BRIGHT, 2.0, true)

	var status_y := 70.0
	if state.shield_remaining > 0.0:
		var se := state.shield_element
		var scol := Elements.color(se)
		var sratio := clampf(state.shield_remaining / maxf(state.shield_duration, 0.01), 0.0, 1.0)
		var srect := Rect2(106, status_y, 266, 28)
		_draw_banner_plaque(srect, Color(COL_PLAQUE.r, COL_PLAQUE.g, COL_PLAQUE.b, 0.92), scol.lightened(0.32), false)
		_draw_element_icon(se, Vector2(124, status_y + 14), 1.0)
		var gauge := Rect2(140, status_y + 6, 118, 16)
		_canvas.draw_rect(gauge, Color("#150f22"))
		_canvas.draw_rect(Rect2(gauge.position, Vector2(gauge.size.x * sratio, gauge.size.y)), scol)
		_canvas.draw_rect(Rect2(gauge.position, Vector2(gauge.size.x * sratio, 4.0)), scol.lightened(0.45))
		_draw_label(Vector2(314, status_y + 14), "%s盾 %.1fs" % [Elements.display_name(se), state.shield_remaining], 15, COL_GOLD_BRIGHT)
		status_y += 34.0

	# 狀態徽章
	var chips := _status_chips(state)
	var cx := 106.0
	for chip: Dictionary in chips:
		var lbl: String = chip["label"]
		var col: Color = chip["color"]
		var w := _font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 28.0
		var r := Rect2(cx, status_y, w, 25.0)
		_draw_banner_plaque(r, Color(COL_PLAQUE.r, COL_PLAQUE.g, COL_PLAQUE.b, 0.90), col, false)
		_canvas.draw_circle(Vector2(cx + 10.0, status_y + 12.5), 4.0, col)
		_draw_label(Vector2(cx + w * 0.5 + 5.0, status_y + 12.5), lbl, 16, col.lightened(0.45))
		cx += w + 8.0

	# 訓練場木樁狀態銘牌
	for target: Node3D in get_tree().get_nodes_in_group("training_targets"):
		var at := target.global_position + Vector3.UP * 2.25
		if _rig.camera.is_position_behind(at) or target.global_position.distance_to(_player.global_position) > 14:
			continue
		var point := _rig.camera.unproject_position(at)
		if not get_viewport().get_visible_rect().grow(-30).has_point(point):
			continue
		var status := _status_label(target.combat_state)
		if not status.is_empty():
			var sw := _font.get_string_size(status, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 22.0
			var sr := Rect2(point.x - sw * 0.5, point.y - 14.0, sw, 27.0)
			_draw_banner_plaque(sr, Color(COL_PLAQUE.r, COL_PLAQUE.g, COL_PLAQUE.b, 0.88), COL_GOLD, false)
			_draw_label(sr.get_center(), status, 18, Color("#fff4dc"))

	# 右搖桿下方待發法術捲軸條
	if _player.has_prepared_spell():
		var spell := _prepared_spell()
		if not spell.is_empty():
			var size := get_viewport().get_visible_rect().size
			var txt: String = spell["name"]
			var dom_col := Elements.color(spell["dominant"]).lightened(0.28)
			var tw := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 44.0
			var pr := Rect2(size.x - 320.0 - tw * 0.5, size.y - 112.0, tw, 34.0)
			_draw_banner_plaque(pr, Color(COL_PLAQUE.r, COL_PLAQUE.g, COL_PLAQUE.b, 0.94), COL_GOLD, false)
			_canvas.draw_circle(Vector2(pr.position.x + 12.0, pr.get_center().y), 4.5, dom_col)
			_canvas.draw_circle(Vector2(pr.end.x - 12.0, pr.get_center().y), 4.5, dom_col)
			_draw_label(pr.get_center(), txt, 20, COL_GOLD_BRIGHT)


func _status_chips(state: CombatState) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key: String in STATUS_META:
		if state.has_status(key):
			result.append(STATUS_META[key])
	if state.is_concealed:
		result.append({"label": "霧中隱蔽", "color": Color("#b4d6f0")})
	return result


func _status_label(state: CombatState) -> String:
	var labels := PackedStringArray()
	for chip: Dictionary in _status_chips(state):
		labels.append(chip["label"])
	return " · ".join(labels)
