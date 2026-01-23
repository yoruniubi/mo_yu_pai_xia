extends Control

# 记录初始位置，防止动画导致位置偏移
var initial_title_y: float

func _on_startbutton_pressed() -> void:
	print("开始游戏！")
	get_tree().change_scene_to_file("res://Scenes/character_selection.tscn")

func _on_exitbutton_pressed() -> void:
	get_tree().quit()

func _ready():
	# 1. 音频处理
	var bgm = preload("res://Assets/Music/Cubicle_Coffee.mp3") 
	BgmManager.play_music(bgm)
	
	# 2. 布局记录
	initial_title_y = $Label.position.y
	
	# 3. 初始化视觉
	apply_css_to_buttons()
	animate_title()
	
	# 4. 确保海浪初始设置（代码双保险）
	setup_waves()

func setup_waves():
	# 确保图片不居中，方便我们计算
	$WaveBack.centered = false
	$WaveFront.centered = false
	
	# 设置海浪的水平位置 (从屏幕最左边 0 开始)
	$WaveBack.position.x = 0
	$WaveFront.position.x = 0
	
	# 设置海浪的垂直位置 (放在标题文字下方)
	# 假设你的标题初始 Y 是 initial_title_y
	var wave_y = initial_title_y + $Label.size.y * 0.7 # 稍微没过文字一点点
	$WaveBack.position.y = wave_y
	$WaveFront.position.y = wave_y + 10 # 前浪稍微低一点，有错落感
	#$WaveBack.modulate = Color(0.302, 0.502, 0.8, 0.616) 
	#$WaveFront.modulate = Color(0.6, 0.8, 1.0, 0.839)
	$WaveBack.region_enabled = true
	$WaveBack.region_rect = Rect2(0, 0, 720, 120)
	$WaveFront.region_enabled = true
	$WaveFront.region_rect = Rect2(0, 0, 720, 120)
	
	

func apply_css_to_buttons():
	for btn in $VBoxContainer.get_children():
		if btn is Button:
			var style_normal = _create_style("#fdf5e6", 30, 8)
			var style_hover = _create_style("#a8d8ea", 30, 12)
			var style_pressed = _create_style("#7fb5c9", 30, 0)
			
			btn.add_theme_stylebox_override("normal", style_normal)
			btn.add_theme_stylebox_override("hover", style_hover)
			btn.add_theme_stylebox_override("pressed", style_pressed)
			
			btn.add_theme_color_override("font_color", Color("#4a4a4a"))
			btn.add_theme_color_override("font_hover_color", Color("#ffffff"))
			btn.add_theme_font_size_override("font_size", 40)
			
			btn.custom_minimum_size = Vector2(350, 100) # 稍微加大一点点，给图标留空间
			btn.pivot_offset = btn.custom_minimum_size / 2.0
			
			# 悬停动画 (增加 TRANS_BACK 让它更Q弹)
			btn.mouse_entered.connect(func(): 
				create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK).tween_property(btn, "scale", Vector2(1.05, 1.05), 0.2)
			)
			btn.mouse_exited.connect(func(): 
				create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).tween_property(btn, "scale", Vector2(1.0, 1.0), 0.2)
			)
			
			if btn.name == "startbutton":
				btn.icon = preload("res://Assets/Icons/start.png")
			elif btn.name == "exitbutton":
				btn.icon = preload("res://Assets/Icons/exit.png")
			
			btn.expand_icon = true 
			btn.add_theme_constant_override("icon_max_width", 50) 
			btn.add_theme_constant_override("h_separation", 20) 
			
			btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
			
			btn.add_theme_color_override("icon_normal_color", Color("#4a4a4a"))
			btn.add_theme_color_override("icon_hover_color", Color("#ffffff"))

func _create_style(color_hex: String, radius: int, shadow: int) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(color_hex)
	sb.set_corner_radius_all(radius)
	sb.shadow_size = shadow
	sb.shadow_offset = Vector2(0, shadow / 2.0)
	sb.content_margin_left = 40 # 增加左边距，让图标不贴边
	sb.content_margin_right = 20
	return sb

func animate_title():
	var title = $Label
	# 关键：在 Godot 4 中，UI 节点的 size 往往在第一帧后才准确
	# 使用 await 确保获取到准确的中心点
	await get_tree().process_frame 
	title.pivot_offset = title.size / 2.0
	
	# 呼吸效果
	var tween_scale = create_tween().set_loops()
	tween_scale.tween_property(title, "scale", Vector2(1.08, 1.08), 2.0).set_trans(Tween.TRANS_SINE)
	tween_scale.tween_property(title, "scale", Vector2(1.0, 1.0), 2.0).set_trans(Tween.TRANS_SINE)
	
	# 倾斜效果
	var tween_rot = create_tween().set_loops()
	tween_rot.tween_property(title, "rotation_degrees", 3.0, 1.8).set_trans(Tween.TRANS_SINE)
	tween_rot.tween_property(title, "rotation_degrees", -3.0, 1.8).set_trans(Tween.TRANS_SINE)

func _process(delta):
	# 1. 无限滚动
	# 检查节点是否存在防止报错
	if has_node("WaveBack") and has_node("WaveFront"):
		$WaveBack.region_rect.position.x += 40 * delta
		$WaveFront.region_rect.position.x += 70 * delta
	
	# 2. 整体浮动效果
	var time = Time.get_ticks_msec() / 1000.0
	# 标题平滑浮动（基于记录的初始位置）
	$Label.position.y = initial_title_y + sin(time * 1.5) * 15
	
	# 海浪也带一点点上下感
	if has_node("WaveFront"):
		$WaveFront.position.y += sin(time * 2.0) * 0.1
