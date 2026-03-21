extends Node

## AchievementManager.gd - 跨局成就与累计统计系统
## 数据存储：user://stats.json（独立于存档，不随通关清除）
##
## 成就列表（共12个）:
##   渡魂入门    - 完成第一次渡化
##   百魂渡者    - 累计渡化10次
##   千魂渡者    - 累计渡化50次
##   无情剑       - 累计镇压20次
##   铁打身躯    - 单局HP从1血反杀Boss
##   五情平衡    - 五情值全部≥3时战斗胜利
##   传说收藏家  - 持有3张传说牌同时出现在牌库
##   遗物控      - 单局同时拥有5个遗物
##   快意恩仇    - 单局未受任何伤害通过一层Boss
##   迷失归来    - 触发"迷失轮回"结局
##   渡尽苍生    - 累计游玩10局
##   至高渡者    - 获得全部其他成就

signal achievement_unlocked(achievement_id: String)

const STATS_PATH = "user://stats.json"

## 累计统计数据（持久化）
var stats: Dictionary = {
	"total_runs":          0,    # 总游玩局数
	"total_du_hua":        0,    # 累计渡化次数
	"total_zhen_ya":       0,    # 累计镇压次数
	"total_victories":     0,    # 总通关次数
	"total_defeats":       0,    # 总失败次数
	"best_layer_reached":  0,    # 最高到达层数
	"best_hp_remaining":   0,    # 历史最高剩余HP
	"total_cards_played":  0,    # 累计出牌数
	"total_gold_earned":   0,    # 累计获得金币
	"achievements":        {},   # 已解锁成就 {id: timestamp}
}

## 成就定义
const ACHIEVEMENTS: Dictionary = {
	"first_du_hua":   {"name": "渡魂入门",   "desc": "完成你的第一次渡化",             "icon": "🕯"},
	"du_hua_10":      {"name": "百魂渡者",   "desc": "累计渡化10次",                   "icon": "📿"},
	"du_hua_50":      {"name": "千魂渡者",   "desc": "累计渡化50次",                   "icon": "⛩"},
	"zhen_ya_20":     {"name": "无情剑",     "desc": "累计镇压20次",                   "icon": "⚔"},
	"clutch_victory": {"name": "铁打身躯",   "desc": "HP为1时击败Boss",               "icon": "💀"},
	"five_balance":   {"name": "五情平衡",   "desc": "五情全≥3时赢得战斗",            "icon": "☯"},
	"legend_3":       {"name": "传说收藏家", "desc": "牌库中同时拥有3张传说牌",        "icon": "📖"},
	"relic_5":        {"name": "遗物控",     "desc": "单局同时持有5个遗物",            "icon": "🪬"},
	"no_damage_boss": {"name": "快意恩仇",   "desc": "0伤通过一层Boss战斗",           "icon": "🌙"},
	"lost_ending":    {"name": "迷失归来",   "desc": "触发\"迷失轮回\"隐藏结局",       "icon": "🌀"},
	"runs_10":        {"name": "渡尽苍生",   "desc": "累计游玩10局",                   "icon": "🗂"},
	"completionist":  {"name": "至高渡者",   "desc": "解锁全部其他成就",               "icon": "👑"},
}

## 本局临时追踪
var _session: Dictionary = {
	"damage_taken_this_boss": 0,
	"hp_at_boss_start":       0,
}

func _ready() -> void:
	_load_stats()
	# Godot 4 信号连接语法
	GameState.game_saved.connect(_on_run_end)

func _load_stats() -> void:
	if not FileAccess.file_exists(STATS_PATH): return
	var f: FileAccess = FileAccess.open(STATS_PATH, FileAccess.READ)
	if not f: return
	var data: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if data is Dictionary:
		for k in data:
			stats[k] = data[k]

func _save_stats() -> void:
	var f: FileAccess = FileAccess.open(STATS_PATH, FileAccess.WRITE)
	if not f: return
	f.store_string(JSON.stringify(stats, "\t"))
	f.close()

## ─── 事件追踪接口（由 BattleScene / GameState 调用）─────────────

## 一次渡化完成
func record_du_hua() -> void:
	stats["total_du_hua"] += 1
	_check_achievement("first_du_hua", stats["total_du_hua"] >= 1)
	_check_achievement("du_hua_10",    stats["total_du_hua"] >= 10)
	_check_achievement("du_hua_50",    stats["total_du_hua"] >= 50)
	_save_stats()

## 一次镇压完成
func record_zhen_ya() -> void:
	stats["total_zhen_ya"] += 1
	_check_achievement("zhen_ya_20", stats["total_zhen_ya"] >= 20)
	_save_stats()

## Boss 战开始
func on_boss_battle_start(current_hp: int) -> void:
	_session["damage_taken_this_boss"] = 0
	_session["hp_at_boss_start"]       = current_hp

## 玩家受伤（Boss战中追踪）
func on_player_damaged(amount: int) -> void:
	_session["damage_taken_this_boss"] += amount

## Boss 战结束
func on_boss_battle_end(result: String, current_hp: int) -> void:
	if result == "victory":
		# 0伤通关 Boss
		_check_achievement("no_damage_boss", _session["damage_taken_this_boss"] == 0)
		# HP为1反杀
		_check_achievement("clutch_victory", current_hp <= 1)
		stats["total_victories"] += 1
	elif result in ["defeat", "du_hua"]:
		if result == "du_hua":
			record_du_hua()
	_save_stats()

## 牌库检查（每次进入战斗后调用）
func check_deck_achievements() -> void:
	var deck: Array = DeckManager.get_full_deck()
	# 传说牌数量
	var legend_count: int = deck.filter(func(c): return c.get("rarity","") == "legendary").size()
	_check_achievement("legend_3", legend_count >= 3)
	# 遗物数量（直接读 GameState.relics）
	_check_achievement("relic_5", len(GameState.relics) >= 5)
	# 五情平衡
	var vals: Dictionary = EmotionManager.values
	var balanced = true
	for v in vals.values():
		if v < 3: balanced = false
	_check_achievement("five_balance", balanced)
	_save_stats()

## 结局触发
func on_ending(ending_type: String) -> void:
	stats["total_runs"] += 1
	_check_achievement("runs_10", stats["total_runs"] >= 10)
	if ending_type == "lost":
		_check_achievement("lost_ending", true)
	_save_stats()

## 游戏保存（层数记录）
func _on_run_end() -> void:
	var layer: int = GameState.current_layer
	if layer > stats["best_layer_reached"]:
		stats["best_layer_reached"] = layer
	_save_stats()

## ─── 成就解锁 ─────────────────────────────────────

func _check_achievement(id: String, condition: bool) -> void:
	if not condition: return
	if stats["achievements"].has(id): return  # 已解锁
	stats["achievements"][id] = Time.get_unix_time_from_system()
	achievement_unlocked.emit(id)
	_show_achievement_toast(id)
	# 检查全成就
	var all_ids: Array = ACHIEVEMENTS.keys().filter(func(k): return k != "completionist")
	var all_done = true
	for k in all_ids:
		if not stats["achievements"].has(k): all_done = false
	if all_done:
		_check_achievement("completionist", true)

func _show_achievement_toast(id: String) -> void:
	var data: Dictionary = ACHIEVEMENTS.get(id, {})
	var icon: String = data.get("icon", "🏆")
	var name: String = data.get("name", id)
	var desc: String = data.get("desc", "")
	# 用 PauseMenu 的 CanvasLayer 发 toast（或自行创建）
	_spawn_toast("%s %s 成就解锁！\n%s" % [icon, name, desc])

func _spawn_toast(msg: String) -> void:
	# 在根节点创建浮动通知
	var lbl: Label = Label.new()
	lbl.text = msg
	lbl.add_theme_color_override("font_color", Color(0.98, 0.85, 0.10))
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var bg: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.03, 0.02, 0.92)
	style.border_color = Color(0.75, 0.55, 0.08)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	bg.add_theme_stylebox_override("panel", style)
	bg.add_child(lbl)

	# 挂在当前场景根节点
	# 挂在 AchievementManager 自身（常驻场景树，不会为 null）
	add_child(bg)
	bg.position = Vector2(20, 520)
	bg.modulate.a = 0.0
	var tw: Tween = bg.create_tween()
	tw.tween_property(bg, "modulate:a", 1.0, 0.3)
	tw.tween_interval(3.0)
	tw.tween_property(bg, "modulate:a", 0.0, 0.5)
	tw.tween_callback(bg.queue_free)

## ─── 查询接口 ─────────────────────────────────────

func get_stats() -> Dictionary:
	return stats

func get_achievement_count() -> int:
	return stats["achievements"].size()

func is_unlocked(id: String) -> bool:
	return stats["achievements"].has(id)
