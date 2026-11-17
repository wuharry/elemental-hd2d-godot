# 交接：目前進度與下一步

規則看 [BLUEPRINT.md](BLUEPRINT.md)。這份記錄實際完成與驗證狀態；靜態截圖不能代替操作手感或手機實機測試。

最後更新：2026-11-17（第二輪：修復未接完的四場景架構、角色重畫與動畫、樹冠遮擋、繪製效能、可靠截圖）

## 1. 本輪接手與使用者決定

- 接手時沒有 commit；主程式仍引用已刪除的 `VillageWorld`／`Layout`，無法啟動。已接上現有 `Scenes → SceneDef → GameWorld`，保留前一輪已寫的四場景與原始參考圖。
- GitHub repo 名稱確定為 `elemental-hd2d-godot`，遠端為 `https://github.com/wuharry/elemental-hd2d-godot.git`。
- Harvey 明確指出第一版人物不夠像 Crusaders Quest。重畫銀髮、羽飾、金邊短裝、紅披風與大型魔導書之後，Harvey 確認沿用此方向，**顏色不要再增加**。目前圖集使用固定 34 種不透明顏色，alpha 只有 0／255；後續細修不准擴充這套色盤。新增的兩張造型參考在 `docs/reference/characters/cq_*.png`。
- 玩法「草案」「待定」維持原狀，本輪沒有決定護盾、副手、配方、傷害或多人規則。

## 2. 操作與畫面

| 操作 | 觸控 | 鍵盤 |
| --- | --- | --- |
| 移動 | 左搖桿 | WASD |
| 加入元素 | 輕點水／火／雷／冰 | 1、2、3、4 |
| 融合最後兩格（原有草案） | 融合鍵 | F |
| 施放 | 右搖桿推外圈放開；拉回內圈放開則取消 | 空白鍵 |
| 切換時段 | 右上角晨／日／昏／夜 | F1–F4；T 下一個 |
| 切換展示場景 | 尚無觸控選單 | F5 村莊、F6 森林、F7 雪原、F8 地下城 |

也可用 `godot --path . -- --scene=forest` 直接開指定場景。這些是場景與操作原型，不是已完成關卡。

原始截圖仍保留在 [screenshots/](screenshots/)。本輪驗收圖用 `iteration2_` 前綴，角色放大圖為 `iteration2_character.png`。本輪產圖與效能紀錄在忽略提交的 `test_output/`。

## 3. 進度與驗證

| 區塊 | 實際完成範圍 | 驗證 |
| --- | --- | --- |
| 專案組裝 | 修復舊類別引用、場景載入與 F5–F8 切換；清掉舊場景法術、重設出生點與鏡頭 | PASS：`style_test.gd` 共 40 項 |
| 世界素材 | 重產原有材質，補齊雪、冰、石板、磚及法線圖，共 34 張 | PASS：生成、匯入與四場景截圖 |
| 角色造型 | 原創銀髮書騎士；56×48 圖格、可見高 44px、32px/m；34 色固定色盤 | PASS：Harvey 確認方向；圖集與色盤檢查 |
| 角色動畫 | 正／背／側各 2 格待機與 4 格走路，左側鏡像；瞄準優先、停步保留方向、撞牆不踏步、施法不重置步伐 | PASS：29 項動畫／色票回歸；整體遊玩手感 NOT RUN（待 Harvey 實玩） |
| 四場景 | 村莊、森林河谷、雪原吊橋、地下城大廳均可開啟 | PASS：實際開視窗截圖看過；不是關卡玩法驗收 |
| 四時段 | 基底與各場景覆寫集中在 `TimeOfDay.PRESETS`；切回村莊不殘留地下城光影 | PASS：時段／切場回歸；四時段與夜間施法截圖實際看過 |
| 樹冠遮擋 | 鏡頭至角色間的樹葉做像素格鏤空，保留深度與完整陰影 | PASS：`--pos=-13,3.1` 開／關對照看過；逐棵樹巡查 NOT RUN |
| 靜態網格 | 64m 中心對齊分區，保留原始材質座標／法線／切線／風動中心；碰撞與動態子樹保持原狀 | PASS：15 項幾何資料回歸與批次前後看圖；800 draw call 目標：日間 PASS、夜間 FAIL |
| 零能量燈 | 完全熄滅的路燈不提交陰影；過場亮起立即恢復 | PASS：日間與黃昏過場回歸 |
| 元素佇列與融合 | 保留既有規則 | PASS：19 項 |
| HUD | 雙搖桿、四元素鍵、融合鍵；補同時移動與反向瞄準、釋放／resize 輸入清理 | PASS：17 項 |
| 截圖工具 | 檢查 Godot 退出碼、錯誤日誌、新圖、缺圖、逾時與不合法檔名；互斥執行避免覆蓋驗收 | PASS：6 項 shell 回歸；實際產圖 |
| 法術 | 仍是帶光元素彈預覽，沒有傷害或環境反應 | PASS：原有操作路徑；正式戰鬥未做 |

本輪自動檢查合計 **126 PASS、0 FAIL**（19 邏輯 + 17 HUD + 29 角色 + 40 場景 + 15 網格 + 6 截圖腳本），程式審查與截圖路徑的安全審查均無待修項目。

效能測量環境：Apple M4、1600×900、Metal／Forward+、無 HUD。最初修復啟動後的村莊約 4,276 draw calls；最後強制完成實際繪製後讀值：日間 **374**、夜間 **895**。在相同新版燈光設定下，`--no-batching` 日間 **3,293**，合併後約少 **89%**。粒子／視角／HUD 會改變呼叫數。**夜間尚未達 800 目標**，不能任意關掉亮燈陰影來達標。

可比較的實玩 FPS 與手機實機 **NOT RUN**：macOS 視窗被遮住時可能停止繪圖，但 process loop 仍跑；因此截圖日誌的 `steady process cadence` 不代表 GPU FPS，也不能據此宣稱幀率提升。正式驗收應前景實玩並量測 frame time。

## 4. 尚未完成與限制

- **手機降級方案／Android 實機：NOT RUN**。仍是 Forward+，還沒有 Mobile renderer 的光影降級、實機 30fps 驗證。
- **完整遊玩流暢度：NOT RUN**。角色動畫與觸控邏輯有自動測試；鏡頭、風、粒子及操作感仍需 Harvey 實玩。
- 樹冠鏤空不是全場物件透視；樹幹仍是實體，房屋遮擋尚未做，所有樹位逐棵巡查未做。
- 池塘反射仍受 SSR 視角限制，尚未特別強化。
- 三個快捷槽仍只有外觀；長按護盾、副手輕點仍是提示，配方對應法術未定。
- 敵人、傷害、環境狀態、友傷、救助／復活、多人未開始。
- Threads 影片連結仍無法取得內容；本輪依 Harvey 提供與 repo 內的圖像參考，沒有宣稱看過影片。

## 5. 下一步

1. Harvey 實玩新版角色與四場景，回饋比例、可讀性、走路動作和操作感。**固定 34 色盤，不增加顏色。**
2. 針對黃昏／夜晚的有效燈光繼續效能量測，再做 Mobile renderer 降級；不得靠任意關掉有光燈具或陰影達標。
3. Android 實機與四時段截圖驗收；沒有裝置就寫 NOT RUN。
4. 玩法草案由 Harvey 拍板後，才接敵人假人、傷害與環境互動；不要自己決定待定規則。

## 6. 驗收指令

```bash
cd /Users/harvey/repo/elemental-hd2d-godot
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --script res://tests/hud_input_test.gd
godot --headless --path . --script res://tests/player_animation_test.gd
godot --headless --path . --script res://tests/style_test.gd
godot --headless --path . --script res://tests/mesh_batch_test.gd
zsh tests/capture_test.sh
tools/capture.sh
tools/capture.sh --nohud --shots=day,dusk --tag=clean
tools/capture.sh --nohud --pos=-7,4 --shots=day --tag=pond
tools/capture.sh --scene=forest --nohud --shots=day --tag=forest
tools/capture.sh --scene=snow --nohud --shots=day --tag=snow
tools/capture.sh --scene=dungeon --nohud --shots=day --tag=dungeon
tools/capture.sh --nohud --pos=-13,3.1 --shots=day --tag=occlusion_on
tools/capture.sh --nohud --pos=-13,3.1 --shots=day --tag=occlusion_off --no-reveal
```

產圖後必須打開 PNG 看。`--no-batching` 可比較未合併的幾何；`--time=night` 可單獨量夜間。`warmup` 是前 150 個 process frame，`steady process cadence` 另量後續 120 個 process frame，**都不是 GPU FPS benchmark**；`rendered draw calls` 則在主動繪製並讀回 PNG 後記錄。`--headless` 不能跑畫面驗收。截圖腳本同時間只能跑一個，失敗不會把舊圖當新成果。

## 7. 修改位置

| 想改什麼 | 修改位置 |
| --- | --- |
| 場景資料與擺放 | `src/world/scenes/*_scene.gd` |
| 新場景登錄、共用路徑規則 | `scenes.gd`、`scene_def.gd` |
| 房屋、樹、道具、橋 | `house_builder.gd`、`tree_builder.gd`、`prop_builder.gd`、`set_pieces.gd` |
| 所有場景的四時段光影 | `time_of_day.gd` 的 `PRESETS`（含 `scene_overrides`） |
| 貼圖與角色 | `tools/gen_textures.gd`、`tools/gen_character.gd`；重跑後匯入 |
| 角色動畫／瞄準 | `src/player/player.gd` |
| 鏡頭／樹冠鏤空 | `camera_rig.gd`、`shaders/foliage_reveal.gdshaderinc` |
| 網格合併 | `mesh_batcher.gd`、`mats.gd`、`batched_triplanar.gdshader`、`foliage_block.gdshader` |
| 操作版面 | `src/ui/hud.gd` 的 `_layout()` |
| 融合規則 | `src/combat/`（先確認 Harvey 已定規則） |

## 8. 保留的踩坑紀錄

- 體積霧與很多暖色點光源會一起過曝。暖燈 `light_volumetric_fog_energy` 約 0.4–0.5；調色先看黃昏，不要拿全局曝光補單一光源。
- 角色在算繪層 2，跟隨角色的武器光排除層 2，另用補光照角色，避免洗白。
- 窗戶發光太高會糊掉窗格，現有值最高 2.8。亮度優先從既有 PRESETS 與 glow 調整。
- `Input.parse_input_event` 用視窗像素座標；測試先以 `root.get_final_transform()` 轉換。`unproject_position` 已是畫布座標，不要再乘縮放。
- `.uid`／`.import`／`.godot/` 由引擎管理。非遊戲圖資料夾保留 `.gdignore`。
- 只有 `--editor --import --quit` 成功不代表動態載入的場景能編譯；本輪在森林首次執行時抓到 `set_pieces.gd` 的型別推導錯誤。四場景測試與實際截圖都要跑。
- 合併網格若只變換頂點，會破壞 local triplanar 與風動相位。使用 CUSTOM 欄位保留來源資料；斜屋頂法線的高次方混合必須正規化，不能用過大的 epsilon 把屋頂壓黑。
- 能量為零的燈在此 renderer 仍會消耗陰影繪製，完全熄滅時隱藏並在亮起時恢復；不影響獨立營火光。
- macOS 視窗被遮住時 `frame_post_draw` 可能不再發出；本輪重現過等待卡住。存 PNG 時在主執行緒主動 `force_sync()`／`force_draw(false)`，再讀回影像；外層仍有逾時與新圖檢查。
