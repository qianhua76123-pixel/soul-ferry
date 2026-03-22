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
	var file: FileAccess = FileAccess.open("res://data/relics.json", FileAccess.READ)
	if not file:
		push_error("RelicManager: 无法打开 relics.json"); return
	var json := JSON.new()
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
	var data: Dictionary = _all_relics_data.get(relic_id, {})
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
	var dominant: String = enemy_data.get("dominant_emotion", "")
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
		DeckManager.current_cost = mini(DeckManager.current_cost + 1, DeckManager.max_cost)
		_wuqing_bonus_active = true
		relic_triggered.emit("wuqing_jie", "五情结：费用上限 +1")
	elif not all_positive and _wuqing_bonus_active:
		DeckManager.max_cost = maxi(DeckManager.BASE_COST, DeckManager.max_cost - 1)
		_wuqing_bonus_active = false

## 阴阳笔 — 打出定类牌时，随机为另一情绪+1（不超过3，不触发失调）
func _effect_yin_yang_bi_on_card_played(card: Dictionary) -> void:
	if not has_relic("yin_yang_bi"): return
	if card.get("emotion_tag","") != "calm": return
	var others: Array = ["rage","fear","grief","joy"]
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
	var hand: Array = DeckManager.hand
	var target_idx: int = randi() % len(hand)
	var card: Dictionary = hand[target_idx]
	var old_cost: int = card.get("cost", 0)
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

# ════════════════════════════════════════════
#  阮如月专属遗物
# ════════════════════════════════════════════

# ── 旧铜铃：施印牌触发情绪亲和效果（每类型每回合一次）
var _jiu_tong_ling_triggered: Dictionary = {}  # emotion_tag -> bool

func on_seal_card_played_ruyue(emotion_tag: String) -> void:
	if not has_relic("jiu_tong_ling"): return
	if _jiu_tong_ling_triggered.get(emotion_tag, false): return
	_jiu_tong_ling_triggered[emotion_tag] = true
	var upgraded: bool = _is_upgraded("jiu_tong_ling")
	match emotion_tag:
		"grief":
			GameState.heal(2 if upgraded else 1)
			relic_triggered.emit("jiu_tong_ling", "旧铜铃：悲印 → 回血%d" % (2 if upgraded else 1))
		"fear":
			# BattleStateMachine 读取此变量减少下次受伤
			next_damage_reduction = (4 if upgraded else 2)
			relic_triggered.emit("jiu_tong_ling", "旧铜铃：惧印 → 下次减伤%d" % next_damage_reduction)
		"rage":
			next_attack_bonus = (6 if upgraded else 3)
			relic_triggered.emit("jiu_tong_ling", "旧铜铃：怒印 → 下次攻击+%d" % next_attack_bonus)
		"joy":
			DeckManager.draw_cards(2 if upgraded else 1)
			relic_triggered.emit("jiu_tong_ling", "旧铜铃：喜印 → 抽%d张" % (2 if upgraded else 1))
		"calm":
			var bonus: int = 2 if upgraded else 1
			DeckManager.current_cost = mini(DeckManager.current_cost + bonus, DeckManager.max_cost)
			relic_triggered.emit("jiu_tong_ling", "旧铜铃：定印 → +%d费" % bonus)

var next_damage_reduction: int = 0
var next_attack_bonus:     int = 0

func consume_damage_reduction() -> int:
	var v: int = next_damage_reduction
	next_damage_reduction = 0
	return v

func consume_attack_bonus() -> int:
	var v: int = next_attack_bonus
	next_attack_bonus = 0
	return v

# ── 观音泥：战斗开始时降低共鸣阈值（由 BattleStateMachine 读取）
var guan_yin_ni_reduced_emotion: String = ""

func on_battle_start_ruyue() -> void:
	if not has_relic("guan_yin_ni"): return
	var emotions: Array = ["grief", "fear", "rage", "joy", "calm"]
	emotions.shuffle()
	guan_yin_ni_reduced_emotion = emotions[0]
	relic_triggered.emit("guan_yin_ni", "观音泥：%s印共鸣阈值降至2层" % EmotionManager.get_emotion_name(guan_yin_ni_reduced_emotion))

func get_resonance_threshold_override(emotion: String) -> int:
	# 返回该情绪的共鸣阈值（默认3，遗物可能降低）
	var threshold: int = 3
	if has_relic("guan_yin_ni") and guan_yin_ni_reduced_emotion == emotion:
		threshold = 2
	if has_relic("guanchen_zhi_jing"):
		threshold = 2  # 传说遗物：所有印记阈值降至2
	return threshold

# ── 碎镜片：五情共鸣触发时永久增加共鸣威力
var sui_jing_resonance_bonus: Dictionary = {}  # emotion -> float bonus

func on_five_resonance_triggered_ruyue() -> void:
	if not has_relic("sui_jing_pian"): return
	var upgraded: bool = _is_upgraded("sui_jing_pian")
	if upgraded:
		for emotion in EmotionManager.EMOTIONS:
			sui_jing_resonance_bonus[emotion] = sui_jing_resonance_bonus.get(emotion, 0.0) + 0.02
		relic_triggered.emit("sui_jing_pian", "碎镜片：所有印记共鸣威力各+2%")
	else:
		# 找最高情绪
		var top_emotion: String = "grief"
		var top_val: int = 0
		for e in EmotionManager.EMOTIONS:
			if EmotionManager.values.get(e, 0) > top_val:
				top_val = EmotionManager.values.get(e, 0)
				top_emotion = e
		sui_jing_resonance_bonus[top_emotion] = sui_jing_resonance_bonus.get(top_emotion, 0.0) + 0.05
		relic_triggered.emit("sui_jing_pian", "碎镜片：%s共鸣威力+5%%" % EmotionManager.get_emotion_name(top_emotion))

func get_resonance_power_bonus(emotion: String) -> float:
	return sui_jing_resonance_bonus.get(emotion, 0.0)

# ── 庙祝法衣：触发共鸣后下一张牌降费
var miaozhu_fayi_next_card_discount: bool = false

func on_resonance_triggered_ruyue(_emotion: String) -> void:
	if not has_relic("miaozhu_fayi"): return
	var upgraded: bool = _is_upgraded("miaozhu_fayi")
	if upgraded:
		DeckManager.current_cost = mini(DeckManager.current_cost + 1, DeckManager.max_cost)
		relic_triggered.emit("miaozhu_fayi", "庙祝法衣：本回合剩余能量+1")
	else:
		miaozhu_fayi_next_card_discount = true
		relic_triggered.emit("miaozhu_fayi", "庙祝法衣：下一张牌费用-1")

func consume_miaozhu_discount() -> bool:
	if not miaozhu_fayi_next_card_discount: return false
	miaozhu_fayi_next_card_discount = false
	return true

# ── 残香（七束）：每次触发共鸣顺序奖励
var canxiang_charge: int = 7
var canxiang_index:  int = 0

func on_resonance_triggered_canxiang(target_node) -> void:
	if not has_relic("canxiang_qi_shu"): return
	var upgraded: bool = _is_upgraded("canxiang_qi_shu")
	if not upgraded and canxiang_charge <= 0: return
	if not upgraded: canxiang_charge -= 1
	var idx: int = canxiang_index % 7
	canxiang_index += 1
	match idx:
		0:
			DeckManager.draw_cards(1)
			relic_triggered.emit("canxiang_qi_shu", "残香第1束：抽1张牌")
		1:
			GameState.heal(4)
			relic_triggered.emit("canxiang_qi_shu", "残香第2束：回血4")
		2:
			DeckManager.current_cost = mini(DeckManager.current_cost + 1, DeckManager.max_cost)
			relic_triggered.emit("canxiang_qi_shu", "残香第3束：+1能量")
		3:
			# 对所有敌人施加随机印记×1：由 BattleStateMachine 响应信号处理
			relic_triggered.emit("canxiang_apply_random_mark_all", "残香第4束：全场施加随机印记×1")
		4:
			# 渡化进度+8%：BattleStateMachine 读取
			relic_triggered.emit("canxiang_purification_bonus_0.08", "残香第5束：渡化进度+8%")
		5:
			# 本回合共鸣效果×1.5：BattleStateMachine 读取
			relic_triggered.emit("canxiang_resonance_x1.5", "残香第6束：本回合共鸣效果×1.5")
		6:
			# 强制触发五情共鸣：BattleStateMachine 响应
			relic_triggered.emit("canxiang_force_five_resonance", "残香第7束：强制触发五情共鸣")

# ── 神像碎块：五情共鸣不清零印记
func should_keep_marks_after_five_resonance() -> bool:
	return has_relic("shenxiang_suikuai")

func get_five_resonance_purification_bonus() -> float:
	if has_relic("guanchen_zhi_jing"): return 0.80
	if has_relic("shenxiang_suikuai"):
		return 0.50 if _is_upgraded("shenxiang_suikuai") else 0.30
	return 0.50  # 默认

# ── 五彩香灰：多种印记时伤害加成
func get_multi_mark_damage_bonus(mark_type_count: int) -> float:
	if not has_relic("wucai_xianghui"): return 0.0
	var threshold: int = 3 if _is_upgraded("wucai_xianghui") else 4
	if mark_type_count >= threshold: return 0.15
	return 0.0

# ── 印堂朱砂：共鸣时同时对自身生效
func on_resonance_mirror_to_self(emotion: String) -> void:
	if not has_relic("yintang_zhusha"): return
	var upgraded: bool = _is_upgraded("yintang_zhusha")
	match emotion:
		"grief":
			next_attack_bonus = maxi(next_attack_bonus, 999)  # 标记为"下次攻击翻倍"
			relic_triggered.emit("yintang_zhusha", "印堂朱砂：下次攻击×2")
		"fear":
			next_damage_reduction = maxi(next_damage_reduction, 9999)  # 标记为"免疫一次"
			relic_triggered.emit("yintang_zhusha", "印堂朱砂：免疫下一次伤害")
		"rage":
			next_attack_bonus += 15
			relic_triggered.emit("yintang_zhusha", "印堂朱砂：下次攻击+15穿甲")
		"joy":
			GameState.heal(8)
			relic_triggered.emit("yintang_zhusha", "印堂朱砂：回血8")
		"calm":
			DeckManager.current_cost = mini(DeckManager.current_cost + 1, DeckManager.max_cost)
			relic_triggered.emit("yintang_zhusha", "印堂朱砂：本回合+1费")

# ── 破庙门槛：战斗结束时印记转金币
func on_battle_end_ruyue(remaining_marks_total: int) -> void:
	if not has_relic("pomiao_menjian"): return
	var upgraded: bool = _is_upgraded("pomiao_menjian")
	var ratio: int    = 2 if upgraded else 1
	var cap: int      = 25 if upgraded else 15
	var gold: int     = minf(remaining_marks_total * ratio, cap)
	if gold > 0:
		GameState.gain_gold(gold)
		relic_triggered.emit("pomiao_menjian", "破庙门槛：印记残留%d层→金币+%d" % [remaining_marks_total, gold])

# ════════════════════════════════════════════
#  沈铁钧专属遗物
# ════════════════════════════════════════════

# ── 怒气壶：怒爆后下回合获得怒+1
var nuqi_hu_pending_rage: int = 0

func on_fury_burst_tiejun() -> void:
	if has_relic("nuqi_hu"):
		var upgraded: bool = _is_upgraded("nuqi_hu")
		nuqi_hu_pending_rage = 2 if upgraded else 1
		relic_triggered.emit("nuqi_hu", "怒气壶：下回合怒+%d" % nuqi_hu_pending_rage)
	if has_relic("tie_shoutao_left"):
		relic_triggered.emit("tie_shoutao_left_stun", "铁手套：怒爆期间附加震慑效果")
	if has_relic("nu_bao_jishuqi"):
		_nu_bao_count += 1
		if _nu_bao_count % (2 if _is_upgraded("nu_bao_jishuqi") else 3) == 0:
			_nu_bao_multiplier += 0.1
			relic_triggered.emit("nu_bao_jishuqi", "怒爆计数器：怒爆倍率升至×%.1f" % (1.5 + _nu_bao_multiplier))

var _nu_bao_count:       int   = 0
var _nu_bao_multiplier:  float = 0.0

func get_fury_burst_multiplier_bonus() -> float:
	if not has_relic("nu_bao_jishuqi"): return 0.0
	return minf(_nu_bao_multiplier, 1.0)  # 最高+1.0（即×2.5）

func consume_nuqi_hu_rage() -> int:
	var v: int = nuqi_hu_pending_rage
	nuqi_hu_pending_rage = 0
	return v

# ── 铁链一段：溅射伤害保底
func get_splash_damage_floor() -> int:
	if not has_relic("tielian_yi_duan"): return 0
	return 5 if _is_upgraded("tielian_yi_duan") else 3

# ── 铁算盘：溅射伤害积累金币
var _tie_suanpan_splash_accum: float = 0.0
var _tie_suanpan_prev_game_accum: float = 0.0  # 升级版本跨场保留

func on_splash_damage_tiejun(damage: int) -> void:
	if not has_relic("tie_suanpan"): return
	var upgraded: bool = _is_upgraded("tie_suanpan")
	var threshold: float = 8.0 if upgraded else 10.0
	_tie_suanpan_splash_accum += float(damage)
	while _tie_suanpan_splash_accum >= threshold:
		_tie_suanpan_splash_accum -= threshold
		GameState.gain_gold(1)
		relic_triggered.emit("tie_suanpan", "铁算盘：溅射伤害累积→+1金币")

# ── 旧案牍：击杀锁链敌人时AOE
func get_kill_chain_aoe_multiplier() -> int:
	if not has_relic("jiu_andu_weijie"): return 0
	return 6 if _is_upgraded("jiu_andu_weijie") else 4

# ── 千斤锁：总锁链层数阈值触发震地
var _qianjin_suo_triggers: int = 0
var _qianjin_suo_last_total: int = 0

func on_chain_total_changed_tiejun(total: int) -> void:
	if not has_relic("qianjin_suo"): return
	var upgraded: bool = _is_upgraded("qianjin_suo")
	var threshold: int = 8 if upgraded else 10
	var max_triggers: int = 9999 if upgraded else 3
	while total >= (_qianjin_suo_triggers + 1) * threshold and _qianjin_suo_triggers < max_triggers:
		_qianjin_suo_triggers += 1
		var dmg: int = 6 if upgraded else 8
		relic_triggered.emit("qianjin_suo_aoe_%d" % dmg, "千斤锁：震地！所有锁链敌人各受%d伤+定+1" % dmg)

# ── 定海神针（残）：定情绪免疫伤害减少+衰减减半
func calm_immune_from_damage() -> bool:
	return has_relic("dinghai_shen_zhen_can")

func get_calm_decay_rate() -> float:
	if has_relic("dinghai_shen_zhen_can"):
		return 0.0 if _is_upgraded("dinghai_shen_zhen_can") else 0.5
	return 1.0

# ── 天网令：锁链层数上限和溅射比例
func get_chain_stack_cap() -> int:
	if has_relic("tian_wang_ling"): return 8
	return 5  # 默认

func get_chain_splash_per_stack() -> float:
	if has_relic("tian_wang_ling"): return 0.12
	return 0.08  # 默认

# ── 旧捕快腰牌：战斗开始额外锁链
func get_battle_start_chain_bonus(target: String) -> int:
	## target: "highest_hp" or "all"
	if not has_relic("jiu_bujing_yaopai"): return 0
	var upgraded: bool = _is_upgraded("jiu_bujing_yaopai")
	if upgraded and target == "all": return 1
	if not upgraded and target == "highest_hp": return 2
	return 0

# ════════════════════════════════════════════
#  辅助方法
# ════════════════════════════════════════════

## 重置回合级状态
func on_turn_start_extended() -> void:
	_jiu_tong_ling_triggered = {}
	# 定海神针升级版：每回合结束定+1
	if _is_upgraded("dinghai_shen_zhen_can"):
		EmotionManager.modify("calm", 1)

## 重置战斗级状态
func on_battle_start_extended(_enemy_data: Dictionary) -> void:
	canxiang_charge  = 7
	canxiang_index   = 0
	_qianjin_suo_triggers = 0
	_qianjin_suo_last_total = 0
	guan_yin_ni_reduced_emotion = ""
	on_battle_start_ruyue()

## 遗物是否已升级（通过遗物 id 存储的 "upgraded" 字段）
func _is_upgraded(relic_id: String) -> bool:
	for r: Dictionary in active_relics:
		if r.get("id","") == relic_id:
			return r.get("upgraded", false)
	return false
