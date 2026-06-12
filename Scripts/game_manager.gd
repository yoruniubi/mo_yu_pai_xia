extends Node

# 这个变量用来保存玩家选中的英雄数据
var selected_hero: CharacterData

# 玩家状态持久化
var player_hp: int = 120
var max_player_hp: int = 120
var mo_yu_coins: int = 0
var player_deck: Array = []
var is_tutorial_mode: bool = false

# 关卡管理
var current_level: int = 1
# 地图共 30 层，分为两个阶段（各15层），每个阶段结束时有一个Boss。
# current_level 仅用于追踪进度，实际敌人由战斗场景从对应池中随机抽取。
var max_levels: int = 30
var evolution_path: String = ""
var current_stage: int = 1  # 当前阶段：1=第一阶段（层0-14），2=第二阶段（层15-29）
var max_ap: int = 3 # 全局最大 AP
var pending_event_id: String = ""
var pending_random_event_id: String = ""
var last_random_event_id: String = ""
var last_battle_level: int = 0
var next_battle_ap_bonus: int = 0
var next_battle_extra_draws: int = 0
var next_battle_damage_multiplier: float = 1.0


var next_battle_enemy_damage_bonus: int = 0
var start_battle_burst_damage: int = 0
var start_battle_discard_random_hand: bool = false
var skip_rewards_battles: int = 0
var first_card_free: bool = false
var heal_multiplier: float = 1.0
var attack_bonus_flat: int = 0
var ap_drain_per_turn: int = 0
var hp_drain_per_turn: int = 0
var skip_next_battle: bool = false
var has_seen_intro: bool = false  # 是否已看过开场过场动画
var encountered_enemies: Array = []  # 本局已遇到的敌人ID列表,避免重复

# 爬塔地图运行时状态。地图场景会频繁切到战斗/事件/商店等场景；
# 这些数据必须保存在 GameManager，否则每次回到地图都会重新随机生成节点与路线。
var map_has_generated: bool = false
var map_seed: int = 0  ## 地图随机种子，确保每次加载地图时节点一致
var map_data: Array = []
var map_connections: Array = []
var map_completed: Dictionary = {}
var map_current_layer: int = 0
var map_current_node_idx: int = -1
var map_completed_layers: Dictionary = {}  ## "layer_index" -> true，记录玩家已完成的地图层

# 局外积分奖励曲线（总升级成本 139 点，对应约 8~10 次完整流程可基本点满）
const META_POINTS_TUTORIAL := 3
const META_POINTS_BOSS := 18
const META_POINTS_ELITE_BASE := 6
const META_POINTS_NORMAL_BY_FLOOR := {
	1: 2,
	2: 2,
	3: 3,
	4: 3,
	5: 4,
	6: 4,
	7: 5,
	8: 5,
	9: 6,
}
 
func _ready():
	_setup_emoji_font_fallback()
	# 自动适配屏幕拉伸
	get_window().min_size = Vector2i(360, 640)
	if OS.get_name() in ["Windows", "macOS", "Linux"]:
		# PC端默认窗口大小调整或支持全屏快捷键
		DisplayServer.window_set_title("摸鱼牌侠 - PC版")

func style_confirm_dialog(dialog: AcceptDialog, size: Vector2i = Vector2i(760, 360)) -> void:
	# 全局确认/提示弹窗样式：解决 Godot 默认 AcceptDialog / ConfirmationDialog 字号偏小的问题。
	# 其他场景只要在 popup_centered 前调用 GameManager.popup_confirm_dialog(dialog) 即可统一放大。
	var text_color := Color("#ffffff")
	var button_bg := Color("#f7ead7")
	var button_border := Color("#cfb896")

	dialog.min_size = size
	dialog.add_theme_font_size_override("title_font_size", 32)
	dialog.add_theme_color_override("title_color", Color("#6a4f3b"))

	var label := dialog.get_label()
	if label:
		label.add_theme_font_size_override("font_size", 30)
		label.add_theme_color_override("font_color", text_color)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_style_dialog_button(dialog.get_ok_button(), "确认", Color("#6a4f3b"), button_bg, button_border)
	if dialog is ConfirmationDialog:
		_style_dialog_button((dialog as ConfirmationDialog).get_cancel_button(), "取消", Color("#6a4f3b"), button_bg, button_border)

func popup_confirm_dialog(dialog: AcceptDialog, size: Vector2i = Vector2i(760, 360)) -> void:
	style_confirm_dialog(dialog, size)
	dialog.popup_centered(size)

func _style_dialog_button(button: Button, fallback_text: String, text_color: Color, bg_color: Color, border_color: Color) -> void:
	if not button:
		return
	if button.text.strip_edges() == "" or button.text in ["OK", "Ok"]:
		button.text = fallback_text
	button.custom_minimum_size = Vector2(180, 72)
	button.add_theme_font_size_override("font_size", 28)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_color_override("font_focus_color", text_color)
	button.add_theme_color_override("font_hover_pressed_color", text_color)
	button.add_theme_color_override("font_disabled_color", text_color.darkened(0.25))

	var normal := StyleBoxFlat.new()
	normal.bg_color = bg_color
	normal.border_color = border_color
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 6
	normal.set_corner_radius_all(24)
	normal.content_margin_left = 20
	normal.content_margin_right = 20
	normal.content_margin_top = 12
	normal.content_margin_bottom = 12
	button.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate()
	hover.bg_color = bg_color.lightened(0.12)
	button.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate()
	pressed.bg_color = bg_color.darkened(0.08)
	pressed.border_width_bottom = 2
	button.add_theme_stylebox_override("pressed", pressed)

func _setup_emoji_font_fallback() -> void:
	# 本地/桌面端优先走系统字体；仅 Web 端启用内置 Emoji 子集字体兜底
	if not OS.has_feature("web"):
		return

	# Web 端使用项目内 Emoji 字体作为 fallback
	var emoji_font_path: String = "res://Assets/Fonts/NotoEmoji-VariableFont_wght.ttf"
	if not FileAccess.file_exists(emoji_font_path):
		return

	var emoji_font_res: Resource = load(emoji_font_path)
	if emoji_font_res == null:
		return
	if not (emoji_font_res is Font):
		return

	var emoji_font: Font = emoji_font_res as Font
	_attach_emoji_font_to_main_font(emoji_font)

	if ThemeDB.fallback_font == null:
		ThemeDB.fallback_font = emoji_font
		return

	var existing_fallbacks: Array = ThemeDB.fallback_font.fallbacks
	if not existing_fallbacks.has(emoji_font):
		existing_fallbacks.append(emoji_font)
		ThemeDB.fallback_font.fallbacks = existing_fallbacks

func _attach_emoji_font_to_main_font(emoji_font: Font) -> void:
	# 项目设置里用了 theme/custom_font，需把 emoji fallback 直接挂到主字体上
	var main_font_res: Resource = load("res://Assets/Fonts/SmileySans-Oblique.ttf")
	if main_font_res == null:
		return
	if not (main_font_res is Font):
		return

	var main_font: Font = main_font_res as Font
	var main_fallbacks: Array = main_font.fallbacks
	if not main_fallbacks.has(emoji_font):
		main_fallbacks.append(emoji_font)
		main_font.fallbacks = main_fallbacks

func _input(event):
	# PC端全屏快捷键 (F11)
	if event is InputEventKey and event.keycode == KEY_F11 and event.pressed:
		var mode = DisplayServer.window_get_mode()
		if mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func start_game(hero: CharacterData):
	selected_hero = hero
	reset_run()
	load_current_level_scene()

# 游戏结束后，重置的属性
func reset_run():
	player_hp = 120
	max_player_hp = 120
	mo_yu_coins = 0
	current_level = 1
	max_ap = 3
	evolution_path = ""
	current_stage = 1
	pending_event_id = ""
	pending_random_event_id = ""
	last_random_event_id = ""
	last_battle_level = 0
	next_battle_ap_bonus = 0
	next_battle_extra_draws = 0
	next_battle_damage_multiplier = 1.0

	next_battle_enemy_damage_bonus = 0
	start_battle_burst_damage = 0
	start_battle_discard_random_hand = false
	skip_rewards_battles = 0
	first_card_free = false
	heal_multiplier = 1.0
	attack_bonus_flat = 0
	ap_drain_per_turn = 0
	hp_drain_per_turn = 0
	skip_next_battle = false
	# 地图状态重置
	map_has_generated = false
	map_seed = randi()
	map_data.clear()
	map_connections.clear()
	map_completed.clear()
	map_current_layer = 0
	map_current_node_idx = -1
	map_completed_layers.clear()
	encountered_enemies.clear()
	initialize_deck()
	apply_meta_upgrades()

func apply_meta_upgrades():
	var meta = _meta_progress_manager()
	if meta == null:
		return
	
	# 资源类升级
	if meta.has_upgrade("ap_start"):
		max_ap += meta.get_level("ap_start")
	
	if meta.has_upgrade("hp_start"):
		var bonus_hp = meta.get_level("hp_start") * 20
		max_player_hp += bonus_hp
		player_hp += bonus_hp
	
	if meta.has_upgrade("draw_start"):
		next_battle_extra_draws += meta.get_level("draw_start")
	
	if meta.has_upgrade("draft_start"):
		next_battle_extra_draws += 2
	
	# 策略类和特殊类升级在战斗场景中动态检查

func calc_battle_reward(floor_num: int, is_elite: bool, is_boss: bool) -> int:
	## 经济系统设计文档：战斗胜利摸鱼币奖励
	##   普通战斗: 15 + (floor_num / 6) + randi(-3, 5)
	##   精英战斗: 普通结果 × 1.8（取整）
	##   Boss 战斗: 固定 60
	if is_boss:
		return 60
	@warning_ignore("integer_division")
	var base := 15 + (floor_num / 6) + randi_range(-3, 5)
	if is_elite:
		return int(base * 1.8)
	return base

func get_battle_gold_reward(level: int = current_level) -> int:
	## 保留旧接口兼容性，默认按普通战斗计算
	return calc_battle_reward(level, false, false)

func add_gold(amount: int) -> void:
	mo_yu_coins = max(0, mo_yu_coins + amount)

func grant_battle_gold(floor_num: int = current_level, is_elite: bool = false, is_boss: bool = false) -> int:
	## 计算并直接发放战斗金币，返回实际发放金额（供 UI 展示用）
	var amount := calc_battle_reward(floor_num, is_elite, is_boss)
	add_gold(amount)
	return amount

func _meta_progress_manager() -> Node:
	return get_node_or_null("/root/MetaProgressManager")

func calc_meta_points_reward(floor_num: int = current_level, is_elite: bool = false, is_boss: bool = false, is_tutorial: bool = false) -> int:
	if is_tutorial:
		return META_POINTS_TUTORIAL
	if is_boss:
		return META_POINTS_BOSS
	if is_elite:
		return META_POINTS_ELITE_BASE + int(floor((max(1, floor_num) - 1) / 3.0))
	return META_POINTS_NORMAL_BY_FLOOR.get(floor_num, 6)

func grant_meta_points(amount: int) -> int:
	var meta = _meta_progress_manager()
	if meta == null or amount <= 0:
		return 0
	meta.add_points(amount)
	if meta.has_method("save"):
		meta.save()
	return amount

func grant_meta_points_for_battle(floor_num: int = current_level, is_elite: bool = false, is_boss: bool = false) -> int:
	return grant_meta_points(calc_meta_points_reward(floor_num, is_elite, is_boss, false))

func grant_meta_points_for_tutorial() -> int:
	return grant_meta_points(calc_meta_points_reward(1, false, false, true))

func initialize_deck():
	player_deck.clear()
	# 初始牌组：约 8 张卡。
	# 之前是 10 张通用牌 + 全部角色卡，开局牌库过厚，导致核心牌和 Combo 更难上手。
	# 新结构：7 张通用基础牌 + 1 张角色本命核心牌，后续通过奖励/商店逐步构筑。
	# 注：universal_cards 已按稀有度重排，这里用 emoji 查找避免硬编码索引被打乱。
	# 2 张 ⌨️ 键盘输出
	for i in range(2):
		player_deck.append(_get_universal_card_by_emoji("⌨️"))
	# 1 张 💧 摸鱼喝水 - 回血
	player_deck.append(_get_universal_card_by_emoji("💧"))
	# 1 张 🛡️ 甩锅 - 护盾+小攻击
	player_deck.append(_get_universal_card_by_emoji("🛡️"))
	# 1 张 🤡 小丑自嘲
	player_deck.append(_get_universal_card_by_emoji("🤡"))
	# 1 张 ☕ 午后咖啡（0 cost AP）
	player_deck.append(_get_universal_card_by_emoji("☕"))
	# 1 张 💩 带薪拉屎（中毒）
	player_deck.append(_get_universal_card_by_emoji("💩"))

	# 角色特色卡：开局只加入 1 张“本命核心”卡，避免一次性塞入整个角色卡池。
	if selected_hero and selected_hero.card_pool.size() > 0:
		var hero_card = _get_starting_hero_core_card()
		if not hero_card.is_empty():
			player_deck.append(hero_card)
	else:
		# 兜底：再给一张键盘
		player_deck.append(_get_universal_card_by_emoji("⌨️"))

func _get_universal_card_by_emoji(emoji: String) -> Dictionary:
	## 通过 emoji 在通用卡池中查找模板卡，返回 duplicate 副本
	for card in universal_cards:
		if card.get("emoji", "") == emoji:
			return card.duplicate()
	# 找不到时兜底返回第一张，避免空 Dictionary 进牌组
	return universal_cards[0].duplicate() if universal_cards.size() > 0 else {}

func _get_starting_hero_core_card() -> Dictionary:
	if not selected_hero:
		return {}
	for card in selected_hero.card_pool:
		var hero_card_name = card.get("name", "")
		if "本命核心" in hero_card_name:
			return _normalize_hero_core_card(card.duplicate())
	# 如果某个角色资源没有标记本命核心，则至少给 1 张角色卡，保证开局有职业特色。
	return _normalize_hero_core_card(selected_hero.card_pool[0].duplicate())

func _normalize_hero_core_card(hero_card: Dictionary) -> Dictionary:
	var hero_card_name = hero_card.get("name", "")
	# 动态更新核心卡描述以匹配最新的护盾/回血逻辑
	if "触手" in hero_card_name:
		hero_card["description"] = "偷取敌人 8 点耐性值转为护盾，并施加 3 层中毒。"
	elif "松果" in hero_card_name:
		hero_card["description"] = "造成 5 伤害，获得 1 个随机 🔥 卡。"
	elif "图表" in hero_card_name:
		hero_card["description"] = "造成 20 伤害。抽 3 张牌。记录本次伤害。回复 1 AP。"
	elif "简历" in hero_card_name:
		hero_card["description"] = "反弹本回合受到的第一次伤害。"
	return hero_card

func get_random_reward_cards(count: int = 3) -> Array:
	var rewards = []
	var pool = []
	pool.append_array(universal_cards)
	if selected_hero:
		pool.append_array(selected_hero.card_pool)
	
	# 避免重复
	pool.shuffle()
	for i in range(min(count, pool.size())):
		rewards.append(pool[i].duplicate())
	return rewards

func show_deck_viewer(parent: Node, can_remove: bool = false, remove_callback: Callable = Callable()):
	var canvas = CanvasLayer.new()
	canvas.layer = 110
	parent.add_child(canvas)

	var root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(root)

	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.9)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left   = 40.0
	vbox.offset_right  = -40.0
	vbox.offset_top    = 40.0
	vbox.offset_bottom = -40.0
	vbox.add_theme_constant_override("separation", 20)
	root.add_child(vbox)

	var title = Label.new()
	title.text = "--- 我的牌库 (%d 张) ---" % player_deck.size()
	if can_remove:
		title.text = "--- 整理工位：选择一张要丢弃的卡牌 ---"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color.GOLD)
	vbox.add_child(title)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 20)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)

	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 25)
	grid.add_theme_constant_override("v_separation", 25)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	margin.add_child(grid)

	for i in range(player_deck.size()):
		var data = player_deck[i]
		var card_box = PanelContainer.new()
		card_box.custom_minimum_size = Vector2(200, 280)
		var style = StyleBoxFlat.new()
		style.bg_color = Color("#fdf5e6")
		style.set_corner_radius_all(10)
		style.border_width_left   = 2
		style.border_width_top    = 2
		style.border_width_right  = 2
		style.border_width_bottom = 2
		style.border_color = Color("#d2b48c")
		card_box.add_theme_stylebox_override("panel", style)
		grid.add_child(card_box)

		var card_vbox = VBoxContainer.new()
		card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		card_box.add_child(card_vbox)

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

		if data.get("upgraded", false):
			var badge = Label.new()
			badge.text = "✨ 已升级"
			badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			badge.add_theme_font_size_override("font_size", 16)
			badge.add_theme_color_override("font_color", Color.GOLD)
			card_vbox.add_child(badge)

		if can_remove:
			var btn = Button.new()
			btn.text = "丢弃"
			btn.custom_minimum_size = Vector2(120, 45)
			btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			btn.add_theme_font_size_override("font_size", 22)
			card_vbox.add_child(btn)
			btn.pressed.connect(func():
				player_deck.remove_at(i)
				canvas.queue_free()
				if remove_callback.is_valid():
					remove_callback.call()
			)

	var close_btn = Button.new()
	close_btn.text = "取消" if can_remove else "返回"
	close_btn.custom_minimum_size = Vector2(200, 60)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.add_theme_font_size_override("font_size", 26)
	vbox.add_child(close_btn)
	close_btn.pressed.connect(canvas.queue_free)

func load_current_level_scene():
	var scene_path = "res://Scenes/battle_scene.tscn"
	
	if is_tutorial_mode and current_level == 1:
		scene_path = "res://Scenes/tutorial_scene.tscn"
	else:
		if pending_event_id != "":
			scene_path = "res://Scenes/event_scene.tscn"
		elif pending_random_event_id != "":
			scene_path = "res://Scenes/event_scene.tscn"
		else:
			# 普通/精英战斗统一由地图节点决定 current_level。
			# 最终 Boss 不再通过 current_level == 10 触发，避免跳过第 10 号敌人“PUA 毒蛇”。
			scene_path = "res://Scenes/battle_scene.tscn"
			
	var tree = Engine.get_main_loop() as SceneTree
	if tree:
		tree.change_scene_to_file(scene_path)

func advance_level():
	current_level += 1
	if current_level > max_levels:
		var tree = Engine.get_main_loop() as SceneTree
		if tree:
			tree.change_scene_to_file("res://Scenes/main_menu.tscn")
	else:
		load_map_scene()

func load_map_scene():
	"""加载爬塔地图场景，让玩家选择下一个节点"""
	var tree = Engine.get_main_loop() as SceneTree
	if tree:
		tree.change_scene_to_file("res://Scenes/map.tscn")

func finish_event_and_continue():
	pending_event_id = ""
	pending_random_event_id = ""
	load_map_scene()

func _get_random_event_id() -> String:
	var keys = random_events.keys()
	if keys.size() == 0:
		return ""
	keys.shuffle()
	if last_random_event_id != "" and keys.size() > 1:
		keys = keys.filter(func(k): return k != last_random_event_id)
		if keys.size() == 0:
			keys = random_events.keys()
			keys.shuffle()
	var chosen = keys[0]
	last_random_event_id = chosen
	return chosen


# 敌人数据 definition
var enemies_data = {
	# ============ 第一阶段（前15层）============
	# 普通敌人池（用于 battle 节点随机抽取）
	1: {
		"name": "传声鹦鹉",
		"image": "res://Assets/Images/parrot.png",
		"hp": 35,
		"intent": "意图：准备复制你的下一张牌",
		"stage": 1,
		"type": "normal"
	},
	2: {
		"name": "闹钟刺猬",
		"image": "res://Assets/Images/hedgehog.png",
		"hp": 45,
		"intent": "意图：高频连击准备中"
	},
	3: {
		"name": "薪水小偷浣熊",
		"image": "res://Assets/Images/Raccoon.png",
		"hp": 60,
		"intent": "意图：盯住你的序列槽"
	},
	4: {
		"name": "老油条鲶鱼",
		"image": "res://Assets/Images/Veteran Catfish.png",
		"hp": 50,
		"intent": "意图：滑不留手的摸鱼"
	},
	5: {
		"name": "打印机螃蟹",
		"image": "res://Assets/Images/Paper Jam Crab.png",
		"hp": 55,
		"intent": "意图：卡纸干扰"
	},
	
	# 第一层精英
	6: {
		"name": "项目组长监控猿",
		"image": "res://Assets/Images/kingkong.png",
		"hp": 90,
		"intent": "意图：锁定你的 Emoji 槽位"
	},
	7: {
		"name": "摸鱼猫主管",
		"image": "res://Assets/Images/Slacking Supervisor.png",
		"hp": 100,
		"intent": "意图：抓包你的摸鱼行为"
	},
	
	# 第一层Boss
	8: {
		"name": "部门经理野猪",
		"image": "res://Assets/Images/Manager Boar.png",
		"hp": 180,
		"intent": "意图：施压强制加班"
	},
	
	# 第二层普通敌人
	9: {
		"name": "会议树懒",
		"image": "res://Assets/Images/Sloth.png",
		"hp": 110,
		"intent": "意图：塞入垃圾文件卡"
	},
	10: {
		"name": "PUA 毒蛇",
		"image": "res://Assets/Images/snake.png",
		"hp": 130,
		"intent": "意图：反转你的回血"
	},
	11: {
		"name": "审计猎犬",
		"image": "res://Assets/Images/dog.png",
		"hp": 140,
		"intent": "意图：发布合规标准"
	},
	12: {
		"name": "裁员镰鼬",
		"image": "res://Assets/Images/Layoff Weasel.png",
		"hp": 150,
		"intent": "意图：削减人员威胁"
	},
	13: {
		"name": "年终总结鲸",
		"image": "res://Assets/Images/Annual Review Whale.png",
		"hp": 160,
		"intent": "意图：压迫式总结考核"
	},
	
	# 第二层精英
	14: {
		"name": "外包秃鹫",
		"image": "res://Assets/Images/Outsource Vulture.png",
		"hp": 170,
		"intent": "意图：寻找外包替代"
	},
	15: {
		"name": "画饼蜘蛛",
		"image": "res://Assets/Images/spider.png",
		"hp": 190,
		"intent": "意图：编织虚假目标"
	},
	16: {
		"name": "KPI 九头蛇",
		"image": "res://Assets/Images/Hydra.png",
		"hp": 220,
		"intent": "意图：分裂指标回血"
	},
	
	# 第二层Boss
	17: {
		"name": "三头狮 CEO",
		"image": "res://Assets/Images/Boss.png",
		"hp": 400,
		"intent": "意图：释放【职场终结者】"
	},
}

func get_random_normal_enemy() -> Dictionary:
	"""根据当前关卡从对应阶段的普通敌人池中随机选择（避免重复）"""
	var normal_enemy_ids: Array
	if current_level <= 15:
		normal_enemy_ids = [1, 2, 3, 4, 5]
	else:
		normal_enemy_ids = [9, 10, 11, 12, 13]
	
	# 过滤已遇到的敌人
	var available = normal_enemy_ids.filter(func(id): return not encountered_enemies.has(id))
	if available.is_empty():
		available = normal_enemy_ids  # 全遇过了就重置
	
	var chosen_id = available[randi() % available.size()]
	encountered_enemies.append(chosen_id)
	return enemies_data.get(chosen_id, enemies_data[1])

func get_random_elite_enemy() -> Dictionary:
	"""根据当前关卡从对应阶段的精英敌人池中随机选择（避免重复）"""
	var elite_enemy_ids: Array
	if current_level <= 15:
		elite_enemy_ids = [6, 7]
	else:
		elite_enemy_ids = [14, 15, 16]
	
	# 过滤已遇到的敌人
	var available = elite_enemy_ids.filter(func(id): return not encountered_enemies.has(id))
	if available.is_empty():
		available = elite_enemy_ids
	
	var chosen_id = available[randi() % available.size()]
	encountered_enemies.append(chosen_id)
	return enemies_data.get(chosen_id, enemies_data[6])

func get_random_boss_enemy() -> Dictionary:
	"""根据当前关卡从对应阶段的 Boss 敌人池中随机选择"""
	var boss_enemy_ids: Array
	if current_level <= 15:
		# 第一阶段 Boss：ID 8（部门经理野猪）
		boss_enemy_ids = [8]
	else:
		# 第二阶段 Boss：ID 17（三头狮 CEO）
		boss_enemy_ids = [17]
	
	var chosen_id = boss_enemy_ids[randi() % boss_enemy_ids.size()]
	if enemies_data.has(chosen_id):
		return enemies_data[chosen_id]
	# 兜底
	return enemies_data[17]

func get_current_enemy():
	if enemies_data.has(current_level):
		return enemies_data[current_level]
	# 默认敌人
	return {
		"name": "职场小怪",
		"image": "res://Assets/Images/parrot.png",
		"hp": 30 + current_level * 8,
		"intent": "意图：让你加班"
	}

# 连招系统定义
var universal_combos = {
	"🤡🤡": {"name": "小丑竟是我自己", "parts": ["🤡", "🤡"], "effect": "伤害等同于已损失压力的 50%", "logic": "clown_self"},
	"💩☕💤": {"name": "终极摸鱼", "parts": ["💩", "☕", "💤"], "effect": "恢复满 HP 且跳过老板回合", "logic": "ultimate_slack"},
	"☕💩💧": {"name": "摸鱼三件套", "parts": ["☕", "💩", "💧"], "effect": "抽 2 张牌，摸鱼力 +1", "logic": "slack_trio"},
	"🤡💩🤡": {"name": "职场老油条", "parts": ["🤡", "💩", "🤡"], "effect": "获得 2 回合减损闪避", "logic": "office_slicker"},
	"🏃💧💩": {"name": "带薪健身", "parts": ["🏃", "💧", "💩"], "effect": "回复 10 HP，本场战斗 HP 上限 +5", "logic": "paid_gym"},
	"👍👍": {"name": "优秀员工", "parts": ["👍", "👍"], "effect": "获得 20 点护盾并回复 1 AP", "logic": "excellent_employee"},
	"💩💩": {"name": "拉屎大师", "parts": ["💩", "💩"], "effect": "使敌人中毒层数翻倍", "logic": "poop_master"},
	"⌨️⌨️⌨️": {"name": "疯狂输出", "parts": ["⌨️", "⌨️", "⌨️"], "effect": "造成 35 点爆发伤害", "logic": "crazy_output"},
	"📑📑": {"name": "深度复盘", "parts": ["📑", "📑"], "effect": "触发本回合所有已打出卡牌的效果各一次", "logic": "deep_review"},
	"💡💡": {"name": "头脑风暴", "parts": ["💡", "💡"], "effect": "抽 3 张牌并回复 1 AP", "logic": "brainstorm"},
	"🏃🏃": {"name": "职场幻影", "parts": ["🏃", "🏃"], "effect": "获得 2 回合闪避", "logic": "office_phantom"},
	"☕☕": {"name": "咖啡因过载", "parts": ["☕", "☕"], "effect": "获得 2 AP，抽 2 张牌，扣 5 HP", "logic": "caffeine_overload"},
	"💻⌨️": {"name": "远程输出", "parts": ["💻", "⌨️"], "effect": "造成 15 伤害，抽 1 张牌", "logic": "remote_output"},
	"💩💩💩": {"name": "拉屎之神", "parts": ["💩", "💩", "💩"], "effect": "中毒层数翻 3 倍", "logic": "poop_god"},
	"📁📑": {"name": "归档整理", "parts": ["📁", "📑"], "effect": "获得 15 护盾并抽 1 张牌", "logic": "file_archive"},
	"🖱️🖱️🖱️": {"name": "连点器", "parts": ["🖱️", "🖱️", "🖱️"], "effect": "造成 20 点伤害", "logic": "auto_clicker"},
	"💼👍": {"name": "带薪面试", "parts": ["💼", "👍"], "effect": "获得 10 护盾并抽 2 张牌", "logic": "paid_interview"},
	"📧📧": {"name": "全员抄送", "parts": ["📧", "📧"], "effect": "抽 2 张牌并造成 12 伤害", "logic": "cc_everyone"},
	"🧘💤": {"name": "心理假", "parts": ["🧘", "💤"], "effect": "回复 25 HP 并回复 1 AP", "logic": "mental_health"},
	"💰💼": {"name": "风险投资", "parts": ["💰", "💼"], "effect": "获得 2 AP 并抽 2 张牌", "logic": "venture_capital"},
	"📄⌨️": {"name": "撰写报告", "parts": ["📄", "⌨️"], "effect": "造成 18 伤害并获得 8 护盾", "logic": "write_report"},
	"⌨️🔌": {"name": "全线崩溃", "parts": ["⌨️", "🔌"], "effect": "造成 60 伤害，下回合 AP 减半", "logic": "system_crash"},
	"💤🧘💧": {"name": "带薪长假", "parts": ["💤", "🧘", "💧"], "effect": "回复 40 HP，下回合抽牌 +3", "logic": "long_vacation"},
	"👍📊📈": {"name": "职场精英", "parts": ["👍", "📊", "📈"], "effect": "获得 20 护盾，下一次伤害翻倍", "logic": "office_elite"},
	"🔌💻": {"name": "断网了", "parts": ["🔌", "💻"], "effect": "老板下回合发呆，抽 2 张牌", "logic": "no_internet"}
}

var character_combos = {
	"博姆 (Boomtail)": {
		"🔥⌨️": {"name": "愤怒的键盘侠", "parts": ["🔥", "⌨️"], "effect": "本回合所有键盘伤害变为 3 倍", "logic": "angry_keyboard"},
		"🔥💣🧨": {"name": "核能爆破", "parts": ["🔥", "💣", "🧨"], "effect": "造成 40 点伤害 + 当前火大层数×5 额外伤害，火大层数翻三倍", "logic": "nuclear_bomb"},
		"⌨️⌨️🔥": {"name": "加班狂魔", "parts": ["⌨️", "⌨️", "🔥"], "effect": "造成 30 点无视防御伤害，额外叠加 2 层火大", "logic": "overtime_demon"},
		"🔥🌋": {"name": "火山爆发", "parts": ["🔥", "🌋"], "effect": "消耗所有火大，每层造成 20 伤害，并获得等量护盾", "logic": "volcano_eruption"}
	},
	"墨里 (Inkwell)": {
		"💩🌊": {
			"name": "浑水摸鱼",
			"parts": ["💩", "🌊"],
			"effect": "获得 20 点防御，且下回合多抽 2 张牌",
			"logic": "muddy_water"
		},
		"🐙💨": {
			"name": "墨雾逃生",
			"parts": ["🐙", "💨"],
			"effect": "本回合无敌，移除所有垃圾卡，并抽 2 张牌",
			"logic": "ink_escape"
		},
		"🌊🌀": {"name": "深海漩涡", "parts": ["🌊", "🌀"], "effect": "老板连续 2 回合无法行动，并造成 30 点伤害", "logic": "deep_sea_vortex"}
	},
	"莱奥 (Leo)": {
		"📊📈🍞": {
			"name": "画大饼",
			"parts": ["📊", "📈", "🍞"],
			"effect": "获得 2 层虚假希望（抵消致死伤害），抽 2 张牌",
			"logic": "big_bread"
		},
		"📊📈📊": {
			"name": "循环报表",
			"parts": ["📊", "📈", "📊"],
			"effect": "重复释放本回合最后一张牌的效果一次",
			"logic": "loop_report"
		},
		"📊📑": {"name": "季度审计", "parts": ["📊", "📑"], "effect": "造成记录值 + 25 点固定伤害，不依赖记录值也有保底", "logic": "quarterly_audit"}
	},
	"苏珊 (Susan)": {
		"❌📋": {
			"name": "流程繁琐",
			"parts": ["❌", "📋"],
			"effect": "老板下 2 回合无法行动，造成 25 点伤害，抽 1 张牌",
			"logic": "red_tape"
		},
		"⏳📋": {
			"name": "带薪休假",
			"parts": ["⏳", "📋"],
			"effect": "回复 30 HP，下回合 AP +2，抽 1 张牌",
			"logic": "paid_leave"
		},
		"❌🚫": {"name": "一票否决", "parts": ["❌", "🚫"], "effect": "永久降低老板 10 点攻击力，并造成 40 点直接伤害", "logic": "veto_power"}
	}
}

# ─────────────────────────────────────────
# 卡牌稀有度划分
#   common (普通): 单一效果、无条件触发，作为开局基石卡使用
#   rare   (稀有): 复合效果 / 条件触发 / buff·debuff / 抽英雄卡
#   epic   (史诗): 终结技 / 全局增益 / 特殊机制 / 决战卡
#
# 与经济系统设计文档对应的商店定价：
#   普通  60–80币
#   稀有  100–130币
#   史诗  150–180币
# ─────────────────────────────────────────
const RARITY_COMMON := "common"
const RARITY_RARE   := "rare"
const RARITY_EPIC   := "epic"

const RARITY_PRICE_RANGES := {
	"common": [60, 80],
	"rare":   [100, 130],
	"epic":   [150, 180],
}

# 通用基础卡池
var universal_cards: Array = [
	# ── 普通 (common) ── 13 张：基础攻击 / 防御 / 回血 / 抽牌
	{"name": "键盘输出", "emoji": "⌨️", "cost": 1, "description": "造成 8 点伤害", "type": "attack", "value": 8, "rarity": "common"},
	{"name": "摸鱼喝水", "emoji": "💧", "cost": 1, "description": "回复 10 点压力 (HP)", "type": "heal", "value": 10, "rarity": "common"},
	{"name": "小丑自嘲", "emoji": "🤡", "cost": 1, "description": "造成 5 点伤害，抽 1 张牌", "type": "attack_draw", "value": 5, "rarity": "common"},
	{"name": "灵光一闪", "emoji": "💡", "cost": 1, "description": "抽 2 张牌", "type": "draw_only", "value": 2, "rarity": "common"},
	{"name": "甩锅", "emoji": "🛡️", "cost": 1, "description": "获得 5 点护盾并造成 3 点伤害", "type": "shield_attack", "value": 5, "rarity": "common"},
	{"name": "老板的赞赏", "emoji": "👍", "cost": 1, "description": "获得 10 点护盾", "type": "shield", "value": 10, "rarity": "common"},
	{"name": "团队协作", "emoji": "🤝", "cost": 1, "description": "抽 2 张牌", "type": "draw_only", "value": 2, "rarity": "common"},
	{"name": "加班餐", "emoji": "🥪", "cost": 1, "description": "回复 15 HP", "type": "heal", "value": 15, "rarity": "common"},
	{"name": "远程办公", "emoji": "💻", "cost": 1, "description": "造成 8 伤害，抽 1 张牌", "type": "attack_draw", "value": 8, "rarity": "common"},
	{"name": "日程表", "emoji": "📅", "cost": 1, "description": "抽 1 张牌，若它是 Emoji 卡则其消耗变为 0", "type": "draw_discount", "value": 1, "rarity": "common"},
	{"name": "文件夹", "emoji": "📁", "cost": 1, "description": "获得 5 护盾，若下一张是 📑 则护盾+10", "type": "shield_folder", "value": 5, "rarity": "common"},
	{"name": "修复Bug", "emoji": "🛠️", "cost": 1, "description": "回复 5 HP，移除手牌中 1 张垃圾卡", "type": "heal_remove_junk", "value": 5, "rarity": "common"},
	{"name": "鼠标点击", "emoji": "🖱️", "cost": 0, "description": "造成 2 点伤害", "type": "attack", "value": 2, "rarity": "common"},

	# ── 稀有 (rare) ── 15 张：复合效果 / 条件触发 / buff·debuff
	{"name": "午后咖啡", "emoji": "☕", "cost": 0, "description": "获得 1 点摸鱼力 (AP) 并抽一张牌", "type": "buff_ap_draw", "value": 1, "rarity": "rare"},
	{"name": "带薪拉屎", "emoji": "💩", "cost": 1, "description": "施加 5 层中毒并抽 1 张牌", "type": "special_poop", "rarity": "rare"},
	{"name": "工位补觉", "emoji": "💤", "cost": 1, "description": "回复 15 HP，抽 1 张牌", "type": "heal_draw", "value": 15, "rarity": "rare"},
	{"name": "老板画饼", "emoji": "🍞", "cost": 1, "description": "获得 10 点护盾，抽 1 张牌", "type": "shield_draw", "value": 10, "rarity": "rare"},
	{"name": "极限跃动", "emoji": "🏃", "cost": 1, "description": "获得 1 回合闪避并抽 1 张牌", "type": "evasion_draw", "value": 1, "rarity": "rare"},
	{"name": "周报汇总", "emoji": "📑", "cost": 1, "description": "造成 8 点伤害，若本回合打出过 ⌨️ 则伤害翻倍", "type": "attack_conditional_keyboard", "value": 8, "rarity": "rare"},
	{"name": "充电宝", "emoji": "🔋", "cost": 1, "description": "下回合额外获得 2 点摸鱼力", "type": "next_turn_ap", "value": 2, "rarity": "rare"},
	{"name": "业绩下滑", "emoji": "📉", "cost": 1, "description": "使敌人进入易伤状态 (受到伤害+5)", "type": "debuff_def", "value": 5, "rarity": "rare"},
	{"name": "接个电话", "emoji": "📞", "cost": 1, "description": "获得 1 回合闪避，下回合抽牌 -1", "type": "evade_penalty_draw", "value": 1, "rarity": "rare"},
	{"name": "邮件确认", "emoji": "📧", "cost": 1, "description": "造成 5 伤害并抽牌。若抽到 ⌨️ 则追加 10 伤害", "type": "attack_draw_email", "value": 5, "rarity": "rare"},
	{"name": "公司大楼", "emoji": "🏢", "cost": 1, "description": "获得等于手牌数 x 2 的护盾", "type": "shield_hand", "value": 2, "rarity": "rare"},
	{"name": "冥想", "emoji": "🧘", "cost": 1, "description": "回复 7 HP，下回合摸鱼力 +1", "type": "heal_ap_next", "value": 7, "rarity": "rare"},
	{"name": "公文包", "emoji": "💼", "cost": 1, "description": "随机获得 1 张当前英雄的专属卡", "type": "draw_hero_card", "value": 1, "rarity": "rare"},
	{"name": "打印文件", "emoji": "📄", "cost": 1, "description": "获得 4 护盾，并将一张 📑 放入弃牌堆", "type": "shield_generate_review", "value": 4, "rarity": "rare"},
	{"name": "快递到了", "emoji": "📦", "cost": 1, "description": "随机获得 2 张通用卡", "type": "delivery_cards", "value": 2, "rarity": "rare"},

	# ── 史诗 (epic) ── 7 张：终结技 / 全局增益 / 特殊机制
	{"name": "扩音器", "emoji": "📣", "cost": 1, "description": "使你的下一次攻击伤害翻倍", "type": "buff_next_attack", "value": 2, "rarity": "epic"},
	{"name": "发工资", "emoji": "💰", "cost": 1, "description": "下回合摸鱼力 +3", "type": "ap_investment", "value": 3, "rarity": "epic"},
	{"name": "团建干杯", "emoji": "🥂", "cost": 1, "description": "本回合所有手牌消耗 -1 (最低为 0)", "type": "cost_reduction", "value": 1, "rarity": "epic"},
	{"name": "存档", "emoji": "💾", "cost": 1, "description": "本回合结束时不弃掉手牌", "type": "save_hand", "rarity": "epic"},
	{"name": "摸鱼洗手", "emoji": "🧼", "cost": 1, "description": "移除自身所有负面状态", "type": "clean_status", "rarity": "epic"},
	{"name": "拔电源", "emoji": "🔌", "cost": 2, "description": "造成 50 伤害，立即结束回合", "type": "pull_plug", "value": 50, "rarity": "epic"},
	{"name": "裁员名单", "emoji": "🔪", "cost": 2, "description": "消耗所有护盾，每点护盾造成 2 倍伤害", "type": "layoff_list", "value": 2, "rarity": "epic"}
]

# ─────────────────────────────────────────
# 稀有度工具函数（供商店 / 宝藏 / 战斗奖励调用）
# ─────────────────────────────────────────
func get_card_rarity(card: Dictionary) -> String:
	## 取卡牌稀有度，未标记则按普通处理
	return card.get("rarity", RARITY_COMMON)

func get_card_price(card: Dictionary) -> int:
	## 根据稀有度生成商店随机定价（与经济系统设计文档一致）
	var rarity := get_card_rarity(card)
	var range_arr: Array = RARITY_PRICE_RANGES.get(rarity, RARITY_PRICE_RANGES["common"])
	var price = randi_range(range_arr[0], range_arr[1])

	# sp_network: 人脉广泛 - 商店价格 -30%
	var meta = _meta_progress_manager()
	if meta and meta.has_upgrade("sp_network"):
		price = int(price * 0.7)

	return price

func get_shop_discount_multiplier() -> float:
	## 商店折扣系数：sp_network 触发时为 0.7，否则 1.0
	var meta = _meta_progress_manager()
	if meta and meta.has_upgrade("sp_network"):
		return 0.7
	return 1.0

func get_cards_by_rarity(rarity: String) -> Array:
	## 按稀有度筛选通用卡池
	var result: Array = []
	for card in universal_cards:
		if card.get("rarity", RARITY_COMMON) == rarity:
			result.append(card.duplicate())
	return result

func roll_card_rarity(common_w: float = 0.65, rare_w: float = 0.28, epic_w: float = 0.07) -> String:
	## 按权重随机抽稀有度。商店/宝藏可以用它决定上架卡的稀有比例。
	var total := common_w + rare_w + epic_w
	var r := randf() * total
	if r < common_w:
		return RARITY_COMMON
	elif r < common_w + rare_w:
		return RARITY_RARE
	return RARITY_EPIC

func draw_random_card_by_rarity(rarity: String) -> Dictionary:
	## 从指定稀有度池中抽一张卡（已 duplicate，可直接放入牌组）
	var pool := get_cards_by_rarity(rarity)
	if pool.is_empty():
		# 兜底回普通池，避免空商店
		pool = get_cards_by_rarity(RARITY_COMMON)
	if pool.is_empty():
		return {}
	return pool[randi() % pool.size()]

# 垃圾卡/诅咒卡定义
var junk_cards = {
	"meeting": {
		"name": "无意义早会",
		"emoji": "📢",
		"cost": 1,
		"description": "打出无效果。不打出则每回合扣 2HP。",
		"type": "junk_meeting",
		"value": 2
	},
	"kpi": {
		"name": "KPI 考核",
		"emoji": "🎯",
		"cost": 99, # 无法打出
		"description": "无法打出。在手牌中时，所有 Combo 卡消耗 +1 AP。",
		"type": "junk_kpi"
	},
	"rambling": {
		"name": "废话连篇",
		"emoji": "💬",
		"cost": 0,
		"description": "打出无效果，只会占用一次出牌节奏。",
		"type": "junk_rambling"
	},
	"printer_jam": {
		"name": "打印机卡纸",
		"emoji": "📰",
		"cost": 99, # 无法打出
		"description": "无法打出。打印机螃蟹每塞入3张会造成一次额外伤害。",
		"type": "junk_printer_jam"
	},
	"goal": {
		"name": "虚假目标",
		"emoji": "🕸️",
		"cost": 1,
		"description": "打出后本回合摸鱼力 -1。不打出则下回合抽牌 -1。",
		"type": "junk_goal"
	}
}

# 随机事件池定义（20 个）
var random_events = {
	"pantry_gossip": {
		"title": "茶水间八卦",
		"desc": "你在茶水间接咖啡时，听到几个同事正在窃窃私语，似乎在讨论关于下个阶段的某种‘变动’..."
	},
	"ppt_help": {
		"title": "同事求助",
		"desc": "邻座的实习生拿着厚厚的一叠文档，可怜兮兮地看着你：‘前辈，这个PPT我实在调不完了，能不能帮帮我？’"
	},
	"emoji_misfire": {
		"title": "群聊手滑",
		"desc": "你在公司大群里吐槽老板，结果不小心点错了一个极其嚣张的表情包，且撤回时间只剩几秒了！"
	},
	"elevator_boss": {
		"title": "饮水机遇老板",
		"desc": "电梯门开了，里面竟然只有老板一个人。在这尴尬的密闭空间里，你必须做出反应。"
	},
	"printer_jam": {
		"title": "打印机卡纸",
		"desc": "打印机发出嘶哑的鸣叫，然后彻底卡死了。一堆废纸塞在出口，而你急用的文件还没印出来。"
	},
	"ac_break": {
		"title": "中央空调故障",
		"desc": "办公室的中央空调突然停止了运转，沉闷闷热的空气迅速在工位间扩散开来，汗水开始打湿衬衫。"
	},
	"mystery_parcel": {
		"title": "神秘快递",
		"desc": "前台通知有你的快递，但你最近并没有买东西。这个神秘的包裹里会装着什么呢？"
	},
	"elevator_encounter": {
		"title": "电梯偶遇",
		"desc": "早高峰的电梯口挤满了人，你正面临一个抉择：是硬挤进去，还是等下一趟？"
	},
	"power_outage": {
		"title": "停电通知",
		"desc": "整栋大楼的灯光突然熄灭，屏幕也瞬间变黑。公司停电了！这是上天给你的某种暗示吗？"
	},
	"blue_screen": {
		"title": "蓝屏瞬间",
		"desc": "你的电脑突然蓝屏了，那一抹刺眼的蓝色伴随着未保存文档的哀鸣，让你的心态濒临崩溃。"
	},
	"old_notes": {
		"title": "旧工位笔记",
		"desc": "你在整理工位时，从抽屉深处翻出了一本前任同事留下的笔记，上面涂满了密密麻麻的符号。"
	},
	"checkup": {
		"title": "体检报告",
		"desc": "公司的年度体检报告发到了你的邮箱。虽然你觉得自己还能加班，但数据或许有不同的看法。"
	},
	"bathroom_break": {
		"title": "带薪如厕",
		"desc": "你在带薪如厕时，隔壁传来了熟悉的游戏音效。看来，这里的摸鱼氛围比你想象的还要浓厚。"
	},
	"caught_slacking": {
		"title": "摸鱼被抓包",
		"desc": "当你正全神贯注地在屏幕上玩连连看时，主管不知何时已经悄无声息地站在了你的身后。"
	},
	"side_job": {
		"title": "私活邀请",
		"desc": "一个猎头在社交平台上私信你，提供了一个酬劳丰厚但极其耗费精力的私活邀请。"
	},
	"trash_treasure": {
		"title": "深夜垃圾桶",
		"desc": "深夜下班时，你路过茶水间的垃圾桶，发现里面塞着一份看起来还没被拆封的数据报表。"
	},
	"mass_test": {
		"title": "全员核酸",
		"desc": "公司通知全员进行核酸检测（或者某种突击体检），长长的队伍已经排到了电梯厅。"
	},
	"broken_chair": {
		"title": "办公椅坏了",
		"desc": "你正要坐下，办公椅突然发出一声脆响，靠背彻底坏了。接下来的日子你可能得‘站’着办公了。"
	},
	"likes": {
		"title": "朋友圈点赞",
		"desc": "你发了一张深夜加班的照片到朋友圈，很快就有几个同事在下面点赞并评论了。"
	},
	"boss_promise": {
		"title": "老板的画饼",
		"desc": "老板把你叫到办公室，语重心长地谈起了公司的未来愿景，顺便递给你一块‘画’得很圆的饼。"
	}
}

# 进化分支定义
var evolution_data = {
	"博姆 (Boomtail)": {
		"7": {
			"A": {"name": "焦土流", "description": "强化 🔥 效果，火大层数翻倍更快", "card": {"name": "烈焰喷射", "emoji": "🔥", "cost": 1, "type": "buff_fire", "value": 3, "description": "目标火大层数变为 3 倍"}},
			"B": {"name": "爆破流", "description": "强化 💣 效果，炸弹基础伤害更高", "card": {"name": "重型松果", "emoji": "💣", "cost": 2, "type": "attack_bomb", "value": 20, "description": "造成 20 伤害。每层火大额外+5"}}
		},
		"8": {
			"A": {"name": "红莲地狱", "description": "终极火系爆发", "card": {"name": "大过滤器", "emoji": "☀️", "cost": 2, "type": "ultimate_fire_filter", "value": 2, "description": "造成 30 基础伤害，引爆当前火大（每层+3）；消灭非火手牌各 +15 伤害 +2 火大"}}
		}
	},
	"墨里 (Inkwell)": {
		"7": {
			"A": {"name": "恐惧流", "description": "强化 🐙 效果，大幅降低敌人攻击", "card": {"name": "深渊恐惧", "emoji": "🐙", "cost": 1, "type": "debuff_atk", "value": 10, "description": "降低老板 10 点攻击力"}},
			"B": {"name": "墨汁流", "description": "强化 🌊 效果，防御与反击并重", "card": {"name": "浓缩墨汁", "emoji": "🌊", "cost": 1, "type": "defense_ink", "value": 15, "description": "获得 15 防御。若触发过 💩，防御变为 3 倍"}}
		},
		"8": {
			"A": {"name": "深海意志", "description": "终极防御反击", "card": {"name": "归于虚无", "emoji": "🌀", "cost": 3, "type": "ultimate_void", "value": 20, "description": "削减老板 20% 耐性上限并回复等量压力"}}
		}
	},
	"莱奥 (Leo)": {
		"7": {
			"A": {"name": "PPT流", "description": "强化 📊 记录效果，数值翻倍", "card": {"name": "精美PPT", "emoji": "📊", "cost": 2, "type": "record_data", "value": 2, "description": "记录上一张牌伤害的 2 倍"}},
			"B": {"name": "资源流", "description": "强化 📈 释放效果，消耗降低", "card": {"name": "资源整合", "emoji": "📈", "cost": 2, "type": "release_data", "value": 2, "description": "释放 📊 记录的数值，消耗 2AP"}}
		},
		"8": {
			"A": {"name": "全宇宙愿景", "description": "终极数据爆发", "card": {"name": "降维打击", "emoji": "🪐", "cost": 3, "type": "ultimate_vision", "value": 0, "description": "爆发所有记录数值，本回合所有卡牌 0 消耗"}}
		}
	},
	"苏珊 (Susan)": {
		"7": {
			"A": {"name": "禁令流", "description": "强化 ❌ 封印效果", "card": {"name": "绝对禁令", "emoji": "❌", "cost": 2, "type": "cancel_intent", "value": 2, "description": "消除老板意图，且下回合老板也发呆"}},
			"B": {"name": "待岗流", "description": "强化 ⏳ 防御效果", "card": {"name": "长期待岗", "emoji": "⏳", "cost": 1, "type": "wait_defense", "value": 40, "description": "下回合不行动，获得 40 点超高防御"}}
		},
		"8": {
			"A": {"name": "行业黑名单", "description": "终极规则裁决", "card": {"name": "终极裁决", "emoji": "🚫", "cost": 3, "type": "ultimate_blacklist", "value": 2, "description": "封印老板 3 回合，期间无法行动且每回合受罚 20 点违约金；封印到期后自动解除"}}
		}
	}
}
