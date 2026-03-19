# 渡魂录 SOUL FERRY — 启动调试说明

## 用 Godot 4 打开项目

1. 打开 Godot 4.x（推荐 4.2 或 4.3）
2. "Import" → 选择 `soul-ferry/project.godot`
3. 点击 "Play"（F5）或直接运行主场景

---

## 预期启动流程

```
启动
 └→ MapScene（主场景）
     ├─ GameState.new_run() 初始化
     ├─ DeckManager.init_starter_deck() 加载10张起始牌
     └─ 渲染三层地图节点

点击战斗节点(⚔)
 └→ BattleScene
     ├─ 加载敌人数据
     ├─ 渲染五边形雷达图（_draw）
     ├─ 摸5张手牌
     └─ 开始回合

出牌
 ├─ 情绪值变化 → 雷达图重绘
 ├─ 敌人HP变化
 └─ 费用扣减

结束回合
 ├─ 敌人行动
 ├─ 情绪衰减
 └─ 下一回合摸牌

战斗结束
 └→ 返回 MapScene
```

---

## 常见报错及处理

### ❌ "Node not found: $UI/HUD/CostLabel"
**原因**: tscn 节点名与脚本路径不匹配  
**检查**: 确认 BattleScene.tscn 里 HUD 下有 CostLabel 节点

### ❌ "Cannot call method on null"（@onready 相关）
**原因**: 场景未包含对应节点  
**处理**: 在 Godot 编辑器里手动检查节点树，或临时加 `if node:` 判断

### ❌ "CardDatabase: 无法加载 res://data/cards.json"
**原因**: 项目路径未正确设置  
**检查**: 确认 `data/` 文件夹在项目根目录（与 project.godot 同级）

### ❌ "Class 'BattleStateMachine' not found"
**原因**: GDScript 4 class_name 需要被引用才注册  
**处理**: 在 Godot 里 Project > Reload Current Project

### ⚠️ 雷达图不显示
**原因**: EmotionRadar 是 Node2D，需要在 Control 容器里设置 position  
**检查**: BattleScene.tscn 里 EmotionRadar 的 position = Vector2(110, 110)

---

## 第一次运行验证清单

- [ ] MapScene 显示三层节点
- [ ] 点击战斗节点进入 BattleScene
- [ ] BattleScene 顶部显示"第 1 回合"
- [ ] 底部有5张手牌
- [ ] 中央有五边形框架（即使情绪都是0）
- [ ] 点击手牌有缩放动画
- [ ] 点击"结束回合"回合数+1
- [ ] 敌人HP条在受到攻击后减少

如果以上都通过 → 核心循环可运行，可以开始调手感 ✅
