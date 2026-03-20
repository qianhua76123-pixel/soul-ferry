extends Node

class_name BossUI

## BossUI.gd - Boss 专属战斗 UI 控制器
## 在 BattleScene._on_battle_started() 中检测到 Boss 时调用 activate()
## 功能：
##   1. Boss 名称大字特效（红色+发光+入场动画）
##   2. 超大血条（带渐变色：绿→黄→橙→红）
##   3. 意图预告系统（显示 Boss 下一轮行动，含图标+文字+进度预测）
##   4. Boss 阶段系统（HP 过半时触发愤怒阶段，强化 Boss 外观）
##   5. Boss 入场动画序列

signal boss_phase_changed(new_phase: int)   # 1=正常, 2=愤怒

# ══════════════════════════════════════════════════════
#  节点引用（由 BattleScene 在 activate() 时传入）
# ══════════════════════════════════════════════════════
var _battle_scene:    Node  = null
var _enemy_area:      Control = null
var _hp_bar:          ProgressBar = null
var _name_label:      Label = null
var _intent_label:    Label = null
var _sprite_node:     TextureRect = null

# ══════════════════════════════════════════════════════
#  Boss 状态
# ══════════════════════════════════════════════════════
var _boss_data:       Dictionary = {}
var _enemy_max_hp:    int = 0
var _current_phase:   int = 1   # 1=正常, 2=愤怒（HP≤50%）
var _action_index:    int = 0   # 当前即将执行的 action 序号
var _is_active:       bool = false

# 意图类型图标映射
const INTENT_ICONS: Dictionary = {
	"attack":          "⚔",
	"attack_all":      "💢",
	"shield":          "🛡",
	"heal":            "💚",
	"dot":             "🔥",
	"dot_fire":        "🔥",
	"emotion_push":    "🌀",
	"summon":          "👻",
	"all_field_heat_dot": "☄",
	"phase_change":    "⚡",
}

# ══════════════════════════════════════════════════════
#  激活（由 BattleScene 在 _on_battle_started 后调用）
# ══════════════════════════════════════════════════════
func activate(battle_scene: Node, enemy_data: Dictionary) -> void:
	_battle_scene = battle_scene
	_boss_data    = enemy_data
	_enemy_max_hp = enemy_data.get("hp", 100)
	_current_phase = 1
	_action_index  = 0
	_is_active     = true

	_resolve_nodes()
	_apply_boss_style()
	_play_boss_intro()
	_update_intent_display(0)

# ══════════════════════════════════════════════════════
#  每回合由 BattleScene 调用，传入当前 HP 和回合数
# ══════════════════════════════════════════════════════
func on_turn_start(current_hp: int, turn: int) -> void:
	if not _is_active: return
	_update_hp_bar_color(current_hp)
	_check_phase_change(current_hp)
	_update_intent_display(turn)

## 每次卡牌打出后由 BattleScene 调用（刷新下一行动预告）
func on_card_played(_card: Dictionary, _result: Dictionary, current_hp: int, turn: int) -> void:
	if not _is_active: return
	_update_hp_bar_color(current_hp)
	_check_phase_change(current_hp)

## Boss 死亡时调用（播放击败动画）
func on_boss_defeated() -> void:
	if not _is_active or not _sprite_node: return
	var tw = _sprite_node.create_tween()
	tw.tween_property(_sprite_node, "modulate", Color(2.0, 0.5, 0.5, 1.0), 0.1)
	tw.tween_property(_sprite_node, "modulate", Color(0.0, 0.0, 0.0, 0.0), 0.6)
	tw.tween_property(_sprite_node, "scale", Vector2(1.3, 0.0), 0.4)

# ══════════════════════════════════════════════════════
#  内部：解析节点引用（宽容模式，节点不存在时静默跳过）
# ══════════════════════════════════════════════════════
func _resolve_nodes() -> void:
	if not _battle_scene: return
	_enemy_area   = _battle_scene.get_node_or_null("UI/AltarLayout/EnemyArea")
	_hp_bar       = _battle_scene.get_node_or_null("UI/AltarLayout/EnemyArea/HPBar")
	_name_label   = _battle_scene.get_node_or_null("UI/AltarLayout/EnemyArea/EnemyName")
	_intent_label = _battle_scene.get_node_or_null("UI/AltarLayout/EnemyArea/IntentLabel")
	_sprite_node  = _battle_scene.get_node_or_null("UI/AltarLayout/EnemyArea/EnemySprite")

# ══════════════════════════════════════════════════════
#  Boss 样式强化
# ══════════════════════════════════════════════════════
func _apply_boss_style() -> void:
	# 血条放大（宽度）
	if _hp_bar:
		_hp_bar.custom_minimum_size = Vector2(240, 18)
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.7, 0.08, 0.08)
		sb.set_corner_radius_all(3)
		_hp_bar.add_theme_stylebox_override("fill", sb)

	# Boss 名称：加大字号，朱红色
	if _name_label:
		_name_label.add_theme_font_size_override("font_size", 20)
		_name_label.add_theme_color_override("font_color", Color(0.9, 0.15, 0.15))

	# BOSS 标签（在 EnemyArea 顶部插入）
	if _enemy_area:
		var boss_tag = Label.new()
		boss_tag.name = "BossTag"
		boss_tag.text = "【 BOSS 】"
		boss_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		boss_tag.add_theme_color_override("font_color", Color(0.95, 0.75, 0.10))
		boss_tag.add_theme_font_size_override("font_size", 14)
		_enemy_area.add_child(boss_tag)
		_enemy_area.move_child(boss_tag, 0)
		# 金色脉冲动画
		var tw = boss_tag.create_tween().set_loops()
		tw.tween_property(boss_tag, "modulate", Color(1.2, 1.0, 0.3, 1.0), 0.8)
		tw.tween_property(boss_tag, "modulate", Color(0.9, 0.6, 0.1, 1.0), 0.8)

# ══════════════════════════════════════════════════════
#  Boss 入场动画（渐入 + 震动）
# ══════════════════════════════════════════════════════
func _play_boss_intro() -> void:
	if not _sprite_node: return
	# 从透明/放大渐入
	_sprite_node.modulate = Color(1, 1, 1, 0)
	_sprite_node.scale    = Vector2(1.5, 1.5)
	var tw = _sprite_node.create_tween()
	tw.tween_property(_sprite_node, "modulate", Color.WHITE, 0.6).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_sprite_node, "scale", Vector2(1.0, 1.0), 0.6).set_ease(Tween.EASE_OUT)
	# 入场后抖动
	tw.tween_callback(func(): _shake_sprite(3, 0.04))

	# 名字标签入场
	if _name_label:
		_name_label.modulate = Color(1, 1, 1, 0)
		var ntw = _name_label.create_tween()
		ntw.tween_interval(0.3)
		ntw.tween_property(_name_label, "modulate", Color.WHITE, 0.5)

	# SFX
	if Engine.has_singleton("SoundManager"):
		SoundManager.play_sfx("disorder_trigger")   # 借用震撼音效

# ══════════════════════════════════════════════════════
#  血条颜色随 HP 比例变化
# ══════════════════════════════════════════════════════
func _update_hp_bar_color(current_hp: int) -> void:
	if not _hp_bar: return
	var ratio = float(current_hp) / float(_enemy_max_hp) if _enemy_max_hp > 0 else 0.0
	var color: Color
	if ratio > 0.6:
		color = Color(0.7, 0.08, 0.08)          # 深红
	elif ratio > 0.35:
		color = Color(0.85, 0.35, 0.05)         # 橙红
	else:
		color = Color(0.95, 0.65, 0.05)         # 金黄（垂死警告）
	var sb = StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(3)
	_hp_bar.add_theme_stylebox_override("fill", sb)

# ══════════════════════════════════════════════════════
#  阶段变换（HP ≤ 50%：进入愤怒阶段）
# ══════════════════════════════════════════════════════
func _check_phase_change(current_hp: int) -> void:
	if _current_phase == 2: return
	var ratio = float(current_hp) / float(_enemy_max_hp) if _enemy_max_hp > 0 else 1.0
	if ratio <= 0.5:
		_current_phase = 2
		boss_phase_changed.emit(2)
		_play_phase_change_fx()

func _play_phase_change_fx() -> void:
	# 全屏红色闪烁（通过 BattleScene 自身 modulate）
	if _battle_scene:
		var tw = _battle_scene.create_tween()
		tw.tween_property(_battle_scene, "modulate", Color(1.5, 0.3, 0.3, 1.0), 0.1)
		tw.tween_property(_battle_scene, "modulate", Color.WHITE, 0.4)

	# Boss 立绘变色（更暗，更红）
	if _sprite_node:
		var tw2 = _sprite_node.create_tween().set_loops()
		tw2.tween_property(_sprite_node, "modulate", Color(1.3, 0.4, 0.4, 1.0), 0.6)
		tw2.tween_property(_sprite_node, "modulate", Color(1.0, 0.7, 0.7, 1.0), 0.6)

	# 阶段提示浮字
	_spawn_phase_text()
	SoundManager.play_sfx("disorder_trigger")

func _spawn_phase_text() -> void:
	if not _enemy_area: return
	var lbl = Label.new()
	lbl.text = "⚡ 愤怒·觉醒 ⚡"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.1))
	lbl.add_theme_font_size_override("font_size", 24)
	_enemy_area.add_child(lbl)
	lbl.position = Vector2(0, -30)
	var tw = lbl.create_tween()
	tw.tween_property(lbl, "position:y", -90.0, 1.5)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 1.5)
	tw.tween_callback(lbl.queue_free)

# ══════════════════════════════════════════════════════
#  意图预告显示
## 从 enemy_data.actions 读取下一行动（按权重轮转简化预测）
# ══════════════════════════════════════════════════════
func _update_intent_display(turn: int) -> void:
	if not _intent_label: return
	var actions = _boss_data.get("actions", [])
	if actions.is_empty():
		_intent_label.text = "意图：???"
		return

	# 愤怒阶段：Boss 优先使用高伤害 action
	var available = actions
	if _current_phase == 2:
		var rage_actions = actions.filter(func(a): return a.get("type","") in ["attack","attack_all","dot_fire"])
		if not rage_actions.is_empty():
			available = rage_actions

	# 加权随机预测下一个（仅预测，不真正改变状态机）
	var predicted = _predict_next_action(available, turn)
	if predicted.is_empty():
		_intent_label.text = "意图：???"
		return

	var icon  = INTENT_ICONS.get(predicted.get("type",""), "❓")
	var atype = predicted.get("type", "")
	var aval  = predicted.get("value", 0)
	var desc  = _action_desc(atype, aval)

	# 颜色：愤怒阶段橙红，正常暗金
	if _current_phase == 2:
		_intent_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.1))
	else:
		_intent_label.add_theme_color_override("font_color", Color(0.85, 0.80, 0.70))

	var rage_mark = "  【愤怒】" if _current_phase == 2 else ""
	_intent_label.text = "%s %s%s" % [icon, desc, rage_mark]

func _predict_next_action(actions: Array, turn: int) -> Dictionary:
	# 简单预测：按 turn 轮转（可替换为更复杂的 AI 预测）
	if actions.is_empty(): return {}
	return actions[turn % actions.size()]

func _action_desc(atype: String, aval: int) -> String:
	match atype:
		"attack":        return "攻击 %d 伤害" % aval
		"attack_all":    return "全体攻击 %d" % aval
		"shield":        return "获得 %d 护盾" % aval
		"heal":          return "恢复 %d HP" % aval
		"dot", "dot_fire": return "施加灼烧 %d" % aval
		"emotion_push":  return "干扰情绪"
		"all_field_heat_dot": return "全场烈焰"
		"summon":        return "召唤随从"
		"phase_change":  return "形态变换"
		_:               return atype

# ══════════════════════════════════════════════════════
#  立绘震动工具
# ══════════════════════════════════════════════════════
func _shake_sprite(times: int, magnitude: float) -> void:
	if not _sprite_node: return
	var origin = _sprite_node.position
	var tw = _sprite_node.create_tween()
	for i in times:
		var dx = randf_range(-magnitude * 20, magnitude * 20)
		tw.tween_property(_sprite_node, "position:x", origin.x + dx, 0.04)
	tw.tween_property(_sprite_node, "position:x", origin.x, 0.05)
