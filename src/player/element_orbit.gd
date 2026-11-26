extends Node3D
## 光點順序與施法佇列相同；奧術保留紫紅漸層，空佇列會停止更新。

const MOTE := preload("res://assets/characters/orb.png")
const ARCANE_MOTE := preload("res://assets/characters/orb_arcane.png")
const RADIUS := 0.94
const HEIGHT := 0.72
const SPEED := TAU / 3.6

var _motes: Array[Sprite3D] = []
var _count := 0
var _angle := 0.0


func _init(queue: ElementQueue) -> void:
	name = "ElementOrbit"
	for i in ElementQueue.CAPACITY:
		var dot := Sprite3D.new()
		dot.texture = MOTE
		dot.pixel_size = 1.0 / 32.0
		dot.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		dot.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		dot.shaded = false
		dot.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(dot)
		_motes.append(dot)
	queue.changed.connect(_sync)
	_sync(queue.slots)


func _sync(slots: Array[int]) -> void:
	_count = slots.size()
	for i in _motes.size():
		var dot := _motes[i]
		dot.visible = i < _count
		if dot.visible:
			var arcane := slots[i] == Elements.Type.ARCANE
			dot.texture = ARCANE_MOTE if arcane else MOTE
			dot.modulate = Color.WHITE if arcane else Elements.color(slots[i])
	set_process(_count > 0)
	_place_motes()


func _process(delta: float) -> void:
	_angle = fmod(_angle + delta * SPEED, TAU)
	_place_motes()


func _place_motes() -> void:
	for i in _count:
		var angle := _angle + TAU * i / _count
		_motes[i].position = Vector3(RADIUS * cos(angle), HEIGHT, RADIUS * sin(angle))
