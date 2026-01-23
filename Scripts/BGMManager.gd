extends AudioStreamPlayer

# 定义淡入淡出的时长
const FADE_DURATION = 0.3

func _ready():
	# 初始音量设为静音，防止启动时爆音
	volume_db = -80

# 播放音乐的函数（带淡入效果）
func play_music(music_stream: AudioStream):
	# 如果当前已经在播放这段音乐了，就直接返回，防止音乐重头开始放
	if stream == music_stream and playing:
		return
	
	# 如果正在放别的，先淡出
	if playing:
		await fade_out()
	
	# 设置新音乐并播放
	stream = music_stream
	play()
	fade_in()

# 淡入逻辑
func fade_in():
	var tween = create_tween()
	# 从静音 (-80dB) 在指定时间内恢复到正常音量 (0dB)
	tween.tween_property(self, "volume_db", -6, FADE_DURATION).set_trans(Tween.TRANS_SINE)

# 淡出逻辑
func fade_out():
	var tween = create_tween()
	# 从当前音量降到静音
	tween.tween_property(self, "volume_db", -80, FADE_DURATION).set_trans(Tween.TRANS_SINE)
	# 等动画播完后停止播放
	await tween.finished
	stop()
