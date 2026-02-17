extends Control

@onready var title_label = %TitleLabel
@onready var description_label = %DescriptionLabel
@onready var option_container = %OptionContainer
@onready var next_button = %NextButton

func _ready():
	next_button.hide()
	_setup_ui_styles()
	_create_floating_decorations()
	_setup_deck_button()
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

func _setup_deck_button():
	var deck_btn = Button.new()
	deck_btn.text = " 🗃️ 查看牌库 "
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#fdf5e6")
	style.set_corner_radius_all(10)
	style.shadow_size = 2
	deck_btn.add_theme_stylebox_override("normal", style)
	deck_btn.add_theme_color_override("font_color", Color("#4a4a4a"))
	deck_btn.position = Vector2(20, 20)
	deck_btn.custom_minimum_size = Vector2(140, 40)
	add_child(deck_btn)
	deck_btn.pressed.connect(func(): GameManager.show_deck_viewer(self))

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
	if GameManager.pending_event_id != "":
		match GameManager.pending_event_id:
			"pantry":
				setup_pantry()
			"team_building":
				setup_evolution(7)
			"ultimate_evolution":
				setup_evolution(8)
			"desk_organizing":
				setup_desk_organizing()
			_:
				GameManager.finish_event_and_continue()
		return
	if GameManager.pending_random_event_id != "":
		setup_random_event(GameManager.pending_random_event_id)
		return
	
	# 兜底：如果没有事件标记，直接进入下一关
	GameManager.advance_level()

func setup_random_event(event_id: String):
	var info = GameManager.random_events.get(event_id, {})
	title_label.text = "【%s】" % info.get("title", "随机事件")
	description_label.text = info.get("desc", "一次临时事件出现了...")

	match event_id:
		"pantry_gossip":
			add_option("[听听看] 揭示下关敌人意图，初始 AP -1", func():
				var next_enemy = GameManager.enemies_data.get(GameManager.current_level + 1, {})
				var intent = next_enemy.get("intent", "未知意图")
				GameManager.next_battle_ap_bonus -= 1
				finish_event("你偷听到了：%s" % intent)
			)
			add_option("[走开] 回复 10 压力", func():
				GameManager.player_hp = min(GameManager.max_player_hp, GameManager.player_hp + 10)
				finish_event("你躲开了八卦，压力 -10。")
			)
		"ppt_help":
			add_option("[帮改PPT] 删掉 1 张强力卡，首张牌 0 费", func():
				_remove_strong_card(1)
				GameManager.first_card_free = true
				finish_event("你帮完PPT，获得了首张牌 0 费的被动。")
			)
			add_option("[拒绝] 压力 +5", func():
				GameManager.player_hp = max(0, GameManager.player_hp - 5)
				finish_event("你拒绝了求助，压力 +5。")
			)
		"emoji_misfire":
			add_option("[发表情包] 随机得 1 张高级卡，Boss 伤害 +2", func():
				_add_random_high_cost_card()
				GameManager.next_battle_enemy_damage_bonus += 2
				finish_event("你顺走了一张高级卡，但老板更凶了。")
			)
			add_option("[及时撤回] 无事发生", func():
				finish_event("你及时撤回，风平浪静。")
			)
		"elevator_boss":
			add_option("[大声问好] 下场初始 AP +1", func():
				GameManager.next_battle_ap_bonus += 1
				finish_event("老板对你印象不错，初始 AP +1。")
			)
			add_option("[低头快走] 压力 +15", func():
				GameManager.player_hp = max(0, GameManager.player_hp - 15)
				finish_event("你低头快走，压力 +15。")
			)
		"printer_jam":
			add_option("[踢一脚] 首回合爆炸伤害，随机丢 1 张手牌", func():
				GameManager.start_battle_burst_damage = 25
				GameManager.start_battle_discard_random_hand = true
				finish_event("你踢了一脚，首回合爆炸伤害将触发。")
			)
			add_option("[清理] 升级 1 张基础卡", func():
				_upgrade_random_basic_card(1)
				finish_event("你清理完毕，基础卡获得强化。")
			)
		"ac_break":
			add_option("[忍受] 每回合压力 +2", func():
				GameManager.hp_drain_per_turn += 2
				finish_event("空调坏了，你每回合压力 +2。")
			)
			add_option("[蹭空调] 获得 1 张闪避卡", func():
				_add_evade_card()
				finish_event("你蹭到了清凉，获得一张闪避卡。")
			)
		"mystery_parcel":
			add_option("[拆开] 50% 免控耳机 / 50% 塞 2 张垃圾卡", func():
				if randf() < 0.5:
					_add_invincible_card()
					finish_event("你拆到了免控耳机，获得无敌卡！")
				else:
					_add_junk_cards(2)
					finish_event("你拆到了垃圾，卡组被污染了。")
			)
			add_option("[退回] 压力 -5", func():
				GameManager.player_hp = min(GameManager.max_player_hp, GameManager.player_hp + 5)
				finish_event("你退回快递，压力 -5。")
			)
		"elevator_encounter":
			add_option("[挤进去] 压力 +10", func():
				GameManager.player_hp = max(0, GameManager.player_hp - 10)
				finish_event("拥挤的电梯让你压力 +10。")
			)
			add_option("[等下一趟] 获得 1 张 ⏳ 连招卡", func():
				_add_wait_card()
				finish_event("你等待下一趟，获得一张 ⏳ 连招卡。")
			)
		"power_outage":
			add_option("[直接下班] 立即胜利，无奖励", func():
				GameManager.skip_next_battle = true
				GameManager.skip_rewards_battles = max(1, GameManager.skip_rewards_battles + 1)
				finish_event("停电下班！下一场战斗直接跳过。")
			)
			add_option("[开备用电源] 压力 +20，下场伤害翻倍", func():
				GameManager.player_hp = max(0, GameManager.player_hp - 20)
				GameManager.next_battle_damage_multiplier = 2.0
				finish_event("你开了电源，下场伤害翻倍。")
			)
		"blue_screen":
			add_option("[心态崩了] 压力 +30，获 1 张 0 费神卡", func():
				GameManager.player_hp = max(0, GameManager.player_hp - 30)
				_add_random_card_cost_zero()
				finish_event("你心态崩了，获得一张 0 费神卡。")
			)
			add_option("[重启] 删 1 张牌", func():
				_remove_random_card(1)
				finish_event("你重启了系统，删掉一张牌。")
			)
		"old_notes":
			add_option("[学习] 获 1 个随机 Combo 配方", func():
				finish_event("你学会了一个新的连招配方。")
			)
			add_option("[丢弃] 压力上限 +5", func():
				GameManager.max_player_hp += 5
				GameManager.player_hp += 5
				finish_event("你抛下过去，压力上限 +5。")
			)
		"checkup":
			add_option("[不看] 压力 -10", func():
				GameManager.player_hp = min(GameManager.max_player_hp, GameManager.player_hp + 10)
				finish_event("你选择不看，压力 -10。")
			)
			add_option("[看细节] 压力 +20，本局回血翻倍", func():
				GameManager.player_hp = max(0, GameManager.player_hp - 20)
				GameManager.heal_multiplier = 2.0
				finish_event("你认真阅读，回血翻倍。")
			)
		"bathroom_break":
			add_option("[刷视频] 压力回复 50", func():
				GameManager.player_hp = min(GameManager.max_player_hp, GameManager.player_hp + 50)
				finish_event("你摸鱼成功，压力回复 50。")
			)
			add_option("[抽烟] 攻击 +5，但每回合扣 1 AP", func():
				GameManager.attack_bonus_flat += 5
				GameManager.ap_drain_per_turn += 1
				finish_event("你抽了根烟，攻击 +5，但每回合扣 1 AP。")
			)
		"caught_slacking":
			add_option("[推卸给AI] 随机 2 张卡变随机 Emoji", func():
				_randomize_cards(2)
				finish_event("你把锅甩给AI，卡组被重写了两张。")
			)
			add_option("[老实认错] 移除 1 张强力卡", func():
				_remove_strong_card(1)
				finish_event("你认错了，强力卡被没收。")
			)
		"side_job":
			add_option("[接单] 下 2 场无卡牌奖励，压力上限 +20", func():
				GameManager.skip_rewards_battles = max(GameManager.skip_rewards_battles, 2)
				GameManager.max_player_hp += 20
				GameManager.player_hp += 20
				finish_event("你接了私活，压力上限 +20。")
			)
			add_option("[拒绝] 升级 2 张卡", func():
				_upgrade_random_card(2)
				finish_event("你拒绝私活，专注强化卡组。")
			)
		"trash_treasure":
			add_option("[翻找] 获得 📊 数据卡", func():
				_add_data_card()
				finish_event("你找到了 📊 数据卡。")
			)
			add_option("[不看] 无事发生", func():
				finish_event("你选择无视垃圾桶。")
			)
		"mass_test":
			add_option("[排队] 获得 1 回合无敌卡", func():
				_add_invincible_card()
				finish_event("你乖乖排队，获得无敌卡。")
			)
			add_option("[插队] 压力 +20", func():
				GameManager.player_hp = max(0, GameManager.player_hp - 20)
				finish_event("你插队成功，但压力 +20。")
			)
		"broken_chair":
			add_option("[站着办公] 攻击 +3", func():
				GameManager.attack_bonus_flat += 3
				finish_event("你站着办公，攻击 +3。")
			)
			add_option("[修椅子] 压力 +10", func():
				GameManager.player_hp = max(0, GameManager.player_hp - 10)
				finish_event("你修好了椅子，压力 +10。")
			)
		"likes":
			add_option("[互赞] 随机 1 张卡伤害 +5", func():
				_upgrade_random_card_damage()
				finish_event("你互赞了一轮，一张卡伤害 +5。")
			)
			add_option("[忽略] 无事发生", func():
				finish_event("你选择无视点赞。")
			)
		"boss_promise":
			add_option("[吃饼] 获得 20 护盾卡，牌组塞 1 张垃圾卡", func():
				_add_shield_card()
				_add_junk_cards(1)
				finish_event("你吃下了画饼，获得护盾卡但被塞垃圾卡。")
			)
			add_option("[不吃] 压力 +5", func():
				GameManager.player_hp = max(0, GameManager.player_hp - 5)
				finish_event("你拒绝画饼，压力 +5。")
			)
		_:
			finish_event("你度过了一个平静的随机事件。")

func setup_pantry():
	title_label.text = "【茶水间】"
	description_label.text = "这里是公司里唯一的‘避难所’，咖啡机的轰鸣声掩盖了不远处办公室的喧闹。空气中弥漫着廉价咖啡豆和隔壁同事午餐便当的味道。在这个短暂的空档里，你打算怎么做？"
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
	add_option("扔掉废话 (手动删卡)", func():
		GameManager.show_deck_viewer(self, true, func():
			finish_event("你扔掉了一张不需要的卡牌，心情舒畅。")
		)
	)

func setup_training():
	title_label.text = "【技能培训】"
	description_label.text = "HR 正在台上满怀激情地讲解着公司文化和职业规划，但台下的你只关心如何在这场漫长的会议中神不知鬼不觉地提升自己的‘生存技巧’。这是一次难得的学习机会——针对摸鱼而言。"
	add_option("带薪补觉 (回复 40% 压力)", func():
		var heal = int(GameManager.max_player_hp * 0.4)
		GameManager.player_hp = min(GameManager.max_player_hp, GameManager.player_hp + heal)
		finish_event("你在培训课上偷偷补了个觉，压力大幅缓解。")
	)
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
		GameManager.finish_event_and_continue()
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
		description_label.text = "在团建的深夜篝火旁，跳动的火焰倒映在你的瞳孔中。你突然领悟到，职场不仅仅是忍受，更是一种艺术。你体内的摸鱼能量开始剧烈波动，你的核心 Emoji 似乎要突破某种枷锁，迎来质的飞跃..."
		
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
		return

	if stage == 8:
		title_label.text = "【终极进化】"
		description_label.text = "强敌已倒下，你站在精英 BOSS 的残骸上。四周的空气仿佛因为你的觉醒而震颤，你终于触碰到了职场生存的终极真理。这一刻，你的核心 Emoji 将彻底蜕变，展现出足以震撼全宇宙的降维打击力量！"
		var opt = options["A"]
		add_option(opt.name + ": " + opt.description, func():
			GameManager.player_deck.append(opt.card.duplicate())
			finish_event("终极进化完成！你获得终极卡：【" + opt.card.name + "】！")
		)

func setup_desk_organizing():
	title_label.text = "【整理工位】"
	description_label.text = "离职流程已经走到了最后一步。你看着桌上堆积的旧便签、空咖啡杯和那盆快要枯萎的仙人掌，心中百感交集。在收拾东西离开这个格子间之前，你还有最后一次调整状态的机会。"
	add_option("全状态回满", func():
		GameManager.player_hp = GameManager.max_player_hp
		finish_event("准备好迎接最终挑战了。")
	)
	add_option("精简卡组 (手动删卡)", func():
		GameManager.show_deck_viewer(self, true, func():
			finish_event("你扔掉了一张不需要的卡牌，卡组变得更精炼了。")
		)
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

func _remove_random_card(count: int):
	for i in range(count):
		if GameManager.player_deck.is_empty():
			return
		var idx = randi() % GameManager.player_deck.size()
		GameManager.player_deck.remove_at(idx)

func _remove_strong_card(count: int):
	for i in range(count):
		var candidates = GameManager.player_deck.filter(func(c): return c.get("cost", 0) >= 2 and not str(c.get("type", "")).begins_with("junk"))
		if candidates.size() == 0:
			candidates = GameManager.player_deck.filter(func(c): return not str(c.get("type", "")).begins_with("junk"))
		if candidates.size() == 0:
			return
		var target = candidates[randi() % candidates.size()]
		GameManager.player_deck.erase(target)

func _upgrade_random_card(count: int):
	for i in range(count):
		if GameManager.player_deck.is_empty():
			return
		var idx = randi() % GameManager.player_deck.size()
		_upgrade_card(GameManager.player_deck[idx])

func _upgrade_random_basic_card(count: int):
	var basics = ["键盘输出", "摸鱼喝水", "小丑自嘲", "午后咖啡", "带薪拉屎", "工位补觉", "老板画饼", "极限跃动"]
	for i in range(count):
		var candidates = GameManager.player_deck.filter(func(c): return c.get("name", "") in basics)
		if candidates.size() == 0:
			return
		var target = candidates[randi() % candidates.size()]
		_upgrade_card(target)

func _upgrade_random_card_damage():
	var candidates = GameManager.player_deck.filter(func(c): return c.has("value") and c.get("type", "").begins_with("attack"))
	if candidates.size() == 0:
		return
	var target = candidates[randi() % candidates.size()]
	if target.has("value"):
		target["value"] = int(target["value"]) + 5
		target["description"] = "%s (强化)" % target.get("description", "")

func _upgrade_card(card: Dictionary):
	if card.has("value"):
		card["value"] = int(card["value"]) + 5
	if card.has("cost"):
		card["cost"] = max(0, int(card["cost"]) - 1)
	card["description"] = "%s (强化)" % card.get("description", "")

func _add_random_high_cost_card():
	var pool = GameManager.universal_cards.duplicate()
	if GameManager.selected_hero:
		pool.append_array(GameManager.selected_hero.card_pool)
	var candidates = pool.filter(func(c): return c.get("cost", 0) >= 2)
	if candidates.size() == 0:
		candidates = pool
	var card = candidates[randi() % candidates.size()].duplicate()
	GameManager.player_deck.append(card)

func _add_random_card_cost_zero():
	var pool = GameManager.get_random_reward_cards(1)
	if pool.size() == 0:
		return
	var card = pool[0].duplicate()
	card["cost"] = 0
	card["description"] = "%s (0费)" % card.get("description", "")
	GameManager.player_deck.append(card)

func _add_evade_card():
	for card in GameManager.universal_cards:
		if card.get("emoji", "") == "🏃" or card.get("type", "") == "evasion_draw":
			GameManager.player_deck.append(card.duplicate())
			return
	_add_invincible_card()

func _add_wait_card():
	var card = {
		"name": "待岗警告",
		"emoji": "⏳",
		"cost": 1,
		"type": "wait_defense",
		"value": 20,
		"description": "下回合不行动，获得 20 点防御"
	}
	GameManager.player_deck.append(card)

func _add_data_card():
	var card = {
		"name": "数据卡",
		"emoji": "📊",
		"cost": 1,
		"type": "record_data",
		"value": 1,
		"description": "记录上一张牌伤害的数值"
	}
	GameManager.player_deck.append(card)

func _add_invincible_card():
	var card = {
		"name": "免控耳机",
		"emoji": "🎧",
		"cost": 1,
		"type": "buff_evasion",
		"value": 0,
		"description": "本回合无敌"
	}
	GameManager.player_deck.append(card)

func _add_shield_card():
	var card = {
		"name": "画饼护盾",
		"emoji": "🥯",
		"cost": 1,
		"type": "shield",
		"value": 20,
		"description": "获得 20 点护盾"
	}
	GameManager.player_deck.append(card)

func _add_junk_cards(count: int):
	for i in range(count):
		GameManager.player_deck.append(GameManager.junk_cards["meeting"].duplicate())

func _randomize_cards(count: int):
	for i in range(count):
		if GameManager.player_deck.is_empty():
			return
		var idx = randi() % GameManager.player_deck.size()
		var card = GameManager.universal_cards[randi() % GameManager.universal_cards.size()].duplicate()
		GameManager.player_deck[idx] = card

func _on_next_pressed():
	if next_button.disabled: return
	next_button.disabled = true
	GameManager.finish_event_and_continue()
