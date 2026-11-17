extends Node3D
## 讓雲影方塊往 +X 慢慢飄，飄出邊界就從另一邊回來。

@export var speed := 1.4
@export var half_width := 120.0


func _process(delta: float) -> void:
	for c in get_children():
		var n := c as Node3D
		n.position.x += speed * delta
		if n.position.x > half_width:
			n.position.x -= half_width * 2.0
