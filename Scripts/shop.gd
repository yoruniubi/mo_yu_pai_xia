extends Node

# ─────────────────────────────────────────
#  商店场景 ShopScene.gd
#  依赖：GameManager（全局单例）持有：
#    - game_manager.mo_yu_coins : int        摸鱼币
#    - game_manager.player_deck : Array      当前牌组（Array of Dictionary）
#    - game_manager.universal_cards : Array   通用卡池（Array of Dictionary）
#    - game_manager.selected_hero.card_pool   英雄专属卡池（Array of Dictionary）
# ─────────────────────────────────────────

# ── UI 节点引用（在 _ready 里绑定） ──
@onready var hp_label         : Label       = $UI/TopBar/TopHBox/HpLabel
@onready var coin_label       : Label       = $UI/TopBar/TopHBox/CoinLabel
@onready var card_grid        : GridContainer = $UI/ShopPanel/CardGrid
@onready var leave_button     : Button      = $UI/BottomBar/LeaveButton
@onready var confirm_popup    : AcceptDialog = $UI/ConfirmPopup
@onready var toast_label      : Label       = $UI/Toast          # 短暂提示

# ── 商店配置 ──
const SHOP_CARD_COUNT   : int = 6      # 每次刷新展示的卡牌数量：2列 × 3行
const DELETE_PRICE      : int = 15     # 删牌固定价格
const REFRESH_PRICE     : int = 10     # 刷新商店价格
const BUTTON_BG         : Color = Color("#fdf5e6")
const BUTTON_BORDER     : Color = Color("#cfb896")
const BUTTON_TEXT       : Color = Color("#6a4f3b")
const BUTTON_MUTED      : Color = Color("#a68b73")
const CARD_COMMON_BG    : Color = Color("#fdf5e6")
const CARD_RARE_BG      : Color = Color("#d7dcf4")
const CARD_EPIC_BG      : Color = Color("#f3e2ff")

# ── 内部状态 ──
var shop_cards      : Array = []       # 当前上架的卡牌 [{card: Dictionary, price: int, sold: bool}]
var pending_action  : Callable         # 等待确认的操作

# ══════════════════════════════════════════
func _ready() -> void:
	var bgm = preload("res://Assets/Music/shop_bgm.mp3")
	BgmManager.play_music(bgm)

	leave_button.pressed.connect(_on_leave)
	_setup_button_style(leave_button, 28, true, Vector2(360, 100))
	_setup_cash_machine()
	_refresh_shop(true)          
	_update_coin_display()
	_setup_header_buttons()

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

# ══════════════════════════════════════════
#  摸鱼币显示
# ══════════════════════════════════════════
func _update_coin_display() -> void:
	coin_label.text = "🪙 摸鱼币：%d" % GameManager.mo_yu_coins
	hp_label.text  = "❤️ %d / %d" % [GameManager.player_hp, GameManager.max_player_hp]
# ══════════════════════════════════════════
#  商店卡牌区
# ══════════════════════════════════════════
func _refresh_shop(is_free: bool = false) -> void:
	if not is_free:
		if GameManager.mo_yu_coins < REFRESH_PRICE:
			_show_toast("摸鱼币不足，无法刷新！")
			return
		GameManager.mo_yu_coins -= REFRESH_PRICE
		_update_coin_display()

	# 构建全卡池（通用 + 英雄专属），按稀有度权重随机抽取
	var pool : Array = _build_shop_pool()
	shop_cards.clear()
	for i in range(min(SHOP_CARD_COUNT, pool.size())):
		var idx  = randi() % pool.size()
		var card = pool[idx]
		pool.remove_at(idx)
		shop_cards.append({
			"card":   card,
			"price":  GameManager.get_card_price(card),
			"sold":   false
		})

	_build_shop_grid()


func _setup_cash_machine() -> void:
	if has_node("UI/CashMachine"):
		return

	var cash_machine := TextureRect.new()
	cash_machine.name = "CashMachine"
	cash_machine.texture = preload("res://Assets/Images/cash_machine.png")
	cash_machine.position = Vector2(250, 1200) # x 越大越往右，y 越小越往上
	cash_machine.custom_minimum_size = Vector2(420, 420)
	cash_machine.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	cash_machine.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cash_machine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(cash_machine)
	$UI.move_child(cash_machine, 2) # 放在 Background 上面、商店 UI 下面

	var tween := create_tween().set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(cash_machine, "position:y", cash_machine.position.y - 8.0, 0.8)
	tween.tween_property(cash_machine, "position:y", cash_machine.position.y, 0.8)

func _build_shop_pool() -> Array:
	## 从通用卡池 + 英雄专属卡池中筛选可购买的卡
	## 排除已在牌组中数量 >=2 的卡
	var pool : Array = []

	# 通用卡池
	for card in GameManager.universal_cards:
		var card_name = card.get("name", "")
		var count = _count_cards_in_deck(card_name)
		if count < 2:
			pool.append(card)

	# 英雄专属卡池
	if GameManager.selected_hero:
		for card in GameManager.selected_hero.card_pool:
			var card_name = card.get("name", "")
			var count = _count_cards_in_deck(card_name)
			if count < 2:
				pool.append(card)

	return pool


func _count_cards_in_deck(card_name: String) -> int:
	## 按卡名统计牌组中的数量
	var count = 0
	for c in GameManager.player_deck:
		if c.get("name", "") == card_name:
			count += 1
	return count


func _build_shop_grid() -> void:
	# 清空旧节点
	for child in card_grid.get_children():
		child.queue_free()

	for entry in shop_cards:
		var card = entry["card"]
		var btn = _make_card_button(card, entry["price"], entry["sold"])
		var captured_entry = entry          # 闭包捕获
		btn.pressed.connect(func():
			_try_buy_card(captured_entry)
		)
		card_grid.add_child(btn)

	# 刷新按钮
	var refresh_btn = Button.new()
	refresh_btn.text  = "🔄 刷新商品（%d币）" % REFRESH_PRICE
	refresh_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	refresh_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_setup_button_style(refresh_btn, 30, true, Vector2(360, 140))
	refresh_btn.pressed.connect(func(): _refresh_shop(false))
	card_grid.add_child(refresh_btn)

	_add_delete_service_button_to_shop_grid()


func _make_card_button(card: Dictionary, price: int, sold: bool) -> Button:
	var btn = Button.new()
	var emoji = card.get("emoji",  "❓")
	var name_ = card.get("name",   "未知卡")
	var desc  = card.get("description", "")
	var rarity = card.get("rarity", "common")
	var rarity_label = {"common": "普通", "rare": "稀有", "epic": "史诗"}.get(rarity, "")
	btn.text = "%s %s\n%s\n🌟 稀有度：%s\n🪙 %d" % [emoji, name_, desc, rarity_label, price]
	btn.disabled = sold or GameManager.mo_yu_coins < price
	btn.tooltip_text = "%s [%s]\n%s" % [name_, rarity_label, desc]
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_setup_button_style(btn, 30, false, Vector2(360, 220), _rarity_to_bg_color(rarity))
	return btn


# ── 购买逻辑 ──
func _try_buy_card(entry: Dictionary) -> void:
	if entry["sold"]:
		return
	if GameManager.mo_yu_coins < entry["price"]:
		_show_toast("摸鱼币不足！")
		return

	var card = entry["card"]
	pending_action = func():
		GameManager.mo_yu_coins -= entry["price"]
		entry["sold"] = true
		# 将卡牌副本加入牌组（与 initialize_deck 一致使用 duplicate）
		GameManager.player_deck.append(card.duplicate())
		_update_coin_display()
		_build_shop_grid()
		_show_toast("获得：%s %s" % [card.get("emoji", ""), card.get("name", "")])

	confirm_popup.title        = "确认购买？"
	confirm_popup.dialog_text  = "花费 %d 摸鱼币购买【%s】？" % [entry["price"], card.get("name", "")]
	confirm_popup.confirmed.connect(_execute_pending, CONNECT_ONE_SHOT)
	GameManager.popup_confirm_dialog(confirm_popup)

# ══════════════════════════════════════════
#  删牌入口：商品区只放一个按钮，点击后打开 GameManager.show_deck_viewer
# ══════════════════════════════════════════
func _add_delete_service_button_to_shop_grid() -> void:
	var delete_btn := Button.new()
	delete_btn.text = "🗑 删牌服务\n打开牌库选择要删除的卡（%d币/张）" % DELETE_PRICE
	delete_btn.disabled = GameManager.mo_yu_coins < DELETE_PRICE or GameManager.player_deck.size() <= 5
	delete_btn.tooltip_text = "点击后弹出牌库，再点对应卡牌下方的“丢弃”删除。"
	delete_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	delete_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_setup_button_style(delete_btn, 29, true, Vector2(360, 140))
	delete_btn.pressed.connect(_open_paid_delete_viewer)
	card_grid.add_child(delete_btn)


func _open_paid_delete_viewer() -> void:
	if GameManager.mo_yu_coins < DELETE_PRICE:
		_show_toast("摸鱼币不足，无法删牌！")
		return
	if GameManager.player_deck.size() <= 5:
		_show_toast("牌组至少保留 5 张！")
		return

	GameManager.show_deck_viewer(self, true, func():
		GameManager.mo_yu_coins -= DELETE_PRICE
		_update_coin_display()
		_build_shop_grid()
		_show_toast("已支付 %d 摸鱼币，删除了一张卡。" % DELETE_PRICE)
	)

# ══════════════════════════════════════════
#  通用工具
# ══════════════════════════════════════════
func _execute_pending() -> void:
	if pending_action:
		pending_action.call()
		pending_action = Callable()

func _show_toast(msg: String) -> void:
	toast_label.text    = msg
	toast_label.visible = true
	await get_tree().create_timer(2.0).timeout
	toast_label.visible = false

func _on_leave() -> void:
	get_tree().change_scene_to_file("res://Scenes/map.tscn")

func _setup_button_style(button: Button, font_size: int = 34, is_primary: bool = false, custom_size: Vector2 = Vector2(220, 200), bg_color: Color = BUTTON_BG) -> void:
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
	normal_style.bg_color = bg_color if not is_primary else Color("#f7ead7")
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
