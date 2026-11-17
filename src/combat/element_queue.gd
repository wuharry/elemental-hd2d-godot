class_name ElementQueue
extends RefCounted
## 四格施法佇列。限制的是「目前占用幾格」，不是「最多按幾次」：
## 融合把兩格變一格後，就能再加元素。

signal changed(slots: Array[int])

const CAPACITY := 4

var slots: Array[int] = []


func is_empty() -> bool:
	return slots.is_empty()


func is_full() -> bool:
	return slots.size() >= CAPACITY


## 加入一個元素；滿了回傳 false。同一種元素可以重複加。
func add(element: int) -> bool:
	if is_full():
		return false
	slots.append(element)
	changed.emit(slots)
	return true


## DRAFT：融合固定取最後兩格（Gemini 建議，Harvey 尚未拍板；要改成任選兩格只動這兩個函式）。
func can_fuse() -> bool:
	if slots.size() < 2:
		return false
	return Elements.fuse(slots[-2], slots[-1]) != -1


func fuse_last_two() -> bool:
	if not can_fuse():
		return false
	var fused := Elements.fuse(slots[-2], slots[-1])
	slots.resize(slots.size() - 2)
	slots.append(fused)
	changed.emit(slots)
	return true


## 取走整個佇列（施法用）。
func take_all() -> Array[int]:
	var out := slots.duplicate()
	slots.clear()
	changed.emit(slots)
	return out


func clear() -> void:
	if slots.is_empty():
		return
	slots.clear()
	changed.emit(slots)
