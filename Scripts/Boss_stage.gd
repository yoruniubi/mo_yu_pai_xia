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
@onready var emoji_slot_container = %EmojiSlot
@onready var end_turn_button = %EndTurnButton
@onready var ending_layer = %EndingLayer
@onready var back_to_menu_button = %BackToMenuButton
@onready var game_over_layer = %GameOverLayer
@onready var restart_button = %RestartButton
@onready var status_container = %StatusContainer
@onready var enemy_status_container = %EnemyStatusContainer

# --- 配置参数 ---
var card_scene = preload("res://Scenes/battle_card.tscn")
var floating_number_scene = preload("res://Scenes/floating_number.tscn")
var hand_cards = []
var current_sequence = [] # 存储当前打出的 Emoji 序列
var cards_played_this_turn = [] # 记录本回合打出的所有卡牌数据
var last_player_card_data = {} # 记录玩家最后出的牌
var draw_pile = []
var discard_pile = []
var is_battle_over = false # 战斗结束锁

# 战斗数值
var hero_hp = 100 # 初始 100 生命
var hero_shield = 0
var enemy_hp = 100
var current_ap = 3

# 特殊状态变量 (同步 battle_scene)
var enemy_fire_stacks = 0
var enemy_poison_stacks = 0
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
var next_turn_extra_ap = 0
var next_attack_multiplier = 1.0 # 扩音器效果
var cost_reduction_active = false # 团建干杯效果
var save_hand_this_turn = false # 存档效果
var ap_multiplier_next_turn = 1.0 # 全线崩溃效果
var current_phase = 0 # 0: KPI, 1: Wolf, 2: Dream

# 当前激活的连招池
var active_combos = {}

# 扇形布局参数 (同步 battle_scene)
const FAN_RADIUS = 800.0
const MAX_FAN_ANGLE = 30.0

func _ready() -> void:
	# 1. 播放 BOSS 战音乐
	var bgm = preload("res://Assets/Music/Deadline_Duel.mp3")
	BgmManager.play_music(bgm)
	
	# 2. 初始化连招池
	_initialize_combos()
	
	# 3. 初始化英雄数据
	if GameManager.selected_hero:
		var hero = GameManager.selected_hero
		hero_sprite.texture = hero.character_image
		hero_name_label.text = hero.character_name
		# 确保名字标签尺寸固定，防止内容变化引起血条上下抖动
		hero_name_label.custom_minimum_size = Vector2(240, 40)
		hero_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hero_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	
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
	_update_boss_intent()
	%BossSprite.texture = load(enemy.image)
	
	# 初始 AP
	current_ap = GameManager.max_ap
	
	# 5. 初始化数值 UI
	update_ui_values()
	update_status_display()
	
	# 6. 按钮样式与绑定
	setup_button_style()
	
	# 5. 初始化战斗牌堆
	draw_pile = GameManager.player_deck.duplicate()
	draw_pile.shuffle()
	
	# 6. 初始抽牌
	for i in range(5):
		draw_card()

func setup_button_style():
	var style_normal = _create_style("#4a4a4a", 10, 4)
	var style_hover = _create_style("#666666", 10, 6)
	var style_pressed = _create_style("#222222", 10, 0)
	
	# 结束回合按钮样式
	end_turn_button.add_theme_stylebox_override("normal", style_normal)
	end_turn_button.add_theme_stylebox_override("hover", style_hover)
	end_turn_button.add_theme_stylebox_override("pressed", style_pressed)
	end_turn_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	end_turn_button.focus_mode = Control.FOCUS_NONE
	end_turn_button.add_theme_color_override("font_color", Color.WHITE)
	
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	
	# 放弃挑战按钮样式 (Boss 关)
	back_to_menu_button.add_theme_stylebox_override("normal", _create_style("#fdf5e6", 15, 2))
	back_to_menu_button.add_theme_stylebox_override("hover", _create_style("#ff6b6b", 15, 4))
	back_to_menu_button.add_theme_stylebox_override("pressed", _create_style("#c0392b", 15, 0))
	back_to_menu_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	back_to_menu_button.focus_mode = Control.FOCUS_NONE
	back_to_menu_button.add_theme_color_override("font_color", Color("#4a4a4a"))
	back_to_menu_button.add_theme_color_override("font_hover_color", Color.WHITE)
	
	back_to_menu_button.pressed.connect(_on_back_to_menu_pressed)
	back_to_menu_button.position = Vector2(20, 110)
	
	# 重新开始按钮样式
	restart_button.add_theme_stylebox_override("normal", style_normal)
	restart_button.add_theme_stylebox_override("hover", style_hover)
	restart_button.add_theme_stylebox_override("pressed", style_pressed)
	restart_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	restart_button.focus_mode = Control.FOCUS_NONE
	restart_button.add_theme_color_override("font_color", Color.WHITE)
	
	restart_button.pressed.connect(_on_restart_pressed)
	
	if has_node("%ComboDirectoryButton"):
		var combo_btn = %ComboDirectoryButton
		combo_btn.pressed.connect(show_combo_directory)
		# 统一按钮风格
		var cb_normal = _create_style("#fdf5e6", 10, 2)
		var cb_hover = _create_style("#8fb9aa", 10, 4)
		var cb_pressed = _create_style("#7aa899", 10, 0)
		combo_btn.add_theme_stylebox_override("normal", cb_normal)
		combo_btn.add_theme_stylebox_override("hover", cb_hover)
		combo_btn.add_theme_stylebox_override("pressed", cb_pressed)
		combo_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		combo_btn.focus_mode = Control.FOCUS_NONE
		combo_btn.add_theme_color_override("font_color", Color("#4a4a4a"))

func _create_style(color_hex: String, radius: int, shadow: int) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(color_hex)
	sb.set_corner_radius_all(radius)
	sb.shadow_size = shadow
	sb.shadow_offset = Vector2(0, shadow / 2.0)
	sb.border_width_bottom = 2
	sb.border_color = Color(0, 0, 0, 0.1)
	return sb

func update_ui_values():
	hero_hp_bar.value = hero_hp
	enemy_hp_bar.value = enemy_hp
	_ensure_hp_label(hero_hp_bar, "HeroHpValueLabel", hero_hp, Color.WHITE)
	_ensure_hp_label(enemy_hp_bar, "EnemyHpValueLabel", enemy_hp, Color.WHITE)
	
	# 同步护盾 UI (与 battle_scene 一致)
	var shield_display = hero_hp_bar.get_node_or_null("ShieldDisplay")
	if not shield_display:
		shield_display = PanelContainer.new()
		shield_display.name = "ShieldDisplay"
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0, 0.6, 0.7, 0.9) # 更亮一点的护盾青
		style.set_corner_radius_all(10)
		style.content_margin_left = 6
		style.content_margin_right = 6
		style.border_width_left = 2
		style.border_color = Color.CYAN
		shield_display.add_theme_stylebox_override("panel", style)
		
		var label = Label.new()
		label.name = "Label"
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color.WHITE)
		shield_display.add_child(label)
		hero_hp_bar.add_child(shield_display)
	
	if hero_shield > 0:
		shield_display.get_node("Label").text = "🛡️%d" % hero_shield
		shield_display.show()
		# 放在血条左侧固定位置
		shield_display.position = Vector2(-70, -2) 
	else:
		shield_display.hide()
		
	# 保持名字标签纯净，防止抖动
	hero_name_label.text = GameManager.selected_hero.character_name if GameManager.selected_hero else "英雄"

	energy_label.text = "摸鱼力: %d/%d" % [current_ap, GameManager.max_ap]
	
	# 如果当前 AP 超过上限（临时 AP），改变颜色提醒
	if current_ap > GameManager.max_ap:
		energy_label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		energy_label.remove_theme_color_override("font_color")
		
	# 更新离职进度条
	if has_node("%ResignationBar"):
		var bar = %ResignationBar
		bar.value = GameManager.current_level
		_style_resignation_bar(bar)
	# 同步到全局
	GameManager.player_hp = hero_hp

func _ensure_hp_label(bar: ProgressBar, label_name: String, value: int, color: Color) -> void:
	var label = bar.get_node_or_null(label_name)
	if not label:
		label = Label.new()
		label.name = label_name
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.anchor_left = 0
		label.anchor_top = 0
		label.anchor_right = 1
		label.anchor_bottom = 1
		label.offset_left = 0
		label.offset_top = 0
		label.offset_right = 0
		label.offset_bottom = 0
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", color)
		label.add_theme_constant_override("outline_size", 2)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		bar.add_child(label)
	bar.show_percentage = false
	label.text = str(value)

func _initialize_combos():
	active_combos = GameManager.universal_combos.duplicate(true)
	if GameManager.selected_hero:
		var hero_name = GameManager.selected_hero.character_name
		if GameManager.character_combos.has(hero_name):
			var char_combos = GameManager.character_combos[hero_name]
			for key in char_combos:
				active_combos[key] = char_combos[key]

func _is_emoji_part_of_any_combo(emoji: String) -> bool:
	for combo in active_combos.values():
		if emoji in combo.parts:
			return true
	return false

# --- 核心战斗逻辑：卡牌使用与连招 ---

func _on_card_played(card_node):
	var data = card_node.card_data
	var cost = data.get("cost", 1)
	
	if cost_reduction_active:
		cost = max(0, cost - 1)
	
	# KPI 考核影响
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
	
	var type = data.get("type", "")
	# 特殊逻辑：文件夹配合周报
	if type == "attack_conditional_keyboard" and not cards_played_this_turn.is_empty():
		var last = cards_played_this_turn.back()
		if last.get("emoji") == "📁":
			apply_shield_to_hero(10)
			spawn_floating_number("ARCHIVED", false, hero_sprite.global_position + Vector2(0, -100), Color.CYAN)

	execute_card_effect(data)
	last_player_card_data = data
	cards_played_this_turn.append(data)
	
	# 垃圾卡也会进入弃牌堆以持续污染牌组
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

func execute_card_effect(data: Dictionary):
	var type = data.get("type", "")
	var value = data.get("value", 0)
	var emoji = data.get("emoji", "")
	match type:
		"attack":
			var dmg = value
			if emoji == "⌨️" and keyboard_buff_active:
				dmg *= 3
			dmg *= next_attack_multiplier
			next_attack_multiplier = 1.0
			apply_damage_to_enemy(dmg)
		"heal":
			apply_heal_to_hero(value)
		"shield":
			apply_shield_to_hero(value)
		"shield_draw":
			apply_shield_to_hero(value)
			draw_card()
		"shield_attack":
			apply_shield_to_hero(value)
			apply_damage_to_enemy(value - 2)
		"evasion_draw":
			is_evading = true
			draw_card()
		"attack_draw":
			apply_damage_to_enemy(value)
			draw_card()
		"buff_ap", "temp_ap":
			current_ap += value
		"buff_ap_draw":
			current_ap += value
			draw_card()
		"next_turn_ap":
			next_turn_extra_ap += value
		"special_poop":
			poop_played_this_turn = true
			enemy_poison_stacks += 3 # 施加 3 层中毒
			draw_card()
		"sleep", "bread":
			draw_card()
		"draw_only":
			for i in range(value):
				draw_card()
		"defense_attack":
			apply_heal_to_hero(value)
			apply_damage_to_enemy(value)
		"attack_fire":
			apply_damage_to_enemy(value)
			enemy_fire_stacks += 1
		"attack_bomb":
			var total_dmg = value + (enemy_fire_stacks * 5)
			apply_damage_to_enemy(total_dmg)
		"buff_fire":
			if enemy_fire_stacks == 0:
				enemy_fire_stacks = 1
			else:
				enemy_fire_stacks *= value
			if data.get("name") == "余烬":
				current_ap += 1
		"attack_seed":
			apply_damage_to_enemy(value)
			apply_shield_to_hero(3)
			if GameManager.selected_hero:
				var fire_cards = GameManager.selected_hero.card_pool.filter(func(c): return c.get("emoji") == "🔥")
				if fire_cards.size() > 0:
					draw_card(fire_cards[randi() % fire_cards.size()])
				else:
					draw_card()
		"defense_ink":
			var def = value
			if poop_played_this_turn:
				if value >= 15: def *= 3
				else: def *= 2
			apply_shield_to_hero(def)
		"buff_evasion":
			is_evading = true
			next_turn_extra_draws += value
		"debuff_atk":
			enemy_atk_reduction += value
		"attack_steal":
			apply_damage_to_enemy(value)
			apply_shield_to_hero(value)
		"record_data":
			# 保底记录 5 点，防止空转
			var base = last_damage_dealt if last_damage_dealt > 0 else 5
			recorded_data_value = base * (value if value > 0 else 1)
		"release_data":
			# 保底造成 5 点伤害
			var dmg = recorded_data_value * value
			apply_damage_to_enemy(max(5, dmg))
		"debuff_def":
			enemy_vulnerability += value
		"junk_goal":
			current_ap -= 1
		"attack_draw_conditional":
			apply_damage_to_enemy(value)
			var c = draw_card()
			if c and c.card_data.get("emoji") == "📊":
				await get_tree().create_timer(0.2).timeout
				draw_card()
		"attack_draw_record":
			apply_damage_to_enemy(value)
			for i in range(3): draw_card()
			recorded_data_value = last_damage_dealt
			current_ap += 1
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
			var discarded_count = 0
			for i in range(value):
				var c = draw_card()
				if c and c.card_data.get("cost", 1) > 1:
					await get_tree().create_timer(0.1).timeout
					if c in hand_cards:
						hand_cards.erase(c)
						c.queue_free()
						discarded_count += 1
						update_hand_layout()
			if discarded_count > 0:
				apply_shield_to_hero(discarded_count * 3)
		"wait_defense":
			is_waiting_next_turn = true
			apply_shield_to_hero(value)
		"reflect_damage":
			has_reflect_shield = true
			apply_shield_to_hero(5)
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
		"heal_draw":
			apply_heal_to_hero(value)
			draw_card()
		"attack_conditional_keyboard":
			var dmg = value
			var keyboard_played = false
			for c in cards_played_this_turn:
				if c.get("emoji") == "⌨️":
					keyboard_played = true
					break
			if keyboard_played:
				dmg *= 2
			apply_damage_to_enemy(dmg)
		"evade_penalty_draw":
			is_evading = true
			next_turn_extra_draws -= 1
		"draw_discount":
			var c = draw_card()
			if c and c.card_data.get("emoji") != "":
				c.card_data["cost"] = 0
				c.update_ui()
		"shield_folder":
			apply_shield_to_hero(value)
			# 逻辑在打出卡牌时判断，这里简单处理
		"buff_next_attack":
			next_attack_multiplier = value
			spawn_floating_number("POWER UP!", false, hero_sprite.global_position + Vector2(0, -100), Color.ORANGE)
		"heal_remove_junk":
			apply_heal_to_hero(value)
			var junk_removed = false
			for i in range(hand_cards.size()-1, -1, -1):
				if hand_cards[i].card_data.get("type", "").begins_with("junk"):
					var c = hand_cards[i]
					hand_cards.remove_at(i)
					c.queue_free()
					junk_removed = true
					break
			if junk_removed:
				update_hand_layout()
				spawn_floating_number("BUG FIXED", false, hero_sprite.global_position + Vector2(0, -150), Color.WHITE)
		"draw_hero_card":
			if GameManager.selected_hero and GameManager.selected_hero.card_pool.size() > 0:
				var pool = GameManager.selected_hero.card_pool
				draw_card(pool[randi() % pool.size()])
		"attack_draw_email":
			apply_damage_to_enemy(value)
			var c = draw_card()
			if c and c.card_data.get("emoji") == "⌨️":
				apply_damage_to_enemy(10)
				spawn_floating_number("CONFIRMED!", false, %BossSprite.global_position + Vector2(0, -150), Color.GOLD)
		"shield_hand":
			apply_shield_to_hero(hand_cards.size() * value)
		"heal_ap_next":
			apply_heal_to_hero(value)
			next_turn_extra_ap += 1
		"ap_investment":
			next_turn_extra_ap += value
			spawn_floating_number("PAYDAY!", false, hero_sprite.global_position + Vector2(0, -100), Color.GOLD)
		"shield_generate_review":
			apply_shield_to_hero(value)
			discard_pile.append(GameManager.universal_cards[11].duplicate()) # 📑 周报汇总
		"cost_reduction":
			cost_reduction_active = true
			for c in hand_cards:
				c.update_ui() # 刷新 UI 显示新消耗
		"save_hand":
			save_hand_this_turn = true
			spawn_floating_number("SAVED", false, hero_sprite.global_position + Vector2(0, -100), Color.GREEN)
		"pull_plug":
			apply_damage_to_enemy(value)
			_on_end_turn_pressed()
		"clean_status":
			# 移除可能的负面状态
			if next_turn_extra_draws < 0: next_turn_extra_draws = 0
			ap_multiplier_next_turn = 1.0
			spawn_floating_number("CLEANSED", false, hero_sprite.global_position + Vector2(0, -100), Color.WHITE)
		"delivery_cards":
			for i in range(value):
				var card_data = GameManager.universal_cards[randi() % GameManager.universal_cards.size()].duplicate()
				draw_card(card_data)
		"layoff_list":
			var dmg = hero_shield * value
			hero_shield = 0
			apply_damage_to_enemy(dmg)
			update_ui_values()
		"attack_fire_burst":
			apply_damage_to_enemy(value)
			enemy_fire_stacks += 2
		"generate_fire_card":
			if GameManager.selected_hero:
				var fire_cards = GameManager.selected_hero.card_pool.filter(func(c): return c.get("emoji") == "🔥")
				if fire_cards.size() > 0:
					draw_card(fire_cards[randi() % fire_cards.size()])
		"debuff_atk_next":
			enemy_atk_reduction += value
		"record_shield_dmg":
			recorded_data_value = hero_shield * value
			spawn_floating_number("SHIELD DATA", false, hero_sprite.global_position + Vector2(0, -100), Color.CYAN)
		"draw_ap":
			draw_card()
			current_ap += value
		"attack_debuff_atk_half":
			apply_damage_to_enemy(value)
			# 简化：降低老板下一击伤害
			enemy_atk_reduction += 15 
		"heal_vulnerability":
			apply_heal_to_hero(value)
			enemy_vulnerability += 5

func apply_damage_to_enemy(amount: int):
	if is_battle_over: return
	var final_dmg = amount
	if enemy_vulnerability > 0:
		final_dmg += enemy_vulnerability
	if self.has_meta("perm_vulnerability"):
		final_dmg += get_meta("perm_vulnerability")
		
	enemy_hp -= final_dmg
	enemy_hp = max(0, enemy_hp)
	last_damage_dealt = final_dmg
	print("对 BOSS 造成 %d 点伤害" % amount)
	
	# 播放敌人受击动画
	if %BossSprite.has_method("play_hit"):
		%BossSprite.play_hit()
	
	# 显示伤害数字
	spawn_floating_number(amount, amount > 20, %BossSprite.global_position)
	
	if enemy_hp <= 0:
		show_ending()

func show_ending():
	if is_battle_over: return
	is_battle_over = true
	end_turn_button.disabled = true
	get_tree().create_timer(1.0).timeout.connect(func():
		ending_layer.visible = true
	)

func _on_back_to_menu_pressed():
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")

func _on_restart_pressed():
	GameManager.is_tutorial_mode = false
	GameManager.reset_run()
	GameManager.load_current_level_scene()

func _style_resignation_bar(bar: ProgressBar):
	# 背景样式：深奶油色底座，更有厚度感
	var sb_bg = StyleBoxFlat.new()
	sb_bg.bg_color = Color("#dcd8c0") 
	sb_bg.set_corner_radius_all(12)
	sb_bg.expand_margin_top = 6
	sb_bg.expand_margin_bottom = 6
	sb_bg.border_width_left = 2
	sb_bg.border_width_top = 2
	sb_bg.border_width_right = 2
	sb_bg.border_width_bottom = 2
	sb_bg.border_color = Color("#c5c0a5")
	bar.add_theme_stylebox_override("background", sb_bg)
	
	# 填充样式：Boss战特有的金绿色渐变质感
	var sb_fg = StyleBoxFlat.new()
	sb_fg.bg_color = Color("#ffd700") # 金色，强调终局
	sb_fg.set_corner_radius_all(10)
	sb_fg.border_width_right = 4
	sb_fg.border_color = Color("#b8860b") # 暗金色边
	bar.add_theme_stylebox_override("fill", sb_fg)
	
	# 文字标签优化：增加描边使其更清晰
	if bar.has_node("ResignationLabel"):
		var label = bar.get_node("ResignationLabel")
		label.add_theme_color_override("font_color", Color("#3d3d3d"))
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_constant_override("outline_size", 3)
		label.add_theme_color_override("font_outline_color", Color.WHITE)
		label.text = "🔥 最终决战: %d / 10 🏁" % GameManager.current_level
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func apply_heal_to_hero(amount: int):
	# 传统回血
	hero_hp += amount
	hero_hp = min(GameManager.max_player_hp, hero_hp)
	print("回复了 %d 点生命" % amount)
	spawn_floating_number(amount, false, hero_sprite.global_position + Vector2(0, -50), Color.GREEN)
	update_ui_values()
	update_status_display()

func apply_shield_to_hero(amount: int):
	hero_shield += amount
	spawn_floating_number(amount, false, hero_sprite.global_position + Vector2(0, -50), Color.CYAN)
	update_ui_values()
	update_status_display()

func spawn_floating_number(value: Variant, is_critical: bool, pos: Vector2, color: Color = Color.WHITE):
	var fn = floating_number_scene.instantiate()
	add_child(fn)
	fn.global_position = pos
	fn.pop_up(value, is_critical)
	fn.modulate = color

func update_emoji_slots():
	# 清空旧的显示
	for child in emoji_slot_container.get_children():
		child.queue_free()
	
	# 创建新的 Emoji 标签
	for emoji in current_sequence:
		var label = Label.new()
		label.text = emoji
		label.add_theme_font_size_override("font_size", 40)
		emoji_slot_container.add_child(label)
		
		# 入场动画
		label.scale = Vector2.ZERO
		label.pivot_offset = Vector2(20, 20)
		create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK).tween_property(label, "scale", Vector2.ONE, 0.3)

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
			# 触发连招后通常清空序列，或者保留部分，这里选择清空
			current_sequence.clear()
			# 延迟一点清空 UI，让玩家看清
			get_tree().create_timer(0.8).timeout.connect(update_emoji_slots)
			break

func trigger_combo(combo_data):
	print("！！！触发连招：", combo_data.name, " -> ", combo_data.effect)
	
	# --- 视觉特效 ---
	# 1. 屏幕闪烁
	if %AnimationManager.has_method("play_combo_flash"):
		%AnimationManager.play_combo_flash()
	elif has_node("%FlashLayer"):
		var flash = %FlashLayer
		var ft = create_tween()
		flash.modulate = Color(1, 1, 0, 0.4) # 金色闪烁
		ft.tween_property(flash, "modulate:a", 0, 0.5)
		ft.finished.connect(func(): flash.modulate = Color(1, 0, 0, 0))
	
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
		"slack_trio":
			for i in range(2): draw_card()
			current_ap += 1
		"office_slicker":
			is_evading = true
			set_meta("evasion_turns", 2)
		"paid_gym":
			apply_heal_to_hero(10)
			GameManager.max_player_hp += 5
			hero_hp_bar.max_value = GameManager.max_player_hp
		"excellent_employee":
			apply_shield_to_hero(20)
			current_ap += 1
		"poop_master":
			enemy_poison_stacks *= 2
			spawn_floating_number("POISON x2", false, %BossSprite.global_position + Vector2(0, -100), Color.GREEN_YELLOW)
		"crazy_output":
			apply_damage_to_enemy(35)
		"deep_review":
			var cards_to_copy = cards_played_this_turn.duplicate()
			for card_data in cards_to_copy:
				if card_data.get("emoji") == "":
					execute_card_effect(card_data)
		"brainstorm":
			for i in range(3): draw_card()
			current_ap += 1
		"office_phantom":
			is_evading = true
			set_meta("evasion_turns", 2)
		"caffeine_overload":
			current_ap += 2
			for i in range(2): draw_card()
			apply_damage_to_hero(5)
		"remote_output":
			apply_damage_to_enemy(15)
			draw_card()
		"poop_god":
			enemy_poison_stacks *= 3
			spawn_floating_number("POISON x3", false, %BossSprite.global_position + Vector2(0, -100), Color.GREEN_YELLOW)
		"file_archive":
			apply_shield_to_hero(15)
			draw_card()
		"auto_clicker":
			apply_damage_to_enemy(20)
		"paid_interview":
			apply_shield_to_hero(10)
			for i in range(2): draw_card()
		"cc_everyone":
			for i in range(2): draw_card()
			apply_damage_to_enemy(12)
		"mental_health":
			apply_heal_to_hero(25)
			current_ap += 1
		"venture_capital":
			current_ap += 2
			for i in range(2): draw_card()
		"write_report":
			apply_damage_to_enemy(18)
			apply_shield_to_hero(8)
		"volcano_eruption":
			var dmg = enemy_fire_stacks * 15
			apply_damage_to_enemy(dmg)
			enemy_fire_stacks = 0
			spawn_floating_number("VOLCANO!", true, %BossSprite.global_position)
		"deep_sea_vortex":
			skip_enemy_turn = true
			set_meta("skip_next_intent", true)
			spawn_floating_number("STUNNED", false, %BossSprite.global_position + Vector2(0, -100), Color.CYAN)
		"quarterly_audit":
			apply_damage_to_enemy(recorded_data_value * 2)
			spawn_floating_number("AUDITED", true, %BossSprite.global_position)
		"veto_power":
			enemy_atk_reduction += 10
			spawn_floating_number("VETOED", false, %BossSprite.global_position + Vector2(0, -100), Color.RED)
		"system_crash":
			apply_damage_to_enemy(60)
			ap_multiplier_next_turn = 0.5
			spawn_floating_number("SYSTEM CRASH", true, %BossSprite.global_position, Color.RED)
		"long_vacation":
			apply_heal_to_hero(40)
			next_turn_extra_draws += 3
		"office_elite":
			apply_shield_to_hero(20)
			next_attack_multiplier = 2.0
		"no_internet":
			skip_enemy_turn = true
			for i in range(2): draw_card()

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

# --- 基础功能 (同步自 battle_scene) ---

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
	var base_y = hand_container.size.y - 100.0
	var total_angle = min(MAX_FAN_ANGLE, card_count * 10.0)
	var angle_step = 0.0
	if card_count > 1: angle_step = total_angle / (card_count - 1.0)
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

func _on_end_turn_pressed():
	print("结束回合！")
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
	# 处理中毒伤害
	if enemy_poison_stacks > 0:
		print("中毒发作：造成 %d 点伤害" % enemy_poison_stacks)
		apply_damage_to_enemy(enemy_poison_stacks)
		enemy_poison_stacks = max(0, enemy_poison_stacks - 1)
		update_status_display()
		await get_tree().create_timer(0.4).timeout

	# 同步 battle_scene 的跳过意图逻辑
	if has_meta("skip_next_intent"):
		remove_meta("skip_next_intent")
		intent_label.text = "意图：继续发呆..."
		await get_tree().create_timer(1.0).timeout
		start_player_turn()
		return

	if %BossSprite.has_method("play_attack"):
		%BossSprite.play_attack()
	
	await get_tree().create_timer(0.5).timeout
	
	match current_phase:
		0: # KPI 考核
			print("CEO 释放了【KPI 考核】！")
			var dmg = max(0, 15 - enemy_atk_reduction)
			apply_damage_to_hero(dmg)
			inject_junk_card("kpi")
		1: # 狼性文化
			print("CEO 宣扬【狼性文化】！")
			for i in range(4):
				var dmg = max(0, 8 - enemy_atk_reduction)
				apply_damage_to_hero(dmg)
				await get_tree().create_timer(0.2).timeout
		2: # 谈谈梦想
			print("CEO 和你【谈谈梦想】！")
			var dmg = max(0, 10 - enemy_atk_reduction)
			apply_damage_to_hero(dmg)
			enemy_hp += 40
			enemy_hp = min(500, enemy_hp)
			spawn_floating_number(40, false, %BossSprite.global_position, Color.GREEN)
			update_ui_values()
	
	current_phase = (current_phase + 1) % 3
	enemy_atk_reduction = 0 # 重置
	
	if hero_hp <= 0:
		show_game_over()
		return
		
	start_player_turn()

func _update_boss_intent():
	match current_phase:
		0: intent_label.text = "意图：KPI 考核 (增加 Combo 消耗)"
		1: intent_label.text = "意图：狼性文化 (高频连击)"
		2: intent_label.text = "意图：谈谈梦想 (回复耐性)"

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
	print("玩家回合开始！")
	end_turn_button.disabled = false
	
	# 1. 重置摸鱼力 (同步 battle_scene 的 AP 计算逻辑)
	current_ap = int((GameManager.max_ap + next_turn_extra_ap) * ap_multiplier_next_turn)
	next_turn_extra_ap = 0
	ap_multiplier_next_turn = 1.0
	
	# 2. 重置回合状态
	poop_played_this_turn = false
	cards_played_this_turn.clear()
	cost_reduction_active = false
	
	# 回合开始重置护盾
	hero_shield = 0
	
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
	
	# 3. 清空序列
	current_sequence.clear()
	update_emoji_slots()
	enemy_vulnerability = 0 # 重置易伤状态
	
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
		
		# 4. 清空手牌
		for card in hand_cards: card.queue_free()
		hand_cards.clear()
		
		# 5. 重新抽牌
		for i in range(draw_count): draw_card()
	
	# 6. 更新 UI
	_update_boss_intent()
	update_ui_values()
	update_status_display()

func apply_damage_to_hero(amount: int):
	var final_damage = amount
	
	if is_evading:
		if %AnimationManager.has_method("play_evade_anim"):
			%AnimationManager.play_evade_anim()
		spawn_floating_number("MISS", false, hero_sprite.global_position + Vector2(0, -50), Color.CYAN)
		return
		
	# 播放受击动画
	if %AnimationManager:
		%AnimationManager.play_player_hit_anim()
	
	# 优先扣除护盾
	if hero_shield > 0:
		if hero_shield >= final_damage:
			hero_shield -= final_damage
			spawn_floating_number(final_damage, false, hero_sprite.global_position + Vector2(0, -50), Color.CYAN)
			final_damage = 0
		else:
			final_damage -= hero_shield
			spawn_floating_number(hero_shield, false, hero_sprite.global_position + Vector2(0, -50), Color.CYAN)
			hero_shield = 0
	
	if final_damage <= 0:
		update_ui_values()
		return

	if has_reflect_shield:
		var multiplier = get_meta("reflect_multiplier") if has_meta("reflect_multiplier") else 1
		print("反弹！对 BOSS 造成 %d 点伤害" % (final_damage * multiplier))
		apply_damage_to_enemy(final_damage * multiplier)
		final_damage = 0
		has_reflect_shield = false
		if has_meta("reflect_multiplier"): remove_meta("reflect_multiplier")
	
	if final_damage >= hero_hp and false_hope_stacks > 0:
		false_hope_stacks -= 1
		final_damage = 0
		print("虚假希望抵消了致死伤害！")
	
	hero_hp -= final_damage
	hero_hp = max(0, hero_hp)
	
	var t = create_tween()
	t.tween_property(hero_sprite, "modulate", Color.RED, 0.1)
	t.tween_property(hero_sprite, "modulate", Color.WHITE, 0.1)
	
	update_ui_values()
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
						# 1. 序列还没凑齐该 Emoji
						# 2. 或者手牌本身就能凑齐连招
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
	if enemy_status_container:
		for child in enemy_status_container.get_children():
			child.queue_free()
	
	# 玩家状态
	if is_evading:
		_add_status_badge(status_container, " 闪避", Color.CYAN, "闪避：受到攻击时不受伤害")
	if keyboard_buff_active:
		_add_status_badge(status_container, "⌨️ 键盘侠", Color.ORANGE, "键盘侠：本回合键盘伤害 ×3")
	if has_reflect_shield:
		_add_status_badge(status_container, "🛡️ 反伤", Color.PURPLE, "反伤：反弹下一次受到的伤害")
	if false_hope_stacks > 0:
		_add_status_badge(status_container, "🍞 希望 x%d" % false_hope_stacks, Color.YELLOW, "希望：抵消一次致死伤害")
	
	# 敌人状态
	if enemy_status_container:
		if enemy_fire_stacks > 0:
			_add_status_badge(enemy_status_container, "🔥 火大 x%d" % enemy_fire_stacks, Color.RED, "火大：部分火系/爆破效果会消耗火大造成额外伤害")
		if enemy_vulnerability > 0:
			_add_status_badge(enemy_status_container, "💔 易伤 +%d" % enemy_vulnerability, Color.CORAL, "易伤：受到额外伤害 +%d" % enemy_vulnerability)
		if enemy_atk_reduction > 0:
			_add_status_badge(enemy_status_container, "📉 虚弱 -%d" % enemy_atk_reduction, Color.DARK_GRAY, "虚弱：攻击伤害降低 %d" % enemy_atk_reduction)
		if enemy_poison_stacks > 0:
			_add_status_badge(enemy_status_container, "🤢 中毒 x%d" % enemy_poison_stacks, Color.GREEN_YELLOW, "中毒：回合开始受到层数伤害，层数逐回合 -1")

func _add_status_badge(container: Control, text: String, color: Color, tooltip_text: String = ""):
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.25)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.border_width_left = 1
	style.border_color = color
	panel.add_theme_stylebox_override("panel", style)
	panel.tooltip_text = tooltip_text
	
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", color)
	label.tooltip_text = tooltip_text
	panel.add_child(label)
	container.add_child(panel)
