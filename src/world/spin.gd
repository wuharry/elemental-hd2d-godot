extends Node3D
## 繞自己的 Y 軸慢慢轉（齒輪用）。

@export var speed := 0.4


func _process(delta: float) -> void:
	rotate_object_local(Vector3.UP, speed * delta)
