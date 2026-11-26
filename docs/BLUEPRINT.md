# 藍圖：元素組招 HD-2D（Godot 4.7）

給接手的 agent：這份是**不變的規則**（美術做法、架構、驗收方式）。目前做到哪、下一步做什麼，看 [HANDOFF.md](HANDOFF.md)。兩份衝突時，以這份為準並回報。

## 1. 目標與驗收

- 遊戲：手機橫向、斜俯視的元素組招動作冒險。規則來源是 [design/rules.md](design/rules.md)。
- 第一輪只驗收一件事：**開啟遊戲後的畫面，是否像參考圖那樣生動、細膩、有自己的 HD-2D 風格**。玩法只做到能走、能排元素、能融合、能放出一發法術。
- 參考圖放在 `docs/reference/`（Harvey 提供）。兩張圖各自要學的東西：

| 參考圖 | 要學的 | 不要學的 |
| --- | --- | --- |
| 村莊四時段（morning／day／dusk／night） | 窄視角 + 前後景都糊的景深、暖窗光對冷環境光、石牆與木牆的凹凸感、滿地花草 | 構圖照抄 |
| 體素營地（池塘、營火、方塊樹） | 方塊堆出來的樹與雲、池塘倒影、營火、Q 版角色比例 | 右側的編輯器面板 |

## 2. 美術硬規則（違反就是 bug）

| # | 規則 | 數值／做法 | 為什麼 |
| --- | --- | --- | --- |
| A1 | 世界像素密度與主角顯示倍率 | 世界貼圖固定 32 px／公尺（64 px 鋪 2 公尺，`Mats.TEXEL_SCALE = 0.5`）。B 主角以 1/32 公尺為原生像素單位，在世界內等比呈現 1.20 倍 | 讓主角在固定的建築比例下清晰可辨 |
| A2 | 貼圖一律 nearest | 世界用 `NEAREST_WITH_MIPMAPS`，角色與 UI 用 `NEAREST` | 糊掉的像素不是像素風 |
| A3 | 幾何只用方塊與三角柱 | `BoxMesh`、`PrismMesh`、交叉面片（花草）；可將這些原始幾何合併成 `ArrayMesh`，不改形狀；不用圓柱、球、平滑曲面 | 體素感來自方塊，圓滑幾何會出戲 |
| A4 | 貼圖不畫光影 | 貼圖只放固有色與 `_n` 法線圖；明暗全部交給即時光 | 四個時段共用同一套貼圖，畫死的陰影在夜晚會穿幫 |
| A5 | 貼圖不手改 | 改 `tools/gen_textures.gd`、`tools/gen_character.gd` 或 `tools/gen_element_icons.gd` 後重跑；PNG 是產物 | 可重現，也能一次調整全套色調 |
| A6 | 方塊貼圖走 triplanar | `Mats.tri()`（local triplanar），用 `BoxMesh.size` 定尺寸，**不要用 node scale**；合併時由 `Mats.batched_tri()` 與頂點自訂欄位保留原始座標、法線與切線 | scale 會把像素拉長，破壞 A1 |
| A7 | 光影數值只放一處 | 四時段、場景微調、四季與晴雨天氣的太陽、環境光、霧、窗光、路燈全部在 `src/world/time_of_day.gd` 的 `PRESETS` | 調色時不用滿專案找數字 |
| A8 | 暖冷對比 | 人造光（窗、路燈、營火）一律暖色；陰影與夜晚環境光偏冷 | 兩張參考圖的氛圍都靠這個 |
| A9 | 角色是 2 頭身像素圖片 | `Sprite3D` 搭配 `shaders/pixel_character.gdshader`（Y 軸看板、立體法線圖、即時 3D 輪廓光、alpha cutout 深度寫入），以腳底為原點垂直補償鏡頭俯角 `1/cos(pitch)`，保留原像素寬度 | 維持紙片直立與接地，讓像素角色融入真實 3D 光影 |
| A11 | Q 版世界比例 | 戴帽 B 主角基準高 1.65 公尺（44 原生像素 × 1.20 ÷ 32），33° 俯角下紙片補償高約 1.97 公尺。門高 1.5 公尺、一層樓 1.6 公尺、窗 0.75 公尺（24 px） | 用正常鏡頭同時看清主角和建築 |
| A10 | 場景要有會動的東西 | 風吹花草與樹、落葉、蝴蝶、鳥、煙囪煙、塵埃光點、雲影、夜晚螢火蟲 | 驗收條件明寫「生動」 |

## 3. 算繪設定

- Renderer：Forward+（體積霧、SSAO、SSIL、SSR 只有它有）。**手機是主要平台，Mobile renderer 沒有這幾項**；降級方案尚未做，列在 HANDOFF 的待辦。
- 鏡頭：`Camera3D` FOV 25°、俯角 33°、水平轉 22°、距離 30 公尺；`CameraAttributesPractical` 開近、遠兩段景深，對焦在角色前後約 4 公尺。數值是 `camera_rig.gd` 的 `@export`。
- 後製：ACES tonemap、glow、SSAO、SSIL、體積霧、少量色彩調整。數值在 `time_of_day.gd`。
- 水面：保留藍綠水色的半透明清水，依實際水底深度由 48% 至 82% 不透明度漸變；岸邊看得見淺灘，深處仍有水的厚度。池塘與河流使用真正下沉的水底，不能把貼近水面的泥地當成深水。
- 水面倒影由 `WaterSurface` 建立的局部 `ReflectionProbe` 提供。半透明水不依賴 SSR；探針只捕捉場景，排除角色紙片與水面自身，只影響水層。有效光影改變後重拍，相同光影沿用快取。倒影方向光使用單級陰影並跟隨主光，主鏡頭保持原有四級陰影。反射圖集上限 8，避免預留不必要的記憶體。這是局部近似倒影，不能宣稱等同逐幀平面鏡射或手機效能已驗收。

## 4. 架構

```text
main.tscn ── src/main.gd（組裝根：只負責把下面的東西接起來）
   ├─ Scenes.make(id) → SceneDef   src/world/scenes/*_scene.gd
   ├─ GameWorld      src/world/game_world.gd      依 SceneDef 組裝場景
   │    ├─ HouseBuilder / TreeBuilder / PropBuilder   純函式，回傳 Node3D
   │    ├─ GroundBuilder   地面 + 路徑遮罩（同一個距離函式也用來避開花草）
   │    ├─ FoliageField    花草 MultiMesh + 風 shader
   │    └─ AmbientLife     落葉、蝴蝶、鳥、煙、塵埃、螢火蟲、雲影
   │    完成組裝後由 MeshBatcher 合併可安全合併的靜態網格，保留碰撞與動態子樹
   ├─ TimeOfDay      src/world/time_of_day.gd      四個時段與過場
   ├─ Player         src/player/player.gd          移動、像素角色、元素佇列與周身光點
   ├─ CameraRig      src/player/camera_rig.gd      跟隨 + 景深對焦
   └─ Hud            src/ui/hud.gd                 元素配裝、雙搖桿、四元素圖示鍵、融合鍵
src/combat/elements.gd、element_queue.gd：純邏輯（RefCounted，不碰節點），可單獨測試
```

- 場景用程式組出來，不是手寫 `.tscn`。原因：agent 手寫 `.tscn` 容易把 `ext_resource`／UID 弄壞。要讓 Harvey 在編輯器調整的參數，用 `@export` 放在腳本上。
- 依賴方向只能往下：`main` → `world`／`player`／`ui` → `combat`。`combat` 不准認識任何節點。
- 新增物件的流程：在對應 Builder 加一個函式 → 在對應 `*_scene.gd` 的資料或 `populate()` 加一筆 → 跑截圖驗收。
- 場景清單在 `Scenes.LIST`，共用地形／路徑定義在 `SceneDef`。場景光影差異仍只放在 `TimeOfDay.PRESETS.scene_overrides`，不在場景檔各寫一套。
- 合併網格必須保留原始像素座標、材質、風動中心、陰影模式、碰撞和動畫。`--no-batching` 可拍原始網格作比較。樹冠遮擋使用 `foliage_reveal.gdshaderinc` 的像素格鏤空，不用半透明，且不改陰影輪廓。

## 5. 規則狀態（玩法）

HUD 圖示、融合鍵與祭壇配裝的畫面判準見 [元素 HUD 與祭壇操作 harness](harness/ELEMENT_HUD.md)。

- **已定**：從六種有獨立圖示的基礎元素中選四種出戰、四格佇列（限制的是目前占用格數）、可重複加入、融合後騰出格子、水＋火不自動融合、獨立融合鍵、左搖桿移動、右搖桿瞄準施放、長按元素開盾、三個快捷槽。
- **草案（Gemini 建議，Harvey 尚未拍板，程式裡標 `DRAFT`）**：融合固定取最後兩格、複合元素不可再融合、護盾長按後持續固定秒數、輕點右搖桿中心放副手、友傷比例。
- 草案要改時只改 `src/combat/`，不要讓 UI 或世界層寫死這些規則。

## 6. 指令

```bash
cd /Users/harvey/repo/elemental-hd2d-godot
godot --headless --path . --script res://tools/gen_textures.gd    # 重產世界貼圖
godot --headless --path . --script res://tools/gen_character.gd   # 重產角色
godot --headless --path . --script res://tools/gen_element_icons.gd # 重產六種元素圖示與環繞光點貼圖
godot --headless --path . --import                                # 讓引擎重新匯入（.import 由引擎產生，不手改）
godot --headless --path . --script res://tests/run_tests.gd       # 純邏輯測試
godot --headless --path . --script res://tests/hud_input_test.gd  # 操作路徑測試（載入真正的 main 場景送觸控事件）
godot --headless --path . --script res://tests/player_animation_test.gd # 四方向、瞄準、動畫
godot --headless --path . --script res://tests/character_layers_test.gd # 逐格接縫與角色／武器拆層
godot --headless --path . --script res://tests/element_orbit_test.gd # 佇列狀態與角色周身光點
godot --path . --script res://tests/element_altar_fx_test.gd     # 祭壇動畫、連續電弧／水流、合批及局部燈（需真實渲染）
godot --path . --script res://tests/element_glow_test.gd         # 關閉場景光後逐元素比較 glow 開／關，含正負控制
godot --headless --path . --script res://tests/style_test.gd      # 四場景組裝與切換 + 逐場景硬規則（第 2、8 節；不是視覺驗收）
godot --headless --path . --script res://tests/mesh_batch_test.gd # 合併前後幾何與材質資料
godot --headless --path . --script res://tests/water_reflection_test.gd # 水底、反射覆蓋及日夜／場景切換
godot --headless --path . --script res://tests/season_weather_lighting_test.gd # 村莊四季、雨天濕地與角色 3D 光照
zsh tests/capture_test.sh                                       # 缺圖、舊圖、失敗、逾時必須回報失敗
tools/capture.sh                                                  # 開視窗拍四個時段到 test_output/（可加 --scene=、--season=、--weather=、--nohud、--pos=x,z、--shots=day,night、--tag=名稱）
godot --headless --path . --script res://tools/contact_sheet.gd   # 場景 × 時段總表 test_output/contact_sheet.png（先用 --tag=<場景> 拍齊）
godot --path .                                                    # 實際遊玩
```

- 截圖必須開視窗跑；`--headless` 沒有畫面，不能證明視覺正確。
- 驗收截圖只留在本機的 `test_output/` 或 `docs/screenshots/`，不新增到 Git；遊戲執行需要的正式貼圖照常提交。既有已追蹤的歷史截圖不在此規則下批量刪除。
- 每次改場景或光影：跑 `tools/capture.sh`，**親眼看 PNG**，再對照 `docs/reference/`。
- 測試分兩種，不能互相代替：`tests/` 驗的是「按了會發生對的事」，截圖驗的是「畫面對不對」。

## 7. 接手守則

1. 先讀這份與 HANDOFF，再動手。
2. 不新增第二套做法：材質一律經 `Mats`，光影數值一律進 `PRESETS`，貼圖一律經產生器。
3. `.uid`、`.import`、`.godot/` 不手改。
4. 做完更新 HANDOFF 的進度表，寫清楚 `PASS`／`FAIL`／`NOT RUN`。

## 8. 場景守則（新增或修改場景時照做）

場景跟村莊是不是同一個遊戲，取決於這一節。標「自動」的由 `tests/style_test.gd` 逐場景檢查：場景加進 `Scenes.LIST` 就會受檢，不用改測試。標「看圖」的要拍圖對照村莊。

| # | 規則 | 怎麼驗 |
| --- | --- | --- |
| S1 | 一個場景一個檔：`src/world/scenes/<id>_scene.gd` 繼承 `SceneDef`，`id` 跟檔名相同，並加進 `Scenes.LIST` | 自動 |
| S2 | 場景檔只放資料與擺放。不准自己 new 材質、網格、燈光、粒子或環境，不准改 `scale`，不准直接 `load` 貼圖 | 自動（靜態掃描） |
| S3 | 東西只從共用零件來：`Build`、`HouseBuilder`、`TreeBuilder`、`PropBuilder`、`SetPieces`、`AmbientLife`。缺零件就加進 `SetPieces`，一樣守 A1–A6 | 自動（A1–A6 逐節點） |
| S4 | 光影差異只寫在 `TimeOfDay.PRESETS.scene_overrides[id]`，而且只能覆寫基底已有的欄位 | 自動 |
| S5 | 亮燈時段（`lamps > 0`）的 `vol_density ≤ 0.02`、暖燈 `light_volumetric_fog_energy ≤ 0.5`、窗光 `≤ 3` | 自動 |
| S6 | 人造光一律暖色（色相 ≤ 0.14 或 ≥ 0.95、飽和 ≥ 0.3）。冷色魔法光（水晶）要加進 `magic_lights` 群組 | 自動 |
| S7 | 開場畫面要有暖冷對比：出生點 12 公尺內至少一個暖色光源 | 自動 |
| S8 | 會動的東西至少四種：`AmbientLife.KINDS`，每個工廠函式回傳前呼叫 `tag()` | 自動 |
| S9 | Q 版比例：房屋底層 1.6–1.9 公尺、每層 1.5–1.75 公尺（A11） | 自動 |
| S10 | 開場畫面的構圖：前景有東西給景深糊掉；中景是玩家加一個地標（營火、橋、祭壇、正門）；背景有台地、樹林或牆擋住地平線 | 看圖 |
| S11 | 細節密度跟村莊同級：畫面每一區都要有東西，不能有大片空地板或空雪地。地下城第一版只有 595 個節點，看起來就是空的 | 看圖 |
| S12 | 地面用三層加側面貼圖。草叢依環境與季節換圖集（`grass_tuft`／`grass_tuft_autumn`／`grass_tuft_frost`），樹冠依季節換葉片貼圖（`leaves`／`leaves_blossom`／`leaves_autumn`／`leaves_winter`），不要用色調把綠草硬染成別的顏色 | 看圖 |

驗收順序：`style_test.gd` 全過 → 拍四個時段 → `tools/contact_sheet.gd` 排成總表 → 跟村莊同一欄比。總表印出的亮度數字只是輔助，數字正常不代表畫面對。

做場景時踩過的坑（2026-11-17）：

- **暗場景先查霧，再調燈。** 地下城體積霧 0.03 時整片霧濛濛；只改成 0.01 做 A/B，地板、水道、石階就出來了。
- **高金屬度在黑天空場景會變一片黑**：金屬只反射天空。`Mats.metal` 的金屬度固定 0.35。
- **錯層 45° 的針葉樹加雪片，雪只露出四個角**，看起來像紙三角。積雪的針葉樹要層層同向。
- **裂谷太深會被霧吃成一片灰。** 谷底放在約 5.5 公尺深，岩壁加錯落的岩架，谷底要有東西。
- **開陰影的點光源用雙拋物面**（`omni_shadow_mode = SHADOW_DUAL_PARABOLOID`）：立方陰影要畫 6 面，雙拋物面只畫 2 面。

## 9. 角色守則（之後的角色、敵人、隊友）

- **風格**：參考 `docs/reference/characters/`（Harvey 指定 Crusaders Quest 那種 Q 版像素風）。只學比例與畫法：大頭小身體、不對稱髮束、彩色描邊、誇張的裝備剪影。不照抄任何現有角色的造型、配色或圖。參考圖只放在 repo 裡給人看，不打包進遊戲。
- **規格**：圖格 56×48，原生單位為 1/32 公尺。B 主角站立戴帽的可見身高為 44 px，世界顯示倍率 1.20（基準高 1.65 公尺，A11），垂直另補償鏡頭俯角。接觸姿勢的腳底對齊地面，跑步騰空格由圖集中的抬腳表現。alpha 只能是 0 或 255，因為角色走 `alpha_cut`（A9）。
- **二頭身的量法**：以站立待機圖的顱頂、下巴、腳底三條基準線，核對「顱頂至下巴」與「下巴至腳底」約等長。量測先拿掉帽子，法杖與頭飾也不計入人體身高。帶帽的可見高度另依 A11 檢查。[第一輪原始要求](reference/round1_brief.png)
- **描邊**：外框取相鄰那格顏色加深，再往墨色 `#302a43` 拉近，最後吸附到色盤裡的描邊色。不要用一整圈純黑。
- **主角造型與色盤**：Harvey 選定 B「極致 Q 版」。細修沿用 B 原稿與遊戲圖集的 21 色；其他角色可另開色盤。參考圖順序、完整原始 prompt、Crusaders Quest 畫法與轉製驗收收在 [角色美術 harness](harness/MAGE_B.md)。
- **臉型**：分開量露臉與頭髮。兩張參考的下巴約為眼頰寬的 75–80%，下緣短平，近眼比遠眼寬，瀏海只留一道窄額縫。原圖有混色，邊界容許約一個來源像素的誤差。[露臉與五官量測](reference/characters/cq_face_measurement.png)・[黑色短鮑伯參考](reference/characters/violet_mage_concept.png)
- **戴帽與身體**：法師參考的左側帽簷壓在近側鬢髮前，下沿向右上揚約 13°，前額處有轉折。下巴緊接窄領，肩線斜落，腰比肩窄，翻起的袍尾撐開衣襬。法杖往身體外側伸出，杖頭與露臉寬度相近。以帽冠到衣襬為基準並排檢查。[法師比例參考](reference/characters/cq_mage_proportions.png)
- **動畫**：Harvey 選定保留四方向、6 格走路。圖集 10 欄 × 3 列，依序為正面、背面、側面，每列 4 格待機（呼吸與眨眼）加 6 格走路。所有面向統一按水平朝向鏡像，接近純上下時保留前次左右方向。帽尖、衣襬、持杖手與杖有分層延遲，雙靴保持間隔，步頻依實際移動速度調整。
- **活動接縫**：帽簷下保留內襯，袖口與肩、袍內與靴口保留重疊。所有方向的待機與跑步都不能因分層位移而透出背景；保留帽尖彎折、杖叉及雙靴之間的刻意留白。
- **手持物件**：角色本體、武器、握持手分層。`mage_atlas.png` 只含角色本體，`mage_hand_atlas.png` 是握持手圖集；`mage_staff.png` 是獨立法杖。`HeldWeapon` 依 `WeaponVisual` 的貼圖、握點及可選光源掛到手部，`Player.equip_weapon()` 可替換法杖、魔導書外觀或卸下。換裝不重畫角色圖集，三層共用鏡像、俯角補償與最近取樣，手指位於武器前方。`mage_idle.png` 僅作完整造型參考。
- **產生方式**：照 A5，角色圖由 `tools/gen_character.gd` 這類產生器輸出，不手改 PNG。
