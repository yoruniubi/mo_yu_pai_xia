extends Control

# --- 节点引用 (完全对齐 BattleScene) ---
@onready var hero_sprite = %HeroSprite
@onready var hero_name_label = %HeroName
@onready var hero_hp_bar = %HeroHPBar
@onready var enemy_name_label = %EnemyName
@onready var enemy_hp_bar = %EnemyHPBar
@onready var intent_label = %IntentLabel
@onready var energy_label = %EnergyLabel
@onready var hand_container = %HandContainer
@onready var end_turn_button = %EndTurnButton
@onready var emoji_slot_container = %EmojiSlot
@onready var victory_layer = %VictoryLayer
@onready var game_over_layer = %GameOverLayer
@onready var animation_manager = %AnimationManager
@onready var status_container = %StatusContainer
@onready var enemy_status_container = %EnemyStatusContainer

# --- 教学专用引用 ---
@onready var tutorial_layer = $TutorialLayer
@onready var guidance_box = %GuidanceBox
@onready var guidance_label = %GuidanceLabel
@onready var confirm_button = %ConfirmButton
@onready var pointer = %Pointer
@onready var mask = %Mask

# --- 战斗配置 ---
var card_scene = preload("res://Scenes/battle_card.tscn")
var floating_number_scene = preload("res://Scenes/floating_number.tscn")
var hand_cards = []
var current_sequence = []
var draw_pile = []

var hero_hp = 100
var hero_shield = 0
var enemy_hp = 50
var current_ap = 3

const FAN_RADIUS = 800.0
const MAX_FAN_ANGLE = 30.0

# --- 教学步骤 (增强描述版) ---
var tutorial_step = 0
var steps = [
	{"text": "欢迎来到《摸鱼牌侠》实战演练！\n这是一场沉浸式的职场生存 Roguelike。", "target": null},
	{"text": "首先看上方，这是老板的【耐性值（HP）】。\n归零则代表战斗胜利，老板放弃挣扎。", "target": "enemy_hp"},
	{"text": "旁边是老板的【意图栏】。它显示了老板下一步的动作。\n比如现在，他正准备复制你的操作！", "target": "intent"},
	{"text": "这里是老板的【状态栏】。所有的负面效果（如中毒）\n或强化状态都会显示在这里。", "target": "enemy_status"},
	{"text": "再看下方，这是你的【压力值（HP）】。\n随加班/受击增长，满值则“过劳”，游戏结束。", "target": "hero_status"},
	{"text": "这里是你的【状态/Buff栏】。你获得的护盾、\n闪避等增益效果都会在这里排排坐。", "target": "hero_status_buff"},
	{"text": "核心数值：【摸鱼力（AP）】。\n打出每张 Emoji 卡牌都需要消耗它，每回合自动回复。", "target": "ap"},
	{"text": "这些是你的【弧形手牌】。拖动或点击即可打出。\n注意：不同 Emoji 组合能触发强力连招！", "target": "hand"},
	{"text": "这里是【序列槽】。打出的 Emoji 依次进入这里。\n试试连续打出 3 张键盘 ⌨️ 触发“疯狂输出”！", "target": "combo"},
	{"text": "最后是【结束回合】。当你摸不动鱼时，\n点击它让老板开始他的表演。", "target": "end_turn"},
	{"text": "教学结束！现在，尝试击败这只鹦鹉，\n开启你的“离职之路”吧！", "target": null}
]

func _ready():
	var battle_bgm = preload("res://Assets/Music/Cubicle_Cruise.mp3")
	BgmManager.play_music(battle_bgm)
	
	_setup_tutorial_battle()
	_update_ui_values()
	
	tutorial_layer.visible = true
	mask.show()
	guidance_box.show()
	_show_step(0)
	
	confirm_button.pressed.connect(_on_confirm_pressed)
	if has_node("%SkipTutorialButton"):
		%SkipTutorialButton.pressed.connect(_on_tutorial_finished)
	%NextLevelButton.pressed.connect(_on_tutorial_finished)
	%RestartButton.pressed.connect(func(): get_tree().reload_current_scene())

func _setup_tutorial_battle():
	if GameManager.selected_hero:
		hero_sprite.texture = GameManager.selected_hero.character_image
		hero_name_label.text = GameManager.selected_hero.character_name
	
	enemy_hp_bar.max_value = 50
	enemy_hp = 50
	hero_hp = 100
	hero_hp_bar.max_value = 100
	current_ap = 3
	
	draw_pile = [
		GameManager.universal_cards[0].duplicate(), # ⌨️
		GameManager.universal_cards[0].duplicate(), # ⌨️
		GameManager.universal_cards[0].duplicate(), # ⌨️
		GameManager.universal_cards[1].duplicate(), # 💧
		GameManager.universal_cards[9].duplicate()  # 🛡️
	]
	
	for i in range(5):
		draw_card()
	
	end_turn_button.disabled = true

func _show_step(index):
	tutorial_step = index
	var step = steps[index]
	guidance_label.text = step.text
	
	if step.target == "hand" or step.target == "ap" or step.target == "hero_status" or step.target == "hero_status_buff":
		guidance_box.anchor_top = 0.2
		guidance_box.anchor_bottom = 0.2
		guidance_box.offset_top = -75
		guidance_box.offset_bottom = 75
	else:
		guidance_box.anchor_top = 0.6
		guidance_box.anchor_bottom = 0.6
		guidance_box.offset_top = -75
		guidance_box.offset_bottom = 75
		
	pointer.hide()
	match step.target:
		"enemy_hp":
			_focus_ui(enemy_hp_bar.global_position + Vector2(200, 40), "👆")
		"intent":
			_focus_ui(intent_label.global_position + Vector2(100, 40), "👆")
		"enemy_status":
			_focus_ui(enemy_status_container.global_position + Vector2(50, 40), "👆")
		"hero_status":
			_focus_ui(hero_hp_bar.global_position + Vector2(60, -40), "👇")
		"hero_status_buff":
			_focus_ui(status_container.global_position + Vector2(50, -40), "👇")
		"ap":
			_focus_ui(energy_label.global_position + Vector2(-60, 0), "👉")
		"hand":
			_focus_ui(hand_container.global_position + Vector2(360, -100), "👇")
		"combo":
			_focus_ui(%ComboSlotArea.global_position + Vector2(200, 80), "👆")
		"end_turn":
			_focus_ui(end_turn_button.global_position + Vector2(-60, 0), "👉")

func _focus_ui(pos, icon):
	pointer.show()
	pointer.text = icon
	pointer.global_position = pos
	var tw = create_tween().set_loops()
	tw.tween_property(pointer, "scale", Vector2(1.2, 1.2), 0.5)
	tw.tween_property(pointer, "scale", Vector2(1.0, 1.0), 0.5)

func _on_confirm_pressed():
	if tutorial_step < steps.size() - 1:
		_show_step(tutorial_step + 1)
	else:
		guidance_box.hide()
		pointer.hide()
		mask.hide()
		end_turn_button.disabled = false

func _on_tutorial_finished():
	GameManager.is_tutorial_mode = false
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")

func draw_card():
	if draw_pile.is_empty(): return
	var new_card = card_scene.instantiate()
	new_card.card_data = draw_pile.pop_back()
	hand_container.add_child(new_card)
	new_card.scale = Vector2(0.75, 0.75)
	new_card.pivot_offset = Vector2(110, 340) 
	hand_cards.append(new_card)
	_update_hand_layout()

func _update_hand_layout():
	var card_count = hand_cards.size()
	if card_count == 0: return
	var center_x = hand_container.size.x / 2.0
	var base_y = hand_container.size.y - 110.0
	var total_angle = min(MAX_FAN_ANGLE, card_count * 10.0)
	var angle_step = total_angle / max(1, card_count - 1)
	var start_angle = -total_angle / 2.0
	
	for i in range(card_count):
		var card = hand_cards[i]
		var angle_deg = start_angle + (i * angle_step)
		var angle_rad = deg_to_rad(angle_deg)
		var target_x = center_x + FAN_RADIUS * sin(angle_rad)
		var target_y = base_y - (FAN_RADIUS * cos(angle_rad) - FAN_RADIUS)
		
		var tween = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(card, "position", Vector2(target_x - 110, target_y - 340), 0.3)
		tween.tween_property(card, "rotation_degrees", angle_deg, 0.3)
		card.z_index = i

func _on_card_played(card_node):
	var data = card_node.card_data
	var cost = data.get("cost", 1)
	if current_ap < cost: return
	
	current_ap -= cost
	if animation_manager.has_method("play_player_attack_anim"):
		animation_manager.play_player_attack_anim(data.get("emoji", "⌨️"))
	
	execute_card_effect(data)
	
	var emoji = data.get("emoji", "")
	if emoji != "":
		current_sequence.append(emoji)
		_update_emoji_slots()
		_check_combos()
	
	hand_cards.erase(card_node)
	card_node.queue_free()
	_update_ui_values()
	_update_hand_layout()

func execute_card_effect(data):
	var type = data.get("type", "")
	var value = data.get("value", 0)
	match type:
		"attack", "attack_draw":
			_apply_damage_to_enemy(value)
		"heal", "heal_draw":
			_apply_heal_to_hero(value)
		"shield", "shield_draw", "shield_attack":
			_apply_shield_to_hero(value)

func _apply_damage_to_enemy(amount):
	enemy_hp -= amount
	enemy_hp = max(0, enemy_hp)
	_spawn_floating_number(amount, false, %BossSprite.global_position)
	if animation_manager.has_method("shake_screen"):
		animation_manager.shake_screen(10.0, 0.2)
	_update_ui_values()
	if enemy_hp <= 0:
		victory_layer.visible = true

func _apply_heal_to_hero(amount):
	hero_hp = min(100, hero_hp + amount)
	_spawn_floating_number(amount, false, hero_sprite.global_position, Color.GREEN)
	_update_ui_values()

func _apply_shield_to_hero(amount):
	hero_shield += amount
	_spawn_floating_number(amount, false, hero_sprite.global_position, Color.CYAN)
	_update_ui_values()

func _spawn_floating_number(val, crit, pos, color = Color.WHITE):
	var fn = floating_number_scene.instantiate()
	add_child(fn)
	fn.global_position = pos
	fn.pop_up(val, crit)
	fn.modulate = color

func _update_ui_values():
	hero_hp_bar.value = hero_hp
	enemy_hp_bar.value = enemy_hp
	energy_label.text = "摸鱼力: %d/3" % current_ap

func _update_emoji_slots():
	for child in emoji_slot_container.get_children(): child.queue_free()
	for e in current_sequence:
		var l = Label.new()
		l.text = e
		l.add_theme_font_size_override("font_size", 32)
		emoji_slot_container.add_child(l)

func _check_combos():
	var seq = "".join(current_sequence)
	if "⌨️⌨️⌨️" in seq:
		_trigger_tutorial_combo()
		current_sequence.clear()
		get_tree().create_timer(0.5).timeout.connect(_update_emoji_slots)

func _trigger_tutorial_combo():
	var combo_label = Label.new()
	combo_label.text = "★ 疯狂输出 ★"
	combo_label.add_theme_font_size_override("font_size", 60)
	combo_label.add_theme_color_override("font_color", Color.YELLOW)
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.position = Vector2(50, 400) 
	add_child(combo_label)
	create_tween().tween_property(combo_label, "modulate:a", 0, 1.5).set_delay(0.5)
	_apply_damage_to_enemy(35)
	if animation_manager.has_method("play_combo_flash"):
		animation_manager.play_combo_flash()

func _on_end_turn_pressed():
	current_ap = 3
	hero_shield = 0
	if %BossSprite.has_method("play_attack"):
		%BossSprite.play_attack()
	_apply_damage_to_hero(5)
	while hand_cards.size() < 5 and not draw_pile.is_empty():
		draw_card()
	_update_ui_values()

func _apply_damage_to_hero(amount):
	hero_hp -= amount
	_spawn_floating_number(amount, false, hero_sprite.global_position)
	if hero_hp <= 0:
		game_over_layer.visible = true
	_update_ui_values()
