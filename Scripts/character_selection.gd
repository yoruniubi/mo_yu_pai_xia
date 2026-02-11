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

func _setup_back_button():
	var back_btn = Button.new()
	back_btn.text = " ↩ 返回主菜单 "
	back_btn.name = "BackButton"
	
	# 样式设置
	var style_normal = _create_style("#fdf5e6", 15, 4)
	var style_hover = _create_style("#a8d8ea", 15, 6)
	var style_pressed = _create_style("#7fb5c9", 15, 0)
	
	back_btn.add_theme_stylebox_override("normal", style_normal)
	back_btn.add_theme_stylebox_override("hover", style_hover)
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

func _create_style(color_hex: String, radius: int, shadow: int) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(color_hex)
	sb.set_corner_radius_all(radius)
	sb.shadow_size = shadow
	sb.shadow_offset = Vector2(0, shadow / 2.0)
	sb.content_margin_left = 15
	sb.content_margin_right = 15
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	return sb
