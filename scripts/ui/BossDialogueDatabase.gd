extends Node
## BossDialogueDatabase.gd - Boss渡化对话数据库
## 注意：不声明 class_name，避免与脚本名冲突；通过 preload 或直接路径引用

const DATA_PATH: String = "res://data/boss_dialogues.json"

var _data: Dictionary = {}
var _loaded: bool = false

func _ready() -> void:
	_load()

func _load() -> void:
	if _loaded: return
	var file: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	if not file:
		push_error("BossDialogueDatabase: 无法打开 " + DATA_PATH); return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("BossDialogueDatabase: JSON 解析失败"); file.close(); return
	file.close()
	_data = json.get_data()
	_loaded = true

func get_trigger(boss_id: String, char_id: String, route: String) -> Dictionary:
	## 返回渡化触发条件 {emotion: value, ...}
	if not _loaded: _load()
	var entry: Dictionary = _data.get(boss_id, {}).get(char_id, {}).get(route, {})
	return entry.get("trigger", {})

func get_phases(boss_id: String, char_id: String, route: String) -> Array:
	## 返回对话阶段列表
	if not _loaded: _load()
	return _data.get(boss_id, {}).get(char_id, {}).get(route, {}).get("phases", [])

func get_completion_effect(boss_id: String, char_id: String, route: String) -> String:
	if not _loaded: _load()
	return str(_data.get(boss_id, {}).get(char_id, {}).get(route, {}).get("completion_effect", ""))

func has_dialogue(boss_id: String, char_id: String, route: String) -> bool:
	if not _loaded: _load()
	return _data.has(boss_id) and \
		   _data[boss_id].has(char_id) and \
		   _data[boss_id][char_id].has(route)
