## Last Daily Summary
2026-04-01T06:03:00+08:00

## 项目：渡魂录 SOUL FERRY

- repo: https://github.com/qianhua76123-pixel/soul-ferry.git
- 引擎：Godot 4.6 / GDScript 4 严格模式（warnings as errors）
- HEAD（截至2026-03-24晚）: 9729f3f

### 已完成模块（截至2026-03-23）
- 核心战斗循环（BattleStateMachine + BattleScene）
- 五情情绪系统（EmotionManager）+ 失控机制生效（怒/悲限牌）
- 遗物系统（RelicManager，共34件，获取有Toast提示）
- 卡牌系统（CardDatabase，共80张+无名28张）
- 地图/商店/事件/休息/结局场景
- 3个Boss + 完整渡化/镇压对话
- 双角色协作模式框架（CoopBattleStateMachine，入口隐藏）
- 无面人第三角色·空系统（空度进度条+空鸣弹窗+镜·无我）
- 阮如月印记UI（敌人身上实时显示层数+共鸣高亮）
- 沈铁钧锁链系统（攻击削弱+5层镇压+衰减+HUD）
- 程序化音效（26种SFX + 五声音阶BGM，无外部文件）
- 锻造工坊（左右分栏，金币三选项）
- 休整场景（回复/升级/移除牌三选项）
- 107处Variant警告清理，代码干净编译

### 已删除/简化（2026-03-23）
- 问路香遗物（UI按钮删除，数据保留）
- 主动弃牌功能（保留被动弃牌）
- 碎片系统（DiscardSystem保留角色被动信号，积累/消耗/UI全删）
- ForgeSystem只保留金币基础锻造（strong/cost/extend）

### 关键技术约束
- 所有 var 必须有类型注解（get_node_or_null → `: Node =`）
- 中文注释，英文变量名
- 信号优先于直接函数调用
- 所有值从 JSON 读取，不硬编码

### 子agent工作流
- 每次功能迭代用 `sessions_spawn(agentId="mulerun", runtime="subagent")` 启动
- 任务完成后自动推送并发回 `AGENT_X_DONE: <hash>`
- 可并行启动多个子agent（今天最多同时跑3个）
- 大任务可并行：互不依赖的模块同时交给不同agent

### 2026-03-27 工作记录

**Bug 检索（全量）**
- 扫描所有 .gd 文件，输出 17 个 bug，按 P0/P1/P2/P3 分级
- P0：锁链跳过逻辑变量用错（next_intent vs 当前回合）、enemy_hp 类型 int/float 混用、铁甲覆体 _shield_no_expire_flag 未设置
- P1：五情结费用战斗间泄漏、印记高亮阈值硬编码、discard_from_hand 方法不存在、跨角色 seal_bonus 信号未过滤
- P2：渡化UI未同步（已知）、遗物图标不完整、get_card_data 方法不存在导致抖动反馈失效、定共鸣费用不通知UI
- P3：_check_du_hua -1阶段兜底漏洞、一念弃牌触发跨角色被动

**渡化系统重写（fix commit: ebafc45）**
- 问题根源：三条路径相互脱节（三阶段frequency窗口 / 旧emotion_threshold兜底被绕过 / PurificationPanel按钮守卫死锁）
- 解决：废弃三阶段frequency窗口机制，改为直接读 du_hua_condition.emotion_requirement
- frequency 仅影响渡化品质计算（minimal/stable/perfect），不再作为触发前置条件
- PurificationPanel：增加 _state_machine_confirmed 双轨激活 + 修复 _cond_items 为空时 all_met 默认 true 的 bug
- 渡化超时中断：5回合未确认→中断惩罚（原3回合，且计时逻辑已修正）
- Boss 渡化对话改为由 state_machine.du_hua_triggered 驱动

### 待处理（更新）
- 锁链跳过逻辑（P0，next_intent变量错误）
- discard_from_hand 不存在（P1，draw_player 行动会崩溃）
- 五情结费用战斗间泄漏（P1）
- 印记高亮阈值硬编码（P2）
- 遗物图标不完整（P2）
- 双人模式 CoopBattleScene UI
- CharacterPortrait 首帧延迟小 bug
- 真实 ogg 音频文件接入


### 2026-03-24 新增/变更（难度重设计 v2.0）
- 生成 docs/design_numbers.md（697行，全量数值提取文档，14章）
- EmotionManager：情绪上限5→6，三级失调（≥4/≥5/=6），定≥5时其他四情+1，衰减节奏分化
- BattleStateMachine：渡化机制完全重写（窗口系统+三阶段+分级惩罚），护盾改为回合末减半，执念计数器（0-5），跨战斗情绪余韵
- enemies.json：普通怪HP/攻击全面强化（+50-70%），Boss HP上调，新增独立phase_2_actions数组
- characters.json：三角色起始HP各-5（如月75/铁钧95/无名55）
- GameState.gd：new_run()改为从characters.json动态读角色HP
- RestScene.gd：回血30%→20%
- 新增遗物字段：dominant_emotion/obsession_init/purification_window_gain

### 已知问题（2026-03-24）
- 渡化新条件（三阶段+情绪共振）未同步到 BattleScene UI（玩家无法看到窗口状态）
- design_numbers.md 部分数值基于旧代码（v1.0），需要同步更新为v2.0数值
