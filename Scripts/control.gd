extends Control

# 引用内部的表现层节点
@onready var visual = $Visual
@export var character_data: CharacterData:
	set(value):
		character_data = value
		if is_node_ready():
			update_ui()

# 配置动画参数（像 CSS 变量一样方便修改）
const HOVER_SCALE = Vector2(1.15, 1.15)      # 放大倍数
const HOVER_PULL_UP = -40                   # 向上漂浮的像素
const ANIM_SPEED = 0.15                     # 动画持续时间（秒）
const HOVER_ROTATION = 2.0                  # 悬停时微微倾斜的角度（增加灵动感）

func _ready():
	# 初始化数据显示
	update_ui()
	
	# 关键：确保 Visual 节点的轴心在中心，否则动画会歪
	visual.pivot_offset = visual.size / 2

func update_ui():
	if character_data:
		$Visual/HeroImage.texture = character_data.character_image
		$Visual/InfoContainer/NameLabel.text = character_data.character_name
		$Visual/InfoContainer/JobLabel.text = character_data.job_title + " (" + character_data.race + ")"
		$Visual/InfoContainer/EmojiLabel.text = character_data.core_emojis
		$Visual/InfoContainer/StyleLabel.text = character_data.combo_style

# --- 核心交互逻辑 ---

func _on_mouse_entered():
	if not is_inside_tree():
		return
	print("鼠标进来了！")
	# 1. 提高显示优先级
	z_index = 10
	
	# 2. 创建补间动画（Tween）
	var tween = create_tween().set_parallel(true) # 允许所有属性同时变
	
	# 动画：放大
	tween.tween_property(visual, "scale", HOVER_SCALE, ANIM_SPEED)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) # 带一点点弹性的效果
	
	# 动画：向上漂浮 (修改 position.y)
	tween.tween_property(visual, "position:y", HOVER_PULL_UP, ANIM_SPEED)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# 动画：微微倾斜（像真实手牌一样）
	tween.tween_property(visual, "rotation_degrees", HOVER_ROTATION, ANIM_SPEED)
	
	# 动画：颜色变亮 (Glow 效果)
	tween.tween_property(visual, "modulate", Color(1.2, 1.2, 1.2), ANIM_SPEED)

func _on_mouse_exited():
	if not is_inside_tree():
		return
	# 1. 恢复显示优先级
	z_index = 0
	
	var tween = create_tween().set_parallel(true)
	
	# 恢复所有属性到初始状态
	tween.tween_property(visual, "scale", Vector2.ONE, ANIM_SPEED)
	tween.tween_property(visual, "position:y", 0.0, ANIM_SPEED)
	tween.tween_property(visual, "rotation_degrees", 0.0, ANIM_SPEED)
	tween.tween_property(visual, "modulate", Color.WHITE, ANIM_SPEED)

# --- 点击逻辑 ---

func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not is_inside_tree():
			return
		# 点击时做一个“按下”的反震效果
		var tween = create_tween()
		tween.tween_property(visual, "scale", Vector2(0.9, 0.9), 0.05)
		tween.tween_property(visual, "scale", HOVER_SCALE, 0.1)
		
		# 延迟一点跳转，让点击感更爽
		get_tree().create_timer(0.1).timeout.connect(select_this_character)

func select_this_character():
	if not is_inside_tree():
		return
	GameManager.start_game(character_data)
