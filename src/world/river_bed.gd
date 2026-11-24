extends RefCounted
## 自然河床只在場景 ready 時組裝一次；沿用地面一公尺空洞格，再合併同深度區段。

const DEPTHS := [0.3, 0.6, 1.0]
const BASE_DEPTH := 1.2


static func build(parent: Node3D, rect: Rect2, level: float) -> void:
	var world := parent.get_parent()
	while world != null and not world is GameWorld:
		world = world.get_parent()
	if world == null:
		return
	var def: SceneDef = world.def
	var wet: Dictionary[Vector2i, bool] = {}
	var left := floori(rect.position.x)
	var right := ceili(rect.end.x)
	var back := floori(rect.position.y)
	var front := ceili(rect.end.y)
	for z in range(back, front):
		for x in range(left, right):
			var local := Vector3(x + 0.5, level, z + 0.5)
			var p: Vector3 = world.to_local(parent.to_global(local))
			if rect.has_point(Vector2(local.x, local.z)) and def.is_void(Vector2(p.x, p.z)):
				wet[Vector2i(x, z)] = true
	var bands: Dictionary[Vector2i, int] = {}
	for cell: Vector2i in wet:
		var band := 2
		for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if not wet.has(cell + offset):
				band = 0
				break
		if band == 2:
			for offset: Vector2i in [Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(1, 1)]:
				if not wet.has(cell + offset):
					band = 1
					break
		bands[cell] = band
	var materials := [
		Mats.tri("dirt", Color("#c4c5ac"), 0.98),
		Mats.tri("dirt", Color("#b0b5a5"), 0.98),
		Mats.tri("dirt", Color("#a0aa9c"), 0.98),
	]
	# key = [起點X, 終點X, 深度層]；相同橫段沿Z延伸，避免每格一個 draw primitive。
	var open: Dictionary[Vector3i, int] = {}
	for z in range(back, front + 1):
		var runs: Array[Vector3i] = []
		if z < front:
			var start := left
			var previous := -1
			for x in range(left, right + 1):
				var band: int = bands.get(Vector2i(x, z), -1) if x < right else -1
				if band != previous:
					if previous >= 0:
						runs.append(Vector3i(start, x, previous))
					start = x
					previous = band
		for key: Vector3i in open.keys():
			if not runs.has(key):
				var area := Rect2(key.x, open[key], key.y - key.x, z - open[key])
				var c := area.get_center()
				var depth: float = DEPTHS[key.z]
				var height := BASE_DEPTH - depth
				var mesh := Build.box(parent, Vector3(area.size.x, height, area.size.y),
					Vector3(c.x, level - depth - height * 0.5, c.y), materials[key.z])
				mesh.name = "RiverBed"
				open.erase(key)
		for run: Vector3i in runs:
			if not open.has(run):
				open[run] = z
