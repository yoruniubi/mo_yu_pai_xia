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
