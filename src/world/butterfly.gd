extends Node3D
## 一隻蝴蝶：兩片像素翅膀拍動，在自己的花叢附近亂飛。

const RADIUS := 3.2
const SPEED := 1.1

var _home := Vector3.ZERO
var _target := Vector3.ZERO
var _t := 0.0
var _left: Node3D
var _right: Node3D
var _rng := RandomNumberGenerator.new()


func setup(home: Vector3, tint: Color, index: int) -> void:
	_home = home
	_rng.seed = 1000 + index * 37
	_t = _rng.randf() * 10.0
	position = home + Vector3(0, 0.8, 0)
	var mat := Mats.quad("wing", tint, true, true)
	_left = _wing(mat, -1.0)
	_right = _wing(mat, 1.0)
	Build.box(self, Vector3(0.04, 0.04, 0.2), Vector3.ZERO, Mats.flat(Color("#2a2028")))
	_pick()


func _wing(mat: Material, side: float) -> Node3D:
	var pivot := Node3D.new()
	add_child(pivot)
	var q := Build.quad(pivot, Vector2(0.25, 0.25), Vector3(0.125 * side, 0, 0), mat, Vector3(-90, 0, 0))
	if side > 0.0:
		q.rotation_degrees = Vector3(-90, 180, 0)
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return pivot


func _pick() -> void:
	var a := _rng.randf() * TAU
	var r := _rng.randf_range(0.6, RADIUS)
	_target = _home + Vector3(cos(a) * r, _rng.randf_range(0.5, 1.6), sin(a) * r)


func _process(delta: float) -> void:
	_t += delta
	var flap := sin(_t * 24.0) * 1.05
	_left.rotation.z = -flap
	_right.rotation.z = flap
	var to := _target - position
	if to.length() < 0.35:
		_pick()
		return
	var dir := to.normalized()
	position += dir * SPEED * delta
	position.y += sin(_t * 9.0) * 0.6 * delta
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), delta * 6.0)
