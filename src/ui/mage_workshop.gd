extends CanvasLayer
## 魔術師工坊（HD-2D 像素魔法古書 UI）：翻開的紫紅皮面與羊皮紙法典，左頁手動配方、右頁快捷星槽。
## 只編輯知識模型；手動配方與三格快捷各自獨立綁定。

signal closed
signal settings_changed

const ELEMENT_ICONS: Texture2D = preload("res://assets/ui/element_icons.png")
const HOLD_PRESETS := [1.0, 1.5, 2.0, 2.5, 3.0]
const SLOT_ROMAN := ["I", "II", "III"]

# 與 B 版法師紫帽酒紅袍一致的古典奇幻色盤（羊皮紙 + 紫紅皮封 + 鍛造古金 + 紅蠟封）
const COL_LEATHER := Color("#35213e")
const COL_LEATHER_DARK := Color("#211429")
const COL_LEATHER_HI := Color("#543661")
const COL_PAGE := Color("#ede0c4")
const COL_PAGE_ALT := Color("#e3d2af")
const COL_PAGE_SHADE := Color("#cbb489")
const COL_PAGE_CREAM := Color("#f8f0dc")
const COL_INK := Color("#2a1c30")
const COL_INK_SOFT := Color("#614b56")
const COL_INK_FAINT := Color("#91786a")
const COL_GOLD := Color("#dfb15b")
const COL_GOLD_HI := Color("#fce49c")
const COL_GOLD_DARK := Color("#855b26")
const COL_RIBBON := Color("#7d243b")
const COL_RIBBON_HI := Color("#a8344f")
const COL_RIBBON_DARK := Color("#4c1324")
const COL_SOCKET := Color("#221731")
const COL_SOCKET_ACTIVE := Color("#362450")

var _player: Player
var _root: Control
var _backdrop: Control
var _book_art: Control
var _recipe_select: OptionButton
var _manual_select: OptionButton
var _quick_selects: Array[OptionButton] = []
var _recipes: Array[Array] = []
var _spells: Array[Dictionary] = []
var _selected_recipe := 0
var _active_quick_slot := 0
var _recipe_strip: Control
var _manual_cards: VBoxContainer
var _manual_hint: Label
var _quick_slots_box: HBoxContainer
var _spell_shelf: GridContainer
var _shelf_title: Label
var _hold_value_label: Label
var _hold_slider: HSlider
var _preset_buttons: Array[Button] = []
var _grabber_tex: Texture2D
var _settings_only := false
var _was_paused := false
var _previous_keyboard := true
var _anim_t := 0.0
var _syncing_proxies := false


func _init() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS


func open(player: Player, settings_only: bool = false) -> void:
	if is_instance_valid(_root):
		return
	_player = player
	_settings_only = settings_only
	_previous_keyboard = player.accept_keyboard
	player.accept_keyboard = false
	player.move_input = Vector2.ZERO
	player.aim_input = Vector2.ZERO
	player.cancel_element_holds()
	_was_paused = get_tree().paused
	get_tree().paused = true
	_selected_recipe = 0
	_active_quick_slot = 0
	_anim_t = 0.0
	_build()


func is_open() -> bool:
	return is_instance_valid(_root)


func close() -> void:
	if not is_open():
		return
	_root.queue_free()
	_root = null
	_backdrop = null
	_book_art = null
	_quick_selects.clear()
	_preset_buttons.clear()
	_player.accept_keyboard = _previous_keyboard
	get_tree().paused = _was_paused
	closed.emit()


func _process(delta: float) -> void:
	if not is_open():
		return
	_anim_t += delta
	if is_instance_valid(_backdrop):
		_backdrop.queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	if is_open() and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()


func _build() -> void:
	_grabber_tex = _make_gem_grabber()

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_root)

	# 暮光暗角與漂浮像素金星微塵
	_backdrop = Control.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.draw.connect(_draw_backdrop)
	_root.add_child(_backdrop)

	# 測試相容用隱藏代理（與遊戲法典操作雙向同步）
	var proxy_host := Control.new()
	proxy_host.name = "BindingProxies"
	proxy_host.visible = false
	_root.add_child(proxy_host)
	_setup_proxies(proxy_host)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	# 實體魔法書外框容器（皮面封面、疊頁厚度、四角黃銅護角與垂墜酒紅書籤帶由 _book_art 像素化精繪）
	var book_shell := MarginContainer.new()
	book_shell.custom_minimum_size = Vector2(780 if _settings_only else 1300, 0 if _settings_only else 720)
	center.add_child(book_shell)

	_book_art = Control.new()
	_book_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_book_art.draw.connect(_draw_grimoire_book.bind(_book_art))
	book_shell.add_child(_book_art)

	var inner_pad := MarginContainer.new()
	inner_pad.add_theme_constant_override("margin_left", 44 if _settings_only else 58)
	inner_pad.add_theme_constant_override("margin_right", 44 if _settings_only else 58)
	inner_pad.add_theme_constant_override("margin_top", 28 if _settings_only else 34)
	inner_pad.add_theme_constant_override("margin_bottom", 34 if _settings_only else 40)
	book_shell.add_child(inner_pad)

	var main_col := VBoxContainer.new()
	main_col.add_theme_constant_override("separation", 14)
	inner_pad.add_child(main_col)

	_build_banner_header(main_col)
	if not _settings_only:
		_build_open_pages(main_col)
	_build_brass_footer(main_col)
	_refresh_all()


func _setup_proxies(host: Control) -> void:
	_spells.assign(_player.knowledge.available_spells())
	_recipes.clear()
	for spell: Dictionary in _spells:
		_add_recipe(spell["elements"])
	if not _player.queue.is_empty():
		_add_recipe(_player.queue.slots)

	_recipe_select = OptionButton.new()
	_recipe_select.name = "Recipe"
	for recipe: Array in _recipes:
		_recipe_select.add_item(_recipe_label(recipe))
	host.add_child(_recipe_select)
	_selected_recipe = _preferred_recipe_index()

	_manual_select = OptionButton.new()
	_manual_select.name = "ManualSpell"
	host.add_child(_manual_select)

	_recipe_select.item_selected.connect(func(idx: int) -> void:
		if _syncing_proxies:
			return
		_selected_recipe = clampi(idx, 0, maxi(_recipes.size() - 1, 0))
		_refresh_all())
	_manual_select.item_selected.connect(func(idx: int) -> void:
		if _syncing_proxies or _selected_recipe < 0 or _selected_recipe >= _recipes.size():
			return
		var recipe: Array[int] = []
		recipe.assign(_recipes[_selected_recipe])
		var id: String = str(_manual_select.get_item_metadata(idx))
		_player.knowledge.set_manual(recipe, id)
		_refresh_all())

	_quick_selects.clear()
	for slot in 3:
		var pick := OptionButton.new()
		pick.name = "Shortcut%d" % slot
		pick.item_selected.connect(func(idx: int) -> void:
			if _syncing_proxies:
				return
			_set_shortcut(slot, pick.get_item_metadata(idx))
			_refresh_all())
		host.add_child(pick)
		_quick_selects.append(pick)


# ---------- 頂部酒紅緞帶標題與鍛金關閉鈕 ----------

func _build_banner_header(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var left_sp := Control.new()
	left_sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left_sp)

	# 酒紅金邊捲軸緞帶標題牌
	var ribbon := MarginContainer.new()
	ribbon.custom_minimum_size = Vector2(360 if _settings_only else 440, 52)
	var ribbon_bg := Control.new()
	ribbon_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ribbon_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ribbon_bg.draw.connect(func() -> void:
		var r := Rect2(Vector2.ZERO, ribbon_bg.size)
		# 左右燕尾緞帶端
		var lt := PackedVector2Array([Vector2(-18, 8), Vector2(4, 8), Vector2(4, r.size.y - 4), Vector2(-18, r.size.y - 4), Vector2(-8, r.size.y * 0.5 + 2)])
		var rt := PackedVector2Array([Vector2(r.size.x + 18, 8), Vector2(r.size.x - 4, 8), Vector2(r.size.x - 4, r.size.y - 4), Vector2(r.size.x + 18, r.size.y - 4), Vector2(r.size.x + 8, r.size.y * 0.5 + 2)])
		ribbon_bg.draw_colored_polygon(lt, COL_RIBBON_DARK)
		ribbon_bg.draw_colored_polygon(rt, COL_RIBBON_DARK)
		_draw_pixel_frame(ribbon_bg, r, COL_RIBBON, COL_GOLD, COL_RIBBON_HI, COL_RIBBON_DARK)
		# 兩側金色菱星
		for sx: float in [24.0, r.size.x - 24.0]:
			var m := Vector2(sx, r.size.y * 0.5)
			var d := PackedVector2Array([m + Vector2(0, -6), m + Vector2(6, 0), m + Vector2(0, 6), m + Vector2(-6, 0)])
			ribbon_bg.draw_colored_polygon(d, COL_GOLD_HI)
	)
	ribbon.add_child(ribbon_bg)
	var title := _label(ribbon, "操作設定" if _settings_only else "魔術師工坊", 28, COL_GOLD_HI)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", COL_RIBBON_DARK)
	title.add_theme_constant_override("outline_size", 5)
	row.add_child(ribbon)

	var right_sp := Control.new()
	right_sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right_sp)

	# 實體鍛金圓扣關閉鈕
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.custom_minimum_size = Vector2(44, 44)
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.add_theme_color_override("font_color", COL_GOLD_HI)
	close_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	close_btn.add_theme_stylebox_override("normal", _bevel_box(COL_RIBBON, COL_GOLD, COL_RIBBON_DARK, 3, 2))
	close_btn.add_theme_stylebox_override("hover", _bevel_box(COL_RIBBON_HI, COL_GOLD_HI, COL_RIBBON_DARK, 3, 2))
	close_btn.add_theme_stylebox_override("pressed", _bevel_box(COL_RIBBON_DARK, COL_GOLD, COL_RIBBON_DARK, 3, 2))
	close_btn.pressed.connect(close)
	row.add_child(close_btn)


# ---------- 翻開的左右羊皮紙書頁 ----------

func _build_open_pages(parent: VBoxContainer) -> void:
	var pages := HBoxContainer.new()
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pages.add_theme_constant_override("separation", 68)
	parent.add_child(pages)

	# === 左書頁：手動配方與法術切換 ===
	var left_page := VBoxContainer.new()
	left_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_page.add_theme_constant_override("separation", 12)
	pages.add_child(left_page)

	_page_heading(left_page, "手動配方", "右搖桿直接施放", COL_RIBBON)

	var rec_lbl := _label(left_page, "已收錄元素配方（點選切換檢視）", 16, COL_INK_SOFT)
	rec_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var recipe_flow := HFlowContainer.new()
	recipe_flow.add_theme_constant_override("h_separation", 10)
	recipe_flow.add_theme_constant_override("v_separation", 10)
	left_page.add_child(recipe_flow)
	_recipe_strip = recipe_flow

	_ink_divider(left_page)

	var bind_lbl := _label(left_page, "選擇此配方於手動施法時觸發的法術", 16, COL_INK_SOFT)
	bind_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_manual_cards = VBoxContainer.new()
	_manual_cards.add_theme_constant_override("separation", 10)
	_manual_cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_page.add_child(_manual_cards)

	_manual_hint = _label(left_page, "", 15, COL_INK_SOFT)
	_manual_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# === 右書頁：星盤快捷三槽與熟練法典 ===
	var right_page := VBoxContainer.new()
	right_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_page.add_theme_constant_override("separation", 12)
	pages.add_child(right_page)

	_page_heading(right_page, "快捷星槽", "施放保留手動佇列", Color("#3c2860"))

	# 三枚連著細金星軌的鑲嵌法術槽位
	var socket_stage := Control.new()
	socket_stage.custom_minimum_size = Vector2(0, 142)
	socket_stage.draw.connect(func() -> void:
		var w := socket_stage.size.x
		var y := 60.0
		# 手繪細金鍊接三個星槽
		socket_stage.draw_line(Vector2(w * 0.16, y), Vector2(w * 0.84, y), Color(COL_GOLD_DARK.r, COL_GOLD_DARK.g, COL_GOLD_DARK.b, 0.45), 3.0)
		socket_stage.draw_line(Vector2(w * 0.16, y), Vector2(w * 0.84, y), Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.7), 1.0)
		for mx: float in [w * 0.33, w * 0.67]:
			var p := Vector2(mx, y)
			var d := PackedVector2Array([p + Vector2(0, -5), p + Vector2(5, 0), p + Vector2(0, 5), p + Vector2(-5, 0)])
			socket_stage.draw_colored_polygon(d, COL_GOLD_DARK)
	)
	right_page.add_child(socket_stage)

	_quick_slots_box = HBoxContainer.new()
	_quick_slots_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_quick_slots_box.add_theme_constant_override("separation", 14)
	socket_stage.add_child(_quick_slots_box)

	_ink_divider(right_page)

	_shelf_title = _label(right_page, "", 16, COL_RIBBON)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 196)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_page.add_child(scroll)

	_spell_shelf = GridContainer.new()
	_spell_shelf.columns = 2
	_spell_shelf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spell_shelf.add_theme_constant_override("h_separation", 10)
	_spell_shelf.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_spell_shelf)

	_label(right_page, "實戰有效命中或降雨可累積熟練，集滿 3 顆金星即可裝入快捷。", 15, COL_INK_SOFT)


# ---------- 底部木框黃銅護盾計量條與火漆封印按鈕 ----------

func _build_brass_footer(parent: VBoxContainer) -> void:
	var tray := PanelContainer.new()
	tray.add_theme_stylebox_override("panel", _bevel_box(COL_LEATHER_DARK, COL_GOLD_DARK, Color("#120a18"), 3, 2, 18, 12))
	parent.add_child(tray)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	tray.add_child(row)

	# 護盾徽章
	var emblem := _make_icon_canvas(Vector2(44, 44), func(c: Control) -> void:
		var m := c.size * 0.5
		var outer := PackedVector2Array([m + Vector2(0, -19), m + Vector2(16, -11), m + Vector2(14, 7), m + Vector2(0, 19), m + Vector2(-14, 7), m + Vector2(-16, -11)])
		var inner := PackedVector2Array([m + Vector2(0, -13), m + Vector2(10, -7), m + Vector2(9, 4), m + Vector2(0, 13), m + Vector2(-9, 4), m + Vector2(-10, -7)])
		c.draw_colored_polygon(outer, COL_GOLD_DARK)
		c.draw_colored_polygon(inner, Color("#3a79c4"))
		c.draw_polyline(outer + PackedVector2Array([outer[0]]), COL_GOLD_HI, 2.0)
		c.draw_line(m + Vector2(0, -11), m + Vector2(0, 10), Color("#b4ecff"), 2.0)
	)
	row.add_child(emblem)

	var shield_col := VBoxContainer.new()
	shield_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shield_col.add_theme_constant_override("separation", 6)
	row.add_child(shield_col)

	var top_row := HBoxContainer.new()
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_row.add_theme_constant_override("separation", 10)
	shield_col.add_child(top_row)

	_label(top_row, "元素護盾 · 長按門檻", 19, Color("#f2e6cf"))
	_hold_value_label = _label(top_row, "%.1f 秒" % _player.shield_hold_seconds, 21, COL_GOLD_HI)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(sp)

	_preset_buttons.clear()
	for preset: float in HOLD_PRESETS:
		var pill := Button.new()
		pill.text = "%.1fs" % preset
		pill.focus_mode = Control.FOCUS_NONE
		pill.custom_minimum_size = Vector2(58, 30)
		pill.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		pill.add_theme_font_size_override("font_size", 15)
		pill.pressed.connect(func() -> void:
			_hold_slider.value = preset)
		top_row.add_child(pill)
		_preset_buttons.append(pill)

	_hold_slider = HSlider.new()
	_hold_slider.name = "ShieldHoldSeconds"
	_hold_slider.min_value = 1.0
	_hold_slider.max_value = 3.0
	_hold_slider.step = 0.1
	_hold_slider.value = _player.shield_hold_seconds
	_hold_slider.custom_minimum_size.y = 28
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#130c1c")
	track.border_color = COL_GOLD_DARK
	track.set_border_width_all(2)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#58b6ec")
	fill.border_color = Color("#a8ebff")
	fill.border_width_top = 2
	fill.content_margin_top = 6
	fill.content_margin_bottom = 6
	_hold_slider.add_theme_stylebox_override("slider", track)
	_hold_slider.add_theme_stylebox_override("grabber_area", fill)
	_hold_slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	_hold_slider.add_theme_icon_override("grabber", _grabber_tex)
	_hold_slider.add_theme_icon_override("grabber_highlight", _grabber_tex)
	_hold_slider.value_changed.connect(func(value: float) -> void:
		_player.shield_hold_seconds = value
		_hold_value_label.text = "%.1f 秒" % value
		_style_preset_pills()
		settings_changed.emit())
	shield_col.add_child(_hold_slider)

	# 右側實體金邊立體封印按鈕
	var done := Button.new()
	done.text = "收起法典" if not _settings_only else "完成設定"
	done.custom_minimum_size = Vector2(182, 56)
	done.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	done.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	done.add_theme_font_size_override("font_size", 21)
	done.add_theme_color_override("font_color", COL_GOLD_HI)
	done.add_theme_color_override("font_hover_color", Color.WHITE)
	done.add_theme_color_override("font_pressed_color", COL_GOLD_HI)
	done.add_theme_color_override("font_focus_color", COL_GOLD_HI)
	done.add_theme_color_override("font_outline_color", COL_RIBBON_DARK)
	done.add_theme_constant_override("outline_size", 4)
	var done_n := _bevel_box(COL_RIBBON, COL_GOLD, COL_RIBBON_DARK, 3, 2, 16, 8)
	var done_h := _bevel_box(COL_RIBBON_HI, COL_GOLD_HI, COL_RIBBON_DARK, 3, 2, 16, 8)
	var done_p := _bevel_box(COL_RIBBON_DARK, COL_GOLD, COL_RIBBON_DARK, 3, 2, 16, 8)
	done.add_theme_stylebox_override("normal", done_n)
	done.add_theme_stylebox_override("hover", done_h)
	done.add_theme_stylebox_override("pressed", done_p)
	done.add_theme_stylebox_override("focus", done_n)
	done.pressed.connect(close)
	row.add_child(done)
	done.grab_focus()


# ---------- 狀態刷新 ----------

func _refresh_all() -> void:
	_style_preset_pills()
	if _settings_only:
		return
	_sync_proxies()
	_rebuild_recipe_strip()
	_rebuild_manual_cards()
	_rebuild_quick_slots()
	_rebuild_spell_shelf()


func _sync_proxies() -> void:
	_syncing_proxies = true
	if not _recipes.is_empty():
		_selected_recipe = clampi(_selected_recipe, 0, _recipes.size() - 1)
		_recipe_select.disabled = false
		_recipe_select.select(_selected_recipe)
	else:
		_recipe_select.disabled = true

	_manual_select.clear()
	_manual_select.add_item("普通組合法術")
	_manual_select.set_item_metadata(0, "")
	if _selected_recipe >= 0 and _selected_recipe < _recipes.size():
		_manual_select.disabled = false
		var recipe: Array[int] = []
		recipe.assign(_recipes[_selected_recipe])
		var binding := _player.knowledge.manual_binding(recipe)
		_manual_select.select(0)
		for id: String in _player.knowledge.catalog:
			var candidate := SpellRules.resolve(recipe, id, _player.knowledge.catalog)
			if candidate.is_empty() or not _player.knowledge.is_unlocked(id):
				continue
			_manual_select.add_item(candidate["name"])
			var item := _manual_select.item_count - 1
			_manual_select.set_item_metadata(item, id)
			if binding == id:
				_manual_select.select(item)
	else:
		_manual_select.disabled = true

	for slot in 3:
		var pick := _quick_selects[slot]
		pick.clear()
		pick.add_item("未裝備")
		pick.set_item_metadata(0, {})
		pick.select(0)
		var equipped := _player.knowledge.shortcut_spell(slot)
		for spell: Dictionary in _spells:
			var progress: Dictionary = _player.knowledge.mastery_progress(spell["id"])
			var mastered: bool = _player.knowledge.is_mastered(spell["id"])
			pick.add_item(spell["name"] + ("" if mastered else "　熟練 %d/%d" % [progress["current"], progress["required"]]))
			var item := pick.item_count - 1
			pick.set_item_metadata(item, spell)
			pick.set_item_disabled(item, not mastered)
			if not equipped.is_empty() and equipped["id"] == spell["id"]:
				pick.select(item)
	_syncing_proxies = false


func _rebuild_recipe_strip() -> void:
	for child in _recipe_strip.get_children():
		child.queue_free()
	if _recipes.is_empty():
		var empty := PanelContainer.new()
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty.add_theme_stylebox_override("panel", _bevel_box(COL_PAGE_ALT, COL_PAGE_SHADE, COL_PAGE_SHADE, 2, 0, 12, 10))
		_label(empty, "尚無可設定配方 · 在訓練場組招或閱讀法術書即可收錄", 16, COL_INK_SOFT)
		_recipe_strip.add_child(empty)
		return
	for idx in _recipes.size():
		var recipe: Array[int] = []
		recipe.assign(_recipes[idx])
		var active := idx == _selected_recipe
		var has_named := _recipe_has_named(recipe)
		var holder := PanelContainer.new()
		holder.add_theme_stylebox_override("panel", _bevel_box(
			COL_SOCKET_ACTIVE if active else COL_PAGE_ALT,
			COL_GOLD_HI if active else (COL_GOLD_DARK if has_named else COL_PAGE_SHADE),
			COL_LEATHER_DARK if active else COL_PAGE_SHADE,
			3 if active else 2, 0, 10, 6))
		var content := HBoxContainer.new()
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		content.add_theme_constant_override("separation", 5)
		for i in recipe.size():
			if i > 0:
				var plus := _label(content, "+", 16, COL_GOLD_HI if active else COL_INK_SOFT)
				plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
			content.add_child(_element_gem(recipe[i], 30))
		if has_named:
			var star := _label(content, "★", 15, COL_GOLD_HI if active else COL_RIBBON)
			star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(content)

		var overlay := Button.new()
		overlay.flat = true
		overlay.focus_mode = Control.FOCUS_NONE
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		overlay.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		overlay.add_theme_stylebox_override("hover", _bevel_box(Color(1, 0.92, 0.65, 0.14), COL_GOLD, Color.TRANSPARENT, 2, 0, 0, 0))
		overlay.pressed.connect(func() -> void:
			_selected_recipe = idx
			_refresh_all())
		holder.add_child(overlay)
		_recipe_strip.add_child(holder)


func _rebuild_manual_cards() -> void:
	for child in _manual_cards.get_children():
		child.queue_free()
	if _recipes.is_empty():
		_manual_hint.text = "學會具名秘術後，可於此自由切換普通組招或秘術。"
		return
	var recipe: Array[int] = []
	recipe.assign(_recipes[_selected_recipe])
	var current_binding := _player.knowledge.manual_binding(recipe)
	var ordinary := SpellRules.resolve(recipe)

	var options: Array[Dictionary] = [{
		"id": "",
		"spell": ordinary,
		"tag": "普通組合",
		"tag_bg": Color("#3b4f74"),
		"desc": _spell_desc(ordinary, false),
		"named": false,
	}]
	for id: String in _player.knowledge.catalog:
		var candidate := SpellRules.resolve(recipe, id, _player.knowledge.catalog)
		if candidate.is_empty() or not _player.knowledge.is_unlocked(id):
			continue
		options.append({
			"id": id,
			"spell": candidate,
			"tag": "具名秘術",
			"tag_bg": COL_RIBBON,
			"desc": _spell_desc(candidate, true),
			"named": true,
		})

	for opt: Dictionary in options:
		var opt_id: String = opt["id"]
		var spell: Dictionary = opt["spell"]
		var selected := current_binding == opt_id
		var is_named: bool = opt["named"]

		# 選中＝古紙亮底鑲金框＋酒紅火漆印；未選＝柔和手繪羊皮紙框
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _bevel_box(
			COL_PAGE_CREAM if selected else COL_PAGE_ALT,
			COL_RIBBON if (selected and is_named) else (COL_GOLD_DARK if selected else COL_PAGE_SHADE),
			COL_PAGE_SHADE, 3 if selected else 2, 0, 14, 12))

		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 14)
		card.add_child(row)

		row.add_child(_spell_medallion(spell, 56, selected))

		var info := VBoxContainer.new()
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 4)
		row.add_child(info)

		var head := HBoxContainer.new()
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.alignment = BoxContainer.ALIGNMENT_CENTER
		head.add_theme_constant_override("separation", 8)
		info.add_child(head)

		var title := _label(head, spell["name"], 22, COL_RIBBON if (is_named and selected) else COL_INK)
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_child(_stamp_tag(opt["tag"], opt["tag_bg"]))

		var desc := _label(info, opt["desc"], 15, COL_INK_SOFT)
		desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		# 右側實體火漆印章
		if selected:
			row.add_child(_wax_seal("啟用"))
		else:
			var switch_lbl := _label(row, "切換 ▸", 16, COL_INK_SOFT)
			switch_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var overlay := Button.new()
		overlay.flat = true
		overlay.focus_mode = Control.FOCUS_NONE
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		overlay.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		overlay.add_theme_stylebox_override("hover", _bevel_box(Color(1, 0.9, 0.6, 0.14), COL_GOLD, Color.TRANSPARENT, 2, 0, 0, 0))
		overlay.pressed.connect(func() -> void:
			_player.knowledge.set_manual(recipe, opt_id)
			_refresh_all())
		card.add_child(overlay)
		_manual_cards.add_child(card)

	_manual_hint.text = "同配方可手動綁定普通組招、右頁快捷槽另外裝配秘術，互不干擾。"


func _rebuild_quick_slots() -> void:
	for child in _quick_slots_box.get_children():
		child.queue_free()
	for slot in 3:
		var equipped := _player.knowledge.shortcut_spell(slot)
		var active := slot == _active_quick_slot
		var has_spell := not equipped.is_empty()

		# 深紫寶石鑲座，與溫潤羊皮紙拉開遊戲級焦點對比
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", _bevel_box(
			COL_SOCKET_ACTIVE if active else COL_SOCKET,
			COL_GOLD_HI if active else (COL_GOLD if has_spell else COL_GOLD_DARK),
			Color("#110a1a"), 3 if active else 2, 0, 10, 8))

		var col := VBoxContainer.new()
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 5)
		card.add_child(col)

		var header := HBoxContainer.new()
		header.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_child(header)
		var slot_lbl := _label(header, "星槽 %s" % SLOT_ROMAN[slot], 14, COL_GOLD_HI if active else Color("#baa8cb"))
		slot_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sp := Control.new()
		sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(sp)
		if active and not has_spell:
			var mark := _label(header, "◆", 14, COL_GOLD_HI)
			mark.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var icon_center := CenterContainer.new()
		icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(icon_center)
		if has_spell:
			icon_center.add_child(_spell_medallion(equipped, 52, active))
		else:
			icon_center.add_child(_empty_rune_socket(52, active))

		var name_lbl := _label(col, equipped["name"] if has_spell else "空槽位", 17,
			COL_GOLD_HI if active else (Color("#f5ecdf") if has_spell else Color("#8a799e")))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var overlay := Button.new()
		overlay.flat = true
		overlay.focus_mode = Control.FOCUS_NONE
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		overlay.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		overlay.add_theme_stylebox_override("hover", _bevel_box(Color(1, 0.92, 0.65, 0.10), COL_GOLD_HI, Color.TRANSPARENT, 2, 0, 0, 0))
		overlay.pressed.connect(func() -> void:
			_active_quick_slot = slot
			_refresh_all())
		card.add_child(overlay)

		if has_spell:
			var corner := HBoxContainer.new()
			corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
			corner.alignment = BoxContainer.ALIGNMENT_END
			corner.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			var clear_btn := Button.new()
			clear_btn.text = "✕"
			clear_btn.focus_mode = Control.FOCUS_NONE
			clear_btn.custom_minimum_size = Vector2(24, 24)
			clear_btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			clear_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			clear_btn.add_theme_font_size_override("font_size", 12)
			clear_btn.add_theme_color_override("font_color", COL_GOLD_HI)
			clear_btn.add_theme_stylebox_override("normal", _bevel_box(COL_RIBBON_DARK, COL_GOLD_DARK, Color("#180810"), 1, 0))
			clear_btn.add_theme_stylebox_override("hover", _bevel_box(COL_RIBBON_HI, COL_GOLD_HI, Color("#180810"), 1, 0))
			clear_btn.pressed.connect(func() -> void:
				_player.knowledge.clear_shortcut(slot)
				_refresh_all())
			corner.add_child(clear_btn)
			card.add_child(corner)

		_quick_slots_box.add_child(card)


func _rebuild_spell_shelf() -> void:
	_shelf_title.text = "✦ 鑲嵌至 星槽 %s（點選已熟練法術裝備／卸下）" % SLOT_ROMAN[_active_quick_slot]
	for child in _spell_shelf.get_children():
		child.queue_free()

	if _spells.is_empty():
		var empty := PanelContainer.new()
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty.add_theme_stylebox_override("panel", _bevel_box(COL_PAGE_ALT, COL_PAGE_SHADE, COL_PAGE_SHADE, 2, 0, 12, 12))
		_label(empty, "尚無收錄法術 · 實戰使用法術或閱讀法術書即可登錄法典", 15, COL_INK_SOFT)
		_spell_shelf.add_child(empty)
		return

	var equipped_in_slot := _player.knowledge.shortcut_spell(_active_quick_slot)
	for spell: Dictionary in _spells:
		var spell_id: String = spell["id"]
		var progress: Dictionary = _player.knowledge.mastery_progress(spell_id)
		var mastered: bool = _player.knowledge.is_mastered(spell_id)
		var is_equipped: bool = not equipped_in_slot.is_empty() and str(equipped_in_slot.get("id", "")) == spell_id

		var tile := PanelContainer.new()
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.add_theme_stylebox_override("panel", _bevel_box(
			COL_SOCKET_ACTIVE if is_equipped else (COL_PAGE_CREAM if mastered else COL_PAGE_ALT),
			COL_GOLD_HI if is_equipped else (COL_GOLD_DARK if mastered else COL_PAGE_SHADE),
			COL_LEATHER_DARK if is_equipped else COL_PAGE_SHADE,
			2, 0, 10, 8))

		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 10)
		tile.add_child(row)

		row.add_child(_spell_medallion(spell, 40, is_equipped, not mastered))

		var info := VBoxContainer.new()
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 2)
		row.add_child(info)

		var name_lbl := _label(info, spell["name"], 17,
			COL_GOLD_HI if is_equipped else (COL_INK if mastered else COL_INK_FAINT))
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var pip_row := HBoxContainer.new()
		pip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip_row.add_theme_constant_override("separation", 6)
		info.add_child(pip_row)
		var cur: int = mini(int(progress["current"]), int(progress["required"]))
		var req: int = int(progress["required"])
		var stars := ""
		for k in req:
			stars += "★" if k < cur else "☆"
		var star_lbl := _label(pip_row, stars, 14,
			COL_GOLD_HI if is_equipped else (Color("#c78a22") if mastered else COL_INK_FAINT))
		star_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var status_txt := "已鑲嵌" if is_equipped else ("已熟練" if mastered else "%d/%d" % [cur, req])
		var st_lbl := _label(pip_row, status_txt, 13,
			Color("#f5dca0") if is_equipped else (COL_RIBBON if mastered else COL_INK_FAINT))
		st_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

		if mastered:
			var overlay := Button.new()
			overlay.flat = true
			overlay.focus_mode = Control.FOCUS_NONE
			overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			overlay.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			overlay.add_theme_stylebox_override("hover", _bevel_box(Color(1, 0.9, 0.6, 0.14), COL_GOLD, Color.TRANSPARENT, 2, 0, 0, 0))
			overlay.pressed.connect(func() -> void:
				if is_equipped:
					_player.knowledge.clear_shortcut(_active_quick_slot)
				else:
					_set_shortcut(_active_quick_slot, spell)
				_refresh_all())
			tile.add_child(overlay)

		_spell_shelf.add_child(tile)


func _style_preset_pills() -> void:
	for i in _preset_buttons.size():
		var pill := _preset_buttons[i]
		var on := is_equal_approx(_player.shield_hold_seconds, HOLD_PRESETS[i])
		pill.add_theme_color_override("font_color", COL_INK if on else Color("#d2c4dc"))
		pill.add_theme_color_override("font_hover_color", COL_INK if on else COL_GOLD_HI)
		pill.add_theme_stylebox_override("normal", _bevel_box(
			COL_GOLD if on else COL_SOCKET,
			COL_GOLD_HI if on else COL_GOLD_DARK,
			COL_GOLD_DARK if on else Color("#120b1b"), 2, 0, 6, 2))
		pill.add_theme_stylebox_override("hover", _bevel_box(
			COL_GOLD_HI if on else COL_SOCKET_ACTIVE, COL_GOLD_HI, COL_GOLD_DARK, 2, 0, 6, 2))
		pill.add_theme_stylebox_override("pressed", _bevel_box(COL_GOLD, COL_GOLD_HI, COL_GOLD_DARK, 2, 0, 6, 2))


# ---------- 實體古書外殼、羊皮紙頁、火漆印章與星槽繪製 ----------

func _draw_backdrop() -> void:
	var sz := _backdrop.size
	_backdrop.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.035, 0.024, 0.06, 0.78))
	for i in 22:
		var phase := fposmod(_anim_t * (0.07 + float(i % 4) * 0.022) + float(i) * 0.167, 1.0)
		var x := fposmod(sin(float(i) * 21.3) * 437.5, 1.0) * sz.x
		var y := sz.y * (1.0 - phase)
		var alpha := sin(phase * PI) * 0.42
		var col := Color(0.98, 0.85, 0.52, alpha) if i % 2 == 0 else Color(0.78, 0.52, 1.0, alpha)
		_backdrop.draw_rect(Rect2(Vector2(snappedf(x, 2.0), snappedf(y, 2.0)), Vector2(4, 4)), col)


func _draw_grimoire_book(c: Control) -> void:
	var r := Rect2(Vector2.ZERO, c.size)
	# 1. 底部柔和書影
	c.draw_rect(Rect2(r.position + Vector2(10, 14), r.size), Color(0.02, 0.01, 0.04, 0.62))

	# 2. 垂墜酒紅金流蘇書籤帶（從書脊下方露出來，一眼認出是實體書！）
	if not _settings_only:
		var rx := r.size.x * 0.5 - 14.0
		var ry := r.size.y - 8.0
		var tail := PackedVector2Array([
			Vector2(rx, ry), Vector2(rx + 28, ry), Vector2(rx + 28, ry + 42),
			Vector2(rx + 14, ry + 30), Vector2(rx, ry + 42)])
		c.draw_colored_polygon(tail, COL_RIBBON)
		c.draw_polyline(tail, COL_GOLD, 2.0)

	# 3. 紫紅精裝厚皮書封（最外層）
	_draw_pixel_frame(c, r, COL_LEATHER, COL_GOLD_DARK, COL_LEATHER_HI, COL_LEATHER_DARK)

	# 4. 左右與底部露出的厚疊紙頁層（像素條紋表現書頁厚度）
	var pages_rect := Rect2(r.position + Vector2(18, 12), r.size - Vector2(36, 26))
	c.draw_rect(Rect2(pages_rect.position + Vector2(-6, 4), pages_rect.size + Vector2(12, 6)), COL_PAGE_SHADE)
	c.draw_rect(Rect2(pages_rect.position + Vector2(-3, 2), pages_rect.size + Vector2(6, 3)), COL_PAGE_ALT)

	# 5. 溫潤羊皮紙內頁（設定模式用單頁古紙捲軸，工坊用左右雙頁）
	c.draw_rect(pages_rect, COL_PAGE)
	# 紙頁邊緣做舊框線
	c.draw_rect(pages_rect, COL_PAGE_SHADE, false, 3.0)
	c.draw_rect(pages_rect.grow(-8.0), Color(COL_GOLD_DARK.r, COL_GOLD_DARK.g, COL_GOLD_DARK.b, 0.35), false, 1.0)
	# 細緻紙紋像素點
	for i in 36:
		var px := pages_rect.position.x + fposmod(sin(float(i) * 37.1) * 913.0, 1.0) * pages_rect.size.x
		var py := pages_rect.position.y + fposmod(cos(float(i) * 19.7) * 731.0, 1.0) * pages_rect.size.y
		c.draw_rect(Rect2(Vector2(snappedf(px, 2.0), snappedf(py, 2.0)), Vector2(4, 4)), Color(0.70, 0.58, 0.40, 0.22))

	# 6. 雙頁中央書脊折痕陰影與鍛金裝訂扣
	if not _settings_only:
		var mid := r.size.x * 0.5
		for step in 5:
			var w := float(36 - step * 6)
			var a := 0.08 + float(step) * 0.055
			c.draw_rect(Rect2(mid - w * 0.5, pages_rect.position.y, w, pages_rect.size.y), Color(0.26, 0.16, 0.12, a))
		c.draw_line(Vector2(mid, pages_rect.position.y), Vector2(mid, pages_rect.end.y), Color(0.24, 0.14, 0.12, 0.55), 2.0)
		# 書脊頂底鍛金扣環
		for by: float in [pages_rect.position.y - 4.0, pages_rect.end.y - 10.0]:
			_draw_pixel_frame(c, Rect2(mid - 16, by, 32, 14), COL_GOLD, COL_GOLD_DARK, COL_GOLD_HI, COL_GOLD_DARK)

	# 7. 四個精雕古金護角（L 型黃銅金屬護角＋圓鉚釘）
	_draw_brass_corner(c, r.position, Vector2(1, 1))
	_draw_brass_corner(c, Vector2(r.end.x, r.position.y), Vector2(-1, 1))
	_draw_brass_corner(c, Vector2(r.position.x, r.end.y), Vector2(1, -1))
	_draw_brass_corner(c, r.end, Vector2(-1, -1))


func _draw_brass_corner(c: Control, origin: Vector2, dir: Vector2) -> void:
	var arm_h := Rect2(origin, Vector2(dir.x * 38.0, dir.y * 12.0)).abs()
	var arm_v := Rect2(origin, Vector2(dir.x * 12.0, dir.y * 38.0)).abs()
	c.draw_rect(arm_h, COL_GOLD)
	c.draw_rect(arm_v, COL_GOLD)
	c.draw_rect(arm_h, COL_GOLD_DARK, false, 2.0)
	c.draw_rect(arm_v, COL_GOLD_DARK, false, 2.0)
	var hi := Rect2(origin + dir * 2.0, Vector2(dir.x * 8.0, dir.y * 8.0)).abs()
	c.draw_rect(hi, COL_GOLD_HI)
	c.draw_circle(origin + Vector2(dir.x * 26.0, dir.y * 6.0), 2.5, COL_GOLD_HI)
	c.draw_circle(origin + Vector2(dir.x * 6.0, dir.y * 26.0), 2.5, COL_GOLD_HI)


func _draw_pixel_frame(c: Control, r: Rect2, fill: Color, border: Color, hi: Color, lo: Color) -> void:
	c.draw_rect(r, fill)
	c.draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, 3)), hi)
	c.draw_rect(Rect2(r.position + Vector2(2, r.size.y - 5), Vector2(r.size.x - 4, 3)), lo)
	c.draw_rect(r, border, false, 3.0)


func _element_gem(element: int, px: int) -> Control:
	var col := Elements.color(element)
	var is_base := Elements.is_base(element)
	return _make_icon_canvas(Vector2(px, px), func(c: Control) -> void:
		var m := c.size * 0.5
		if is_base:
			c.draw_circle(m, px * 0.48, COL_SOCKET)
			c.draw_arc(m, px * 0.45, 0, TAU, 24, COL_GOLD, 2.2, true)
			var tile := float(ELEMENT_ICONS.get_height())
			var src := Rect2(Vector2(Elements.ICON_ORDER.find(element) * tile, 0), Vector2(tile, tile))
			var icon_sz := Vector2.ONE * (px * 0.72)
			c.draw_texture_rect_region(ELEMENT_ICONS, Rect2((m - icon_sz * 0.5).round(), icon_sz.round()), src)
		else:
			var d := px * 0.48
			var poly := PackedVector2Array([m + Vector2(0, -d), m + Vector2(d, 0), m + Vector2(0, d), m + Vector2(-d, 0)])
			c.draw_colored_polygon(poly, col.darkened(0.28))
			c.draw_polyline(poly + PackedVector2Array([poly[0]]), COL_GOLD_HI, 2.2, true)
			var glyph := Elements.display_name(element).substr(0, 1)
			var f := ThemeDB.fallback_font
			var fsz := int(px * 0.48)
			var ts := f.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz)
			c.draw_string_outline(f, m + Vector2(-ts.x * 0.5, ts.y * 0.30), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, 4, Color(0.08, 0.05, 0.12, 0.95))
			c.draw_string(f, m + Vector2(-ts.x * 0.5, ts.y * 0.30), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, Color.WHITE)
	)


func _spell_medallion(spell: Dictionary, px: int, active: bool, dimmed: bool = false) -> Control:
	var dominant: int = spell["dominant"]
	var is_rain: bool = spell.get("kind", "") == "rain"
	var is_named: bool = not str(spell.get("id", "")).begins_with(SpellRules.ORDINARY_PREFIX)
	var col := Elements.color(dominant)
	if dimmed:
		col = col.lerp(Color("#6b6278"), 0.55)
	return _make_icon_canvas(Vector2(px, px), func(c: Control) -> void:
		var m := c.size * 0.5
		var rad := px * 0.47
		# 實體鍛金八角徽章底座
		c.draw_circle(m + Vector2(0, 2), rad, Color(0.08, 0.04, 0.10, 0.45))
		c.draw_circle(m, rad, COL_SOCKET)
		c.draw_circle(m, rad - 4.0, col.darkened(0.32 if not active else 0.18))
		c.draw_arc(m, rad - 7.0, -PI * 0.85, -PI * 0.15, 14, Color(1, 1, 1, 0.25), 2.5, true)
		var rim := COL_GOLD_HI if (active or is_named) else COL_GOLD
		c.draw_arc(m, rad - 1.5, 0, TAU, 32, rim, 3.0 if active else 2.2, true)
		if is_rain:
			var cloud_col := Color("#e4f6ff") if not dimmed else Color("#9baab8")
			c.draw_circle(m + Vector2(-6, -3), px * 0.14, cloud_col)
			c.draw_circle(m + Vector2(4, -5), px * 0.16, cloud_col)
			c.draw_circle(m + Vector2(10, -1), px * 0.11, cloud_col)
			c.draw_rect(Rect2(m + Vector2(-9, -3), Vector2(21, px * 0.12)), cloud_col)
			for dx: float in [-7.0, 0.0, 7.0]:
				c.draw_line(m + Vector2(dx, 5), m + Vector2(dx - 2.5, 12), Color("#6fd4ff"), 2.4, true)
		elif Elements.is_base(dominant):
			var tile := float(ELEMENT_ICONS.get_height())
			var src := Rect2(Vector2(Elements.ICON_ORDER.find(dominant) * tile, 0), Vector2(tile, tile))
			var sz := Vector2.ONE * (px * 0.62)
			c.draw_texture_rect_region(ELEMENT_ICONS, Rect2((m - sz * 0.5).round(), sz.round()), src,
				Color(1, 1, 1, 0.62 if dimmed else 1.0))
		else:
			var d := px * 0.24
			var star := PackedVector2Array([m + Vector2(0, -d), m + Vector2(d * 0.72, 0), m + Vector2(0, d), m + Vector2(-d * 0.72, 0)])
			c.draw_colored_polygon(star, col.lightened(0.35))
			c.draw_polyline(star + PackedVector2Array([star[0]]), Color.WHITE * Color(1, 1, 1, 0.85), 1.8, true)
	)


func _empty_rune_socket(px: int, active: bool) -> Control:
	return _make_icon_canvas(Vector2(px, px), func(c: Control) -> void:
		var m := c.size * 0.5
		var rad := px * 0.44
		c.draw_circle(m, rad, Color("#150e20"))
		c.draw_arc(m, rad - 1.5, 0, TAU, 28, COL_GOLD_HI if active else COL_GOLD_DARK, 2.2, true)
		var d := px * 0.19
		var pts := PackedVector2Array([m + Vector2(0, -d), m + Vector2(d, 0), m + Vector2(0, d), m + Vector2(-d, 0), m + Vector2(0, -d)])
		c.draw_polyline(pts, COL_GOLD if active else Color("#5e4d73"), 2.0, true)
	)


func _wax_seal(text: String) -> Control:
	return _make_icon_canvas(Vector2(56, 56), func(c: Control) -> void:
		var m := c.size * 0.5
		c.draw_circle(m + Vector2(1, 3), 24.0, Color(0.18, 0.06, 0.08, 0.35))
		c.draw_circle(m, 24.0, COL_RIBBON_DARK)
		c.draw_circle(m, 21.0, COL_RIBBON)
		c.draw_arc(m, 17.0, 0, TAU, 24, COL_GOLD_HI, 1.8, true)
		var f := ThemeDB.fallback_font
		var ts := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		c.draw_string(f, m + Vector2(-ts.x * 0.5, ts.y * 0.30), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COL_GOLD_HI)
	)


func _make_gem_grabber() -> ImageTexture:
	var sz := 24
	var img := Image.create_empty(sz, sz, false, Image.FORMAT_RGBA8)
	var half := sz * 0.5 - 0.5
	for y in sz:
		for x in sz:
			var dist := absf(float(x) - half) + absf(float(y) - half)
			if dist <= 10.5:
				var col := Color("#d4f7ff") if dist <= 4.0 else (Color("#58b6ec") if dist <= 7.0 else (COL_GOLD_HI if dist <= 9.0 else COL_GOLD_DARK))
				img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


# ---------- 工具函式 ----------

func _preferred_recipe_index() -> int:
	for idx in _recipes.size():
		var recipe: Array[int] = []
		recipe.assign(_recipes[idx])
		if _recipe_has_named(recipe):
			return idx
	return 0


func _recipe_has_named(recipe: Array[int]) -> bool:
	for id: String in _player.knowledge.catalog:
		if _player.knowledge.is_unlocked(id) and not SpellRules.resolve(recipe, id, _player.knowledge.catalog).is_empty():
			return true
	return false


func _add_recipe(recipe: Array) -> void:
	var typed: Array[int] = []
	typed.assign(recipe)
	var key := SpellRules.recipe_key(typed)
	for existing: Array in _recipes:
		var other: Array[int] = []
		other.assign(existing)
		if SpellRules.recipe_key(other) == key:
			return
	_recipes.append(typed)


func _set_shortcut(slot: int, spell: Dictionary) -> void:
	if spell.is_empty():
		_player.knowledge.clear_shortcut(slot)
	else:
		var recipe: Array[int] = []
		recipe.assign(spell["elements"])
		_player.knowledge.equip_shortcut(slot, recipe, "" if spell["id"].begins_with("ordinary:") else spell["id"])


func _recipe_label(recipe: Array) -> String:
	var names := PackedStringArray()
	for element: int in recipe:
		names.append(Elements.display_name(element))
	return " ＋ ".join(names)


func _spell_desc(spell: Dictionary, is_named: bool) -> String:
	if spell.get("kind") == "rain":
		return "召喚露天降雨，使目標漸濕並熄滅燃燒。"
	if is_named:
		return "已解鎖的具名秘術，保留專屬形態與效果。"
	var dom: int = spell["dominant"]
	match dom:
		Elements.Type.MIST:
			return "保留普通組合形態，展開局部水霧遮蔽視線。"
		Elements.Type.WATER, Elements.Type.ICE, Elements.Type.STEAM:
			return "向前方展開元素扇面衝擊，觸發元素反應。"
		Elements.Type.LIGHTNING, Elements.Type.ARCANE, Elements.Type.PLASMA, Elements.Type.LIGHT:
			return "直線能量貫穿與連鎖，可觸發折射或導電。"
		Elements.Type.LIFE:
			return "展開自身治療脈衝，回復生命值。"
		_:
			return "以目前元素成分組招，觸發普通元素反應。"


func _page_heading(parent: VBoxContainer, title: String, subtitle: String, badge_bg: Color) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	_label(row, "✦", 18, COL_RIBBON)
	_label(row, title, 24, COL_INK)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	row.add_child(_stamp_tag(subtitle, badge_bg))


func _ink_divider(parent: VBoxContainer) -> void:
	var d := Control.new()
	d.custom_minimum_size.y = 8
	d.draw.connect(func() -> void:
		var y := 4.0
		var mid := d.size.x * 0.5
		d.draw_line(Vector2(0, y), Vector2(mid - 14, y), Color(COL_INK_FAINT.r, COL_INK_FAINT.g, COL_INK_FAINT.b, 0.45), 1.5)
		d.draw_line(Vector2(mid + 14, y), Vector2(d.size.x, y), Color(COL_INK_FAINT.r, COL_INK_FAINT.g, COL_INK_FAINT.b, 0.45), 1.5)
		var pts := PackedVector2Array([Vector2(mid, 0), Vector2(mid + 6, y), Vector2(mid, 8), Vector2(mid - 6, y)])
		d.draw_colored_polygon(pts, COL_GOLD_DARK)
	)
	parent.add_child(d)


func _stamp_tag(text: String, bg: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", _bevel_box(bg, COL_GOLD, bg.darkened(0.45), 2, 0, 8, 2))
	var l := _label(p, text, 13, COL_GOLD_HI)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _make_icon_canvas(min_size: Vector2, draw_cb: Callable) -> Control:
	var c := Control.new()
	c.custom_minimum_size = min_size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	c.draw.connect(draw_cb.bind(c))
	return c


## 像素硬邊立體斜角框（零圓角網頁卡片味！用上亮下暗厚度邊營造 RPG 實體按鈕／牌匾感）
func _bevel_box(bg: Color, border: Color, shadow_col: Color, border_w: int, shadow_px: int, pad_x: int = 0, pad_y: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.border_width_bottom = border_w + shadow_px
	s.set_corner_radius_all(2)
	s.shadow_color = Color(shadow_col.r, shadow_col.g, shadow_col.b, 0.35 if shadow_px > 0 else 0.0)
	s.shadow_size = shadow_px
	s.shadow_offset = Vector2(0, shadow_px)
	s.content_margin_left = pad_x
	s.content_margin_right = pad_x
	s.content_margin_top = pad_y
	s.content_margin_bottom = pad_y
	return s


func _label(parent: Node, text: String, size: int, color: Color = COL_INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label
