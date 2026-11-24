# 交接：目前進度與下一步

規則看 [BLUEPRINT.md](BLUEPRINT.md)。這份記錄實際完成與驗證狀態；靜態截圖不能代替操作手感或手機實機測試。

最後更新：2026-11-24（相連的六座元素祭壇與出戰格換裝）

## 靠近祭壇直接替換出戰格（2026-11-24）

西村口傳送門抵達森林的土祭壇前。水、冰、土、奧術、火、雷六座祭壇連在同一排石座上，各自使用與 HUD 相同的圖示。沿石座前方走，HUD 顯示最近的祭壇和亮起的出戰格。點一下或按對應的 1–4 鍵，即時替換該格。若目標元素已裝備，只亮對應格並顯示「已裝備」。換裝期間可移動，離開祭壇後出戰鍵恢復組招。已排好的法術與往返後的配置均保留。

| 驗證項目 | 結果 |
| --- | --- |
| 祭壇與觸控 | PASS。實際用測試搖桿走過六座祭壇，驗證直接換格、跨祭壇取消舊點按、避免重複裝備及回村後的新按鍵。HUD 回歸 45 項。 |
| 場景與回歸 | PASS。七套 Godot 回歸共 603 項，截圖工具回歸 6 項，皆 0 FAIL。 |
| 實際畫面 | PASS。用 `tools/capture.sh --altar-preview --tag=altar_row` 拍晨、日、昏、夜四張，並另拍水祭壇的已裝備狀態，均已檢視。共用工作目錄的渲染器在退出時有 Texture RID 警告，五張圖均正常產出。 |
| 手機實機 | NOT RUN。 |

## 從村莊走到元素祭壇（2026-11-21）

從村莊中央出生，沿石板路向西走過最後一間房屋，會在可行走區域西界內側 2 公尺看見傳送門。門前會出現互動圖示，點一下或按 E 可抵達森林祭壇。祭壇旁的回程門會送玩家回西村口，落在門朝村內的一側。

當時以六選四面板裝備，現已由上節的就近替換取代。換裝保留已排好的法術，往返保留配置，重啟時預設為水、火、雷、冰。戰鬥 HUD 的兩節鎖鏈代表融合，有有效配方時會提亮，輕點一次就融合。[元素 HUD 與祭壇操作規格](harness/ELEMENT_HUD.md)

門框包住位置較深的漩渦，十二枚立體光屑從門前旋入。紫色點光源照到門柱與石板，投下即時陰影。出發與抵達都會觸發一次光脈衝，照明半徑從 4.6 公尺擴至 5.75 公尺，約 0.55 秒後復原。[遊戲內傳送動態](screenshots/waygate_transit.webp)

| 驗證項目 | 結果 |
| --- | --- |
| 村外路線 | PASS。從出生點沿石板路至門心約 29.7 公尺，以角色膠囊檢查沿路 303 點均可通行。另以遊戲左搖桿實際走到門心、進入祭壇，再從回村落點沿原路走回出生點。回村距門 1.3 公尺，原地等候不會再傳送。 |
| 祭壇與觸控 | PASS。驗證融合、鎖定槽、六選四、確認與取消、多指移動、連點進門與往返保留配裝。七套 Godot 回歸共 595 PASS、0 FAIL，其中 HUD 與操作路線 37 項。 |
| 3D 光影 | PASS。實際檢視 Forward+ 四時段西村口與森林祭壇、配裝面板和回程門。以 Windows 上的 Godot Mobile 渲染器另拍白天與夜間村口，門幕及石板受光均可見。Mobile 模式會略過目前場景的 SSAO、SSIL、SSR 與體積霧。 |
| `tools/capture.sh` | NOT RUN。這台 Windows 沒有可用的 zsh，改用相同 Godot `--capture` 入口，逐張檢查檔案更新時間和實際畫面。 |
| Z Fold7 實機與參考遊戲 | NOT RUN。Windows「本機」能列出「浩維 的 Z Fold7」，這個工作階段未能列出該裝置下的儲存空間。另一路共用儲存可讀到 `Android/media` 和下載目錄，檢查其中五個 APK 的套件名稱，均不是《元素世界》。目前未取得該遊戲的手機資源或實機幀時間。 |

## 活動接縫與獨立武器（2026-11-19，Harvey 已確認本版）

Harvey 看過實際遊戲預覽後，確認此版並要求 commit、push 到 GitHub。本版包含下列接縫與武器拆分，以及同日的俯角補償、四方向六格動畫；原本已存在的 `project.godot` 編輯器設定差異保留在本機，不納入這次提交。

Harvey 指出移動／呼吸時帽子與頭部之間透出背景，也要求修正同類問題，並把法杖拆成獨立物件，供之後換法杖或魔導書。前一輪抽樣漏掉帽簷開縫，不能以當時的動畫 PASS 代表接縫驗收通過。

本輪在帽簷後方補內襯，補齊肩袖到握手、袍內到靴口的重疊，保留帽尖彎折、杖叉、雙靴之間的刻意留白。沿用 B 造型、21 色、人物尺寸與四方向六格走路。

本體圖集 `mage_atlas.png` 已移除武器與握持手；`mage_hand_atlas.png` 是手與袖口覆蓋層，`mage_staff.png` 是獨立法杖。遊戲使用 `HeldWeapon` 節點，`WeaponVisual` 資源指定貼圖、握點及可選光源；預設是 `assets/weapons/amber_staff.tres`。`Player.equip_weapon(resource)` 替換外觀，傳 `null` 卸下。武器在角色前、手指後，三層同步鏡像與俯角補償。武器光跟隨自身發光位置；完整待機參考 `mage_idle.png` 保留。

| 交付 | 驗證狀態 |
| --- | --- |
| 30 格接縫與拆層 | PASS。`character_layers_test.gd` 126 項直接檢查輸出 PNG：帽髮交界、封閉透明孔、身體連通、袖手接合及拆層色票。原圖 13 個姿勢的帽髮檢查帶共有 96 個透明像素，修補後 30 格均為 0；複審發現的兩個袍靴單像素孔也已修正。 |
| 換裝與握點 | PASS。角色回歸 93 項，含原法杖、16×12 測試書本、卸下與重新裝備；逐一核對 30 姿勢 × 兩種鏡像 × 0°／33°／55° 下的握點與發光位置。書本是測試圖，不是正式素材。 |
| 回歸 | PASS。接縫 126、角色 93、場景 292、HUD 19、光點 13、元素邏輯 19，共 562 項。 |
| 真實畫面與動態 | PASS（錄製與逐格檢視）。`tools/capture.sh` 產出四時段、滿佇列與夜間施法六張新圖，均已實際檢視。另以真實主場景和 `move_input` 錄製 150 格、約 6.3 秒，檢視其中 34 種姿勢／方向組合及前景遮擋；帽髮接縫與握杖正常。[實際遊戲動態](screenshots/mage_motion.webp)・[修補前後](screenshots/mage_seams_comparison.png)・[30 格合成圖集](screenshots/mage_motion_sheet.png)。操作手感與手機實機 NOT RUN。 |
| 正式魔導書素材／戰鬥差異 | NOT RUN。本輪建立可替換外觀介面；正式魔導書造型、攻擊與技能規則尚未製作。 |

## 角色畫面修正（2026-11-19，納入本版）

接手時已有俯角補償、補光與腳步的未提交修改。本輪依 Harvey 指示完成修正，並依他選定的「保留四方向、6 格走路」重做動畫。紙片以腳底為軸垂直拉長 1/cos(pitch)，水平像素保留 1.20/32 公尺。33° 時垂直倍率約 1.192，站立紙片高約 1.97 公尺，中心投影等效高度約 1.65 公尺。俯角每幀由 `main.gd` 傳入，調整後杖光立即重新定位。透視與螢幕取樣仍需實際看圖。

補光為 0.3。正面、背面與側面統一按水平朝向鏡像，方向正規化後水平分量超過 0.12 才切換左右。圖集是 10 欄 × 3 列，每列 3 個呼吸姿勢、1 格眨眼與 6 格跑步。呼吸週期 0.8 秒，每 3.2 秒眨眼。預設跑步 18 fps，步頻按實際位移速度調整，帽子與杖手比身體晚一格，衣襬與髮尾分開擺動。晶石、掌心與杖光共用每格位移資料。

| 交付 | 驗證狀態 |
| --- | --- |
| 俯角補償與補光 | PASS。實際透視投影測試涵蓋 0°、33°、55°，驗證像素比例、既定寬度、腳底接地與杖光。`tools/capture.sh` 四時段、滿佇列與夜間施法共六張截圖已產出並檢視。 |
| 左右翻面 | PASS。涵蓋淺左下、左上、側身、低幅度搖桿與垂直附近遲滯，另驗證往左走時朝右下瞄準。 |
| 回歸 | PASS。角色 81、元素邏輯 19、光點 13、HUD 19、場景 290，共 422 項。 |
| 跑步與像素素材 | PASS。30 格逐格驗證透明邊界、21 色、雙靴間隙、接地與騰空姿勢、握杖及光源位置。杖頭選擇性深色收邊、眼睫、領結與靴邊已細修。 |
| 實際動態 | PASS（錄製與逐格檢視）。以真實主場景和 `move_input` 錄下 150 張畫面，包括四格待機和每個跑步段的六個姿勢，移動時保留地面作接地參考。[村莊動態](screenshots/mage_motion.webp)・[30 格圖集](screenshots/mage_motion_sheet.png)・[前後截圖](screenshots/mage_motion_comparison.png)。前後截圖的舊畫面在眨眼格，供對照高度與接地。Harvey 操作手感驗收 NOT RUN。 |


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
godot --headless --path . --script res://tests/character_layers_test.gd
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
| 手持武器外觀與握點 | `src/player/held_weapon.gd`、`weapon_visual.gd`、`assets/weapons/amber_staff.tres` |
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
