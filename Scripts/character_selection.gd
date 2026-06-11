extends Control

@onready var card_container = $GridContainer
var card_scene = preload("res://Scenes/control.tscn")
var scale_factor: float = 1.0

var characters = [
	preload("res://Resources/squirrel.tres"),
	preload("res://Resources/kraken.tres"),
	preload("res://Resources/leo.tres"),
	preload("res://Resources/susan.tres")
]

func _ready():
	var bgm = preload("res://Assets/Music/Cubicle_Coffee.mp3")
	BgmManager.play_music(bgm)

	# 计算缩放比例
	var screen_size = get_viewport_rect().size
	scale_factor = min(screen_size.x / 1080.0, screen_size.y / 1920.0)

	for child in card_container.get_children():
		child.queue_free()

	for data in characters:
		var card = card_scene.instantiate()
		card_container.add_child(card)
		card.character_data = data

	_setup_back_button()
	# 计算 scale_factor 之后加这两行
	card_container.add_theme_constant_override("h_separation", int(30 * scale_factor))
	card_container.add_theme_constant_override("v_separation", int(30 * scale_factor))
	if GameManager.has_seen_intro:
		_setup_recap_button()

func _on_character_selected(hero: CharacterData) -> void:
	GameManager.selected_hero = hero
	GameManager.reset_run()

	# 教学模式下直接进入教学场景，跳过剧情
	if GameManager.is_tutorial_mode:
		get_tree().change_scene_to_file("res://Scenes/tutorial_scene.tscn")
		return

	if not GameManager.has_seen_intro:
		GameManager.has_seen_intro = true
		get_tree().change_scene_to_file("res://Scenes/StoryScene.tscn")
	else:
		GameManager.load_current_level_scene()

func _setup_back_button():
	var back_btn = Button.new()
	back_btn.text = " ↩ 返回主菜单 "
	back_btn.name = "BackButton"

	var style_normal  = _create_style("#fdf5e6", 15, 4)
	var style_hover   = _create_style("#a8d8ea", 15, 6)
	var style_pressed = _create_style("#7fb5c9", 15, 0)

	back_btn.add_theme_stylebox_override("normal",  style_normal)
	back_btn.add_theme_stylebox_override("hover",   style_hover)
	back_btn.add_theme_stylebox_override("pressed", style_pressed)
	back_btn.add_theme_color_override("font_color", Color("#4a4a4a"))
	back_btn.add_theme_font_size_override("font_size", int(32 * scale_factor))
	back_btn.custom_minimum_size = Vector2(300 * scale_factor, 80 * scale_factor)

	back_btn.position = Vector2(20 * scale_factor, 20 * scale_factor)
	add_child(back_btn)

	back_btn.pressed.connect(func():
		get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
	)

func _setup_recap_button() -> void:
	var recap_btn = Button.new()
	recap_btn.text = "📖 前情提要"
	recap_btn.name = "RecapButton"

	var style_n = _create_style("#2a2a3a", 12, 3)
	var style_h = _create_style("#3a3a5a", 12, 5)

	for style in [style_n, style_h]:
		style.border_width_left   = 1
		style.border_width_right  = 1
		style.border_width_top    = 1
		style.border_width_bottom = 1

	style_n.border_color = Color("#8888cc")
	style_h.border_color = Color("#aaaaee")

	recap_btn.add_theme_stylebox_override("normal", style_n)
	recap_btn.add_theme_stylebox_override("hover",  style_h)
	recap_btn.add_theme_color_override("font_color", Color("#ccccff"))
	recap_btn.add_theme_font_size_override("font_size", int(32 * scale_factor))
	recap_btn.custom_minimum_size = Vector2(300 * scale_factor, 80 * scale_factor)

	# 右上角锚点定位（与返回按钮相同尺寸）
	var btn_w := 300.0 * scale_factor
	var btn_h := 80.0 * scale_factor
	var margin := 20.0 * scale_factor
	recap_btn.anchor_left   = 1.0
	recap_btn.anchor_right  = 1.0
	recap_btn.anchor_top    = 0.0
	recap_btn.anchor_bottom = 0.0
	recap_btn.offset_left   = -(btn_w + margin)
	recap_btn.offset_right  = -margin
	recap_btn.offset_top    = margin
	recap_btn.offset_bottom = margin + btn_h
	add_child(recap_btn)

	recap_btn.pressed.connect(_open_recap)

func _open_recap() -> void:
	var story_layer = CanvasLayer.new()
	story_layer.layer = 100
	add_child(story_layer)

	var story_scene_res = preload("res://Scenes/StoryScene.tscn")
	var story_inst = story_scene_res.instantiate()
	story_inst._recap_mode = true
	story_inst.connect("story_closed", story_layer.queue_free)
	story_layer.add_child(story_inst)

func _create_style(color_hex: String, radius: int, shadow: int) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(color_hex)
	sb.set_corner_radius_all(radius)
	sb.shadow_size = shadow
	sb.shadow_offset = Vector2(0, shadow / 2.0)
	sb.content_margin_left   = 15 * scale_factor
	sb.content_margin_right  = 15 * scale_factor
	sb.content_margin_top    = 5  * scale_factor
	sb.content_margin_bottom = 5  * scale_factor
	return sb