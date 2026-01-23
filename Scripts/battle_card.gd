extends Control

@onready var visual = $Visual
@onready var name_label = %NameLabel
@onready var cost_label = %CostLabel
@onready var description_label = %DescriptionLabel
@onready var card_image = %CardImage
@onready var emoji_label = %EmojiLabel
@onready var highlight = %Highlight

# 模拟卡片数据结构 (后续可改为 Resource)
var card_data: Dictionary = {}: 
	set(value):
		card_data = value
		if is_node_ready():
			update_ui()

const HOVER_SCALE = Vector2(1.2, 1.2)
const HOVER_OFFSET = -50.0
const ANIM_SPEED = 0.15

func _ready():
	update_ui()
	visual.pivot_offset = Vector2(110, 340) # 底部中心

func update_ui():
	if card_data.is_empty():
		return
		
	set_highlight(false)
	name_label.text = card_data.get("name", "未知卡牌")
	cost_label.text = str(card_data.get("cost", 1))
	description_label.text = card_data.get("description", "")
	
	# 优先显示 Emoji
	if card_data.has("emoji"):
		emoji_label.text = card_data.emoji
		emoji_label.visible = true
		card_image.visible = false
	else:
		emoji_label.visible = false
		card_image.visible = true
		var img = card_data.get("image")
		if img is Texture2D:
			card_image.texture = img
		elif img is String and img != "":
			card_image.texture = load(img)
		else:
			card_image.texture = preload("res://Assets/Images/coffee_cup.png")

func _on_mouse_entered():
	z_index = 100
	var tween = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(visual, "scale", HOVER_SCALE, ANIM_SPEED)
	tween.tween_property(visual, "position:y", HOVER_OFFSET, ANIM_SPEED)
	tween.tween_property(visual, "modulate", Color(1.1, 1.1, 1.1), ANIM_SPEED)

func _on_mouse_exited():
	z_index = 0
	var tween = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(visual, "scale", Vector2.ONE, ANIM_SPEED)
	tween.tween_property(visual, "position:y", 0.0, ANIM_SPEED)
	tween.tween_property(visual, "modulate", Color.WHITE, ANIM_SPEED)

func set_highlight(enabled: bool):
	if highlight:
		highlight.visible = enabled

func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# 选中逻辑
		var tween = create_tween()
		tween.tween_property(visual, "scale", Vector2(0.9, 0.9), 0.05)
		tween.tween_property(visual, "scale", HOVER_SCALE, 0.1)
		
		# 发出信号，通知战斗场景该卡牌被使用了
		var battle_scene = get_tree().current_scene
		if battle_scene.has_method("_on_card_played"):
			battle_scene._on_card_played(self)
