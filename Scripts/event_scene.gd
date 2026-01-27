extends Control

@onready var title_label = %TitleLabel
@onready var description_label = %DescriptionLabel
@onready var option_container = %OptionContainer
@onready var next_button = %NextButton

func _ready():
	next_button.hide()
	_setup_ui_styles()
	_create_floating_decorations()
	if has_node("%ResignationBar"):
		%ResignationBar.value = GameManager.current_level
	
	# 初始动画：全屏淡入
	modulate.a = 0
	var t = create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.5)
	
	setup_event()

func _create_floating_decorations():
	# 创建装饰容器
	var deco_container = Control.new()
	deco_container.name = "Decorations"
	deco_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(deco_container)
	move_child(deco_container, 1) # 放在 Background 之后
	
	var items = [
		"res://Assets/Images/coffee_cup.png",
		"res://Assets/Images/咸鱼.png",
		"res://Assets/Images/奶茶.png",
		"res://Assets/Images/小零食.png"
	]
	
	for i in range(8):
		var sprite = Sprite2D.new()
		var img_path = items[randi() % items.size()]
		if FileAccess.file_exists(img_path):
			sprite.texture = load(img_path)
		else:
			continue
			
		sprite.modulate.a = 0.3 # 半透明
		sprite.scale = Vector2(0.5, 0.5)
		deco_container.add_child(sprite)
		
		# 随机初始位置
		var screen = get_viewport_rect().size
		sprite.position = Vector2(randf_range(0, screen.x), randf_range(0, screen.y))
		
		# 浮动动画
		_animate_float(sprite)

func _animate_float(node: Node2D):
	var screen = get_viewport_rect().size
	var target_pos = Vector2(randf_range(0, screen.x), randf_range(0, screen.y))
	var duration = randf_range(10.0, 20.0)
	var rot = randf_range(-PI, PI)
	
	var t = create_tween().set_parallel(true).set_loops()
	t.tween_property(node, "position", target_pos, duration).set_trans(Tween.TRANS_SINE)
	t.tween_property(node, "rotation", rot, duration).set_trans(Tween.TRANS_SINE)

func _setup_ui_styles():
	# 添加暗角效果
	var vignette = TextureRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grad = Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0))
	grad.set_color(1, Color(0, 0, 0, 0.15))
	var tex = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 1.0)
	vignette.texture = tex
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(vignette)
	move_child(vignette, 2) # 放在背景和装饰之后

	# 标题美化
	title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.1))
	title_label.add_theme_constant_override("shadow_offset_x", 2)
	title_label.add_theme_constant_override("shadow_offset_y", 2)
	title_label.add_theme_constant_override("shadow_outline_size", 5)

	# 描述美化
	description_label.add_theme_color_override("font_color", Color("#5d5d5d"))
	
	# 美化进度条
	if has_node("%ResignationBar"):
		var bar = %ResignationBar
		_style_resignation_bar(bar)

	# 美化 NextButton
	var btn_style = _create_button_style("#4a4a4a", "#666666")
	next_button.add_theme_stylebox_override("normal", btn_style.normal)
	next_button.add_theme_stylebox_override("hover", btn_style.hover)
	next_button.add_theme_stylebox_override("pressed", btn_style.pressed)
	next_button.add_theme_color_override("font_color", Color.WHITE)

func _style_resignation_bar(bar: ProgressBar):
	# 背景样式：浅奶油灰，圆润感
	var sb_bg = StyleBoxFlat.new()
	sb_bg.bg_color = Color("#e0dcc8") 
	sb_bg.set_corner_radius_all(10)
	sb_bg.expand_margin_top = 4
	sb_bg.expand_margin_bottom = 4
	bar.add_theme_stylebox_override("background", sb_bg)
	
	# 填充样式：奶油绿，带右侧装饰边
	var sb_fg = StyleBoxFlat.new()
	sb_fg.bg_color = Color("#8fb9aa") 
	sb_fg.set_corner_radius_all(10)
	sb_fg.border_width_right = 3
	sb_fg.border_color = Color("#7aa899")
	bar.add_theme_stylebox_override("fill", sb_fg)
	
	# 文字标签优化
	if bar.has_node("ResignationLabel"):
		var label = bar.get_node("ResignationLabel")
		label.add_theme_color_override("font_color", Color("#4a4a4a"))
		label.add_theme_font_size_override("font_size", 18)
		label.text = "离职进度: %d / 10" % GameManager.current_level
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _create_button_style(color_hex: String, hover_hex: String) -> Dictionary:
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(color_hex)
	normal.set_corner_radius_all(15)
	normal.shadow_size = 4
	normal.shadow_offset = Vector2(0, 2)
	
	var hover = normal.duplicate()
	hover.bg_color = Color(hover_hex)
	hover.shadow_size = 6
	
	var pressed = normal.duplicate()
	pressed.bg_color = Color("#222222")
	pressed.shadow_size = 0
	
	return {"normal": normal, "hover": hover, "pressed": pressed}

func setup_event():
	var level = GameManager.current_level
	match level:
		3:
			setup_pantry()
		5:
			setup_training()
		7:
			setup_evolution(7)
		9:
			setup_desk_organizing()
		_:
			# 兜底
			GameManager.advance_level()

func setup_pantry():
	title_label.text = "【茶水间】"
	description_label.text = "忙里偷闲，喝杯咖啡还是摸个鱼？"
	add_option("喝杯咖啡 (压力清零)", func(): 
		GameManager.player_hp = GameManager.max_player_hp
		finish_event("神清气爽！压力全消。")
	)
	add_option("顺走一个 Emoji (获得随机卡)", func():
		var rewards = GameManager.get_random_reward_cards(1)
		if rewards.size() > 0:
			GameManager.player_deck.append(rewards[0])
			finish_event("你获得了一张强力 Emoji：【%s】！" % rewards[0].name)
		else:
			finish_event("茶水间空空如也...")
	)
	add_option("扔掉废话 (移除 1 张基础卡)", func():
		var removed = false
		for i in range(GameManager.player_deck.size()):
			if GameManager.player_deck[i].name in ["键盘输出", "摸鱼喝水"]:
				GameManager.player_deck.remove_at(i)
				removed = true
				break
		if removed:
			finish_event("你扔掉了一张废话卡，心情舒畅。")
		else:
			finish_event("你手里已经没有废话了。")
	)

func setup_training():
	title_label.text = "【技能培训】"
	description_label.text = "公司组织了摸鱼技能培训，你想提升哪方面？"
	add_option("提升摸鱼效率 (最大 AP +1)", func():
		GameManager.max_ap += 1
		finish_event("你的摸鱼效率提升了！当前最大 AP: %d" % GameManager.max_ap)
	)
	add_option("增强抗压能力 (最大 HP +20)", func():
		GameManager.max_player_hp += 20
		GameManager.player_hp += 20
		finish_event("你变得更能抗压了！当前最大 HP: %d" % GameManager.max_player_hp)
	)
	add_option("深造 Emoji (获得 2 张随机卡)", func():
		var rewards = GameManager.get_random_reward_cards(2)
		for r in rewards:
			GameManager.player_deck.append(r)
		finish_event("你学到了新的摸鱼技巧！")
	)

func setup_evolution(stage: int):
	if not GameManager.selected_hero:
		GameManager.advance_level()
		return
		
	var hero_name = GameManager.selected_hero.character_name
	if not GameManager.evolution_data.has(hero_name):
		finish_event("该角色暂无进化分支。")
		return
		
	var data = GameManager.evolution_data[hero_name]
	if not data.has(str(stage)):
		finish_event("当前阶段无进化。")
		return
		
	var options = data[str(stage)]
	
	if stage == 7:
		title_label.text = "【核心进化】"
		description_label.text = "团建的篝火旁，你的摸鱼神功即将大成！"
		
		var opt1 = options["A"]
		var opt2 = options["B"]
		
		add_option(opt1.name + ": " + opt1.description, func():
			GameManager.evolution_path = "A"
			GameManager.player_deck.append(opt1.card.duplicate())
			finish_event("核心进化！你选择了【" + opt1.name + "】，获得核心卡：【" + opt1.card.name + "】！")
		)
		add_option(opt2.name + ": " + opt2.description, func():
			GameManager.evolution_path = "B"
			GameManager.player_deck.append(opt2.card.duplicate())
			finish_event("核心进化！你选择了【" + opt2.name + "】，获得核心卡：【" + opt2.card.name + "】！")
		)

func setup_desk_organizing():
	title_label.text = "【整理工位】"
	description_label.text = "离职前的最后准备，把工位擦干净。"
	add_option("全状态回满", func():
		GameManager.player_hp = GameManager.max_player_hp
		finish_event("准备好迎接最终挑战了。")
	)
	add_option("精简卡组 (移除 2 张基础卡)", func():
		var removed_count = 0
		for i in range(GameManager.player_deck.size() - 1, -1, -1):
			var card = GameManager.player_deck[i]
			if card.name == "键盘输出" or card.name == "摸鱼喝水":
				GameManager.player_deck.remove_at(i)
				removed_count += 1
				if removed_count >= 2:
					break
		finish_event("你移除了 %d 张废话卡，卡组变得更精炼了。" % removed_count)
	)

func add_option(text: String, callback: Callable):
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(450, 90)
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# 应用奶油色调按钮样式
	var styles = _create_button_style("#fdf5e6", "#fffaf0") # 奶油白/米色
	btn.add_theme_stylebox_override("normal", styles.normal)
	btn.add_theme_stylebox_override("hover", styles.hover)
	btn.add_theme_stylebox_override("pressed", styles.pressed)
	btn.add_theme_color_override("font_color", Color("#4a4a4a"))
	btn.add_theme_color_override("font_hover_color", Color("#222222"))
	btn.add_theme_font_size_override("font_size", 24)
	
	btn.pressed.connect(func():
		# 立即禁用所有选项，防止重复触发
		for child in option_container.get_children():
			if child is Button:
				child.disabled = true
		
		# 点击反馈动画
		var t = create_tween()
		t.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.05)
		t.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.05)
		t.finished.connect(callback)
	)
	
	option_container.add_child(btn)
	
	# 选项进入动画
	btn.modulate.a = 0
	btn.position.x += 50
	var t = create_tween().set_parallel(true)
	t.tween_property(btn, "modulate:a", 1.0, 0.4).set_delay(option_container.get_child_count() * 0.1)
	t.tween_property(btn, "position:x", btn.position.x - 50, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(option_container.get_child_count() * 0.1)

func finish_event(msg: String):
	description_label.text = msg
	# 文字切换动画
	description_label.modulate.a = 0
	var lt = create_tween()
	lt.tween_property(description_label, "modulate:a", 1.0, 0.5)
	
	for child in option_container.get_children():
		child.queue_free()
		
	next_button.show()
	next_button.text = "继续离职之路"
	
	# NextButton 出现动画
	next_button.modulate.a = 0
	next_button.scale = Vector2(0.8, 0.8)
	next_button.pivot_offset = next_button.size / 2
	var bt = create_tween().set_parallel(true)
	bt.tween_property(next_button, "modulate:a", 1.0, 0.5)
	bt.tween_property(next_button, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	if not next_button.pressed.is_connected(_on_next_pressed):
		next_button.pressed.connect(_on_next_pressed)

func _on_next_pressed():
	if next_button.disabled: return
	next_button.disabled = true
	GameManager.advance_level()
