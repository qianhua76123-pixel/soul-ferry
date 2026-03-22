extends Node
## DiscardSystem.gd - 弃牌机制 + 角色被动触发
## Autoload 单例，注册名 "DiscardSystem"
## 碎片系统已删除（SHARD_TYPES/shards/resonance_active 等已移除）
## 保留：card_discarded 信号响应、三角色弃牌被动效果信号

# ── 碎片系统信号已删除 ──────────────────────────────────
# signal shard_gained(shard_type: String, amount: int)      # 已删除
# signal shard_resonance_triggered(shard_type: String)      # 已删除
# signal shards_cleared()                                   # 已删除

# ── 初始化 ─────────────────────────────────────────────
func _ready() -> void:
	DeckManager.card_discarded.connect(_on_card_discarded)

# ── 核心：弃牌事件处理 ────────────────────────────────
func _on_card_discarded(card: Dictionary, is_forced: bool) -> void:
	# 碎片积累逻辑已删除

	# 三角色专属弃牌附加效果（仅主动弃牌时触发；
	# 注意：主动弃牌按钮已删，但保留被动弃牌触发路径）
	if not is_forced:
		var char_id: String = str(GameState.get_meta("selected_character", ""))
		match char_id:
			"ruan_ruyue":   _ruyue_discard_bonus(card)
			"shen_tiejun":  _tiejun_discard_bonus(card)
			"wumian":       _wumian_discard_bonus()

# ── 三角色专属弃牌加成 ────────────────────────────────

func _ruyue_discard_bonus(card: Dictionary) -> void:
	## 印散：弃牌后随机对一个敌人施加对应情绪印记×1
	var emotion: String = card.get("emotion_tag", "")
	if emotion.is_empty() or emotion == "none":
		# 无情绪标签 → 随机印记
		var all_emotions: Array[String] = ["grief", "fear", "rage", "joy", "calm"]
		emotion = all_emotions[randi() % all_emotions.size()]
	# 通过信号通知 BattleStateMachine 对随机敌人施加印记
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

# ── 碎片 API 已删除 ────────────────────────────────────
# func get_shard(shard_type: String) -> int: ...     # 已删除
# func has_shards(cost_dict: Dictionary) -> bool: ...  # 已删除
# func spend_shards(cost_dict: Dictionary) -> bool: ... # 已删除
# func clear_run_shards() -> void: ...               # 已删除
# func is_resonance_active(shard_type: String) -> bool: ... # 已删除
# func get_resonance_bonus(shard_type: String) -> float: ... # 已删除
