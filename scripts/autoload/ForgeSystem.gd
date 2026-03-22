extends Node
## ForgeSystem.gd - 锻造系统（金币/碎片双轨，三层结构）
## Autoload 单例，注册名 "ForgeSystem"
## 注意：不声明 class_name，避免与 Autoload 全局名冲突

signal forge_completed(original: Dictionary, forged: Dictionary)
signal recipe_unlocked(recipe_id: String)

# ── 已解锁图纸（保留字段，后续扩展用）────────────────
var unlocked_recipes: Array[String] = []

func _ready() -> void:
	# 监听成就/遗物，自动检查图纸解锁（保留，供后续扩展）
	AchievementManager.achievement_unlocked.connect(_on_achievement)
	GameState.relic_added.connect(func(_id: String): check_and_unlock_recipes())

# ── 公共 API ───────────────────────────────────────────

## 返回该牌所有可用锻造方案（金币基础 + 碎片进阶 + 图纸暂注释）
func get_available_forges(card: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var gold: int = GameState.gold
	var char_id: String = str(GameState.get_meta("selected_character", "ruan_ruyue"))

	# ── 基础锻造（金币，无需碎片）────────────────────
	result.append({
		"type":         "basic_power",
		"label":        "⚒ 强化  —  数值×1.25",
		"cost_display": "💰 80 金",
		"eligible":     gold >= 80 and not card.get("forged", false),
		"locked":       false,
		"cost_gold":    80,
	})
	result.append({
		"type":         "basic_cost",
		"label":        "✦ 减费  —  费用-1",
		"cost_display": "💰 120 金",
		"eligible":     gold >= 120 and int(card.get("cost", 0)) > 0 and not card.get("forged", false),
		"locked":       false,
		"cost_gold":    120,
	})
	result.append({
		"type":         "basic_extend",
		"label":        "＋ 扩展  —  追加升级效果",
		"cost_display": "💰 100 金",
		"eligible":     gold >= 100 and not card.get("forged", false),
		"locked":       false,
		"cost_gold":    100,
	})

	# ── 进阶锻造（碎片，有碎片才显示，无需解锁）────
	var spirit: int = DiscardSystem.get_shard("spirit")
	if spirit >= 3:
		result.append({
			"type":         "adv_emotion",
			"label":        "🌀 注入情绪  —  打出时+最优情绪",
			"cost_display": "灵气碎片×3",
			"eligible":     true,
			"locked":       false,
			"cost_shards":  {"spirit": 3},
		})

	var void_shard: int = DiscardSystem.get_shard("void")
	if void_shard >= 5 and char_id == "wumian":
		result.append({
			"type":         "adv_void",
			"label":        "◎ 空度注入  —  效果值×1.5（无名专属）",
			"cost_display": "空度碎片×5",
			"eligible":     true,
			"locked":       false,
			"cost_shards":  {"void": 5},
		})

	var seal_shard: int = DiscardSystem.get_shard("seal")
	var etype: String = str(card.get("effect_type", ""))
	if seal_shard >= 4 and ("mark" in etype or "resonance" in etype or "seal" in etype):
		result.append({
			"type":         "adv_resonance",
			"label":        "印 共鸣强化  —  共鸣效果×1.5（阮如月）",
			"cost_display": "印记碎片×4",
			"eligible":     char_id == "ruan_ruyue",
			"locked":       char_id != "ruan_ruyue",
			"cost_shards":  {"seal": 4},
		})

	# ── 图纸锻造（暂时注释，后续扩展）──────────────
	# TODO: 解锁后在此追加 recipe-based forges

	return result

## 执行锻造：支持基础（金币）和进阶（碎片）两轨
func execute_forge(card: Dictionary, forge_type: String, _params: Dictionary = {}) -> Dictionary:
	var result: Dictionary = card.duplicate(true)
	result["forged"] = true

	match forge_type:
		"basic_power":
			# 强化：数值×1.25，消耗 80 金
			if not GameState.spend_gold(80):
				return card
			var ev: int = int(result.get("effect_value", 0))
			if ev > 0:
				result["effect_value"] = int(ev * 1.25)
			result["description"] = str(result.get("description", "")) + "\n[锻造] 数值强化×1.25"

		"basic_cost":
			# 减费：费用-1（最低0），消耗 120 金
			if not GameState.spend_gold(120):
				return card
			var c: int = int(result.get("cost", 1))
			result["cost"] = maxi(0, c - 1)
			result["description"] = str(result.get("description", "")) + "\n[锻造] 费用-1"

		"basic_extend":
			# 扩展：追加升级效果文字，消耗 100 金
			if not GameState.spend_gold(100):
				return card
			var extra: String = str(result.get("upgrade_extra_effect", "强化完成"))
			result["description"] = str(result.get("description", "")) + "\n[锻造] " + extra

		"adv_emotion":
			# 注入情绪：消耗 spirit×3，给牌打上当前最高情绪标签
			if not DiscardSystem.spend_shards({"spirit": 3}):
				return card
			var top_emo: String = "joy"
			var top_val: int = 0
			for e: String in EmotionManager.EMOTIONS:
				var v: int = EmotionManager.values.get(e, 0)
				if v > top_val:
					top_val = v
					top_emo = e
			result["emotion_tag"] = top_emo
			result["description"] = str(result.get("description", "")) + \
				"\n[锻造] 打出时%s+1" % EmotionManager.get_emotion_name(top_emo)

		"adv_void":
			# 空度注入（无名专属）：消耗 void×5，效果值×1.5
			if not DiscardSystem.spend_shards({"void": 5}):
				return card
			var ev2: int = int(result.get("effect_value", 0))
			if ev2 > 0:
				result["effect_value"] = int(ev2 * 1.5)
			result["description"] = str(result.get("description", "")) + "\n[锻造] 空度效果×1.5"

		"adv_resonance":
			# 共鸣强化（阮如月）：消耗 seal×4，共鸣触发时效果×1.5
			if not DiscardSystem.spend_shards({"seal": 4}):
				return card
			result["resonance_amp"] = true
			result["description"] = str(result.get("description", "")) + "\n[锻造] 共鸣效果×1.5"

		_:
			# 未知锻造类型，直接返回原卡不修改
			push_warning("ForgeSystem: 未知锻造类型 %s" % forge_type)
			return card

	# 同步到 DeckManager（用 replace_card 更新牌堆中的卡牌数据）
	DeckManager.replace_card(str(card.get("id", "")), result)
	forge_completed.emit(card, result)
	return result

func check_and_unlock_recipes() -> void:
	## 检查并解锁图纸（供后续扩展）
	var stats: Dictionary = AchievementManager.stats
	if int(stats.get("total_du_hua", 0)) >= 3 and "duhua_forge" not in unlocked_recipes:
		_unlock("duhua_forge")
	if int(stats.get("total_rage_burst", 0)) >= 5 and "rage_forge" not in unlocked_recipes:
		_unlock("rage_forge")
	if int(stats.get("total_kongming", 0)) >= 2 and "kongming_forge" not in unlocked_recipes:
		_unlock("kongming_forge")
	for rid: String in ["guan_chen_jing", "tian_wang_ling"]:
		if GameState.has_relic(rid) and "legend_forge" not in unlocked_recipes:
			_unlock("legend_forge")
			break

# ── 内部工具 ───────────────────────────────────────────

func _unlock(recipe_id: String) -> void:
	if recipe_id not in unlocked_recipes:
		unlocked_recipes.append(recipe_id)
		recipe_unlocked.emit(recipe_id)

func _on_achievement(_achievement_id: String) -> void:
	check_and_unlock_recipes()
