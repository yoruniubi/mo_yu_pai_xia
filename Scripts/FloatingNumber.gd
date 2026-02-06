extends Control

@onready var label = Label.new()

func _ready():
	add_child(label)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(200, 100)
	label.position = Vector2(-100, -50) # 居中对齐
	label.add_theme_font_size_override("font_size", 48) # 增加基础大小
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 12)

# 显示伤害数字或文本
func pop_up(value: Variant, is_critical: bool):
	label.text = str(value)
	if is_critical: 
		label.modulate = Color.GOLD # 大数字用金色
		label.add_theme_font_size_override("font_size", 96) # 进一步增加暴击大小
		label.add_theme_constant_override("outline_size", 16)
	
	var t = create_tween().set_parallel(true)
	# 向上飘并向随机左右偏移
	t.tween_property(self, "position:y", position.y - 150, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(self, "position:x", position.x + randf_range(-50, 50), 0.6)
	# 渐隐
	t.tween_property(self, "modulate:a", 0, 0.6).set_delay(0.3)
	t.finished.connect(queue_free)
