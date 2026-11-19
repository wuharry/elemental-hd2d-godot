class_name WeaponVisual
extends Resource
## 可替換的手持外觀。座標以貼圖左上角為原點，單位是原生像素。
## 握點不依賴貼圖尺寸，法杖與魔導書都能接到同一隻手。

@export var texture: Texture2D
@export var grip_pixel := Vector2.ZERO
@export var light_pixel := Vector2.ZERO
@export var light_color := Color("#ffb969")
@export_range(0.0, 8.0) var light_energy := 0.0
@export_range(0.0, 8.0) var light_pulse := 0.0
@export_range(0.0, 20.0) var light_range := 3.2
