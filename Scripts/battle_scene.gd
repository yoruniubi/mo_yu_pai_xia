extends Control

# --- 节点引用 ---
@onready var hero_sprite = %HeroSprite
@onready var hero_name_label = %HeroName
@onready var hero_hp_bar = %HeroHPBar
@onready var enemy_name_label = %EnemyName
@onready var enemy_hp_bar = %EnemyHPBar
@onready var intent_card = %IntentCard
@onready var intent_icon = %IntentIcon
@onready var intent_text = %IntentText
@onready var intent_description = %IntentDescription
@onready var energy_label = %EnergyLabel
@onready var hand_container = %HandContainer
@onready var end_turn_button = %EndTurnButton
# boss_stage.tscn 使用 EndingLayer 而不是 VictoryLayer，统一兼容
@onready var victory_layer = get_node_or_null("%VictoryLayer") if has_node("%VictoryLayer") else get_node_or_null("%EndingLayer")
@onready var next_level_button = get_node_or_null("%NextLevelButton") if has_node("%NextLevelButton") else get_node_or_null("%BackToMenuButton")
@onready var level_clear_label = get_node_or_null("%LevelClearLabel")
# @onready var victory_sub_label = %VictorySubLabel
@onready var game_over_layer = %GameOverLayer
@onready var restart_button = %RestartButton
@onready var status_container = %StatusContainer
@onready var enemy_status_container = %EnemyStatusContainer

# --- 配置参数 ---
var card_scene = preload("res://Scenes/battle_card.tscn")
var floating_number_scene = preload("res://Scenes/floating_number.tscn")
var hand_cards = []
var current_sequence = []
var cards_played_this_turn = [] # 记录本回合打出的所有卡牌数据
var last_player_card_data = {} # 记录玩家最后出的牌，供鹦鹉复制
var draw_pile = []
var discard_pile = []
var is_battle_over = false # 战斗结束锁，防止重复触发胜利/失败

# 界面缩放
var _scale_factor: float = 1.0
# 战斗数值
var hero_hp = 120
var hero_shield = 0
var enemy_hp = 100
var current_ap = 4

# 特殊状态变量
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
var compliance_rule: Dictionary = {}
var compliance_violation_this_turn = false
var compliance_ap_spent_this_turn = 0
var raccoon_steal_ready = false
var poison_heal_inverted = false
var hydra_heads = 3
var hydra_head_hp = 60
var hydra_head_damage_this_turn = 0
var spider_shuffle_used = false
var hedgehog_turns_left = 3
var hedgehog_combo_met = false
var monkey_surveillance_stacks = 0  # 本回合打出的 Emoji 数量（监控蓄力）
var monkey_combo_count = 0          # 本场战斗已触发的 Combo 次数
var monkey_locked_emoji_slot = false # 监控猿：下回合锁定 1 个 Emoji 序列槽
var catfish_slipped_this_turn: bool = false  # 老油条鲶鱼：本回合是否已触发减伤
var supervisor_sleeping: bool = false  # 摸鱼猫主管：是否在偷懒
var whale_review_pressure: int = 0  # 年终总结鲸：累积考核压力
var vulture_outsource_stacks: int = 0  # 外包秃鹫：外包层数
var crab_jammed_count: int = 0  # 打印机螃蟹：已塞入的卡纸数
var battle_turn_count = 0            # 敌方回合计数：用于 Boss 周期技能
var printer_jam_cards_added = 0      # 打印机螃蟹：累计塞入卡纸数量
var boar_phase_two = false           # 部门经理野猪：二阶段增伤标记
var enemy_damage_bonus = 0
var player_damage_multiplier = 1.0
var battle_ap_bonus_applied = false
var first_card_free_used = false

# 局外升级相关计数
var _meta_burst_ot_count: int = 0       # burst_ot：每3张牌后下一张费用归零
var _meta_burst_ot_next_free: bool = false
var _meta_grind_count: int = 0           # sp_grind：每5张牌触发一次额外连招检测
# var _draft_discard_pending: bool = false # draft_start：回合结束额外丢弃1张

# 当前激活的连招池
var active_combos = {}

# 敌方行动卡组（用于区分普攻/技能并可视化）
var enemy_action_deck: Array = []
var enemy_action_index: int = 0
var current_enemy_action: Dictionary = {}

# 扇形布局参数
const FAN_RADIUS = 1000.0     # 扇形圆心距离
const MAX_FAN_ANGLE = 35.0    # 最大展开角度（度）

func _ready():

	var screen_size = get_viewport_rect().size
	_scale_factor = min(screen_size.x / 1080.0, screen_size.y / 1920.0)
	
	# 1. 根据战斗类型播放对应 BGM（在敌人选择之前判断）
	var battle_bgm: AudioStream
	var bgm_battle_type = GameManager.get_meta("next_battle_type", "normal") if GameManager.has_meta("next_battle_type") else "normal"
	match bgm_battle_type:
		"boss":
			battle_bgm = preload("res://Assets/Music/Deadline_Duel.mp3")
		"elite":
			battle_bgm = preload("res://Assets/Music/elite_bgm.mp3")
		_:
			battle_bgm = preload("res://Assets/Music/Cubicle_Cruise.mp3")
	BgmManager.play_music(battle_bgm)
	
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
	# 小Boss战前自动回满状态（仅在真正的小Boss关触发，而非硬编码关卡号）
	var is_miniboss = GameManager.has_meta("next_battle_type") and GameManager.get_meta("next_battle_type") == "boss" and GameManager.current_level < 15
	if is_miniboss:
		hero_hp = GameManager.max_player_hp
		GameManager.player_hp = hero_hp
		spawn_floating_number("小Boss战备战：状态回满！", false, hero_sprite.global_position + Vector2(0, -120), Color.GREEN)
	hero_hp_bar.max_value = GameManager.max_player_hp
	hero_hp_bar.value = hero_hp
	
	# 4. 初始化敌人数据 - 根据 GameManager 的战斗类型标记选择
	var battle_type = GameManager.get_meta("next_battle_type", "normal")
	GameManager.remove_meta("next_battle_type")
	
	var enemy: Dictionary
	if battle_type == "boss":
		enemy = GameManager.get_random_boss_enemy()
	elif battle_type == "elite":
		enemy = GameManager.get_random_elite_enemy()
	else:
		enemy = GameManager.get_random_normal_enemy()
	
	# 设置敌人名称样式
	enemy_name_label.add_theme_font_size_override("font_size", 34 * _scale_factor)
	enemy_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# 设置敌人血条样式
	var hp_bg_style = StyleBoxFlat.new()
	hp_bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.6)
	hp_bg_style.border_width_left = 2
	hp_bg_style.border_width_top = 3
	hp_bg_style.border_width_right = 2
	hp_bg_style.border_width_bottom = 3
	hp_bg_style.border_color = Color(1, 1, 1, 0.35)
	hp_bg_style.set_corner_radius_all(5)
	enemy_hp_bar.add_theme_stylebox_override("background", hp_bg_style)
	
	var hp_fill_style = StyleBoxFlat.new()
	hp_fill_style.bg_color = Color(0.8, 0.2, 0.2, 1)
	hp_fill_style.set_corner_radius_all(5)
	enemy_hp_bar.add_theme_stylebox_override("fill", hp_fill_style)
	
	enemy_hp_bar.custom_minimum_size = Vector2(10, 36)
	enemy_hp_bar.show_percentage = false
	
	enemy_name_label.text = enemy.name
	enemy_hp = enemy.hp
	enemy_hp_bar.max_value = enemy.hp
	enemy_hp_bar.value = enemy_hp
	# 初始化意图显示
	_update_enemy_intent()
	%BossSprite.texture = load(enemy.image)
	if %BossSprite.has_method("set_enemy_name"):
		%BossSprite.set_enemy_name(enemy.name)
	if "九头蛇" in enemy.name:
		hydra_heads = 3
		hydra_head_hp = int(ceil(enemy.hp / 3.0))
	if "刺猬" in enemy.name:
		hedgehog_init()
	_init_enemy_action_deck(enemy.name)
	_roll_next_enemy_action(false)
	_update_enemy_intent()
	
	# 4.1 事件影响
	enemy_damage_bonus = GameManager.next_battle_enemy_damage_bonus
	player_damage_multiplier = GameManager.next_battle_damage_multiplier
	GameManager.next_battle_enemy_damage_bonus = 0
	GameManager.next_battle_damage_multiplier = 1.0
	
	# 初始 AP
	current_ap = GameManager.max_ap
	
	# 应用局外升级：特殊类
	_apply_meta_upgrades_special()
	
	# 5. 初始化数值 UI
	update_ui_values()
	
	# 5. 初始化战斗牌堆
	draw_pile = GameManager.player_deck.duplicate()
	draw_pile.shuffle()
	
	# 7. 初始抽牌
	for i in range(5):
		draw_card()
	# 局外升级：斜杠青年 - 每关额外抽 1 张随机角色专属牌
	var meta_for_slash = get_node_or_null("/root/MetaProgressManager")
	if meta_for_slash and meta_for_slash.has_upgrade("sp_slash"):
		if GameManager.selected_hero and GameManager.selected_hero.card_pool.size() > 0:
			var pool = GameManager.selected_hero.card_pool
			var bonus_card_data = pool[randi() % pool.size()].duplicate()
			draw_card(bonus_card_data)
			spawn_floating_number("斜杠青年!", false, hero_sprite.global_position + Vector2(0, -120), Color.PURPLE)
	if GameManager.start_battle_discard_random_hand and hand_cards.size() > 0:
		var idx = randi() % hand_cards.size()
		var c = hand_cards[idx]
		hand_cards.remove_at(idx)
		c.queue_free()
		update_hand_layout()
		GameManager.start_battle_discard_random_hand = false
	
	if GameManager.start_battle_burst_damage > 0:
		apply_damage_to_enemy(GameManager.start_battle_burst_damage)
		GameManager.start_battle_burst_damage = 0
	
	if GameManager.skip_next_battle:
		GameManager.skip_next_battle = false
		GameManager.skip_rewards_battles = max(1, GameManager.skip_rewards_battles)
		show_victory()
		return
	
	# 8. 添加返回按钮与牌库按钮
	_setup_battle_ui_buttons()
	_setup_hero_status_display()
	_setup_intent_card()

func _setup_intent_card():
	var sf_yige = _scale_factor
	var screen_w = get_viewport_rect().size.x
	
	# 卡片整体尺寸和位置
	var card_w = 270.0 * sf_yige
	var card_h = 360.0 * sf_yige
	var margin = 20.0
	
	intent_card.set_anchors_preset(Control.PRESET_TOP_LEFT)
	intent_card.position = Vector2(screen_w - card_w - margin, 280.0 * sf_yige)
	intent_card.custom_minimum_size = Vector2(card_w, card_h)
	
	# ValueContainer（左上角的红色数值圆圈）
	var val_size = 60.0 * sf_yige
	var value_container = intent_card.get_node("ValueContainer")
	value_container.offset_left   = -val_size / 2
	value_container.offset_top    = -val_size / 2
	value_container.offset_right  =  val_size / 2
	value_container.offset_bottom =  val_size / 2
	
	# 字体大小
	intent_card.get_node("VBox/Title").add_theme_font_size_override("font_size", int(26 * sf_yige))
	intent_icon.add_theme_font_size_override("font_size", int(64 * sf_yige))
	intent_description.add_theme_font_size_override("font_size", int(26 * sf_yige))
	intent_text.add_theme_font_size_override("font_size", int(26 * sf_yige))
	intent_description.custom_minimum_size = Vector2(card_w - 20, 0)

func _setup_hero_status_display():
	# HeroStatusSmall 位置和尺寸
	var hs = $BottomArea/StatusBar/HeroStatusSmall
	hs.offset_left   = 20.0
	hs.offset_top    = -30.0 * _scale_factor + 40
	hs.offset_right  = 480.0 * _scale_factor
	hs.offset_bottom = 50.0 * _scale_factor + 40
	# hs.postion = Vector2(0, 1) # 锚点在底部
	# 头像大小
	hero_sprite.custom_minimum_size = Vector2(150 * _scale_factor, 150 * _scale_factor)

	# 名字字体
	hero_name_label.add_theme_font_size_override("font_size", int(30 * _scale_factor))

	# 血条尺寸
	hero_hp_bar.custom_minimum_size = Vector2(280 * _scale_factor, 40 * _scale_factor)

func _setup_battle_ui_buttons():
	var sf = _scale_factor
	var btn_w = 220.0 * sf
	var btn_h = 70.0 * sf
	var margin = 12.0
	var gap = 8.0
	
	# 创建通用按钮样式
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
	end_turn_button.custom_minimum_size = Vector2(btn_w, 80 * sf)
	end_turn_button.add_theme_font_size_override("font_size", int(36 * sf))
	
	# 胜利/失败界面的按钮也统一样式并修复焦点边框
	for btn in [next_level_button, restart_button]:
		btn.add_theme_stylebox_override("normal", style_normal)
		btn.add_theme_stylebox_override("hover", style_hover)
		btn.add_theme_stylebox_override("pressed", style_pressed)
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_color_override("font_color", Color.WHITE)
	
	next_level_button.pressed.connect(_on_next_level_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	
	# ── 左上角：放弃挑战 ──
	var back_btn = Button.new()
	back_btn.text = " ↩ 放弃挑战 "
	back_btn.name = "AbandonButton"
	back_btn.custom_minimum_size = Vector2(btn_w, btn_h)
	back_btn.position = Vector2(margin, margin)
	
	var back_style_normal = _create_style("#fdf5e6", 15, 2)
	var back_style_hover = _create_style("#ff6b6b", 15, 4)
	var back_style_pressed = _create_style("#c0392b", 15, 0)
	
	back_btn.add_theme_stylebox_override("normal", back_style_normal)
	back_btn.add_theme_stylebox_override("hover", back_style_hover)
	back_btn.add_theme_stylebox_override("pressed", back_style_pressed)
	back_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	back_btn.focus_mode = Control.FOCUS_NONE
	back_btn.add_theme_color_override("font_color", Color("#4a4a4a"))
	back_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	back_btn.add_theme_font_size_override("font_size", 30 * sf)
	
	back_btn.pressed.connect(func():
		var dialog = ConfirmationDialog.new()
		dialog.title = "确认放弃？"
		dialog.dialog_text = "当前的离职进度将会丢失，确定要返回主菜单吗？"
		dialog.ok_button_text = "确定"
		dialog.cancel_button_text = "点错了"
		dialog.get_label().add_theme_font_size_override("font_size", 26 * sf)
		dialog.get_ok_button().add_theme_font_size_override("font_size", 24 * sf)
		dialog.get_cancel_button().add_theme_font_size_override("font_size", 24 * sf)
		add_child(dialog)
		GameManager.popup_confirm_dialog(dialog)
		dialog.confirmed.connect(func():
			get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
		)
	)
	add_child(back_btn)
	
	# ── 左上角：查看牌库（放弃挑战正下方）──
	var deck_btn = Button.new()
	deck_btn.text = " 🗃️ 查看牌库 "
	deck_btn.name = "DeckButton"
	deck_btn.custom_minimum_size = Vector2(btn_w, btn_h)
	deck_btn.position = Vector2(margin, margin + btn_h + gap)
	
	deck_btn.add_theme_stylebox_override("normal", _create_style("#fdf5e6", 15, 2))
	deck_btn.add_theme_stylebox_override("hover", _create_style("#8fb9aa", 15, 4))
	deck_btn.add_theme_stylebox_override("pressed", _create_style("#7aa899", 15, 0))
	deck_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	deck_btn.focus_mode = Control.FOCUS_NONE
	deck_btn.add_theme_color_override("font_color", Color("#4a4a4a"))
	deck_btn.add_theme_font_size_override("font_size", 30 * sf)
	
	deck_btn.pressed.connect(func(): GameManager.show_deck_viewer(self))
	add_child(deck_btn)
	
	# ── 右上角：连招一览 ──
	var screen_w = get_viewport_rect().size.x
	if has_node("%ComboDirectoryButton"):
		var combo_btn = %ComboDirectoryButton
		combo_btn.custom_minimum_size = Vector2(btn_w, btn_h)
		combo_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
		combo_btn.position = Vector2(screen_w - btn_w - margin, margin)
		combo_btn.text = " 📜 连招一览"
		combo_btn.add_theme_stylebox_override("normal", _create_style("#fdf5e6", 15, 8))
		combo_btn.add_theme_stylebox_override("hover", _create_style("#a8d8ea", 15, 12))
		combo_btn.add_theme_stylebox_override("pressed", _create_style("#7fb5c9", 15, 0))
		combo_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		combo_btn.focus_mode = Control.FOCUS_NONE
		combo_btn.add_theme_color_override("font_color", Color("#4a4a4a"))
		combo_btn.add_theme_font_size_override("font_size", int(28 * sf))
		combo_btn.pressed.connect(show_combo_directory)
	
	# ── 右上角：敌方卡组（连招一览正下方）──
	var enemy_deck_btn = Button.new()
	enemy_deck_btn.text = " 🧾 敌方卡组 "
	enemy_deck_btn.name = "EnemyDeckButton"
	enemy_deck_btn.custom_minimum_size = Vector2(btn_w, btn_h)
	enemy_deck_btn.position = Vector2(screen_w - btn_w - margin, margin + btn_h + gap)
	
	enemy_deck_btn.add_theme_stylebox_override("normal", _create_style("#fdf5e6", 15, 2))
	enemy_deck_btn.add_theme_stylebox_override("hover", _create_style("#8fb9aa", 15, 4))
	enemy_deck_btn.add_theme_stylebox_override("pressed", _create_style("#7aa899", 15, 0))
	enemy_deck_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	enemy_deck_btn.focus_mode = Control.FOCUS_NONE
	enemy_deck_btn.add_theme_color_override("font_color", Color("#4a4a4a"))
	enemy_deck_btn.add_theme_font_size_override("font_size", 30 * sf)
	
	enemy_deck_btn.pressed.connect(_show_enemy_deck_viewer)
	add_child(enemy_deck_btn)

func update_ui_values():
	hero_hp_bar.value = hero_hp
	enemy_hp_bar.value = enemy_hp
	_ensure_hp_label(hero_hp_bar, "HeroHpValueLabel", hero_hp, Color.WHITE)
	_ensure_hp_label(enemy_hp_bar, "EnemyHpValueLabel", enemy_hp, Color.WHITE)
	
	# 护盾显示挂在 HeroSprite 右下角
	var shield_display = hero_sprite.get_node_or_null("ShieldDisplay")
	if not shield_display:
		shield_display = PanelContainer.new()
		shield_display.name = "ShieldDisplay"
		
		shield_display.anchor_left   = 1.0
		shield_display.anchor_top    = 1.0
		shield_display.anchor_right  = 1.0
		shield_display.anchor_bottom = 1.0
		
		var badge_w = hero_sprite.custom_minimum_size.x * 0.5
		var badge_h = hero_sprite.custom_minimum_size.y * 0.25
		shield_display.offset_left   = -badge_w
		shield_display.offset_top    = -badge_h
		shield_display.offset_right  = 0
		shield_display.offset_bottom = 0
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0, 0.6, 0.7, 0.9)
		style.set_corner_radius_all(10)
		style.content_margin_left  = 6
		style.content_margin_right = 6
		style.border_width_left = 2
		style.border_color = Color.CYAN
		shield_display.add_theme_stylebox_override("panel", style)
		
		var label = Label.new()
		label.name = "Label"
		label.add_theme_font_size_override("font_size", int(18 * _scale_factor))
		label.add_theme_color_override("font_color", Color.WHITE)
		shield_display.add_child(label)
		hero_sprite.add_child(shield_display)
	
	if hero_shield > 0:
		shield_display.get_node("Label").text = "🛡️%d" % hero_shield
		shield_display.show()
	else:
		shield_display.hide()
	
	hero_name_label.text = GameManager.selected_hero.character_name if GameManager.selected_hero else "英雄"
	energy_label.text = "摸鱼力: %d/%d" % [current_ap, GameManager.max_ap]
	
	if current_ap > GameManager.max_ap:
		energy_label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		energy_label.remove_theme_color_override("font_color")
	
	GameManager.player_hp = hero_hp
	energy_label.add_theme_font_size_override("font_size", int(32 * _scale_factor))

func _roll_compliance_rule():
	var rule_type = randi() % 2
	if rule_type == 0:
		var parity = "even" if (randi() % 2 == 0) else "odd"
		compliance_rule = {"type": "ap_parity", "value": parity}
	else:
		compliance_rule = {"type": "emoji_colors", "value": 2}
	compliance_violation_this_turn = false

func _check_compliance_violation():
	if compliance_rule.is_empty():
		return
	if compliance_rule.type == "ap_parity":
		var is_even = compliance_ap_spent_this_turn % 2 == 0
		if (compliance_rule.value == "even" and not is_even) or (compliance_rule.value == "odd" and is_even):
			compliance_violation_this_turn = true
		else:
			compliance_violation_this_turn = false
	elif compliance_rule.type == "emoji_colors":
		var colors = {}
		for card_data in cards_played_this_turn:
			var emoji = card_data.get("emoji", "")
			if emoji == "":
				continue
			var color = _get_emoji_color_group(emoji)
			# 中性色不计入“颜色种类”限制，避免误判
			if color == "white":
				continue
			colors[color] = true
		if colors.keys().size() > compliance_rule.value:
			compliance_violation_this_turn = true
		else:
			compliance_violation_this_turn = false

func _get_emoji_color_group(emoji: String) -> String:
	if emoji in ["🔥", "💣", "🧨", "🌋"]:
		return "red"
	if emoji in ["💧", "🌊", "🐙", "💨", "🌀"]:
		return "blue"
	if emoji in ["📊", "📈", "📉", "📑", "📁", "📅", "📧", "📄"]:
		return "yellow"
	return "white"


func hedgehog_init():
	hedgehog_turns_left = 3
	hedgehog_combo_met = false

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

func _apply_meta_upgrades_special():
	var meta = get_node_or_null("/root/MetaProgressManager")
	if not meta:
		return
	
	# 策略类升级
	if meta.has_upgrade("fish_first"):
		GameManager.first_card_free = true
	
	if meta.has_upgrade("def_shield"):
		hero_shield = 5
	
	if meta.has_upgrade("dot_start"):
		enemy_poison_stacks = 1
	
	# 特殊类升级
	if meta.has_upgrade("sp_yolo"):
		hero_hp = int(hero_hp * 0.5)
		GameManager.player_hp = hero_hp
		player_damage_multiplier *= 2.0

func _on_restart_pressed():
	GameManager.is_tutorial_mode = false
	GameManager.reset_run()
	GameManager.load_current_level_scene()

func _on_next_level_pressed():
	next_level_button.disabled = true
	GameManager.advance_level()

func _create_style(color_hex: String, radius: int, shadow: int) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(color_hex)
	sb.set_corner_radius_all(radius)
	sb.shadow_size = shadow
	sb.shadow_offset = Vector2(0, shadow / 2.0)
	sb.border_width_bottom = 2
	sb.border_color = Color(0, 0, 0, 0.1)
	return sb

func _on_end_turn_pressed():
	end_turn_button.disabled = true
	# Boomtail 核爆倒计时：回合结束时爆炸
	if has_meta("bomb_timer_active"):
		remove_meta("bomb_timer_active")
		var marks = get_meta("bomb_marks", 0)
		if marks > 0:
			var bomb_dmg = marks * 20
			apply_damage_to_enemy(bomb_dmg)
			remove_meta("bomb_marks")
			spawn_floating_number("💥 BOOM x%d = %d!" % [marks, bomb_dmg], true, %BossSprite.global_position + Vector2(0, -100), Color.ORANGE_RED)
			await get_tree().create_timer(0.5).timeout
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
	battle_turn_count += 1
	# 处理中毒伤害
	if enemy_poison_stacks > 0:
		print("中毒发作：造成 %d 点伤害" % enemy_poison_stacks)
		apply_damage_to_enemy(enemy_poison_stacks)
		enemy_poison_stacks = max(0, enemy_poison_stacks - 1)
		update_status_display()
		await get_tree().create_timer(0.4).timeout

	# 苏珊终极进化：黑名单逻辑（限时3回合）
	if has_meta("boss_blacklisted"):
		var turns_left = get_meta("blacklist_turns", 1)
		turns_left -= 1
		var penalty = 20 # 每回合违约金
		apply_damage_to_enemy(penalty)
		if turns_left <= 0:
			# 封印到期，解除黑名单
			remove_meta("boss_blacklisted")
			if has_meta("blacklist_turns"): remove_meta("blacklist_turns")
			spawn_floating_number("黑名单到期！违约金: %d" % penalty, true, %BossSprite.global_position, Color.DARK_ORANGE)
			_update_enemy_intent()
		else:
			set_meta("blacklist_turns", turns_left)
			spawn_floating_number("违约金: %d (剩余%d回合)" % [penalty, turns_left], false, %BossSprite.global_position, Color.BLACK)
			# 更新意图显示剩余回合
			intent_text.text = "封印(%d回合)" % turns_left
		await get_tree().create_timer(0.8).timeout
		start_player_turn()
		return

	if has_meta("skip_next_intent"):
		remove_meta("skip_next_intent")
		intent_icon.text = "💤"
		intent_text.text = "继续发呆..."
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
	
	# 根据“敌方行动卡”决定演出动画
	var anim_type = _get_enemy_anim_type(enemy_name)
	if %BossSprite.has_method("play_" + anim_type):
		%BossSprite.call("play_" + anim_type)
	else:
		%BossSprite.play_attack()
	
	await get_tree().create_timer(0.5).timeout
	
	# 根据敌人类型执行不同行为
	if "审计" in enemy_name:
		if compliance_violation_this_turn:
			spawn_floating_number("审计未通过：追加追责", true, hero_sprite.global_position + Vector2(0, -100), Color.RED)
			await get_tree().create_timer(0.6).timeout
			apply_damage_to_hero(16 + enemy_damage_bonus)
		else:
			apply_damage_to_hero(10 + enemy_damage_bonus)
		print("审计猎犬发动了合规审查...")
	elif "鹦鹉" in enemy_name:
		# 鹦鹉机制已移至玩家回合开始时的“复读干扰”
		apply_damage_to_hero(12 + enemy_damage_bonus)
		print("鹦鹉发动了普通攻击...")
	elif "浣熊" in enemy_name:
		# 薪水小偷浣熊：偷走序列槽中的 Emoji
		if current_sequence.size() > 0:
			var stolen_idx = randi() % current_sequence.size()
			var stolen_emoji = current_sequence[stolen_idx]
			current_sequence.remove_at(stolen_idx)
			spawn_floating_number("偷走了 %s!" % stolen_emoji, false, %BossSprite.global_position + Vector2(0, -120), Color.GOLD)
			_update_sequence_display()
		apply_damage_to_hero(14 + enemy_damage_bonus)
		print("薪水小偷浣熊顺手牵羊...")
	elif "刺猬" in enemy_name:
		if hedgehog_turns_left <= 1:
			if not hedgehog_combo_met:
				spawn_floating_number("DEADLINE!", true, %BossSprite.global_position + Vector2(0, -120), Color.RED)
				apply_pure_damage_to_hero(15) # 进一步降低死线伤害
				hedgehog_init()
			else:
				hedgehog_init()
		else:
			hedgehog_turns_left -= 1
			print("刺猬发动连击！")
			for i in range(3):
				apply_damage_to_hero(4 + enemy_damage_bonus) # 降低连击伤害
				await get_tree().create_timer(0.2).timeout
	elif "鲶鱼" in enemy_name:
		# 老油条鲶鱼：每回合首次受伤减半，然后回血并塞废话
		catfish_slipped_this_turn = false  # 重置滑溜状态
		var heal = 6
		enemy_hp = min(enemy_hp_bar.max_value, enemy_hp + heal)
		spawn_floating_number("摸鱼回血 +%d" % heal, false, %BossSprite.global_position + Vector2(0, -120), Color.GREEN)
		inject_junk_card("rambling")
		apply_damage_to_hero(8 + enemy_damage_bonus)
		print("老油条鲶鱼回血并塞入【废话连篇】...")
	elif "螃蟹" in enemy_name:
		# 打印机螃蟹：持续塞卡纸，每3张触发爆发
		inject_junk_card("printer_jam")
		crab_jammed_count += 1
		
		if crab_jammed_count >= 3:
			var burst = 25 + enemy_damage_bonus
			apply_damage_to_hero(burst)
			spawn_floating_number("卡纸爆发！", true, %BossSprite.global_position + Vector2(0, -120), Color.RED)
			crab_jammed_count = 0  # 重置计数
		else:
			apply_damage_to_hero(10 + enemy_damage_bonus)
		
		spawn_floating_number("卡纸 x%d" % crab_jammed_count, false, %BossSprite.global_position + Vector2(0, -80), Color.ORANGE)
		print("打印机螃蟹塞入【打印机卡纸】...")
	elif "摸鱼猫主管" in enemy_name:
		if supervisor_sleeping:
			supervisor_sleeping = false  # 清醒过来
			spawn_floating_number("清醒了！", false, %BossSprite.global_position + Vector2(0, -120), Color.CYAN)
			print("摸鱼猫主管清醒，准备下回合攻击。")
		else:
			# 检测玩家是否使用了摸鱼卡（☕💩💤💧等）
			var slacking_detected = false
			for card_data in cards_played_this_turn:
				if card_data.get("emoji", "") in ["☕", "💩", "💤", "💧"]:
					slacking_detected = true
					break
			
			if slacking_detected:
				var cat_damage = 22 + enemy_damage_bonus
				spawn_floating_number("抓包摸鱼！惩罚加倍！", true, %BossSprite.global_position + Vector2(0, -120), Color.RED)
				apply_damage_to_hero(cat_damage)
			else:
				apply_damage_to_hero(14 + enemy_damage_bonus)
			print("摸鱼猫主管抓包施压...")
	elif "树懒" in enemy_name:
		# 会议树懒：持续塞垃圾文件，手牌越多伤害越高
		var base_damage = 12 + enemy_damage_bonus
		if hand_cards.size() >= 7:
			base_damage += 6
			spawn_floating_number("文件堆积！", true, hero_sprite.global_position + Vector2(0, -100), Color.ORANGE)
		apply_damage_to_hero(base_damage)
		inject_junk_card("meeting")
		print("树懒塞入了【无意义早会】...")
	elif "镰鼬" in enemy_name:
		# 裁员镰鼬：威胁性削减手牌和牌库
		var cut_damage = 18 + enemy_damage_bonus
		var cards_in_hand = hand_cards.size()
		
		if cards_in_hand >= 6:
			cut_damage += 10
			spawn_floating_number("裁员名单超员！", true, hero_sprite.global_position + Vector2(0, -100), Color.RED)
		
		apply_damage_to_hero(cut_damage)
		
		# 裁掉1张手牌
		if cards_in_hand > 0:
			var idx = randi() % cards_in_hand
			var removed = hand_cards[idx]
			hand_cards.remove_at(idx)
			removed.queue_free()
			update_hand_layout()
			spawn_floating_number("裁掉1张手牌", false, %BossSprite.global_position + Vector2(0, -120), Color.ORANGE)
		
		# 每3回合还会裁掉牌库中的一张牌
		if battle_turn_count % 3 == 0 and draw_pile.size() > 0:
			draw_pile.remove_at(randi() % draw_pile.size())
			spawn_floating_number("牌库裁员！", false, %BossSprite.global_position + Vector2(0, -100), Color.DARK_RED)
	elif "鲸" in enemy_name:
		# 年终总结鲸：根据玩家出牌数量累计考核压力
		var whale_damage = 14 + enemy_damage_bonus + whale_review_pressure * 2
		apply_damage_to_hero(whale_damage)
		
		if whale_review_pressure >= 5:
			inject_junk_card("kpi")
			spawn_floating_number("总结超载：塞入KPI！", true, %BossSprite.global_position + Vector2(0, -120), Color.GOLD)
		
		spawn_floating_number("考核压力: %d" % whale_review_pressure, false, %BossSprite.global_position + Vector2(0, -80), Color.YELLOW)
		whale_review_pressure = 0  # 重置压力值
	elif "秃鹫" in enemy_name:
		# 外包秃鹫：逐步压低 AP，还会削弱卡牌效果
		vulture_outsource_stacks += 1
		apply_damage_to_hero(20 + enemy_damage_bonus)
		
		# 每2层外包，强制将一张手牌降级（随机减少其效果值）
		if vulture_outsource_stacks % 2 == 0 and hand_cards.size() > 0:
			var target_idx = randi() % hand_cards.size()
			var target_card = hand_cards[target_idx]
			if target_card.card_data.has("value") and target_card.card_data.value > 0:
				target_card.card_data.value = max(1, target_card.card_data.value - 3)
				spawn_floating_number("外包替代：削弱手牌！", false, %BossSprite.global_position + Vector2(0, -120), Color.DARK_ORANGE)
		
		spawn_floating_number("外包层数 x%d" % vulture_outsource_stacks, false, %BossSprite.global_position + Vector2(0, -80), Color.ORANGE)
	elif "蜘蛛" in enemy_name:
		# 画饼蜘蛛：持续编织虚假目标，越往后越强
		var spider_damage = 16 + enemy_damage_bonus + (battle_turn_count * 2)
		apply_damage_to_hero(spider_damage)
		inject_junk_card("goal")
		
		# 每4回合触发一次"大画饼"：塞入2张虚假目标
		if battle_turn_count % 4 == 0:
			inject_junk_card("goal")
			spawn_floating_number("大饼！双倍虚假目标！", true, %BossSprite.global_position + Vector2(0, -120), Color.PURPLE)
		
		print("画饼蜘蛛编织了【虚假目标】...")
	elif "鲶鱼" in enemy_name:
		var heal = 6
		enemy_hp = min(enemy_hp_bar.max_value, enemy_hp + heal)
		spawn_floating_number("摸鱼回血 +%d" % heal, false, %BossSprite.global_position + Vector2(0, -120), Color.GREEN)
		inject_junk_card("rambling")
		apply_damage_to_hero(8 + enemy_damage_bonus)
		print("老油条鲶鱼回血并塞入【废话连篇】...")
	elif "螃蟹" in enemy_name:
		inject_junk_card("printer_jam")
		printer_jam_cards_added += 1
		apply_damage_to_hero(10 + enemy_damage_bonus)
		if printer_jam_cards_added % 3 == 0:
			spawn_floating_number("卡纸爆发!", true, hero_sprite.global_position + Vector2(0, -100), Color.ORANGE_RED)
			apply_damage_to_hero(8 + enemy_damage_bonus)
		print("打印机螃蟹塞入【打印机卡纸】...")
	elif "摸鱼猫主管" in enemy_name:
		if supervisor_sleeping:
			spawn_floating_number("打盹中...", false, %BossSprite.global_position + Vector2(0, -120), Color.CYAN)
			print("摸鱼猫主管正在打盹，本回合不攻击。")
		else:
			var cat_damage = 16 + enemy_damage_bonus
			if has_meta("supervisor_woke_angry"):
				cat_damage += 10
				remove_meta("supervisor_woke_angry")
				spawn_floating_number("醒后恼羞成怒!", true, %BossSprite.global_position + Vector2(0, -120), Color.RED)
			apply_damage_to_hero(cat_damage)
			print("摸鱼猫主管抓包施压...")
	elif "野猪" in enemy_name:
		if battle_turn_count % 3 == 0:
			spawn_floating_number("冲锋KPI!", true, %BossSprite.global_position + Vector2(0, -120), Color.RED)
			apply_damage_to_hero(28 + enemy_damage_bonus)
			inject_junk_card("kpi")
		else:
			var boar_damage = 14 + enemy_damage_bonus
			if boar_phase_two:
				boar_damage += 6
			apply_damage_to_hero(boar_damage)
			print("部门经理野猪持续施压...")
	elif "树懒" in enemy_name:
		apply_damage_to_hero(12 + enemy_damage_bonus)
		print("树懒塞入了垃圾卡...")
		inject_junk_card("meeting")
	elif "监控猿" in enemy_name:
		if monkey_surveillance_stacks >= 4:
			monkey_locked_emoji_slot = true
			spawn_floating_number("锁定槽位!", false, %BossSprite.global_position + Vector2(0, -120), Color.PURPLE)
		apply_damage_to_hero(18 + enemy_damage_bonus)
		print("监控猿正在严密监控...")
	elif "镰鼬" in enemy_name:
		var cut_damage = 18 + enemy_damage_bonus
		if hand_cards.size() >= 5:
			cut_damage += 8
			spawn_floating_number("裁员名单命中!", true, hero_sprite.global_position + Vector2(0, -100), Color.RED)
		apply_damage_to_hero(cut_damage)
		if hand_cards.size() > 0:
			var idx = randi() % hand_cards.size()
			var removed = hand_cards[idx]
			hand_cards.remove_at(idx)
			removed.queue_free()
			update_hand_layout()
			spawn_floating_number("裁掉1张手牌", false, %BossSprite.global_position + Vector2(0, -120), Color.ORANGE)
	elif "鲸" in enemy_name:
		var whale_damage = 14 + enemy_damage_bonus + whale_review_pressure
		apply_damage_to_hero(whale_damage)
		if whale_review_pressure >= 6:
			inject_junk_card("kpi")
			spawn_floating_number("总结超载：KPI!", true, %BossSprite.global_position + Vector2(0, -120), Color.GOLD)
		whale_review_pressure = 0
	elif "秃鹫" in enemy_name:
		vulture_outsource_stacks += 1
		apply_damage_to_hero(20 + enemy_damage_bonus)
		if draw_pile.size() > 0:
			draw_pile.shuffle()
		spawn_floating_number("外包替代 x%d" % vulture_outsource_stacks, false, %BossSprite.global_position + Vector2(0, -120), Color.DARK_ORANGE)
	elif "蜘蛛" in enemy_name:
		print("画饼蜘蛛发动了【虚假目标】！")
		apply_damage_to_hero(20 + enemy_damage_bonus)
		inject_junk_card("goal")
	elif "九头蛇" in enemy_name:
		# KPI 九头蛇：多头回血机制
		if hydra_head_damage_this_turn < hydra_head_hp:
			var heal = 40
			enemy_hp = min(enemy_hp_bar.max_value, enemy_hp + heal)
			spawn_floating_number("指标未达成：回血", false, %BossSprite.global_position + Vector2(0, -120), Color.GREEN)
		else:
			spawn_floating_number("击破一个指标！", false, %BossSprite.global_position + Vector2(0, -120), Color.GOLD)
			hydra_heads -= 1
		apply_damage_to_hero(25 + enemy_damage_bonus)
	elif "CEO" in enemy_name:
		# CEO：三阶段状态切换
		var state_roll = randi() % 3
		if state_roll == 0:
			set_meta("ceo_state", "lion") # 狮态：锁攻击
			spawn_floating_number("【狮态】：严厉考核", false, %BossSprite.global_position + Vector2(0, -120), Color.RED)
		elif state_roll == 1:
			set_meta("ceo_state", "sheep") # 羊态：伤上限
			spawn_floating_number("【羊态】：温水青蛙", false, %BossSprite.global_position + Vector2(0, -120), Color.WHITE)
		else:
			set_meta("ceo_state", "snake") # 蛇态：AP 封印
			set_meta("ceo_snake_seal", true)
			spawn_floating_number("【蛇态】：摸鱼力封印！", false, %BossSprite.global_position + Vector2(0, -120), Color.PURPLE)
		
		apply_damage_to_hero(35 + enemy_damage_bonus)
		inject_junk_card("kpi")
	else:
		var damage = 5 + (GameManager.current_level * 2) + enemy_damage_bonus
		# 应用攻击削减
		damage = max(0, damage - enemy_atk_reduction)
		enemy_atk_reduction = 0 # 重置
		apply_damage_to_hero(damage)
	
	if hero_hp <= 0:
		show_game_over()
		return

	_roll_next_enemy_action()
		
	start_player_turn()

# 根据敌人当前回合意图类型决定播放哪种动画
func _get_enemy_anim_type(enemy_name: String) -> String:
	if not current_enemy_action.is_empty() and current_enemy_action.has("anim"):
		return current_enemy_action.anim

	# 审计犬：规则审查属于技能演出
	if "审计" in enemy_name:
		return "special"
	# 树懒/蜘蛛：塞垃圾卡 → 特殊
	if "树懒" in enemy_name or "蜘蛛" in enemy_name:
		return "special"
	# 九头蛇：回血时先蓄力
	if "九头蛇" in enemy_name:
		if hydra_head_damage_this_turn < hydra_head_hp:
			return "charge"
		else:
			return "attack"
	# 毒蛇：反转回血 → 特殊
	if "毒蛇" in enemy_name:
		return "special"
	# 刺猬倒计时：最后回合爆发
	if "刺猬" in enemy_name:
		if hedgehog_turns_left <= 1:
			return "enrage"
		else:
			return "attack"
	# CEO：每回合切形态，属于技能演出；低血量用狂暴
	if "CEO" in enemy_name:
		if enemy_hp < enemy_hp_bar.max_value * 0.4:
			return "enrage"
		return "special"
	# 监控猿/浣熊/鹦鹉：当前回合仅执行普通攻击（其机制在其他时机触发）
	if "监控" in enemy_name or "浣熊" in enemy_name or "鹦鹉" in enemy_name:
		return "attack"
	return "attack"


func _init_enemy_action_deck(enemy_name: String) -> void:
	enemy_action_deck.clear()
	enemy_action_index = 0

	if "CEO" in enemy_name:
		enemy_action_deck = [
			{"name":"KPI 考核", "type":"skill", "anim":"special", "icon":"📉", "text":"35", "desc":"技能：造成重压并切换形态"},
			{"name":"高压追击", "type":"normal", "anim":"attack", "icon":"⚔️", "text":"35", "desc":"普攻：直接造成伤害"},
			{"name":"管理威压", "type":"skill", "anim":"enrage", "icon":"👑", "text":"35", "desc":"技能：低血量更易进入狂暴演出"}
		]
	elif "九头蛇" in enemy_name:
		enemy_action_deck = [
			{"name":"多头撕咬", "type":"normal", "anim":"attack", "icon":"⚔️", "text":"25", "desc":"普攻：多头集火"},
			{"name":"指标再生", "type":"skill", "anim":"charge", "icon":"🐲", "text":"25", "desc":"技能：未击破指标则回血"}
		]
	elif "树懒" in enemy_name:
		enemy_action_deck = [
			{"name":"流程压制", "type":"skill", "anim":"special", "icon":"📄", "text":"技能", "desc":"技能：塞入【无意义文档】并施压"},
			{"name":"普通施压", "type":"normal", "anim":"attack", "icon":"⚔️", "text":"攻击", "desc":"普攻：直接造成伤害"}
		]
	elif "蜘蛛" in enemy_name:
		enemy_action_deck = [
			{"name":"虚假目标", "type":"skill", "anim":"special", "icon":"🕸️", "text":"技能", "desc":"技能：塞入【虚假目标】扰乱抽牌"},
			{"name":"普通施压", "type":"normal", "anim":"attack", "icon":"⚔️", "text":"攻击", "desc":"普攻：直接造成伤害"}
		]
	elif "审计" in enemy_name:
		enemy_action_deck = [
			{"name":"合规审查", "type":"skill", "anim":"special", "icon":"🔍", "text":"技能", "desc":"技能：发布规则并在违规时追加伤害"},
			{"name":"普通施压", "type":"normal", "anim":"attack", "icon":"⚔️", "text":"攻击", "desc":"普攻：直接造成伤害"}
		]
	elif "毒蛇" in enemy_name:
		enemy_action_deck = [
			{"name":"认知反转", "type":"skill", "anim":"special", "icon":"🐍", "text":"技能", "desc":"技能：将回血/减压效果反转"},
			{"name":"普通施压", "type":"normal", "anim":"attack", "icon":"⚔️", "text":"攻击", "desc":"普攻：直接造成伤害"}
		]
	elif "鹦鹉" in enemy_name:
		enemy_action_deck = [
			{"name":"复读干扰", "type":"skill", "anim":"special", "icon":"🦜", "text":"技能", "desc":"技能：复读上回合符号干扰序列"},
			{"name":"普通施压", "type":"normal", "anim":"attack", "icon":"⚔️", "text":"攻击", "desc":"普攻：直接造成伤害"}
		]
	elif "浣熊" in enemy_name:
		enemy_action_deck = [
			{"name":"顺手牵羊", "type":"skill", "anim":"special", "icon":"🦝", "text":"技能", "desc":"技能：有概率偷走你序列中的 Emoji"},
			{"name":"普通施压", "type":"normal", "anim":"attack", "icon":"⚔️", "text":"攻击", "desc":"普攻：直接造成伤害"}
		]
	elif "监控猿" in enemy_name:
		enemy_action_deck = [
			{"name":"监控蓄力", "type":"skill", "anim":"special", "icon":"👁️", "text":"技能", "desc":"技能：根据你出牌逐步蓄力"},
			{"name":"普通施压", "type":"normal", "anim":"attack", "icon":"⚔️", "text":"攻击", "desc":"普攻：直接造成伤害"}
		]
	elif "刺猬" in enemy_name:
		enemy_action_deck = [
			{"name":"死线倒计时", "type":"skill", "anim":"enrage", "icon":"⏰", "text":"技能", "desc":"技能：限时内未达标将触发高伤惩罚"},
			{"name":"普通施压", "type":"normal", "anim":"attack", "icon":"⚔️", "text":"攻击", "desc":"普攻：连续造成伤害"}
		]
	else:
		enemy_action_deck = [
			{"name":"流程压制", "type":"skill", "anim":"special", "icon":"✨", "text":"技能", "desc":"技能：带额外机制（塞卡/规则/反转）"},
			{"name":"普通施压", "type":"normal", "anim":"attack", "icon":"⚔️", "text":"攻击", "desc":"普攻：直接造成伤害"}
		]


func _roll_next_enemy_action(advance: bool = true) -> void:
	if enemy_action_deck.is_empty():
		current_enemy_action = {"name":"普通攻击", "type":"normal", "anim":"attack", "icon":"⚔️", "text":"攻击", "desc":"普攻"}
		return
	if advance:
		enemy_action_index += 1
	var idx = posmod(enemy_action_index, enemy_action_deck.size())
	current_enemy_action = enemy_action_deck[idx]


func _show_enemy_deck_viewer() -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "敌方卡组"
	dialog.ok_button_text = "关闭"
	dialog.dialog_text = ""
	dialog.min_size = Vector2i(680, 460)
	add_child(dialog)

	var text = RichTextLabel.new()
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text.offset_left = 16
	text.offset_top = 16
	text.offset_right = -16
	text.offset_bottom = -56
	text.bbcode_enabled = true
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.scroll_active = true
	text.add_theme_font_size_override("normal_font_size", 20)
	text.add_theme_font_size_override("bold_font_size", 22)

	var s = "[b]当前敌人：%s[/b]\n\n" % enemy_name_label.text
	for i in range(enemy_action_deck.size()):
		var card = enemy_action_deck[i]
		var tag = "[普攻]" if card.get("type", "normal") == "normal" else "[技能]"
		var pointer = "  ← 下回合" if i == posmod(enemy_action_index, max(1, enemy_action_deck.size())) else ""
		s += "• %s %s  %s\n    %s%s\n\n" % [tag, card.get("name", "未知行动"), card.get("icon", ""), card.get("desc", ""), pointer]
	text.text = s
	dialog.add_child(text)
	dialog.popup_centered_ratio(0.72)

func inject_junk_card(type: String):
	var junk_data = GameManager.junk_cards.get(type)
	if not junk_data: return
	
	var new_card = card_scene.instantiate()
	new_card.card_data = junk_data.duplicate()
	hand_container.add_child(new_card)
	new_card.scale = Vector2(1.0, 1.0)  
	new_card.pivot_offset = Vector2(110, 340)
	hand_cards.append(new_card)
	update_hand_layout()

func show_game_over():
	if is_battle_over: return
	is_battle_over = true
	end_turn_button.disabled = true
	game_over_layer.visible = true

func start_player_turn():
	end_turn_button.disabled = false
	var base_ap = GameManager.max_ap
	if not battle_ap_bonus_applied:
		base_ap += GameManager.next_battle_ap_bonus
		battle_ap_bonus_applied = true
		GameManager.next_battle_ap_bonus = 0
	current_ap = int((base_ap + next_turn_extra_ap) * ap_multiplier_next_turn)
	next_turn_extra_ap = 0
	ap_multiplier_next_turn = 1.0
	poop_played_this_turn = false
	cards_played_this_turn.clear()
	compliance_ap_spent_this_turn = 0
	cost_reduction_active = false
	compliance_violation_this_turn = false
	raccoon_steal_ready = false
	hydra_head_damage_this_turn = 0
	spider_shuffle_used = false
	catfish_slipped_this_turn = false
	first_card_free_used = false
	
	var meta = get_node_or_null("/root/MetaProgressManager")
	if meta:
		# fish_hand: 手牌>6时摸鱼力+1
		if meta.has_upgrade("fish_hand") and hand_cards.size() > 6:
			current_ap += 1
		# def_retain: 护盾不清零
		if not meta.has_upgrade("def_retain"):
			hero_shield = 0
		# def_shield: 回合开始获得5点护盾
		if meta.has_upgrade("def_shield"):
			hero_shield += 5
		# sp_lazy: 回合开始回血5
		if meta.has_upgrade("sp_lazy"):
			apply_heal_to_hero(5)
	# 回合切换后失效：仅本回合生效的莱奥终极 0 费状态
	if has_meta("ultimate_vision_free_cost"):
		remove_meta("ultimate_vision_free_cost")
	if has_meta("cancel_played_this_turn"):
		remove_meta("cancel_played_this_turn")
	
	# 更新敌人意图
	_update_enemy_intent()
	var enemy_name = enemy_name_label.text
	if "审计" in enemy_name:
		_roll_compliance_rule()
		_update_enemy_intent()
	if "毒蛇" in enemy_name:
		poison_heal_inverted = true
	else:
		poison_heal_inverted = false
	if "监控猿" in enemy_name:
		monkey_surveillance_stacks = 0
		_update_enemy_intent()
	if "秃鹫" in enemy_name and vulture_outsource_stacks > 0:
		current_ap = max(0, current_ap - min(2, vulture_outsource_stacks))
		spawn_floating_number("外包压价 AP-%d" % min(2, vulture_outsource_stacks), false, hero_sprite.global_position + Vector2(0, -100), Color.DARK_ORANGE)
	
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
	if monkey_locked_emoji_slot:
		current_sequence.append("👁️")
		monkey_locked_emoji_slot = false
		spawn_floating_number("槽位被锁定!", false, %BossSprite.global_position + Vector2(0, -120), Color.PURPLE)
	
	if "鹦鹉" in enemy_name:
		if not last_player_card_data.is_empty():
			var last_emoji = last_player_card_data.get("emoji", "")
			if last_emoji != "":
				current_sequence.append(last_emoji)
				spawn_floating_number("复读: %s" % last_emoji, false, %BossSprite.global_position + Vector2(0, -120), Color.GREEN)

	update_emoji_slots()
	enemy_vulnerability = 0 # 重置敌人易伤状态
	
	if GameManager.ap_drain_per_turn > 0:
		current_ap = max(0, current_ap - GameManager.ap_drain_per_turn)
	if GameManager.hp_drain_per_turn > 0:
		apply_damage_to_hero(GameManager.hp_drain_per_turn)
	
	if has_meta("ceo_snake_seal"):
		current_ap = 0
		remove_meta("ceo_snake_seal")
		spawn_floating_number("AP 被封印！", false, hero_sprite.global_position + Vector2(0, -100), Color.PURPLE)
	
	if has_meta("ceo_state"):
		remove_meta("ceo_state")
		
	if is_waiting_next_turn:
		is_waiting_next_turn = false
		print("本回合待岗结束，保留手牌继续行动")
	elif save_hand_this_turn:
		save_hand_this_turn = false
		print("存档生效：保留手牌并补牌")
		var draw_count = (5 + next_turn_extra_draws) - hand_cards.size()
		next_turn_extra_draws = 0
		for i in range(max(0, draw_count)):
			draw_card()
	else:
		# 检查手牌中的"虚假目标"
		var draw_count = 5 + next_turn_extra_draws
		next_turn_extra_draws = 0
		
		# 局外升级：无为而治 - 回合结束保留1张手牌
		var retained_card = null
		if meta and meta.has_upgrade("fish_retain") and hand_cards.size() > 0:
			retained_card = hand_cards.pop_back()
			draw_count -= 1
		
		for card in hand_cards:
			if card.card_data.get("type") == "junk_goal":
				print("由于未打出虚假目标，本回合抽牌减少")
				draw_count -= 1
			# 回合结束手牌进弃牌堆
			discard_pile.append(card.card_data)
		
		for card in hand_cards:
			card.queue_free()
		hand_cards.clear()
		
		if retained_card:
			hand_cards.append(retained_card)
		
		for i in range(draw_count):
			draw_card()
	
	update_ui_values()
	update_status_display()

func apply_damage_to_hero(amount: int):
	var final_damage = amount
	
	if is_evading:
		if %AnimationManager:
			%AnimationManager.play_evade_anim()
		spawn_floating_number("MISS", false, hero_sprite.global_position + Vector2(0, -50), Color.CYAN)
		return
		
	if has_meta("nullify_next_enemy_attack"):
		remove_meta("nullify_next_enemy_attack")
		spawn_floating_number("NULLIFIED!", false, hero_sprite.global_position + Vector2(0, -50), Color.CYAN)
		return
	
	if %AnimationManager:
		%AnimationManager.play_player_hit_anim()
	
	# 优先扣除护盾
	var shield_blocked = false
	if hero_shield > 0:
		shield_blocked = true
		if hero_shield >= final_damage:
			hero_shield -= final_damage
			spawn_floating_number(final_damage, false, hero_sprite.global_position + Vector2(0, -50), Color.CYAN)
			final_damage = 0
		else:
			final_damage -= hero_shield
			spawn_floating_number(hero_shield, false, hero_sprite.global_position + Vector2(0, -50), Color.CYAN)
			hero_shield = 0
	# 局外升级：挡箭牌 - 护盾抵消伤害时30%概率抽一张牌
	if shield_blocked:
		var meta = get_node_or_null("/root/MetaProgressManager")
		if meta and meta.has_upgrade("def_draw") and randf() < 0.3:
			draw_card()
			spawn_floating_number("挡箭牌!", false, hero_sprite.global_position + Vector2(0, -120), Color.LIGHT_BLUE)
	
	if final_damage <= 0:
		update_ui_values()
		return

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

func apply_pure_damage_to_hero(amount: int):
	if is_evading:
		spawn_floating_number("MISS", false, hero_sprite.global_position + Vector2(0, -50), Color.CYAN)
		return
	hero_hp -= amount
	hero_hp = max(0, hero_hp)
	spawn_floating_number(amount, true, hero_sprite.global_position + Vector2(0, -50), Color.RED)
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

	# 对齐 evolution_data：莱奥终极期间，本回合抽到的牌也显示为 0 费
	if has_meta("ultimate_vision_free_cost"):
		new_card.card_data["cost"] = 0
	
	hand_container.add_child(new_card)
	new_card.scale = Vector2(1.0, 1.0)
	new_card.pivot_offset = Vector2(110, 340) 
	
	hand_cards.append(new_card)
	update_hand_layout()
	update_hand_combo_hints()
	return new_card

func update_hand_layout():
	var card_count = hand_cards.size()
	if card_count == 0: return
	var center_x = hand_container.size.x / 2.0
	var base_y = hand_container.size.y - 130.0
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
	# 注意：团建干杯（cost_reduction）的 -1 已经直接写入 card_data.cost，这里不再二次扣减
	
	# KPI 考核影响：手牌中有 KPI 卡时，Combo 卡消耗 +1
	var has_kpi = false
	for c in hand_cards:
		if c.card_data.get("type") == "junk_kpi":
			has_kpi = true
			break
	
	var emoji = data.get("emoji", "")
	if has_kpi and emoji != "" and _is_emoji_part_of_any_combo(emoji):
		cost += 1
	
	if GameManager.first_card_free and not first_card_free_used:
		cost = 0
		first_card_free_used = true

	# 局外升级：加班文化 - 每打出3张牌，下一张牌费用归零
	if _meta_burst_ot_next_free:
		cost = 0
		_meta_burst_ot_next_free = false
		spawn_floating_number("加班 0费!", false, hero_sprite.global_position + Vector2(0, -100), Color.GOLD)

	# 对齐 evolution_data：莱奥 8 级终极（ultimate_vision）= 本回合所有卡牌 0 消耗
	# 必须放在费用修正末尾，确保不被 KPI/其他修正覆写
	if has_meta("ultimate_vision_free_cost"):
		cost = 0
	
	if current_ap < cost:
		var t = create_tween()
		t.tween_property(card_node, "position:x", card_node.position.x + 10, 0.05)
		t.tween_property(card_node, "position:x", card_node.position.x - 10, 0.05)
		t.tween_property(card_node, "position:x", card_node.position.x, 0.05)
		return
	
	current_ap -= cost
	compliance_ap_spent_this_turn += cost
	if %AnimationManager.has_method("play_player_attack_anim"):
		var content = emoji
		if content == "" and data.has("image"):
			content = data.image
		%AnimationManager.play_player_attack_anim(content)
	
	var type = data.get("type", "")
	
	# CEO 狮态逻辑：非攻击卡扣血
	if has_meta("ceo_state") and get_meta("ceo_state") == "lion":
		if not type.begins_with("attack"):
			var penalty = int(GameManager.max_player_hp * 0.1)
			apply_pure_damage_to_hero(penalty)
			spawn_floating_number("违规出牌!", false, hero_sprite.global_position + Vector2(0, -100), Color.RED)
	# 特殊逻辑：文件夹配合周报
	if type == "attack_conditional_keyboard" and not cards_played_this_turn.is_empty():
		var last = cards_played_this_turn.back()
		if last.get("emoji") == "📁":
			apply_shield_to_hero(10)
			spawn_floating_number("ARCHIVED", false, hero_sprite.global_position + Vector2(0, -100), Color.CYAN)

	execute_card_effect(data)
	last_player_card_data = data
	cards_played_this_turn.append(data)
	if "鲸" in enemy_name_label.text:
		whale_review_pressure += 1

	if "审计" in enemy_name_label.text:
		_check_compliance_violation()
	
	# 局外升级：加班文化 - 每打出3张牌，下一张牌费用归零
	var meta = get_node_or_null("/root/MetaProgressManager")
	if meta and meta.has_upgrade("burst_ot"):
		_meta_burst_ot_count += 1
		if _meta_burst_ot_count >= 3:
			_meta_burst_ot_count = 0
			_meta_burst_ot_next_free = true
	
	# 局外升级：卷王附体 - 每打出5张牌触发一次额外连招检测
	if meta and meta.has_upgrade("sp_grind"):
		_meta_grind_count += 1
		if _meta_grind_count >= 5:
			_meta_grind_count = 0
			check_combos()
			spawn_floating_number("卷王连招!", false, hero_sprite.global_position + Vector2(0, -120), Color.PURPLE)
	
	# 博姆终极进化：火伤翻倍逻辑
	if _get_emoji_color_group(emoji) == "red" and has_meta("fire_multiplier"):
		# 逻辑在 apply_damage_to_enemy 中处理
		pass

	# 垃圾卡也会进入弃牌堆以持续污染牌组
	discard_pile.append(data)
	
	if emoji != "":
		current_sequence.append(emoji)
		update_emoji_slots()
		check_combos()
		if "浣熊" in enemy_name_label.text:
			if current_sequence.size() >= 2 and not raccoon_steal_ready:
				raccoon_steal_ready = true
				if randf() < 0.5:
					var idx = randi() % current_sequence.size()
					current_sequence.remove_at(idx)
					update_emoji_slots()
					spawn_floating_number("偷走了!", false, %BossSprite.global_position + Vector2(0, -120), Color.ORANGE)
	
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

func _add_status_badge(container: Control, text: String, color: Color, p_tooltip_text: String = ""):
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	var sf_1 = _scale_factor
	style.bg_color = Color(color.r, color.g, color.b, 0.25)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.border_width_left = 1
	style.border_color = color
	panel.add_theme_stylebox_override("panel", style)
	panel.tooltip_text = p_tooltip_text
	
	# 为 tooltip 设置更大的字体
	var tooltip_theme = Theme.new()
	var tooltip_font_size = 24 * sf_1
	var tooltip_style = StyleBoxFlat.new()
	tooltip_style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	tooltip_style.set_corner_radius_all(6)
	tooltip_style.content_margin_left = 10
	tooltip_style.content_margin_right = 10
	tooltip_style.content_margin_top = 6
	tooltip_style.content_margin_bottom = 6
	tooltip_theme.set_stylebox("panel", "TooltipPanel", tooltip_style)
	tooltip_theme.set_font_size("font_size", "TooltipLabel", tooltip_font_size)
	panel.theme = tooltip_theme
	
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 26 * sf_1)
	label.add_theme_color_override("font_color", color)
	label.tooltip_text = p_tooltip_text
	panel.add_child(label)
	container.add_child(panel)

func update_emoji_slots():
	for child in %EmojiSlot.get_children():
		child.queue_free()
	# 监控猿：显示蓄力层数提示
	if "监控猿" in enemy_name_label.text:
		var stacks_label = Label.new()
		stacks_label.text = "👁️ 监控蓄力: %d" % monkey_surveillance_stacks
		stacks_label.add_theme_font_size_override("font_size", 20)
		stacks_label.add_theme_color_override("font_color", Color.ORANGE)
		%EmojiSlot.add_child(stacks_label)
	for emoji in current_sequence:
		var label = Label.new()
		label.text = emoji
		label.add_theme_font_size_override("font_size", 32)
		%EmojiSlot.add_child(label)

func _update_sequence_display() -> void:
	# 兼容旧调用名：当前 Emoji 序列 UI 的实际刷新函数是 update_emoji_slots()。
	# 敌人机制（如薪水小偷浣熊）在修改 current_sequence 后可统一调用此包装函数。
	update_emoji_slots()

func check_combos():
	# 统计当前序列中的 Emoji 数量
	var seq_counts = {}
	for e in current_sequence:
		seq_counts[e] = seq_counts.get(e, 0) + 1
	
	# 监控猿：每打出一张 Emoji 蓄力 +1
	if "监控猿" in enemy_name_label.text:
		monkey_surveillance_stacks += 1
		update_emoji_slots()

	if "蜘蛛" in enemy_name_label.text and not spider_shuffle_used and current_sequence.size() == 3:
		if randf() < 0.5:
			current_sequence.shuffle()
			spider_shuffle_used = true
			update_emoji_slots()
			spawn_floating_number("序列重组！", true, %BossSprite.global_position + Vector2(0, -120), Color.ORANGE_RED)
			# 乱序后继续检查，看是否还能凑出连招
			seq_counts.clear()
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
	
	# 刺猬关卡特殊逻辑：打出包含键盘的连招可避险
	if "刺猬" in enemy_name_label.text:
		if "⌨️" in combo_data.parts:
			hedgehog_combo_met = true
			spawn_floating_number("SAFE!", false, %BossSprite.global_position + Vector2(0, -120), Color.GREEN)

	# 局外升级：键盘侠觉醒 - ⌨️连招额外5点伤害
	var meta = get_node_or_null("/root/MetaProgressManager")
	if meta and meta.has_upgrade("burst_kb") and "⌨️" in combo_data.parts:
		apply_damage_to_enemy(5)
	
	# 局外升级：办公室政治 - 连招时额外施加1层易伤
	if meta and meta.has_upgrade("dot_combo"):
		enemy_vulnerability += 1

	# --- 视觉特效 ---
	if %AnimationManager.has_method("play_combo_flash"):
		%AnimationManager.play_combo_flash()
	
	if %AnimationManager.has_method("shake_screen"):
		%AnimationManager.shake_screen(20.0, 0.4)
	
	# 弹出大文字提示
	var combo_label = Label.new()
	combo_label.text = "★ %s ★" % combo_data.name
	combo_label.add_theme_font_size_override("font_size", 60)
	combo_label.add_theme_color_override("font_color", Color.YELLOW)
	combo_label.add_theme_color_override("font_outline_color", Color.BLACK)
	combo_label.add_theme_constant_override("outline_size", 10)
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	combo_label.custom_minimum_size = Vector2(800, 100)
	combo_label.position = Vector2(50, 400) 
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
			var nuke_dmg = 40 + enemy_fire_stacks * 5
			apply_damage_to_enemy(nuke_dmg)
			enemy_fire_stacks *= 3
			spawn_floating_number("KABOOM!", true, %BossSprite.global_position + Vector2(0, -80), Color.ORANGE_RED)
		"muddy_water":
			apply_shield_to_hero(20)
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
			for i in range(2): draw_card()
			update_hand_layout()
		"big_bread":
			false_hope_stacks += 2
			for i in range(2): draw_card()
		"loop_report":
			if not last_player_card_data.is_empty():
				execute_card_effect(last_player_card_data)
				spawn_floating_number("REPLAY!", false, %BossSprite.global_position + Vector2(0, -120), Color.CYAN)
		"red_tape":
			intent_icon.text = "📋"
			intent_text.text = "流程审批中"
			skip_enemy_turn = true
			set_meta("skip_next_intent", true)
			apply_damage_to_enemy(25)
			draw_card()
		"paid_leave":
			apply_heal_to_hero(30)
			is_waiting_next_turn = false
			next_turn_extra_ap += 2
			draw_card()
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
			# 复制本回合之前打出的所有卡牌效果（不包括这张连招触发卡本身，但 cards_played_this_turn 已经记录了）
			# 为了防止无限递归，我们只复制基础效果
			var cards_to_copy = cards_played_this_turn.duplicate()
			for card_data in cards_to_copy:
				# 排除掉触发连招的 Emoji 卡，避免逻辑混乱
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
			var shield_gained = enemy_fire_stacks * 2
			var dmg = enemy_fire_stacks * 20
			apply_damage_to_enemy(dmg)
			apply_shield_to_hero(shield_gained)
			enemy_fire_stacks = 0
			spawn_floating_number("VOLCANO!", true, %BossSprite.global_position)
		"overtime_demon":
			apply_pure_damage_to_hero(0) # 无视护盾（直接调用不扣血）
			apply_damage_to_enemy(30)
			enemy_fire_stacks += 2
			spawn_floating_number("OVERTIME!", true, %BossSprite.global_position + Vector2(0, -80), Color.RED)
		"deep_sea_vortex":
			skip_enemy_turn = true
			set_meta("skip_next_intent", true)
			apply_damage_to_enemy(30)
			spawn_floating_number("STUNNED", false, %BossSprite.global_position + Vector2(0, -100), Color.CYAN)
		"quarterly_audit":
			var audit_dmg = recorded_data_value + 25
			apply_damage_to_enemy(audit_dmg)
			spawn_floating_number("AUDITED!", true, %BossSprite.global_position)
		"veto_power":
			enemy_atk_reduction += 10
			apply_damage_to_enemy(40)
			spawn_floating_number("VETOED!", true, %BossSprite.global_position + Vector2(0, -100), Color.RED)
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
	var dialog = AcceptDialog.new()
	dialog.title = "连招一览"
	dialog.ok_button_text = "关闭"
	dialog.dialog_text = ""
	var is_mobile = OS.has_feature("mobile")
	dialog.min_size = Vector2i(760, 560) if is_mobile else Vector2i(720, 520)
	add_child(dialog)
	
	# 调大关闭按钮
	var ok_btn = dialog.get_ok_button()
	ok_btn.custom_minimum_size = Vector2(180, 60)
	ok_btn.add_theme_font_size_override("font_size", 26)

	var container = MarginContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.add_theme_constant_override("margin_left", 14)
	container.add_theme_constant_override("margin_top", 12)
	container.add_theme_constant_override("margin_right", 14)
	container.add_theme_constant_override("margin_bottom", 48)
	dialog.add_child(container)

	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	container.add_child(scroll)

	var text = RichTextLabel.new()
	text.bbcode_enabled = true
	text.scroll_active = false
	text.fit_content = true
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(680, 0)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font_size = 28 if is_mobile else 24
	text.add_theme_font_size_override("normal_font_size", font_size)
	text.add_theme_font_size_override("bold_font_size", font_size + 2)
	scroll.add_child(text)

	var combo_text = "[b]--- 摸鱼连招秘籍 ---[/b]\n\n"
	var universal_keys = GameManager.universal_combos.keys()
	var hero_keys: Array = []

	if GameManager.selected_hero and GameManager.character_combos.has(GameManager.selected_hero.character_name):
		hero_keys = GameManager.character_combos[GameManager.selected_hero.character_name].keys()

	universal_keys.sort()
	hero_keys.sort()

	combo_text += "[color=#8fb9aa][b]通用连招[/b][/color]\n"
	for recipe in universal_keys:
		if active_combos.has(recipe):
			var data = active_combos[recipe]
			combo_text += "• [b]%s[/b]  %s\n    %s\n\n" % [recipe, data.name, data.effect]

	if hero_keys.size() > 0:
		combo_text += "[color=#ffb86c][b]角色专属连招[/b][/color]\n"
		for recipe in hero_keys:
			if active_combos.has(recipe):
				var data = active_combos[recipe]
				combo_text += "• [b]%s[/b]  %s\n    %s\n\n" % [recipe, data.name, data.effect]

	text.text = combo_text
	dialog.popup_centered_ratio(0.92 if is_mobile else 0.85)

func execute_card_effect(data: Dictionary):
	var type = data.get("type", "")
	var value = data.get("value", 0)
	var emoji = data.get("emoji", "")
	match type:
		"attack":
			var dmg = value + GameManager.attack_bonus_flat
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
			apply_damage_to_enemy(value + GameManager.attack_bonus_flat)
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
			apply_damage_to_enemy(value + GameManager.attack_bonus_flat)
			enemy_fire_stacks += 1
		"attack_bomb":
			var total_dmg = value + (enemy_fire_stacks * 8) + GameManager.attack_bonus_flat
			apply_damage_to_enemy(total_dmg)
		"buff_fire":
			if enemy_fire_stacks == 0:
				enemy_fire_stacks = 1
			else:
				enemy_fire_stacks *= value
			if data.get("name") == "余烬":
				current_ap += 1
		"attack_seed":
			apply_damage_to_enemy(value + GameManager.attack_bonus_flat)
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
			apply_damage_to_enemy(value + GameManager.attack_bonus_flat)
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
			apply_damage_to_enemy(value + GameManager.attack_bonus_flat)
			var c = draw_card()
			if c and c.card_data.get("emoji") == "📊":
				await get_tree().create_timer(0.2).timeout
				draw_card()
		"attack_then_record":
			apply_damage_to_enemy(value + GameManager.attack_bonus_flat)
			recorded_data_value = last_damage_dealt
			spawn_floating_number("RECORDED", false, hero_sprite.global_position + Vector2(0, -100), Color.GOLD)
		"attack_plus_release":
			apply_damage_to_enemy(value + GameManager.attack_bonus_flat)
			if recorded_data_value > 0:
				apply_damage_to_enemy(recorded_data_value)
				spawn_floating_number("+ %d!" % recorded_data_value, true, %BossSprite.global_position + Vector2(0, -60), Color.ORANGE)
		"attack_draw_record":
			apply_damage_to_enemy(value + GameManager.attack_bonus_flat)
			for i in range(2): draw_card()
			recorded_data_value = last_damage_dealt
		"red_tape":
			intent_icon.text = "📋"
			intent_text.text = "流程审批中"
			skip_enemy_turn = true
		"paid_leave":
			apply_heal_to_hero(20)
			is_waiting_next_turn = false
			next_turn_extra_draws += 2
		"cancel_intent":
			intent_icon.text = "💤"
			intent_text.text = "发呆中..."
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
			apply_damage_to_enemy(value + GameManager.attack_bonus_flat)
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
			var dmg = value + GameManager.attack_bonus_flat
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
			apply_damage_to_enemy(value + GameManager.attack_bonus_flat)
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
			# 通过 emoji 查找 📑 周报汇总，避免硬编码索引在 universal_cards 重排后失效
			var review_card: Dictionary = {}
			for c_data in GameManager.universal_cards:
				if c_data.get("emoji", "") == "📑":
					review_card = c_data.duplicate()
					break
			if not review_card.is_empty():
				discard_pile.append(review_card)
		"cost_reduction":
			cost_reduction_active = true
			# 直接改写所有手牌的 cost，UI 立即生效
			for c in hand_cards:
				c.card_data["cost"] = max(0, c.card_data.get("cost", 1) - 1)
				c.update_ui()
		"save_hand":
			save_hand_this_turn = true
			spawn_floating_number("SAVED", false, hero_sprite.global_position + Vector2(0, -100), Color.GREEN)
		"pull_plug":
			apply_damage_to_enemy(value + GameManager.attack_bonus_flat)
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
			apply_damage_to_enemy(value + GameManager.attack_bonus_flat)
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
			enemy_atk_reduction += 15
		"heal_vulnerability":
			apply_heal_to_hero(value)
			enemy_vulnerability += 5
		"cancel_deal_dmg":
			# Susan：否决申请 - 封印敌人下一次行动 + 造成伤害
			set_meta("skip_next_intent", true)
			skip_enemy_turn = true
			apply_damage_to_enemy(value + GameManager.attack_bonus_flat)
			spawn_floating_number("REJECTED!", true, %BossSprite.global_position + Vector2(0, -80), Color.RED)
			set_meta("cancel_played_this_turn", true)
		"shield_conditional_dmg":
			# Susan：合规检查 - 获得护盾；若本回合打过 ❌，额外造成伤害
			apply_shield_to_hero(value)
			if has_meta("cancel_played_this_turn"):
				apply_damage_to_enemy(20 + GameManager.attack_bonus_flat)
				spawn_floating_number("COMPLIANCE!", true, %BossSprite.global_position + Vector2(0, -60), Color.GOLD)
		"attack_steal_poison":
			# Inkwell：触手核心 - 偷取耐性转为护盾 + 施加中毒
			apply_shield_to_hero(value)
			enemy_atk_reduction += value
			enemy_poison_stacks += 3
			spawn_floating_number("STOLEN!", false, %BossSprite.global_position + Vector2(0, -80), Color.PURPLE)
		"shield_to_damage":
			# Inkwell：墨汁炮 - 护盾值 × 1.5 转化为伤害，消耗护盾
			var cannon_dmg = int(hero_shield * 1.5)
			cannon_dmg = max(value, cannon_dmg) # 最低保底伤害
			hero_shield = 0
			apply_damage_to_enemy(cannon_dmg + GameManager.attack_bonus_flat)
			spawn_floating_number("INK CANNON!", cannon_dmg > 25, %BossSprite.global_position + Vector2(0, -80), Color.DEEP_SKY_BLUE)
			update_ui_values()
		"junk_rambling":
			# 废话连篇：打出无效果，占用一次出牌节奏
			pass
		"nullify_next_attack":
			# Inkwell：触手缠绕 - 使敌人下一次攻击变为0 + 偷取攻击力转护盾
			set_meta("nullify_next_enemy_attack", true)
			apply_shield_to_hero(value)
			spawn_floating_number("TANGLED!", false, %BossSprite.global_position + Vector2(0, -80), Color.CYAN)
		"ignite_fuse":
			# Boomtail：点燃导火索 - 标记后本回合每打 🔥 额外结算一次火大
			set_meta("fuse_active", true)
			spawn_floating_number("FUSE LIT!", false, hero_sprite.global_position + Vector2(0, -80), Color.ORANGE)
		"bomb_timer":
			# Boomtail：核爆倒计时 - 叠加爆炸标记，下回合结束时爆炸
			var current_marks = get_meta("bomb_marks", 0) + value
			set_meta("bomb_marks", current_marks)
			set_meta("bomb_timer_active", true)
			spawn_floating_number("BOMB x%d" % current_marks, false, %BossSprite.global_position + Vector2(0, -80), Color.ORANGE_RED)
		"ultimate_fire_filter":
			var discarded_count = 0
			for i in range(hand_cards.size() - 1, -1, -1):
				var c = hand_cards[i]
				if _get_emoji_color_group(c.card_data.get("emoji", "")) != "red":
					hand_cards.remove_at(i)
					c.queue_free()
					discarded_count += 1
			update_hand_layout()
			# 重设计：即使手牌没有非火系牌也有强力单卡效果
			# 基础伤害 30，每消灭一张非火牌额外 +15 伤害 +2 火大
			# 同时引爆现有火大层数：每层额外 +3 伤害
			var fire_bonus_dmg = enemy_fire_stacks * 3
			var fire_boost = 2 + discarded_count * 2
			enemy_fire_stacks += fire_boost
			var total_fire_dmg = 30 + discarded_count * 15 + fire_bonus_dmg
			apply_damage_to_enemy(total_fire_dmg)
			if not has_meta("fire_multiplier"):
				set_meta("fire_multiplier", 1.0)
			set_meta("fire_multiplier", get_meta("fire_multiplier") + fire_boost)
			spawn_floating_number("INFERNO +%d" % fire_boost, true, hero_sprite.global_position + Vector2(0, -100), Color.ORANGE_RED)
		"ultimate_void":
			var reduction = int(enemy_hp_bar.max_value * 0.2)
			enemy_hp_bar.max_value -= reduction
			enemy_hp = min(enemy_hp, enemy_hp_bar.max_value)
			apply_heal_to_hero(reduction)
			apply_shield_to_hero(int(reduction * 0.5))
			enemy_atk_reduction += 5
			spawn_floating_number("VOID", true, %BossSprite.global_position, Color.PURPLE)
		"ultimate_vision":
			# 对齐 evolution_data（莱奥 8 级）：爆发记录数值 + 本回合所有卡牌 0 消耗
			var base = max(20, recorded_data_value)
			recorded_data_value = base
			apply_damage_to_enemy(base)
			set_meta("ultimate_vision_free_cost", true)
			for c in hand_cards:
				c.card_data["cost"] = 0
				c.update_ui()
			spawn_floating_number("VISIONARY", true, hero_sprite.global_position, Color.GOLD)
		"ultimate_blacklist":
			# 限时3回合封印：设置倒计时，每回合递减
			set_meta("boss_blacklisted", true)
			set_meta("blacklist_turns", 3)
			intent_icon.text = "🚫"
			intent_text.text = "封印(3回合)"
			intent_description.text = "老板被列入黑名单3回合，无法行动且每回合受罚20点"
			apply_damage_to_enemy(20)
			apply_shield_to_hero(15)
			spawn_floating_number("BLACKLISTED (3T)", true, %BossSprite.global_position, Color.BLACK)

func apply_damage_to_enemy(amount: int):
	if is_battle_over: return
	
	# 增伤逻辑：打出的每张牌（或触发的伤害效果）都获得固定增伤
	var final_dmg = amount
	if amount > 0:
		final_dmg += GameManager.attack_bonus_flat

	# 审计猎犬改版：不再把玩家伤害转为回血（避免挫败感）

	# 博姆终极进化：火伤翻倍
	if has_meta("fire_multiplier") and last_player_card_data.has("emoji") and _get_emoji_color_group(last_player_card_data.emoji) == "red":
		final_dmg = int(final_dmg * get_meta("fire_multiplier"))

	# CEO 羊态逻辑：单次伤害上限
	if has_meta("ceo_state") and get_meta("ceo_state") == "sheep":
		final_dmg = min(final_dmg, 10)
		
	if final_dmg > 0:
		final_dmg = int(final_dmg * player_damage_multiplier)
	
	# 扩音器效果：下一次攻击翻倍
	if final_dmg > 0 and next_attack_multiplier != 1.0:
		final_dmg = int(final_dmg * next_attack_multiplier)
		next_attack_multiplier = 1.0
	
	# 局外升级：末日冲刺 - 血量低于30%时伤害+50%
	var meta = get_node_or_null("/root/MetaProgressManager")
	if meta and meta.has_upgrade("burst_lowHP") and hero_hp < GameManager.max_player_hp * 0.3:
		final_dmg = int(final_dmg * 1.5)
	
	# 局外升级：背刺专家 - 对中毒敌人伤害+20%
	if meta and meta.has_upgrade("dot_bonus") and enemy_poison_stacks > 0:
		final_dmg = int(final_dmg * 1.2)
	
	if enemy_vulnerability > 0:
		final_dmg += enemy_vulnerability
	if self.has_meta("perm_vulnerability"):
		final_dmg += get_meta("perm_vulnerability")

	enemy_hp -= final_dmg
	enemy_hp = max(0, enemy_hp)
	if "九头蛇" in enemy_name_label.text and final_dmg > 0:
		hydra_head_damage_this_turn += final_dmg
	last_damage_dealt = final_dmg
	if %BossSprite.has_method("play_hit"):
		%BossSprite.play_hit()
	spawn_floating_number(final_dmg, final_dmg > 20, %BossSprite.global_position)
	if enemy_hp <= 0:
		show_victory()

func show_victory():
	if is_battle_over: return
	is_battle_over = true
	end_turn_button.disabled = true
	
	# 检测是否通关（打完最终 Boss）
	var is_final_boss = GameManager.current_level >= GameManager.max_levels and "CEO" in enemy_name_label.text
	
	var _gold_reward = GameManager.grant_battle_gold(GameManager.current_level, false, is_final_boss)
	var _meta_points_reward = GameManager.grant_meta_points_for_battle(GameManager.current_level, false, is_final_boss)
	
	if is_final_boss:
		# 最终通关：显示特殊结算文字
		level_clear_label.text = "恭喜通关！\n成功离职！\n 🪙 +%d 摸鱼币  ·  ⭐ +%d 积分" % [_gold_reward, _meta_points_reward]
	else:
		level_clear_label.text = "第 %d 关 已突破\n 🪙 +%d 摸鱼币  ·  ⭐ +%d 积分" % [GameManager.current_level, _gold_reward, _meta_points_reward]
	
	# 兼容 boss_stage.tscn 使用 EndingLayer 而非 VictoryLayer
	var victory_node = get_node_or_null("%VictoryLayer")
	if not victory_node:
		victory_node = get_node_or_null("%EndingLayer")
	
	if is_final_boss:
		# 最终通关：直接显示结算画面，不进入奖励选择
		if victory_node:
			victory_node.visible = true
		return
	
	if GameManager.skip_rewards_battles > 0:
		GameManager.skip_rewards_battles -= 1
		if victory_node:
			victory_node.visible = true
		return
	get_tree().create_timer(0.5).timeout.connect(show_reward_selection)

func show_reward_selection():
	var sf_2 = _scale_factor
	if has_node("RewardLayer"): return
	var reward_layer = CanvasLayer.new()
	reward_layer.name = "RewardLayer"
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
	title.add_theme_font_size_override("font_size", int(36 * sf_2))
	title.add_theme_color_override("font_color", Color.GOLD)
	vbox.add_child(title)
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", int(36 * sf_2))
	vbox.add_child(hbox)
	var rewards = GameManager.get_random_reward_cards(3)
	var reward_buttons = []
	
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
		card_panel.custom_minimum_size = Vector2(270 * sf_2, 380 * sf_2)
		hbox.add_child(card_panel)
		var card_vbox = VBoxContainer.new()
		card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		card_vbox.add_theme_constant_override("separation", int(12 * sf_2))
		card_panel.add_child(card_vbox)
		var emoji_label = Label.new()
		emoji_label.text = data.emoji
		emoji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		emoji_label.add_theme_font_size_override("font_size", int(90 * sf_2))
		card_vbox.add_child(emoji_label)
		var name_label = Label.new()
		name_label.text = data.name
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", int(30 * sf_2))
		name_label.add_theme_color_override("font_color", Color.BLACK)
		card_vbox.add_child(name_label)
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 12 * sf_2)
		card_vbox.add_child(spacer)
		var desc_label = Label.new()
		desc_label.text = data.get("description", "")
		desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.custom_minimum_size = Vector2(180 * sf_2, 0)
		desc_label.add_theme_font_size_override("font_size", int(26 * sf_2))
		desc_label.add_theme_color_override("font_color", Color("#555555"))
		card_vbox.add_child(desc_label)

		var select_btn = Button.new()
		reward_buttons.append(select_btn)
		select_btn.text = "选择"
		select_btn.custom_minimum_size = Vector2(180 * sf_2, 70 * sf_2)
		select_btn.add_theme_font_size_override("font_size", int(28 * sf_2))
		select_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card_vbox.add_child(select_btn)
		select_btn.pressed.connect(func():
			for btn in reward_buttons:
				if is_instance_valid(btn): btn.disabled = true
			GameManager.player_deck.append(data)
			reward_layer.queue_free()
			victory_layer.visible = true
		)

func apply_heal_to_hero(amount: int):
	if poison_heal_inverted:
		# PUA 毒蛇优化：回血不再全额转伤害，改为回血失效并扣除 5 点固定压力
		apply_damage_to_hero(5)
		spawn_floating_number("PUA：拒绝回血", false, hero_sprite.global_position + Vector2(0, -100), Color.RED)
		return
	var final_heal = int(amount * GameManager.heal_multiplier)
	hero_hp += final_heal
	hero_hp = min(GameManager.max_player_hp, hero_hp)
	spawn_floating_number(final_heal, false, hero_sprite.global_position + Vector2(0, -50), Color.GREEN)
	update_ui_values()
	update_status_display()

func apply_shield_to_hero(amount: int):
	# 局外升级：躺平哲学 - 无法获得护盾
	var meta = get_node_or_null("/root/MetaProgressManager")
	if meta and meta.has_upgrade("sp_lazy"):
		return
	
	hero_shield += amount
	spawn_floating_number(amount, false, hero_sprite.global_position + Vector2(0, -50), Color.CYAN)
	update_ui_values()
	update_status_display()

func _update_enemy_intent():
	var enemy = GameManager.get_current_enemy()
	
	# 重置样式
	intent_text.remove_theme_color_override("font_color")
	intent_description.text = ""

	# 优先显示“敌方行动卡”对应意图（与敌方卡组一致）
	if not current_enemy_action.is_empty():
		intent_icon.text = current_enemy_action.get("icon", "⚔️")
		intent_text.text = str(current_enemy_action.get("text", "攻击"))
		intent_description.text = current_enemy_action.get("desc", "")
	else:
		var base_dmg = 10 + (GameManager.current_level * 3)
		intent_icon.text = "⚔️"
		intent_text.text = str(base_dmg)
		intent_description.text = "准备发动一次普通攻击"

	# 追加机制提示（不覆盖行动卡意图）
	var notes: Array[String] = []
	if "鹦鹉" in enemy.name:
		notes.append("复读：锁定序列首位为上回合末尾符号")
	if "刺猬" in enemy.name:
		notes.append("倒计时：%d 回合内未打出⌨️连招将受大伤" % hedgehog_turns_left)
	if "浣熊" in enemy.name:
		notes.append("顺手牵羊：打出2个Emoji后有概率偷走序列")
	if "审计" in enemy.name:
		if compliance_rule.is_empty():
			notes.append("合规规则将于本回合发布")
		elif compliance_rule.type == "ap_parity":
			notes.append("规则：AP须%s（违规追加伤害）" % ("偶数" if compliance_rule.value == "even" else "奇数"))
		else:
			notes.append("规则：颜色≤%d（白色不计，违规追加伤害）" % compliance_rule.value)
	if "毒蛇" in enemy.name:
		notes.append("认知反转：回血/减压会被反转")
	if "监控猿" in enemy.name:
		notes.append("监控蓄力：%d" % monkey_surveillance_stacks)
	if "九头蛇" in enemy.name:
		notes.append("若本回合未击破指标，Boss会回血")

	if notes.size() > 0:
		if intent_description.text != "":
			intent_description.text += "\n"
		intent_description.text += "；".join(notes)

func spawn_floating_number(value: Variant, is_critical: bool, pos: Vector2, color: Color = Color.WHITE):
	var fn = floating_number_scene.instantiate()
	add_child(fn)
	fn.global_position = pos
	fn.pop_up(value, is_critical)
	fn.modulate = color
