# elemental-hd2d-godot

手機橫向、斜俯視的元素組招動作冒險。Godot 4.7、GDScript、Forward+。

```bash
godot --path .          # 開始玩（WASD 移動、1–4 加元素、F 融合、空白鍵施放、F1–F4 切時段）
godot --path . -- --scene=forest  # village／forest／snow／dungeon
```

F5–F8 分別切換村莊、森林河谷、雪原吊橋、地下城大廳。這些是畫面與操作原型，尚未加入敵人或正式傷害系統。

首次下載後先用 Godot 4.7.2 開啟 `project.godot`，或執行 `godot --headless --path . --editor --import --quit` 匯入素材。角色與世界貼圖由 `tools/gen_character.gd`、`tools/gen_textures.gd` 產生，修改造型時重跑產生器。

角色身邊每顆光點代表一個待發元素。連按兩次同一個圖示會出現兩顆同色光點；水與火按融合後變成一顆蒸氣光點。[遊戲內操作動畫](docs/screenshots/iteration4_mage_orbit.webp)

- 規則與架構：[docs/BLUEPRINT.md](docs/BLUEPRINT.md)
- 進度與下一步：[docs/HANDOFF.md](docs/HANDOFF.md)
- 玩法規則：[docs/design/rules.md](docs/design/rules.md)
- 目前畫面：[docs/screenshots/](docs/screenshots/)
