class_name Player
extends CharacterBody3D
## 玩家：2 頭身像素角色（BLUEPRINT A9）+ 移動 + 元素佇列。
## 移動方向由外部塞進 move_input（HUD 搖桿或鍵盤），這裡不直接讀觸控。

signal cast(elements: Array[int], origin: Vector3, direction: Vector3)
signal spell_cast(spell: Dictionary, origin: Vector3, direction: Vector3)
signal loadout_changed
signal notice(text: String)
signal casting_changed

const SPEED := 5.2
const CharacterAnimation := preload("res://src/player/character_animation.gd")
const WeaponAppearance := preload("res://src/player/weapon_visual.gd")
const HeldWeapon := preload("res://src/player/held_weapon.gd")
const DEFAULT_WEAPON := preload("res://assets/weapons/amber_staff.tres")
const CHAR_SHADER := preload("res://shaders/pixel_character.gdshader")
# B 版在世界中的顯示倍率。圖集與杖光共用同一個像素到公尺的換算。
const VISUAL_SCALE := 1.2
const PIXEL := VISUAL_SCALE / 32.0
# 紙片立在地面，垂直拉長 1/cos(pitch) 抵消俯角投影，保持原生像素的水平寬度。
const DEFAULT_CAMERA_PITCH_DEG := 33.0
const FRAME_SIZE := Vector2i(56, 48)
# 正面待機格的原生像素座標，以左上角為原點。
const FEET := Vector2(31.5, 47.0)
const GRIP := Vector2(20.5, 38.5)
const LAYER_DEPTH := 0.002
const BODY_OFFSET_X := FEET.x - FRAME_SIZE.x * 0.5
const ATLAS_COLUMNS := CharacterAnimation.COLUMNS
const ATLAS_ROWS := CharacterAnimation.ROWS
enum Facing { FRONT, BACK, SIDE }

@export_range(1.0, 30.0, 0.5) var walk_fps := 18.0
@export_range(1.0, 6.0, 0.1) var idle_period := 3.2
const BREATH_PERIOD := 0.8

var queue := ElementQueue.new()
var loadout := Elements.LOADOUT.duplicate()
var knowledge := SpellKnowledge.new()
var combat_state := CombatState.new()
var armed_shortcut := -1
var shield_hold_seconds := 1.5:
	set(value):
		shield_hold_seconds = clampf(value, 1.0, 3.0) if is_finite(value) else 1.5
var _element_holds: Dictionary = {}
var training_mode := false
var _revive_time := 0.0
## 搖桿輸入，x 右、y 下（螢幕方向），長度 0..1。
var move_input := Vector2.ZERO
## 右搖桿的螢幕方向；非零時瞄準優先於移動面向。
var aim_input := Vector2.ZERO
## 截圖驗收時可關閉鍵盤輸入，避免背景按鍵影響畫面方向。
var accept_keyboard := true
## 鏡頭水平朝向（弧度），由 main 每幀更新。
var camera_yaw := 0.0
## 目前面向／瞄準的世界方向（水平）。
var aim_dir := Vector3(0, 0, 1)
## 鏡頭俯角（度），由 main 依 CameraRig.pitch_deg 設定。
var camera_pitch_deg := DEFAULT_CAMERA_PITCH_DEG:
	set(value):
		var safe_pitch := clampf(value, -80.0, 80.0) if is_finite(value) else DEFAULT_CAMERA_PITCH_DEG
		if is_equal_approx(camera_pitch_deg, safe_pitch):
			return
		camera_pitch_deg = safe_pitch
		_apply_pitch_compensation()

var sprite: Sprite3D
var hand_sprite: Sprite3D
var weapon: HeldWeapon
var equipped_weapon: WeaponAppearance = DEFAULT_WEAPON
var _body_mat: ShaderMaterial
var _hand_mat: ShaderMaterial
## 舊測試與場景讀取用；光源的生命週期與設定由武器管理。
var staff_light: OmniLight3D:
	get:
		return weapon.emitter if weapon != null else null
var _t := 0.0
var _animation_time := 0.0
var _was_moving := false
var _face_left := false
var _stretch := 1.0


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.3
	shape.shape = capsule
	shape.position.y = 0.65
	add_child(shape)

	sprite = Sprite3D.new()
	sprite.texture = load("res://assets/characters/mage_atlas.png")
	sprite.hframes = ATLAS_COLUMNS
	sprite.vframes = ATLAS_ROWS
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.shaded = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.double_sided = true
	sprite.centered = true
	# 正面與右側身都為左邊的長杖留白，腳底仍對齊人物原點。
	sprite.offset = Vector2(-BODY_OFFSET_X, FEET.y - FRAME_SIZE.y * 0.5)
	# 角色放在第 2 層，讓杖光照亮她腳邊的地面。
	sprite.layers = 2
	_body_mat = _make_char_material(sprite.texture,
		load("res://assets/characters/mage_atlas_n.png"),
		load("res://assets/characters/mage_atlas_m.png"))
	sprite.material_override = _body_mat
	add_child(sprite)
	weapon = HeldWeapon.new()
	add_child(weapon)
	weapon.equip(equipped_weapon)
	hand_sprite = Sprite3D.new()
	hand_sprite.name = "GrippingHand"
	hand_sprite.texture = load("res://assets/characters/mage_hand_atlas.png")
	hand_sprite.hframes = ATLAS_COLUMNS
	hand_sprite.vframes = ATLAS_ROWS
	hand_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	hand_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	hand_sprite.shaded = true
	hand_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	hand_sprite.double_sided = true
	hand_sprite.layers = 2
	hand_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hand_mat = _make_char_material(hand_sprite.texture,
		load("res://assets/characters/mage_hand_atlas_n.png"),
		load("res://assets/characters/mage_hand_atlas_m.png"))
	hand_sprite.material_override = _hand_mat
	add_child(hand_sprite)
	_apply_pitch_compensation()

	# 只照角色的柔和補光（第 2 層）：降到 0.16，讓 3D 法線受光與輪廓光不被平面洗白。
	var fill := OmniLight3D.new()
	fill.light_color = Color("#fff1e0")
	fill.light_energy = 0.16
	fill.light_cull_mask = 2
	fill.omni_range = 4.0
	fill.omni_attenuation = 0.6
	fill.light_specular = 0.0
	fill.position = Vector3(0.6, 1.6, 2.0)
	add_child(fill)
	var orbit := preload("res://src/player/element_orbit.gd").new(queue)
	orbit.scale = Vector3.ONE * VISUAL_SCALE
	add_child(orbit)
	_refresh_sprite()


func _make_char_material(albedo: Texture2D, normal: Texture2D, material_map: Texture2D) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = CHAR_SHADER
	mat.set_shader_parameter("albedo_tex", albedo)
	mat.set_shader_parameter("normal_tex", normal)
	mat.set_shader_parameter("material_tex", material_map)
	mat.set_shader_parameter("rim_strength", 0.92)
	mat.set_shader_parameter("emission_strength", 0.0)
	return mat


func replace_element(slot: int, element: int) -> void:
	if slot < 0 or slot >= loadout.size() or not Elements.SELECTABLE.has(element) or loadout.has(element):
		return
	cancel_element_holds()
	loadout[slot] = element
	loadout_changed.emit()


func _physics_process(delta: float) -> void:
	_t += delta
	combat_state.tick(delta)
	if combat_state.health <= 0.0:
		cancel_element_holds()
		velocity = Vector3.ZERO
		if training_mode:
			_revive_time += delta
			if _revive_time >= 2.0:
				combat_state.reset()
				_revive_time = 0.0
				notice.emit("訓練恢復 · 生命已回滿")
		return
	_revive_time = 0.0
	_tick_element_holds(delta)
	var input := move_input
	if accept_keyboard:
		var kb := Vector2(
			float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
			float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
		if kb != Vector2.ZERO:
			input = kb.normalized()
	var dir := Vector3(input.x, 0, input.y).rotated(Vector3.UP, camera_yaw)
	var move_speed := SPEED
	if combat_state.has_status("frozen") or combat_state.has_status("rooted"):
		move_speed = 0.0
	elif combat_state.has_status("slow"):
		move_speed *= 0.5
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	velocity.y = 0.0 if is_on_floor() else velocity.y - 20.0 * delta
	move_and_slide()

	if aim_input.length() > 0.2:
		aim_dir = Vector3(aim_input.x, 0, aim_input.y).rotated(Vector3.UP, camera_yaw).normalized()
	elif input.length() > 0.1:
		aim_dir = dir.normalized()
	# 用實際位移決定踏步，推著牆時不會繼續原地走。
	var actual := get_position_delta()
	var horizontal_speed := Vector2(actual.x, actual.z).length() / maxf(delta, 0.0001)
	_update_animation(delta, horizontal_speed)


func _update_animation(delta: float, horizontal_speed: float) -> void:
	var moving := horizontal_speed > 0.1
	if moving != _was_moving:
		_animation_time = 0.0
		_was_moving = moving
	_animation_time += delta * (horizontal_speed / SPEED if moving else 1.0)
	_refresh_sprite()


func _refresh_sprite() -> void:
	var screen_dir := aim_dir.rotated(Vector3.UP, -camera_yaw)
	screen_dir.y = 0.0
	screen_dir = screen_dir.normalized()
	var facing := Facing.FRONT
	if absf(screen_dir.x) > absf(screen_dir.z):
		facing = Facing.SIDE
	elif screen_dir.z < 0.0:
		facing = Facing.BACK
	# 3/4 構圖：往畫面左方就整體鏡像，接近垂直時沿用上一次的左右，避免來回閃。
	if absf(screen_dir.x) > 0.12:
		_face_left = screen_dir.x < 0.0
	# 背面圖格本身已鏡像（右手杖轉身後在畫面右邊），所以三個面向用同一條規則。
	sprite.flip_h = _face_left
	var mirrored := sprite.flip_h != (facing == Facing.BACK)
	sprite.offset.x = BODY_OFFSET_X if mirrored else -BODY_OFFSET_X
	# 每個呼吸週期依序吸氣、回落，預設每四個週期在回到基準姿勢時眨眼。
	var breath_phase := int(fmod(_animation_time, BREATH_PERIOD) / BREATH_PERIOD
		* CharacterAnimation.IDLE_CYCLE.size())
	var column: int = CharacterAnimation.IDLE_CYCLE[breath_phase]
	if _animation_time >= idle_period and fmod(_animation_time, idle_period) < 0.12:
		column = CharacterAnimation.BLINK_FRAME
	if _was_moving:
		column = CharacterAnimation.WALK_START + int(_animation_time * walk_fps) % CharacterAnimation.WALK_FRAMES
	sprite.frame_coords = Vector2i(column, facing)
	var staff_offset := CharacterAnimation.staff_offset(column)
	hand_sprite.flip_h = sprite.flip_h
	hand_sprite.frame_coords = sprite.frame_coords
	hand_sprite.offset = sprite.offset
	# 沿鏡頭視線分開深度，避免同平面 z-fighting，也不把手掌往畫面上下推。
	var pitch := deg_to_rad(camera_pitch_deg)
	var camera_ray := Vector3(0.0, sin(pitch), cos(pitch)).rotated(Vector3.UP, camera_yaw)
	hand_sprite.position = camera_ray * LAYER_DEPTH * 2.0
	var flip_sign := -1.0 if sprite.flip_h else 1.0
	var bounce_dir := 0.82 if mirrored else -0.82
	var bounce_energy := 0.0
	var bounce_col := Color("#ffb969")
	if equipped_weapon != null and equipped_weapon.light_energy > 0.0:
		var pulse := maxf(0.0, equipped_weapon.light_energy + sin(_t * 3.0) * equipped_weapon.light_pulse)
		bounce_energy = clampf(pulse * 0.18, 0.0, 0.24)
		bounce_col = equipped_weapon.light_color
	var wet := 1.0 if combat_state.has_status("wet") else 0.0
	for mat: ShaderMaterial in [_body_mat, _hand_mat]:
		if mat != null:
			mat.set_shader_parameter("flip_sign", flip_sign)
			mat.set_shader_parameter("bounce_dir_x", bounce_dir)
			mat.set_shader_parameter("bounce_energy", bounce_energy)
			mat.set_shader_parameter("bounce_color", bounce_col)
			mat.set_shader_parameter("wet_amount", wet)
	var grip := GRIP + Vector2(staff_offset) - FEET
	grip.y = -grip.y
	weapon.pose(grip, mirrored, PIXEL, _stretch, camera_yaw, camera_ray * LAYER_DEPTH, _t)


func _apply_pitch_compensation() -> void:
	if sprite == null:
		return
	var c := cos(deg_to_rad(camera_pitch_deg))
	_stretch = 1.0 / c
	sprite.pixel_size = PIXEL
	sprite.scale = Vector3(1.0, _stretch, 1.0)
	if hand_sprite != null:
		hand_sprite.pixel_size = PIXEL
		hand_sprite.scale = sprite.scale
	if weapon != null and hand_sprite != null:
		_refresh_sprite()


## 換上另一支法杖或魔導書外觀；null 卸下武器，保留角色與手部動畫。
func equip_weapon(appearance: WeaponAppearance) -> void:
	equipped_weapon = appearance
	if weapon != null:
		weapon.equip(appearance)
		_refresh_sprite()


## 把目前佇列放出去（清空佇列）。direction 是水平世界方向。
func cast_queue(direction: Vector3) -> void:
	if combat_state.health <= 0.0:
		return
	var spell: Dictionary
	if armed_shortcut >= 0:
		spell = knowledge.shortcut_spell(armed_shortcut)
	else:
		spell = knowledge.manual_spell(queue.slots)
	if spell.is_empty():
		return
	if direction.length() > 0.01:
		aim_dir = direction.normalized()
	_refresh_sprite()
	if armed_shortcut < 0:
		queue.clear()
	armed_shortcut = -1
	casting_changed.emit()
	var origin := global_position + Vector3(0, 0.9, 0) + aim_dir * 0.5
	cast.emit(spell["elements"], origin, aim_dir)
	spell_cast.emit(spell, origin, aim_dir)
	notice.emit(spell["name"])


func arm_shortcut(slot: int) -> bool:
	if knowledge.shortcut_spell(slot).is_empty():
		notice.emit("在魔術師工坊裝備已熟練的法術")
		return false
	armed_shortcut = -1 if armed_shortcut == slot else slot
	casting_changed.emit()
	return true


func cancel_cast_selection() -> void:
	armed_shortcut = -1
	casting_changed.emit()


func has_prepared_spell() -> bool:
	return not queue.is_empty() or armed_shortcut >= 0


## 觸控與鍵盤共用長按計時；成功開盾的那次放開不能再加入元素。
func begin_element_hold(source: String, slot: int) -> bool:
	if combat_state.health <= 0.0 or slot < 0 or slot >= loadout.size() or _element_holds.has(source):
		return false
	for hold: Dictionary in _element_holds.values():
		if hold["slot"] == slot:
			return false
	_element_holds[source] = {"slot": slot, "element": loadout[slot], "elapsed": 0.0, "triggered": false}
	return true


func finish_element_hold(source: String, cancelled: bool = false) -> void:
	if not _element_holds.has(source):
		return
	var hold: Dictionary = _element_holds[source]
	_element_holds.erase(source)
	if cancelled or hold["triggered"] or loadout[hold["slot"]] != hold["element"]:
		return
	if not queue.add(hold["element"]):
		notice.emit("佇列已滿（四格）")


func cancel_element_holds() -> void:
	_element_holds.clear()


func hold_progress(slot: int) -> float:
	for hold: Dictionary in _element_holds.values():
		if hold["slot"] == slot:
			return minf(float(hold["elapsed"]) / shield_hold_seconds, 1.0)
	return 0.0


func _tick_element_holds(delta: float) -> void:
	for hold: Dictionary in _element_holds.values():
		hold["elapsed"] += delta
		if not hold["triggered"] and hold["elapsed"] >= shield_hold_seconds:
			hold["triggered"] = true
			if combat_state.activate_shield(hold["element"]):
				notice.emit("%s盾 · 可以放開繼續組招" % Elements.display_name(hold["element"]))


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		cancel_element_holds()
		move_input = Vector2.ZERO
		aim_input = Vector2.ZERO
