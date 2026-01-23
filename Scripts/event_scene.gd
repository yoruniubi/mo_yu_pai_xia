extends Control

@onready var title_label = %TitleLabel
@onready var description_label = %DescriptionLabel
@onready var option_container = %OptionContainer
@onready var next_button = %NextButton

func _ready():
	next_button.hide()
	if has_node("%ResignationBar"):
		%ResignationBar.value = GameManager.current_level
	setup_event()

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
	btn.custom_minimum_size = Vector2(400, 80)
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.pressed.connect(callback)
	option_container.add_child(btn)

func finish_event(msg: String):
	description_label.text = msg
	for child in option_container.get_children():
		child.queue_free()
	next_button.show()
	next_button.text = "继续离职之路"
	if not next_button.pressed.is_connected(_on_next_pressed):
		next_button.pressed.connect(_on_next_pressed)

func _on_next_pressed():
	GameManager.advance_level()
