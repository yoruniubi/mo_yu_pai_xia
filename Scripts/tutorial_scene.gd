extends Control

# --- 节点引用 (完全对齐 BattleScene) ---
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
@onready var tutorial_root = $TutorialLayer

# --- 战斗配置 ---
var card_scene = preload("res://Scenes/battle_card.tscn")
var floating_number_scene = preload("res://Scenes/floating_number.tscn")
var hand_cards = []
var current_sequence = []
var draw_pile = []
var discard_pile = []

var hero_hp = 100
var hero_shield = 0
var enemy_hp = 50
var current_ap = 3

var highlight_targets = {}
var highlight_padding = {
	"enemy_hp": Vector2(18, 10),
	"intent": Vector2(18, 10),
	"enemy_status": Vector2(18, 10),
	"hero_hp": Vector2(18, 10),
	"hero_status": Vector2(18, 10),
	"hero_status_buff": Vector2(18, 10),
	"ap": Vector2(18, 10),
	"hand": Vector2(25, 20),
	"combo": Vector2(25, 15),
	"end_turn": Vector2(18, 10)
}

const FAN_RADIUS = 800.0
const MAX_FAN_ANGLE = 30.0

# --- 教学步骤 (增强描述版) ---
var tutorial_step = 0
var steps = [
	{"text": "欢迎来到 <摸鱼牌侠> 实战演练!
这是一场沉浸式的职场生存 Roguelike.", "target": null},
	{"text": "基础信息 1/3: 这是老板的 (耐性值 HP).
归零则代表战斗胜利, 老板放弃挣扎.", "target": "enemy_hp"},
	{"text": "基础信息 2/3: 这是你的 (压力值 HP).
随加班/受击增长, 满值则 '过劳', 游戏结束.", "target": "hero_hp"},
	{"text": "基础信息 3/3: (摸鱼力 AP).
打出每张 Emoji 卡牌都需要消耗它, 每回合自动回复.", "target": "ap"},
	{"text": "这里是老板的 (意图栏). 它显示老板下一步的动作.
比如现在, 他正准备复制你的操作!", "target": "intent"},
	{"text": "卡牌系统 1/2: 这是你的 (弧形手牌).
拖动或点击即可打出, 构成你的生存与输出.", "target": "hand"},
	{"text": "卡牌系统 2/2: 不同 Emoji 组合会触发强力连招.
试试连续打出 3 张键盘 ⌨️ 触发 '疯狂输出'!", "target": "combo"},
	{"text": "状态说明: 你的 Buff 会显示在这里 (例如护盾/闪避).
需要时记得查看状态栏.", "target": "hero_status_buff"},
	{"text": "状态说明: 敌人的 Debuff 会显示在这里 (例如中毒/虚弱).
持续伤害与削弱都能在此查看.", "target": "enemy_status"},
	{"text": "最后是 (结束回合). 当你摸不动鱼时,
点击它让老板开始他的表演.", "target": "end_turn"},
	{"text": "教学结束! 现在, 尝试击败这只鹦鹉,
开启你的 '离职之路' 吧!", "target": null}
]

func _ready():
	var battle_bgm = preload("res://Assets/Music/Cubicle_Cruise.mp3")
	BgmManager.play_music(battle_bgm)
	
	_setup_tutorial_battle()
	_setup_tutorial_highlight_targets()
	_setup_mask_material()
	_update_ui_values()
	_update_enemy_intent()
	
	tutorial_layer.visible = true
	mask.show()
	guidance_box.show()
	_show_step(0)
	
	confirm_button.pressed.connect(_on_confirm_pressed)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
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

	# 教学关使用固定牌组，便于体验完整的回合循环
	draw_pile = _build_tutorial_deck()
	draw_pile.shuffle()
	
	for i in range(5):
		draw_card()
	
	end_turn_button.disabled = true

func _build_tutorial_deck() -> Array:
	return [
		GameManager.universal_cards[0].duplicate(), # ⌨️
		GameManager.universal_cards[0].duplicate(), # ⌨️
		GameManager.universal_cards[0].duplicate(), # ⌨️
		GameManager.universal_cards[1].duplicate(), # 💧
		GameManager.universal_cards[9].duplicate(), # 🛡️
		GameManager.universal_cards[3].duplicate(), # ☕
		GameManager.universal_cards[5].duplicate()  # 💤
	]

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
	_apply_highlight(step.target)
	match step.target:
		"enemy_hp":
			_focus_ui(enemy_hp_bar.global_position + Vector2(200, 40), "👆")
		"intent":
			_focus_ui(intent_card.global_position + Vector2(100, 120), "👆")
		"enemy_status":
			_focus_ui(enemy_status_container.global_position + Vector2(50, 40), "👆")
		"hero_hp":
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
		_:
			_apply_highlight(null)

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

func _setup_tutorial_highlight_targets() -> void:
	highlight_targets = {
		"enemy_hp": enemy_hp_bar,
		"intent": intent_card,
		"enemy_status": enemy_status_container,
		"hero_hp": hero_hp_bar,
		"hero_status": status_container,
		"hero_status_buff": status_container,
		"ap": energy_label,
		"hand": hand_container,
		"combo": %ComboSlotArea,
		"end_turn": end_turn_button
	}

func _setup_mask_material() -> void:
	if not mask.material:
		var shader = load("res://Assets/Shaders/tutorial_highlight_mask.gdshader")
		var mask_material = ShaderMaterial.new()
		mask_material.shader = shader
		mask.material = mask_material
	mask.show()

func _apply_highlight(target_key):
	if target_key == null or not highlight_targets.has(target_key):
		mask.hide()
		return
	var target = highlight_targets[target_key]
	if not target:
		mask.hide()
		return
	var rect = target.get_global_rect()
	var pad = highlight_padding.get(target_key, Vector2(12, 8))
	var pos = rect.position - pad
	var cutout_size = rect.size + (pad * 2.0)
	var mat = mask.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("cutout_pos", pos)
		mat.set_shader_parameter("cutout_size", cutout_size)
		mat.set_shader_parameter("view_size", get_viewport_rect().size)
		mat.set_shader_parameter("corner_radius", 12.0)
		mat.set_shader_parameter("feather", 2.0)
		mat.set_shader_parameter("overlay_color", Color(0, 0, 0, 0.6))
	mask.show()

func draw_card():
	if draw_pile.is_empty():
		if discard_pile.is_empty():
			return
		draw_pile = discard_pile.duplicate()
		discard_pile.clear()
		draw_pile.shuffle()
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
	# 回合结束时会弃掉手牌，所以放进弃牌堆
	discard_pile.append(data)
	
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
	_ensure_hp_label(hero_hp_bar, "HeroHpValueLabel", hero_hp, Color.WHITE)
	_ensure_hp_label(enemy_hp_bar, "EnemyHpValueLabel", enemy_hp, Color.WHITE)
	energy_label.text = "摸鱼力: %d/3" % current_ap

func _update_enemy_intent():
	intent_icon.text = "📝"
	intent_text.text = "复制"
	intent_description.text = "模仿你上一张打出的卡牌效果"

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
	end_turn_button.disabled = true
	current_ap = 3
	hero_shield = 0
	if %BossSprite.has_method("play_attack"):
		%BossSprite.play_attack()
	await get_tree().create_timer(0.4).timeout
	_apply_damage_to_hero(5)
	
	# 回合结束手牌进弃牌堆并清空
	for card in hand_cards:
		discard_pile.append(card.card_data)
		card.queue_free()
	hand_cards.clear()
	
	var draw_count = 5
	for i in range(draw_count):
		draw_card()
	
	current_sequence.clear()
	_update_emoji_slots()
	_update_ui_values()
	_update_hand_layout()
	end_turn_button.disabled = false

func _apply_damage_to_hero(amount):
	hero_hp -= amount
	_spawn_floating_number(amount, false, hero_sprite.global_position)
	if animation_manager.has_method("play_player_hit_anim"):
		animation_manager.play_player_hit_anim()
	if hero_hp <= 0:
		game_over_layer.visible = true
	_update_ui_values()
