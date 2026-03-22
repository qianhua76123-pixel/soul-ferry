extends Node
## DiscardSystem.gd - 弃牌机制 + 情绪碎片系统
## Autoload 单例，注册名 "DiscardSystem"

signal shard_gained(shard_type: String, amount: int)
signal shard_resonance_triggered(shard_type: String)
signal shards_cleared()

# ── 碎片存储 ──────────────────────────────────────────
const SHARD_TYPES: Array[String] = [
	"bei", "ju", "nu", "xi", "ding",   # 五情碎片
	"seal", "chain", "void",            # 专属碎片
	"spirit", "echo"                    # 灵气/残响碎片
]
const SHARD_CAP: int = 20             # 每种碎片上限

var shards: Dictionary = {
	"bei": 0, "ju": 0, "nu": 0, "xi": 0, "ding": 0,
	"seal": 0, "chain": 0, "void": 0,
	"spirit": 0, "echo": 0
}

# 碎片共鸣激活标记（溢出时触发，本场战斗有效）
var resonance_active: Dictionary = {}

# ── 初始化 ─────────────────────────────────────────────
func _ready() -> void:
	DeckManager.card_discarded.connect(_on_card_discarded)

func clear_run_shards() -> void:
	## 局外清零（新局开始时调用）
	for k in SHARD_TYPES:
		shards[k] = 0
	resonance_active.clear()
	shards_cleared.emit()

# ── 核心：弃牌事件处理 ────────────────────────────────
func _on_card_discarded(card: Dictionary, is_forced: bool) -> void:
	var multiplier: int = 1 if is_forced else 2   # 主动弃=×2，被动/强制=×1

	# 升级牌（level>0）额外×2
	if card.get("level", 0) > 0:
		multiplier *= 2

	# 确定碎片类型
	var shard_type: String = _card_to_shard_type(card)
	_add_shard(shard_type, multiplier)

	# 三角色专属弃牌附加效果（仅主动弃牌）
	if not is_forced:
		var char_id: String = str(GameState.get_meta("selected_character", ""))
		match char_id:
			"ruan_ruyue":   _ruyue_discard_bonus(card)
			"shen_tiejun":  _tiejun_discard_bonus(card)
			"wumian":       _wumian_discard_bonus()

# ── 碎片类型映射 ──────────────────────────────────────
func _card_to_shard_type(card: Dictionary) -> String:
	var etype: String = card.get("effect_type", "")
	var emotion: String = card.get("emotion_tag", "")
	var char_c: String = card.get("character", "shared")

	# 专属碎片
	if "seal" in etype or "mark" in etype or etype == "apply_mark_and_heal":
		return "seal"
	if "chain" in etype or etype in ["chain_and_shield", "attack_by_shield"]:
		return "chain"
	if "emptiness" in etype or "void" in etype or char_c == "wumian":
		return "void"

	# 残响碎片（升级牌额外产出，此处按标签 echo 判断，升级牌在外层 ×2 已处理）
	if card.get("level", 0) > 0:
		return "echo"

	# 五情碎片
	match emotion:
		"grief": return "bei"
		"fear":  return "ju"
		"rage":  return "nu"
		"joy":   return "xi"
		"calm":  return "ding"

	return "spirit"  # 无情绪标签 → 灵气碎片

# ── 碎片增加 + 溢出检测 ───────────────────────────────
func _add_shard(shard_type: String, amount: int) -> void:
	if shard_type not in shards:
		return
	var prev: int = shards[shard_type]
	shards[shard_type] = mini(prev + amount, SHARD_CAP)
	var actual: int = shards[shard_type] - prev
	if actual > 0:
		shard_gained.emit(shard_type, actual)

	# 溢出 → 碎片共鸣
	if shards[shard_type] >= SHARD_CAP and not resonance_active.get(shard_type, false):
		resonance_active[shard_type] = true
		shard_resonance_triggered.emit(shard_type)

# ── 三角色专属弃牌加成 ────────────────────────────────

func _ruyue_discard_bonus(card: Dictionary) -> void:
	## 印散：弃牌后随机对一个敌人施加对应情绪印记×1
	var emotion: String = card.get("emotion_tag", "")
	if emotion.is_empty() or emotion == "none":
		# 无情绪标签 → 随机印记
		var all_emotions: Array[String] = ["grief", "fear", "rage", "joy", "calm"]
		emotion = all_emotions[randi() % all_emotions.size()]
	# 通过信号通知 BattleStateMachine 对随机敌人施加印记
	# BattleScene 监听此信号
	_emit_ruyue_seal_bonus(emotion)

func _tiejun_discard_bonus(card: Dictionary) -> void:
	## 余怒：根据弃牌标签执行不同效果
	var emotion: String = card.get("emotion_tag", "")
	var etype: String = card.get("effect_type", "")
	if emotion == "rage":
		_emit_tiejun_rage_bonus()
	elif "chain" in etype:
		_emit_tiejun_chain_bonus()
	elif etype in ["shield", "shield_attack", "shield_and_draw", "shield_and_emotion",
				   "reflect_next_damage", "shield_regen_on_hit", "persistent_shield"]:
		EmotionManager.modify("calm", 1)

func _wumian_discard_bonus() -> void:
	## 空流：弃牌后空度+1，若进入新分段触发进入奖励
	if not WumianManager.is_wumian_active:
		return
	var prev_tier: int = WumianManager.current_tier
	WumianManager.modify_emptiness(1)
	var new_tier: int = WumianManager.current_tier
	if new_tier != prev_tier:
		_apply_wumian_tier_bonus(new_tier)

func _apply_wumian_tier_bonus(tier: int) -> void:
	match tier:
		0:  GameState.heal(3)                               # 进入低段：回复3HP
		1:  DeckManager.draw_cards(1)                       # 进入中段：抽1张
		2:  _emit_wumian_energy_bonus()                     # 进入高段：+1能量
		3:  _emit_wumian_free_card_bonus()                  # 进入极高段：下一张牌免费

# ── 信号发射（BattleScene/BattleStateMachine 响应） ────
signal ruyue_seal_bonus_requested(emotion: String)
signal tiejun_rage_bonus_requested()
signal tiejun_chain_bonus_requested()
signal wumian_energy_bonus_requested()
signal wumian_free_card_bonus_requested()

func _emit_ruyue_seal_bonus(emotion: String) -> void:
	ruyue_seal_bonus_requested.emit(emotion)

func _emit_tiejun_rage_bonus() -> void:
	tiejun_rage_bonus_requested.emit()

func _emit_tiejun_chain_bonus() -> void:
	tiejun_chain_bonus_requested.emit()

func _emit_wumian_energy_bonus() -> void:
	wumian_energy_bonus_requested.emit()

func _emit_wumian_free_card_bonus() -> void:
	wumian_free_card_bonus_requested.emit()

# ── 公共查询 API ──────────────────────────────────────

func get_shard(shard_type: String) -> int:
	return shards.get(shard_type, 0)

func has_shards(cost_dict: Dictionary) -> bool:
	## 检查碎片是否满足消耗要求
	for k in cost_dict:
		if shards.get(k, 0) < int(cost_dict[k]):
			return false
	return true

func spend_shards(cost_dict: Dictionary) -> bool:
	## 消耗碎片（锻造/升级用）
	if not has_shards(cost_dict):
		return false
	for k in cost_dict:
		shards[k] -= int(cost_dict[k])
		resonance_active[k] = false  # 消耗后解除共鸣
	return true

func is_resonance_active(shard_type: String) -> bool:
	return resonance_active.get(shard_type, false)

func get_resonance_bonus(shard_type: String) -> float:
	## 共鸣激活时对应情绪牌效果+15%
	return 0.15 if is_resonance_active(shard_type) else 0.0
