extends Node

## BuffManager.gd - 状态效果系统（第6个 Autoload 单例）
## 注意：不要加 class_name，否则与 autoload 同名冲突

signal buff_changed(target: String, buff_id: String, stacks: int)
signal buff_expired(target: String, buff_id: String)
signal buff_damage_to_enemy(amount: int)

# ── 目标常量（避免硬编码字符串）
const TARGET_PLAYER = "player"
const TARGET_ENEMY  = "enemy"

# ── Buff 内部数据结构（用 Dictionary 代替 class，兼容 GDScript 4 Autoload）
# 结构：{
#   "id": String,
#   "display_name": String,
#   "stacks": int,
#   "duration": int,    # -1=永久, >0=剩余回合数
#   "icon_color": Color,
#   "tooltip": String,  # Tooltip 说明文字
# }

# ── 存储
var player_buffs: Dictionary = {}   # buff_id → buff_dict
var enemy_buffs:  Dictionary = {}   # buff_id → buff_dict

# ── 执念锁定状态（由 process_turn_start 设置，EmotionManager.on_turn_end 里读取）
var obsession_active: bool = false

# ════════════════════════════════════════════
#  内置 Buff 定义
# ════════════════════════════════════════════

## 构造灼烧 Buff
static func make_burn(stacks: int) -> Dictionary:
	return {
		"id":           "burn",
		"display_name": "灼烧",
		"stacks":       stacks,
		"duration":     -1,
		"icon_color":   Color(0.9, 0.35, 0.05, 0.85),
		"tooltip":      "每回合结束时受到等同层数的伤害，之后层数-1，归零自动消失。",
	}

## 构造中毒 Buff
static func make_poison(stacks: int) -> Dictionary:
	return {
		"id":           "poison",
		"display_name": "中毒",
		"stacks":       stacks,
		"duration":     -1,
		"icon_color":   Color(0.25, 0.7, 0.15, 0.85),
		"tooltip":      "每回合结束时受到等同层数的伤害，层数不衰减，需要主动清除。",
	}

## 构造执念 Buff
static func make_obsession(duration: int) -> Dictionary:
	return {
		"id":           "obsession",
		"display_name": "执念",
		"stacks":       duration,
		"duration":     duration,
		"icon_color":   Color(0.1, 0.15, 0.55, 0.85),
		"tooltip":      "情绪值本回合无法自然衰减，持续%d回合。" % duration,
	}

## 构造护盾 Buff（战斗护盾层，回合结束归零）
static func make_shield(stacks: int) -> Dictionary:
	return {
		"id":           "shield",
		"display_name": "护盾",
		"stacks":       stacks,
		"duration":     0,        # 回合结束清除
		"icon_color":   Color(0.35, 0.55, 0.85, 0.85),
		"tooltip":      "受到伤害时优先抵消护盾层数，回合结束归零。",
	}

# ════════════════════════════════════════════
#  公共 API
# ════════════════════════════════════════════

func add_buff(target: String, buff_id: String, stacks: int = 1, duration: int = -1) -> void:
	var buffs: Dictionary = _get_target_buffs(target)
	if buff_id in buffs:
		buffs[buff_id]["stacks"] += stacks
		if duration > 0:
			buffs[buff_id]["duration"] = maxf(buffs[buff_id].get("duration", 0), duration)
		if buff_id == "obsession":
			buffs[buff_id]["duration"] = buffs[buff_id]["stacks"]
	else:
		var new_buff: Dictionary = _make_buff(buff_id, stacks)
		if new_buff.is_empty():
			push_warning("BuffManager: 未知 buff_id: " + buff_id)
			return
		buffs[buff_id] = new_buff
	buff_changed.emit(target, buff_id, buffs[buff_id]["stacks"])

func remove_buff(target: String, buff_id: String) -> void:
	var buffs: Dictionary = _get_target_buffs(target)
	if buff_id in buffs:
		buffs.erase(buff_id)
		buff_changed.emit(target, buff_id, 0)
		buff_expired.emit(target, buff_id)

func get_buffs(target: String) -> Array:
	return _get_target_buffs(target).values()

func has_buff(target: String, buff_id: String) -> bool:
	return buff_id in _get_target_buffs(target)

func get_stacks(target: String, buff_id: String) -> int:
	var buffs: Dictionary = _get_target_buffs(target)
	return buffs[buff_id]["stacks"] if buff_id in buffs else 0

## 清空所有 Buff（新局/战斗结束时调用）
func clear_all() -> void:
	player_buffs.clear()
	enemy_buffs.clear()
	obsession_active = false

# ════════════════════════════════════════════
#  回合处理（由 BattleStateMachine 调用）
# ════════════════════════════════════════════

## 回合开始：处理执念锁定
func process_turn_start(target: String) -> void:
	var buffs: Dictionary = _get_target_buffs(target)
	if "obsession" in buffs:
		obsession_active = (target == TARGET_PLAYER)

## 回合结束：处理灼烧/中毒伤害，duration 倒计时，护盾归零
func process_turn_end(target: String) -> void:
	var buffs: Dictionary = _get_target_buffs(target)
	var to_remove = []

	for buff_id in buffs.keys():
		var buff: Dictionary = buffs[buff_id]
		match buff_id:
			"burn":
				_deal_buff_damage(target, buff["stacks"])
				buff["stacks"] -= 1
				if buff["stacks"] <= 0:
					to_remove.append(buff_id)
				else:
					buff_changed.emit(target, buff_id, buff["stacks"])

			"poison":
				_deal_buff_damage(target, buff["stacks"])
				# 中毒层数不衰减
				buff_changed.emit(target, buff_id, buff["stacks"])

			"obsession":
				buff["duration"] -= 1
				buff["stacks"]    = buff["duration"]
				if buff["duration"] <= 0:
					to_remove.append(buff_id)
				else:
					buff_changed.emit(target, buff_id, buff["stacks"])
				# 解除执念锁定
				if target == TARGET_PLAYER:
					obsession_active = false

			"shield":
				# 回合结束护盾归零
				to_remove.append(buff_id)

	for buff_id in to_remove:
		remove_buff(target, buff_id)

## 受伤时护盾拦截（由 BattleStateMachine 调用，返回实际穿透伤害）
func absorb_damage(target: String, raw_damage: int) -> int:
	if not has_buff(target, "shield"):
		return raw_damage
	var buffs: Dictionary = _get_target_buffs(target)
	var shield: int = buffs["shield"]["stacks"]
	var blocked: int = mini(shield, raw_damage)
	buffs["shield"]["stacks"] -= blocked
	if buffs["shield"]["stacks"] <= 0:
		remove_buff(target, "shield")
	else:
		buff_changed.emit(target, "shield", buffs["shield"]["stacks"])
	return raw_damage - blocked

# ════════════════════════════════════════════
#  解析 enemies.json 的 dot 行动
#  格式：type = "dot_burn_2" / "dot_poison_3" / "dot_fire"（兼容旧格式）
# ════════════════════════════════════════════

func parse_dot_action(action: Dictionary) -> void:
	var atype: String = action.get("type", "")
	var value: int = action.get("value", 1)
	if atype == "dot" or atype == "dot_fire" or atype == "all_field_heat_dot":
		# 旧格式：直接当灼烧处理
		add_buff(TARGET_PLAYER, "burn", value)
		return
	# 新格式：dot_{buff_id}_{stacks}
	if atype.begins_with("dot_"):
		var parts: Array = atype.split("_")
		if len(parts) >= 3:
			var buff_id: String = parts[1]                         # burn / poison / obsession
			var stacks  = int(parts[2]) if parts[2].is_valid_int() else value
			add_buff(TARGET_PLAYER, buff_id, stacks)
		elif len(parts) == 2:
			add_buff(TARGET_PLAYER, parts[1], value)

# ════════════════════════════════════════════
#  私有工具
# ════════════════════════════════════════════

func _get_target_buffs(target: String) -> Dictionary:
	if target == TARGET_PLAYER: return player_buffs
	return enemy_buffs

func _make_buff(buff_id: String, stacks: int) -> Dictionary:
	match buff_id:
		"burn":      return make_burn(stacks)
		"poison":    return make_poison(stacks)
		"obsession": return make_obsession(stacks)
		"shield":    return make_shield(stacks)
	return {}

func _deal_buff_damage(target: String, amount: int) -> void:
	if amount <= 0: return
	if target == TARGET_PLAYER:
		GameState.take_damage(amount)
	else:
		# 敌人受 Buff 伤害：通过信号通知 BattleStateMachine
		buff_damage_to_enemy.emit(amount)
