extends Control

## EmotionWheel.gd - 五情盘 UI 组件
## 显示当前五情状态、主导情绪、失调警告


@export var emotion_bars: Dictionary = {}  # emotion -> ProgressBar 节点

func _ready() -> void:
	# 监听情绪变化信号
	EmotionManager.emotion_changed.connect(_on_emotion_changed)
	EmotionManager.dominant_changed.connect(_on_dominant_changed)
	EmotionManager.disorder_triggered.connect(_on_disorder_triggered)
	EmotionManager.disorder_cleared.connect(_on_disorder_cleared)

func _on_emotion_changed(emotion: String, _old: int, new_value: int) -> void:
	_update_bar(emotion, new_value)

func _on_dominant_changed(_old: String, new_dominant: String) -> void:
	# 更新主导情绪高亮
	for emotion in emotion_bars:
		var bar: ProgressBar = emotion_bars[emotion]
		if is_instance_valid(bar):
			bar.modulate = Color.WHITE
	if new_dominant != "" and new_dominant in emotion_bars:
		var dominant_bar: ProgressBar = emotion_bars[new_dominant]
		if is_instance_valid(dominant_bar):
			dominant_bar.modulate = EmotionManager.get_emotion_color(new_dominant)

func _on_disorder_triggered(emotion: String) -> void:
	# 显示失调警告（闪烁/变色）
	if emotion in emotion_bars:
		var bar: ProgressBar = emotion_bars[emotion]
		if is_instance_valid(bar):
			bar.modulate = Color.RED

func _on_disorder_cleared(emotion: String) -> void:
	if emotion in emotion_bars:
		var bar: ProgressBar = emotion_bars[emotion]
		if is_instance_valid(bar):
			bar.modulate = Color.WHITE

func _update_bar(emotion: String, value: int) -> void:
	if emotion in emotion_bars:
		var bar: ProgressBar = emotion_bars[emotion]
		if is_instance_valid(bar):
			bar.value = value
			bar.max_value = EmotionManager.MAX_VALUE
