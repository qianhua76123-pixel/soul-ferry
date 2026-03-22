extends Node
## ForgeSystem.gd - 锻造系统（8种锻造类型 + 图纸系统）
## Autoload 单例，注册名 "ForgeSystem"
## 注意：不声明 class_name，避免与 Autoload 全局名冲突

signal forge_completed(original: Dictionary, forged: Dictionary)
signal recipe_unlocked(recipe_id: String)

# ── 已解锁图纸 ─────────────────────────────────────────
var unlocked_recipes: Array[String] = []

# ── 8种锻造类型及碎片消耗 ─────────────────────────────
const FORGE_COSTS: Dictionary = {
	"emotion_brand":    {},  # 动态：对应情绪碎片×5 + spirit×2（由 params 指定情绪）
	"mechanism_link":   {},  # 动态：seal×5 或 chain×5
	"resonance_amp":    {},  # 动态：对应情绪×8 + echo×1
	"chain_enhance":    {"chain": 6, "nu": 3},
	"emotion_swap":     {},  # 动态：情绪A×4 + 情绪B×4
	"soul_link":        {"spirit": 5},  # 五色碎片由外部传入
	"void_inject":      {"void": 5, "spirit": 3},
	"ultimate_recast":  {"echo": 2},  # 角色专属×10 由 params 传入
}

func _ready() -> void:
	# 监听成就/统计，自动解锁图纸
	AchievementManager.achievement_unlocked.connect(_on_achievement)
	GameState.relic_added.connect(func(_id: String): check_and_unlock_recipes())

# ── 公共 API ───────────────────────────────────────────

func can_forge(card: Dictionary, forge_type: String, params: Dictionary = {}) -> bool:
	if card.get("forged", false):
		return false
	# 图纸检查
	if not _recipe_check(forge_type):
		return false
	# 角色限制
	if forge_type == "void_inject":
		var char_id: String = str(GameState.get_meta("selected_character", ""))
		if char_id != "wumian":
			return false
	# 适用性检查
	if not _card_eligible(card, forge_type):
		return false
	# 碎片检查
	var cost: Dictionary = _resolve_cost(forge_type, params)
	return DiscardSystem.has_shards(cost)

func execute_forge(card: Dictionary, forge_type: String, params: Dictionary = {}) -> Dictionary:
	var cost: Dictionary = _resolve_cost(forge_type, params)
	if not DiscardSystem.spend_shards(cost):
		push_error("ForgeSystem: 碎片不足，无法锻造")
		return card

	var result: Dictionary = card.duplicate(true)
	var char_id: String = str(GameState.get_meta("selected_character", "ruan_ruyue"))

	match forge_type:
		"emotion_brand":
			var target_emotion: String = str(params.get("emotion", "grief"))
			result["emotion_tag"] = target_emotion
			var map: Dictionary = {"grief":"bei","fear":"ju","rage":"怒","joy":"xi","calm":"ding"}
			result["description"] = str(result.get("description","")) + "\n[锻造] 打出时%s+1" % _emotion_cn(target_emotion)

		"mechanism_link":
			var link_type: String = str(params.get("link_type", "seal"))  # "seal" or "chain"
			result["forge_mechanism_link"] = link_type
			result["description"] = str(result.get("description","")) + "\n[锻造] 打出时触发最近%s效果的40%%" % ("印记" if link_type=="seal" else "锁链")

		"resonance_amp":
			result["resonance_amp"] = true
			result["description"] = str(result.get("description","")) + "\n[锻造] 触发共鸣时效果×1.5"

		"chain_enhance":
			var cur: int = int(result.get("chain_enhance_stacks", 0))
			if cur < 3:
				result["chain_enhance_stacks"] = cur + 1
				result["description"] = str(result.get("description","")) + "\n[锻造] 锁链溅射+5%%（已叠加%d次）" % (cur+1)

		"emotion_swap":
			var from_e: String = str(params.get("from_emotion", ""))
			var to_e: String   = str(params.get("to_emotion", ""))
			if not from_e.is_empty() and not to_e.is_empty():
				result["emotion_tag"] = to_e
				result["description"] = str(result.get("description","")) + "\n[锻造] 情绪标签：%s→%s" % [_emotion_cn(from_e), _emotion_cn(to_e)]

		"soul_link":
			result["soul_link"] = true
			result["description"] = str(result.get("description","")) + "\n[锻造] 打出时若场上有印记，渡化进度+5%%"

		"void_inject":
			result["void_inject"] = true
			result["description"] = str(result.get("description","")) + "\n[锻造] 打出时可选择空度±1"

		"ultimate_recast":
			result = _ultimate_recast(result, char_id, params)

	result["forged"]    = true
	result["forge_type"] = forge_type

	DeckManager.replace_card(str(card.get("id","")), result)
	forge_completed.emit(card, result)
	return result

func get_available_forges(card: Dictionary) -> Array[Dictionary]:
	## 返回该牌所有可用锻造类型（含可用性和消耗信息，供UI展示）
	var result: Array[Dictionary] = []
	var char_id: String = str(GameState.get_meta("selected_character", "ruan_ruyue"))

	for ft in FORGE_COSTS.keys():
		var entry: Dictionary = {
			"type":    ft,
			"label":   _forge_label(ft),
			"locked":  not _recipe_check(ft),
			"eligible": _card_eligible(card, ft),
			"cost_display": _cost_display(ft),
		}
		# 角色限制
		if ft == "void_inject" and char_id != "wumian":
			entry["locked"] = true
		result.append(entry)
	return result

func check_and_unlock_recipes() -> void:
	var stats: Dictionary = AchievementManager.stats
	if int(stats.get("total_du_hua", 0)) >= 3 and "duhua_forge" not in unlocked_recipes:
		_unlock("duhua_forge")
	if int(stats.get("total_rage_burst", 0)) >= 5 and "rage_forge" not in unlocked_recipes:
		_unlock("rage_forge")
	if int(stats.get("total_kongming", 0)) >= 2 and "kongming_forge" not in unlocked_recipes:
		_unlock("kongming_forge")
	# 传说遗物解锁
	for rid in ["guan_chen_jing", "tian_wang_ling"]:
		if GameState.has_relic(rid) and "legend_forge" not in unlocked_recipes:
			_unlock("legend_forge")
			break

# ── 极限改造（各角色独立逻辑） ────────────────────────
func _ultimate_recast(card: Dictionary, char_id: String, _params: Dictionary) -> Dictionary:
	var c: Dictionary = card.duplicate(true)
	match char_id:
		"ruan_ruyue":
			var etype: String = str(c.get("effect_type",""))
			if "mark" in etype or "seal" in etype or "apply_mark" in etype:
				# 施印牌：印层×3，共鸣消耗-1
				c["effect_value"] = int(c.get("effect_value",1)) * 3
				c["resonance_cost_reduction"] = 1
				c["description"] = str(c.get("description","")) + "\n[极限] 施印层数×3，共鸣消耗印记-1层"
			else:
				# 触发牌：去掉条件限制，但每场战斗只能出1次
				c.erase("condition")
				c["battle_use_limit"] = 1
				c["description"] = str(c.get("description","")) + "\n[极限] 去除所有条件，但每场战斗限打出1次"

		"shen_tiejun":
			var etype: String = str(c.get("effect_type",""))
			if "chain" in etype:
				c["chain_cap_override"] = 8
				c["description"] = str(c.get("description","")) + "\n[极限] 锁链层数上限突破至8层"
			else:
				c["ultimate_rage_bonus"] = true
				c["description"] = str(c.get("description","")) + "\n[极限] 额外造成怒×5伤害，打出后怒-2"

		"wumian":
			var etype: String = str(c.get("effect_type",""))
			if "emptiness" in etype:
				c["void_amp"] = 2.0
				c["void_no_hp_penalty"] = true
				c["description"] = str(c.get("description","")) + "\n[极限] 空度调整量×2，不触发极高段HP-5副作用"
			else:
				c["transfer_amp"] = 2.0
				c["transfer_aoe"] = true
				c["description"] = str(c.get("description","")) + "\n[极限] 情绪转移量翻倍，且作用于所有敌人"
	return c

# ── 内部工具 ───────────────────────────────────────────

func _recipe_check(forge_type: String) -> bool:
	## 检查图纸是否解锁（无需图纸的类型默认解锁）
	match forge_type:
		"soul_link":      return "duhua_forge" in unlocked_recipes
		"chain_enhance":  return "rage_forge" in unlocked_recipes
		"void_inject":    return "kongming_forge" in unlocked_recipes
		"ultimate_recast":return "legend_forge" in unlocked_recipes
		_:                return true

func _card_eligible(card: Dictionary, forge_type: String) -> bool:
	var etype: String = str(card.get("effect_type",""))
	match forge_type:
		"resonance_amp":
			return "mark" in etype or "resonance" in etype or "seal" in etype
		"chain_enhance":
			return "chain" in etype
		"emotion_brand":
			return card.get("emotion_tag","") in ["", "none"]
		_:
			return true

func _resolve_cost(forge_type: String, params: Dictionary) -> Dictionary:
	match forge_type:
		"emotion_brand":
			var e: String = str(params.get("emotion","grief"))
			return {_emotion_shard(e): 5, "spirit": 2}
		"mechanism_link":
			var lt: String = str(params.get("link_type","seal"))
			return {lt: 5}
		"resonance_amp":
			var e: String = str(params.get("emotion","grief"))
			return {_emotion_shard(e): 8, "echo": 1}
		"emotion_swap":
			var fa: String = _emotion_shard(str(params.get("from_emotion","")))
			var fb: String = _emotion_shard(str(params.get("to_emotion","")))
			return {fa: 4, fb: 4}
		"ultimate_recast":
			var char_id: String = str(GameState.get_meta("selected_character","ruan_ruyue"))
			var spec: String = {"ruan_ruyue":"seal","shen_tiejun":"chain","wumian":"void"}.get(char_id,"spirit")
			return {"echo": 2, spec: 10}
		_:
			return FORGE_COSTS.get(forge_type, {}).duplicate()

func _emotion_shard(emotion: String) -> String:
	return {"grief":"bei","fear":"ju","rage":"nu","joy":"xi","calm":"ding"}.get(emotion, "spirit")

func _emotion_cn(emotion: String) -> String:
	return {"grief":"悲","fear":"惧","rage":"怒","joy":"喜","calm":"定","none":"无"}.get(emotion, emotion)

func _forge_label(ft: String) -> String:
	return {
		"emotion_brand":   "情绪刻印",
		"mechanism_link":  "机制衔接",
		"resonance_amp":   "共鸣倍增",
		"chain_enhance":   "锁链强化",
		"emotion_swap":    "情绪置换",
		"soul_link":       "亡魂共鸣",
		"void_inject":     "空度注入",
		"ultimate_recast": "极限改造",
	}.get(ft, ft)

func _cost_display(ft: String) -> String:
	return {
		"emotion_brand":   "对应情绪×5 + 灵气×2",
		"mechanism_link":  "印记/锁链碎片×5",
		"resonance_amp":   "对应情绪×8 + 残响×1",
		"chain_enhance":   "锁链×6 + 怒×3",
		"emotion_swap":    "情绪A×4 + 情绪B×4",
		"soul_link":       "灵气×5（图纸：渡化×3）",
		"void_inject":     "空度×5 + 灵气×3（图纸：空鸣×2）",
		"ultimate_recast": "残响×2 + 专属×10（图纸：传说遗物）",
	}.get(ft, "???")

func _unlock(recipe_id: String) -> void:
	if recipe_id not in unlocked_recipes:
		unlocked_recipes.append(recipe_id)
		recipe_unlocked.emit(recipe_id)

func _on_achievement(achievement_id: String) -> void:
	check_and_unlock_recipes()
