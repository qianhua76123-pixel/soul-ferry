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

# 渡化频率进度条和状态标签
var _freq_bar: ProgressBar = null
var _state_lbl: Label = null

# 当 du_hua_available 被调用时（状态机已确认），直接解锁按钮
var _state_machine_confirmed: bool = false

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
	_title_lbl.add_theme_color_override("font_color", UIConstants.color_of("gold_dim"))
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_title_lbl)

	# 条件进度行
	_cond_row = HBoxContainer.new()
	_cond_row.add_theme_constant_override("separation", 8)
	_cond_row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_cond_row)

	# 渡化频率进度条 + 状态标签
	var freq_row: VBoxContainer = VBoxContainer.new()
	freq_row.add_theme_constant_override("separation", 2)
	add_child(freq_row)

	var freq_title: Label = Label.new()
	freq_title.text = "共鸣频率"
	freq_title.add_theme_font_size_override("font_size", 10)
	freq_title.add_theme_color_override("font_color", UIConstants.color_of("text_dim"))
	freq_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	freq_row.add_child(freq_title)

	_freq_bar = ProgressBar.new()
	_freq_bar.min_value = 0
	_freq_bar.max_value = 100
	_freq_bar.value = 0
	_freq_bar.show_percentage = false
	_freq_bar.custom_minimum_size = Vector2(200, 6)
	var freq_fill: StyleBoxFlat = StyleBoxFlat.new()
	freq_fill.bg_color = Color(0.8, 0.65, 0.2, 0.9)
	freq_fill.set_corner_radius_all(3)
	_freq_bar.add_theme_stylebox_override("fill", freq_fill)
	var freq_bg: StyleBoxFlat = StyleBoxFlat.new()
	freq_bg.bg_color = Color(0.15, 0.15, 0.15, 0.8)
	freq_bg.set_corner_radius_all(3)
	_freq_bar.add_theme_stylebox_override("background", freq_bg)
	freq_row.add_child(_freq_bar)

	_state_lbl = Label.new()
	_state_lbl.text = ""
	_state_lbl.add_theme_font_size_override("font_size", 10)
	_state_lbl.add_theme_color_override("font_color", UIConstants.color_of("text_muted"))
	_state_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	freq_row.add_child(_state_lbl)

	# 渡化按钮
	_purify_btn = Button.new()
	_purify_btn.text     = "条件未满足"
	_purify_btn.disabled = true
	_purify_btn.add_theme_font_size_override("font_size", 12)
	_purify_btn.custom_minimum_size = Vector2(200, 28)
	_purify_btn.pressed.connect(func(): purify_requested.emit())
	_purify_btn.add_theme_stylebox_override("normal", UIConstants.make_button_style("parch", "gold_dim"))
	_purify_btn.add_theme_stylebox_override("hover", UIConstants.make_button_style("parch", "gold"))
	_purify_btn.add_theme_color_override("font_color", UIConstants.color_of("text_primary"))
	add_child(_purify_btn)

func setup_conditions(enemy_data: Dictionary) -> void:
	## 根据敌人数据初始化渡化条件显示
	_state_machine_confirmed = false
	# 清空旧条件
	for child in _cond_row.get_children(): child.queue_free()
	_cond_items.clear()

	var cond: Dictionary = enemy_data.get("du_hua_condition", {})
	var emotion_req: Dictionary = cond.get("emotion_requirement", {})

	if emotion_req.is_empty():
		# 无情绪条件（如连续出牌型）：显示说明文字
		var hint: Label = Label.new()
		hint.text = cond.get("description", "满足特殊条件后触发")
		hint.add_theme_font_size_override("font_size", 11)
		hint.add_theme_color_override("font_color", UIConstants.color_of("text_dim"))
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_cond_row.add_child(hint)
		return

	# 逐个情绪条件构建进度条
	for emotion: String in emotion_req:
		var required: int = int(emotion_req[emotion])
		var col: VBoxContainer = VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		_cond_row.add_child(col)

		var lbl: Label = Label.new()
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.text = "%s 0/%d" % [EMOTION_CN.get(emotion, emotion), required]
		col.add_child(lbl)

		var bar: ProgressBar = ProgressBar.new()
		bar.min_value = 0
		bar.max_value = required
		bar.value     = 0
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(44, 8)
		var sty: StyleBoxFlat = StyleBoxFlat.new()
		var track: Color = UIConstants.color_of("text_dim")
		sty.bg_color = Color(track.r, track.g, track.b, 0.58)
		bar.add_theme_stylebox_override("fill", sty)
		var sty_bg: StyleBoxFlat = StyleBoxFlat.new()
		var ink: Color = UIConstants.color_of("ink")
		sty_bg.bg_color = Color(ink.r, ink.g, ink.b, 0.62)
		bar.add_theme_stylebox_override("background", sty_bg)
		col.add_child(bar)

		_cond_items.append({
			"emotion": emotion, "required": required,
			"bar": bar, "label": lbl
		})

	update_display()

func update_display() -> void:
	## 刷新所有条件进度，检查是否全部满足
	if _state_machine_confirmed:
		# 状态机已确认触发，保持激活状态不再重新计算
		return

	var all_met: bool = _cond_items.is_empty()  # 无条件项时视为满足
	for item: Dictionary in _cond_items:
		var cur: int  = EmotionManager.values.get(item["emotion"], 0)
		var req: int  = item["required"]
		var met: bool = cur >= req
		item["bar"].value  = mini(cur, req)
		item["label"].text = "%s %d/%d%s" % [
			EMOTION_CN.get(item["emotion"], item["emotion"]),
			cur, req, " ✓" if met else ""]
		# 进度条颜色
		var fill_sty: StyleBoxFlat = StyleBoxFlat.new()
		var unfilled: Color = UIConstants.color_of("text_dim")
		fill_sty.bg_color = UIConstants.color_of("gold") if met else Color(unfilled.r, unfilled.g, unfilled.b, 0.58)
		item["bar"].add_theme_stylebox_override("fill", fill_sty)
		item["label"].add_theme_color_override("font_color",
			UIConstants.color_of("gold") if met else UIConstants.color_of("text_muted"))
		if not met: all_met = false

	_set_ready(all_met)

func _set_ready(ready: bool) -> void:
	if ready == _ready_state: return
	_ready_state = ready
	if ready:
		_purify_btn.text     = "✦ 开始渡化"
		_purify_btn.disabled = false
		_title_lbl.add_theme_color_override("font_color", UIConstants.color_of("gold"))
		_play_pulse()
	else:
		_purify_btn.text     = "条件未满足"
		_purify_btn.disabled = true
		_title_lbl.add_theme_color_override("font_color", UIConstants.color_of("gold_dim"))
		if _pulse_tween: _pulse_tween.kill()
		modulate.a = 1.0

func _play_pulse() -> void:
	if _pulse_tween: _pulse_tween.kill()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(self, "modulate:a", 0.65, 0.8)
	_pulse_tween.tween_property(self, "modulate:a", 1.0,  0.8)

func _on_emotion_changed(_emotion: String, _old: int, _new: int) -> void:
	update_display()

## 状态机已确认条件满足——强制激活按钮，忽略后续情绪变化
func on_du_hua_available(_desc: String) -> void:
	_state_machine_confirmed = true
	_set_ready(true)

## 渡化频率/中断/阶段状态更新——刷新进度条和状态标签
func on_du_hua_state_updated(frequency: int, interrupts: int, stage: int) -> void:
	if not _freq_bar or not _state_lbl:
		return
	_freq_bar.value = frequency
	# 颜色：频率越高越金黄
	var freq_fill_sty: StyleBoxFlat = StyleBoxFlat.new()
	if frequency >= 60:
		freq_fill_sty.bg_color = Color(0.95, 0.8, 0.2, 0.95)
	elif frequency >= 30:
		freq_fill_sty.bg_color = Color(0.7, 0.55, 0.2, 0.85)
	else:
		freq_fill_sty.bg_color = Color(0.45, 0.35, 0.2, 0.75)
	freq_fill_sty.set_corner_radius_all(3)
	_freq_bar.add_theme_stylebox_override("fill", freq_fill_sty)
	# 状态标签
	var quality_hint: String = ""
	if frequency >= 60:
		quality_hint = " → 完美"
	elif frequency >= 30:
		quality_hint = " → 稳定"
	else:
		quality_hint = " → 微弱"
	var interrupt_text: String = ""
	if interrupts == 1:
		interrupt_text = " ⚠︎中断×1"
	elif interrupts == 2:
		interrupt_text = " ⚠︎中断×2"
	elif stage == -1:
		interrupt_text = " ✗渡化封闭"
	_state_lbl.text = "频率%d%s%s" % [frequency, quality_hint, interrupt_text]
	# 渡化永久封闭时变红
	if stage == -1:
		_state_lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	elif interrupts > 0:
		_state_lbl.add_theme_color_override("font_color", Color(0.9, 0.65, 0.2))
	else:
		_state_lbl.add_theme_color_override("font_color", UIConstants.color_of("text_muted"))

## 渡化完成后重置（供下一场战斗）
func reset() -> void:
	_state_machine_confirmed = false
	_ready_state = false
	_purify_btn.text     = "条件未满足"
	_purify_btn.disabled = true
	_title_lbl.add_theme_color_override("font_color", UIConstants.color_of("gold_dim"))
	if _pulse_tween:
		_pulse_tween.kill()
	modulate.a = 1.0

## 增加渡化进度（空鸣/渡化之道选项调用）
func add_progress(_amount: float) -> void:
	## PurificationPanel 不直接管理数值进度，
	## 进度改变通知由状态机通过 du_hua_available 处理。
	## 此函数保留兼容接口，供 BattleScene 的空鸣面板调用。
	pass

