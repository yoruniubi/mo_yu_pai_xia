extends Node

# ─────────────────────────────────────────
#  休息场景 RestScene.gd
# ─────────────────────────────────────────

@onready var hp_label        : Label          = $UI/TopBar/TopHBox/HpLabel
@onready var action_panel    : GridContainer  = $UI/ActionPanel
@onready var work_panel      : Control        = $UI/WorkPanel
@onready var work_grid       : GridContainer  = $UI/WorkPanel/Scroll/Grid
@onready var work_title      : Label          = $UI/WorkPanel/Title
@onready var back_button     : Button         = $UI/WorkPanel/BackBtn
@onready var leave_button    : Button         = $UI/BottomBar/LeaveBtn
@onready var toast_label     : Label          = $UI/Toast
@onready var confirm_popup   : AcceptDialog   = $UI/ConfirmPopup
@onready var moyu_coin       : Label          = $UI/TopBar/TopHBox/MoyuCoin
@onready var coffee_anchor : Node2D = $UI/CoffeeAnchor

const HEAL_PERCENT   : float = 0.30
const MIN_DECK_SIZE  : int   = 5
const BUTTON_BG      : Color = Color("#fdf5e6")
const BUTTON_HOVER   : Color = Color("#fffaf1")
const BUTTON_BORDER  : Color = Color("#cfb896")
const BUTTON_TEXT    : Color = Color("#6a4f3b")
const BUTTON_MUTED   : Color = Color("#a68b73")

var current_mode     : String = ""
var action_used      : bool   = false
var pending_action   : Callable
var work_backdrop    : ColorRect

# ══════════════════════════════════════════
func _ready() -> void:
	var bgm = preload("res://Assets/Music/rest_bgm.mp3")
	BgmManager.play_music(bgm)

	work_panel.visible = false
	back_button.pressed.connect(_back_to_actions)
	leave_button.pressed.connect(_on_leave)
	_setup_button_style(leave_button, 28, true, Vector2(360, 100))
	_setup_work_panel_style()
	GameManager.style_confirm_dialog(confirm_popup)
	_update_hp_display()
	_build_action_panel()
	_setup_coffee_scene()
	_setup_header_buttons()

func _setup_work_panel_style() -> void:
	# WorkPanel 是升级/删牌选择界面的前景面板：加不透明背景，盖住咖啡杯和热气。
	work_backdrop = ColorRect.new()
	work_backdrop.name = "WorkPanelBackdrop"
	work_backdrop.color = Color("#f9efd9")
	# 只作为视觉背景，不能拦截卡牌按钮和返回按钮的点击。
	work_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	work_backdrop.visible = false
	work_backdrop.z_index = 79
	work_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	work_backdrop.offset_left = 54
	work_backdrop.offset_top = 180
	work_backdrop.offset_right = -54
	work_backdrop.offset_bottom = -138
	$UI.add_child(work_backdrop)

	work_panel.z_index = 80
	var panel_bg := StyleBoxFlat.new()
	panel_bg.bg_color = Color("#f9efd9")
	panel_bg.border_color = BUTTON_BORDER
	panel_bg.border_width_left = 2
	panel_bg.border_width_top = 2
	panel_bg.border_width_right = 2
	panel_bg.border_width_bottom = 6
	panel_bg.set_corner_radius_all(28)
	panel_bg.shadow_color = Color(0.35, 0.25, 0.16, 0.16)
	panel_bg.shadow_size = 10
	panel_bg.content_margin_left = 26
	panel_bg.content_margin_right = 26
	panel_bg.content_margin_top = 24
	panel_bg.content_margin_bottom = 24
	work_panel.add_theme_stylebox_override("panel", panel_bg)

	work_title.add_theme_font_size_override("font_size", 34)
	work_title.add_theme_color_override("font_color", BUTTON_TEXT)
	work_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	work_grid.columns = 2
	work_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	work_grid.add_theme_constant_override("h_separation", 18)
	work_grid.add_theme_constant_override("v_separation", 18)

	# 返回按钮不要铺满整行，缩成一个居中的小按钮。
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_setup_button_style(back_button, 30, true, Vector2(320, 76))

func _setup_confirm_popup_style() -> void:
	GameManager.style_confirm_dialog(confirm_popup)

func _popup_confirm_centered() -> void:
	GameManager.popup_confirm_dialog(confirm_popup)

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
#  咖啡杯 + 热气（绑定在同一个父节点下）
# ══════════════════════════════════════════
func _setup_coffee_scene() -> void:
	# 位置直接在 tscn 里的 CoffeeAnchor 上设，这里只负责加子节点
	var cup = TextureRect.new()
	cup.texture = preload("res://Assets/Images/rest_cup.png")
	cup.custom_minimum_size = Vector2(360, 360)
	cup.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	cup.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cup.position = Vector2(-240, -250)   
	coffee_anchor.add_child(cup)

	var offsets = [Vector2(-30, -130), Vector2(0, -130), Vector2(30, -130)]
	var delays  = [0.0, 0.4, 0.8]
	for i in range(3):
		var wisp = Node2D.new()
		wisp.set_script(load("res://Scripts/SteamWisp.gd"))
		wisp.position = offsets[i]
		coffee_anchor.add_child(wisp)
		_animate_wisp(wisp, delays[i])

func _animate_wisp(node: Node2D, delay: float) -> void:
	var start_pos = node.position
	# 每缕热气有微小的左右漂移，-1/0/1 对应左中右
	var drift_x = (node.get_index() - 1) * 8.0
	var tween = create_tween().set_loops()
	tween.tween_interval(delay)
	tween.tween_callback(func():
		node.position = start_pos
		node.modulate.a = 0.85
	)
	tween.tween_property(node, "position", 
		Vector2(start_pos.x + drift_x, start_pos.y - 70.0), 2.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(node, "modulate:a", 0.0, 2.5)
# ══════════════════════════════════════════
#  顶部 HP 显示
# ══════════════════════════════════════════
func _update_hp_display() -> void:
	hp_label.text  = "❤️ %d / %d" % [GameManager.player_hp, GameManager.max_player_hp]
	moyu_coin.text = "🪙 %d" % GameManager.mo_yu_coins

# ══════════════════════════════════════════
#  三个行动按钮（竖排，单列）
# ══════════════════════════════════════════
func _build_action_panel() -> void:
	action_panel.columns = 1   # 1列竖排，避免按钮文字横向溢出屏幕
	for child in action_panel.get_children():
		child.queue_free()

	var actions = [
		{
			"key":   "heal",
			"icon":  "☕",
			"title": "带薪喝咖啡",
			"desc":  "回复 %d HP（当前最大HP的30%%）" % _calc_heal(),
		},
		{
			"key":   "upgrade",
			"icon":  "⬆️",
			"title": "深夜充电",
			"desc":  "选择一张牌并将其升级",
		},
		{
			"key":   "delete",
			"icon":  "🗑",
			"title": "断舍离",
			"desc":  "免费永久删除一张牌",
		},
	]

	for action in actions:
		var btn = Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var used_suffix = "（已使用）" if (action_used and action["key"] != "view") else ""
		btn.text = "%s  %s%s\n%s" % [action["icon"], action["title"], used_suffix, action["desc"]]
		btn.disabled  = action_used and action["key"] != "view"
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_setup_button_style(btn)
		var captured_key = action["key"]
		btn.pressed.connect(func(): _on_action_selected(captured_key))
		action_panel.add_child(btn)

# ══════════════════════════════════════════
#  按钮样式
# ══════════════════════════════════════════
func _setup_button_style(button: Button, font_size: int = 34, is_primary: bool = false, custom_size: Vector2 = Vector2(220, 200)) -> void:
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", BUTTON_TEXT)
	button.add_theme_color_override("font_hover_color", BUTTON_TEXT.darkened(0.08))
	button.add_theme_color_override("font_pressed_color", BUTTON_TEXT.darkened(0.14))
	button.add_theme_color_override("font_disabled_color", BUTTON_MUTED)
	button.add_theme_constant_override("h_separation", 12)
	button.add_theme_constant_override("outline_size", 0)
	button.custom_minimum_size = Vector2(
		max(button.custom_minimum_size.x, custom_size.x),
		max(button.custom_minimum_size.y, custom_size.y)
	)

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color            = BUTTON_BG if not is_primary else Color("#f7ead7")
	normal_style.border_color        = BUTTON_BORDER
	normal_style.border_width_left   = 2
	normal_style.border_width_top    = 2
	normal_style.border_width_right  = 2
	normal_style.border_width_bottom = 6
	normal_style.corner_radius_top_left     = 30
	normal_style.corner_radius_top_right    = 30
	normal_style.corner_radius_bottom_right = 30
	normal_style.corner_radius_bottom_left  = 30
	normal_style.shadow_color        = Color(0.45, 0.34, 0.24, 0.12)
	normal_style.shadow_size         = 8
	normal_style.content_margin_left   = 24
	normal_style.content_margin_right  = 24
	normal_style.content_margin_top    = 18
	normal_style.content_margin_bottom = 18

	var hover_style := normal_style.duplicate()
	hover_style.bg_color     = BUTTON_HOVER if not is_primary else Color("#fbf1e3")
	hover_style.border_color = BUTTON_BORDER.lightened(0.08)
	hover_style.shadow_size  = 8

	var pressed_style := normal_style.duplicate()
	pressed_style.bg_color            = Color("#f3e4cf")
	pressed_style.border_color        = BUTTON_BORDER.darkened(0.12)
	pressed_style.shadow_size         = 1
	pressed_style.content_margin_top    = 22
	pressed_style.content_margin_bottom = 14

	var disabled_style := normal_style.duplicate()
	disabled_style.bg_color     = Color("#eee3d2")
	disabled_style.border_color = Color("#c9b69d")
	disabled_style.shadow_size  = 0

	button.add_theme_stylebox_override("normal",   normal_style)
	button.add_theme_stylebox_override("hover",    hover_style)
	button.add_theme_stylebox_override("pressed",  pressed_style)
	button.add_theme_stylebox_override("disabled", disabled_style)
	button.add_theme_stylebox_override("focus",    hover_style)

# ── 行动选择入口 ──
func _on_action_selected(key: String) -> void:
	current_mode = key
	match key:
		"heal":
			_do_heal()
		"upgrade":
			_show_card_picker("升级哪张牌？", _upgrade_card)
		"delete":
			_show_card_picker("删除哪张牌？", _delete_card)
		"view":
			_show_card_viewer()

# ══════════════════════════════════════════
#  A. 回复 HP
# ══════════════════════════════════════════
func _calc_heal() -> int:
	return int(GameManager.max_player_hp * HEAL_PERCENT)

func _do_heal() -> void:
	var amount = _calc_heal()
	GameManager.player_hp = min(
		GameManager.player_hp + amount,
		GameManager.max_player_hp
	)
	action_used = true
	_update_hp_display()
	_build_action_panel()
	_show_toast("喝了杯咖啡，恢复了 %d HP！" % amount)

# ══════════════════════════════════════════
#  B. 升级牌（数值 +50%，标记 upgraded）
# ══════════════════════════════════════════
func _upgrade_card(card_id: String) -> void:
	# card_id 在当前项目里实际是 work_grid 按钮传回来的牌组下标字符串。
	# GameManager.player_deck 保存的是 Array[Dictionary]，不是旧版的卡牌 id 字符串。
	var idx = card_id.to_int()
	if idx < 0 or idx >= GameManager.player_deck.size():
		return

	# 在牌组中找到该牌的实际引用
	var card = GameManager.player_deck[idx]
	if not (card is Dictionary):
		return

	if card.get("upgraded", false):
		_show_toast("这张牌已经升级过了！")
		return

	var card_name = card.get("name", card_id)
	pending_action = func():
		card["upgraded"] = true
		# 数值 +50%
		if card.has("value"):
			card["value"] = int(card["value"] * 1.5)
		# 更新描述里的数字（简单替换）
		if card.has("description"):
			card["description"] = card["description"] + "\n✨ 已升级 (数值 +50%)"
		action_used = true
		_back_to_actions()
		_show_toast("升级成功：%s！" % card_name)

	confirm_popup.title       = "确认升级？"
	confirm_popup.dialog_text = "升级【%s】？数值将提升 50%%，并获得 ✨ 标记。" % card_name
	confirm_popup.confirmed.connect(_execute_pending, CONNECT_ONE_SHOT)
	_popup_confirm_centered()

# ══════════════════════════════════════════
#  C. 删牌（免费）
# ══════════════════════════════════════════
func _delete_card(card_id: String) -> void:
	if GameManager.player_deck.size() <= MIN_DECK_SIZE:
		_show_toast("牌组至少保留 %d 张！" % MIN_DECK_SIZE)
		return

	var idx = card_id.to_int()
	if idx < 0 or idx >= GameManager.player_deck.size():
		return

	var card_data = GameManager.player_deck[idx]
	if not (card_data is Dictionary):
		return

	pending_action = func():
		if idx >= 0 and idx < GameManager.player_deck.size():
			GameManager.player_deck.remove_at(idx)
		action_used = true
		_back_to_actions()
		_show_toast("已删除：%s" % card_data.get("name", card_id))

	confirm_popup.title       = "确认删牌？"
	confirm_popup.dialog_text = "永久删除【%s】？此操作不可撤销。" % card_data.get("name", card_id)
	confirm_popup.confirmed.connect(_execute_pending, CONNECT_ONE_SHOT)
	_popup_confirm_centered()

# ══════════════════════════════════════════
#  通用卡牌选择器
# ══════════════════════════════════════════
func _show_card_viewer() -> void:
	GameManager.show_deck_viewer(self)

func _show_card_picker(title: String, callback: Callable) -> void:
	work_title.text      = title
	action_panel.visible = false
	coffee_anchor.visible = false
	if work_backdrop:
		work_backdrop.visible = true
	work_panel.visible   = true
	work_grid.columns = 2

	for child in work_grid.get_children():
		child.queue_free()

	for i in range(GameManager.player_deck.size()):
		var card_data = GameManager.player_deck[i]
		if not (card_data is Dictionary):
			continue
		var emoji     = card_data.get("emoji",  "❓")
		var name_     = card_data.get("name",   "未知卡牌")
		var effect    = card_data.get("description", card_data.get("effect", ""))
		var is_upgraded = card_data.get("upgraded", false)
		var upgraded_suffix = " ✨" if is_upgraded else ""

		var btn       = Button.new()
		# 升级模式下，已升级的卡牌不可再次升级，按钮禁用并标注。
		var locked_for_upgrade = current_mode == "upgrade" and is_upgraded
		var locked_suffix = "（已升级）" if locked_for_upgrade else ""
		btn.text      = "%s %s%s%s\n%s" % [emoji, name_, upgraded_suffix, locked_suffix, effect]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_setup_button_style(btn, 24, false, Vector2(380, 170))
		btn.disabled = locked_for_upgrade
		var captured  = str(i)
		btn.pressed.connect(func(): callback.call(captured))
		work_grid.add_child(btn)

# ══════════════════════════════════════════
#  导航
# ══════════════════════════════════════════
func _back_to_actions() -> void:
	work_panel.visible   = false
	if work_backdrop:
		work_backdrop.visible = false
	coffee_anchor.visible = true
	action_panel.visible = true
	_build_action_panel()

func _on_leave() -> void:
	get_tree().change_scene_to_file("res://Scenes/map.tscn")

# ══════════════════════════════════════════
#  工具
# ══════════════════════════════════════════
func _execute_pending() -> void:
	if pending_action:
		pending_action.call()
		pending_action = Callable()

func _show_toast(msg: String) -> void:
	toast_label.text    = msg
	toast_label.visible = true
	await get_tree().create_timer(2.5).timeout
	toast_label.visible = false