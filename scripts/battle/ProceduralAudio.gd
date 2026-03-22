extends Node

## ProceduralAudio.gd - 程序化音效生成器（无需外部音频文件）
## 用 PCM 数据直接构建 AudioStreamWAV，挂为 Autoload
## 所有音效在 _ready() 时生成并缓存，供 SoundManager 播放

const SAMPLE_RATE: int = 22050
const CHANNELS: int    = 1   # 单声道

var _cache: Dictionary = {}   # sfx_name → AudioStreamWAV
var _players: Array[AudioStreamPlayer] = []
var _pool_idx: int = 0
const POOL_SIZE: int = 6

func _ready() -> void:
	# 播放池
	for _i in POOL_SIZE:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.volume_db = -4.0
		add_child(p)
		_players.append(p)
	# 预生成所有音效
	_cache["card_draw"]        = _gen_card_draw()
	_cache["card_play"]        = _gen_card_play()
	_cache["card_discard"]     = _gen_card_discard()
	_cache["card_upgrade"]     = _gen_card_upgrade()
	_cache["attack_hit"]       = _gen_attack_hit()
	_cache["shield_block"]     = _gen_shield_block()
	_cache["heal"]             = _gen_heal()
	_cache["du_hua_success"]   = _gen_du_hua()
	_cache["battle_victory"]   = _gen_victory()
	_cache["battle_defeat"]    = _gen_defeat()
	_cache["disorder_trigger"] = _gen_disorder()
	_cache["emotion_rise"]     = _gen_emotion_rise()
	_cache["emotion_drop"]     = _gen_emotion_drop()
	_cache["relic_trigger"]    = _gen_relic_trigger()
	_cache["relic_acquire"]    = _gen_relic_acquire()
	_cache["turn_end"]         = _gen_turn_end()
	_cache["gold_gain"]        = _gen_gold_gain()
	_cache["gold_spend"]       = _gen_gold_spend()
	_cache["btn_click"]        = _gen_btn_click()
	_cache["btn_hover"]        = _gen_btn_hover()
	_cache["card_fail"]        = _gen_card_fail()
	_cache["boss_heartbeat"]   = _gen_boss_heartbeat()
	print("ProceduralAudio: %d 音效已生成" % _cache.size())

## 播放指定音效（pitch_scale 允许微调音调）
func play(sfx_name: String, pitch: float = 1.0, volume_offset: float = 0.0) -> void:
	if not _cache.has(sfx_name):
		push_warning("ProceduralAudio: 未知音效 '%s'" % sfx_name)
		return
	var player: AudioStreamPlayer = _players[_pool_idx % POOL_SIZE]
	_pool_idx = (_pool_idx + 1) % POOL_SIZE
	player.stream      = _cache[sfx_name]
	player.pitch_scale = pitch
	player.volume_db   = -4.0 + volume_offset
	player.play()

## 是否有该音效
func has(sfx_name: String) -> bool:
	return _cache.has(sfx_name)

# ════════════════════════════════════════════════════════
#  PCM 构建工具
# ════════════════════════════════════════════════════════

## 构建 AudioStreamWAV from PCM float 数组（-1.0~1.0）
func _make_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format    = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate  = SAMPLE_RATE
	wav.stereo    = false
	# float → int16 PCM
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var s: int = int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		data[i * 2]     = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	wav.data = data
	return wav

## 正弦波
func _sine(freq: float, dur: float, amp: float = 0.8) -> PackedFloat32Array:
	var n: int = int(SAMPLE_RATE * dur)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = sin(TAU * freq * float(i) / float(SAMPLE_RATE)) * amp
	return out

## 线性包络（ADSR 简化：attack+decay+sustain+release）
func _envelope(buf: PackedFloat32Array, attack: float, decay: float,
			   sustain_level: float, release: float) -> PackedFloat32Array:
	var n: int    = buf.size()
	var atk: int  = int(attack  * SAMPLE_RATE)
	var dec: int  = int(decay   * SAMPLE_RATE)
	var rel: int  = int(release * SAMPLE_RATE)
	var sus_end: int = n - rel
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	for i in n:
		var env: float
		if i < atk:
			env = float(i) / float(maxi(atk, 1))
		elif i < atk + dec:
			var t: float = float(i - atk) / float(maxi(dec, 1))
			env = 1.0 - t * (1.0 - sustain_level)
		elif i < sus_end:
			env = sustain_level
		else:
			var t: float = float(i - sus_end) / float(maxi(rel, 1))
			env = sustain_level * (1.0 - t)
		out[i] = buf[i] * env
	return out

## 白噪声
func _noise(dur: float, amp: float = 0.6) -> PackedFloat32Array:
	var n: int = int(SAMPLE_RATE * dur)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 0xABCD1234
	for i in n:
		out[i] = rng.randf_range(-amp, amp)
	return out

## 低通滤波（简单 IIR，平滑噪声变音色）
func _lowpass(buf: PackedFloat32Array, cutoff: float) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(buf.size())
	var rc: float  = 1.0 / (TAU * cutoff)
	var dt: float  = 1.0 / float(SAMPLE_RATE)
	var alpha: float = dt / (rc + dt)
	var prev: float = 0.0
	for i in buf.size():
		prev   = prev + alpha * (buf[i] - prev)
		out[i] = prev
	return out

## 混合两个音频流（对齐长度）
func _mix(a: PackedFloat32Array, b: PackedFloat32Array, ratio: float = 0.5) -> PackedFloat32Array:
	var n: int = maxi(a.size(), b.size())
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	for i in n:
		var sa: float = a[i] if i < a.size() else 0.0
		var sb: float = b[i] if i < b.size() else 0.0
		out[i] = sa * (1.0 - ratio) + sb * ratio
	return out

## 频率扫描（sweep：从 f_start 到 f_end 线性扫）
func _sweep(f_start: float, f_end: float, dur: float, amp: float = 0.75) -> PackedFloat32Array:
	var n: int = int(SAMPLE_RATE * dur)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var phase: float = 0.0
	for i in n:
		var t: float   = float(i) / float(n)
		var freq: float = f_start + (f_end - f_start) * t
		phase += TAU * freq / float(SAMPLE_RATE)
		out[i] = sin(phase) * amp
	return out

# ════════════════════════════════════════════════════════
#  各音效生成
# ════════════════════════════════════════════════════════

func _gen_card_draw() -> AudioStreamWAV:
	# 纸牌滑出：高频短促 sweep 向上 + 轻微噪声
	var s1: PackedFloat32Array = _sweep(800.0, 1400.0, 0.08, 0.5)
	var n1: PackedFloat32Array = _noise(0.08, 0.15)
	var mix: PackedFloat32Array = _mix(s1, n1, 0.25)
	return _make_wav(_envelope(mix, 0.005, 0.03, 0.1, 0.04))

func _gen_card_play() -> AudioStreamWAV:
	# 出牌：中频扫下 + 冲击感
	var s1: PackedFloat32Array = _sweep(600.0, 300.0, 0.12, 0.7)
	var s2: PackedFloat32Array = _sweep(1200.0, 500.0, 0.07, 0.4)
	var mix: PackedFloat32Array = _mix(s1, s2, 0.35)
	return _make_wav(_envelope(mix, 0.003, 0.04, 0.2, 0.07))

func _gen_card_discard() -> AudioStreamWAV:
	# 弃牌：低沉短促降调
	var s: PackedFloat32Array = _sweep(450.0, 220.0, 0.10, 0.55)
	var n: PackedFloat32Array = _noise(0.10, 0.10)
	return _make_wav(_envelope(_mix(s, n, 0.2), 0.004, 0.03, 0.15, 0.06))

func _gen_card_upgrade() -> AudioStreamWAV:
	# 升级：三音阶上升 (C4 E4 G4)
	var n_sam: int = int(SAMPLE_RATE * 0.45)
	var out: PackedFloat32Array = PackedFloat32Array(); out.resize(n_sam)
	var notes: Array[float] = [261.6, 329.6, 392.0]
	for ni in notes.size():
		var start: int = int(float(ni) / 3.0 * float(n_sam))
		var end_i: int  = int(float(ni + 1) / 3.0 * float(n_sam))
		var freq: float = notes[ni]
		for i in range(start, mini(end_i, n_sam)):
			var local_t: float = float(i - start) / float(end_i - start)
			var env2: float    = sin(local_t * PI)   # 半波包络
			out[i] += sin(TAU * freq * float(i) / float(SAMPLE_RATE)) * 0.6 * env2
	return _make_wav(out)

func _gen_attack_hit() -> AudioStreamWAV:
	# 攻击命中：冲击噪声 + 低频撞击
	var n1: PackedFloat32Array = _noise(0.06, 0.9)
	var s1: PackedFloat32Array = _sine(120.0, 0.06, 0.6)
	var mix: PackedFloat32Array = _mix(_lowpass(n1, 800.0), s1, 0.35)
	return _make_wav(_envelope(mix, 0.001, 0.02, 0.3, 0.04))

func _gen_shield_block() -> AudioStreamWAV:
	# 格挡：金属回响，高频短促
	var s1: PackedFloat32Array = _sine(880.0, 0.12, 0.6)
	var s2: PackedFloat32Array = _sine(1320.0, 0.06, 0.3)
	var mix: PackedFloat32Array = _mix(s1, s2, 0.3)
	return _make_wav(_envelope(mix, 0.001, 0.01, 0.4, 0.10))

func _gen_heal() -> AudioStreamWAV:
	# 回血：柔和上升，两音叠加 (E4 + G4)
	var s1: PackedFloat32Array = _sine(329.6, 0.30, 0.5)
	var s2: PackedFloat32Array = _sine(392.0, 0.30, 0.35)
	var mix: PackedFloat32Array = _mix(s1, s2, 0.4)
	return _make_wav(_envelope(mix, 0.015, 0.06, 0.5, 0.18))

func _gen_du_hua() -> AudioStreamWAV:
	# 渡化成功：空灵泛音叠加 (A3 + E4 + A4 + C#5)
	var freqs: Array[float] = [220.0, 329.6, 440.0, 554.4]
	var dur: float = 0.80
	var n_sam: int = int(SAMPLE_RATE * dur)
	var out: PackedFloat32Array = PackedFloat32Array(); out.resize(n_sam)
	for i in n_sam:
		var t: float = float(i) / float(SAMPLE_RATE)
		var env3: float = exp(-t * 1.5) * sin(t * PI / dur)
		for fi in freqs.size():
			out[i] += sin(TAU * freqs[fi] * t) * 0.3 / float(freqs.size()) * env3
	return _make_wav(out)

func _gen_victory() -> AudioStreamWAV:
	# 胜利：大三和弦上行 C-E-G-C (C4 E4 G4 C5)
	var notes2: Array[float] = [261.6, 329.6, 392.0, 523.3]
	var note_dur: float = 0.12
	var total: float    = note_dur * float(notes2.size()) + 0.25
	var n_sam2: int = int(SAMPLE_RATE * total)
	var out2: PackedFloat32Array = PackedFloat32Array(); out2.resize(n_sam2)
	for ni in notes2.size():
		var start2: int = int(float(ni) * note_dur * float(SAMPLE_RATE))
		var note_n: int = int(note_dur * 1.6 * float(SAMPLE_RATE))
		for i in note_n:
			var idx: int = start2 + i
			if idx >= n_sam2: break
			var env4: float = sin(float(i) / float(note_n) * PI)
			out2[idx] += sin(TAU * notes2[ni] * float(idx) / float(SAMPLE_RATE)) * 0.6 * env4
	return _make_wav(out2)

func _gen_defeat() -> AudioStreamWAV:
	# 失败：低沉下行，小三度
	var s1: PackedFloat32Array = _sweep(220.0, 110.0, 0.55, 0.65)
	var s2: PackedFloat32Array = _sweep(185.0,  92.5, 0.55, 0.40)
	var mix2: PackedFloat32Array = _mix(s1, s2, 0.4)
	return _make_wav(_envelope(mix2, 0.02, 0.10, 0.6, 0.30))

func _gen_disorder() -> AudioStreamWAV:
	# 情绪失调：刺耳高频噪声 + 低频混合
	var hi: PackedFloat32Array  = _noise(0.18, 0.8)
	var lo: PackedFloat32Array  = _sine(80.0, 0.18, 0.5)
	var mix3: PackedFloat32Array = _mix(_lowpass(hi, 2000.0), lo, 0.5)
	return _make_wav(_envelope(mix3, 0.005, 0.04, 0.6, 0.12))

func _gen_emotion_rise() -> AudioStreamWAV:
	# 情绪上升：短促向上 sweep
	return _make_wav(_envelope(_sweep(400.0, 700.0, 0.09, 0.45), 0.003, 0.02, 0.2, 0.05))

func _gen_emotion_drop() -> AudioStreamWAV:
	# 情绪下降：短促向下 sweep
	return _make_wav(_envelope(_sweep(700.0, 350.0, 0.10, 0.40), 0.003, 0.02, 0.2, 0.06))

func _gen_relic_trigger() -> AudioStreamWAV:
	# 遗物触发：金属叮声 (A5)
	var s: PackedFloat32Array = _sine(880.0, 0.25, 0.55)
	var h: PackedFloat32Array = _sine(1760.0, 0.15, 0.25)
	return _make_wav(_envelope(_mix(s, h, 0.3), 0.001, 0.01, 0.5, 0.20))

func _gen_relic_acquire() -> AudioStreamWAV:
	# 遗物获得：双音上行 + 余音
	var s1: PackedFloat32Array = _sine(523.3, 0.20, 0.5)
	var s2: PackedFloat32Array = _sine(659.3, 0.30, 0.5)
	var n_sam3: int = int(SAMPLE_RATE * 0.30)
	var out3: PackedFloat32Array = PackedFloat32Array(); out3.resize(n_sam3)
	for i in n_sam3:
		var v1: float = s1[i] if i < s1.size() else 0.0
		var v2: float = s2[i] if i < s2.size() else 0.0
		var t3: float = float(i) / float(SAMPLE_RATE)
		out3[i] = (v1 * 0.5 + v2 * 0.5) * exp(-t3 * 3.0)
	return _make_wav(out3)

func _gen_turn_end() -> AudioStreamWAV:
	# 回合结束：低沉中性提示音
	return _make_wav(_envelope(_sine(330.0, 0.12, 0.5), 0.005, 0.03, 0.3, 0.07))

func _gen_gold_gain() -> AudioStreamWAV:
	# 金币获得：硬币叮叮（两次短促高音）
	var n_sam4: int = int(SAMPLE_RATE * 0.18)
	var out4: PackedFloat32Array = PackedFloat32Array(); out4.resize(n_sam4)
	for hit in [0, int(SAMPLE_RATE * 0.08)]:
		for i in int(SAMPLE_RATE * 0.07):
			var idx: int = hit + i
			if idx >= n_sam4: break
			var env5: float = exp(-float(i) / float(SAMPLE_RATE) * 25.0)
			out4[idx] += sin(TAU * 1047.0 * float(idx) / float(SAMPLE_RATE)) * 0.55 * env5
	return _make_wav(out4)

func _gen_gold_spend() -> AudioStreamWAV:
	# 金币消耗：稍低版金币音
	var s: PackedFloat32Array = _sine(784.0, 0.10, 0.50)
	return _make_wav(_envelope(s, 0.002, 0.02, 0.3, 0.07))

func _gen_btn_click() -> AudioStreamWAV:
	# 按钮点击：短促中频
	return _make_wav(_envelope(_sweep(500.0, 400.0, 0.06, 0.45), 0.002, 0.01, 0.2, 0.04))

func _gen_btn_hover() -> AudioStreamWAV:
	# 按钮悬停：极短高频
	return _make_wav(_envelope(_sine(900.0, 0.04, 0.25), 0.001, 0.01, 0.1, 0.02))

func _gen_card_fail() -> AudioStreamWAV:
	# 出牌失败/费用不足：低沉否定音
	return _make_wav(_envelope(_sweep(300.0, 180.0, 0.10, 0.45), 0.003, 0.02, 0.3, 0.07))

func _gen_boss_heartbeat() -> AudioStreamWAV:
	# Boss心跳：低频双击 thud-thud
	var n_sam5: int = int(SAMPLE_RATE * 0.70)
	var out5: PackedFloat32Array = PackedFloat32Array(); out5.resize(n_sam5)
	for hit in [0, int(SAMPLE_RATE * 0.18)]:
		for i in int(SAMPLE_RATE * 0.14):
			var idx: int = hit + i
			if idx >= n_sam5: break
			var env6: float = exp(-float(i) / float(SAMPLE_RATE) * 20.0)
			out5[idx] += sin(TAU * 55.0 * float(idx) / float(SAMPLE_RATE)) * 0.75 * env6
			out5[idx] += _lowpass_sample(out5[idx], 200.0)
	return _make_wav(out5)

func _lowpass_sample(v: float, _cutoff: float) -> float:
	return v * 0.0   # placeholder — 心跳音在 _gen_boss_heartbeat 内已足够
