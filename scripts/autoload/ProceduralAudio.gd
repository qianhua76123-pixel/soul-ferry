extends Node
## ProceduralAudio.gd - 程序化音效合成器（Autoload 单例）
## 使用 AudioStreamGenerator 合成所有 SFX，无需外部音频文件

# SFX 播放池（4个并发）
const POOL_SIZE: int = 4
var _pool: Array[AudioStreamPlayer] = []
var _pool_idx: int = 0

# BGM 合成播放器
var _bgm_gen_player: AudioStreamPlayer = null
var _bgm_playback: AudioStreamGeneratorPlayback = null
var _bgm_phase: float = 0.0
var _bgm_active: bool = false
var _bgm_notes: Array[float] = []   # 当前 BGM 音符序列
var _bgm_note_idx: int = 0
var _bgm_note_timer: float = 0.0
var _bgm_note_duration: float = 0.5

# 五声音阶（古风，单位 Hz）
const PENTATONIC: Array = [261.63, 293.66, 329.63, 392.0, 440.0,
							523.25, 587.33, 659.25, 784.0, 880.0]

func _ready() -> void:
	# 初始化 SFX 播放池
	for i: int in range(POOL_SIZE):
		var gen: AudioStreamGenerator = AudioStreamGenerator.new()
		gen.mix_rate = 22050.0
		gen.buffer_length = 0.1
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.stream = gen
		player.bus = "Master"
		player.name = "ProcSFX_%d" % i
		add_child(player)
		_pool.append(player)

	# BGM 合成播放器（较长 buffer）
	var bgm_gen: AudioStreamGenerator = AudioStreamGenerator.new()
	bgm_gen.mix_rate = 22050.0
	bgm_gen.buffer_length = 0.3
	_bgm_gen_player = AudioStreamPlayer.new()
	_bgm_gen_player.stream = bgm_gen
	_bgm_gen_player.bus = "Master"
	_bgm_gen_player.name = "ProcBGM"
	_bgm_gen_player.volume_db = -8.0
	add_child(_bgm_gen_player)

func has(sfx_name: String) -> bool:
	## SoundManager 查询是否支持该音效
	return sfx_name in _SFX_DEFS

func play(sfx_name: String, pitch: float = 1.0, _vol_db: float = 0.0) -> void:
	## 播放指定音效
	if not has(sfx_name): return
	var params: Dictionary = _SFX_DEFS[sfx_name]
	var player: AudioStreamPlayer = _pool[_pool_idx % POOL_SIZE]
	_pool_idx = (_pool_idx + 1) % POOL_SIZE
	if player.playing:
		player.stop()
	player.pitch_scale = pitch
	player.volume_db = params.get("vol", -6.0)
	player.play()
	var pb: AudioStreamGeneratorPlayback = player.get_stream_playback() as AudioStreamGeneratorPlayback
	if not pb: return
	_synthesize(pb, params)

# ══════════════════════════════════════════════════════
#  音效定义表
# ══════════════════════════════════════════════════════
const _SFX_DEFS: Dictionary = {
	# shape: "sine"|"square"|"tri"|"noise"|"pluck"
	# freq: 基频 Hz
	# dur: 持续秒
	# sweep: 频率扫描终止值（0=不扫描）
	# vol: 音量 dB
	"card_draw":        {"shape":"pluck",  "freq":520.0, "dur":0.18, "vol":-8.0},
	"card_play":        {"shape":"pluck",  "freq":440.0, "dur":0.22, "vol":-7.0},
	"card_discard":     {"shape":"sine",   "freq":300.0, "dur":0.15, "sweep":180.0, "vol":-10.0},
	"card_upgrade":     {"shape":"sine",   "freq":660.0, "dur":0.4,  "sweep":880.0, "vol":-6.0},
	"attack_hit":       {"shape":"noise",  "freq":0.0,   "dur":0.12, "vol":-5.0},
	"attack_miss":      {"shape":"sine",   "freq":200.0, "dur":0.08, "sweep":150.0, "vol":-12.0},
	"shield_block":     {"shape":"square", "freq":220.0, "dur":0.14, "vol":-8.0},
	"heal":             {"shape":"sine",   "freq":528.0, "dur":0.35, "sweep":660.0, "vol":-7.0},
	"burn_tick":        {"shape":"noise",  "freq":0.0,   "dur":0.06, "vol":-14.0},
	"poison_tick":      {"shape":"sine",   "freq":180.0, "dur":0.08, "vol":-14.0},
	"du_hua_success":   {"shape":"sine",   "freq":523.0, "dur":0.8,  "sweep":1046.0, "vol":-4.0},
	"battle_victory":   {"shape":"pluck",  "freq":392.0, "dur":0.6,  "vol":-5.0},
	"battle_defeat":    {"shape":"sine",   "freq":196.0, "dur":0.7,  "sweep":98.0,   "vol":-6.0},
	"emotion_rise":     {"shape":"sine",   "freq":440.0, "dur":0.15, "sweep":550.0,  "vol":-10.0},
	"emotion_drop":     {"shape":"sine",   "freq":440.0, "dur":0.15, "sweep":330.0,  "vol":-10.0},
	"disorder_trigger": {"shape":"square", "freq":160.0, "dur":0.3,  "sweep":80.0,   "vol":-5.0},
	"relic_trigger":    {"shape":"pluck",  "freq":587.0, "dur":0.25, "vol":-8.0},
	"relic_acquire":    {"shape":"sine",   "freq":659.0, "dur":0.5,  "sweep":880.0,  "vol":-5.0},
	"btn_click":        {"shape":"sine",   "freq":800.0, "dur":0.06, "vol":-12.0},
	"btn_hover":        {"shape":"sine",   "freq":600.0, "dur":0.04, "vol":-16.0},
	"turn_end":         {"shape":"sine",   "freq":330.0, "dur":0.2,  "vol":-10.0},
	"scene_transition": {"shape":"sine",   "freq":220.0, "dur":0.4,  "sweep":440.0,  "vol":-8.0},
	"gold_gain":        {"shape":"pluck",  "freq":660.0, "dur":0.18, "vol":-8.0},
	"gold_spend":       {"shape":"pluck",  "freq":440.0, "dur":0.15, "vol":-10.0},
	"event_text":       {"shape":"sine",   "freq":900.0, "dur":0.03, "vol":-18.0},
	"menu_confirm":     {"shape":"sine",   "freq":523.0, "dur":0.15, "sweep":659.0,  "vol":-8.0},
	"menu_cancel":      {"shape":"sine",   "freq":440.0, "dur":0.12, "sweep":330.0,  "vol":-10.0},
}

# ══════════════════════════════════════════════════════
#  合成核心
# ══════════════════════════════════════════════════════
func _synthesize(pb: AudioStreamGeneratorPlayback, params: Dictionary) -> void:
	var shape: String = params.get("shape", "sine")
	var freq: float   = params.get("freq",  440.0)
	var dur: float    = params.get("dur",   0.2)
	var sweep: float  = params.get("sweep", 0.0)
	var mix_rate: float = 22050.0
	var num_samples: int = int(dur * mix_rate)

	var frames: PackedVector2Array = PackedVector2Array()
	frames.resize(num_samples)

	for i: int in range(num_samples):
		var t: float = float(i) / mix_rate
		var progress: float = float(i) / float(maxi(num_samples - 1, 1))

		# 频率扫描（线性插值）
		var cur_freq: float = freq
		if sweep > 0.0:
			cur_freq = lerpf(freq, sweep, progress)

		# 包络（简单 ADSR：前10%淡入，后30%淡出）
		var env: float = 1.0
		if progress < 0.1:
			env = progress / 0.1
		elif progress > 0.7:
			env = (1.0 - progress) / 0.3

		# 波形生成
		var sample: float = 0.0
		match shape:
			"sine":
				sample = sin(TAU * cur_freq * t)
			"square":
				sample = 1.0 if sin(TAU * cur_freq * t) >= 0.0 else -1.0
				sample *= 0.4  # 方波音量压低
			"tri":
				var phase: float = fmod(cur_freq * t, 1.0)
				sample = (4.0 * phase - 1.0) if phase < 0.5 else (3.0 - 4.0 * phase)
				sample *= 0.7
			"noise":
				sample = randf_range(-1.0, 1.0)
				# 加一点低频调制让噪音更有质感
				sample *= (0.5 + 0.5 * sin(TAU * 80.0 * t))
			"pluck":
				# Karplus-Strong 简化版：指数衰减 sine
				var decay: float = exp(-t * 8.0)
				sample = sin(TAU * cur_freq * t) * decay
				# 加谐波
				sample += sin(TAU * cur_freq * 2.0 * t) * decay * 0.3
				sample += sin(TAU * cur_freq * 3.0 * t) * decay * 0.15

		frames[i] = Vector2(sample * env, sample * env)

	pb.push_buffer(frames)

# ══════════════════════════════════════════════════════
#  程序化 BGM（五声音阶环境音）
# ══════════════════════════════════════════════════════
func start_proc_bgm(style: String = "map") -> void:
	## 启动程序化 BGM 循环
	_bgm_active = true
	_bgm_phase = 0.0
	_bgm_note_idx = 0
	_bgm_note_timer = 0.0

	match style:
		"map":
			# 悠远五声，稀疏节奏
			_bgm_notes = [261.63, 329.63, 392.0, 0.0, 440.0, 392.0, 0.0, 329.63,
							261.63, 0.0, 293.66, 329.63, 392.0, 0.0, 523.25, 0.0]
			_bgm_note_duration = 0.55
		"battle":
			# 急促五声，战斗感
			_bgm_notes = [392.0, 440.0, 392.0, 329.63, 392.0, 0.0, 440.0, 523.25,
							440.0, 392.0, 0.0, 329.63, 293.66, 261.63, 0.0, 392.0]
			_bgm_note_duration = 0.28
		"rest":
			# 宁静轻柔
			_bgm_notes = [261.63, 0.0, 0.0, 329.63, 0.0, 392.0, 0.0, 0.0,
							440.0, 0.0, 392.0, 0.0, 0.0, 329.63, 0.0, 261.63]
			_bgm_note_duration = 0.7
		_:
			_bgm_notes = [261.63, 329.63, 392.0, 440.0]
			_bgm_note_duration = 0.5

	if not _bgm_gen_player.playing:
		_bgm_gen_player.play()

func stop_proc_bgm() -> void:
	## 停止程序化 BGM
	_bgm_active = false
	_bgm_gen_player.stop()

func _process(delta: float) -> void:
	if not _bgm_active: return
	var pb: AudioStreamGeneratorPlayback = _bgm_gen_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if not pb: return

	_bgm_note_timer -= delta
	if _bgm_note_timer <= 0.0:
		_bgm_note_timer = _bgm_note_duration
		var note_freq: float = _bgm_notes[_bgm_note_idx % _bgm_notes.size()]
		_bgm_note_idx = (_bgm_note_idx + 1) % _bgm_notes.size()
		if note_freq > 0.0:
			_play_bgm_note(pb, note_freq, _bgm_note_duration * 0.7)

func _play_bgm_note(pb: AudioStreamGeneratorPlayback, freq: float, dur: float) -> void:
	## 向 BGM 播放器推送一个拨弦音符
	var mix_rate: float = 22050.0
	var num_samples: int = int(dur * mix_rate)
	var frames: PackedVector2Array = PackedVector2Array()
	frames.resize(num_samples)
	for i: int in range(num_samples):
		var t: float = float(i) / mix_rate
		var progress: float = float(i) / float(maxi(num_samples - 1, 1))
		var env: float = 1.0
		if progress < 0.05: env = progress / 0.05
		elif progress > 0.6: env = (1.0 - progress) / 0.4
		# 拨弦音色（sine + 谐波 + 指数衰减）
		var decay: float = exp(-t * 4.0)
		var sample: float = sin(TAU * freq * t) * decay * 0.7
		sample += sin(TAU * freq * 2.0 * t) * decay * 0.2
		sample += sin(TAU * freq * 0.5 * t) * decay * 0.15  # 低八度
		sample *= env * 0.35  # BGM 整体较安静
		frames[i] = Vector2(sample, sample)
	pb.push_buffer(frames)
