extends VBoxContainer

## PurificationPanel.gd - 渡化条件面板
## 位于五情祭坛雷达正下方，显示渡化条件进度和触发按钮
## 由 BattleScene 在 _setup_purification_panel() 中实例化并绑定信号

signal purify_requested()

const EMOTION_CN = {"calm":"定","rage":"怒","fear":"惧","grief":"悲","joy":"喜"}

var _title_lbl:   Label
var _cond_row:    HBoxContainer
var _purify_btn:  Button
var _cond_items:  Array = []   # [{emotion, required, bar, label}]
var _pulse_tween: Tween = null
var _ready_state: bool  = false

func _ready() -> void:
	custom_minimum_size = Vector2(240, 80)
	add_theme_constant_override("separation", 4)
	_build()
	EmotionManager.emotion_changed.connect(_on_emotion_changed)

func _build() -> void:
	# 标题行
	_title_lbl = Label.new()
	_title_lbl.text = "✦ 渡化条件"
	_title_lbl.add_theme_font_size_override("font_size", 12)
	_title_lbl.add_theme_color_override("font_color", Color(0.65, 0.52, 0.12))
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_title_lbl)

	# 条件进度行
	_cond_row = HBoxContainer.new()
	_cond_row.add_theme_constant_override("separation", 8)
	_cond_row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_cond_row)

	# 渡化按钮
	_purify_btn = Button.new()
	_purify_btn.text     = "条件未满足"
	_purify_btn.disabled = true
	_purify_btn.add_theme_font_size_override("font_size", 12)
	_purify_btn.custom_minimum_size = Vector2(200, 28)
	_purify_btn.pressed.connect(func(): purify_requested.emit())
	add_child(_purify_btn)

func setup_conditions(enemy_data: Dictionary) -> void:
	## 根据敌人数据初始化渡化条件显示
	# 清空旧条件
	for child in _cond_row.get_children(): child.queue_free()
	_cond_items.clear()

	var cond = enemy_data.get("du_hua_condition", {})
	var emotion_req = cond.get("emotion_requirement", {})

	if emotion_req.is_empty():
		# 无情绪条件（如连续出牌型）：显示说明文字
		var hint = Label.new()
		hint.text = cond.get("description", "满足特殊条件后触发")
		hint.add_theme_font_size_override("font_size", 11)
		hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_cond_row.add_child(hint)
		return

	# 逐个情绪条件构建进度条
	for emotion in emotion_req:
		var required = emotion_req[emotion]
		var col = VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		_cond_row.add_child(col)

		var lbl = Label.new()
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.text = "%s 0/%d" % [EMOTION_CN.get(emotion, emotion), int(required)]
		col.add_child(lbl)

		var bar = ProgressBar.new()
		bar.min_value = 0
		bar.max_value = required
		bar.value     = 0
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(44, 8)
		var sty = StyleBoxFlat.new()
		sty.bg_color = Color(0.45, 0.45, 0.45, 0.6)
		bar.add_theme_stylebox_override("fill", sty)
		var sty_bg = StyleBoxFlat.new()
		sty_bg.bg_color = Color(0.10, 0.10, 0.10, 0.6)
		bar.add_theme_stylebox_override("background", sty_bg)
		col.add_child(bar)

		_cond_items.append({
			"emotion": emotion, "required": required,
			"bar": bar, "label": lbl
		})

	update_display()

func update_display() -> void:
	## 刷新所有条件进度，检查是否全部满足
	var all_met = true
	for item in _cond_items:
		var cur  = EmotionManager.values.get(item["emotion"], 0)
		var req  = item["required"]
		var met  = cur >= req
		item["bar"].value  = min(cur, req)
		item["label"].text = "%s %d/%d%s" % [
			EMOTION_CN.get(item["emotion"], item["emotion"]),
			int(cur), int(req), " ✓" if met else ""]
		# 进度条颜色
		var fill_sty = StyleBoxFlat.new()
		fill_sty.bg_color = Color(0.95, 0.76, 0.08) if met else Color(0.45, 0.45, 0.45, 0.6)
		item["bar"].add_theme_stylebox_override("fill", fill_sty)
		item["label"].add_theme_color_override("font_color",
			Color(0.95, 0.76, 0.08) if met else Color(0.70, 0.70, 0.70))
		if not met: all_met = false

	_set_ready(all_met)

func _set_ready(ready: bool) -> void:
	if ready == _ready_state: return
	_ready_state = ready
	if ready:
		_purify_btn.text     = "✦ 开始渡化"
		_purify_btn.disabled = false
		_title_lbl.add_theme_color_override("font_color", Color(0.95, 0.76, 0.08))
		_play_pulse()
	else:
		_purify_btn.text     = "条件未满足"
		_purify_btn.disabled = true
		_title_lbl.add_theme_color_override("font_color", Color(0.65, 0.52, 0.12))
		if _pulse_tween: _pulse_tween.kill()
		modulate.a = 1.0

func _play_pulse() -> void:
	if _pulse_tween: _pulse_tween.kill()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(self, "modulate:a", 0.65, 0.8)
	_pulse_tween.tween_property(self, "modulate:a", 1.0,  0.8)

func _on_emotion_changed(_emotion: String, _old: int, _new: int) -> void:
	update_display()

## 渡化条件已由状态机触发——更新按钮为激活状态
func on_du_hua_available(_desc: String) -> void:
	_set_ready(true)
