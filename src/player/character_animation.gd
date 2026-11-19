extends RefCounted
## 圖集欄位與手持武器的原生像素位移，供產生器與遊戲播放共用。

const IDLE_FRAMES := 4
const WALK_FRAMES := 6
const WALK_START := IDLE_FRAMES
const COLUMNS := IDLE_FRAMES + WALK_FRAMES
const ROWS := 3
const BLINK_FRAME := 3
const IDLE_CYCLE := [0, 1, 2, 1]

# 0–2 是呼吸，3 是眨眼；4–9 是接地、蹬地、騰空各兩次。
# 武器與掌心使用同一個位移。走路時比軀幹晚一格到達最高點。
const STAFF_OFFSETS := [
	Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, -1), Vector2i(0, 0),
	Vector2i(-1, -2), Vector2i(0, 0), Vector2i(1, -1),
	Vector2i(1, -2), Vector2i(0, 0), Vector2i(-1, -1),
]


static func staff_offset(column: int) -> Vector2i:
	return STAFF_OFFSETS[column]
