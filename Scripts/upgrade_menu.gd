extends Control

@onready var points_label    = %PointsLabel
@onready var upgrade_grid    = %UpgradeGrid
@onready var tab_resource    = %TabResource
@onready var tab_strategy    = %TabStrategy
@onready var tab_special     = %TabSpecial
@onready var back_button     = %BackButton

func _meta_progress_manager() -> Node:
	return get_node_or_null("/root/MetaProgressManager")

# ──────────────────────────────────────────────────────────────────────────────
# 升级数据定义
# 每项结构：{ id, name, desc, max_level, cost_per_level, category, branch?, risk? }
# ──────────────────────────────────────────────────────────────────────────────
const UPGRADES: Array = [
	# ── 资源类 ──────────────────────────────────────────────────────────────
	{
		"id": "ap_start",        "category": "resource",
		"name": "摸鱼老手",      "icon": "🐟",
		"desc": "初始摸鱼力 +1", "max_level": 2,  "cost": 30,
	},
	{
		"id": "hp_start",        "category": "resource",
		"name": "养生达人",      "icon": "🧘",
		"desc": "初始生命值 +20","max_level": 5,  "cost": 20,
	},
	{
		"id": "draw_start",      "category": "resource",
		"name": "手速极快",      "icon": "⚡",
		"desc": "初始抽牌数 +1", "max_level": 2,  "cost": 40,
	},
	{
		"id": "draft_start",     "category": "resource",
		"name": "提前备稿",      "icon": "📝",
		"desc": "初始多抽 2 张，但回合结束时丢弃 1 张",
		"max_level": 1,  "cost": 30,
	},

	# ── 策略类 · 摸鱼流 ──────────────────────────────────────────────────────
	{
		"id": "fish_first",      "category": "strategy", "branch": "摸鱼流",
		"name": "划水专家",      "icon": "🏊",
		"desc": "每回合第一张牌费用 -1",
		"max_level": 1,  "cost": 50,
	},
	{
		"id": "fish_hand",       "category": "strategy", "branch": "摸鱼流",
		"name": "摆烂大师",      "icon": "😴",
		"desc": "手牌超过 6 张时摸鱼力 +1",
		"max_level": 1,  "cost": 50,
	},
	{
		"id": "fish_retain",     "category": "strategy", "branch": "摸鱼流",
		"name": "无为而治",      "icon": "☯️",
		"desc": "结束回合时保留 1 张手牌到下回合",
		"max_level": 1,  "cost": 50,
	},

	# ── 策略类 · 爆发流 ──────────────────────────────────────────────────────
	{
		"id": "burst_kb",        "category": "strategy", "branch": "爆发流",
		"name": "键盘侠觉醒",    "icon": "⌨️",
		"desc": "⌨️ 连招触发时额外造成 5 点伤害",
		"max_level": 1,  "cost": 50,
	},
	{
		"id": "burst_ot",        "category": "strategy", "branch": "爆发流",
		"name": "加班文化",      "icon": "💼",
		"desc": "每打出 3 张牌，下一张牌费用归零",
		"max_level": 1,  "cost": 50,
	},
	{
		"id": "burst_lowHP",     "category": "strategy", "branch": "爆发流",
		"name": "末日冲刺",      "icon": "🔥",
		"desc": "血量低于 30% 时所有攻击伤害 +50%",
		"max_level": 1,  "cost": 60,
	},

	# ── 策略类 · 防御流 ──────────────────────────────────────────────────────
	{
		"id": "def_shield",      "category": "strategy", "branch": "防御流",
		"name": "规避考核",      "icon": "🛡️",
		"desc": "每回合开始获得 5 点护盾",
		"max_level": 1,  "cost": 50,
	},
	{
		"id": "def_retain",      "category": "strategy", "branch": "防御流",
		"name": "职场老油条",    "icon": "🧱",
		"desc": "护盾不清零，保留至下回合（上限 20）",
		"max_level": 1,  "cost": 60,
	},
	{
		"id": "def_draw",        "category": "strategy", "branch": "防御流",
		"name": "挡箭牌",        "icon": "🪃",
		"desc": "护盾抵消伤害时 30% 概率抽一张牌",
		"max_level": 1,  "cost": 50,
	},

	# ── 策略类 · 毒/Debuff 流 ────────────────────────────────────────────────
	{
		"id": "dot_start",       "category": "strategy", "branch": "毒流",
		"name": "散布谣言",      "icon": "🤫",
		"desc": "每场战斗开始敌人附带 1 层中毒",
		"max_level": 1,  "cost": 50,
	},
	{
		"id": "dot_combo",       "category": "strategy", "branch": "毒流",
		"name": "办公室政治",    "icon": "🗡️",
		"desc": "触发连招时额外施加 1 层易伤",
		"max_level": 1,  "cost": 50,
	},
	{
		"id": "dot_bonus",       "category": "strategy", "branch": "毒流",
		"name": "背刺专家",      "icon": "🐍",
		"desc": "对中毒敌人的攻击伤害 +20%",
		"max_level": 1,  "cost": 60,
	},

	# ── 特殊类 ──────────────────────────────────────────────────────────────
	{
		"id": "sp_yolo",         "category": "special",
		"name": "破罐破摔",      "icon": "💀",
		"desc": "初始 HP 减半，但所有伤害翻倍",
		"max_level": 1,  "cost": 60, "risk": true,
	},
	{
		"id": "sp_lazy",         "category": "special",
		"name": "躺平哲学",      "icon": "🛋️",
		"desc": "无法获得护盾，但每回合回复 5 HP",
		"max_level": 1,  "cost": 60,  "risk": true,
	},
	{
		"id": "sp_slash",        "category": "special",
		"name": "斜杠青年",      "icon": "🎭",
		"desc": "每关开始额外获得 1 张随机角色专属牌",
		"max_level": 1,  "cost": 80,
	},
	{
		"id": "sp_network",      "category": "special",
		"name": "人脉广泛",      "icon": "🤝",
		"desc": "商店物品价格 -30%",
		"max_level": 1,  "cost": 90,
	},
	{
		"id": "sp_grind",        "category": "special",
		"name": "卷王附体",      "icon": "📚",
		"desc": "每打出 5 张牌触发一次额外连招检测",
		"max_level": 1,  "cost": 80,
	},
]

# 当前激活分类
var _current_tab: String = "resource"

# 颜色方案（与 SettingsMenu 保持同一 lofi 奶油风）
const COLOR_BG_PANEL      = Color("#fff8e8")
const COLOR_BORDER        = Color("#e6d7b8")
const COLOR_SECTION_TEXT  = Color(0.49, 0.43, 0.35, 1)
const COLOR_BODY_TEXT     = Color("#3b3b3b")
const COLOR_OUTLINE       = Color(1, 1, 1, 0.45)

# Tab 颜色
const COLOR_TAB_ACTIVE    = Color("#8fb9aa")
const COLOR_TAB_INACTIVE  = Color("#e8dfc8")
const COLOR_TAB_HOVER     = Color("#a5cfc0")

# 卡片颜色
const COLOR_CARD_BG       = Color("#ffffff7f")
const COLOR_CARD_BORDER   = Color("#d9c9a8")
const COLOR_CARD_MAXED    = Color("#c5e8d5")
const COLOR_CARD_SPECIAL  = Color("#f8e4c8")
const COLOR_CARD_SPECIAL_RISK = Color("#f5d0d0")
const COLOR_LEVEL_FILLED  = Color("#8fb9aa")
const COLOR_LEVEL_EMPTY   = Color("#d9c9a8")
const COLOR_COST_TAG      = Color("#f5c870")

# ────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	if _meta_progress_manager() == null:
		push_error("MetaProgressManager autoload 未注册：/root/MetaProgressManager")
		return
	_setup_panel_style()
	_setup_tab_styles()
	_setup_back_button()
	_setup_tab_signals()
	back_button.pressed.connect(_on_back_pressed)
	_refresh_points_label()
	_populate_grid(_current_tab)

# ────────────────────────────────────────────────────────────────────────────
# 样式：主面板
# ────────────────────────────────────────────────────────────────────────────
func _setup_panel_style() -> void:
	var s = StyleBoxFlat.new()
	s.bg_color = COLOR_BG_PANEL
	s.set_corner_radius_all(26)
	s.shadow_size = 12
	s.shadow_offset = Vector2(0, 6)
	s.shadow_color = Color(0, 0, 0, 0.18)
	s.border_width_left   = 2
	s.border_width_top    = 2
	s.border_width_right  = 2
	s.border_width_bottom = 2
	s.border_color = COLOR_BORDER
	s.content_margin_left   = 32
	s.content_margin_right  = 32
	s.content_margin_top    = 28
	s.content_margin_bottom = 28
	$Panel.add_theme_stylebox_override("panel", s)

# ────────────────────────────────────────────────────────────────────────────
# 样式：Tab 按钮
# ────────────────────────────────────────────────────────────────────────────
func _setup_tab_styles() -> void:
	for tab in [tab_resource, tab_strategy, tab_special]:
		_apply_tab_style(tab)
		tab.focus_mode = Control.FOCUS_NONE

func _apply_tab_style(btn: Button) -> void:
	var active   = _make_tab_sb(COLOR_TAB_ACTIVE)
	var inactive = _make_tab_sb(COLOR_TAB_INACTIVE)
	var hover    = _make_tab_sb(COLOR_TAB_HOVER)
	btn.add_theme_stylebox_override("normal",         inactive)
	btn.add_theme_stylebox_override("pressed",        active)
	btn.add_theme_stylebox_override("hover",          hover)
	btn.add_theme_stylebox_override("focus",          StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color",        COLOR_BODY_TEXT)
	btn.add_theme_color_override("font_hover_color",  Color.BLACK)
	btn.add_theme_color_override("font_pressed_color",Color.BLACK)

func _make_tab_sb(color: Color) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(14)
	sb.content_margin_left   = 14
	sb.content_margin_right  = 14
	sb.content_margin_top    = 8
	sb.content_margin_bottom = 8
	return sb

# ────────────────────────────────────────────────────────────────────────────
# 样式：返回按钮
# ────────────────────────────────────────────────────────────────────────────
func _setup_back_button() -> void:
	_apply_solid_button(back_button, Color("#f5c2c7"), Color("#f2a6ad"), Color("#e98993"))

func _apply_solid_button(btn: Button, base: Color, hover: Color, pressed: Color) -> void:
	btn.add_theme_stylebox_override("normal",  _make_btn_sb(base))
	btn.add_theme_stylebox_override("hover",   _make_btn_sb(hover))
	btn.add_theme_stylebox_override("pressed", _make_btn_sb(pressed))
	btn.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_color_override("font_color",       COLOR_BODY_TEXT)
	btn.add_theme_color_override("font_hover_color", Color.BLACK)

func _make_btn_sb(color: Color) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(18)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	sb.shadow_color = Color(0, 0, 0, 0.2)
	sb.content_margin_left   = 16
	sb.content_margin_right  = 16
	sb.content_margin_top    = 8
	sb.content_margin_bottom = 8
	sb.border_width_bottom = 2
	sb.border_color = Color(0, 0, 0, 0.08)
	return sb

# ────────────────────────────────────────────────────────────────────────────
# Tab 信号绑定
# ────────────────────────────────────────────────────────────────────────────
func _setup_tab_signals() -> void:
	tab_resource.pressed.connect(func(): _switch_tab("resource"))
	tab_strategy.pressed.connect(func(): _switch_tab("strategy"))
	tab_special.pressed.connect(func():  _switch_tab("special"))

func _switch_tab(cat: String) -> void:
	_current_tab = cat
	# 保持 toggle 状态视觉一致
	tab_resource.button_pressed = (cat == "resource")
	tab_strategy.button_pressed = (cat == "strategy")
	tab_special.button_pressed  = (cat == "special")
	_populate_grid(cat)

# ────────────────────────────────────────────────────────────────────────────
# 填充升级卡片网格
# ────────────────────────────────────────────────────────────────────────────
func _populate_grid(cat: String) -> void:
	# 清空旧节点
	for child in upgrade_grid.get_children():
		child.queue_free()

	var filtered = UPGRADES.filter(func(u): return u["category"] == cat)

	# 策略类按分支插入小节标题
	var last_branch = ""

	for upgrade in filtered:
		# ── 分支标题（策略类）─────────────────────────────────────────────
		if cat == "strategy":
			var branch = upgrade.get("branch", "")
			if branch != last_branch:
				last_branch = branch
				# 占满3列：用3个节点，第一个放标题，后两个透明占位
				var section_label = _make_section_label(branch)
				section_label.custom_minimum_size = Vector2(0, 44)
				upgrade_grid.add_child(section_label)
				for _i in range(2):
					var sp = Control.new()
					sp.custom_minimum_size = Vector2(300, 44)  # 与卡片同宽
					upgrade_grid.add_child(sp)

		# ── 升级卡片 ────────────────────────────────────────────────────────
		var card = _build_card(upgrade)
		upgrade_grid.add_child(card)

func _make_section_label(text: String) -> Label:
	var lbl = Label.new()
	lbl.text = "── " + text + " ──"
	lbl.add_theme_font_size_override("font_size", 26)  
	lbl.add_theme_color_override("font_color", COLOR_SECTION_TEXT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return lbl

# ────────────────────────────────────────────────────────────────────────────
# 构建单张升级卡片
# ────────────────────────────────────────────────────────────────────────────
func _build_card(upgrade: Dictionary) -> PanelContainer:
	var meta = _meta_progress_manager()
	var id        = upgrade["id"]
	var max_lvl   = upgrade["max_level"]
	var cur_lvl   = meta.get_level(id)
	var cost      = upgrade["cost"]
	var points    = meta.get_points()
	var is_maxed  = (cur_lvl >= max_lvl)
	var is_risk   = upgrade.get("risk", false)
	var is_special = upgrade["category"] == "special"
	var can_buy   = (not is_maxed) and (points >= cost)

	# 卡片容器
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(310,150)

	# 卡片背景样式
	var bg_color = COLOR_CARD_BG
	if is_maxed:
		bg_color = COLOR_CARD_MAXED
	elif is_special and is_risk:
		bg_color = COLOR_CARD_SPECIAL_RISK
	elif is_special:
		bg_color = COLOR_CARD_SPECIAL

	var card_sb = StyleBoxFlat.new()
	card_sb.bg_color = bg_color
	card_sb.set_corner_radius_all(18)
	card_sb.border_width_left   = 2
	card_sb.border_width_top    = 2
	card_sb.border_width_right  = 2
	card_sb.border_width_bottom = 2
	card_sb.border_color = COLOR_CARD_BORDER
	card_sb.shadow_size = 4
	card_sb.shadow_offset = Vector2(0, 2)
	card_sb.shadow_color = Color(0, 0, 0, 0.10)
	card_sb.content_margin_left   = 16
	card_sb.content_margin_right  = 16
	card_sb.content_margin_top    = 14
	card_sb.content_margin_bottom = 14
	card.add_theme_stylebox_override("panel", card_sb)

	# 内部垂直布局
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	# 图标 + 名称行
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)

	var icon_lbl = Label.new()
	icon_lbl.text = upgrade.get("icon", "")
	icon_lbl.add_theme_font_size_override("font_size", 28)
	header.add_child(icon_lbl)

	var name_lbl = Label.new()
	name_lbl.text = upgrade["name"]
	name_lbl.add_theme_font_size_override("font_size", 26)
	name_lbl.add_theme_color_override("font_color", COLOR_BODY_TEXT)
	name_lbl.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	name_lbl.add_theme_constant_override("outline_size", 1)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_lbl)

	# 描述
	var desc_lbl = Label.new()
	desc_lbl.text = upgrade["desc"]
	desc_lbl.add_theme_font_size_override("font_size", 22)
	desc_lbl.add_theme_color_override("font_color", COLOR_SECTION_TEXT)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.custom_minimum_size = Vector2(100, 40)
	vbox.add_child(desc_lbl)

	# 等级点阵
	if max_lvl > 1:
		var pip_row = HBoxContainer.new()
		pip_row.add_theme_constant_override("separation", 6)
		vbox.add_child(pip_row)
		for i in range(max_lvl):
			var pip = ColorRect.new()
			pip.custom_minimum_size = Vector2(28, 12)
			pip.color = COLOR_LEVEL_FILLED if i < cur_lvl else COLOR_LEVEL_EMPTY
			# 圆角用 StyleBox
			pip.set_script(null) # 普通 ColorRect 够用
			pip_row.add_child(pip)
		var lvl_txt = Label.new()
		lvl_txt.text = " %d / %d 级" % [cur_lvl, max_lvl]
		lvl_txt.add_theme_font_size_override("font_size", 17)
		lvl_txt.add_theme_color_override("font_color", COLOR_SECTION_TEXT)
		pip_row.add_child(lvl_txt)

	# 底部：费用 + 购买按钮
	var footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	footer.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(footer)

	# 费用标签
	var cost_lbl = Label.new()
	if is_maxed:
		cost_lbl.text = "✅ 已满级"
		cost_lbl.add_theme_color_override("font_color", Color("#4e8b7d"))
	else:
		cost_lbl.text = "🪙 %d 积分" % cost
		cost_lbl.add_theme_color_override("font_color",
			COLOR_BODY_TEXT if can_buy else Color(0.6, 0.5, 0.4, 1))
	cost_lbl.add_theme_font_size_override("font_size", 20)
	cost_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(cost_lbl)

	# 升级按钮
	var btn_text = "升级" if max_lvl > 1 else "解锁"
	var buy_btn = Button.new()
	buy_btn.text = "已满级" if is_maxed else btn_text
	buy_btn.disabled = is_maxed or not can_buy
	buy_btn.custom_minimum_size = Vector2(90, 38)
	buy_btn.add_theme_font_size_override("font_size", 20)
	buy_btn.focus_mode = Control.FOCUS_NONE

	var btn_base    = Color("#8fb9aa") if not is_risk else Color("#e89090")
	var btn_hover   = Color("#6fa597") if not is_risk else Color("#d07070")
	var btn_pressed = Color("#4e8b7d") if not is_risk else Color("#b05050")
	var btn_disabled = Color("#c8c0b0")

	buy_btn.add_theme_stylebox_override("normal",   _make_btn_sb(btn_base if can_buy else btn_disabled))
	buy_btn.add_theme_stylebox_override("hover",    _make_btn_sb(btn_hover))
	buy_btn.add_theme_stylebox_override("pressed",  _make_btn_sb(btn_pressed))
	buy_btn.add_theme_stylebox_override("disabled", _make_btn_sb(btn_disabled))
	buy_btn.add_theme_stylebox_override("focus",    StyleBoxEmpty.new())
	buy_btn.add_theme_color_override("font_color",          COLOR_BODY_TEXT)
	buy_btn.add_theme_color_override("font_disabled_color", Color(0.55, 0.52, 0.48, 1))
	buy_btn.custom_minimum_size = Vector2(100, 44)
	if not is_maxed and can_buy:
		buy_btn.pressed.connect(_on_upgrade_pressed.bind(id, upgrade["category"]))

	# 重置按钮：当已升级（cur_lvl > 0）时显示，点击后归还积分并清空该项等级
	if cur_lvl > 0:
		var reset_btn = Button.new()
		reset_btn.text = "重置"
		reset_btn.tooltip_text = "归还 %d 积分并重置该升级" % (cost * cur_lvl)
		reset_btn.custom_minimum_size = Vector2(70, 44)
		reset_btn.add_theme_font_size_override("font_size", 18)
		reset_btn.focus_mode = Control.FOCUS_NONE

		var reset_base    = Color("#e6c870")
		var reset_hover   = Color("#d9b85a")
		var reset_pressed = Color("#b89a3e")
		reset_btn.add_theme_stylebox_override("normal",   _make_btn_sb(reset_base))
		reset_btn.add_theme_stylebox_override("hover",    _make_btn_sb(reset_hover))
		reset_btn.add_theme_stylebox_override("pressed",  _make_btn_sb(reset_pressed))
		reset_btn.add_theme_stylebox_override("focus",    StyleBoxEmpty.new())
		reset_btn.add_theme_color_override("font_color",        COLOR_BODY_TEXT)
		reset_btn.add_theme_color_override("font_hover_color",  Color.BLACK)

		reset_btn.pressed.connect(_on_reset_pressed.bind(id, upgrade["category"]))
		footer.add_child(reset_btn)

	footer.add_child(buy_btn)

	return card

# ────────────────────────────────────────────────────────────────────────────
# 购买逻辑
# ────────────────────────────────────────────────────────────────────────────
func _on_upgrade_pressed(id: String, cat: String) -> void:
	var meta = _meta_progress_manager()
	if meta == null:
		return
	var upgrade = UPGRADES.filter(func(u): return u["id"] == id).front()
	if upgrade == null:
		return
	var cost    = upgrade["cost"]
	var max_lvl = upgrade["max_level"]
	var cur_lvl = meta.get_level(id)

	if cur_lvl >= max_lvl:
		return
	if meta.get_points() < cost:
		return

	meta.spend_points(cost)
	meta.set_level(id, cur_lvl + 1)
	meta.save()

	_refresh_points_label()
	_populate_grid(cat)

func _refresh_points_label() -> void:
	var meta = _meta_progress_manager()
	points_label.text = "  |  积分：%d" % (meta.get_points() if meta != null else 0)

# ────────────────────────────────────────────────────────────────────────────
# 返回主菜单
# ────────────────────────────────────────────────────────────────────────────
func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")

func _on_reset_pressed(id: String, cat: String) -> void:
	var meta = _meta_progress_manager()
	if meta == null:
		return
	var upgrade = UPGRADES.filter(func(u): return u["id"] == id).front()
	if upgrade == null:
		return
	# reset_upgrade 内部会按 cur_lvl * cost 返还积分并清空等级
	if not meta.reset_upgrade(id, upgrade["cost"]):
		return
	meta.save()

	_refresh_points_label()
	_populate_grid(cat)
