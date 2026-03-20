extends Node

## SoundManager.gd - 音效与背景音乐管理（第8个 Autoload）
## 占位符实现：所有 SFX/BGM 调用接口已就位，无需真实音频文件即可运行
## 替换真实音频时：将 .ogg/.wav 放入 res://audio/，取消相应注释即可

# ══════════════════════════════════════════════════════
#  信号
# ══════════════════════════════════════════════════════
signal bgm_changed(track_name: String)
signal sfx_played(sfx_name: String)

# ══════════════════════════════════════════════════════
#  内部节点（在 _ready 里动态创建，不依赖场景树）
# ══════════════════════════════════════════════════════
var _bgm_player:  AudioStreamPlayer = null
var _sfx_players: Array[AudioStreamPlayer] = []   # SFX 池：3个并发
const SFX_POOL_SIZE = 3

# ══════════════════════════════════════════════════════
#  音量设置（0.0 ~ 1.0）
# ══════════════════════════════════════════════════════
var bgm_volume: float = 0.7:
	set(v):
		bgm_volume = clamp(v, 0.0, 1.0)
		if _bgm_player:
			_bgm_player.volume_db = linear_to_db(bgm_volume)

var sfx_volume: float = 0.9:
	set(v):
		sfx_volume = clamp(v, 0.0, 1.0)
		for p in _sfx_players:
			p.volume_db = linear_to_db(sfx_volume)

var bgm_muted: bool = false
var sfx_muted: bool = false

# ══════════════════════════════════════════════════════
#  BGM 曲目定义
#  key = 逻辑名称，value = 音频文件路径（占位符为空串）
# ══════════════════════════════════════════════════════
const BGM_TRACKS: Dictionary = {
	"main_menu":   "",   # res://audio/bgm/main_menu.ogg
	"map":         "",   # res://audio/bgm/map.ogg
	"battle_1":    "",   # res://audio/bgm/battle_layer1.ogg
	"battle_2":    "",   # res://audio/bgm/battle_layer2.ogg
	"battle_3":    "",   # res://audio/bgm/battle_layer3.ogg
	"battle_boss": "",   # res://audio/bgm/battle_boss.ogg
	"event":       "",   # res://audio/bgm/event.ogg
	"shop":        "",   # res://audio/bgm/shop.ogg
	"rest":        "",   # res://audio/bgm/rest.ogg
	"victory":     "",   # res://audio/bgm/victory.ogg
	"defeat":      "",   # res://audio/bgm/defeat.ogg
	"ending_good": "",   # res://audio/bgm/ending_good.ogg
	"ending_bad":  "",   # res://audio/bgm/ending_bad.ogg
}

# ══════════════════════════════════════════════════════
#  SFX 音效定义
#  key = 逻辑名称，value = 音频文件路径（占位符为空串）
# ══════════════════════════════════════════════════════
const SFX_CLIPS: Dictionary = {
	# 卡牌操作
	"card_draw":       "",   # res://audio/sfx/card_draw.wav
	"card_play":       "",   # res://audio/sfx/card_play.wav
	"card_discard":    "",   # res://audio/sfx/card_discard.wav
	"card_upgrade":    "",   # res://audio/sfx/card_upgrade.wav
	# 战斗
	"attack_hit":      "",   # res://audio/sfx/attack_hit.wav
	"attack_miss":     "",   # res://audio/sfx/attack_miss.wav
	"shield_block":    "",   # res://audio/sfx/shield_block.wav
	"heal":            "",   # res://audio/sfx/heal.wav
	"burn_tick":       "",   # res://audio/sfx/burn_tick.wav
	"poison_tick":     "",   # res://audio/sfx/poison_tick.wav
	"du_hua_success":  "",   # res://audio/sfx/du_hua_success.wav
	"battle_victory":  "",   # res://audio/sfx/battle_victory.wav
	"battle_defeat":   "",   # res://audio/sfx/battle_defeat.wav
	# 情绪系统
	"emotion_rise":    "",   # res://audio/sfx/emotion_rise.wav
	"emotion_drop":    "",   # res://audio/sfx/emotion_drop.wav
	"disorder_trigger":"",   # res://audio/sfx/disorder_trigger.wav
	# 遗物
	"relic_trigger":   "",   # res://audio/sfx/relic_trigger.wav
	"relic_acquire":   "",   # res://audio/sfx/relic_acquire.wav
	# UI
	"btn_click":       "",   # res://audio/sfx/btn_click.wav
	"btn_hover":       "",   # res://audio/sfx/btn_hover.wav
	"turn_end":        "",   # res://audio/sfx/turn_end.wav
	"scene_transition":"",   # res://audio/sfx/scene_transition.wav
	# 事件/商店
	"gold_gain":       "",   # res://audio/sfx/gold_gain.wav
	"gold_spend":      "",   # res://audio/sfx/gold_spend.wav
	"event_text":      "",   # res://audio/sfx/event_text.wav  （逐字音效）
	# 主菜单
	"menu_confirm":    "",   # res://audio/sfx/menu_confirm.wav
	"menu_cancel":     "",   # res://audio/sfx/menu_cancel.wav
}

# ══════════════════════════════════════════════════════
#  当前播放状态
# ══════════════════════════════════════════════════════
var _current_bgm:  String = ""
var _sfx_pool_idx: int    = 0

# ══════════════════════════════════════════════════════
#  初始化
# ══════════════════════════════════════════════════════
func _ready() -> void:
	# BGM 播放器
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name       = "BGMPlayer"
	_bgm_player.bus        = "BGM"   # 如果没有 BGM Bus 会退回 Master
	_bgm_player.volume_db  = linear_to_db(bgm_volume)
	add_child(_bgm_player)

	# SFX 播放池
	for i in SFX_POOL_SIZE:
		var p = AudioStreamPlayer.new()
		p.name      = "SFXPlayer_%d" % i
		p.bus       = "SFX"
		p.volume_db = linear_to_db(sfx_volume)
		add_child(p)
		_sfx_players.append(p)

	# 连接场景切换信号，自动切换 BGM
	get_tree().node_added.connect(_on_node_added)

# ══════════════════════════════════════════════════════
#  公开 API
# ══════════════════════════════════════════════════════

## 播放 BGM（如果已在播放同一首则忽略）
## fade_time: 淡出旧 BGM 的时间（秒）；0 = 立即切换
func play_bgm(track_name: String, fade_time: float = 0.5) -> void:
	if track_name == _current_bgm:
		return
	if not BGM_TRACKS.has(track_name):
		push_warning("SoundManager: 未知 BGM 轨道 '%s'" % track_name)
		return

	_current_bgm = track_name
	bgm_changed.emit(track_name)

	var path = BGM_TRACKS[track_name]
	if path == "" or not ResourceLoader.exists(path, ""):
		# 占位符模式：静默跳过，不报错
		_log_stub("BGM", track_name)
		return

	var stream = load(path) as AudioStream
	if not stream:
		return

	if fade_time > 0.0 and _bgm_player.playing:
		# 淡出旧音乐，再切换
		var tw = create_tween()
		tw.tween_property(_bgm_player, "volume_db",
			linear_to_db(0.001), fade_time)
		tw.tween_callback(func():
			_bgm_player.stream   = stream
			_bgm_player.volume_db = linear_to_db(bgm_volume)
			if not bgm_muted:
				_bgm_player.play()
		)
	else:
		_bgm_player.stream = stream
		_bgm_player.volume_db = linear_to_db(bgm_volume)
		if not bgm_muted:
			_bgm_player.play()

## 停止 BGM
func stop_bgm(fade_time: float = 0.5) -> void:
	if not _bgm_player.playing:
		return
	if fade_time > 0.0:
		var tw = create_tween()
		tw.tween_property(_bgm_player, "volume_db", linear_to_db(0.001), fade_time)
		tw.tween_callback(_bgm_player.stop)
	else:
		_bgm_player.stop()
	_current_bgm = ""

## 播放 SFX（从池中选一个空闲播放器）
func play_sfx(sfx_name: String, pitch_scale: float = 1.0) -> void:
	if sfx_muted:
		return
	if not SFX_CLIPS.has(sfx_name):
		push_warning("SoundManager: 未知 SFX '%s'" % sfx_name)
		return

	sfx_played.emit(sfx_name)

	var path = SFX_CLIPS[sfx_name]
	if path == "" or not ResourceLoader.exists(path, ""):
		_log_stub("SFX", sfx_name)
		return

	var stream = load(path) as AudioStream
	if not stream:
		return

	# 轮询 SFX 池
	var player = _sfx_players[_sfx_pool_idx % SFX_POOL_SIZE]
	_sfx_pool_idx = (_sfx_pool_idx + 1) % SFX_POOL_SIZE
	player.stream      = stream
	player.pitch_scale = pitch_scale
	player.volume_db   = linear_to_db(sfx_volume)
	player.play()

## 静音/取消静音 BGM
func set_bgm_muted(muted: bool) -> void:
	bgm_muted = muted
	if muted:
		_bgm_player.stop()
	else:
		if _current_bgm != "" and not _bgm_player.playing:
			play_bgm(_current_bgm, 0.0)

## 静音/取消静音 SFX
func set_sfx_muted(muted: bool) -> void:
	sfx_muted = muted

## 获取当前 BGM 名称
func get_current_bgm() -> String:
	return _current_bgm

# ══════════════════════════════════════════════════════
#  场景自动切换 BGM（按场景根节点名判断）
# ══════════════════════════════════════════════════════
func _on_node_added(node: Node) -> void:
	# 只处理直接挂到 root 的顶层场景节点
	if node.get_parent() != get_tree().root:
		return
	match node.name:
		"MainMenu":        play_bgm("main_menu")
		"MapScene":        play_bgm("map")
		"EventScene":      play_bgm("event")
		"ShopScene":       play_bgm("shop")
		"RestScene":       play_bgm("rest")
		"CardRewardScene": pass   # 沿用上一首 BGM
		"BattleScene":     pass   # 战斗 BGM 由 BattleScene 自己在 start_battle 时按层级选择
		"EndingScene":     pass   # 结局由 EndingScene 自己选择

## 战斗场景专用：根据楼层和是否 Boss 选择 BGM
## 在 BattleScene._on_battle_started 里调用
func play_battle_bgm(layer: int, is_boss: bool) -> void:
	if is_boss:
		play_bgm("battle_boss")
	else:
		match layer:
			1: play_bgm("battle_1")
			2: play_bgm("battle_2")
			3: play_bgm("battle_3")
			_: play_bgm("battle_1")

# ══════════════════════════════════════════════════════
#  调试：占位符日志（发布时可关闭）
# ══════════════════════════════════════════════════════
var _stub_log_enabled: bool = true   # 改为 false 可静默

func _log_stub(kind: String, name: String) -> void:
	if _stub_log_enabled:
		print("[SoundManager] 占位符 %s: %s（文件未加载）" % [kind, name])

## 暂停菜单音量调节接口
func set_bgm_volume(v: float) -> void:
	bgm_volume = v

func set_sfx_volume(v: float) -> void:
	sfx_volume = v
