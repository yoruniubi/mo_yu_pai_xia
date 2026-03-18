extends Control

@onready var card_container = $GridContainer
var card_scene = preload("res://Scenes/control.tscn")

var characters = [
	preload("res://Resources/squirrel.tres"),
	preload("res://Resources/kraken.tres"),
	preload("res://Resources/leo.tres"),
	preload("res://Resources/susan.tres")
]

func _ready():
	# 播放背景音乐
	var bgm = preload("res://Assets/Music/Cubicle_Coffee.mp3") 
	BgmManager.play_music(bgm)
	
	# 清除编辑器中的占位符
	for child in card_container.get_children():
		child.queue_free()
	
	# 动态生成角色卡片
	for data in characters:
		var card = card_scene.instantiate()
		card_container.add_child(card)
		card.character_data = data
	
	_setup_back_button()
	
	# 非首次进入：在角落显示「前情提要」按钮
	if GameManager.has_seen_intro:
		_setup_recap_button()

func _on_character_selected(hero: CharacterData) -> void:
	# 角色确认后由此处跳转，而非 control.gd 直接 start_game
	GameManager.selected_hero = hero
	GameManager.reset_run()
	
	if not GameManager.has_seen_intro:
		# 首次：跳过场动画，动画结束后再进游戏
		GameManager.has_seen_intro = true
		get_tree().change_scene_to_file("res://Scenes/StoryScene.tscn")
	else:
		# 非首次：直接进第一关
		GameManager.load_current_level_scene()

func _setup_back_button():
	var back_btn = Button.new()
	back_btn.text = " ↩ 返回主菜单 "
	back_btn.name = "BackButton"
	
	# 样式设置
	var style_normal = _create_style("#fdf5e6", 15, 4)
	var style_hover  = _create_style("#a8d8ea", 15, 6)
	var style_pressed = _create_style("#7fb5c9", 15, 0)
	
	back_btn.add_theme_stylebox_override("normal",  style_normal)
	back_btn.add_theme_stylebox_override("hover",   style_hover)
	back_btn.add_theme_stylebox_override("pressed", style_pressed)
	back_btn.add_theme_color_override("font_color", Color("#4a4a4a"))
	back_btn.add_theme_font_size_override("font_size", 28)
	back_btn.custom_minimum_size = Vector2(200, 60)
	
	# 位置设置 (左上角)
	back_btn.position = Vector2(20, 20)
	add_child(back_btn)
	
	back_btn.pressed.connect(func():
		get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
	)

func _setup_recap_button() -> void:
	# 右上角「前情提要」按钮，仅非首次显示
	var recap_btn = Button.new()
	recap_btn.text = "📖 前情提要"
	recap_btn.name = "RecapButton"
	
	var style_n = _create_style("#2a2a3a", 12, 3)
	var style_h = _create_style("#3a3a5a", 12, 5)
	style_n.border_width_left   = 1
	style_n.border_width_right  = 1
	style_n.border_width_top    = 1
	style_n.border_width_bottom = 1
	style_n.border_color = Color("#8888cc")
	style_h.border_width_left   = 1
	style_h.border_width_right  = 1
	style_h.border_width_top    = 1
	style_h.border_width_bottom = 1
	style_h.border_color = Color("#aaaaee")
	
	recap_btn.add_theme_stylebox_override("normal", style_n)
	recap_btn.add_theme_stylebox_override("hover",  style_h)
	recap_btn.add_theme_color_override("font_color", Color("#ccccff"))
	recap_btn.add_theme_font_size_override("font_size", 22)
	recap_btn.custom_minimum_size = Vector2(160, 50)
	
	# 右上角，距右边 20px，距上边 20px
	recap_btn.anchor_left   = 1.0
	recap_btn.anchor_right  = 1.0
	recap_btn.anchor_top    = 0.0
	recap_btn.anchor_bottom = 0.0
	recap_btn.offset_left   = -180
	recap_btn.offset_right  = -20
	recap_btn.offset_top    = 20
	recap_btn.offset_bottom = 70
	add_child(recap_btn)
	
	recap_btn.pressed.connect(_open_recap)

func _open_recap() -> void:
	# 以前情提要模式打开 StoryScene（叠加在当前场景之上的 CanvasLayer）
	var story_layer = CanvasLayer.new()
	story_layer.layer = 100
	add_child(story_layer)
	
	var story_scene_res = preload("res://Scenes/StoryScene.tscn")
	var story_inst = story_scene_res.instantiate()
	story_inst._recap_mode = true   # 设置为前情提要模式（秒显全文 + 关闭按钮）
	
	# 连接关闭信号：story_scene 播完/关闭后销毁 CanvasLayer
	story_inst.connect("story_closed", story_layer.queue_free)
	story_layer.add_child(story_inst)

func _create_style(color_hex: String, radius: int, shadow: int) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(color_hex)
	sb.set_corner_radius_all(radius)
	sb.shadow_size = shadow
	sb.shadow_offset = Vector2(0, shadow / 2.0)
	sb.content_margin_left   = 15
	sb.content_margin_right  = 15
	sb.content_margin_top    = 5
	sb.content_margin_bottom = 5
	return sb
