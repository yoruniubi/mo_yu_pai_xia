# EnemyAnimator.gd
extends Control # 如果是 TextureRect 用 Control，Sprite2D 则改用 Node2D

# 记录初始状态，防止动画播完后位置“跑偏”
@onready var original_pos = position
@onready var original_scale = scale

var idle_tween: Tween

func _ready():
	play_idle()

# --- 1. 常态 (Idle): 呼吸感 ---
func play_idle():
	# 如果有正在播的呼吸动画，先关掉
	if idle_tween: idle_tween.kill()
	
	idle_tween = create_tween().set_loops() # 无限循环
	# 缓慢地上下浮动
	idle_tween.tween_property(self, "position:y", original_pos.y + 10, 2.0).set_trans(Tween.TRANS_SINE)
	idle_tween.tween_property(self, "position:y", original_pos.y, 2.0).set_trans(Tween.TRANS_SINE)
	
	# 同步进行微弱的缩放 (呼吸感)
	idle_tween.parallel().tween_property(self, "scale", original_scale * 1.02, 2.0).set_trans(Tween.TRANS_SINE)
	idle_tween.parallel().tween_property(self, "scale", original_scale, 2.0).set_trans(Tween.TRANS_SINE)

# --- 2. 受击 (Hit): 震动与闪红 ---
func play_hit():
	# 受击是高优先级，先杀掉呼吸动画
	if idle_tween: idle_tween.kill()
	
	var hit_tween = create_tween()
	# 瞬间变色（变红或爆白）
	modulate = Color(2, 0.5, 0.5) # 增加红色分量，数值大于1会产生发光感
	
	# 快速左右剧烈晃动
	for i in range(4):
		var offset = 10 if i % 2 == 0 else -10
		hit_tween.tween_property(self, "position:x", original_pos.x + offset, 0.05)
	
	# 恢复原状
	hit_tween.tween_property(self, "position:x", original_pos.x, 0.05)
	hit_tween.parallel().tween_property(self, "modulate", Color.WHITE, 0.1)
	
	# 动画播完后回到呼吸状态
	hit_tween.finished.connect(play_idle)

# --- 3. 攻击 (Attack): 俯冲撞击 ---
func play_attack():
	if idle_tween: idle_tween.kill()
	
	var atk_tween = create_tween()
	# A. 蓄力：微微后退并缩小
	atk_tween.tween_property(self, "position:y", original_pos.y - 30, 0.2).set_trans(Tween.TRANS_QUAD)
	atk_tween.parallel().tween_property(self, "scale", original_scale * 0.9, 0.2)
	
	# B. 冲锋：迅速向玩家（下方）冲去，并放大
	atk_tween.tween_property(self, "position:y", original_pos.y + 100, 0.1).set_trans(Tween.TRANS_EXPO)
	atk_tween.parallel().tween_property(self, "scale", original_scale * 1.1, 0.1)
	
	# C. 回弹：回到原位
	atk_tween.tween_property(self, "position:y", original_pos.y, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	atk_tween.parallel().tween_property(self, "scale", original_scale, 0.3)
	
	atk_tween.finished.connect(play_idle)