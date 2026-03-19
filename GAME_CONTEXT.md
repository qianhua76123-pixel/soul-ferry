# 渡魂录 SOUL FERRY — 项目上下文文档

> 每次开启新的 AI 对话时，请先读取本文件。
> 标准开场：「请先读取 GAME_CONTEXT.md，然后再回答。当前任务：[具体任务描述]」

---

## 项目概述

| 参数 | 内容 |
|------|------|
| 游戏名 | 渡魂录 SOUL FERRY |
| 类型 | Roguelite Deckbuilder |
| 引擎 | Godot 4.x / GDScript |
| 平台 | PC（Windows/Mac） |
| 开发周期 | 8周 Solo + AI 辅助 |
| 美术风格 | 剪纸·水墨，黑红金三色 |

---

## 核心系统

### 五情系统（EmotionManager）

五情：怒(rage)、惧(fear)、悲(grief)、喜(joy)、定(calm)

- 情绪值范围：0～5，不可溢出
- 主导情绪 = 当前最高情绪（同值保持上一状态）
- 定不参与主导竞争，独立计算
- 每回合结束：非主导情绪自然衰减-1

**失调条件（≥4触发）：**
- 怒≥4：无法打出防御/定类牌
- 惧≥4：回合开始随机弃1张
- 悲≥4：无法使用任何回复牌
- 喜≥4：敌人伤害全场×1.2
- 定：无失调，但无情绪增幅

**增幅效果：**
- 怒主导：攻击牌伤害×1.3
- 惧主导：摸牌类牌+2张
- 悲主导：吸取效果×1.5
- 喜主导：恢复/增幅效果×1.5
- 定≥3：所有牌费用-1

### 牌库系统（DeckManager）

- 初始牌库：10张
- 手牌上限：10张
- 每回合起手：5张（惧失调时-1）
- 每回合费用：3点（定≥3时-1）

### 双路线系统

- **镇压路线**：纯战斗解决，奖励随机牌卡+材料
- **渡化路线**：理解执念、使用特定情绪组合化解，奖励更丰厚

---

## 代码架构

### Autoload（单例）
```
EmotionManager    # 五情状态机
DeckManager       # 牌库管理
CardDatabase      # 牌卡数据库（从JSON加载）
GameState         # 游戏状态/存档
```

### 场景
```
BattleScene    # 战斗
MapScene       # 地图导航
EventScene     # 民俗事件
ShopScene      # 商店
```

### 数据文件
```
res://data/cards.json     # 牌卡数据
res://data/enemies.json   # 敌人数据（含渡化条件）
res://data/events.json    # 民俗事件
res://data/relics.json    # 遗物/法器
```

---

## 命名规范

| 类型 | 规范 | 示例 |
|------|------|------|
| 变量 | snake_case | `current_hp`, `emotion_value` |
| 函数 | snake_case | `apply_damage()`, `check_disorder()` |
| 信号 | snake_case | `emotion_changed`, `card_played` |
| 常量 | UPPER_SNAKE | `MAX_VALUE`, `BASE_COST` |
| 类名 | PascalCase | `EmotionManager`, `CardDatabase` |
| 场景节点 | PascalCase | `BattleScene`, `EnemyHPBar` |

---

## 情绪枚举值（英文）

| 中文 | 英文键 | 颜色 |
|------|--------|------|
| 怒 | rage | #8B1A1A 朱红 |
| 惧 | fear | #4B0082 深紫 |
| 悲 | grief | #1A3A6B 幽蓝 |
| 喜 | joy | #B8860B 暖金 |
| 定 | calm | #E8E0D0 素白 |

---

## 牌卡数据结构

```json
{
  "id": "zhenhunfu",
  "name": "镇魂符",
  "emotion_tag": "calm",
  "cost": 1,
  "effect_type": "shield",
  "effect_value": 8,
  "condition": "calm >= 3",
  "condition_bonus": 4,
  "emotion_shift": {"calm": 1},
  "rarity": "common",
  "description": "获得8点护盾，若定≥3额外获得4点"
}
```

**effect_type 枚举：**
- `attack` — 攻击单体
- `attack_all` — 攻击全体
- `shield` — 获得护盾
- `heal` — 回复HP
- `draw` — 摸牌
- `weaken` — 施加削弱
- `reset_shield` — 五情归一护盾
- `du_hua_trigger` — 触发渡化判定
- `du_hua_progress` — 推进渡化进度
- `dot_and_weaken` — 持续伤害+削弱
- `dodge_attack` — 闪避+攻击
- `buff_all_cards` — 增幅本回合所有牌

---

## 敌人数据结构

```json
{
  "id": "enemy_id",
  "name": "敌人名称",
  "type": "normal | boss",
  "layer": 1,
  "hp": 80,
  "emotion_pressure": [{"emotion": "grief", "value": 2}],
  "actions": [
    {"type": "attack", "value": 12, "weight": 40}
  ],
  "du_hua_condition": {
    "type": "card_play | dialogue_choice | consecutive_joy_cards",
    "card_id": "yin_du",
    "emotion_requirement": {"grief": 3},
    "description": "渡化条件文字描述"
  }
}
```

---

## 三层地图

| 层级 | 地点 | 主题情绪 | Boss |
|------|------|----------|------|
| 第一层 | 荒村 | 悲·惧 | 水鬼·望归 |
| 第二层 | 古祠 | 怒·定 | 旱魃·焦骨 |
| 第三层 | 幽冥渡口 | 喜·定 | 鬼新娘·素锦 |

节点类型权重：战斗50% · 事件25% · 商店15% · 休息10%

---

## 开发优先级（8周计划）

1. **第1周**：情绪系统手感验证（EmotionManager + 基础出牌逻辑）
2. **第2周**：完整单局可玩（地图+战利品+牌库构筑+基础UI）
3. **第3-4周**：60张牌 + 10个敌人 + Boss框架
4. **第5周**：渡化系统双路线
5. **第6周**：叙事氛围（事件文本+音乐+美术替换占位符）
6. **第7周**：平衡调优
7. **第8周**：Demo发布准备

---

## 数值调整说明

> **所有游戏数值在 `data/*.json` 里调整，严禁在代码中硬编码数值。**

可调参数参考：

| 参数 | 当前值 | 备注 |
|------|--------|------|
| 情绪最大值 | 5 | 越大策略空间越大 |
| 失调触发阈值 | 4 | 越低越紧张 |
| 回合情绪衰减 | -1（非主导） | 0=永久累积 |
| 每回合费用 | 3 | 影响出牌数量 |
| 定≥3费用减免 | -1 | 定路线核心收益 |

---

## AI 辅助开发规则

使用 Trae/Cursor/Claude 时必须遵守：

1. **每次新对话必须先读取本文件**
2. GDScript 4.x 语法（非 GDScript 2.x）
3. 中文注释，英文变量名
4. 信号（Signal）优先于直接函数调用
5. 数值从 JSON 读取，严禁硬编码
6. 命名符合本文件规范
7. 新功能完成后更新本文件相关部分
