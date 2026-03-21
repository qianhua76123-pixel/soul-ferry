class_name CoopManager
extends Node
## 协作模式管理器（Autoload，仅在协作模式激活时有效）
## 负责协同遗物加载、协同状态同步、回合级临时加成管理

# ── 信号 ─────────────────────────────────────────────────
signal coop_mode_started
signal coop_mode_ended

# ── 模式激活标志 ─────────────────────────────────────────
var is_coop_active: bool = false

# ── 玩家分配 ─────────────────────────────────────────────
## 本地玩家1控制阮如月
var ruan_player_id: int = 1
## 本地玩家2控制沈铁钧（或AI控制）
var shen_player_id: int = 2

# ── 协同遗物列表（从 coop_relics.json 加载） ─────────────
var coop_relics: Array = []

# ── 协同状态（由 CoopBattleStateMachine 更新） ───────────
## 沈铁钧锁链伤害加成（印记引爆累积）
var shen_chain_damage_bonus: float = 0.0
## 沈铁钧下次锁链溅射伤害翻倍标记
var shen_next_splash_double: bool  = false
## 沈铁钧施锁后阮如月本回合印记牌效率+1层（累积值）
var ruan_mark_efficiency_bonus: int = 0
## 沈铁钧怒爆后阮如月本回合所有印记牌降费（累积值）
var ruan_card_cost_reduction: int   = 0


# ────────────────────────────────────────────────────────
# 公开方法
# ────────────────────────────────────────────────────────

func activate_coop_mode() -> void:
	## 激活协作模式，加载协同遗物并发出信号
	if is_coop_active:
		push_warning("CoopManager: 协作模式已处于激活状态")
		return
	is_coop_active = true
	load_coop_relics()
	reset_turn_bonuses()
	coop_mode_started.emit()


func deactivate_coop_mode() -> void:
	## 关闭协作模式，清空所有协同状态
	if not is_coop_active:
		return
	is_coop_active              = false
	coop_relics                 = []
	shen_chain_damage_bonus     = 0.0
	shen_next_splash_double     = false
	ruan_mark_efficiency_bonus  = 0
	ruan_card_cost_reduction    = 0
	coop_mode_ended.emit()


func load_coop_relics() -> void:
	## 从 res://data/coop_relics.json 加载协同专属遗物数据
	var file: FileAccess = FileAccess.open("res://data/coop_relics.json", FileAccess.READ)
	if not file:
		push_error("CoopManager: 无法打开 res://data/coop_relics.json")
		return
	var raw_text: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result: int = json.parse(raw_text)
	if parse_result != OK:
		push_error("CoopManager: 解析 coop_relics.json 失败，错误行: " + str(json.get_error_line()))
		return

	var data: Variant = json.get_data()
	if data is Dictionary:
		coop_relics = data.get("coop_relics", [])
	else:
		push_error("CoopManager: coop_relics.json 格式错误，根节点应为 Dictionary")
		coop_relics = []


func has_coop_relic(relic_id: String) -> bool:
	## 检查当前协作战斗是否持有指定协同遗物
	if not is_coop_active:
		return false
	for relic: Dictionary in coop_relics:
		if relic.get("id", "") == relic_id:
			return true
	return false


func reset_turn_bonuses() -> void:
	## 每回合开始时清空所有回合级临时协同加成
	shen_chain_damage_bonus    = 0.0
	shen_next_splash_double    = false
	ruan_mark_efficiency_bonus = 0
	ruan_card_cost_reduction   = 0
