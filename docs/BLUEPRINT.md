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
| A1 | 全場同一個像素密度 | 世界貼圖 32 px／公尺：64px 貼圖鋪 2 公尺，`Mats.TEXEL_SCALE = 0.5`；角色 `pixel_size = 1/32` | 像素大小不一致，畫面立刻像拼貼 |
| A2 | 貼圖一律 nearest | 世界用 `NEAREST_WITH_MIPMAPS`，角色與 UI 用 `NEAREST` | 糊掉的像素不是像素風 |
| A3 | 幾何只用方塊與三角柱 | `BoxMesh`、`PrismMesh`、交叉面片（花草）；可將這些原始幾何合併成 `ArrayMesh`，不改形狀；不用圓柱、球、平滑曲面 | 體素感來自方塊，圓滑幾何會出戲 |
| A4 | 貼圖不畫光影 | 貼圖只放固有色與 `_n` 法線圖；明暗全部交給即時光 | 四個時段共用同一套貼圖，畫死的陰影在夜晚會穿幫 |
| A5 | 貼圖不手改 | 改 `tools/gen_textures.gd`、`tools/gen_character.gd` 後重跑；PNG 是產物 | 可重現，也能一次調整全套色調 |
| A6 | 方塊貼圖走 triplanar | `Mats.tri()`（local triplanar），用 `BoxMesh.size` 定尺寸，**不要用 node scale**；合併時由 `Mats.batched_tri()` 與頂點自訂欄位保留原始座標、法線與切線 | scale 會把像素拉長，破壞 A1 |
| A7 | 光影數值只放一處 | 四個時段的太陽、環境光、霧、窗光、路燈全部在 `src/world/time_of_day.gd` 的 `PRESETS` | 調色時不用滿專案找數字 |
| A8 | 暖冷對比 | 人造光（窗、路燈、營火）一律暖色；陰影與夜晚環境光偏冷 | 兩張參考圖的氛圍都靠這個 |
| A9 | 角色是 2 頭身像素圖片 | `Sprite3D`、繞 Y 軸面向鏡頭、吃場景光、`alpha_cut`（不用半透明） | 半透明物件不寫深度，景深會把它糊錯 |
| A11 | Q 版世界比例 | 角色約 1.4 公尺（44px）；門高 1.5 公尺、一層樓 1.6 公尺、窗 0.75 公尺（24px） | 房子照真實比例蓋會比角色大太多，鏡頭拉不進整棟；參考圖也是這個比例 |
| A10 | 場景要有會動的東西 | 風吹花草與樹、落葉、蝴蝶、鳥、煙囪煙、塵埃光點、雲影、夜晚螢火蟲 | 驗收條件明寫「生動」 |

## 3. 算繪設定

- Renderer：Forward+（體積霧、SSAO、SSIL、SSR 只有它有）。**手機是主要平台，Mobile renderer 沒有這幾項**；降級方案尚未做，列在 HANDOFF 的待辦。
- 鏡頭：`Camera3D` FOV 25°、俯角 33°、水平轉 22°、距離 30 公尺；`CameraAttributesPractical` 開近、遠兩段景深，對焦在角色前後約 4 公尺。數值是 `camera_rig.gd` 的 `@export`。
- 後製：ACES tonemap、glow、SSAO、SSIL、體積霧、少量色彩調整。數值在 `time_of_day.gd`。

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
   ├─ Player         src/player/player.gd          移動 + 像素角色 + 元素佇列
   ├─ CameraRig      src/player/camera_rig.gd      跟隨 + 景深對焦
   └─ Hud            src/ui/hud.gd                 雙搖桿、元素鍵、融合鍵、佇列顯示
src/combat/elements.gd、element_queue.gd：純邏輯（RefCounted，不碰節點），可單獨測試
```

- 場景用程式組出來，不是手寫 `.tscn`。原因：agent 手寫 `.tscn` 容易把 `ext_resource`／UID 弄壞。要讓 Harvey 在編輯器調整的參數，用 `@export` 放在腳本上。
- 依賴方向只能往下：`main` → `world`／`player`／`ui` → `combat`。`combat` 不准認識任何節點。
- 新增物件的流程：在對應 Builder 加一個函式 → 在對應 `*_scene.gd` 的資料或 `populate()` 加一筆 → 跑截圖驗收。
- 場景清單在 `Scenes.LIST`，共用地形／路徑定義在 `SceneDef`。場景光影差異仍只放在 `TimeOfDay.PRESETS.scene_overrides`，不在場景檔各寫一套。
- 合併網格必須保留原始像素座標、材質、風動中心、陰影模式、碰撞和動畫。`--no-batching` 可拍原始網格作比較。樹冠遮擋使用 `foliage_reveal.gdshaderinc` 的像素格鏤空，不用半透明，且不改陰影輪廓。

## 5. 規則狀態（玩法）

- **已定**：四種出戰元素、四格佇列（限制的是目前占用格數）、可重複加入、融合後騰出格子、水＋火不自動融合、獨立融合鍵、左搖桿移動、右搖桿瞄準施放、長按元素開盾、三個快捷槽。
- **草案（Gemini 建議，Harvey 尚未拍板，程式裡標 `DRAFT`）**：融合固定取最後兩格、複合元素不可再融合、護盾長按後持續固定秒數、輕點右搖桿中心放副手、友傷比例。
- 草案要改時只改 `src/combat/`，不要讓 UI 或世界層寫死這些規則。

## 6. 指令

```bash
cd /Users/harvey/repo/elemental-hd2d-godot
godot --headless --path . --script res://tools/gen_textures.gd    # 重產世界貼圖
godot --headless --path . --script res://tools/gen_character.gd   # 重產角色與圖示
godot --headless --path . --import                                # 讓引擎重新匯入（.import 由引擎產生，不手改）
godot --headless --path . --script res://tests/run_tests.gd       # 純邏輯測試
godot --headless --path . --script res://tests/hud_input_test.gd  # 操作路徑測試（載入真正的 main 場景送觸控事件）
godot --headless --path . --script res://tests/player_animation_test.gd # 四方向、瞄準、動畫
godot --headless --path . --script res://tests/style_test.gd      # 四場景組裝、切換與像素規格（不是視覺驗收）
godot --headless --path . --script res://tests/mesh_batch_test.gd # 合併前後幾何與材質資料
zsh tests/capture_test.sh                                       # 缺圖、舊圖、失敗、逾時必須回報失敗
tools/capture.sh                                                  # 開視窗拍四個時段到 test_output/（可加 --nohud、--pos=x,z、--shots=day,night、--tag=名稱）
godot --path .                                                    # 實際遊玩
```

- 截圖必須開視窗跑；`--headless` 沒有畫面，不能證明視覺正確。
- 每次改場景或光影：跑 `tools/capture.sh`，**親眼看 PNG**，再對照 `docs/reference/`。
- 測試分兩種，不能互相代替：`tests/` 驗的是「按了會發生對的事」，截圖驗的是「畫面對不對」。

## 7. 接手守則

1. 先讀這份與 HANDOFF，再動手。
2. 不新增第二套做法：材質一律經 `Mats`，光影數值一律進 `PRESETS`，貼圖一律經產生器。
3. `.uid`、`.import`、`.godot/` 不手改。
4. 做完更新 HANDOFF 的進度表，寫清楚 `PASS`／`FAIL`／`NOT RUN`。
