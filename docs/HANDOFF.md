# 交接：目前進度與下一步

規則看 [BLUEPRINT.md](BLUEPRINT.md)。這份記錄實際完成與驗證狀態；靜態截圖不能代替操作手感或手機實機測試。

最後更新：2026-11-18（B「極致 Q 版」定為主角造型，調整村莊中的人物大小）

## B 版角色與建築比例（2026-11-18）

Harvey 確認 B 版造型，要求人物相對建築再大一點。以角色腳底為基準將遊戲中的法師等比例放大 20%，待機從帽頂到鞋底由 1.375 m 增為 1.65 m。角色圖格仍是 56×48，維持 B 的臉型、頭身比與 21 色；建築尺寸及遊戲鏡頭沿用原值。

| 交付 | 驗證狀態 |
| --- | --- |
| 角色與門窗的相對尺寸 | PASS。用同一個村莊站位、鏡頭與裁切位置並排檢視白天截圖，兩版腳底、門窗位置對齊。[放大前後對照](screenshots/mage_b_village_scale.png) |
| 遊戲畫面與回歸 | PASS。實際看過四時段、滿佇列、夜間施法共六張截圖。角色 45、光點 13、HUD 19、場景 288、元素邏輯 19、網格 15、截圖工具 6，合計 405 項通過。手機實機 NOT RUN。 |
| 美術 harness | PASS。AGENTS.md 與 CLAUDE.md 均連到 [B 版規格](harness/MAGE_B.md)，已逐字比對原始生成 prompt 並核對三張輸入圖的順序。 |

## 角色重設草稿（2026-11-18）

Harvey 提供的風格說明含較修長與極 Q 兩種比例，並要求「兩種都生成，將共同點捏合」。本輪使用內建 ImageGen 分別生成 A、B，再以兩張實際輸出與 CQ 原始法師參考生成 C；三版均保留黑短鮑伯、紫帽紫袍、酒紅點綴及大型琥珀法杖。A 著重肩腰、袍身與雙腿；B 著重大頭方圓臉與短軀幹；C 保留 B 的簡潔五官，加入 A 的腰線、衣襬、靴子層次。法杖立於身旁，手掌覆在杖柄前方，握點上下均可見杖身。

| 交付 | 驗證狀態 |
| --- | --- |
| 三張透明造型草稿 | PASS（產圖與人工檢視）。[A 修長 Q 版](reference/characters/mage_variants/a_tall.png)・[B 極致 Q 版](reference/characters/mage_variants/b_chibi.png)・[C 融合版](reference/characters/mage_variants/c_fused.png)。生成圖不是精確原生像素圖集，提示詞中的頭身比與色數只是生成目標，未宣稱輸出已精確符合。 |
| 等高比較圖 | PASS（產圖與人工檢視）。[三版並排](reference/characters/mage_variants/comparison.png) 為 1500×650。用 alpha ≥128 的可見輪廓對齊總高度，保持各圖長寬比與 nearest 取樣；微弱透明邊緣仍完整繪出。臉、帽子、袍身、雙靴與握杖可一起比較。 |
| 參考造型偏好 | PASS。Harvey 從三張草稿中貼回 B「極致 Q 版」，表示這個比較好。遊戲圖集按 B 轉製；實際遊戲造型的主觀驗收另記。 |
| B 版遊戲圖集 | PASS。正面依 B 原稿轉為原生像素，背面與側面共用帽子、握杖與腳底基準。每格 56×48，站立可見高 44 px，保留既有 21 個不透明色。去帽顱頂至下巴為 14 px，下巴至鞋底為 13 px。 |
| 動畫與杖光 | PASS。角色測試 45 項通過。包括三方向共 18 格的姿勢、掌心上下的杖柄、腳底位置與四面向的晶石光源。另跑元素光點 12 項、場景規則 288 項，全部通過。 |
| Godot 視窗 | PASS。已執行 `tools/capture.sh` 並檢視村莊晨、日、昏、夜與元素滿載、夜間施放共六張截圖。[原稿、原生像素與遊戲截圖對照](screenshots/mage_b_comparison.png) |
| B 版遊戲造型 | PASS。Harvey 看過遊戲對照後肯定角色造型，要求調整與建築的相對大小。實玩手感 NOT RUN。 |

B 版完整提示詞收於[角色美術 harness](harness/MAGE_B.md)，A、C 兩稿則在[草稿提示詞索引](reference/characters/mage_variants/prompts.txt)。參考草稿放在受 `docs/.gdignore` 排除的目錄。

## 第四輪角色與元素顯示（2026-11-18）

Harvey 選定黑色齊瀏海短鮑伯、深紫法袍與大武器。前兩次稿件的臉、帽子與身體比例均未獲接受。本次先依使用者提供的遊戲圖量出露臉輪廓與帽簷、身軀的相對位置，再重建角色。原始生成稿只作髮型參考。[黑色短鮑伯](reference/characters/violet_mage_concept.png)

| 拆解部位 | 素材讀值與重畫依據 |
| --- | --- |
| 露臉 | 白髮參考的眼頰寬約 20 個來源像素、頷底約 16；尖帽法師約 17 與 13。近眼較寬，額頭只從瀏海間露出窄縫，嘴寬而低。[原圖](reference/characters/cq_face_proportions.png)・[判讀圖](reference/characters/cq_face_measurement.png) |
| 帽子 | 女巫左簷約在 (25, 61)，右端約在 (93, 45)，由左下往右上約 13°。中段壓住近側鬢髮，額側形成轉折，右端翻起露出帽底。[原圖](reference/characters/cq_mage_proportions.png) |
| 身體 | 女巫下巴約 y70，領口 y71–74，肩袖 y75–79，衣襬在 y88 平止。圖中鞋形無法獨立量測。重畫時，緊接下巴的窄領、斜肩和袍尾各自保留可辨認的形狀。[帽子與身體判讀圖](reference/characters/cq_hat_body_measurement.png) |
| 二頭身 | 原始需求明寫「2頭身像素腳色」。先前只對齊帽冠和衣襬，導致下巴到腳底只剩 11px，Harvey 指出身體太矮。最新畫稿改以去帽人偶的顱頂、下巴、腳底分別量兩段。[原始需求圖](reference/round1_brief.png) |

<details>
<summary>髮型參考的 ImageGen 提示詞</summary>

One original full body playable chibi mage sprite, facing slightly right toward viewer. Use the three supplied images exclusively as haircut references: black chin-length inward-curving bob with clear blunt slightly parted bangs, both framing cheeks. Classic very wide deep violet pointed witch hat, bent tip, antique gold small diamond buckle and a wine ribbon, matching deep violet flared robe with large sleeves and worn boots, small old wood wand with amber tip. Make a charming, confident, deliberately super-deformed pixel-art RPG adventurer, 1.8 heads tall including a generous face, tiny compact body, stout, dot eyes, single pixels of blush. Chunky expressive intentional clusters you could really draw on a tiny 56x48 grid, limited rich palette, nearest-neighbour pixel grid. Single small character enlarged to fill the picture on transparent background. No UI, text, shadow, guides or scenery. Aim for the appeal and bold silhouettes of high-quality Crusaders Quest pixel characters but an original character design.

</details>

| 第四輪交付 | 驗證狀態 |
| --- | --- |
| 前兩版造型 | FAIL。Harvey 指出臉形、帽子與身體比例都未到位，兩版均已撤換。 |
| 接手重畫後的遊戲圖集 | PASS（素材規格）。18 格、21 個不透明色，alpha 僅 0／255。正面眼頰 14px、頷底 11px（79%），近／遠眼寬 4／2px、眼距 9px。去帽顱頂 y14、下巴 y30、腳底 y46，按像素行中心量得頭長 16px、身長 16px。衣襬提高，靴底分成兩段。角色與動畫回歸共 37 項通過。[兩頭身實測圖](screenshots/iteration4_mage_body_check.png)・[角色對照，左為參考、右為遊戲圖集](screenshots/iteration4_mage_comparison.png) |
| 元素鍵 | PASS。水滴、火焰、閃電與雪花四種像素圖示都有對應觸控回歸，HUD 共 19 項通過。 |
| 環繞光點 | PASS。空佇列、重複元素、滿載、水火融合、移動跟隨、施放與清空共 12 項通過；取消瞄準保留光點另由 HUD 操作測試驗證。 |
| 遊戲視窗 | PASS。實際檢視村莊晨／日／昏／夜、白天滿佇列及夜間施法，共 6 張。另以遊戲鏡頭錄下水火融合、補入其他元素與施放。[四元素 HUD](screenshots/iteration4_day_elements.png)・[環繞動畫](screenshots/iteration4_mage_orbit.webp) |
| 造型驗收 | FAIL。Harvey 看過二頭身版本後仍認為缺少 Crusaders Quest 風格，要求先提供同高度的整體對照，並指出武器握持不清楚。目前帽冠偏扁，手掌、杖柄與袖口連成橫線，包握輪廓待重畫。 |
| 手機實機 | NOT RUN。尚無 Android 實機幀時間或觸控手感量測。 |

第四輪回歸合計 396 PASS、0 FAIL（19 邏輯、19 HUD、12 光點、37 角色、288 場景、15 網格、6 截圖腳本）。

## 0. 第三輪（2026-11-17 下午）

目標：保證之後的場景跟村莊風格一致，而且是測試會擋，不只是寫在文件裡；同時把明顯偏離村莊的雪原、地下城修掉。角色、角色產生器與 34 色盤都沒動。

| 項目 | 做了什麼 | 驗證 |
| --- | --- | --- |
| 基準 | HANDOFF 第 6 節全部實跑 | PASS：19／17／29／40／15／6 = 126 |
| 風格自動檢查 | `style_test.gd` 會把 `Scenes.LIST` 每個場景在未合併網格的狀態下建出來，逐節點檢查 A1、A2、A3、A6、A7、A8、A10、A11，並靜態掃描場景檔與 shader。規則表在 BLUEPRINT 第 8 節 | PASS：288 項。改完當下抓到地下城 6 項 FAIL（體積霧 0.03、火盆霧能量 0.6），修正後歸零 |
| 地下城 | 霧 0.03 → 0.01（先 A/B 確認是主因）；出生點移到大廳中央；地板改錯縫大小石板；加正門鐵柵、蠟燭、吊鏈、石棺、水窪、牆苔、碎石；前排火盆移到玩家兩側；銅金屬度 0.75 → 0.35；水色調亮；蝙蝠只在大廳內飛 | 前後對照：`iteration3_dungeon_before.png` → `iteration3_dungeon_day.png`／`_night.png`，看過 |
| 雪原 | 新增霜枯草圖集 `grass_tuft_frost`，草依雜訊成叢；積雪針葉樹改成層層同向，每層一圈雪；裂谷加積雪岩架，谷底抬到 5.5 公尺深，放結冰溪流、雪堆、石頭；雪堆改成錯位的低矮雪丘 | `iteration3_snow_day.png`、`iteration3_snow_chasm.png`，看過 |
| 點光源陰影 | 開陰影的路燈、營火、火盆改用雙拋物面陰影（2 面，立方體是 6 面） | 實際繪製 draw call 見下表。看得到的差異：路燈正下方原本被燈罩底板擋出的暗圈消失，地上多一圈暖光（`iteration3_village_night.png`），請 Harvey 確認 |
| 一致性總表 | `tools/contact_sheet.gd` 把 4 場景 × 4 時段排成一張，並印出亮度數字 | `iteration3_contact_sheet.png`，看過 |
| 文件 | BLUEPRINT 新增第 8 節場景守則、第 9 節角色守則 | 文件一致性自查 |

最終 draw call（Apple M4、1600×900、無 HUD，存圖後實際繪製讀值，晨／日／昏／夜）：

| 場景 | 第三輪前 | 第三輪後 |
| --- | --- | --- |
| 村莊 | 397／375／916／873 | 298／276／500／463 |
| 森林 | 399／381／676／664 | 327／306／418／408 |
| 雪原 | 298／284／431／416 | 225／211／279／259 |
| 地下城 | 日 584、夜 687（加細節前） | 540／515／517／530 |

「第三輪前」是雙拋物面之前在同一台機器拍的。地下城細節加完、陰影還是立方體時，四個時段是 883／866／846／861。這些都是 draw call，**不是 FPS**，手機實機仍 NOT RUN。

## 1. 本輪接手與使用者決定

- 接手時沒有 commit；主程式仍引用已刪除的 `VillageWorld`／`Layout`，無法啟動。已接上現有 `Scenes → SceneDef → GameWorld`，保留前一輪已寫的四場景與原始參考圖。
- GitHub repo 名稱確定為 `elemental-hd2d-godot`，遠端為 `https://github.com/wuharry/elemental-hd2d-godot.git`。
- 第二輪曾使用銀髮書騎士與 34 色色盤。第四輪依 Harvey 的新參考更換主角，現用黑短髮法師，後續細修仍限制色數。
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

各輪場景驗收圖保留在 [screenshots/](screenshots/)。`iteration2_` 與 `iteration3_` 的場景截圖記錄當時版本。執行截圖工具會將新圖與日誌寫到 `test_output/`。

## 3. 第二、三輪進度與驗證

| 區塊 | 實際完成範圍 | 驗證 |
| --- | --- | --- |
| 專案組裝 | 修復舊類別引用、場景載入與 F5–F8 切換；清掉舊場景法術、重設出生點與鏡頭 | PASS：`style_test.gd` 組裝段 40 項（第三輪擴充為 288 項，見第 0 節） |
| 世界素材 | 重產原有材質，補齊雪、冰、石板、磚及法線圖，共 34 張 | PASS：生成、匯入與四場景截圖 |
| 角色造型 | 原創銀髮書騎士；56×48 圖格、可見高 44px、32px/m；34 色固定色盤 | PASS：Harvey 確認方向；圖集與色盤檢查 |
| 角色動畫 | 正／背／側各 2 格待機與 4 格走路，左側鏡像；瞄準優先、停步保留方向、撞牆不踏步、施法不重置步伐 | PASS：29 項動畫／色票回歸；整體遊玩手感 NOT RUN（待 Harvey 實玩） |
| 四場景 | 村莊、森林河谷、雪原吊橋、地下城大廳均可開啟 | PASS：實際開視窗截圖看過；不是關卡玩法驗收 |
| 四時段 | 基底與各場景覆寫集中在 `TimeOfDay.PRESETS`；切回村莊不殘留地下城光影 | PASS：時段／切場回歸；四時段與夜間施法截圖實際看過 |
| 樹冠遮擋 | 鏡頭至角色間的樹葉做像素格鏤空，保留深度與完整陰影 | PASS：`--pos=-13,3.1` 開／關對照看過；逐棵樹巡查 NOT RUN |
| 靜態網格 | 64m 中心對齊分區，保留原始材質座標／法線／切線／風動中心；碰撞與動態子樹保持原狀 | PASS：15 項幾何資料回歸與批次前後看圖；800 draw call 目標：第三輪改雙拋物面陰影後，四場景四時段全部 PASS（最高 540） |
| 零能量燈 | 完全熄滅的路燈不提交陰影；過場亮起立即恢復 | PASS：日間與黃昏過場回歸 |
| 元素佇列與融合 | 保留既有規則 | PASS：19 項 |
| HUD | 雙搖桿、四元素鍵、融合鍵；補同時移動與反向瞄準、釋放／resize 輸入清理 | PASS：17 項 |
| 截圖工具 | 檢查 Godot 退出碼、錯誤日誌、新圖、缺圖、逾時與不合法檔名；互斥執行避免覆蓋驗收 | PASS：6 項 shell 回歸；實際產圖 |
| 法術 | 仍是帶光元素彈預覽，沒有傷害或環境反應 | PASS：原有操作路徑；正式戰鬥未做 |

第二輪結束時合計 126 PASS。第三輪結束後合計 **374 PASS、0 FAIL**（19 邏輯 + 17 HUD + 29 角色 + 288 場景風格 + 15 網格 + 6 截圖腳本）。

效能測量環境：Apple M4、1600×900、Metal／Forward+、無 HUD。第二輪：村莊最初約 4,276 draw calls，合併網格後日間 374、夜間 895；`--no-batching` 日間 3,293，合併約少 89%。第三輪把點光源陰影改成雙拋物面，夜間降到 463，四場景四時段都在 800 以下（第 0 節表格）。陰影沒有關掉，只換了模式。粒子、視角、HUD 都會改變呼叫數。

可比較的實玩 FPS 與手機實機 **NOT RUN**：macOS 視窗被遮住時可能停止繪圖，但 process loop 仍跑；因此截圖日誌的 `steady process cadence` 不代表 GPU FPS，也不能據此宣稱幀率提升。正式驗收應前景實玩並量測 frame time。

## 4. 尚未完成與限制

- **手機降級方案／Android 實機：NOT RUN**。仍是 Forward+，還沒有 Mobile renderer 的光影降級、實機 30fps 驗證。
- **完整遊玩流暢度：NOT RUN**。角色動畫與觸控邏輯有自動測試；鏡頭、風、粒子及操作感仍需 Harvey 實玩。
- 樹冠鏤空不是全場物件透視；樹幹仍是實體，房屋遮擋尚未做，所有樹位逐棵巡查未做。
- 地下城、雪原只看過開場位置與裂谷一個視角；整張地圖逐區巡查 NOT RUN。地下城的蝙蝠在近景是小黑方塊，還沒做翅膀細節。
- 風格自動檢查管得到規則與數值範圍，管不到「好不好看」：構圖（S10）、細節密度（S11）仍要看圖。
- 池塘反射仍受 SSR 視角限制，尚未特別強化。
- 三個快捷槽仍只有外觀；長按護盾、副手輕點仍是提示，配方對應法術未定。
- 敵人、傷害、環境狀態、友傷、救助／復活、多人未開始。
- Threads 影片連結仍無法取得內容；本輪依 Harvey 提供與 repo 內的圖像參考，沒有宣稱看過影片。

## 5. 下一步

1. Harvey 實玩 B 版法師，確認一般鏡頭下的剪影、四方向移動與光點可讀性。細修沿用既有 21 色。
2. 做 Mobile renderer 降級，並在手機上量 frame time。draw call 已經壓到 800 以下，但這不代表手機跑得動；不得靠關掉有光燈具或陰影來達標。
3. Android 實機與四時段截圖驗收；沒有裝置就寫 NOT RUN。
4. 玩法草案由 Harvey 拍板後，才接敵人假人、傷害與環境互動；不要自己決定待定規則。

## 6. 驗收指令

```bash
cd /Users/harvey/repo/elemental-hd2d-godot
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --script res://tests/hud_input_test.gd
godot --headless --path . --script res://tests/player_animation_test.gd
godot --headless --path . --script res://tests/element_orbit_test.gd
godot --headless --path . --script res://tests/style_test.gd
godot --headless --path . --script res://tests/mesh_batch_test.gd
zsh tests/capture_test.sh
tools/capture.sh
for s in village forest snow dungeon; do tools/capture.sh --scene=$s --nohud --tag=$s; done
godot --headless --path . --script res://tools/contact_sheet.gd   # 4 場景 × 4 時段總表，打開 test_output/contact_sheet.png 看
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
| 新場景登錄、共用路徑規則 | `scenes.gd`、`scene_def.gd`；守則見 BLUEPRINT 第 8 節 |
| 房屋、樹、道具、橋 | `house_builder.gd`、`tree_builder.gd`、`prop_builder.gd`、`set_pieces.gd` |
| 所有場景的四時段光影 | `time_of_day.gd` 的 `PRESETS`（含 `scene_overrides`） |
| 貼圖與角色 | `tools/gen_textures.gd`、`tools/gen_character.gd`；重跑後匯入 |
| 角色動畫／瞄準 | `src/player/player.gd` |
| 佇列光點與元素圖示 | `src/player/element_orbit.gd`、`tools/gen_element_icons.gd` |
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
- 第三輪：暗場景先查霧再調燈；高金屬度在黑天空下變黑；錯層 45° 的雪片只露四角；裂谷太深被霧吃成灰；點光源陰影用雙拋物面。細節見 BLUEPRINT 第 8 節。
- GDScript 在 `for side in [-1, 1]` 這種無型別迴圈裡用 `:=` 推導會解析失敗，整個場景載不進來（雪原第三輪踩過）。迴圈變數寫 `for side: int in ...`，或結果寫明型別。`--editor --import` 不一定會先抓到，要跑 `style_test.gd`。
