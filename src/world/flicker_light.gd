extends OmniLight3D
## 營火的光：亮度隨時間抖動，看起來像火在燒。

@export var base_energy := 3.0
@export var flicker := 0.28

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	var n := sin(_t * 11.0) * 0.5 + sin(_t * 17.3 + 1.7) * 0.3 + sin(_t * 29.1 + 0.4) * 0.2
	light_energy = base_energy * (1.0 + n * flicker)
