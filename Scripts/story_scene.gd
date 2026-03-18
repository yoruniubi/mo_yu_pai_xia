extends Control

# ============================================================
# StoryScene.gd  ──  过场动画：打字机展示「离职宣言」剧情
#
# 触发逻辑（由 character_selection.gd 控制）：
#   首次进入：强制播放打字机动画（可跳过）→ 播完自动跳首关
#   非首次：以前情提要模式打开（_recap_mode=true）
#           → 全文秒显 + 显示「关闭」按钮，不自动跳转
# ============================================================

# ---------- 剧情文本 ----------
const STORY_LINES: Array = [
	"📅  周一早上 9:02",
	"",
	"你盯着屏幕，KPI 考核表已经在桌面上躺了三天。",
	"老板在群里发来消息：",
	"「小X，今天下班前给我一份完整的报告。」",
	"",
	"你深吸一口气。",
	"",
	"不是今天。",
	"",
	"打开辞职信草稿，删了又写，写了又删……",
	"终于，你把它存进了一张卡牌。",
	"",
	"    ✉️  【辞职申请】  ✉️",
	"",
	"这是你的武器。",
	"这是你的离职之路。",
	"",
	"── 10 关，打穿整个职场。──",
]

# ---------- 信号 ----------
signal story_closed   # 前情提要关闭时通知父节点（_recap_mode=true 时 emit）

# ---------- 节点引用（代码构建，无需 tscn 预先摆放） ----------
var _bg: ColorRect
var _label: RichTextLabel
var _skip_btn: Button
var _continue_btn: Button
var _progress_bar: ProgressBar

# ---------- 打字机状态 ----------
var _line_idx: int = 0
var _full_text: String = ""
var _shown_text: String = ""
var _timer: float = 0.0
var _typing: bool = false

const CHAR_DELAY: float = 0.035   # 每字间隔(秒)
const LINE_PAUSE: float = 0.55    # 换行停顿(秒)
const TOTAL_LINES: int = 18       # 与 STORY_LINES.size() 保持一致

# ---------- 模式 ----------
## true = 前情提要模式（非首次，秒显全文）
var _recap_mode: bool = false

# ── 入口 ─────────────────────────────────────────────────────
func _ready() -> void:
	_build_ui()
	if _recap_mode:
		_show_all_instantly()
	else:
		_start_typewriter()

# ── UI 构建 ──────────────────────────────────────────────────
func _build_ui() -> void:
	# 深色背景
	_bg = ColorRect.new()
	_bg.color = Color(0.06, 0.06, 0.10, 1.0)
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	# 进度条（仅首次模式显示）
	_progress_bar = ProgressBar.new()
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = float(STORY_LINES.size())
	_progress_bar.value = 0.0
	_progress_bar.show_percentage = false
	_progress_bar.anchor_left = 0.1
	_progress_bar.anchor_right = 0.9
	_progress_bar.anchor_top = 0.0
	_progress_bar.offset_top = 20.0
	_progress_bar.offset_bottom = 36.0
	_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bar_style = StyleBoxFlat.new()
	bar_style.bg_color = Color(0.2, 0.8, 0.6, 0.8)
	bar_style.set_corner_radius_all(4)
	_progress_bar.add_theme_stylebox_override("fill", bar_style)
	add_child(_progress_bar)
	_progress_bar.visible = not _recap_mode

	# 文字区域（留边距）
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 60)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_top", 80)
	margin.add_theme_constant_override("margin_bottom", 130)
	add_child(margin)

	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.scroll_active = false
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_label.add_theme_font_size_override("normal_font_size", 28)
	_label.add_theme_color_override("default_color", Color(0.92, 0.90, 0.85))
	margin.add_child(_label)

	# 「跳过」按钮（右上角，仅首次模式）
	_skip_btn = _make_button("跳过 ▶▶")
	_skip_btn.anchor_right = 1.0
	_skip_btn.anchor_top = 0.0
	_skip_btn.offset_left = -160.0
	_skip_btn.offset_right = -20.0
	_skip_btn.offset_top = 16.0
	_skip_btn.offset_bottom = 56.0
	_skip_btn.pressed.connect(_on_skip_pressed)
	add_child(_skip_btn)
	_skip_btn.visible = not _recap_mode

	# 「开始离职」/ 「关闭」按钮（底部居中，初始隐藏）
	var btn_text = "关闭" if _recap_mode else "开始我的离职之路 →"
	_continue_btn = _make_button(btn_text)
	_continue_btn.anchor_left = 0.5
	_continue_btn.anchor_right = 0.5
	_continue_btn.anchor_top = 1.0
	_continue_btn.anchor_bottom = 1.0
	_continue_btn.offset_left = -160.0
	_continue_btn.offset_right = 160.0
	_continue_btn.offset_top = -90.0
	_continue_btn.offset_bottom = -30.0
	_continue_btn.pressed.connect(_on_continue_pressed)
	add_child(_continue_btn)
	_continue_btn.visible = false

func _make_button(text: String) -> Button:
	var btn = Button.new()
	btn.text = text
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.15, 0.55, 0.45, 0.9)
	s.set_corner_radius_all(10)
	s.border_width_bottom = 2
	s.border_color = Color(0.3, 0.9, 0.7, 0.7)
	btn.add_theme_stylebox_override("normal", s)
	var sh = StyleBoxFlat.new()
	sh.bg_color = Color(0.22, 0.75, 0.60, 1.0)
	sh.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("hover", sh)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 26)
	return btn

# ── 打字机模式 ───────────────────────────────────────────────
func _start_typewriter() -> void:
	_line_idx = 0
	_shown_text = ""
	_typing = true
	_type_next_line()

func _type_next_line() -> void:
	if _line_idx >= STORY_LINES.size():
		_finish_typing()
		return

	_full_text = STORY_LINES[_line_idx]
	_line_idx += 1
	_progress_bar.value = float(_line_idx)

	if _full_text == "":
		# 空行：追加换行后短暂停顿再继续
		_shown_text += "\n"
		_label.text = _shown_text
		await get_tree().create_timer(LINE_PAUSE * 0.6).timeout
		_type_next_line()
		return

	# 逐字打出当前行
	for ch in _full_text:
		_shown_text += ch
		_label.text = _shown_text
		await get_tree().create_timer(CHAR_DELAY).timeout
		if not _typing:
			return  # 已跳过

	_shown_text += "\n"
	_label.text = _shown_text
	await get_tree().create_timer(LINE_PAUSE).timeout
	if _typing:
		_type_next_line()

func _finish_typing() -> void:
	_typing = false
	_skip_btn.visible = false
	# 结尾淡入「开始」按钮
	_continue_btn.visible = true
	_continue_btn.modulate.a = 0.0
	var t = create_tween()
	t.tween_property(_continue_btn, "modulate:a", 1.0, 0.6)

# ── 前情提要模式：秒显全文 ──────────────────────────────────
func _show_all_instantly() -> void:
	var full = ""
	for line in STORY_LINES:
		full += line + "\n"
	_label.text = full
	_continue_btn.visible = true

# ── 按钮回调 ─────────────────────────────────────────────────
func _on_skip_pressed() -> void:
	_typing = false
	_show_all_instantly()
	_skip_btn.visible = false
	_progress_bar.value = _progress_bar.max_value


func _on_continue_pressed() -> void:
	if _recap_mode:
		# 前情提要模式：通知父节点后关闭
		story_closed.emit()
		queue_free()
		return
	# 首次模式：跳转到第一关
	GameManager.has_seen_intro = true
	GameManager.load_current_level_scene()
