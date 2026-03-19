## RelicManager 验证清单（在 Godot Output 面板确认）
## 把此文件挂到任意临时 Node 的 _ready() 测试后删除

## 触发方式对照表：
##
## 遗物ID            | 触发时机                       | 预期输出（relic_triggered 信号）
## ─────────────────────────────────────────────────────────────────
## tong_jing_sui    | BattleScene._on_battle_started | "铜镜碎片感知到：敌人情绪以 X 为主"
## shaogu_pian      | BattleScene._on_battle_ended(victory) | "+2护盾"
## qingming_pai     | on_turn_start() + 定=0         | "清明牌：定 +1"
## wuqing_jie       | on_hand_updated + 五情全>0     | "五情结：费用上限 +1"
## yin_yang_bi      | DeckManager.card_played (定牌) | "阴阳笔：X +1"
## hun_bo_lu        | on_turn_start()                | "魂魄炉：「牌名」费用 -1"
## si_xiang_pian    | EmotionManager.悲≥3            | "思乡片：回复 5 HP"
## duhun_ce         | BattleScene.on_du_hua_success  | "渡魂册：最大HP +3"
## wenlu_xiang      | use_wenlu_xiang() 手动调用     | "问路香：感知敌人意图"
## nianhua_yan      | use_nianhua_yan() 手动调用     | "年画眼：看清事件真相"
##
## 检查要点：
## 1. project.godot Autoload 顺序：EmotionManager→CardDatabase→DeckManager→GameState→RelicManager
## 2. RelicManager._ready() 中信号连接顺序正确（DeckManager 在 GameState 之前 ready）
## 3. new_run() 后 RelicManager.active_relics 长度应为 3（三件初始遗物）
