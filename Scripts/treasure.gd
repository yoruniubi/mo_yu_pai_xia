extends Node

# ─────────────────────────────────────────
#  宝藏场景 TreasureScene.gd
#  进入后自动发放：
#    - 随机摸鱼币（根据当前层数浮动）
#    - 三选一随机卡牌（玩家选一张加入牌组）
#
#  依赖 GameManager 单例持有：
#    - mo_yu_coins   : int
#    - player_deck   : Array[Dictionary]
#    - universal_cards / selected_hero.card_pool
#    - current_level : int
# ─────────────────────────────────────────

# ── UI 节点引用 ──
@onready var hp_label      : Label         = $UI/TopBar/TopHBox/HpLabel
@onready var coin_label    : Label         = $UI/TopBar/TopHBox/CoinLabel
@onready var reward_label  : Label         = $UI/RewardLabel      
@onready var card_grid     : HBoxContainer = $UI/TreasurePanel/CardGrid         
@onready var skip_button   : Button        = $UI/BottomBar/SkipBtn 
@onready var leave_button  : Button        = $UI/BottomBar/LeaveBtn
@onready var toast_label   : Label         = $UI/Toast

# ── 常量 ──
const COIN_BASE   : int = 40     # 基础摸鱼币
const COIN_PER_FL : int = 10     # 每层额外加成
const COIN_RAND   : int = 30     # 随机浮动范围（±15）
const CARD_PICKS  : int = 3      # 展示几张牌供选择
const BUTTON_BG       : Color = Color("#fdf5e6")
const BUTTON_BORDER   : Color = Color("#cfb896")
const BUTTON_TEXT     : Color = Color("#6a4f3b")
const BUTTON_MUTED    : Color = Color("#a68b73")
const CARD_COMMON_BG  : Color = Color("#fdf5e6")
const CARD_RARE_BG    : Color = Color("#d7dcf4")
const CARD_EPIC_BG    : Color = Color("#f3e2ff")

# ── 内部状态 ──
var card_chosen : bool = false   # 是否已选牌
var treasure_opened : bool = false
var treasure_box_button : TextureButton

# ══════════════════════════════════════════
func _ready() -> void:
	var bgm = preload("res://Assets/Music/treasure_bgm.mp3")
	BgmManager.play_music(bgm)

	skip_button.pressed.connect(_on_skip)
	leave_button.pressed.connect(_on_leave)
	leave_button.disabled = true   # 选牌或跳过前不能离开
	_setup_button_style(skip_button, 28, true, Vector2(300, 100))
	_setup_button_style(leave_button, 28, true, Vector2(300, 100))
	_setup_label_style()

	_give_coins()
	_update_coin_display()
	_setup_header_buttons()
	_setup_open_treasure_animation()

func _setup_open_treasure_animation() -> void:
	# 这个函数负责打开箱子，弹出三选一奖励卡的动画
	var box_closed := preload("res://Assets/Images/treasure_box_closed.png")
	var box_opened := preload("res://Assets/Images/treasure_box_opened.png")

	card_grid.visible = false
	skip_button.disabled = true

	treasure_box_button = TextureButton.new()
	treasure_box_button.name = "TreasureBoxButton"
	treasure_box_button.texture_normal = box_closed
	treasure_box_button.texture_hover = box_closed
	treasure_box_button.texture_pressed = box_closed
	treasure_box_button.ignore_texture_size = true
	treasure_box_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	treasure_box_button.custom_minimum_size = Vector2(960, 780)
	treasure_box_button.set_anchors_preset(Control.PRESET_CENTER)
	treasure_box_button.offset_left = -480
	treasure_box_button.offset_top = -390
	treasure_box_button.offset_right = 480
	treasure_box_button.offset_bottom = 390
	treasure_box_button.pivot_offset = Vector2(480, 390)
	treasure_box_button.z_index = 50
	treasure_box_button.pressed.connect(func(): _open_treasure_box(box_opened))
	$UI.add_child(treasure_box_button)

	var idle_tween := create_tween().set_loops()
	idle_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	idle_tween.tween_property(treasure_box_button, "position:y", treasure_box_button.position.y - 10.0, 0.8)
	idle_tween.tween_property(treasure_box_button, "position:y", treasure_box_button.position.y, 0.8)


func _open_treasure_box(box_opened: Texture2D) -> void:
	if treasure_opened:
		return
	treasure_opened = true
	treasure_box_button.disabled = true
	treasure_box_button.texture_normal = box_opened
	treasure_box_button.texture_hover = box_opened
	treasure_box_button.texture_pressed = box_opened

	var open_tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	open_tween.tween_property(treasure_box_button, "scale", Vector2(1.12, 1.12), 0.16)
	open_tween.tween_property(treasure_box_button, "scale", Vector2(1.0, 1.0), 0.14)
	await open_tween.finished

	var fade_tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fade_tween.tween_property(treasure_box_button, "modulate:a", 0.0, 0.25)
	await fade_tween.finished
	treasure_box_button.visible = false

	_build_card_picks()
	card_grid.visible = true
	skip_button.disabled = false
	_start_card_float_animation()


func _start_card_float_animation() -> void:
	for i in range(card_grid.get_child_count()):
		var child := card_grid.get_child(i)
		if child is Control:
			child.pivot_offset = child.size / 2.0
			var base_y: float = child.position.y
			child.position.y = base_y + 18.0
			child.modulate.a = 0.0

			var appear_tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			appear_tween.tween_interval(i * 0.08)
			appear_tween.tween_property(child, "position:y", base_y, 0.28)
			appear_tween.parallel().tween_property(child, "modulate:a", 1.0, 0.22)

			var float_tween := create_tween().set_loops()
			float_tween.tween_interval(0.4 + i * 0.12)
			float_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			float_tween.tween_property(child, "position:y", base_y - 8.0, 0.9)
			float_tween.tween_property(child, "position:y", base_y, 0.9)


func _setup_header_buttons() -> void:
	var bb = Button.new()
	bb.text = "↩"
	bb.offset_left = 21
	bb.offset_top = 36
	bb.offset_right = 105
	bb.offset_bottom = 120
	bb.add_theme_font_size_override("font_size", 39)
	_style_header_button(bb)
	bb.pressed.connect(func(): get_tree().change_scene_to_file("res://Scenes/main_menu.tscn"))
	$UI.add_child(bb)

	var db = Button.new()
	db.text = "🗃️"
	db.anchor_left = 1.0
	db.anchor_right = 1.0
	db.offset_left = -105
	db.offset_top = 36
	db.offset_right = -21
	db.offset_bottom = 120
	db.add_theme_font_size_override("font_size", 36)
	_style_header_button(db)
	db.pressed.connect(func(): GameManager.show_deck_viewer(self))
	$UI.add_child(db)

func _style_header_button(btn: Button) -> void:
	btn.z_index = 200
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color("#2F4654")
	normal.set_corner_radius_all(10)
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.border_color = Color("#F1D39A55")
	btn.add_theme_stylebox_override("normal", normal)

	var hover = normal.duplicate()
	hover.bg_color = Color("#416174")
	btn.add_theme_stylebox_override("hover", hover)

	var pressed = normal.duplicate()
	pressed.bg_color = Color("#20313B")
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color("#F8F1E3"))

func _setup_label_style() -> void:
	reward_label.add_theme_color_override("font_color", BUTTON_TEXT)
	hp_label.add_theme_color_override("font_color", Color.WHITE)
	coin_label.add_theme_color_override("font_color", Color.WHITE)
	toast_label.add_theme_color_override("font_color", BUTTON_TEXT)

func _setup_button_style(button: Button, font_size: int = 30, is_primary: bool = false, custom_size: Vector2 = Vector2(260, 200), bg_color: Color = BUTTON_BG) -> void:
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", BUTTON_TEXT)
	button.add_theme_color_override("font_hover_color", BUTTON_TEXT.darkened(0.08))
	button.add_theme_color_override("font_pressed_color", BUTTON_TEXT.darkened(0.14))
	button.add_theme_color_override("font_disabled_color", BUTTON_MUTED)
	button.add_theme_constant_override("h_separation", 12)
	button.custom_minimum_size = Vector2(
		max(button.custom_minimum_size.x, custom_size.x),
		max(button.custom_minimum_size.y, custom_size.y)
	)

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color("#f7ead7") if is_primary else bg_color
	normal_style.border_color = BUTTON_BORDER
	normal_style.border_width_left = 2
	normal_style.border_width_top = 2
	normal_style.border_width_right = 2
	normal_style.border_width_bottom = 6
	normal_style.set_corner_radius_all(30)
	normal_style.shadow_color = Color(0.45, 0.34, 0.24, 0.12)
	normal_style.shadow_size = 8
	normal_style.content_margin_left = 24
	normal_style.content_margin_right = 24
	normal_style.content_margin_top = 18
	normal_style.content_margin_bottom = 18

	var hover_style := normal_style.duplicate()
	hover_style.bg_color = normal_style.bg_color.lightened(0.15)
	hover_style.border_color = BUTTON_BORDER.lightened(0.20)
	hover_style.shadow_size = 12
	

	var pressed_style := normal_style.duplicate()
	pressed_style.bg_color = Color("#f3e4cf")
	pressed_style.border_color = BUTTON_BORDER.darkened(0.12)
	pressed_style.shadow_size = 1
	pressed_style.content_margin_top = 22
	pressed_style.content_margin_bottom = 14

	var disabled_style := normal_style.duplicate()
	disabled_style.bg_color = Color("#eee3d2")
	disabled_style.border_color = Color("#c9b69d")
	disabled_style.shadow_size = 0

	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("disabled", disabled_style)
	button.add_theme_stylebox_override("focus", hover_style)

	# hover 放大效果
	button.mouse_entered.connect(func():
		var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(button, "scale", Vector2(1.06, 1.06), 0.15)
	)
	button.mouse_exited.connect(func():
		var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(button, "scale", Vector2(1.0, 1.0), 0.15)
	)

# ══════════════════════════════════════════
#  摸鱼币奖励
# ══════════════════════════════════════════
func _give_coins() -> void:
	var floor_bonus = GameManager.current_level * COIN_PER_FL
	@warning_ignore("integer_division")
	var random_part = randi_range(-COIN_RAND / 2, COIN_RAND / 2)
	var amount = max(COIN_BASE + floor_bonus + random_part, COIN_BASE)

	GameManager.add_gold(amount)
	reward_label.text = "💰 发现摸鱼基金！获得 %d 摸鱼币" % amount
	reward_label.add_theme_font_size_override("font_size", 32)
func _update_coin_display() -> void:
	hp_label.text = "❤️ %d / %d" % [GameManager.player_hp, GameManager.max_player_hp]
	coin_label.text = "🪙 摸鱼币：%d" % GameManager.mo_yu_coins

# ══════════════════════════════════════════
#  三选一卡牌
# ══════════════════════════════════════════
func _build_card_picks() -> void:
	for child in card_grid.get_children():
		child.queue_free()

	var picks: Array = _build_reward_picks()
	if picks.is_empty():
		# 卡池耗尽，直接允许离开
		var lbl = Label.new()
		lbl.text = "（卡池已满，无可选卡牌）"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 34)
		lbl.add_theme_color_override("font_color", BUTTON_TEXT)
		card_grid.add_child(lbl)
		_unlock_leave()
		return

	for card_data in picks:
		var btn = _make_card_button(card_data)
		card_grid.add_child(btn)

func _build_reward_picks() -> Array:
	# 以当前新版卡牌结构构建奖励池：通用卡 + 当前英雄卡池
	# 排除牌组里已拥有 >= 2 张的同名卡，最后随机抽 3 张
	var pool: Array = []
	for card in GameManager.universal_cards:
		if _count_card_in_deck(card) < 2:
			pool.append(card.duplicate())

	if GameManager.selected_hero:
		for card in GameManager.selected_hero.card_pool:
			if _count_card_in_deck(card) < 2:
				pool.append(card.duplicate())

	pool.shuffle()
	var picks: Array = []
	for i in range(min(CARD_PICKS, pool.size())):
		picks.append(pool[i].duplicate())
	return picks

func _count_card_in_deck(target_card: Dictionary) -> int:
	var target_name: String = String(target_card.get("name", ""))
	var count := 0
	for card in GameManager.player_deck:
		if card is Dictionary and card.get("name", "") == target_name:
			count += 1
	return count

func _make_card_button(card_data: Dictionary) -> Button:
	var btn    = Button.new()
	var emoji  = card_data.get("emoji",  "❓")
	var name_  = card_data.get("name",   "未知卡牌")
	var effect = card_data.get("description", "")
	var rarity = _rarity_to_text(card_data.get("rarity", GameManager.RARITY_COMMON))

	btn.text         = ""
	btn.tooltip_text = effect
	btn.alignment    = HORIZONTAL_ALIGNMENT_CENTER
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.size_flags_vertical   = Control.SIZE_SHRINK_CENTER

	_setup_button_style(btn, 38, false, Vector2(320, 440), _rarity_to_bg_color(card_data.get("rarity", GameManager.RARITY_COMMON)))

	# 必须先 setup_button_style 设好尺寸，再创建 label 跟随
	var label = RichTextLabel.new()
	label.bbcode_enabled        = true
	label.fit_content           = false
	label.scroll_active         = false
	label.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	label.anchor_left           = 0.0
	label.anchor_top            = 0.0
	label.anchor_right          = 1.0
	label.anchor_bottom         = 1.0
	label.offset_left           = 8.0
	label.offset_top            = 8.0
	label.offset_right          = -8.0
	label.offset_bottom         = -8.0
	label.text = "[center][font_size=72]%s[/font_size]\n[font_size=30]%s[/font_size]\n\n[font_size=30]%s[/font_size]\n\n[font_size=28]【%s】[/font_size][/center]" % [emoji, name_, effect, rarity]
	label.add_theme_color_override("default_color", BUTTON_TEXT)
	btn.add_child(label)

	var captured = card_data.duplicate()
	btn.pressed.connect(func(): _pick_card(captured))
	return btn

func _pick_card(card_data: Dictionary) -> void:
	if card_chosen:
		return
	card_chosen = true

	GameManager.player_deck.append(card_data.duplicate())

	# 禁用所有选牌按钮
	for child in card_grid.get_children():
		if child is Button:
			child.disabled = true

	skip_button.disabled = true
	_unlock_leave()

	var name_ = card_data.get("name", "未知卡牌")
	var emoji = card_data.get("emoji", "")
	_show_toast("获得：%s %s！加入牌组" % [emoji, name_])

# ══════════════════════════════════════════
#  跳过选牌
# ══════════════════════════════════════════
func _on_skip() -> void:
	if card_chosen:
		return
	card_chosen = true
	skip_button.disabled = true

	# 跳过奖励：额外给一点摸鱼币
	var bonus = 20
	GameManager.add_gold(bonus)
	_update_coin_display()
	_unlock_leave()
	_show_toast("跳过选牌，额外获得 %d 摸鱼币作为补偿！" % bonus)

# ══════════════════════════════════════════
#  导航
# ══════════════════════════════════════════
func _unlock_leave() -> void:
	leave_button.disabled = false

func _on_leave() -> void:
	# 接入 Map 时替换路径
	get_tree().change_scene_to_file("res://Scenes/map.tscn")


# ══════════════════════════════════════════
#  工具
# ══════════════════════════════════════════
func _show_toast(msg: String) -> void:
	toast_label.text    = msg
	toast_label.add_theme_font_size_override("font_size", 34)
	toast_label.visible = true
	await get_tree().create_timer(2.5).timeout
	toast_label.visible = false

func _rarity_to_text(rarity: String) -> String:
	match rarity:
		GameManager.RARITY_COMMON:
			return "普通"
		GameManager.RARITY_RARE:
			return "稀有"
		GameManager.RARITY_EPIC:
			return "史诗"
		_:
			return rarity

func _rarity_to_bg_color(rarity: String) -> Color:
	match rarity:
		GameManager.RARITY_COMMON:
			return CARD_COMMON_BG
		GameManager.RARITY_RARE:
			return CARD_RARE_BG
		GameManager.RARITY_EPIC:
			return CARD_EPIC_BG
		_:
			return CARD_COMMON_BG