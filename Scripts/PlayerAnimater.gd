# 玩家受击动画
extends Node

@onready var flash_layer = get_node_or_null("%FlashLayer")
@onready var boss_node = %BossSprite

# --- 1. 玩家受击 (Player Hit) ---
func play_player_hit_anim():
	# 即使没有闪屏层，也要震屏
	shake_screen(15.0, 0.3)
	if not flash_layer: return
	# A. 视野红闪
	var t = create_tween()
	# 显式设置为红色并设置透明度，防止被其他特效（如连招金色）残留颜色影响
	flash_layer.modulate = Color(1, 0, 0, 0.5) 
	t.tween_property(flash_layer, "modulate:a", 0, 0.4).set_trans(Tween.TRANS_SINE)
	# 动画结束后确保颜色重置为红色基础色
	t.finished.connect(func(): flash_layer.modulate = Color(1, 0, 0, 0))
	
	# B. 剧烈震屏 (Screen Shake)
	# 我们可以震动整个场景根节点，或者震动 Camera2D
	shake_screen(15.0, 0.3)

# --- 根据 emoji 决定投掷物颜色 ---
func _get_emoji_color(emoji: String) -> Color:
	match emoji:
		"🔥", "💣", "🧨", "🌋":
			return Color(2.0, 0.7, 0.2)  # 火焰橙
		"💧", "🌊", "🐙", "🌀", "💨":
			return Color(0.3, 1.2, 2.0)  # 水蓝
		"💩":
			return Color(0.9, 0.55, 0.2)  # 棕
		"🛡️":
			return Color(0.5, 1.8, 1.8)  # 护盾青
		"☠️", "💀":
			return Color(0.6, 0.0, 1.4)  # 毒紫
		"📊", "📈", "📑", "📁", "🗂️":
			return Color(2.0, 1.8, 0.3)  # 文档金
		"🌰", "🍄", "🌱":
			return Color(0.6, 1.5, 0.4)  # 自然绿
		_:
			return Color.WHITE

# --- 2. 玩家攻击 (Player Attack) ---
# 传入卡牌的 Emoji (字符串或贴图)，实现"投掷"感
func play_player_attack_anim(content):
	var projectile
	var emoji_str: String = str(content) if not (content is Texture2D) else ""
	
	if content is Texture2D:
		projectile = TextureRect.new()
		projectile.texture = content
		projectile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		projectile.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	else:
		projectile = Label.new()
		projectile.text = emoji_str
		projectile.add_theme_font_size_override("font_size", 64)
		projectile.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		projectile.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	projectile.custom_minimum_size = Vector2(100, 100)
	projectile.size = Vector2(100, 100)
	projectile.pivot_offset = Vector2(50, 50)
	
	# 根据 emoji 类型设置发光颜色
	var proj_color = _get_emoji_color(emoji_str)
	projectile.modulate = proj_color
	
	# 从屏幕下方中心出发
	var start_pos = Vector2(get_viewport().size.x / 2 - 50, get_viewport().size.y + 100)
	projectile.global_position = start_pos
	projectile.scale = Vector2(0.5, 0.5)
	
	# 必须添加到 CanvasLayer 或者根节点下，确保不被 UI 遮挡
	get_tree().root.add_child(projectile)
	
	# B. 弹道飞行轨迹（护盾类走弧线，攻击类直冲）
	var t = create_tween().set_parallel(true)
	var target_pos = boss_node.global_position + (boss_node.size / 2) - Vector2(50, 50)
	var flight_time = 0.25 if proj_color != Color.WHITE else 0.3
	
	t.tween_property(projectile, "global_position", target_pos, flight_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_property(projectile, "scale", Vector2(1.6, 1.6), flight_time)
	# 飞行时旋转增加动感
	t.tween_property(projectile, "rotation_degrees", 360.0, flight_time)
	
	# C. 命中反馈
	await t.finished
	
	# 命中时爆出同色闪光
	if flash_layer:
		flash_layer.modulate = Color(proj_color.r, proj_color.g, proj_color.b, 0.45)
		var flash_t = create_tween()
		flash_t.tween_property(flash_layer, "modulate:a", 0, 0.3).set_trans(Tween.TRANS_SINE)
		flash_t.finished.connect(func(): flash_layer.modulate = Color(1, 0, 0, 0))
	
	projectile.queue_free()
	
	# 触发 Boss 的受击动画
	if boss_node.has_method("play_hit"):
		boss_node.play_hit()
	
	# 轻微震屏，增加打击感
	shake_screen(5.0, 0.1)

# --- 3. 连招特效 (Combo Flash) ---
func play_combo_flash():
	if not flash_layer: return
	var t = create_tween()
	# 金色闪烁
	flash_layer.modulate = Color(1, 1, 0, 0.4)
	t.tween_property(flash_layer, "modulate:a", 0, 0.5).set_trans(Tween.TRANS_SINE)
	# 结束后必须重置回红色基础色，否则后续受击会变黄
	t.finished.connect(func(): flash_layer.modulate = Color(1, 0, 0, 0))

# --- 通用的震屏函数 ---
func shake_screen(intensity: float, duration: float):
	var t = create_tween()
	var parent = get_parent()
	if not parent is Control: return
	
	var original_pos = parent.position
	
	# 快速来回跳动
	for i in range(5):
		var random_offset = Vector2(randf_range(-1,1), randf_range(-1,1)) * intensity
		t.tween_property(parent, "position", original_pos + random_offset, duration / 5)
	
	# 滚回原位
	t.tween_property(parent, "position", original_pos, 0.05)

# --- 4. 玩家躲避 (Player Evade) ---
func play_evade_anim():
	var parent = get_parent()
	if not parent is Control: return
	var sprite = %HeroSprite
	if not sprite: return
	
	var original_pos = sprite.position
	var t = create_tween()
	
	# 快速侧移一下
	t.tween_property(sprite, "position:x", original_pos.x - 40, 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(sprite, "modulate:a", 0.5, 0.1)
	t.tween_property(sprite, "position:x", original_pos.x, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(sprite, "modulate:a", 1.0, 0.2)
