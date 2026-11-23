# elemental-hd2d-godot

動手前依序讀這兩份，並嚴格照做：

1. [docs/BLUEPRINT.md](docs/BLUEPRINT.md)：美術硬規則、架構、驗收指令。違反就是 bug。
2. [docs/HANDOFF.md](docs/HANDOFF.md)：目前進度、已知問題、下一步的順序、踩過的坑。

修改主角、製作角色素材或產生概念圖時，接著讀 [角色美術 harness：B「極致 Q 版」](docs/harness/MAGE_B.md)。沿用其中的 B 原稿、Crusaders Quest 像素畫設定、生成提示詞與 Godot 驗收方式。

修改 HUD、元素配裝、傳送門或祭壇互動時，接著讀 [元素 HUD 與祭壇操作 harness](docs/harness/ELEMENT_HUD.md)。

做完更新 HANDOFF 的進度表，`PASS`／`FAIL`／`NOT RUN` 分清楚。改了畫面就要跑 `tools/capture.sh` 並實際看圖。

玩法規則來源：[docs/design/rules.md](docs/design/rules.md)。標「草案」「待定」的項目不要自己決定，問 Harvey。
