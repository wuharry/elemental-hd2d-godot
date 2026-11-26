# 角色美術 harness · B「極致 Q 版」

Harvey 選定 **B「極致 Q 版」** 作為本作主角造型。修改帽子、臉、身體或裝備時，先並看 B 原稿與 Godot 正面待機格。比較角色自身比例時，從帽冠到鞋底等高並排，保持長寬比。比較人物和建築時，用同一遊戲鏡頭與同一站位看全景。[B 原稿](../reference/characters/mage_variants/b_chibi.png) · [Godot 待機圖](../../assets/characters/mage_idle.png)

## Crusaders Quest 角色畫法

| 部位 | 這個專案採用的畫法 |
| --- | --- |
| 剪影 | 用戰鬥像素角色的三分之四側面作基礎。頭大、無明顯脖子、軀幹短。近眼比遠眼寬，深紅直眼、淡腮紅、下緣短平的方圓臉。 |
| 頭髮與帽子 | 黑色短鮑伯到下巴，厚瀏海分束，兩側髮尾內彎。深紫高尖帽向左折，酒紅帽帶配小金扣，近側帽簷壓住鬢髮，另一端向上翹。 |
| 袍身與裝備 | 深紫短袍、寬袖、酒紅領結與金邊。袍下留出分開的短靴。大型琥珀杖頭撐起左側剪影，杖身略向外傾，手指從前方包住杖柄；掌心上下都看得到木柄。 |
| 像素與色彩 | 每種材質用 2–3 階成塊的明暗，以相鄰材質的深色收邊。角色面向改變時，仍要讀得出帽、髮、袍與武器。沿用遊戲主角的 21 色盤，保留透明背景與硬邊。 |

這套設定用於角色。場景沿用 HD-2D 的景深、即時光與世界貼圖密度，見 [BLUEPRINT 第 2、3 節](../BLUEPRINT.md)。

## 生成 B 草稿

使用內建 ImageGen，開啟透明背景（`transparent_background: true`），依原始順序附上三張圖，再輸入下列完整原文。

1. [CQ 法師](../reference/characters/cq_mage_proportions.png) — 全身、帽簷角度、短身體與裝備份量。
2. [CQ 臉型](../reference/characters/cq_face_proportions.png) — 額頭、眼頰與下巴輪廓，近眼和遠眼的寬度。
3. [黑短鮑伯參考](../reference/characters/violet_mage_concept.png) — 只取黑色短髮、瀏海分束與臉側內彎髮尾。

```text
Make ONE full-body original playable female mage character design, isolated on true transparent background, generous margin around hat, feet and weapon. Treat images 1 and 2 as Crusaders Quest sprite style references; image 3 ONLY as reference for black chin-length bob haircut with thick layered bangs, ear visible and cheek locks curling inward. Style: cheerful refined 16-bit game sprite, strongly pixelated, square pixel clusters, discrete stepped edges, clean cel-color blocks, exactly 2-3 tones per material, no dithering, no grain, no painted gradients, no realism, no blurry miniature drawing. A large rounded-square face, offset vertical simple dark red pupils indicating 3/4 face to the right, near eye twice the width of far eye, light cheek blush, barely any mouth and no nose. Jet black bob, classic deep violet pointed wizard hat with substantial tall cocked crown; brim seats on skull, tilts upward at far right, near brim overlaps hair. Violet short bell-sleeve mage robe with burgundy ribbon and small restrained gold trim; simple clothing blocks; small visible boots and space between feet. Large magical staff with dark brown straight shaft and oversized angular gold-pronged amber crystal head. STAFF HOLD: upright beside the body on the viewer's LEFT, gently inclined away from the face. A bent near arm comes from shoulder down through sleeve to a clearly visible 3x3-pixel flesh-colored gripping fist at waist height. Fingers visibly wrap IN FRONT of the brown shaft. Brown shaft continues above AND below the fist, with a long lower end down to near the ground; keep a gap between shaft and robe. The other hand rests beside robe. Weapon must be ornate but simply drawn and unmistakably a staff. Keep face unobscured, clear skin-vs-hair edges. Compact readable palette no more than 22 substantive colors. No labels, text, ground, backdrops, shadows or UI. Proportion variant B: deliberately EXTREME CHIBI, about 1.7 HEADS TALL excluding hat: bare skull-to-chin is ONE unit, chin-to-soles only 0.7 units. Big round-cornered box-shaped head and short matchbox torso directly attached under chin, no visible neck, tiny 2x3-pixel legs separated by a narrow gap, simple two-cluster sleeve and fist. Facial eyes near 2x3 pixels and far 1x3 pixels, no drawn nose or mouth. Head and black bob dominate roughly 60% of anatomical height. Proportions like the first two small original CQ references, not the big-haired illustration. Clear waist, robe hem and feet even in this tiny body. Think approximately 48 by 56 source pixels enlarged with nearest-neighbor.
```

## Godot 轉製與驗收

提示詞中的約 1.7 頭身與 48×56 是生成草稿時的目標。遊戲圖集以 **56×48** 為一格，按正面、背面、側面排三列，每列四格待機、六格走路，朝左使用鏡像。B 版正面待機的去帽顱頂至下巴為 14 px，下巴至靴底為 13 px。戴帽的可見高度為 44 px。主角在世界內以腳底為基準呈現 1.20 倍，基準高為 1.65 公尺。

2026-11-19，Harvey 選定保留四方向並增為六格走路。呼吸約每 0.8 秒循環，眨眼獨立計時。跑步有接觸、抬腳與小跳步，兩隻靴子逐格留出間隙。帽尖、髮尾與衣襬有相對身體的延遲，持杖手跟著杖柄一起擺，杖光依實際姿勢定位。

活動時帽簷內襯必須持續覆住頭髮交界，肩袖與握手、袍內與靴口也必須接合；逐格檢查不能只看站姿。保留帽尖彎折、法杖叉口與雙靴之間的留白。

Harvey 另指定法杖獨立成物件，以便之後替換法杖或魔導書。遊戲以角色本體、武器、握持手三層呈現：本體與手各有 10×3 圖集，武器使用自己的貼圖與握點。預設外觀在 `assets/weapons/amber_staff.tres`，由 `WeaponVisual` 指定貼圖、握點及發光位置，`Player.equip_weapon()` 負責替換。手掌位於武器前方，袖口接回角色；鏡像與俯角補償需同步。完整待機參考 `mage_idle.png` 與此處 B 原始 prompt 繼續保留。

紙片保持直立，以腳底為原點垂直乘上 `1/cos(pitch)`。33° 時約為 1.192，補償後紙片高度約 1.97 公尺，水平像素仍為 1.20/32 公尺。用實際遊戲畫面核對臉型與頭身比例，並檢查遮擋、接地和陰影。角色補光使用 0.16，搭配部位法線與即時輪廓光；白天與夜間都需看圖確認黑髮、紫帽和琥珀晶面。

本體、握手與法杖的 `_n` 法線圖及 `_m` 材質遮罩由同一產生器輸出，不能改動原本 21 色的本體圖集。材質遮罩 RGBA 分別代表粗糙度、金屬度、輪廓權重與自發光；A 不是透明度，匯入時須關閉 Fix Alpha Border，並比對匯入後資料。看板在一般及陰影 pass 都使用主攝影機方向，避免角色投影隨光源轉面。

改圖集時編輯 [角色產生器](../../tools/gen_character.gd)，重新執行產生器與匯入。角色回歸會檢查色票、二頭身、四面向、杖柄接點與杖光位置；元素回歸會檢查角色身邊的光點。最後打開截圖，看正常鏡頭下的雙靴、杖頭、握持與人物相對門窗的大小。[村莊人物與門窗尺寸對照，右欄為現行倍率](../screenshots/mage_b_village_scale.png)

```sh
godot --headless --path . --script res://tools/gen_character.gd
godot --headless --path . --import
godot --headless --path . --script res://tests/player_animation_test.gd
godot --headless --path . --script res://tests/character_layers_test.gd
godot --headless --path . --script res://tests/element_orbit_test.gd
tools/capture.sh
```
