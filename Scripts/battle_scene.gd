extends Control

# --- 节点引用 ---
@onready var hero_sprite = %HeroSprite
@onready var hero_name_label = %HeroName
@onready var hero_hp_bar = %HeroHPBar
@onready var enemy_name_label = %EnemyName
@onready var enemy_hp_bar = %EnemyHPBar
@onready var intent_label = %IntentLabel
@onready var energy_label = %EnergyLabel
@onready var hand_container = %HandContainer
@onready var end_turn_button = %EndTurnButton
@onready var go_to_boss_button = %GoToBossButton
@onready var victory_layer = %VictoryLayer
@onready var next_level_button = %NextLevelButton
@onready var level_clear_label = %LevelClearLabel
@onready var game_over_layer = %GameOverLayer
@onready var restart_button = %RestartButton
@onready var status_container = %StatusContainer

# --- 配置参数 ---
var card_scene = preload("res://Scenes/battle_card.tscn")
var floating_number_scene = preload("res://Scenes/floating_number.tscn")
var hand_cards = []
var current_sequence = []
var last_player_card_data = {} # 记录玩家最后出的牌，供鹦鹉复制
var draw_pile = []
var discard_pile = []

# 战斗数值
var hero_hp = 100
var enemy_hp = 100
var current_ap = 3

# 特殊状态变量
var enemy_fire_stacks = 0
var last_damage_dealt = 0
var recorded_data_value = 0
var poop_played_this_turn = false
var is_evading = false
var is_waiting_next_turn = false
var has_reflect_shield = false
var false_hope_stacks = 0
var keyboard_buff_active = false
var enemy_atk_reduction = 0
var enemy_vulnerability = 0 # 敌人受到的额外伤害
var skip_enemy_turn = false
var next_turn_extra_draws = 0

# 当前激活的连招池
var active_combos = {}

# 扇形布局参数
const FAN_RADIUS = 800.0      # 扇形圆心距离
const MAX_FAN_ANGLE = 30.0    # 最大展开角度（度）

func _ready():
	# 1. 播放战斗音乐
	var battle_bgm = preload("res://Assets/Music/Cubicle_Cruise.mp3")
	BgmManager.play_music(battle_bgm)
	
	# 2. 初始化连招池
	_initialize_combos()
	
	# 3. 初始化英雄数据
	if GameManager.selected_hero:
		var hero = GameManager.selected_hero
		hero_sprite.texture = hero.character_image
		hero_name_label.text = hero.character_name
	
	# 3. 初始化玩家 HP
	hero_hp = GameManager.player_hp
	hero_hp_bar.max_value = GameManager.max_player_hp
	hero_hp_bar.value = hero_hp
	
	# 4. 初始化敌人数据
	var enemy = GameManager.get_current_enemy()
	enemy_name_label.text = enemy.name
	enemy_hp = enemy.hp
	enemy_hp_bar.max_value = enemy.hp
	enemy_hp_bar.value = enemy_hp
	intent_label.text = enemy.intent
	%BossSprite.texture = load(enemy.image)
	
	# 初始 AP
	current_ap = GameManager.max_ap
	
	# 5. 初始化数值 UI
	update_ui_values()
	
	# 5. 按钮样式与绑定
	setup_button_style()
	
	# 6. 初始化战斗牌堆
	draw_pile = GameManager.player_deck.duplicate()
	draw_pile.shuffle()
	
	# 7. 初始抽牌
	for i in range(5):
		draw_card()

func update_ui_values():
	hero_hp_bar.value = hero_hp
	enemy_hp_bar.value = enemy_hp
	energy_label.text = "摸鱼力: %d/%d" % [current_ap, GameManager.max_ap]
	
	# 如果当前 AP 超过上限（临时 AP），改变颜色提醒
	if current_ap > GameManager.max_ap:
		energy_label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		energy_label.remove_theme_color_override("font_color")
		
	# 更新离职进度条
	if has_node("%ResignationBar"):
		%ResignationBar.value = GameManager.current_level
	# 同步到全局
	GameManager.player_hp = hero_hp

func setup_button_style():
	var btn = end_turn_button
	var style_normal = _create_style("#4a4a4a", 10, 4)
	var style_hover = _create_style("#666666", 10, 6)
	var style_pressed = _create_style("#222222", 10, 0)
	
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	btn.add_theme_color_override("font_color", Color.WHITE)
	
	btn.pressed.connect(_on_end_turn_pressed)
	go_to_boss_button.pressed.connect(_on_go_to_boss_pressed)
	next_level_button.pressed.connect(_on_next_level_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	if has_node("%ComboDirectoryButton"):
		%ComboDirectoryButton.pressed.connect(show_combo_directory)

func _on_restart_pressed():
	GameManager.player_hp = GameManager.max_player_hp
	GameManager.current_level = 1
	GameManager.load_current_level_scene()

func _on_next_level_pressed():
	GameManager.advance_level()

func _on_go_to_boss_pressed():
	get_tree().change_scene_to_file("res://Scenes/boss_stage.tscn")

func _create_style(color_hex: String, radius: int, shadow: int) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(color_hex)
	sb.set_corner_radius_all(radius)
	sb.shadow_size = shadow
	sb.shadow_offset = Vector2(0, shadow / 2.0)
	return sb

func _on_end_turn_pressed():
	end_turn_button.disabled = true
	if skip_enemy_turn:
		skip_enemy_turn = false
		print("连招效果：跳过老板回合")
		
		var skip_label = Label.new()
		skip_label.text = "老板被你气跑了！(跳过回合)"
		skip_label.add_theme_font_size_override("font_size", 32)
		skip_label.add_theme_color_override("font_color", Color.CYAN)
		skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		skip_label.custom_minimum_size = Vector2(800, 50)
		skip_label.position = Vector2(50, 300)
		add_child(skip_label)
		
		var st = create_tween()
		st.tween_property(skip_label, "modulate:a", 0, 1.5)
		st.finished.connect(skip_label.queue_free)
		
		await get_tree().create_timer(1.0).timeout
		start_player_turn()
	else:
		enemy_turn()

func enemy_turn():
	if has_meta("skip_next_intent"):
		remove_meta("skip_next_intent")
		intent_label.text = "意图：继续发呆..."
		await get_tree().create_timer(1.0).timeout
		start_player_turn()
		return

	var enemy_name = enemy_name_label.text
	
	# 检查手牌中的“无意义早会”
	for card in hand_cards:
		if card.card_data.get("type") == "junk_meeting":
			var penalty = card.card_data.get("value", 2)
			print("由于未打出早会卡，受到 %d 点伤害" % penalty)
			apply_damage_to_hero(penalty)
	
	if %BossSprite.has_method("play_attack"):
		%BossSprite.play_attack()
	
	await get_tree().create_timer(0.5).timeout
	
	# 根据敌人类型执行不同行为
	if "鹦鹉" in enemy_name:
		if not last_player_card_data.is_empty():
			var type = last_player_card_data.get("type", "")
			var val = last_player_card_data.get("value", 5)
			print("鹦鹉复制了你的行为！")
			if type == "attack" or type == "attack_draw" or type == "attack_fire" or type == "attack_seed":
				apply_damage_to_hero(val)
			elif type == "defense" or type == "defense_ink":
				apply_damage_to_enemy(-val) # 相当于回血
			else:
				apply_damage_to_hero(10)
		else:
			apply_damage_to_hero(10)
	elif "刺猬" in enemy_name:
		print("刺猬发动连击！")
		for i in range(3):
			apply_damage_to_hero(6)
			await get_tree().create_timer(0.2).timeout
	elif "树懒" in enemy_name:
		apply_damage_to_hero(12)
		print("树懒塞入了垃圾卡...")
		inject_junk_card("meeting")
	elif "监控猿" in enemy_name:
		apply_damage_to_hero(15)
		# 锁定逻辑简化：随机弃掉一张手牌
		if hand_cards.size() > 0:
			var idx = randi() % hand_cards.size()
			var c = hand_cards[idx]
			hand_cards.remove_at(idx)
			c.queue_free()
			print("监控猿锁定了你的一张牌！")
	elif "蜘蛛" in enemy_name:
		print("画饼蜘蛛发动了【虚假目标】！")
		apply_damage_to_hero(18)
		inject_junk_card("goal")
	else:
		var damage = 10 + (GameManager.current_level * 2)
		# 应用攻击削减
		damage = max(0, damage - enemy_atk_reduction)
		enemy_atk_reduction = 0 # 重置
		apply_damage_to_hero(damage)
	
	if hero_hp <= 0:
		show_game_over()
		return
		
	start_player_turn()

func inject_junk_card(type: String):
	var junk_data = GameManager.junk_cards.get(type)
	if not junk_data: return
	
	var new_card = card_scene.instantiate()
	new_card.card_data = junk_data.duplicate()
	hand_container.add_child(new_card)
	new_card.scale = Vector2(0.75, 0.75)
	new_card.pivot_offset = Vector2(110, 340) 
	hand_cards.append(new_card)
	update_hand_layout()

func show_game_over():
	end_turn_button.disabled = true
	game_over_layer.visible = true

func start_player_turn():
	end_turn_button.disabled = false
	current_ap = GameManager.max_ap
	poop_played_this_turn = false
	
	# 处理多回合状态
	if has_meta("evasion_turns"):
		var t = get_meta("evasion_turns") - 1
		if t <= 0:
			is_evading = false
			remove_meta("evasion_turns")
		else:
			set_meta("evasion_turns", t)
			is_evading = true # 保持开启
	else:
		is_evading = false
		
	keyboard_buff_active = false
	has_reflect_shield = false
	
	current_sequence.clear()
	update_emoji_slots()
	enemy_vulnerability = 0 # 重置敌人易伤状态
	
	if is_waiting_next_turn:
		is_waiting_next_turn = false
		print("本回合待岗结束，保留手牌继续行动")
	else:
		# 检查手牌中的“虚假目标”
		var draw_count = 5 + next_turn_extra_draws
		next_turn_extra_draws = 0
		
		for card in hand_cards:
			if card.card_data.get("type") == "junk_goal":
				print("由于未打出虚假目标，本回合抽牌减少")
				draw_count -= 1
			# 回合结束手牌进弃牌堆
			if not card.card_data.get("type", "").begins_with("junk"):
				discard_pile.append(card.card_data)
		
		for card in hand_cards:
			card.queue_free()
		hand_cards.clear()
		
		for i in range(draw_count):
			draw_card()
	
	update_ui_values()
	update_status_display()

func apply_damage_to_hero(amount: int):
	var final_damage = amount
	if %AnimationManager:
		%AnimationManager.play_player_hit_anim()
	
	if is_evading:
		final_damage /= 2
	
	if has_reflect_shield:
		var multiplier = get_meta("reflect_multiplier") if has_meta("reflect_multiplier") else 1
		apply_damage_to_enemy(final_damage * multiplier)
		final_damage = 0
		has_reflect_shield = false
		if has_meta("reflect_multiplier"): remove_meta("reflect_multiplier")
	
	if final_damage >= hero_hp and false_hope_stacks > 0:
		false_hope_stacks -= 1
		final_damage = 0
	
	hero_hp -= final_damage
	hero_hp = max(0, hero_hp)
	
	spawn_floating_number(final_damage, false, hero_sprite.global_position + Vector2(0, -50))
	
	var t = create_tween()
	t.tween_property(hero_sprite, "modulate", Color.RED, 0.1)
	t.tween_property(hero_sprite, "modulate", Color.WHITE, 0.1)
	
	update_ui_values()
	update_status_display()

func draw_card(specific_data: Dictionary = {}):
	var new_card = card_scene.instantiate()
	
	if specific_data.is_empty():
		if draw_pile.size() == 0:
			if discard_pile.size() == 0:
				print("没牌抽了！")
				return null
			draw_pile = discard_pile.duplicate()
			discard_pile.clear()
			draw_pile.shuffle()
			print("洗牌！")
		
		new_card.card_data = draw_pile.pop_back()
	else:
		new_card.card_data = specific_data.duplicate()
	
	hand_container.add_child(new_card)
	new_card.scale = Vector2(0.75, 0.75)
	new_card.pivot_offset = Vector2(110, 340) 
	
	hand_cards.append(new_card)
	update_hand_layout()
	update_hand_combo_hints()
	return new_card

func update_hand_layout():
	var card_count = hand_cards.size()
	if card_count == 0: return
	var center_x = hand_container.size.x / 2.0
	var base_y = hand_container.size.y - 110.0
	var total_angle = min(MAX_FAN_ANGLE, card_count * 10.0)
	var angle_step = 0.0
	if card_count > 1:
		angle_step = total_angle / (card_count - 1)
	var start_angle = -total_angle / 2.0
	
	for i in range(card_count):
		var card = hand_cards[i]
		var angle_deg = start_angle + (i * angle_step)
		var angle_rad = deg_to_rad(angle_deg)
		var target_x = center_x + FAN_RADIUS * sin(angle_rad)
		var target_y = base_y - (FAN_RADIUS * cos(angle_rad) - FAN_RADIUS)
		var tween = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		var scaled_width = card.size.x * card.scale.x
		var scaled_height = card.size.y * card.scale.y
		var final_pos = Vector2(target_x - scaled_width / 2.0, target_y - scaled_height)
		tween.tween_property(card, "position", final_pos, 0.3)
		tween.tween_property(card, "rotation_degrees", angle_deg, 0.3)
		card.z_index = i

func _is_emoji_part_of_any_combo(emoji: String) -> bool:
	for combo in active_combos.values():
		if emoji in combo.parts:
			return true
	return false

func _initialize_combos():
	active_combos = GameManager.universal_combos.duplicate(true)
	if GameManager.selected_hero:
		var hero_name = GameManager.selected_hero.character_name
		if GameManager.character_combos.has(hero_name):
			var char_combos = GameManager.character_combos[hero_name]
			for key in char_combos:
				active_combos[key] = char_combos[key]

func _on_card_played(card_node):
	var data = card_node.card_data
	var cost = data.get("cost", 1)
	
	# KPI 考核影响：手牌中有 KPI 卡时，Combo 卡消耗 +1
	var has_kpi = false
	for c in hand_cards:
		if c.card_data.get("type") == "junk_kpi":
			has_kpi = true
			break
	
	var emoji = data.get("emoji", "")
	if has_kpi and emoji != "" and _is_emoji_part_of_any_combo(emoji):
		cost += 1
	
	if current_ap < cost:
		var t = create_tween()
		t.tween_property(card_node, "position:x", card_node.position.x + 10, 0.05)
		t.tween_property(card_node, "position:x", card_node.position.x - 10, 0.05)
		t.tween_property(card_node, "position:x", card_node.position.x, 0.05)
		return
	
	current_ap -= cost
	if %AnimationManager.has_method("play_player_attack_anim"):
		var content = emoji
		if content == "" and data.has("image"):
			content = data.image
		%AnimationManager.play_player_attack_anim(content)
	
	execute_card_effect(data)
	last_player_card_data = data
	
	# 垃圾卡不进弃牌堆，直接消失（或者根据需求定，这里简单处理为不进弃牌堆）
	if not data.get("type", "").begins_with("junk"):
		discard_pile.append(data)
	
	if emoji != "":
		current_sequence.append(emoji)
		update_emoji_slots()
		check_combos()
	
	hand_cards.erase(card_node)
	card_node.queue_free()
	
	update_ui_values()
	update_hand_layout()
	update_hand_combo_hints()
	update_status_display()

func update_hand_combo_hints():
	# 统计当前序列中的 Emoji
	var seq_counts = {}
	for e in current_sequence:
		seq_counts[e] = seq_counts.get(e, 0) + 1
	
	# 统计手牌中的 Emoji
	var hand_emoji_counts = {}
	for card in hand_cards:
		var e = card.card_data.get("emoji", "")
		if e != "":
			hand_emoji_counts[e] = hand_emoji_counts.get(e, 0) + 1
	
	for card in hand_cards:
		var e = card.card_data.get("emoji", "")
		var can_complete_combo = false
		
		if e != "":
			for combo_id in active_combos:
				var combo = active_combos[combo_id]
				if e in combo.parts:
					# 统计该连招需要的各 Emoji 数量
					var req_counts = {}
					for p in combo.parts:
						req_counts[p] = req_counts.get(p, 0) + 1
					
					# 检查 (当前序列 + 手牌) 是否能凑齐该连招
					var possible = true
					for p in req_counts:
						var count_in_seq = seq_counts.get(p, 0)
						var count_in_hand = hand_emoji_counts.get(p, 0)
						if count_in_seq + count_in_hand < req_counts[p]:
							possible = false
							break
					
					if possible:
						# 进一步检查：这张卡是否对凑齐连招有贡献？
						var is_needed_for_seq = seq_counts.get(e, 0) < req_counts.get(e, 0)
						
						var can_form_from_hand = true
						for p in req_counts:
							if hand_emoji_counts.get(p, 0) < req_counts[p]:
								can_form_from_hand = false
								break
						
						if is_needed_for_seq or can_form_from_hand:
							can_complete_combo = true
							break
							
		card.set_highlight(can_complete_combo)

func update_status_display():
	for child in status_container.get_children():
		child.queue_free()
	
	if is_evading:
		_add_status_label("💨 闪避", Color.CYAN)
	if keyboard_buff_active:
		_add_status_label("⌨️ 键盘侠", Color.ORANGE)
	if has_reflect_shield:
		_add_status_label("🛡️ 反伤", Color.PURPLE)
	if false_hope_stacks > 0:
		_add_status_label("🍞 希望 x%d" % false_hope_stacks, Color.YELLOW)
	if enemy_fire_stacks > 0:
		_add_status_label("🔥 敌火 x%d" % enemy_fire_stacks, Color.RED)

func _add_status_label(text: String, color: Color):
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", color)
	status_container.add_child(label)

func update_emoji_slots():
	for child in %EmojiSlot.get_children():
		child.queue_free()
	for emoji in current_sequence:
		var label = Label.new()
		label.text = emoji
		label.add_theme_font_size_override("font_size", 32)
		%EmojiSlot.add_child(label)

func check_combos():
	# 统计当前序列中的 Emoji 数量
	var seq_counts = {}
	for e in current_sequence:
		seq_counts[e] = seq_counts.get(e, 0) + 1
	
	for recipe_key in active_combos:
		var combo = active_combos[recipe_key]
		var req_counts = {}
		for p in combo.parts:
			req_counts[p] = req_counts.get(p, 0) + 1
		
		# 检查序列是否包含所有必需的 Emoji
		var match_found = true
		for p in req_counts:
			if seq_counts.get(p, 0) < req_counts[p]:
				match_found = false
				break
		
		if match_found:
			trigger_combo(combo)
			current_sequence.clear()
			get_tree().create_timer(0.5).timeout.connect(update_emoji_slots)
			break

func trigger_combo(combo_data):
	print("！！！触发连招：", combo_data.name, " -> ", combo_data.effect)
	
	# --- 视觉特效 ---
	# 1. 屏幕闪烁
	if %AnimationManager.has_method("play_combo_flash"):
		%AnimationManager.play_combo_flash()
	
	# 2. 震屏
	if %AnimationManager.has_method("shake_screen"):
		%AnimationManager.shake_screen(20.0, 0.4)
	
	# 3. 弹出大文字提示
	var combo_label = Label.new()
	combo_label.text = "★ %s ★" % combo_data.name
	combo_label.add_theme_font_size_override("font_size", 60)
	combo_label.add_theme_color_override("font_color", Color.YELLOW)
	combo_label.add_theme_color_override("font_outline_color", Color.BLACK)
	combo_label.add_theme_constant_override("outline_size", 10)
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	combo_label.custom_minimum_size = Vector2(800, 100)
	combo_label.position = Vector2(50, 400) # 屏幕中心上方
	add_child(combo_label)
	
	var lt = create_tween().set_parallel(true)
	lt.tween_property(combo_label, "position:y", 300, 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	lt.tween_property(combo_label, "modulate:a", 0, 1.2).set_delay(0.5)
	lt.finished.connect(combo_label.queue_free)
	
	# 执行连招效果
	match combo_data.logic:
		"clown_self":
			var lost_hp = 100 - hero_hp
			apply_damage_to_enemy(int(lost_hp * 0.5))
		"ultimate_slack":
			hero_hp = 100
			skip_enemy_turn = true
			_on_end_turn_pressed()
		"angry_keyboard":
			keyboard_buff_active = true
		"nuclear_bomb":
			apply_damage_to_enemy(30)
			enemy_fire_stacks *= 3
		"muddy_water":
			apply_heal_to_hero(15)
			for i in range(2): draw_card()
		"ink_escape":
			is_evading = true
			var to_remove = []
			for c in hand_cards:
				if c.card_data.get("type", "").begins_with("junk"):
					to_remove.append(c)
			for c in to_remove:
				hand_cards.erase(c)
				c.queue_free()
			update_hand_layout()
		"big_bread":
			false_hope_stacks += 3
		"loop_report":
			if not last_player_card_data.is_empty():
				execute_card_effect(last_player_card_data)
		"red_tape":
			intent_label.text = "意图：流程审批中 (发呆)"
			skip_enemy_turn = true
		"paid_leave":
			apply_heal_to_hero(20)
			is_waiting_next_turn = false
			next_turn_extra_draws += 2
			print("带薪休假：取消待岗状态，下回合额外抽 2 张牌")

func show_combo_directory():
	var combo_text = "--- 摸鱼连招秘籍 ---\n\n"
	for recipe in active_combos:
		var data = active_combos[recipe]
		combo_text += "【%s】 %s\n   └─ %s\n\n" % [recipe, data.name, data.effect]
	
	var dialog = AcceptDialog.new()
	dialog.title = "连招一览"
	dialog.dialog_text = combo_text
	add_child(dialog)
	dialog.popup_centered()

func execute_card_effect(data: Dictionary):
	var type = data.get("type", "")
	var value = data.get("value", 0)
	var emoji = data.get("emoji", "")
	match type:
		"attack":
			var dmg = value
			if emoji == "⌨️" and keyboard_buff_active:
				dmg *= 3
			apply_damage_to_enemy(dmg)
		"defense":
			apply_heal_to_hero(value)
		"attack_draw":
			apply_damage_to_enemy(value)
			draw_card()
		"buff_ap":
			current_ap += value
		"special_poop":
			poop_played_this_turn = true
			draw_card()
		"sleep", "bread":
			draw_card()
		"attack_fire":
			apply_damage_to_enemy(value)
			enemy_fire_stacks += 1
		"attack_bomb":
			var total_dmg = value + (enemy_fire_stacks * 5)
			apply_damage_to_enemy(total_dmg)
		"buff_fire":
			enemy_fire_stacks *= value
			if data.get("name") == "余烬":
				current_ap += 1
		"attack_seed":
			apply_damage_to_enemy(value)
			if GameManager.selected_hero:
				var fire_cards = GameManager.selected_hero.card_pool.filter(func(c): return c.get("emoji") == "🔥")
				if fire_cards.size() > 0:
					draw_card(fire_cards[randi() % fire_cards.size()])
				else:
					draw_card()
		"defense_ink":
			var def = value
			if poop_played_this_turn:
				if value >= 15: # 进化版：浓缩墨汁
					def *= 3
				else:
					def *= 2
			apply_heal_to_hero(def)
		"buff_evasion":
			is_evading = true
			next_turn_extra_draws += value
		"debuff_atk":
			enemy_atk_reduction += value
			print("敌人攻击力降低: ", value)
		"attack_steal":
			apply_damage_to_enemy(value)
			apply_heal_to_hero(value)
		"record_data":
			recorded_data_value = last_damage_dealt * (value if value > 0 else 1)
			print("记录数值: ", recorded_data_value)
		"release_data":
			apply_damage_to_enemy(recorded_data_value * value)
		"debuff_def":
			enemy_vulnerability += value
			print("敌人防御削弱，受击伤害增加: ", value)
		"junk_goal":
			current_ap -= 1
			print("打出虚假目标，摸鱼力 -1")
		"attack_draw_conditional":
			apply_damage_to_enemy(value)
			var c = draw_card()
			if c and c.card_data.get("emoji") == "📊":
				print("触发连动：抽到数据卡，额外再抽一张！")
				await get_tree().create_timer(0.2).timeout
				draw_card()
		"attack_draw_record":
			apply_damage_to_enemy(value)
			for i in range(3): draw_card()
			recorded_data_value = last_damage_dealt
			current_ap += 1
			print("核心卡触发：造成伤害，抽 3 张牌，记录数值并回复 1 AP: ", recorded_data_value)
		"red_tape":
			intent_label.text = "意图：流程审批中 (发呆)"
			skip_enemy_turn = true
		"paid_leave":
			apply_heal_to_hero(20)
			is_waiting_next_turn = false
			next_turn_extra_draws += 2
		"cancel_intent":
			intent_label.text = "意图：发呆中..."
			if value > 1:
				set_meta("skip_next_intent", true)
		"filter_cards":
			for i in range(value):
				var c = draw_card()
				if c and c.card_data.get("cost", 1) > 1:
					await get_tree().create_timer(0.1).timeout
					if c in hand_cards:
						hand_cards.erase(c)
						c.queue_free()
						update_hand_layout()
		"wait_defense":
			is_waiting_next_turn = true
			apply_heal_to_hero(value)
		"reflect_damage":
			has_reflect_shield = true
		"attack_draw_specific":
			apply_damage_to_enemy(value)
			var target = data.get("target_emoji", "")
			var found = false
			for i in range(draw_pile.size()):
				if draw_pile[i].get("emoji") == target:
					var c_data = draw_pile.pop_at(i)
					draw_card(c_data)
					found = true
					break
			if not found:
				for i in range(discard_pile.size()):
					if discard_pile[i].get("emoji") == target:
						var c_data = discard_pile.pop_at(i)
						draw_card(c_data)
						found = true
						break
			if not found:
				print("未找到目标卡牌: ", target)
		"release_data_ap":
			apply_damage_to_enemy(recorded_data_value * value)
			current_ap += 2
		"debuff_def_perm":
			enemy_vulnerability += value
			if not self.has_meta("perm_vulnerability"):
				set_meta("perm_vulnerability", 0)
			set_meta("perm_vulnerability", get_meta("perm_vulnerability") + value)
		"buff_all_cards":
			enemy_vulnerability += 20 
		"reduce_max_hp":
			enemy_hp_bar.max_value -= value
			enemy_hp = min(enemy_hp, enemy_hp_bar.max_value)
			print("敌人耐性上限削减: ", value)
		"filter_cards_buff":
			for i in range(value):
				var c = draw_card()
				if c and c.card_data.get("cost", 1) <= 1:
					c.card_data["cost"] = 0
		"reflect_damage_double":
			has_reflect_shield = true
			set_meta("reflect_multiplier", value)
		"paid_leave_ultra":
			apply_heal_to_hero(value)
			next_turn_extra_draws += 5

func apply_damage_to_enemy(amount: int):
	var final_dmg = amount
	if enemy_vulnerability > 0:
		final_dmg += enemy_vulnerability
	if self.has_meta("perm_vulnerability"):
		final_dmg += get_meta("perm_vulnerability")
		
	enemy_hp -= final_dmg
	enemy_hp = max(0, enemy_hp)
	last_damage_dealt = final_dmg
	if %BossSprite.has_method("play_hit"):
		%BossSprite.play_hit()
	spawn_floating_number(final_dmg, final_dmg > 20, %BossSprite.global_position)
	if enemy_hp <= 0:
		show_victory()

func show_victory():
	end_turn_button.disabled = true
	level_clear_label.text = "第 %d 关 已突破" % GameManager.current_level
	get_tree().create_timer(0.5).timeout.connect(show_reward_selection)

func show_reward_selection():
	var reward_layer = CanvasLayer.new()
	reward_layer.layer = 100 
	add_child(reward_layer)
	var root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reward_layer.add_child(root)
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var center_container = CenterContainer.new()
	center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center_container)
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 60)
	center_container.add_child(vbox)
	var title = Label.new()
	title.text = "--- 获得强化：选择一张新 Emoji 加入牌组 ---"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color.GOLD)
	vbox.add_child(title)
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 30) 
	vbox.add_child(hbox)
	var rewards = GameManager.get_random_reward_cards(3)
	for data in rewards:
		var card_panel = PanelContainer.new()
		var style = StyleBoxFlat.new()
		style.bg_color = Color("#fdf5e6")
		style.set_corner_radius_all(15)
		style.border_width_left = 4
		style.border_width_top = 4
		style.border_width_right = 4
		style.border_width_bottom = 4
		style.border_color = Color("#d2b48c")
		card_panel.add_theme_stylebox_override("panel", style)
		card_panel.custom_minimum_size = Vector2(180, 260) 
		hbox.add_child(card_panel)
		var card_vbox = VBoxContainer.new()
		card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		card_vbox.add_theme_constant_override("separation", 10)
		card_panel.add_child(card_vbox)
		var emoji_label = Label.new()
		emoji_label.text = data.emoji
		emoji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		emoji_label.add_theme_font_size_override("font_size", 80)
		card_vbox.add_child(emoji_label)
		var name_label = Label.new()
		name_label.text = data.name
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 24)
		name_label.add_theme_color_override("font_color", Color.BLACK)
		card_vbox.add_child(name_label)
		var cost_label = Label.new()
		cost_label.text = "%d AP" % data.cost
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_label.add_theme_font_size_override("font_size", 18)
		cost_label.add_theme_color_override("font_color", Color.DARK_SLATE_GRAY)
		card_vbox.add_child(cost_label)
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 10)
		card_vbox.add_child(spacer)
		var select_btn = Button.new()
		select_btn.text = "选择"
		select_btn.custom_minimum_size = Vector2(120, 45)
		select_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card_vbox.add_child(select_btn)
		select_btn.pressed.connect(func():
			GameManager.player_deck.append(data)
			reward_layer.queue_free()
			victory_layer.visible = true
		)

func apply_heal_to_hero(amount: int):
	hero_hp += amount
	hero_hp = min(GameManager.max_player_hp, hero_hp)
	spawn_floating_number(amount, false, hero_sprite.global_position + Vector2(0, -50), Color.GREEN)
	update_ui_values()
	update_status_display()

func spawn_floating_number(amount: int, is_critical: bool, pos: Vector2, color: Color = Color.WHITE):
	var fn = floating_number_scene.instantiate()
	add_child(fn)
	fn.global_position = pos
	fn.pop_up(amount, is_critical)
	fn.modulate = color
