class_name TrainingProps
extends RefCounted
## 可重用的訓練場擺件；不含法術規則。


static func workshop() -> Node3D:
	var n := Node3D.new()
	n.name = "MageWorkbench"
	var wood := Mats.tri("planks", Color("#a17c56"))
	Build.box(n, Vector3(1.7, 0.16, 0.85), Vector3(0, 0.83, 0), wood)
	for x: float in [-0.65, 0.65]:
		for z: float in [-0.28, 0.28]:
			Build.box(n, Vector3(0.14, 0.8, 0.14), Vector3(x, 0.4, z), wood)
	Build.collider(n, Vector3(1.7, 0.9, 0.85), Vector3(0, 0.45, 0))
	var open_book := book()
	open_book.position = Vector3(-0.36, 0.91, 0)
	open_book.rotation_degrees.y = -12
	n.add_child(open_book)
	for i in 3:
		Build.box(n, Vector3(0.12, 0.18 + i * 0.06, 0.12), Vector3(0.25 + i * 0.22, 1.0, 0),
			Mats.altar_energy([Color("#7ad8eb"), Color("#c797e8"), Color("#ffbb68")][i], 1.2))
	return n


static func book() -> Node3D:
	var n := Node3D.new()
	n.name = "Spellbook"
	var cover := Mats.flat(Color("#385b87"))
	var paper := Mats.flat(Color("#ece2c7"))
	for side: int in [-1, 1]:
		Build.box(n, Vector3(0.29, 0.045, 0.40), Vector3(side * 0.145, 0, 0), cover, Vector3(0, 0, side * 8))
		Build.box(n, Vector3(0.25, 0.035, 0.35), Vector3(side * 0.14, 0.04, 0), paper, Vector3(0, 0, side * 8))
		for line in 3:
			Build.box(n, Vector3(0.15, 0.012, 0.018), Vector3(side * 0.14, 0.065, -0.09 + line * 0.07), cover)
	return n


static func lectern() -> Node3D:
	var n := Node3D.new()
	n.name = "RainLectern"
	var stone := Mats.tri("stone_wall", Color("#b1b7a5"))
	Build.box(n, Vector3(0.6, 0.16, 0.5), Vector3(0, 0.08, 0), stone)
	Build.box(n, Vector3(0.2, 0.7, 0.2), Vector3(0, 0.45, 0), stone)
	Build.box(n, Vector3(0.7, 0.08, 0.54), Vector3(0, 0.8, 0), stone)
	var spellbook := book()
	spellbook.position.y = 0.87
	n.add_child(spellbook)
	return n
