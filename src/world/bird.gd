extends Node3D
## 一隻方塊小鳥：沿著大橢圓繞村莊飛，翅膀上下拍。會在地上投下移動的影子。

var _center := Vector3.ZERO
var _rx := 20.0
var _rz := 12.0
var _speed := 0.3
var _phase := 0.0
var _height := 8.0
var _t := 0.0
var _left: Node3D
var _right: Node3D


## orbit：繞圈半徑的縮放（室內場景用小於 1，才不會飛出牆外）。
func setup(index: int, height: Vector2 = Vector2(6.5, 9.5), tint: Color = Color("#3a3440"), orbit: float = 1.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 500 + index * 91
	_center = Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-8, 2))
	_rx = rng.randf_range(16, 28) * orbit
	_rz = rng.randf_range(9, 16) * orbit
	_center *= orbit
	_speed = rng.randf_range(0.22, 0.34) * (1.0 if index % 2 == 0 else -1.0)
	_phase = rng.randf() * TAU
	_height = rng.randf_range(height.x, height.y)
	_t = rng.randf() * 10.0
	var body := Mats.flat(tint)
	var belly := Mats.flat(Color("#e9e2d2"))
	Build.box(self, Vector3(0.16, 0.14, 0.4), Vector3.ZERO, body)
	Build.box(self, Vector3(0.12, 0.06, 0.28), Vector3(0, -0.07, 0.02), belly)
	Build.box(self, Vector3(0.06, 0.05, 0.1), Vector3(0, 0.0, 0.24), Mats.flat(Color("#e8a23a")))
	_left = _wing(body, -1.0)
	_right = _wing(body, 1.0)


func _wing(mat: Material, side: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(0.08 * side, 0.04, 0)
	add_child(pivot)
	Build.box(pivot, Vector3(0.36, 0.03, 0.22), Vector3(0.18 * side, 0, 0), mat)
	return pivot


func _process(delta: float) -> void:
	_t += delta
	var a := _phase + _t * _speed
	var pos := _center + Vector3(cos(a) * _rx, _height + sin(_t * 0.7) * 0.6, sin(a) * _rz)
	var ahead := _center + Vector3(cos(a + 0.05 * signf(_speed)) * _rx, pos.y, sin(a + 0.05 * signf(_speed)) * _rz)
	position = pos
	var dir := ahead - pos
	rotation.y = atan2(dir.x, dir.z)
	var flap := sin(_t * 13.0) * 0.75
	_left.rotation.z = -flap
	_right.rotation.z = flap
