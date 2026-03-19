extends Node

## RelicManager.gd - 遗物运行时系统（第5个 Autoload 单例）
## 注意：不要加 class_name，否则与 autoload 同名冲突

signal relic_triggered(relic_id: String, effect_desc: String)

# ── 当前持有的遗物数据（从 relics.json 加载的完整 Dict）
var active_relics: Array = []

# ── 各遗物的内部状态
var _wenlu_used_this_battle: bool  = false   # 问路香：每战一次
var _sixiang_triggered_this_turn: bool = false  # 思乡片：每回合一次
var _wuqing_bonus_active: bool    = false   # 五情结：附加费用状态

# ── 所有遗物原始数据缓存（从 JSON 加载）
var _all_relics_data: Dictionary = {}

# ════════════════════════════════════════════
#  初始化
# ════════════════════════════════════════════
func _ready() -> void:
	_load_relic_data()
	# 连接已有信号
	DeckManager.card_played.connect(_on_card_played)
	DeckManager.hand_updated.connect(_on_hand_updated)
	EmotionManager.emotion_changed.connect(_on_emotion_changed)
	EmotionManager.dominant_changed.connect(_on_dominant_changed)
	EmotionManager.emotions_reset.connect(_on_emotions_reset)
	GameState.relic_added.connect(_on_relic_added_by_gamestate)

func _load_relic_data() -> void:
	var file = FileAccess.open("res://data/relics.json", FileAccess.READ)
	if not file:
		push_error("RelicManager: 无法打开 relics.json"); return
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("RelicManager: JSON 解析失败"); file.close(); return
	file.close()
	for relic in json.get_data().get("relics", []):
		_all_relics_data[relic.get("id", "")] = relic

# ════════════════════════════════════════════
#  公共 API
# ════════════════════════════════════════════
func add_relic(relic_id: String) -> void:
	if has_relic(relic_id): return
	var data = _all_relics_data.get(relic_id, {})
	if data.is_empty():
		push_warning("RelicManager: 未知遗物 ID: " + relic_id); return
	active_relics.append(data.duplicate(true))
	relic_triggered.emit(relic_id, "获得遗物：" + data.get("name","???"))

func remove_relic(relic_id: String) -> void:
	for i in len(active_relics):
		if active_relics[i].get("id","") == relic_id:
			active_relics.remove_at(i); return

func has_relic(relic_id: String) -> bool:
	for r in active_relics:
		if r.get("id","") == relic_id: return true
	return false

func get_relic_names() -> Array:
	return active_relics.map(func(r): return r.get("name","???"))

# 战斗开始时由 BattleScene 调用
func on_battle_start(enemy_data: Dictionary) -> void:
	_wenlu_used_this_battle = false
	_effect_tong_jing_sui_on_battle_start(enemy_data)

# 回合开始时由 BattleScene 调用
func on_turn_start() -> void:
	_sixiang_triggered_this_turn = false
	_effect_qingming_pai_on_turn_start()
	_effect_hun_bo_lu_on_turn_start()
	_update_wuqing_jie()   # 回合开始也检查一次五情结

# 回合结束时由 BattleScene 调用
func on_turn_end() -> void:
	pass

# 镇压胜利时由 BattleScene 调用
func on_victory_zhenya() -> void:
	_effect_shaogu_pian_on_zhenya()

# 渡化成功时已由 GameState.record_du_hua() 处理（+3max_hp）
# 此处额外触发动画信号
func on_du_hua_success() -> void:
	if has_relic("duhun_ce"):
		relic_triggered.emit("duhun_ce", "渡魂册：最大HP +3")

# ════════════════════════════════════════════
#  信号响应
# ════════════════════════════════════════════
func _on_relic_added_by_gamestate(relic_id: String) -> void:
	add_relic(relic_id)

func _on_card_played(card: Dictionary) -> void:
	_effect_yin_yang_bi_on_card_played(card)

func _on_hand_updated(_hand: Array) -> void:
	# 检查五情结的额外费用加成（手牌更新后重算）
	_update_wuqing_jie()

func _on_emotion_changed(emotion: String, _old: int, new_val: int) -> void:
	# 思乡片：悲≥3自动回血
	if emotion == "grief" and new_val >= 3:
		_effect_sixiang_pian_on_grief()

func _on_dominant_changed(_old: String, _new: String) -> void:
	pass

func _on_emotions_reset() -> void:
	_wuqing_bonus_active = false

# ════════════════════════════════════════════
#  遗物效果实现
# ════════════════════════════════════════════

## 铜镜碎片 — 战斗开始时显示敌人主导情绪（信息型，不影响数值）
func _effect_tong_jing_sui_on_battle_start(enemy_data: Dictionary) -> void:
	if not has_relic("tong_jing_sui"): return
	var dominant = enemy_data.get("dominant_emotion", "")
	if dominant != "":
		relic_triggered.emit("tong_jing_sui",
			"铜镜碎片感知到：敌人情绪以「%s」为主" % EmotionManager.get_emotion_name(dominant))

## 烧骨片 — 镇压后获得2护盾（通过信号通知 BattleScene）
func _effect_shaogu_pian_on_zhenya() -> void:
	if not has_relic("shaogu_pian"): return
	# "shaogu_pian_shield_2" 是 BattleScene 识别的特殊 relic_id，用于直接加护盾
	relic_triggered.emit("shaogu_pian_shield_2", "烧骨片：护盾 +2")

## 清明牌 — 回合开始，定=0时自动+定1
func _effect_qingming_pai_on_turn_start() -> void:
	if not has_relic("qingming_pai"): return
	if EmotionManager.values.get("calm", 0) == 0:
		EmotionManager.modify("calm", 1)
		relic_triggered.emit("qingming_pai", "清明牌：定 +1")

## 五情结 — 五情全部>0时，额外+1费（修改 DeckManager.max_cost）
func _update_wuqing_jie() -> void:
	if not has_relic("wuqing_jie"): return
	var all_positive = true
	for emotion in EmotionManager.EMOTIONS:
		if EmotionManager.values[emotion] == 0:
			all_positive = false; break
	if all_positive and not _wuqing_bonus_active:
		DeckManager.max_cost += 1
		DeckManager.current_cost = min(DeckManager.current_cost + 1, DeckManager.max_cost)
		_wuqing_bonus_active = true
		relic_triggered.emit("wuqing_jie", "五情结：费用上限 +1")
	elif not all_positive and _wuqing_bonus_active:
		DeckManager.max_cost = max(DeckManager.BASE_COST, DeckManager.max_cost - 1)
		_wuqing_bonus_active = false

## 阴阳笔 — 打出定类牌时，随机为另一情绪+1（不超过3，不触发失调）
func _effect_yin_yang_bi_on_card_played(card: Dictionary) -> void:
	if not has_relic("yin_yang_bi"): return
	if card.get("emotion_tag","") != "calm": return
	var others = ["rage","fear","grief","joy"]
	others.shuffle()
	for emotion in others:
		if EmotionManager.values[emotion] < 3:   # 上限3，不触发失调
			EmotionManager.modify(emotion, 1)
			relic_triggered.emit("yin_yang_bi",
				"阴阳笔：%s +1" % EmotionManager.get_emotion_name(emotion))
			return

## 魂魄炉 — 每回合开始时随机降低一张手牌费用1点
func _effect_hun_bo_lu_on_turn_start() -> void:
	if not has_relic("hun_bo_lu"): return
	if DeckManager.hand.is_empty(): return
	var hand = DeckManager.hand
	var target_idx = randi() % len(hand)
	var card = hand[target_idx]
	var old_cost = card.get("cost", 0)
	if old_cost > 0:
		hand[target_idx]["cost"] = old_cost - 1
		DeckManager.hand_updated.emit(DeckManager.hand)
		relic_triggered.emit("hun_bo_lu",
			"魂魄炉：「%s」费用 -1" % card.get("name","???"))

## 思乡片 — 悲≥3时自动回复5HP（每回合最多一次）
func _effect_sixiang_pian_on_grief() -> void:
	if not has_relic("si_xiang_pian"): return
	if _sixiang_triggered_this_turn: return
	_sixiang_triggered_this_turn = true
	GameState.heal(5)
	relic_triggered.emit("si_xiang_pian", "思乡片：回复 5 HP")

## 问路香 — 每战一次，预览敌人意图（在 BattleScene 调用 use_wenlu_xiang()）
func use_wenlu_xiang() -> bool:
	if not has_relic("wenlu_xiang"): return false
	if _wenlu_used_this_battle: return false
	_wenlu_used_this_battle = true
	relic_triggered.emit("wenlu_xiang", "问路香：感知敌人意图")
	return true

## 年画眼 — 事件预览（一局一次），由 EventScene 查询
var nianhua_used_this_run: bool = false
func use_nianhua_yan() -> bool:
	if not has_relic("nianhua_yan"): return false
	if nianhua_used_this_run: return false
	nianhua_used_this_run = true
	relic_triggered.emit("nianhua_yan", "年画眼：看清事件真相")
	return true
