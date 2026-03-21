class_name BossDialogueUI
extends Control
## Boss 渡化/镇压对话 UI
## 职责：加载 boss_dialogues.json，逐行播放对话，等待玩家确认

signal dialogue_finished(route: String)

# 节点引用（由父场景赋值，或 _ready 中查找）
var _dialogue_box: RichTextLabel   ## 显示对话文本
var _speaker_label: Label          ## 显示说话人
var _next_btn: Button              ## 继续按钮

# 对话状态
var _lines: Array = []
var _current_index: int = 0
var _boss_id: String = ""
var _character_id: String = ""
var _route: String = ""
var _current_stage: int = 0

# 旁白说话人标识
const NARRATOR_SPEAKER: String = "旁白"

func _ready() -> void:
	# 尝试从节点树中查找子节点
	_dialogue_box = get_node_or_null("DialogueBox") as RichTextLabel
	_speaker_label = get_node_or_null("SpeakerLabel") as Label
	_next_btn = get_node_or_null("NextButton") as Button

	# 若节点存在，连接按钮信号
	if _next_btn != null:
		if not _next_btn.pressed.is_connected(_on_next_pressed):
			_next_btn.pressed.connect(_on_next_pressed)

	# 初始隐藏
	hide()


## 从 boss_dialogues.json 加载指定对话路线，显示第一行
## boss_id: "jiang_panyu" / "song_lanxiu" / "shen_sujin"
## character_id: "ruan_ruyue" / "shen_tiejun"
## route: "purification" / "suppression"
func start_dialogue(boss_id: String, character_id: String, route: String) -> void:
	_boss_id = boss_id
	_character_id = character_id
	_route = route
	_current_index = 0
	_lines = []

	# 加载并解析 JSON
	var dialogue_data: Dictionary = _load_dialogue_json()
	if dialogue_data.is_empty():
		push_error("BossDialogueUI: 无法加载 boss_dialogues.json")
		return

	# 按路径取出对话行
	var boss_block: Variant = dialogue_data.get("boss_dialogues", {})
	if not boss_block is Dictionary:
		push_error("BossDialogueUI: boss_dialogues 结构异常")
		return

	var char_block: Variant = (boss_block as Dictionary).get(boss_id, {})
	if not char_block is Dictionary:
		push_error("BossDialogueUI: 找不到 boss_id=%s" % boss_id)
		return

	var route_block: Variant = (char_block as Dictionary).get(character_id, {})
	if not route_block is Dictionary:
		push_error("BossDialogueUI: 找不到 character_id=%s" % character_id)
		return

	var route_data: Variant = (route_block as Dictionary).get(route, {})
	if not route_data is Dictionary:
		push_error("BossDialogueUI: 找不到 route=%s" % route)
		return

	# 普通（非多阶段）对话
	var raw_lines: Variant = (route_data as Dictionary).get("lines", [])
	if raw_lines is Array:
		_lines = raw_lines as Array
	else:
		push_error("BossDialogueUI: lines 字段类型错误")
		return

	if _lines.is_empty():
		push_warning("BossDialogueUI: 对话行为空，boss=%s route=%s" % [boss_id, route])
		return

	show()
	_show_line(0)


## 用于沈素锦三阶段渡化 —— 加载指定阶段的对话行
## stage: 1 / 2 / 3
func start_multistage_dialogue(boss_id: String, character_id: String, stage: int) -> void:
	_boss_id = boss_id
	_character_id = character_id
	_route = "purification"
	_current_stage = stage
	_current_index = 0
	_lines = []

	var dialogue_data: Dictionary = _load_dialogue_json()
	if dialogue_data.is_empty():
		push_error("BossDialogueUI: 无法加载 boss_dialogues.json")
		return

	var boss_block: Variant = dialogue_data.get("boss_dialogues", {})
	if not boss_block is Dictionary:
		return

	var char_block: Variant = (boss_block as Dictionary).get(boss_id, {})
	if not char_block is Dictionary:
		return

	var route_block: Variant = (char_block as Dictionary).get(character_id, {})
	if not route_block is Dictionary:
		return

	var purification_data: Variant = (route_block as Dictionary).get("purification", {})
	if not purification_data is Dictionary:
		return

	# 取 stages 数组，找到对应 stage
	var stages_array: Variant = (purification_data as Dictionary).get("stages", [])
	if not stages_array is Array:
		push_error("BossDialogueUI: stages 字段类型错误")
		return

	var found: bool = false
	for stage_entry: Variant in (stages_array as Array):
		if not stage_entry is Dictionary:
			continue
		var entry_dict: Dictionary = stage_entry as Dictionary
		var stage_num: Variant = entry_dict.get("stage", -1)
		if stage_num == stage:
			var raw_lines: Variant = entry_dict.get("lines", [])
			if raw_lines is Array:
				_lines = raw_lines as Array
			found = true
			break

	if not found:
		push_error("BossDialogueUI: 找不到 stage=%d，boss=%s" % [stage, boss_id])
		return

	if _lines.is_empty():
		push_warning("BossDialogueUI: stage=%d 对话行为空" % stage)
		return

	show()
	_show_line(0)


## 按钮回调：推进对话；到最后一行时发出 dialogue_finished 信号并隐藏
func _on_next_pressed() -> void:
	_current_index += 1
	if _current_index >= _lines.size():
		# 对话结束
		hide()
		emit_signal("dialogue_finished", _route)
	else:
		_show_line(_current_index)


## 更新 UI 显示当前行
## 旁白：斜体灰色；角色台词：正常白色
func _show_line(index: int) -> void:
	if index < 0 or index >= _lines.size():
		return

	var line_entry: Variant = _lines[index]
	if not line_entry is Dictionary:
		return

	var line_dict: Dictionary = line_entry as Dictionary
	var speaker: String = str(line_dict.get("speaker", ""))
	var text: String = str(line_dict.get("text", ""))

	# 更新说话人标签
	if _speaker_label != null:
		_speaker_label.text = speaker

	# 更新对话文本（BBCode 格式）
	if _dialogue_box != null:
		_dialogue_box.bbcode_enabled = true
		if speaker == NARRATOR_SPEAKER:
			# 旁白：斜体 + 灰色
			_dialogue_box.text = "[color=#aaaaaa][i]%s[/i][/color]" % text
		else:
			# 角色台词：正常白色
			_dialogue_box.text = "[color=#ffffff]%s[/color]" % text


## 读取并解析 res://data/boss_dialogues.json
## 返回解析后的 Dictionary；失败时返回空 Dictionary
func _load_dialogue_json() -> Dictionary:
	var path: String = "res://data/boss_dialogues.json"
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("BossDialogueUI: 无法打开文件 %s，错误码=%d" % [path, FileAccess.get_open_error()])
		return {}

	var raw_text: String = file.get_as_text()
	file.close()

	var json_parser: JSON = JSON.new()
	var error_code: int = json_parser.parse(raw_text)
	if error_code != OK:
		push_error("BossDialogueUI: JSON 解析失败，行=%d，错误=%s" % [
			json_parser.get_error_line(),
			json_parser.get_error_message()
		])
		return {}

	var result: Variant = json_parser.get_data()
	if not result is Dictionary:
		push_error("BossDialogueUI: JSON 根节点不是 Dictionary")
		return {}

	return result as Dictionary
