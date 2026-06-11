# 玩家受击动画
extends Node

@onready var flash_layer = get_node_or_null("%FlashLayer")
@onready var boss_node = %BossSprite

# --- 1. 玩家受击 (Player Hit) ---
func play_player_hit_anim():
	shake_screen(10.0, 0.25)
	if not flash_layer: return
	flash_layer.modulate = Color(1, 0, 0, 0.35)
	var t = create_tween()
	t.tween_property(flash_layer, "modulate:a", 0, 0.35).set_trans(Tween.TRANS_SINE)
	t.finished.connect(func(): flash_layer.modulate = Color(1, 0, 0, 0))

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

# 攻击动画冷却控制：避免快速连打时特效叠加过多
var _attack_anim_busy := false

# --- 2. 玩家攻击 (Player Attack) ---
# 传入卡牌的 Emoji (字符串或贴图)，实现轻量投掷感
func play_player_attack_anim(content):
	# 冷却中直接跳过投掷物，只触发 Boss 受击
	if _attack_anim_busy:
		if boss_node.has_method("play_hit"):
			boss_node.play_hit()
		return
	_attack_anim_busy = true
	
	var emoji_str: String = str(content) if not (content is Texture2D) else ""
	var proj_color = _get_emoji_color(emoji_str)
	
	var projectile: Control
	if content is Texture2D:
		var tr_1 = TextureRect.new()
		tr_1.texture = content
		tr_1.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr_1.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		projectile = tr_1
	else:
		var lbl = Label.new()
		lbl.text = emoji_str
		lbl.add_theme_font_size_override("font_size", 56)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		projectile = lbl
	
	projectile.custom_minimum_size = Vector2(80, 80)
	projectile.size = Vector2(80, 80)
	projectile.pivot_offset = Vector2(40, 40)
	projectile.modulate = proj_color
	
	var start_pos = Vector2(get_viewport().size.x / 2 - 40, get_viewport().size.y - 80)
	projectile.global_position = start_pos
	projectile.scale = Vector2(0.6, 0.6)
	get_tree().root.add_child(projectile)
	
	var target_pos = boss_node.global_position + (boss_node.size / 2) - Vector2(40, 40)
	var t = create_tween().set_parallel(true)
	t.tween_property(projectile, "global_position", target_pos, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(projectile, "scale", Vector2(1.2, 1.2), 0.2)
	t.tween_property(projectile, "rotation_degrees", 180.0, 0.2)
	
	await t.finished
	projectile.queue_free()
	
	# 命中：只有攻击色（非白色）才做轻微闪光；去掉震屏，减少刺激
	if flash_layer and proj_color != Color.WHITE:
		flash_layer.modulate = Color(proj_color.r, proj_color.g, proj_color.b, 0.18)
		var flash_t = create_tween()
		flash_t.tween_property(flash_layer, "modulate:a", 0, 0.25).set_trans(Tween.TRANS_SINE)
		flash_t.finished.connect(func(): flash_layer.modulate = Color(1, 0, 0, 0))
	
	if boss_node.has_method("play_hit"):
		boss_node.play_hit()
	
	# 冷却 0.25 秒后才允许下一次投掷物
	await get_tree().create_timer(0.25).timeout
	_attack_anim_busy = false

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

# --- 5. 过场动画 (Story Animation) ---
func play_story_anim():
	var parent = get_parent()
	if not parent is Control: return